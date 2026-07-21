-- Row Level Security for Lider Barber.
--
-- Public (anonymous) visitors may READ the catalogue and working hours so the
-- app can compute free slots, but they must NOT read bookings/clients directly
-- (that would leak names, phones, comments). Anonymous booking and availability
-- go through SECURITY DEFINER functions in 0003_functions.sql instead.

-- Helper: is the current auth user an admin? SECURITY DEFINER avoids recursive
-- RLS evaluation on public.users.
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.role = 'admin'
  );
$$;

alter table public.users               enable row level security;
alter table public.services            enable row level security;
alter table public.clients             enable row level security;
alter table public.schedules           enable row level security;
alter table public.schedule_exceptions enable row level security;
alter table public.bookings            enable row level security;

-- users: a user sees/updates their own row; admins see all.
drop policy if exists users_self_select on public.users;
create policy users_self_select on public.users
  for select using (id = auth.uid() or public.is_admin());

drop policy if exists users_self_update on public.users;
create policy users_self_update on public.users
  for update using (id = auth.uid());

-- services: everyone reads active ones; admins read all and write.
drop policy if exists services_public_read on public.services;
create policy services_public_read on public.services
  for select using (is_active or public.is_admin());

drop policy if exists services_admin_write on public.services;
create policy services_admin_write on public.services
  for all using (public.is_admin()) with check (public.is_admin());

-- schedules & exceptions: public read (needed to compute slots), admin write.
drop policy if exists schedules_public_read on public.schedules;
create policy schedules_public_read on public.schedules
  for select using (true);
drop policy if exists schedules_admin_write on public.schedules;
create policy schedules_admin_write on public.schedules
  for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists exceptions_public_read on public.schedule_exceptions;
create policy exceptions_public_read on public.schedule_exceptions
  for select using (true);
drop policy if exists exceptions_admin_write on public.schedule_exceptions;
create policy exceptions_admin_write on public.schedule_exceptions
  for all using (public.is_admin()) with check (public.is_admin());

-- clients: admin only (public access is via RPC).
drop policy if exists clients_admin_all on public.clients;
create policy clients_admin_all on public.clients
  for all using (public.is_admin()) with check (public.is_admin());

-- bookings: admin only for direct access (public access is via RPC).
drop policy if exists bookings_admin_all on public.bookings;
create policy bookings_admin_all on public.bookings
  for all using (public.is_admin()) with check (public.is_admin());
