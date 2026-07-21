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
