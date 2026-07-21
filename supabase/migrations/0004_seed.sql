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
