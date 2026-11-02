import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const AndroidNotificationChannel _highImportanceChannel = AndroidNotificationChannel(
  'jamui_services_channel',
  'Jamui Services Alerts',
  description: 'हाई प्रायोरिटी पुश नोटिफिकेशन एवं सेवा अनुरोध अलर्ट',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 [Provider FCM Background] Message received: ${message.messageId}');
  
  final notification = message.notification;
  final title = notification?.title ?? message.data['title'] ?? 'JAMUI SERVICE';
  final body = notification?.body ?? message.data['message'] ?? message.data['body'] ?? '';

  if (title.isNotEmpty || body.isNotEmpty) {
    await _localNotificationsPlugin.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _highImportanceChannel.id,
          _highImportanceChannel.name,
          channelDescription: _highImportanceChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
      ),
    );
  }
}

class AppNotificationService {
  AppNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _isInitialized = false;

  /// Initialize FCM Push Notifications, high-importance notification channel & background handlers
  static Future<void> initialize({required String userType}) async {
    if (_isInitialized) return;

    try {
      if (!kIsWeb) {
        // 1. Initialize local notifications plugin
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidSettings);
        await _localNotificationsPlugin.initialize(initSettings);

        // 2. Create High Importance Notification Channel on Android device
        await _localNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_highImportanceChannel);

        // 3. Register background message handler
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // 4. Set Foreground Notification Presentation Options
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // 5. Request user permission for notifications
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      debugPrint('🔔 [FCM] Provider notification authorization status: ${settings.authorizationStatus}');

      // 6. Handle foreground notifications with local popup banner
      if (!kIsWeb) {
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('🔔 [Provider FCM Foreground] Received: ${message.notification?.title}');
          final notification = message.notification;
          final title = notification?.title ?? message.data['title'] ?? 'JAMUI SERVICE';
          final body = notification?.body ?? message.data['message'] ?? message.data['body'] ?? '';

          _localNotificationsPlugin.show(
            message.hashCode,
            title,
            body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _highImportanceChannel.id,
                _highImportanceChannel.name,
                channelDescription: _highImportanceChannel.description,
                importance: Importance.max,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
                playSound: true,
                enableVibration: true,
              ),
            ),
          );
        });
      }

      // 7. Subscribe to FCM Topics for broadcast alerts (native only)
      if (!kIsWeb) {
        try {
          await _messaging.subscribeToTopic('all');
          await _messaging.subscribeToTopic(userType == 'provider' ? 'all_providers' : 'all_customers');
          debugPrint('🔔 [FCM] Provider subscribed to broadcast topics: all, ${userType == 'provider' ? 'all_providers' : 'all_customers'}');
        } catch (e) {
          debugPrint('⚠️ [FCM] Provider topic subscription error: $e');
        }
      }

      // 8. Real-time Firestore live notification listener for immediate alerts
      if (!kIsWeb) {
        _listenToFirestoreNotifications(userType: userType);
      }

      // 9. Synchronize FCM Token with Firestore
      try {
        await syncDeviceToken(userType: userType);
      } catch (e) {
        debugPrint('⚠️ [FCM] Device token sync skipped on web: $e');
      }

      // 10. Listen for token refreshes
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔔 [FCM] Provider token refreshed: $newToken');
        await _saveTokenToFirestore(newToken, userType);
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('⚠️ [FCM] Provider Notification Init Error: $e');
    }
  }

  static final DateTime _serviceStartTime = DateTime.now();
  static StreamSubscription<QuerySnapshot>? _firestoreNotificationSubscription;

  /// Realtime stream listener on Firestore to display immediate popup notification for provider.
  /// Optimized with orderBy('createdAt', descending: true) and limit(10) to prevent
  /// reading hundreds of historical notifications on initial launch while catching new arrivals instantly.
  static void _listenToFirestoreNotifications({required String userType}) {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      // Cancel previous subscription on auth state change to prevent memory leaks
      _firestoreNotificationSubscription?.cancel();
      _firestoreNotificationSubscription = null;

      if (user == null) return;

      final targetAudienceTag = userType == 'provider' ? 'all_providers' : 'all_customers';

      _firestoreNotificationSubscription = FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', whereIn: [user.uid, 'all', targetAudienceTag])
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots()
          .listen((snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data == null) continue;

            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            // Only trigger popup for new notifications created after service initialized
            if (createdAt != null && createdAt.isAfter(_serviceStartTime.subtract(const Duration(seconds: 5)))) {
              final title = (data['title'] as String?) ?? 'JAMUI SERVICE';
              final message = (data['message'] as String?) ?? '';

              _localNotificationsPlugin.show(
                change.doc.id.hashCode,
                title,
                message,
                NotificationDetails(
                  android: AndroidNotificationDetails(
                    _highImportanceChannel.id,
                    _highImportanceChannel.name,
                    channelDescription: _highImportanceChannel.description,
                    importance: Importance.max,
                    priority: Priority.high,
                    icon: '@mipmap/ic_launcher',
                    playSound: true,
                    enableVibration: true,
                  ),
                ),
              );
            }
          }
        }
      }, onError: (e) {
        debugPrint('⚠️ [FCM] Firestore notification listener error: $e');
      });
    });
  }

  /// Cancels active notification listeners during app tear-down or logout
  static void dispose() {
    _firestoreNotificationSubscription?.cancel();
    _firestoreNotificationSubscription = null;
  }

  /// Retrieve device FCM token and persist to Firestore under provider document
  static Future<void> syncDeviceToken({required String userType}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('🔔 [FCM] Provider Device Token: $token');
        await _saveTokenToFirestore(token, userType);
      }
    } catch (e) {
      debugPrint('⚠️ [FCM] Error getting provider token: $e');
    }
  }

  static Future<void> _saveTokenToFirestore(String token, String userType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final collection = userType == 'provider' ? 'providers' : 'users';
    try {
      await FirebaseFirestore.instance.collection(collection).doc(user.uid).set({
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ [FCM] Failed to save token to $collection/${user.uid}: $e');
    }
  }

  /// Create in-app notification record in Firestore
  static Future<void> sendInAppNotification({
    required String recipientId,
    required String title,
    required String message,
    String type = 'general',
    String? leadId,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': recipientId,
        'title': title,
        'message': message,
        'type': type,
        'leadId': leadId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ [Notification] Failed to create notification: $e');
    }
  }
}
