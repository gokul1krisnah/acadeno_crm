// Firebase Cloud Messaging & Firestore Service Worker for background notifications on Web
importScripts('https://www.gstatic.com/firebasejs/10.14.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.0/firebase-messaging-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.0/firebase-firestore-compat.js');

const firebaseConfig = {
  apiKey: "AIzaSyA61OIlEI03D0C_RNNTh_FWYU9PwfdXiFI",
  authDomain: "acadenocrm-b727a.firebaseapp.com",
  projectId: "acadenocrm-b727a",
  storageBucket: "acadenocrm-b727a.firebasestorage.app",
  messagingSenderId: "244810173048",
  appId: "1:244810173048:web:cb663e4c195d0d1d92fb8d",
  measurementId: "G-EQGNR4HM72"
};

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();
const db = firebase.firestore();

// 1. Standard FCM Background Handler (runs when FCM sends a message)
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received FCM background push', payload);
  const notificationTitle = payload.notification?.title || payload.data?.title || 'ACADENO CRM';
  const notificationOptions = {
    body: payload.notification?.body || payload.data?.body || 'You have new assigned leads.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {},
    requireInteraction: true
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// 2. Direct Firestore Background Listener (NO BLAZE PLAN REQUIRED)
// Listens directly to real-time assigned leads and shows the native OS tray notification
// even when the user is browsing other tabs or websites!
let unsubscribeAlerts = null;
let currentListenUid = null;

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'START_BACKGROUND_SYNC') {
    const uid = event.data.uid;
    if (!uid || uid === currentListenUid) return;
    currentListenUid = uid;

    if (unsubscribeAlerts) {
      unsubscribeAlerts();
    }

    console.log('[firebase-messaging-sw.js] Started real-time background listener for user:', uid);

    let isInitialLoad = true;
    unsubscribeAlerts = db.collection('alerts')
      .where('recipientUid', '==', uid)
      .onSnapshot((snapshot) => {
        if (isInitialLoad) {
          isInitialLoad = false;
          return;
        }

        snapshot.docChanges().forEach((change) => {
          if (change.type === 'added') {
            const data = change.doc.data();
            const title = data.title || '📞 New Leads Assigned';
            const body = data.subtitle || 'Assigned by Admin. Tap to open Today\'s Calls.';

            self.registration.showNotification(title, {
              body: body,
              icon: '/icons/Icon-192.png',
              badge: '/icons/Icon-192.png',
              tag: change.doc.id,
              requireInteraction: true,
              data: {
                tabIndex: '0',
                alertId: change.doc.id
              }
            });
          }
        });
      }, (err) => {
        console.log('[firebase-messaging-sw.js] Background listener error:', err);
      });
  }
});

// 3. Handle Notification Click (brings window into focus)
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});
