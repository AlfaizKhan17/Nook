-- Keep the post bucket's MIME allow-list in sync with the image picker.
update storage.buckets
set allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif']
where id = 'post-images';

-- Create a profile for new Auth users, including users who must confirm
-- their email before a client session is issued.
create or replace function public.handle_nook_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles(id, name, email, phone)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'name', ''), split_part(new.email, '@', 1)),
    new.email,
    coalesce(new.raw_user_meta_data ->> 'phone', '')
  )
  on conflict (id) do update
    set email = excluded.email,
        name = coalesce(nullif(public.profiles.name, ''), excluded.name),
        phone = coalesce(nullif(public.profiles.phone, ''), excluded.phone);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_nook_profile on auth.users;
create trigger on_auth_user_created_nook_profile
  after insert on auth.users
  for each row execute procedure public.handle_nook_new_user_profile();

-- Nook feature completion migration.
-- Safe to run after 202611060001 and 202611060002. All schema additions
-- are guarded so this file can also be used to reconcile an existing project.

-- Membership roles support creator/admin moderation.
alter table public.group_members
  add column if not exists role text not null default 'member';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'group_members_role_check'
      and conrelid = 'public.group_members'::regclass
  ) then
    alter table public.group_members
      add constraint group_members_role_check
      check (role in ('member', 'admin'));
  end if;
end $$;

-- Join requests are reviewed by the group creator or an admin.
create table if not exists public.group_join_requests (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null
);

create unique index if not exists group_join_requests_one_pending_idx
  on public.group_join_requests(group_id, user_id)
  where status = 'pending';

create index if not exists group_join_requests_group_status_idx
  on public.group_join_requests(group_id, status);

alter table public.group_join_requests enable row level security;

drop policy if exists "Users read own requests and group managers read requests"
  on public.group_join_requests;
create policy "Users read own requests and group managers read requests"
  on public.group_join_requests
  for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.groups g
      where g.id = group_join_requests.group_id
        and g.created_by = auth.uid()
    )
    or exists (
      select 1 from public.group_members gm
      where gm.group_id = group_join_requests.group_id
        and gm.user_id = auth.uid()
        and gm.role = 'admin'
    )
  );

drop policy if exists "Users request to join as themselves"
  on public.group_join_requests;
create policy "Users request to join as themselves"
  on public.group_join_requests
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and not exists (
      select 1 from public.group_members gm
      where gm.group_id = group_join_requests.group_id
        and gm.user_id = auth.uid()
    )
  );

-- Remove the legacy direct self-join policy. Membership is granted only
-- by the secure review function below or by the group creator's own insert.
drop policy if exists "Students can join as themselves" on public.group_members;
drop policy if exists "Students can join groups" on public.group_members;
drop policy if exists "Nook join groups" on public.group_members;
drop policy if exists "Group creator adds themselves as admin" on public.group_members;
create policy "Group creator adds themselves as admin"
  on public.group_members
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and role = 'admin'
    and exists (
      select 1 from public.groups g
      where g.id = group_members.group_id
        and g.created_by = auth.uid()
    )
  );

create or replace function public.review_group_join_request(
  p_request_id uuid,
  p_decision text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.group_join_requests%rowtype;
  v_is_manager boolean;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_decision not in ('approved', 'rejected') then
    raise exception 'Decision must be approved or rejected';
  end if;

  select * into v_request
  from public.group_join_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Join request not found';
  end if;

  select (
    g.created_by = auth.uid()
    or exists (
      select 1 from public.group_members gm
      where gm.group_id = v_request.group_id
        and gm.user_id = auth.uid()
        and gm.role = 'admin'
    )
  ) into v_is_manager
  from public.groups g
  where g.id = v_request.group_id;

  if coalesce(v_is_manager, false) is not true then
    raise exception 'Only the group creator or an admin can review requests';
  end if;

  if v_request.status <> 'pending' then
    raise exception 'This request has already been reviewed';
  end if;

  update public.group_join_requests
  set status = p_decision,
      reviewed_at = now(),
      reviewed_by = auth.uid()
  where id = p_request_id;

  if p_decision = 'approved' then
    insert into public.group_members(group_id, user_id, role)
    values (v_request.group_id, v_request.user_id, 'member')
    on conflict (group_id, user_id) do nothing;
  end if;
end;
$$;

revoke all on function public.review_group_join_request(uuid, text) from public;
grant execute on function public.review_group_join_request(uuid, text)
  to authenticated;

-- Nested replies.
alter table public.comments
  add column if not exists parent_comment_id uuid;

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'comments_parent_comment_id_fkey'
      and conrelid = 'public.comments'::regclass
      and confdeltype <> 'c'
  ) then
    alter table public.comments
      drop constraint comments_parent_comment_id_fkey;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'comments_parent_comment_id_fkey'
      and conrelid = 'public.comments'::regclass
  ) then
    alter table public.comments
      add constraint comments_parent_comment_id_fkey
      foreign key (parent_comment_id)
      references public.comments(id)
      on delete cascade;
  end if;
end $$;

create index if not exists comments_parent_comment_id_idx
  on public.comments(parent_comment_id);

-- A reply must belong to the same post as its parent comment.
create unique index if not exists comments_id_post_id_unique
  on public.comments(id, post_id);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'comments_parent_same_post_fkey'
      and conrelid = 'public.comments'::regclass
  ) then
    alter table public.comments
      add constraint comments_parent_same_post_fkey
      foreign key (parent_comment_id, post_id)
      references public.comments(id, post_id)
      on delete cascade;
  end if;
end $$;

-- Group posts are private to their group; campus posts are public.
drop policy if exists "Signed-in users can read public posts" on public.posts;
drop policy if exists "Read campus and group posts" on public.posts;
create policy "Read campus and group posts"
  on public.posts
  for select to authenticated
  using (
    (visibility = 'public' and group_id is null)
    or user_id = auth.uid()
    or (
      group_id is not null
      and exists (
        select 1 from public.group_members gm
        where gm.group_id = posts.group_id
          and gm.user_id = auth.uid()
      )
    )
  );

drop policy if exists "Students can create their own posts" on public.posts;
create policy "Students can create their own posts"
  on public.posts
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (
      group_id is null and visibility = 'public'
      or group_id is not null and visibility = 'community'
        and exists (
          select 1 from public.group_members gm
          where gm.group_id = posts.group_id
            and gm.user_id = auth.uid()
        )
    )
  );

-- Ensure deleting a group removes its database-owned content.
do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'posts_group_id_fkey'
      and conrelid = 'public.posts'::regclass
      and confdeltype <> 'c'
  ) then
    alter table public.posts drop constraint posts_group_id_fkey;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'posts_group_id_fkey'
      and conrelid = 'public.posts'::regclass
  ) then
    alter table public.posts
      add constraint posts_group_id_fkey
      foreign key (group_id) references public.groups(id) on delete cascade;
  end if;
end $$;
