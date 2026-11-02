create table if not exists public.banners (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  content text not null default '',
  image_url text not null,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.banners enable row level security;

drop policy if exists "Anyone can view banners" on public.banners;
create policy "Anyone can view banners"
on public.banners
for select
to anon, authenticated
using (true);

grant select on table public.banners to anon, authenticated;