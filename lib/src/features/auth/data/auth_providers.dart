// lib/src/features/auth/data/auth_providers.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_repository.dart'; // <-- Import the repository

// Provides the instance of FirebaseAuth
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

// --- START ADDITION ---
// Provides the instance of AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider)); // Pass FirebaseAuth instance
});
// --- END ADDITION ---

// Provides a stream of the user's authentication state (User? or null)
final authStateChangesProvider = StreamProvider<User?>((ref) {
  // Use the repository's auth instance if preferred, or keep direct access
  return ref.watch(firebaseAuthProvider).authStateChanges();
  // Alternatively: return ref.watch(authRepositoryProvider).authStateChanges;
});