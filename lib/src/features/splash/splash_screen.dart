import 'dart:async'; // Import async
import 'package:flutter/material.dart';
import 'package:caption_hook/src/features/auth/presentation/auth_gate.dart'; // Import AuthGate

// Change to StatefulWidget
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // Wait for a minimum duration (e.g., 2-3 seconds)
    // AND ensure Firebase is definitely ready (already done in main.dart now)
    await Future.delayed(const Duration(seconds: 3)); // Adjust duration as needed

    if (mounted) { // Check if the widget is still mounted before navigating
      // Replace the splash screen with AuthGate
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthGate()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The UI remains the same as before
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png', // Use your correct path
              width: 150,
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}