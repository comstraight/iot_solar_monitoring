import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/profile_overview_screen.dart';
import 'services/fcm_service.dart';
import 'services/top_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize FCM globally at app startup
  await FcmService.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ProfileData(),
      child: MaterialApp(
        navigatorKey:
            navigatorKey, // CRITICAL: Required for showGlobalTopNotification overlay
        debugShowCheckedModeBanner: false,
        home: const SlickLoginScreen(),
      ),
    ),
  );
}
