import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caption_hook/src/features/auth/data/auth_providers.dart';
import 'package:caption_hook/src/features/auth/presentation/login_screen.dart';
import 'package:caption_hook/src/features/upload/presentation/video_upload_screen.dart';
// Removed SplashScreen import if not used elsewhere

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          return const VideoUploadScreen();
        } else {
          return const LoginScreen();
        }
      },
      loading: () {
        // --- Revert or Simplify This ---
        // Option 1: Back to simple indicator
         return const Scaffold(body: Center(child: CircularProgressIndicator()));
        // Option 2: Or even just an empty container
        // return const Scaffold(body: SizedBox.shrink());
        // --- END Revert ---
      },
      error: (error, stackTrace) {
        print('Auth State Error: $error');
        return Scaffold(
          body: Center(
            child: Text('Something went wrong!\n$error'),
          ),
        );
      },
    );
  }
}