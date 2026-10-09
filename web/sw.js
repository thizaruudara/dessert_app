// EduPeak Service Worker - PWA & Web Push Notification Handler
const CACHE_NAME = 'edupeak-pwa-v1.5.0';
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
self.addEventListener('push', (event) => {
  console.log('[SW] Push notification event received');
  let data = {
    title: 'EduPeak Physics Institute',
    body: 'You have a new update from your Physics tutor!',
    icon: './icons/icon-192.png',
    badge: './icons/icon-192.png',
    data: { url: './index.html' }
  };

  if (event.data) {
    try {
      const payload = event.data.json();
      data.title = payload.title || payload.notification?.title || data.title;
      data.body = payload.body || payload.notification?.body || data.body;
      if (payload.icon) data.icon = payload.icon;
      if (payload.data) data.data = payload.data;
    } catch (e) {
      data.body = event.data.text() || data.body;
    }
  }

  const options = {
    body: data.body,
    icon: data.icon,
    badge: data.badge,
    vibrate: [100, 50, 100],
    data: data.data,
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
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  if (event.action === 'dismiss') {
    return;
  }

  const targetUrl = event.notification.data?.url || './index.html';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // If a window is already open, focus it
      for (const client of clientList) {
        if (client.url.includes('index.html') && 'focus' in client) {
          return client.focus();
        }
      }
      // Otherwise open a new window
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});
