// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'src/constants/app_theme.dart';
// Import SplashScreen
import 'src/features/splash/splash_screen.dart'; // Assuming this is the path

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ensure Firebase is initialized before running the app
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caption Hook',
      theme: appTheme,
      // --- CHANGE THIS ---
      home: const SplashScreen(), // Start with SplashScreen
      // --- END CHANGE ---
      debugShowCheckedModeBanner: false,
    );
  }
}