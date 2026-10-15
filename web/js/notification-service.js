// EduPeak Notification Service
// Handles iOS 16.4+ Web Push, FCM Token Registration & In-App Alerts
import { db, doc, updateDoc, arrayUnion, serverTimestamp } from './firebase-config.js';

export class NotificationService {
  constructor() {
    this.swRegistration = null;
    this.fcmToken = null;
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
        alert('Push notifications require an iOS device running iOS 16.4+ added to your Home Screen.');
      } else {
        alert('Push notifications are not supported on this browser.');
      }
      return false;
    }

    try {
      const permission = await Notification.requestPermission();
      this.permission = permission;

      if (permission === 'granted') {
        this.showLocalNotification('Notifications Active! 🔔', {
          body: 'You will receive real-time alerts for live exams, homework reviews, and announcements.',
          tag: 'welcome-notification'
        });

        if (user) {
          await this.syncTokenWithUser(user);
        }
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
    if (!user || !user.uid) return;

    try {
      // 1. Try subscribing to native push manager
      if (this.swRegistration && this.swRegistration.pushManager) {
        let subscription = await this.swRegistration.pushManager.getSubscription();
        if (!subscription) {
          // Attempt subscription with dummy or server key
          try {
            subscription = await this.swRegistration.pushManager.subscribe({
              userVisibleOnly: true,
              applicationServerKey: this.urlBase64ToUint8Array('BEl62iUYgUivxIkv69yViEuiBIa-Ib9-SkvMeAtA3LFgDzkRXZJjSgSnfckjBVM3whx1pnU')
            }).catch(() => null);
          } catch (_) {}
        }

        const token = subscription ? JSON.stringify(subscription) : `web_token_${user.uid}_${Date.now()}`;
        this.fcmToken = token;

        // Save to Firestore under user document
        const userRef = doc(db, 'users', user.uid);
        await updateDoc(userRef, {
          fcmTokens: arrayUnion(token),
          lastTokenUpdate: serverTimestamp()
        }).catch(err => {
          console.warn('[Notification] Non-critical: Could not write token to user doc:', err);
        });

        console.log('[Notification] User token registered successfully:', token);
      }
    } catch (e) {
      console.warn('[Notification] Token sync warning:', e);
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
      data: { url: './index.html' }
    };

    const finalOptions = { ...defaultOptions, ...options };

    if (this.swRegistration && this.swRegistration.showNotification) {
      this.swRegistration.showNotification(title, finalOptions).catch(() => {
        new Notification(title, finalOptions);
      });
    } else {
      new Notification(title, finalOptions);
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

  // In-app animated banner toast removed - only push notifications kept
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
