// EduPeak Notification Service
// Handles iOS 16.4+ Web Push, FCM Token Registration & System Push Notifications
import { 
  app,
  db, 
  doc, 
  updateDoc, 
  arrayUnion, 
  serverTimestamp,
  getMessaging,
  getToken,
  isSupported
} from './firebase-config.js';

// Official Firebase Web Push standard uncompressed P-256 public key (65 bytes / 87 chars base64url)
export const VAPID_PUBLIC_KEY = 'BDOU99-h67HcA6JeFXHbSNMu7e2yNNu3RzoMj8TM4W88jITfq7ZmPvIM1Iv-4_l2LxQcYwhqby2xGpWwzjfAnG4';

export class NotificationService {
  constructor() {
    this.swRegistration = null;
    this.fcmToken = null;
    this.pushSubscription = null;
    this.isSupported = 'Notification' in window && 'serviceWorker' in navigator && 'PushManager' in window;
    this.permission = this.isSupported ? Notification.permission : 'denied';
  }

  async init(user = null) {
    try {
      if ('serviceWorker' in navigator && window.isSecureContext) {
        this.swRegistration = await navigator.serviceWorker.register('./sw.js', { scope: './' });
        await navigator.serviceWorker.ready;
      }
      if (!this.isSupported || !this.swRegistration) {
        console.warn('[Notification] Push notifications not supported on this browser/platform');
        return;
      }
      console.log('[Notification] Service Worker Ready for Push Notifications');

      if (this.permission === 'granted' && user) {
        await this.syncTokenWithUser(user);
      }
    } catch (err) {
      console.error('[Notification] Error initializing notification service:', err);
    }
  }

  async requestPermission(user = null) {
    if (!('Notification' in window)) {
      if (/iPad|iPhone|iPod/.test(navigator.userAgent)) {
        alert('Push notifications require iOS 16.4+. Tap the Share icon and select "Add to Home Screen" to enable notifications.');
      } else {
        alert('Push notifications are not supported on this browser.');
      }
      return false;
    }

    try {
      const permission = await Notification.requestPermission();
      this.permission = permission;

      if (permission === 'granted') {
        let token = null;
        if (user) {
          token = await this.syncTokenWithUser(user);
        }

        this.showLocalNotification('Notifications Active! 🔔', {
          body: 'You will receive real-time alerts for live exams, homework reviews, and announcements even when this app is closed.',
          tag: 'welcome-notification'
        });

        return true;
      } else {
        console.warn('[Notification] Permission denied or dismissed:', permission);
        return false;
      }
    } catch (err) {
      console.error('[Notification] Error requesting notification permission:', err);
      return false;
    }
  }

