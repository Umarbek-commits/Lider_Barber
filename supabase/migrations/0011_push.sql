-- Lider Barber — Web Push subscriptions (Stage 10).
-- Each browser/device that opts in stores its push subscription here. The
-- send-push Edge Function (service role) reads these to deliver notifications.

create table if not exists public.push_subscriptions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  endpoint   text not null unique,
  p256dh     text not null,
  auth       text not null,
  created_at timestamptz not null default now()
);

create index if not exists push_subs_user_idx on public.push_subscriptions (user_id);

alter table public.push_subscriptions enable row level security;

-- A user manages only their own subscriptions. The Edge Function uses the
-- service role, which bypasses RLS to read everyone's for sending.
drop policy if exists push_self_all on public.push_subscriptions;
create policy push_self_all on public.push_subscriptions
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Upsert helper: save/refresh the current user's subscription by endpoint.
create or replace function public.save_push_subscription(
  p_endpoint text,
  p_p256dh   text,
  p_auth     text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = 'insufficient_privilege';
  end if;
  insert into public.push_subscriptions (user_id, endpoint, p256dh, auth)
  values (auth.uid(), p_endpoint, p_p256dh, p_auth)
  on conflict (endpoint)
    do update set user_id = auth.uid(), p256dh = excluded.p256dh, auth = excluded.auth;
end;
$$;

grant execute on function public.save_push_subscription(text, text, text) to authenticated;

-- Resolve push targets for an audience. Called by the send-push Edge Function
-- (service role). 'staff' = admin+barber, 'clients' = clients, 'user' = ids.
create or replace function public.push_targets(p_audience text, p_user_ids uuid[] default null)
returns table (endpoint text, p256dh text, auth text)
language sql
security definer
set search_path = public
stable
as $$
  select s.endpoint, s.p256dh, s.auth
  from public.push_subscriptions s
  join public.users u on u.id = s.user_id
  where (
    (p_audience = 'staff'   and u.role in ('admin', 'barber')) or
    (p_audience = 'clients' and u.role = 'client') or
    (p_audience = 'user'    and s.user_id = any(p_user_ids))
  );
$$;

revoke all on function public.push_targets(text, uuid[]) from public;
grant execute on function public.push_targets(text, uuid[]) to service_role;

-- Remove a dead subscription (called by the function on 404/410).
create or replace function public.delete_push_subscription(p_endpoint text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.push_subscriptions where endpoint = p_endpoint;
$$;

revoke all on function public.delete_push_subscription(text) from public;
grant execute on function public.delete_push_subscription(text) to service_role;
