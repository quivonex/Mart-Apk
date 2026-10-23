importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyBzVvj5kzMJ5fkHb_MIYb1sH7ocoRt3200",
   authDomain: "qnxmart.firebaseapp.com",
   projectId: "qnxmart",
   storageBucket: "qnxmart.firebasestorage.app",
   messagingSenderId: "165464716243",
   appId: "1:165464716243:web:95d4ff34eff740acd87526",
   measurementId: "G-Q686F5DSCY"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('Received background message:', payload);

  const notificationTitle = payload.notification?.title || 'QNXmart Notification';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new notification',
    icon: '/favicon.ico',
    data: payload.data,
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});