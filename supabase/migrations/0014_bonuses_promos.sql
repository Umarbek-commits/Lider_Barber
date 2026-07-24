-- Lider Barber — bonuses (cashback) + promo codes (Stage 12).
--   * Cashback: a % of each completed visit is credited as сом-bonuses.
--   * Promo codes: admin creates a code worth a сом discount; client enters it
--     at booking and the price drops by that amount.

-- App settings (single row). cashback_pct = % credited on completed visits.
create table if not exists public.app_settings (
  id           int primary key default 1 check (id = 1),
  cashback_pct int not null default 5 check (cashback_pct between 0 and 100)
);
insert into public.app_settings (id) values (1) on conflict (id) do nothing;

alter table public.app_settings enable row level security;
drop policy if exists app_settings_read on public.app_settings;
create policy app_settings_read on public.app_settings for select using (true);
drop policy if exists app_settings_write on public.app_settings;
create policy app_settings_write on public.app_settings
  for all using (public.is_admin()) with check (public.is_admin());

-- Client bonus balance (сом).
alter table public.clients add column if not exists bonus_som int not null default 0;

-- Promo codes.
create table if not exists public.promo_codes (
  id           uuid primary key default gen_random_uuid(),
  code         text not null unique,
  discount_som int not null check (discount_som > 0),
  is_active    boolean not null default true,
  created_at   timestamptz not null default now()
);
alter table public.promo_codes enable row level security;
drop policy if exists promo_public_read on public.promo_codes;
create policy promo_public_read on public.promo_codes
  for select using (is_active or public.is_admin());
drop policy if exists promo_admin_write on public.promo_codes;
create policy promo_admin_write on public.promo_codes
  for all using (public.is_admin()) with check (public.is_admin());

-- What was applied to a booking.
alter table public.bookings add column if not exists discount_som int not null default 0;
alter table public.bookings add column if not exists promo_code text;

-- Discount for an active promo code (0 if unknown/inactive).
create or replace function public.promo_discount(p_code text)
returns int
language sql
security definer
set search_path = public
stable
as $$
  select coalesce((
    select discount_som from public.promo_codes
    where upper(code) = upper(trim(p_code)) and is_active
    limit 1), 0);
$$;
grant execute on function public.promo_discount(text) to anon, authenticated;

-- Recompute client aggregates: total_spent (net of discounts) + bonus balance.
create or replace function public.refresh_client_stats(p_client uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pct int;
begin
  select cashback_pct into v_pct from public.app_settings where id = 1;
  v_pct := coalesce(v_pct, 0);

  update public.clients c set
    visits_count = coalesce((
      select count(*) from public.bookings b
      where b.client_id = p_client and b.status = 'completed'), 0),
    total_spent = coalesce((
      select sum(s.price_som + public.evening_surcharge(b.start_time) - b.discount_som)
      from public.bookings b
      join public.services s on s.id = b.service_id
      where b.client_id = p_client and b.status = 'completed'), 0),
    bonus_som = coalesce((
      select sum(floor(
        (s.price_som + public.evening_surcharge(b.start_time) - b.discount_som) * v_pct / 100.0))
      from public.bookings b
      join public.services s on s.id = b.service_id
      where b.client_id = p_client and b.status = 'completed'), 0),
    last_visit = (
      select max(b.booking_date) from public.bookings b
      where b.client_id = p_client and b.status = 'completed')
  where c.id = p_client;
end;
$$;

-- create_booking now accepts an optional promo code and records the discount.
create or replace function public.create_booking(
  p_service_id uuid,
  p_date       date,
  p_start      time,
  p_name       text,
  p_phone      text,
  p_comment    text default null,
  p_promo      text default null
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
  v_discount    int;
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
  from public.schedule_exceptions where date = p_date;

  if v_exc_type = 'day_off' then
    raise exception 'closed' using errcode = 'restrict_violation';
  elsif v_exc_type = 'custom_hours' then
    v_break_start := null; v_break_end := null;
  else
    v_isodow := extract(isodow from p_date);
    select is_day_off, start_time, end_time, break_start, break_end
      into v_day_off, v_open, v_close, v_break_start, v_break_end
    from public.schedules where weekday = v_isodow;
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

  if auth.uid() is not null then
    update public.users set contact_phone = p_phone where id = auth.uid();
  end if;

  v_discount := public.promo_discount(p_promo);

  begin
    insert into public.bookings (client_id, service_id, booking_date, start_time,
                                 end_time, comment, status, user_id, discount_som, promo_code)
    values (v_client, p_service_id, p_date, p_start, v_end, p_comment, 'pending', auth.uid(),
            v_discount, case when v_discount > 0 then upper(trim(p_promo)) else null end)
    returning id into v_booking;
  exception
    when exclusion_violation then
      raise exception 'slot_taken' using errcode = 'unique_violation';
  end;

  return v_booking;
end;
$$;

grant execute on function public.create_booking(uuid, date, time, text, text, text, text)
  to anon, authenticated;

-- The signed-in client's own bonus balance + penalties (clients table is
-- staff-only under RLS, so expose just these two numbers via a definer RPC).
create or replace function public.my_bonuses()
returns table (bonus_som int, penalty_som int)
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(c.bonus_som, 0), coalesce(c.penalty_som, 0)
  from public.clients c
  where c.id = (
    select b.client_id from public.bookings b
    where b.user_id = auth.uid()
    order by b.created_at desc limit 1
  );
$$;
grant execute on function public.my_bonuses() to authenticated;
