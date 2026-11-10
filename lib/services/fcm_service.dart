import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'top_notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized when background message handler runs in isolated background VM
  await Firebase.initializeApp();
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // 1. Set background messaging handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Enable foreground notification presentation options for heads-up alert banners
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Request user notification permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // 4. Subscribe to global broadcast topic
      await _messaging.subscribeToTopic('all_users');

      // 5. Save device FCM token to current logged-in user document
      await updateUserFcmToken();

      // 6. Listen for token refreshes
      _messaging.onTokenRefresh.listen((newToken) {
        _saveTokenToFirestore(newToken);
      });

      // 7. Handle foreground push notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final data = message.data;

        if (notification != null) {
          final String title = notification.title ?? 'Notice';
          final String messageBody = notification.body ?? '';
          final String type = data['type']?.toString().toLowerCase() ?? 'info';
          final String? panelId = data['panelId'];

          showGlobalTopNotification(
            title: title,
            message: messageBody,
            type: type,
            panelId: panelId,
          );
        }
      });

      // 8. Handle notification tap when app is opened from background state
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final panelId = message.data['panelId'];
        if (panelId != null && panelId.isNotEmpty) {
          navigatorKey.currentState?.pushNamed(
            '/monitoring',
            arguments: panelId,
          );
        }
      });
    }
  }

  static Future<void> updateUserFcmToken() async {
    try {
      String? token = await _messaging.getToken();

      print("----------------------------------");
      print("DEVICE FCM TOKEN: $token");
      print("----------------------------------");

      if (token != null) {
        await _saveTokenToFirestore(token);
      }
    } catch (_) {}
  }

  static Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
