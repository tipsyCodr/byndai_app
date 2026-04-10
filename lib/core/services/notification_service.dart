import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:gridcard/core/services/auth_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/deep_link_service.dart';
import 'package:gridcard/features/chat/connections_page.dart';
import 'package:gridcard/features/business_event/business_event_page.dart';
import 'package:gridcard/features/profile/profile_page.dart';
import 'package:gridcard/features/home/SubscriptionPlans.dart';
import 'package:gridcard/routes/route_names.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      // 1. Request permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('🔔 User granted notification permission');
      }

      // 2. Initialize Local Notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings();
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('🔔 Notification tapped: ${details.payload}');
          final payload = details.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              final decoded = jsonDecode(payload);
              if (decoded is Map<String, dynamic>) {
                _handleNotificationNavigation(decoded);
              } else if (decoded is Map) {
                _handleNotificationNavigation(Map<String, dynamic>.from(decoded));
              }
            } catch (e) {
              debugPrint('🔔 Failed to decode local notification payload: $e');
              _openPendingConnectionsPage();
            }
          } else {
            _openPendingConnectionsPage();
          }
        },
      );

      // 3. Create Android Notification Channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 4. Set foreground notification presentation options
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. Setup Listeners
      _setupMessageHandlers();
      
      // 6. Get initial token with timeout
      debugPrint('🔔 Fetching FCM Token...');
      String? token = await _messaging.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      if (token != null) {
        debugPrint('🔔 FCM Token: $token');
      }

      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔔 FCM Token Refreshed: $newToken');
        AuthService.updateFCMToken(newToken);
      });
    } catch (e) {
      debugPrint('🔔 Error initializing notifications: $e');
      // Continue execution even if notifications fail
    }
  }

  static void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 Foreground message received: ${message.notification?.title}');
      _showLocalNotification(message);
      _showForegroundCustomPrompt(message.data);
    });

    // Background messages (when app is in background but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 Message clicked! (Background)');
      _handleNotificationNavigation(message.data);
    });

    // Cold-start notification tap
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('🔔 Message clicked! (Terminated launch)');
        _handleNotificationNavigation(message.data);
      }
    });
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final data = message.data;
    final notification = message.notification;

    // Supports both normal notification payload and custom/data-only payload.
    final title = (data['title'] ?? data['notification_title'])?.toString() ??
        notification?.title;
    final body = (data['body'] ??
            data['message'] ??
            data['notification_body'] ??
            data['description'])
        ?.toString() ??
        notification?.body;

    if ((title == null || title.trim().isEmpty) &&
        (body == null || body.trim().isEmpty)) {
      debugPrint('🔔 Skipping local notification: no visible title/body');
      return;
    }

    final notifId = int.tryParse(
            (data['id'] ?? data['notification_id'] ?? message.messageId ?? '')
                .toString()
                .replaceAll(RegExp(r'[^0-9]'), '')) ??
        DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _localNotifications.show(
      id: notifId,
      title: title ?? 'Notification',
      body: body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(data),
    );
  }

  static void _handleNotificationNavigation(Map<String, dynamic> data) {
    final lowerType = (data['type'] ?? data['notification_type'] ?? data['event'])
        ?.toString()
        .toLowerCase();
    final lowerTitle = (data['title'] ?? '').toString().toLowerCase();
    final lowerBody = (data['body'] ?? data['message'] ?? '').toString().toLowerCase();

    if (lowerType == 'custom') {
      _navigateCustomScreen(data);
      return;
    }

    final isConnectionRequest =
        (lowerType != null &&
                (lowerType.contains('connection') || lowerType.contains('request'))) ||
            lowerTitle.contains('connection request') ||
            lowerBody.contains('connection request');

    if (isConnectionRequest) {
      final senderId = _extractSenderId(data);
      debugPrint('🔔 Connection request notification tap. senderId=$senderId');
      _openPendingConnectionsPage();
      return;
    }

    // Default fallback
    _openPendingConnectionsPage();
  }

  static void _showForegroundCustomPrompt(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().toLowerCase();
    if (type != 'custom') return;

    final context = DeepLinkService().navigatorKey.currentContext;
    if (context == null) return;

    final title = (data['title'] ?? data['notification_title'] ?? 'New Notification')
        .toString();
    final body =
        (data['message'] ?? data['body'] ?? data['description'] ?? '').toString();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(body.isEmpty ? title : '$title: $body'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _navigateCustomScreen(data),
        ),
      ),
    );
  }

  static void _navigateCustomScreen(Map<String, dynamic> data) {
    final navigator = DeepLinkService().navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('🔔 Navigator not ready for custom notification navigation');
      return;
    }

    final screen = (data['screen'] ??
            data['target_screen'] ??
            data['page'] ??
            data['route'] ??
            'home')
        .toString()
        .toLowerCase()
        .trim();
    final itemId =
        (data['item_id'] ?? data['target_id'] ?? data['id'] ?? '').toString();
    final parsedId = int.tryParse(itemId);

    debugPrint('🔔 Custom notification navigation: screen=$screen item_id=$itemId');

    switch (screen) {
      case 'event_details':
        navigator.push(
          MaterialPageRoute(
            builder: (_) => BusinessEventPage(openEventId: parsedId),
          ),
        );
        break;
      case 'profile':
        navigator.push(
          MaterialPageRoute(
            builder: (_) => ProfilePage(userId: parsedId),
          ),
        );
        break;
      case 'subscription':
        navigator.push(
          MaterialPageRoute(
            builder: (_) => const SubscriptionPlans(),
          ),
        );
        break;
      default:
        navigator.pushNamed(RouteNames.home);
    }
  }

  static int? _extractSenderId(Map<String, dynamic> data) {
    final raw = data['sender_id'] ??
        data['from_user_id'] ??
        data['user_id'] ??
        data['receiver_id'];
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  static void _openPendingConnectionsPage() {
    final navigator = DeepLinkService().navigatorKey.currentState;
    final context = DeepLinkService().navigatorKey.currentContext;
    if (navigator == null || context == null) {
      debugPrint('🔔 Navigator not ready for notification navigation');
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => const ConnectionsPage(initialTabIndex: 1),
      ),
    );
  }

  // Static method for background handler (must be top-level or static)
  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint("🔔 Handling a background message: ${message.messageId}");
  }
}
