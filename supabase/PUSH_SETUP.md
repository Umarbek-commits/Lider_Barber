# Push-уведомления — настройка (одноразовая)

Что уже готово в коде:
- таблица подписок и функции (`0011_push.sql`), напоминания-cron (`0012_push_reminders.sql`);
- Edge Function `supabase/functions/send-push`;
- в приложении — кнопка 🔔, service worker и подписка.

Публичный VAPID-ключ уже зашит в приложение. Осталось выполнить шаги ниже.

---

## 1. Применить SQL
Supabase → **SQL Editor** → выполнить весь `supabase/apply_all.sql`
(там появятся `push_subscriptions`, `push_config`, cron и т.д.).

## 2. Задеплоить Edge Function `send-push`
Проще через **Supabase CLI**:
```bash
# один раз:
npm i -g supabase
supabase login
supabase link --project-ref pyobqtshoihrncdlqkjj

# задеплоить функцию:
supabase functions deploy send-push --no-verify-jwt
```
> `--no-verify-jwt` — функция сама проверяет секрет `x-push-secret`.

## 3. Секреты функции
Supabase → **Edge Functions → send-push → Secrets** (или CLI `supabase secrets set`):
- `VAPID_PUBLIC_KEY` = `BDTowFRfRCDCzpX-ItRhnbBRq4Ij7BGr5mmW4BT0m-46rcaHIq48k0PMYwUjWueZXtC1kxCZdSJ_4XmKDJyk3X4`
- `VAPID_PRIVATE_KEY` = **твой приватный ключ** (из `npx web-push generate-vapid-keys`)
- `VAPID_SUBJECT` = `mailto:admin@liderbarber.kg`
- `PUSH_SECRET` = придумай длинную случайную строку (пример: `lb_push_9f3k2a7Qx__замени__`)

`SUPABASE_URL` и `SUPABASE_SERVICE_ROLE_KEY` подставляются автоматически.

## 4. Прописать URL функции и секрет в БД (для напоминаний-cron)
SQL Editor:
```sql
insert into public.push_config (id, function_url, push_secret)
values (1,
  'https://pyobqtshoihrncdlqkjj.functions.supabase.co/send-push',
  '<тот же PUSH_SECRET, что в шаге 3>')
on conflict (id) do update
  set function_url = excluded.function_url, push_secret = excluded.push_secret;
```

## 5. Вебхуки на новую запись и новость
Supabase → **Database → Webhooks → Create a new hook** (сделать 2 штуки):

**a) Новая запись → барберу**
- Table: `bookings`, Events: `Insert`
- Type: **HTTP Request**, Method `POST`
- URL: `https://pyobqtshoihrncdlqkjj.functions.supabase.co/send-push`
- HTTP Headers: `x-push-secret: <PUSH_SECRET>`

**b) Новость → всем клиентам**
- Table: `news`, Events: `Insert`
- URL и заголовок — те же.

Функция сама разберёт payload вебхука (по таблице) и разошлёт нужным.

---

## Готово
- Клиент/барбер жмёт 🔔 в приложении → разрешает уведомления.
- Новая запись → push барберу; новость → push клиентам; за 1 день и 1 час до записи → push клиенту.

### Заметки
- **iPhone**: работает только если сайт «Добавлен на главный экран» (PWA), iOS 16.4+.
- Проверить cron: `select * from cron.job;` — должна быть строка `lider-reminders`.
- Проверить подписки: `select count(*) from push_subscriptions;`
