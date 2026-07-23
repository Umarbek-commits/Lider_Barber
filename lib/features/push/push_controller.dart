import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../core/supabase_client.dart';
import 'push_impl_stub.dart' if (dart.library.js_interop) 'push_impl_web.dart' as impl;
import 'push_types.dart';

final pushControllerProvider = Provider<PushController>((_) => const PushController());

/// Requests notification permission, subscribes the browser, and stores the
/// subscription in Supabase so the server can send this device notifications.
class PushController {
  const PushController();

  bool get available => Env.hasSupabase && Env.hasPush;

  Future<PushStatus> enable() async {
    if (!available) return PushStatus.unsupported;
    final res = await impl.subscribeToPush(Env.vapidPublicKey);
    if (res.status != PushStatus.granted) return res.status;
    try {
      await supabase.rpc('save_push_subscription', params: {
        'p_endpoint': res.endpoint,
        'p_p256dh': res.p256dh,
        'p_auth': res.auth,
      });
      return PushStatus.granted;
    } catch (_) {
      return PushStatus.error;
    }
  }
}
