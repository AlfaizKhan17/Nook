-- Nook campus social feed foundation. Apply in Supabase SQL Editor.
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null check (char_length(trim(content)) between 1 and 1000),
  visibility text not null default 'public' check (visibility in ('public','community')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null check (char_length(trim(content)) between 1 and 1000),
  created_at timestamptz not null default now()
);

create index if not exists posts_created_at_idx on public.posts(created_at desc);
create index if not exists posts_user_id_idx on public.posts(user_id);
create index if not exists post_likes_post_id_idx on public.post_likes(post_id);
create index if not exists comments_post_id_created_at_idx on public.comments(post_id, created_at);

alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.comments enable row level security;

drop policy if exists "Signed-in users can read public posts" on public.posts;
create policy "Signed-in users can read public posts" on public.posts for select to authenticated using (visibility = 'public' or user_id = auth.uid());
drop policy if exists "Students can create their own posts" on public.posts;
create policy "Students can create their own posts" on public.posts for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "Authors can update their own posts" on public.posts;
create policy "Authors can update their own posts" on public.posts for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "Authors can delete their own posts" on public.posts;
create policy "Authors can delete their own posts" on public.posts for delete to authenticated using (user_id = auth.uid());

drop policy if exists "Signed-in users can read likes" on public.post_likes;
create policy "Signed-in users can read likes" on public.post_likes for select to authenticated using (true);
drop policy if exists "Users can like as themselves" on public.post_likes;
create policy "Users can like as themselves" on public.post_likes for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "Users can remove their own likes" on public.post_likes;
create policy "Users can remove their own likes" on public.post_likes for delete to authenticated using (user_id = auth.uid());

drop policy if exists "Signed-in users can read comments" on public.comments;
create policy "Signed-in users can read comments" on public.comments for select to authenticated using (true);
drop policy if exists "Users can create their own comments" on public.comments;
create policy "Users can create their own comments" on public.comments for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "Users can update their own comments" on public.comments;
create policy "Users can update their own comments" on public.comments for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "Users can delete their own comments" on public.comments;
create policy "Users can delete their own comments" on public.comments for delete to authenticated using (user_id = auth.uid());
