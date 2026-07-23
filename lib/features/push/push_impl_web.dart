import 'dart:convert';
import 'dart:js_interop';

import 'push_types.dart';

@JS('liderEnablePush')
external JSPromise<JSString?> _liderEnablePush(JSString vapidPublicKey);

/// Requests permission, registers the push SW, subscribes, and returns the
/// subscription details (parsed from the JS helper's JSON result).
Future<PushSubResult> subscribeToPush(String vapidPublicKey) async {
  try {
    final result = await _liderEnablePush(vapidPublicKey.toJS).toDart;
    final str = result?.toDart;
    if (str == null || str.isEmpty) {
      return const PushSubResult(PushStatus.error, message: 'no result');
    }
    switch (str) {
      case 'denied':
        return const PushSubResult(PushStatus.denied);
      case 'unsupported':
        return const PushSubResult(PushStatus.unsupported);
    }
    if (str.startsWith('error:')) {
      return PushSubResult(PushStatus.error, message: str.substring(6));
    }
    final json = jsonDecode(str) as Map<String, dynamic>;
    final keys = (json['keys'] as Map).cast<String, dynamic>();
    return PushSubResult(
      PushStatus.granted,
      endpoint: json['endpoint'] as String,
      p256dh: keys['p256dh'] as String,
      auth: keys['auth'] as String,
    );
  } catch (e) {
    return PushSubResult(PushStatus.error, message: '$e');
  }
}
