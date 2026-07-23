-- Lider Barber — scheduled push reminders (Stage 10).
-- A cron job (every 5 min) sends "1 day before" and "1 hour before" reminders
-- to the client for their upcoming bookings, via the send-push Edge Function.
--
-- New-booking (staff) and new-news (clients) notifications are wired separately
-- as Database Webhooks in the Supabase dashboard (see supabase/PUSH_SETUP.md).

create extension if not exists pg_net;
create extension if not exists pg_cron;

alter table public.bookings add column if not exists reminded_1d boolean not null default false;
alter table public.bookings add column if not exists reminded_1h boolean not null default false;

-- Where to call the function + the shared secret. Admin fills one row (see setup).
create table if not exists public.push_config (
  id           int primary key default 1 check (id = 1),
  function_url text not null,
  push_secret  text not null
);
alter table public.push_config enable row level security; -- locked; only definer funcs read

-- Local wall-clock of a booking as a timestamptz (shop is in Asia/Bishkek, UTC+6).
create or replace function public.booking_at(p_date date, p_start time)
returns timestamptz
language sql
immutable
as $$
  select (p_date + p_start) at time zone 'Asia/Bishkek';
$$;

create or replace function public.send_due_reminders()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  cfg record;
  b   record;
begin
  select * into cfg from public.push_config where id = 1;
  if not found then return; end if;

  -- ~1 day before
  for b in
    select bk.id, bk.user_id, bk.start_time, s.name as service
    from public.bookings bk
    join public.services s on s.id = bk.service_id
    where bk.status in ('pending', 'confirmed')
      and bk.user_id is not null
      and not bk.reminded_1d
      and public.booking_at(bk.booking_date, bk.start_time)
            between now() + interval '23 hours' and now() + interval '25 hours'
  loop
    perform net.http_post(
      url := cfg.function_url,
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', cfg.push_secret),
      body := jsonb_build_object(
        'audience', 'user',
        'userIds', jsonb_build_array(b.user_id),
        'title', 'Напоминание о записи',
        'body', b.service || ' завтра в ' || to_char(b.start_time, 'HH24:MI'),
        'url', '/#/account')
    );
    update public.bookings set reminded_1d = true where id = b.id;
  end loop;

  -- ~1 hour before
  for b in
    select bk.id, bk.user_id, bk.start_time, s.name as service
    from public.bookings bk
    join public.services s on s.id = bk.service_id
    where bk.status in ('pending', 'confirmed')
      and bk.user_id is not null
      and not bk.reminded_1h
      and public.booking_at(bk.booking_date, bk.start_time)
            between now() + interval '50 minutes' and now() + interval '70 minutes'
  loop
    perform net.http_post(
      url := cfg.function_url,
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', cfg.push_secret),
      body := jsonb_build_object(
        'audience', 'user',
        'userIds', jsonb_build_array(b.user_id),
        'title', 'Скоро запись',
        'body', b.service || ' через час, в ' || to_char(b.start_time, 'HH24:MI'),
        'url', '/#/account')
    );
    update public.bookings set reminded_1h = true where id = b.id;
  end loop;
end;
$$;

-- Run every 5 minutes.
select cron.unschedule('lider-reminders') where exists (
  select 1 from cron.job where jobname = 'lider-reminders');
select cron.schedule('lider-reminders', '*/5 * * * *', $$select public.send_due_reminders();$$);
