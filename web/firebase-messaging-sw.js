// Firebase Cloud Messaging Service Worker for background notifications on Web
importScripts('https://www.gstatic.com/firebasejs/10.14.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyA61OIlEI03D0C_RNNTh_FWYU9PwfdXiFI",
  authDomain: "acadenocrm-b727a.firebaseapp.com",
  projectId: "acadenocrm-b727a",
  storageBucket: "acadenocrm-b727a.firebasestorage.app",
  messagingSenderId: "244810173048",
  appId: "1:244810173048:web:cb663e4c195d0d1d92fb8d",
  measurementId: "G-EQGNR4HM72"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification?.title || payload.data?.title || 'ACADENO CRM';
  const notificationOptions = {
    body: payload.notification?.body || payload.data?.body || 'You have a new update.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {}
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

