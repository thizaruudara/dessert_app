import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background FCM message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initialize({bool isAdmin = false}) async {
    try {
      // 1. Request Permission
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('🔔 FCM Notification Permission Granted: ${settings.authorizationStatus}');

        // 2. Fetch Token & Sync with Current User
        final token = await _fcm.getToken();
        if (token != null) {
          debugPrint('🔑 FCM Token: $token');
          await saveTokenToDatabase(token);
        }

        // 3. Listen for token refreshes
        _fcm.onTokenRefresh.listen((newToken) async {
          await saveTokenToDatabase(newToken);
        });

        // 4. Subscribe to Institute Topics (Free Broadcast Channel)
        await _fcm.subscribeToTopic('paper_sessions');
        await _fcm.subscribeToTopic('announcements');

        // 5. Handle Foreground Messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('📩 Foreground Push Notification: ${message.notification?.title} - ${message.notification?.body}');
        });

        // 6. Handle Background / Opened Notifications
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('🚀 App opened via Notification: ${message.data}');
        });
      }
    } catch (e) {
      debugPrint('⚠️ Notification initialization error: $e');
    }
  }

  Future<void> saveTokenToDatabase(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error saving FCM token: $e');
      }
    }
  }
}
