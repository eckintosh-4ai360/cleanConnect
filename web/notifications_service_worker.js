// Flutter Local Notifications Web - Service Worker
// Required by the flutter_local_notifications_web package.
// This service worker handles push notification events for the web platform.

'use strict';

// Install event: cache assets if needed
self.addEventListener('install', function (event) {
  self.skipWaiting();
});

// Activate event: claim clients immediately
self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

// Push event: display notification when a push message is received
self.addEventListener('push', function (event) {
  if (!event.data) return;

  let data = {};
  try {
    data = event.data.json();
  } catch (e) {
    data = { title: event.data.text() };
  }

  const title = data.title || 'Notification';
  const options = {
    body: data.body || '',
    icon: data.icon || '/icons/Icon-192.png',
    badge: data.badge || '/icons/Icon-192.png',
    data: data.data || {},
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

// Notification click event: focus or open the app window
self.addEventListener('notificationclick', function (event) {
  event.notification.close();

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (clientList) {
      for (let i = 0; i < clientList.length; i++) {
        const client = clientList[i];
        if ('focus' in client) return client.focus();
      }
      if (self.clients.openWindow) return self.clients.openWindow('/');
    })
  );
});
