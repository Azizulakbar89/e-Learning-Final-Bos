// Firebase Cloud Messaging Service Worker for Web
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAunBSEelbFQfKJLpKnAQWS3zVITwn6mWg",
  authDomain: "e-learning-b183d.firebaseapp.com",
  projectId: "e-learning-b183d",
  storageBucket: "e-learning-b183d.firebasestorage.app",
  messagingSenderId: "625661482133",
  appId: "1:625661482133:web:bc159000c1f9dcf608379c"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);
  const notificationTitle = payload.notification ? payload.notification.title : 'E-Learning Notifikasi';
  const notificationOptions = {
    body: payload.notification ? payload.notification.body : '',
    icon: '/favicon.png',
    data: payload.data || {}
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
