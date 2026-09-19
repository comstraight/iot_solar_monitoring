import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(
    // FIXED: Wrapped your screen in a MaterialApp instead of calling DashboardScreen twice
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(currentPercentage: 20, cardCount: 1),
    ),
  );
}
