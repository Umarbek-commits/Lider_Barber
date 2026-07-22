-- Lider Barber — news / announcements (Stage 8).
-- Admin posts announcements (e.g. "every 3rd haircut free"); all clients see
-- the active ones on the home screen.

create table if not exists public.news (
  id         uuid primary key default gen_random_uuid(),
  text       text not null,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists news_active_idx on public.news (is_active, created_at desc);

alter table public.news enable row level security;

-- Everyone reads active announcements; admin sees all and writes.
drop policy if exists news_public_read on public.news;
create policy news_public_read on public.news
  for select using (is_active or public.is_admin());

drop policy if exists news_admin_write on public.news;
create policy news_admin_write on public.news
  for all using (public.is_admin()) with check (public.is_admin());
