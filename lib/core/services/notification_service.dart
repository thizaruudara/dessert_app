import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

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
  static const MethodChannel _notifChannel = MethodChannel('com.institute.dessert/notifications');

  /// Displays a native system push notification in status bar & lock screen
  static Future<void> showNotification({
    required String title,
    required String body,
    int? id,
  }) async {
    try {
      await _notifChannel.invokeMethod('showNotification', {
        'title': title,
        'body': body,
        'id': id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
    } catch (e) {
      debugPrint('Error showing native system notification: $e');
    }
  }

  Future<void> initialize({bool isAdmin = false}) async {
    try {
      // 1. Explicitly Request POST_NOTIFICATIONS Permission on Android 13+
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      }

      // 2. Request FCM Permission
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      // 3. Configure iOS Foreground Presentation Options
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional ||
          defaultTargetPlatform == TargetPlatform.android) {
        debugPrint('🔔 FCM Notification Permission Active: ${settings.authorizationStatus}');

        // 4. Fetch Token & Sync with Current User
        final token = await _fcm.getToken();
        if (token != null) {
          debugPrint('🔑 FCM Token: $token');
          await saveTokenToDatabase(token);
        }

        // 5. Listen for token refreshes
        _fcm.onTokenRefresh.listen((newToken) async {
          await saveTokenToDatabase(newToken);
        });

        // 6. Subscribe to Institute Topics (Broadcast Channels)
        await _fcm.subscribeToTopic('paper_sessions');
        await _fcm.subscribeToTopic('announcements');

        // 7. Handle Foreground Messages -> Trigger Native Heads-up & Lock Screen Notification
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('📩 Foreground Push Notification Received: ${message.notification?.title} - ${message.notification?.body}');
          final title = message.notification?.title ?? message.data['title'] ?? 'EduPeak Alert';
          final body = message.notification?.body ?? message.data['message'] ?? message.data['body'] ?? '';
          if (title.isNotEmpty && body.isNotEmpty) {
            showNotification(title: title, body: body, id: message.messageId.hashCode);
          }
        });

        // 8. Handle Background / Opened Notifications
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
