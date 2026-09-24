import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // ADDED: Required for Firebase initialization
import 'screens/login_screen.dart';

// MODIFIED: Made main() async to initialize Firebase before loading the UI
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ADDED: Guarantees plugin bindings are ready
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); // ADDED: Connects Flutter app to Firebase project

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SlickLoginScreen(),
    ),
  );
}
