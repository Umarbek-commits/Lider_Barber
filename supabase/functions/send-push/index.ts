// Lider Barber — Web Push sender (Supabase Edge Function).
//
// Delivers browser push notifications. Called by:
//  * Database Webhooks on INSERT into `bookings` (notify staff) and `news`
//    (notify all clients);
//  * the reminder cron (explicit { audience:'user', userIds, title, body }).
//
// Required function secrets (Supabase → Edge Functions → send-push → Secrets):
//   VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT (mailto:you@example.com),
//   PUSH_SECRET (any long random string; callers must send it as x-push-secret).
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically.

import webpush from 'npm:web-push@3.6.7';
import { createClient } from 'npm:@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

webpush.setVapidDetails(
  Deno.env.get('VAPID_SUBJECT') ?? 'mailto:admin@liderbarber.kg',
  Deno.env.get('VAPID_PUBLIC_KEY')!,
  Deno.env.get('VAPID_PRIVATE_KEY')!,
);

type Payload = {
  audience?: 'staff' | 'clients' | 'user';
  userIds?: string[];
  title: string;
  body: string;
  url?: string;
};

async function send(p: Payload) {
  const { data: targets, error } = await supabase.rpc('push_targets', {
    p_audience: p.audience ?? 'user',
    p_user_ids: p.userIds ?? null,
  });
  if (error) throw error;

  const message = JSON.stringify({
    title: p.title,
    body: p.body,
    url: p.url ?? '/',
  });

  let sent = 0;
  for (const t of targets ?? []) {
    try {
      await webpush.sendNotification(
        { endpoint: t.endpoint, keys: { p256dh: t.p256dh, auth: t.auth } },
        message,
      );
      sent++;
    } catch (e) {
      const status = (e as { statusCode?: number }).statusCode;
      if (status === 404 || status === 410) {
        await supabase.rpc('delete_push_subscription', { p_endpoint: t.endpoint });
      }
    }
  }
  return sent;
}

Deno.serve(async (req) => {
  // Shared-secret auth (webhooks + cron send this header).
  if (req.headers.get('x-push-secret') !== Deno.env.get('PUSH_SECRET')) {
    return new Response('forbidden', { status: 403 });
  }

  let sent = 0;
  try {
    const body = await req.json();

    // Database Webhook payload?
    if (body?.type === 'INSERT' && body?.table && body?.record) {
      const r = body.record;
      if (body.table === 'bookings') {
        sent = await send({
          audience: 'staff',
          title: 'Новая запись',
          body: `Запись на ${r.booking_date} в ${String(r.start_time).slice(0, 5)}`,
          url: '/#/admin',
        });
      } else if (body.table === 'news' && r.is_active !== false) {
        sent = await send({
          audience: 'clients',
          title: 'Lider Barber',
          body: r.text ?? 'Новое объявление',
          url: '/',
        });
      }
    } else {
      // Direct call (reminders / generic).
      sent = await send(body as Payload);
    }

    return Response.json({ ok: true, sent });
  } catch (e) {
    return Response.json({ ok: false, error: String(e) }, { status: 500 });
  }
});
