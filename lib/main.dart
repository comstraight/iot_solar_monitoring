import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/profile_overview_screen.dart'; // Adjust path if ProfileData is in a different directory

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ProfileData(),
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SlickLoginScreen(),
      ),
    ),
  );
}
