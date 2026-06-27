import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'main.dart'; // Import main to access the global scaffoldMessengerKey

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    debugPrint("Handling background message: ${message.messageId}");
  } catch (e) {
    debugPrint("FCM background handler error: $e");
  }
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Request notifications permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('User granted permission: ${settings.authorizationStatus}');

      // 2. Set up background messaging handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Set up foreground message listeners
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          
          // Show foreground notification as a nice SnackBar using the global key
          scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.notification!.title ?? 'StudyMate Notification',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(message.notification!.body ?? ''),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF4F46E5), // Indigo Theme Color
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });

      // 4. Set up message click handler when app is in background but open
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('A new onMessageOpenedApp event was published!');
      });

      _isInitialized = true;

      // 5. Setup Token Refresh Listener
      _messaging.onTokenRefresh.listen((newToken) {
        _saveTokenToDatabase(newToken);
      });

      // 6. Attempt to register/update current user token
      await syncToken();
    } catch (e) {
      debugPrint("Error initializing FCM: $e");
    }
  }

  /// Sync/Save the current FCM token to the current user's profile in Firestore
  static Future<void> syncToken() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? token;
    try {
      if (kIsWeb) {
        // VAPID key is required for Web Push notifications.
        // Users can replace this with their actual VAPID key from Firebase Console -> Cloud Messaging.
        token = await _messaging.getToken(
          vapidKey: 'BOfaO-2E1N4FqZ6W_c_T5l-8_g-m1VnWqPjVn4w-1_placeholder_vapid_key',
        );
      } else {
        token = await _messaging.getToken();
      }
    } catch (e) {
      debugPrint("FCM get token error (with vapidKey): $e. Trying default getToken...");
      try {
        token = await _messaging.getToken();
      } catch (err) {
        debugPrint("FCM default getToken error: $err");
      }
    }

    if (token != null) {
      await _saveTokenToDatabase(token);
    }
  }

  static Future<void> _saveTokenToDatabase(String token) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      debugPrint("FCM Token saved successfully for user ${user.uid}: $token");
    } catch (e) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint("FCM Token merged successfully for user ${user.uid}: $token");
      } catch (err) {
        debugPrint("Error saving FCM Token to database: $err");
      }
    }
  }
}
