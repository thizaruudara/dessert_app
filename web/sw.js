// EduPeak Service Worker - PWA & Web Push Notification Handler
const CACHE_NAME = 'edupeak-pwa-v1.7.2';
const OFFLINE_URLS = [
  './',
  './index.html',
  './manifest.json',
  './css/app.css',
  './css/gatekeeper.css',
  './css/camera-scanner.css',
  './css/exam-room.css',
  './css/features.css',
  './js/firebase-config.js',
  './js/pwa-gatekeeper.js',
  './js/notification-service.js',
  './js/camera-service.js',
  './js/auth-service.js',
  './js/db-service.js',
  './js/app.js',
  './js/app.bundle.js',
  './icons/icon.svg',
  './icons/apple-touch-icon.png'
];

// Install Event - Pre-cache App Shell & force activation immediately
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[SW] Pre-caching offline app shell');
      return cache.addAll(OFFLINE_URLS).catch(err => {
        console.warn('[SW] Cache addAll warning (some assets may load on demand):', err);
      });
    })
  );
  self.skipWaiting();
});

// Activate Event - Clean old caches & claim clients immediately
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME) {
            console.log('[SW] Removing old cache:', key);
            return caches.delete(key);
          }
        })
      );
    })
  );
  return self.clients.claim();
});

// Fetch Event - Network-first for code/HTML to ensure immediate updates; fallback to cache
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Allow Firestore and Firebase Auth / Storage to go straight to network
  if (url.origin.includes('firebase') || url.origin.includes('googleapis') || url.origin.includes('gstatic')) {
    return;
  }

  // Network-First for core application files so updates load immediately without cache staleness
  if (
    event.request.mode === 'navigate' ||
    url.pathname.endsWith('.html') ||
    url.pathname.endsWith('.js') ||
    url.pathname.endsWith('.css')
  ) {
    event.respondWith(
      fetch(event.request)
        .then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            const copy = networkResponse.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
          }
          return networkResponse;
        })
        .catch(() => {
          return caches.match(event.request).then((cached) => {
            if (cached) return cached;
            if (event.request.mode === 'navigate') {
              return caches.match('./index.html');
            }
          });
        })
    );
    return;
  }

  // Cache-first / stale-while-revalidate for static assets (icons, media)
  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      if (cachedResponse) return cachedResponse;
      return fetch(event.request).then((networkResponse) => {
        if (networkResponse && networkResponse.status === 200) {
          const copy = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
        }
        return networkResponse;
      });
    })
  );
});

// ── Web Push Notification Event Listener (iOS 16.4+ / Android / Desktop) ──
// Receives notifications even when the web app / browser tab is completely closed.
self.addEventListener('push', (event) => {
  console.log('[SW] Push notification event received');
  let data = {
    title: 'EduPeak Physics Institute',
    body: 'You have a new update from your Physics tutor!',
    icon: './icons/icon-192.png',
    badge: './icons/icon-192.png',
    image: null,
    data: { url: './index.html' }
  };

  if (event.data) {
    try {
      const payload = event.data.json();
      const notif = payload.notification || {};
      const dataPayload = payload.data || {};
      const webpush = payload.webpush?.notification || {};

      data.title = notif.title || webpush.title || dataPayload.title || payload.title || data.title;
      data.body = notif.body || webpush.body || dataPayload.body || dataPayload.message || payload.body || data.body;
      data.icon = notif.icon || webpush.icon || dataPayload.icon || payload.icon || data.icon;
      data.image = notif.image || webpush.image || dataPayload.image || payload.image || null;

      const targetUrl = dataPayload.route || dataPayload.url || payload.fcmOptions?.link || notif.click_action || './index.html';
      data.data = { url: targetUrl, ...dataPayload };
    } catch (e) {
      const text = event.data.text();
      if (text) data.body = text;
    }
  }

  const options = {
    body: data.body,
    icon: data.icon,
    badge: data.badge,
    image: data.image || undefined,
    vibrate: [200, 100, 200, 100, 200],
    data: data.data,
    tag: data.data?.tag || `edupeak-${Date.now()}`,
    renotify: true,
    requireInteraction: true,
    actions: [
      { action: 'open_app', title: 'Open EduPeak' },
      { action: 'dismiss', title: 'Dismiss' }
    ]
  };

  event.waitUntil(
    self.registration.showNotification(data.title, options)
  );
});

// ── Notification Click Event Listener ──
// Re-opens and focuses the app when user taps the notification while webapp was closed.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  if (event.action === 'dismiss') {
    return;
  }

  const targetUrl = event.notification.data?.url || './index.html';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // If a window is already open, focus it and notify client
      for (const client of clientList) {
        if ('focus' in client) {
          try {
            client.postMessage({
              type: 'NOTIFICATION_CLICKED',
              data: event.notification.data
            });
          } catch (_) {}
          return client.focus();
        }
      }
      // If the app was completely closed, open a new window to the target URL
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});
