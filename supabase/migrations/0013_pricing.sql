-- Lider Barber — late-cancel penalty + evening surcharge (Stage 11).
--   * Cancelling less than 1 hour before the start adds a 50 сом penalty.
--   * Bookings starting 20:00–23:00 cost +50 сом on any service (auto).

-- Accumulated penalties for a client.
alter table public.clients
  add column if not exists penalty_som int not null default 0;

-- +50 сом for evening bookings (start 20:00..22:59).
create or replace function public.evening_surcharge(p_start time)
returns int
language sql
immutable
as $$
  select case when p_start >= time '20:00' and p_start < time '23:00' then 50 else 0 end;
$$;

-- total_spent now includes the evening surcharge per completed visit.
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
      select sum(s.price_som + public.evening_surcharge(b.start_time))
      from public.bookings b
      join public.services s on s.id = b.service_id
      where b.client_id = p_client and b.status = 'completed'), 0),
    last_visit = (
      select max(b.booking_date) from public.bookings b
      where b.client_id = p_client and b.status = 'completed')
  where c.id = p_client;
$$;

-- Cancel own upcoming booking; add a 50 сом penalty if < 1 hour remains.
create or replace function public.cancel_booking(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner  uuid;
  v_status text;
  v_client uuid;
  v_start  timestamptz;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = 'insufficient_privilege';
  end if;

  select user_id, status, client_id, public.booking_at(booking_date, start_time)
    into v_owner, v_status, v_client, v_start
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

  if v_start <= now() + interval '1 hour' then
    update public.clients set penalty_som = penalty_som + 50 where id = v_client;
  end if;
end;
$$;
