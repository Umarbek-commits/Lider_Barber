// Lider Barber — browser push subscription helper, called from Dart.
// Returns a JSON string of the subscription, 'denied', 'unsupported', or an
// error string prefixed with 'error:'.
window.liderEnablePush = async function (vapidPublicKey) {
  try {
    if (!('serviceWorker' in navigator) || !('PushManager' in window) || !('Notification' in window)) {
      return 'unsupported';
    }
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') return 'denied';

    const reg = await navigator.serviceWorker.register('/push/sw.js', { scope: '/push/' });
    // Wait until the worker is active before subscribing.
    await new Promise(function (resolve) {
      if (reg.active) return resolve();
      const sw = reg.installing || reg.waiting;
      if (!sw) return resolve();
      sw.addEventListener('statechange', function () {
        if (reg.active) resolve();
      });
    });

    let sub = await reg.pushManager.getSubscription();
    if (!sub) {
      sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(vapidPublicKey),
      });
    }
    return JSON.stringify(sub.toJSON());
  } catch (e) {
    return 'error:' + (e && e.message ? e.message : e);
  }
};

function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const raw = atob(base64);
  const output = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; ++i) output[i] = raw.charCodeAt(i);
  return output;
}
