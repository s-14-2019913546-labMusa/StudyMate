importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

// Initialize Firebase in the service worker with web credentials
firebase.initializeApp({
  apiKey: "AIzaSyDZQ1v4TFTmCQCAKGzwuXLsncP5MbkbdwE",
  authDomain: "studymate-5ab8c.firebaseapp.com",
  projectId: "studymate-5ab8c",
  storageBucket: "studymate-5ab8c.firebasestorage.app",
  messagingSenderId: "36423587341",
  appId: "1:36423587341:web:e626f1f08b7b8cb2596744"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification ? payload.notification.title : 'StudyMate Reminder';
  const notificationOptions = {
    body: payload.notification ? payload.notification.body : 'You have a new alert.',
    icon: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
