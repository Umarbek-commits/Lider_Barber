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
