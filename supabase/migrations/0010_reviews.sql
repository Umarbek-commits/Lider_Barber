-- Lider Barber — client reviews & 5-star ratings (Stage 9).
-- After a visit is completed the client can rate the master (1–5) and leave a
-- review. The admin sees the rating/review per visit and the master's average.

alter table public.bookings
  add column if not exists rating smallint check (rating between 1 and 5);
alter table public.bookings
  add column if not exists review text;

-- Client leaves a review for their own completed booking.
create or replace function public.leave_review(
  p_booking_id uuid,
  p_rating     smallint,
  p_review     text default null
)
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
  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception 'bad_rating' using errcode = 'check_violation';
  end if;

  select user_id, status into v_owner, v_status
  from public.bookings where id = p_booking_id;

  if not found then
    raise exception 'not_found' using errcode = 'no_data_found';
  end if;
  if v_owner is distinct from auth.uid() then
    raise exception 'forbidden' using errcode = 'insufficient_privilege';
  end if;
  if v_status <> 'completed' then
    raise exception 'not_completed' using errcode = 'check_violation';
  end if;

  update public.bookings
    set rating = p_rating, review = nullif(trim(p_review), '')
  where id = p_booking_id;
end;
$$;

grant execute on function public.leave_review(uuid, smallint, text) to authenticated;
