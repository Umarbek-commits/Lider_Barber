-- Lider Barber — full schema apply (generated from migrations/0001-0009).
-- Paste this whole file into Supabase Studio → SQL Editor → Run.

-- ============================================================
-- migrations/0001_schema.sql
-- ============================================================
-- Lider Barber — core schema (Stage 1)
-- Single-barber v1. Double-booking is prevented at the DB level (see the
-- EXCLUDE constraint on `bookings`), not only in the UI.

create extension if not exists "pgcrypto";   -- gen_random_uuid()
-- btree_gist lets us combine scalar equality (future: barber_id) with a range
-- in one EXCLUDE constraint. Harmless for the single-barber case.
create extension if not exists "btree_gist";

-- ---------------------------------------------------------------------------
-- users: app profile keyed to auth.uid(). Role gates the admin panel.
-- ---------------------------------------------------------------------------
create table if not exists public.users (
  id         uuid primary key references auth.users (id) on delete cascade,
  name       text,
  phone      text unique not null,
  role       text not null default 'client' check (role in ('client', 'admin')),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- services
-- ---------------------------------------------------------------------------
create table if not exists public.services (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  price_som    integer not null check (price_som >= 0),
  duration_min integer not null check (duration_min > 0),
  description  text,
  is_active    boolean not null default true,
  sort_order   integer not null default 0,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- clients: deduplicated by phone. Aggregates maintained by trigger.
-- ---------------------------------------------------------------------------
create table if not exists public.clients (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  phone            text unique not null,
  notes            text,
  is_blacklisted   boolean not null default false,
  blacklist_reason text,
  visits_count     integer not null default 0,
  total_spent      integer not null default 0,
  last_visit       date,
  created_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- weekly working hours. weekday: 1 = Monday … 7 = Sunday (DateTime.weekday).
-- ---------------------------------------------------------------------------
create table if not exists public.schedules (
  id          uuid primary key default gen_random_uuid(),
  weekday     integer not null unique check (weekday between 1 and 7),
  is_day_off  boolean not null default false,
  start_time  time,
  end_time    time,
  break_start time,
  break_end   time,
  check (is_day_off or (start_time is not null and end_time is not null and end_time > start_time))
);

-- ---------------------------------------------------------------------------
-- one-off date overrides (holidays / shortened days)
-- ---------------------------------------------------------------------------
create table if not exists public.schedule_exceptions (
  id         uuid primary key default gen_random_uuid(),
  date       date not null unique,
  type       text not null check (type in ('day_off', 'custom_hours')),
  start_time time,
  end_time   time,
  check (type = 'day_off' or (start_time is not null and end_time is not null and end_time > start_time))
);

-- ---------------------------------------------------------------------------
-- bookings. `slot` is a generated half-open time range used to forbid overlaps.
-- ---------------------------------------------------------------------------
create table if not exists public.bookings (
  id           uuid primary key default gen_random_uuid(),
  client_id    uuid not null references public.clients (id) on delete cascade,
  service_id   uuid not null references public.services (id) on delete restrict,
  booking_date date not null,
  start_time   time not null,
  end_time     time not null,
  status       text not null default 'pending'
                 check (status in ('pending', 'confirmed', 'completed', 'cancelled', 'no_show')),
  comment      text,
  created_at   timestamptz not null default now(),
  check (end_time > start_time),
  slot tsrange generated always as (
    tsrange((booking_date + start_time), (booking_date + end_time), '[)')
  ) stored
);

-- No two active bookings may overlap in time (the core anti-double-booking rule).
-- Cancelled / no-show bookings free the slot again.
alter table public.bookings
  drop constraint if exists bookings_no_overlap;
alter table public.bookings
  add constraint bookings_no_overlap
  exclude using gist (slot with &&)
  where (status not in ('cancelled', 'no_show'));

create index if not exists bookings_date_idx on public.bookings (booking_date);
create index if not exists bookings_status_idx on public.bookings (status);


-- ============================================================
-- migrations/0002_rls.sql
-- ============================================================
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


-- ============================================================
-- migrations/0003_functions.sql
-- ============================================================
-- Functions, triggers and public RPCs for Lider Barber.

-- ---------------------------------------------------------------------------
-- Auto-create a public.users profile when someone signs up (phone OTP).
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, phone, role)
  values (new.id, coalesce(new.phone, new.email, new.id::text), 'client')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Public availability: busy time ranges for a date, WITHOUT any client PII.
-- Anonymous visitors call this; the app subtracts these from the working hours.
-- ---------------------------------------------------------------------------
create or replace function public.get_busy_ranges(p_date date)
returns table (start_time time, end_time time)
language sql
security definer
set search_path = public
stable
as $$
  select b.start_time, b.end_time
  from public.bookings b
  where b.booking_date = p_date
    and b.status not in ('cancelled', 'no_show');
$$;

-- ---------------------------------------------------------------------------
-- Public booking creation. Upserts the client by phone, enforces blacklist,
-- derives the end time from the service duration (anti-tamper), and relies on
-- the exclusion constraint to guarantee no double-booking under concurrency.
-- Raises: 'blacklisted', 'slot_taken', 'service_not_found'.
-- ---------------------------------------------------------------------------
create or replace function public.create_booking(
  p_service_id uuid,
  p_date       date,
  p_start      time,
  p_name       text,
  p_phone      text,
  p_comment    text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_duration    int;
  v_end         time;
  v_client      uuid;
  v_blacklisted boolean;
  v_booking     uuid;
begin
  select duration_min into v_duration
  from public.services
  where id = p_service_id and is_active = true;

  if v_duration is null then
    raise exception 'service_not_found' using errcode = 'no_data_found';
  end if;

  v_end := p_start + make_interval(mins => v_duration);

  -- Upsert client by phone; refresh the name if provided.
  insert into public.clients (name, phone)
  values (p_name, p_phone)
  on conflict (phone) do update set name = excluded.name
  returning id, is_blacklisted into v_client, v_blacklisted;

  if v_blacklisted then
    raise exception 'blacklisted' using errcode = 'check_violation';
  end if;

  -- The exclusion constraint is the real guard against concurrent overlaps.
  begin
    insert into public.bookings (client_id, service_id, booking_date,
                                 start_time, end_time, comment, status)
    values (v_client, p_service_id, p_date, p_start, v_end, p_comment, 'pending')
    returning id into v_booking;
  exception
    when exclusion_violation then
      raise exception 'slot_taken' using errcode = 'unique_violation';
  end;

  return v_booking;
end;
$$;

-- Availability + booking are the only public entry points.
grant execute on function public.get_busy_ranges(date) to anon, authenticated;
grant execute on function public.create_booking(uuid, date, time, text, text, text)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Keep client aggregates (visits_count, total_spent, last_visit) in sync with
-- completed bookings. Recomputed on any status change to stay correct when a
-- booking is un-completed or cancelled.
-- ---------------------------------------------------------------------------
create or replace function public.refresh_client_stats(p_client uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.clients c set
    visits_count = coalesce((
      select count(*) from public.bookings b
      where b.client_id = p_client and b.status = 'completed'), 0),
    total_spent = coalesce((
      select sum(s.price_som)
      from public.bookings b
      join public.services s on s.id = b.service_id
      where b.client_id = p_client and b.status = 'completed'), 0),
    last_visit = (
      select max(b.booking_date) from public.bookings b
      where b.client_id = p_client and b.status = 'completed')
  where c.id = p_client;
$$;

create or replace function public.on_booking_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_client_stats(old.client_id);
    return old;
  end if;
  perform public.refresh_client_stats(new.client_id);
  if tg_op = 'UPDATE' and old.client_id <> new.client_id then
    perform public.refresh_client_stats(old.client_id);
  end if;
  return new;
end;
$$;

drop trigger if exists bookings_stats_sync on public.bookings;
create trigger bookings_stats_sync
  after insert or update or delete on public.bookings
  for each row execute function public.on_booking_status_change();


-- ============================================================
-- migrations/0004_seed.sql
-- ============================================================
-- Initial content for Lider Barber. Safe to re-run (idempotent-ish).

-- Services from the brief.
insert into public.services (name, price_som, duration_min, sort_order)
select * from (values
  ('Мужская стрижка',  500, 60,  1),
  ('Борода',           300, 45,  2),
  ('Комплекс',         700, 90,  3),
  ('Детская стрижка',  400, 60,  4)
) as v(name, price_som, duration_min, sort_order)
where not exists (select 1 from public.services);

-- Weekly schedule: Mon–Sat 10:00–20:00 with a 14:00–15:00 break, Sunday off.
insert into public.schedules (weekday, is_day_off, start_time, end_time, break_start, break_end)
select * from (values
  (1, false, time '10:00', time '20:00', time '14:00', time '15:00'),
  (2, false, time '10:00', time '20:00', time '14:00', time '15:00'),
  (3, false, time '10:00', time '20:00', time '14:00', time '15:00'),
  (4, false, time '10:00', time '20:00', time '14:00', time '15:00'),
  (5, false, time '10:00', time '20:00', time '14:00', time '15:00'),
  (6, false, time '10:00', time '18:00', null,        null),
  (7, true,  null,         null,         null,        null)
) as v(weekday, is_day_off, start_time, end_time, break_start, break_end)
on conflict (weekday) do nothing;


-- ============================================================
-- migrations/0005_hardening.sql
-- ============================================================
-- Lider Barber — security & correctness hardening (Stage 4).

-- ---------------------------------------------------------------------------
-- 1) Prevent privilege escalation via users_self_update.
--    The old policy let a signed-in user update their own row with no column
--    restriction — including setting role = 'admin'. Now a non-admin may only
--    keep role = 'client'; only an existing admin can change roles.
-- ---------------------------------------------------------------------------
drop policy if exists users_self_update on public.users;
create policy users_self_update on public.users
  for update
  using (id = auth.uid())
  with check (id = auth.uid() and (role = 'client' or public.is_admin()));

-- ---------------------------------------------------------------------------
-- 2) create_booking now validates the slot against working hours / day-off /
--    break server-side (the UI already did, but the RPC trusted its input).
--    New error: 'closed' (day off) and 'outside_hours'.
-- ---------------------------------------------------------------------------
create or replace function public.create_booking(
  p_service_id uuid,
  p_date       date,
  p_start      time,
  p_name       text,
  p_phone      text,
  p_comment    text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_duration    int;
  v_end         time;
  v_client      uuid;
  v_blacklisted boolean;
  v_booking     uuid;
  v_isodow      int;
  v_exc_type    text;
  v_open        time;
  v_close       time;
  v_break_start time;
  v_break_end   time;
  v_day_off     boolean;
begin
  select duration_min into v_duration
  from public.services
  where id = p_service_id and is_active = true;

  if v_duration is null then
    raise exception 'service_not_found' using errcode = 'no_data_found';
  end if;

  v_end := p_start + make_interval(mins => v_duration);

  -- Resolve working hours for the date: exception overrides the weekly schedule.
  select type, start_time, end_time
    into v_exc_type, v_open, v_close
  from public.schedule_exceptions
  where date = p_date;

  if v_exc_type = 'day_off' then
    raise exception 'closed' using errcode = 'restrict_violation';
  elsif v_exc_type = 'custom_hours' then
    v_break_start := null;
    v_break_end := null;
  else
    v_isodow := extract(isodow from p_date);  -- 1=Mon … 7=Sun
    select is_day_off, start_time, end_time, break_start, break_end
      into v_day_off, v_open, v_close, v_break_start, v_break_end
    from public.schedules
    where weekday = v_isodow;

    if not found or v_day_off then
      raise exception 'closed' using errcode = 'restrict_violation';
    end if;
  end if;

  -- Must fit inside working hours.
  if v_open is null or v_close is null or p_start < v_open or v_end > v_close then
    raise exception 'outside_hours' using errcode = 'restrict_violation';
  end if;

  -- Must not overlap the lunch break.
  if v_break_start is not null and v_break_end is not null
     and p_start < v_break_end and v_end > v_break_start then
    raise exception 'outside_hours' using errcode = 'restrict_violation';
  end if;

  -- Upsert client by phone; refresh the name if provided.
  insert into public.clients (name, phone)
  values (p_name, p_phone)
  on conflict (phone) do update set name = excluded.name
  returning id, is_blacklisted into v_client, v_blacklisted;

  if v_blacklisted then
    raise exception 'blacklisted' using errcode = 'check_violation';
  end if;

  -- The exclusion constraint is the real guard against concurrent overlaps.
  begin
    insert into public.bookings (client_id, service_id, booking_date,
                                 start_time, end_time, comment, status)
    values (v_client, p_service_id, p_date, p_start, v_end, p_comment, 'pending')
    returning id into v_booking;
  exception
    when exclusion_violation then
      raise exception 'slot_taken' using errcode = 'unique_violation';
  end;

  return v_booking;
end;
$$;


-- ============================================================
-- migrations/0006_client_cabinet.sql
-- ============================================================
-- Lider Barber — client cabinet (Stage 5).
-- Ties bookings to the authenticated user who made them, so a logged-in client
-- can see and cancel their own bookings. Anonymous bookings keep user_id NULL.

-- 1) Ownership column.
alter table public.bookings
  add column if not exists user_id uuid references auth.users (id) on delete set null;

create index if not exists bookings_user_idx on public.bookings (user_id);

-- 2) create_booking stamps the caller's uid (NULL when anonymous). This is the
--    same function as 0005 plus the user_id on insert.
create or replace function public.create_booking(
  p_service_id uuid,
  p_date       date,
  p_start      time,
  p_name       text,
  p_phone      text,
  p_comment    text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_duration    int;
  v_end         time;
  v_client      uuid;
  v_blacklisted boolean;
  v_booking     uuid;
  v_isodow      int;
  v_exc_type    text;
  v_open        time;
  v_close       time;
  v_break_start time;
  v_break_end   time;
  v_day_off     boolean;
begin
  select duration_min into v_duration
  from public.services
  where id = p_service_id and is_active = true;

  if v_duration is null then
    raise exception 'service_not_found' using errcode = 'no_data_found';
  end if;

  v_end := p_start + make_interval(mins => v_duration);

  select type, start_time, end_time
    into v_exc_type, v_open, v_close
  from public.schedule_exceptions
  where date = p_date;

  if v_exc_type = 'day_off' then
    raise exception 'closed' using errcode = 'restrict_violation';
  elsif v_exc_type = 'custom_hours' then
    v_break_start := null;
    v_break_end := null;
  else
    v_isodow := extract(isodow from p_date);
    select is_day_off, start_time, end_time, break_start, break_end
      into v_day_off, v_open, v_close, v_break_start, v_break_end
    from public.schedules
    where weekday = v_isodow;

    if not found or v_day_off then
      raise exception 'closed' using errcode = 'restrict_violation';
    end if;
  end if;

  if v_open is null or v_close is null or p_start < v_open or v_end > v_close then
    raise exception 'outside_hours' using errcode = 'restrict_violation';
  end if;

  if v_break_start is not null and v_break_end is not null
     and p_start < v_break_end and v_end > v_break_start then
    raise exception 'outside_hours' using errcode = 'restrict_violation';
  end if;

  insert into public.clients (name, phone)
  values (p_name, p_phone)
  on conflict (phone) do update set name = excluded.name
  returning id, is_blacklisted into v_client, v_blacklisted;

  if v_blacklisted then
    raise exception 'blacklisted' using errcode = 'check_violation';
  end if;

  begin
    insert into public.bookings (client_id, service_id, booking_date,
                                 start_time, end_time, comment, status, user_id)
    values (v_client, p_service_id, p_date, p_start, v_end, p_comment, 'pending', auth.uid())
    returning id into v_booking;
  exception
    when exclusion_violation then
      raise exception 'slot_taken' using errcode = 'unique_violation';
  end;

  return v_booking;
end;
$$;

-- 3) A client may read their own bookings (admins already can via bookings_admin_all).
drop policy if exists bookings_owner_select on public.bookings;
create policy bookings_owner_select on public.bookings
  for select using (user_id is not null and user_id = auth.uid());

-- 4) Cancel own upcoming booking. Frees the slot (exclusion ignores cancelled).
create or replace function public.cancel_booking(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner  uuid;
  v_status text;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = 'insufficient_privilege';
  end if;

  select user_id, status into v_owner, v_status
  from public.bookings where id = p_id;

  if not found then
    raise exception 'not_found' using errcode = 'no_data_found';
  end if;
  if v_owner is distinct from auth.uid() then
    raise exception 'forbidden' using errcode = 'insufficient_privilege';
  end if;
  if v_status not in ('pending', 'confirmed') then
    raise exception 'cannot_cancel' using errcode = 'check_violation';
  end if;

  update public.bookings set status = 'cancelled' where id = p_id;
end;
$$;

grant execute on function public.cancel_booking(uuid) to authenticated;


-- ============================================================
-- migrations/0007_contact_phone.sql
-- ============================================================
-- Lider Barber — remember a logged-in client's phone (Stage 6).
-- Google gives name + email but no phone; we ask it once and store it on the
-- user's profile so the booking form can prefill it next time.

alter table public.users
  add column if not exists contact_phone text;

-- create_booking (authed variant of 0006) also stamps the caller's phone onto
-- their profile so it can be prefilled later.
create or replace function public.create_booking(
  p_service_id uuid,
  p_date       date,
  p_start      time,
  p_name       text,
  p_phone      text,
  p_comment    text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_duration    int;
  v_end         time;
  v_client      uuid;
  v_blacklisted boolean;
  v_booking     uuid;
  v_isodow      int;
  v_exc_type    text;
  v_open        time;
  v_close       time;
  v_break_start time;
  v_break_end   time;
  v_day_off     boolean;
begin
  select duration_min into v_duration
  from public.services
  where id = p_service_id and is_active = true;

  if v_duration is null then
    raise exception 'service_not_found' using errcode = 'no_data_found';
  end if;

  v_end := p_start + make_interval(mins => v_duration);

  select type, start_time, end_time
    into v_exc_type, v_open, v_close
  from public.schedule_exceptions
  where date = p_date;

  if v_exc_type = 'day_off' then
    raise exception 'closed' using errcode = 'restrict_violation';
  elsif v_exc_type = 'custom_hours' then
    v_break_start := null;
    v_break_end := null;
  else
    v_isodow := extract(isodow from p_date);
    select is_day_off, start_time, end_time, break_start, break_end
      into v_day_off, v_open, v_close, v_break_start, v_break_end
    from public.schedules
    where weekday = v_isodow;

    if not found or v_day_off then
      raise exception 'closed' using errcode = 'restrict_violation';
    end if;
  end if;

  if v_open is null or v_close is null or p_start < v_open or v_end > v_close then
    raise exception 'outside_hours' using errcode = 'restrict_violation';
  end if;

  if v_break_start is not null and v_break_end is not null
     and p_start < v_break_end and v_end > v_break_start then
    raise exception 'outside_hours' using errcode = 'restrict_violation';
  end if;

  insert into public.clients (name, phone)
  values (p_name, p_phone)
  on conflict (phone) do update set name = excluded.name
  returning id, is_blacklisted into v_client, v_blacklisted;

  if v_blacklisted then
    raise exception 'blacklisted' using errcode = 'check_violation';
  end if;

  -- Remember the phone on the caller's profile (authed bookings only).
  if auth.uid() is not null then
    update public.users set contact_phone = p_phone where id = auth.uid();
  end if;

  begin
    insert into public.bookings (client_id, service_id, booking_date,
                                 start_time, end_time, comment, status, user_id)
    values (v_client, p_service_id, p_date, p_start, v_end, p_comment, 'pending', auth.uid())
    returning id into v_booking;
  exception
    when exclusion_violation then
      raise exception 'slot_taken' using errcode = 'unique_violation';
  end;

  return v_booking;
end;
$$;


-- ============================================================
-- migrations/0008_barbers.sql
-- ============================================================
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


-- ============================================================
-- migrations/0009_news.sql
-- ============================================================
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


