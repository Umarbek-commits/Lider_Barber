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
