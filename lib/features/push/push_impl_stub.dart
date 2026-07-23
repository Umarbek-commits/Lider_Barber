import 'push_types.dart';

/// Non-web platforms don't support browser push.
Future<PushSubResult> subscribeToPush(String vapidPublicKey) async =>
    const PushSubResult(PushStatus.unsupported);
