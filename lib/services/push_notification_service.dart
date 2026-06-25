import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

// Top-level background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Make sure Firebase is initialized for background processing if needed.
  print('Handling a background message: ${message.messageId}');
}

class PushNotificationService {
  static final _firebaseMessaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      // 1. Initialize Firebase (gracefully fails if not configured yet on Native side)
      await Firebase.initializeApp();
      
      // 2. Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Init local notifications for foreground alerts
      const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
      const initSettings = InitializationSettings(android: androidInit);
      await _localNotifications.initialize(initSettings);

      // Create Android high importance notification channel
      const channel = AndroidNotificationChannel(
        'high_importance_channel',
        'Notificaciones de Pakiip',
        description: 'Canal para alertas de pedidos en tiempo real.',
        importance: Importance.max,
        playSound: true,
      );

      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
      }

      // 4. Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final android = message.notification?.android;
        if (notification != null && android != null && !kIsWeb) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: '@mipmap/launcher_icon',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
              ),
            ),
            payload: jsonEncode(message.data),
          );
        }
      });

      print('PushNotificationService initialized successfully.');
    } catch (e) {
      print('PushNotificationService initialization failed or skipped: $e');
    }
  }

  static Future<void> requestPermissions() async {
    try {
      // Request permission for push notifications
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      print('User granted permission: ${settings.authorizationStatus}');
    } catch (e) {
      print('Error requesting push notification permissions: $e');
    }
  }

  static Future<void> registerFcmToken() async {
    try {
      if (!await ApiService.isLoggedIn()) {
        print('Skipping FCM token registration: user not logged in.');
        return;
      }

      // Try to get token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        await ApiService.postAuth('/auth/fcm-token', {'token': token});
        print('FCM Token registered successfully with backend.');
      } else {
        print('FCM Token was null.');
      }
    } catch (e) {
      print('Error registering FCM token: $e');
    }
  }
}
