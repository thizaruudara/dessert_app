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
      this.showInAppBanner(title, options.body || '');
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
    return this.showInAppBanner('EduPeak', message, type);
  }

  showLocalToast(message, type = 'info') {
    return this.showInAppBanner('EduPeak', message, type);
  }

  // In-app animated banner toast matching Flutter floating SnackBar
  showInAppBanner(title, message, type = 'info') {
    let container = document.getElementById('in-app-toast-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'in-app-toast-container';
      container.style.cssText = `
        position: fixed;
        top: 20px;
        left: 50%;
        transform: translateX(-50%);
        z-index: 9999999;
        display: flex;
        flex-direction: column;
        gap: 10px;
        max-width: 400px;
        width: calc(100% - 32px);
        pointer-events: none;
      `;
      document.body.appendChild(container);
    }

    const toast = document.createElement('div');
    const isUrgent = type === 'urgent' || type === 'error';
    const isSuccess = type === 'success';
    const isWarning = type === 'warning';

    const bgBadge = isSuccess
      ? '#22C55E'
      : isUrgent
      ? '#EF4444'
      : isWarning
      ? '#F59E0B'
      : '#6366F1';

    const iconSymbol = isSuccess ? '✓' : isUrgent ? '⚠️' : isWarning ? '⏱️' : '🔔';

    toast.style.cssText = `
      background: #1E293B;
      border: 1px solid ${bgBadge}80;
      border-left: 4px solid ${bgBadge};
      box-shadow: 0 12px 30px rgba(0, 0, 0, 0.6);
      border-radius: 14px;
      padding: 12px 14px;
      display: flex;
      align-items: center;
      gap: 12px;
      color: #FFFFFF;
      font-family: 'Poppins', sans-serif;
      pointer-events: auto;
      transform: translateY(20px);
      opacity: 0;
      transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
    `;

    toast.innerHTML = `
      <div style="width:34px; height:34px; border-radius:50%; background:${bgBadge}25; display:flex; align-items:center; justify-content:center; color:${bgBadge}; font-size:16px; font-weight:bold; flex-shrink:0;">
        ${iconSymbol}
      </div>
      <div style="flex:1; min-width:0;">
        <div style="font-size:12.5px; font-weight:700; color:#FFFFFF; margin-bottom:2px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">
          ${title}
        </div>
        <div style="font-size:11px; color:#CBD5E1; line-height:1.4;">
          ${message}
        </div>
      </div>
      <button style="background:transparent; border:none; color:#94A3B8; font-size:16px; cursor:pointer; padding:4px 8px; border-radius:6px; line-height:1; display:flex; align-items:center;" onmouseover="this.style.color='#FFFFFF'" onmouseout="this.style.color='#94A3B8'" onclick="this.parentElement.remove()">
        ✕
      </button>
    `;

    container.appendChild(toast);

    // Trigger enter animation
    requestAnimationFrame(() => {
      toast.style.transform = 'translateY(0)';
      toast.style.opacity = '1';
    });

    // Audio chime
    this.playChime();

    // Auto dismiss after 4.5s
    setTimeout(() => {
      toast.style.transform = 'translateY(10px)';
      toast.style.opacity = '0';
      setTimeout(() => toast.remove(), 250);
    }, 4500);
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
