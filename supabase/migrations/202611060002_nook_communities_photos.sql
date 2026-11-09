
-- Nook: photo posts, campus groups and group discussions.
-- Run after 202611060001_nook_social_feed.sql in Supabase SQL Editor.

-- Allow text-only, photo-only, and mixed posts.
alter table public.posts
  add column if not exists image_urls text[] not null default '{}',
  add column if not exists group_id uuid;

alter table public.posts
  drop constraint if exists posts_content_check;

alter table public.posts
  add constraint posts_content_or_images_check
  check (
    (char_length(trim(coalesce(content, ''))) between 1 and 1000)
    or cardinality(image_urls) > 0
  );

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 60),
  description text not null default '' check (char_length(description) <= 240),
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

alter table public.posts
  drop constraint if exists posts_group_id_fkey;
alter table public.posts
  add constraint posts_group_id_fkey
  foreign key (group_id) references public.groups(id) on delete set null;

create index if not exists groups_name_idx on public.groups(name);
create index if not exists group_members_user_id_idx on public.group_members(user_id);
create index if not exists posts_group_created_idx on public.posts(group_id, created_at desc);

alter table public.groups enable row level security;
alter table public.group_members enable row level security;

drop policy if exists "Signed-in users can read groups" on public.groups;
create policy "Signed-in users can read groups"
  on public.groups for select to authenticated using (true);

drop policy if exists "Students can create groups" on public.groups;
create policy "Students can create groups"
  on public.groups for insert to authenticated with check (created_by = auth.uid());

drop policy if exists "Group creators can update groups" on public.groups;
create policy "Group creators can update groups"
  on public.groups for update to authenticated using (created_by = auth.uid())
  with check (created_by = auth.uid());

drop policy if exists "Group creators can delete groups" on public.groups;
create policy "Group creators can delete groups"
  on public.groups for delete to authenticated using (created_by = auth.uid());

drop policy if exists "Signed-in users can read group members" on public.group_members;
create policy "Signed-in users can read group members"
  on public.group_members for select to authenticated using (true);

drop policy if exists "Students can join as themselves" on public.group_members;
create policy "Students can join as themselves"
  on public.group_members for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "Students can leave groups" on public.group_members;
create policy "Students can leave groups"
  on public.group_members for delete to authenticated using (user_id = auth.uid());


-- Group-scoped posts may only be created by current group members.
drop policy if exists "Students can create their own posts" on public.posts;
create policy "Students can create their own posts"
  on public.posts for insert to authenticated
  with check (
    user_id = auth.uid()
    and (
      group_id is null
      or exists (
        select 1 from public.group_members gm
        where gm.group_id = posts.group_id and gm.user_id = auth.uid()
      )
    )
  );

-- Public image URLs are used by feed cards. Only authenticated users may upload,
-- and each user can write only inside their own folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('post-images', 'post-images', true, 10485760, array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Campus users can view post photos" on storage.objects;
create policy "Campus users can view post photos"
  on storage.objects for select to authenticated
  using (bucket_id = 'post-images');

drop policy if exists "Users upload their own post photos" on storage.objects;
create policy "Users upload their own post photos"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'post-images' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Users delete their own post photos" on storage.objects;
create policy "Users delete their own post photos"
  on storage.objects for delete to authenticated
  using (bucket_id = 'post-images' and (storage.foldername(name))[1] = auth.uid()::text);
