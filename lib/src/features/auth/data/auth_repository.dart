// lib/src/features/auth/data/auth_repository.dart

import 'package:firebase_auth/firebase_auth.dart';

// Custom exception for auth errors
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}


class AuthRepository {
  final FirebaseAuth _firebaseAuth;

  AuthRepository(this._firebaseAuth);

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // Provide more user-friendly messages based on error code
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw AuthException('Invalid email or password.');
      } else if (e.code == 'invalid-email') {
         throw AuthException('Invalid email format.');
      } else {
        // Handle other potential errors
        throw AuthException('An unexpected error occurred. Please try again.');
      }
    } catch (e) {
      // Catch-all for other unexpected errors
      throw AuthException('An unexpected error occurred.');
    }
  }

  // Create user with email and password
  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw AuthException('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        throw AuthException('An account already exists for that email.');
      } else if (e.code == 'invalid-email') {
         throw AuthException('Invalid email format.');
      }else {
        throw AuthException('An unexpected error occurred during sign up.');
      }
    } catch (e) {
       throw AuthException('An unexpected error occurred.');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
       await _firebaseAuth.signOut();
    } on FirebaseAuthException catch(e) {
         print("Error signing out: ${e.code}");
         // Optionally rethrow or handle specific sign-out errors
         throw AuthException('Failed to sign out.');
    }
  }

  // Get current user (can be null)
  User? get currentUser => _firebaseAuth.currentUser;

  // Stream of authentication state changes (already exposed via authStateChangesProvider)
  // Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
}