-- Lider Barber — multiple masters / barbers (Stage 7).
-- Admin adds barbers (email+password). Barbers log into the same panel, see
-- what the admin sees, and "accept" bookings; the DB records which barber
-- accepted each client and when.

-- 1) Allow the 'barber' role.
alter table public.users drop constraint if exists users_role_check;
alter table public.users
  add constraint users_role_check check (role in ('client', 'admin', 'barber'));

-- 2) Who took the booking, and when.
alter table public.bookings
  add column if not exists accepted_by uuid references public.users (id) on delete set null;
alter table public.bookings
  add column if not exists accepted_at timestamptz;

-- 3) Staff = admin or barber.
create or replace function public.is_staff()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.role in ('admin', 'barber')
  );
$$;

-- 4) Barbers get the same read + manage access to bookings and clients as the
--    admin (settings/master management stay admin-only via is_admin()).
drop policy if exists bookings_staff_select on public.bookings;
create policy bookings_staff_select on public.bookings
  for select using (public.is_staff());
drop policy if exists bookings_staff_update on public.bookings;
create policy bookings_staff_update on public.bookings
  for update using (public.is_staff()) with check (public.is_staff());

drop policy if exists clients_staff_select on public.clients;
create policy clients_staff_select on public.clients
  for select using (public.is_staff());

-- Barbers may read the staff directory (to show who accepted a client).
drop policy if exists users_staff_select on public.users;
create policy users_staff_select on public.users
  for select using (public.is_staff());

-- 5) Staff status change that records who served the client.
create or replace function public.staff_set_status(p_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'forbidden' using errcode = 'insufficient_privilege';
  end if;
  if p_status not in ('pending', 'confirmed', 'completed', 'cancelled', 'no_show') then
    raise exception 'bad_status' using errcode = 'check_violation';
  end if;

  update public.bookings set
    status = p_status,
    accepted_by = case
      when p_status in ('confirmed', 'completed') and accepted_by is null
      then auth.uid() else accepted_by end,
    accepted_at = case
      when p_status in ('confirmed', 'completed') and accepted_at is null
      then now() else accepted_at end
  where id = p_id;
end;
$$;

grant execute on function public.staff_set_status(uuid, text) to authenticated;

-- 6) Admin promotes a freshly-signed-up account to a barber (and sets its name).
--    The app creates the auth user via a throwaway signup, then calls this.
create or replace function public.set_barber(p_email text, p_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = 'insufficient_privilege';
  end if;
  update public.users u
    set role = 'barber', name = coalesce(nullif(p_name, ''), u.name)
  from auth.users a
  where a.id = u.id and lower(a.email) = lower(p_email);
end;
$$;

grant execute on function public.set_barber(text, text) to authenticated;

-- 7) Admin removes a barber (revokes access; keeps their history).
create or replace function public.remove_barber(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = 'insufficient_privilege';
  end if;
  update public.users set role = 'client' where id = p_user_id and role = 'barber';
end;
$$;

grant execute on function public.remove_barber(uuid) to authenticated;
