import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Handles FCM token registration, topic subscriptions, and foreground messages.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> initialize({required bool isAdmin}) async {
    // Request permission (iOS)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get and store FCM token
    final token = await _fcm.getToken();
    if (token != null) {
      await _saveToken(token);
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen(_saveToken);

    // Subscribe to appropriate topic
    if (isAdmin) {
      await _fcm.subscribeToTopic('admins');
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle message tap (background / terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
  }

  Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({'fcmToken': token});
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground FCM: ${message.notification?.title}');
    // TODO: Show in-app snackbar / overlay notification
  }

  void _handleMessageTap(RemoteMessage message) {
    final route = message.data['route'];
    debugPrint('Notification tapped → route: $route');
    // Navigation is handled via the router in main.dart
    // You can use a global navigator key to push here if needed
  }

  Future<void> unsubscribe() async {
    await _fcm.unsubscribeFromTopic('admins');
    await _fcm.deleteToken();
  }
}

/// Top-level background message handler (must be a top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background FCM: ${message.notification?.title}');
}