  async syncTokenWithUser(user) {
    if (!user || !user.uid) return null;

    try {
      let fcmToken = null;
      let subscription = null;

      // 1. Ensure service worker is active
      if (!this.swRegistration && 'serviceWorker' in navigator) {
        this.swRegistration = await navigator.serviceWorker.register('./sw.js', { scope: './' });
        await navigator.serviceWorker.ready;
      }

      // 2. Try obtaining a native PushSubscription with the verified 65-byte VAPID key
      if (this.swRegistration && this.swRegistration.pushManager) {
        try {
          subscription = await this.swRegistration.pushManager.getSubscription();
          if (!subscription) {
            subscription = await this.swRegistration.pushManager.subscribe({
              userVisibleOnly: true,
              applicationServerKey: this.urlBase64ToUint8Array(VAPID_PUBLIC_KEY)
            });
          }
          this.pushSubscription = subscription;
          console.log('[Notification] Native push subscription active:', subscription.endpoint);
        } catch (subErr) {
          console.warn('[Notification] pushManager subscribe notice:', subErr.message);
        }
      }

      // 3. Try obtaining official Firebase Cloud Messaging (FCM) registration token
      try {
        const supported = await isSupported().catch(() => false);
        if (supported && this.swRegistration) {
          const messaging = getMessaging(app);
          fcmToken = await getToken(messaging, {
            serviceWorkerRegistration: this.swRegistration,
            vapidKey: VAPID_PUBLIC_KEY
          });
          if (fcmToken) {
            console.log('[Notification] Firebase FCM token acquired successfully');
          }
        }
      } catch (fcmErr) {
        console.warn('[Notification] Firebase getToken notice:', fcmErr.message);
      }

      // 4. Fallback: if FCM token was not generated, use subscription serialized endpoint
      const primaryToken = fcmToken || (subscription ? JSON.stringify(subscription) : null);
      if (!primaryToken) {
        console.warn('[Notification] Could not generate push token for user');
        return null;
      }

      this.fcmToken = primaryToken;

      // 5. Persist to Firestore user document (both fcmToken and fcmTokens for backend parity)
      const userRef = doc(db, 'users', user.uid);
      const updatePayload = {
        fcmToken: primaryToken,
        fcmTokens: arrayUnion(primaryToken),
        lastTokenUpdate: serverTimestamp()
      };
      if (subscription) {
        updatePayload.webPushSubscription = JSON.stringify(subscription);
      }

      await updateDoc(userRef, updatePayload).catch(err => {
        console.warn('[Notification] Non-critical: Could not write token to user doc:', err);
      });

      try {
        localStorage.setItem('edupeak_fcm_token', primaryToken);
      } catch (_) {}

      console.log('[Notification] User push token registered successfully in Firestore');
      return primaryToken;
    } catch (e) {
      console.warn('[Notification] Token sync error:', e);
      return null;
    }
  }

  // Display a system level push notification via Service Worker
  showLocalNotification(title, options = {}) {
    if (!this.isSupported || Notification.permission !== 'granted') {
      console.log('[Push Notification Not Granted / Unsupported]', title, options.body);
      return;
    }

    const defaultOptions = {
      body: '',
      icon: './icons/icon-192.png',
      badge: './icons/icon-192.png',
      vibrate: [200, 100, 200],
      tag: 'edupeak-alert',
      renotify: true,
      requireInteraction: true,
      data: { url: './index.html' }
    };

    const finalOptions = { ...defaultOptions, ...options };

    if (this.swRegistration && this.swRegistration.showNotification) {
      this.swRegistration.showNotification(title, finalOptions).catch(() => {
        try { new Notification(title, finalOptions); } catch (_) {}
      });
    } else {
      try { new Notification(title, finalOptions); } catch (_) {}
    }
  }

  // Toast notification helpers matching Flutter SnackBar
  showInAppToast(message, type = 'info') {
    console.log('[In-App Toast Suppressed]', message, type);
    return null;
  }

  showLocalToast(message, type = 'info') {
    console.log('[Local Toast Suppressed]', message, type);
    return null;
  }

  showInAppBanner(title, message, type = 'info') {
    const existing = document.getElementById('in-app-toast-container');
    if (existing) existing.remove();
    console.log('[Notification]', title, message);
  }

  playChime() {
    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(587.33, ctx.currentTime); // D5
      osc.frequency.exponentialRampToValueAtTime(880, ctx.currentTime + 0.15); // A5
      gain.gain.setValueAtTime(0.12, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.3);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();
      osc.stop(ctx.currentTime + 0.3);
    } catch (_) {}
  }

  notifyPaperHintPublished(hintTitle, batch = 'All Batches') {
    this.playChime();
    this.showInAppBanner(
      '💡 New Paper Hint Published!',
      `"${hintTitle}" (${batch}) hints are now live. Review formulas & guidance!`,
      'info'
    );
    this.showLocalNotification('💡 New Paper Hint Published!', {
      body: `"${hintTitle}" (${batch}) hints and guidance are now available for your exam preparation.`,
      tag: 'paper-hint-alert'
    });
  }

  urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }
}

export const notificationService = new NotificationService();
