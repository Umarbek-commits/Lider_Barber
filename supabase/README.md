# Supabase — Lider Barber

Схема БД, RLS и публичные RPC для приложения.

## Как применить

В **Supabase Studio → SQL Editor** выполни файлы из `migrations/` по порядку:

1. `0001_schema.sql` — таблицы + защита от двойной записи (EXCLUDE-констрейнт)
2. `0002_rls.sql` — Row Level Security
3. `0003_functions.sql` — триггеры и публичные функции `get_busy_ranges`, `create_booking`
4. `0004_seed.sql` — услуги и рабочий график

Либо через CLI: `supabase db push` (если проект связан).

## Модель безопасности

- **Анонимный посетитель** может: читать `services` (активные), `schedules`,
  `schedule_exceptions`; вызывать RPC `get_busy_ranges(date)` и
  `create_booking(...)`. **Не может** напрямую читать `bookings` / `clients` —
  чтобы не утекали имена, телефоны и комментарии.
- **Админ** (роль `admin` в `public.users`) имеет полный доступ ко всем таблицам.
- В приложение попадает **только** `anon` / publishable ключ. Секретный
  (`service_role`) ключ здесь не используется — он понадобится позже для
  Edge Functions уведомлений (Этап 4) и живёт только на сервере.

## Назначить первого админа

После первого входа по номеру телефона узнай свой `id` и подними роль:

```sql
update public.users set role = 'admin' where phone = '+996XXXXXXXXX';
```
