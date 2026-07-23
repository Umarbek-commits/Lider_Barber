enum PushStatus { granted, denied, unsupported, error }

class PushSubResult {
  const PushSubResult(this.status, {this.endpoint, this.p256dh, this.auth, this.message});
  final PushStatus status;
  final String? endpoint;
  final String? p256dh;
  final String? auth;
  final String? message;
}
