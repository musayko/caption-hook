// lib/src/features/auth/presentation/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'registration_screen.dart';
import 'package:caption_hook/src/features/auth/data/auth_providers.dart'; // Import auth providers
import 'package:caption_hook/src/features/auth/data/auth_repository.dart'; // Import auth repository

// --- State Notifier ---

// Simple state class for now, just tracks loading
@immutable // Make state immutable
class LoginScreenState {
  const LoginScreenState({this.isLoading = false, this.error});
  final bool isLoading;
  final String? error; // To hold potential error messages

  LoginScreenState copyWith({bool? isLoading, String? error}) {
    return LoginScreenState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error, // Allow clearing error by passing null
    );
  }
}

// The controller that holds the state and business logic
class LoginScreenController extends StateNotifier<LoginScreenState> {
  // --- START CHANGE ---
  final AuthRepository _authRepository;
  LoginScreenController(this._authRepository) : super(const LoginScreenState());
  // --- END CHANGE ---


  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // --- START CHANGE ---
      // Remove simulation delay
      print('Attempting login with Email: $email'); // Don't log password
      // Call the repository method
      await _authRepository.signInWithEmailAndPassword(email, password);
      // --- END CHANGE ---

      // Auth state change will be handled by AuthGate automatically
      // No need to explicitly set isLoading to false if successful,
      // as the widget might unmount upon successful login via AuthGate.
      // We *could* set it here, but it might cause a brief flicker.
      // Let's clear loading state explicitly for now.
      state = state.copyWith(isLoading: false);

    } on AuthException catch (e) { // Catch our custom exception
        print('Login failed: $e');
        state = state.copyWith(isLoading: false, error: e.message); // Use message from AuthException
    } catch (e) { // Catch any other unexpected errors
      print('Unexpected Login error: $e');
      state = state.copyWith(isLoading: false, error: 'An unexpected error occurred.');
    }
  }
}

// --- Provider ---

// Make the controller available to the UI
final loginScreenControllerProvider =
    StateNotifierProvider.autoDispose<LoginScreenController, LoginScreenState>((ref) { // Use autoDispose
  // --- START CHANGE ---
  // Inject the repository dependency
  return LoginScreenController(ref.watch(authRepositoryProvider));
  // --- END CHANGE ---
});


// --- UI Widget ---

class LoginScreen extends ConsumerStatefulWidget { // Changed to ConsumerStatefulWidget
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> { // Corresponding State class
  final _formKey = GlobalKey<FormState>(); // Key to manage the Form
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true; // State for password visibility

  @override
  void dispose() {
    // Dispose controllers when the widget is removed
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Method to trigger login
  Future<void> _submitLogin() async {
    // Validate the form first
    if (_formKey.currentState!.validate()) {
      // Read email and password from controllers
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Access the controller via ref and call the login method
      await ref.read(loginScreenControllerProvider.notifier).login(email, password);

      // Note: Navigation logic (if login is successful) will be handled
      // by the "Auth Gate" listening to the actual Firebase auth state,
      // not typically directly here after the login call.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access theme data
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // Listen to the state of the controller
    final loginState = ref.watch(loginScreenControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form( // Wrap content in a Form widget
              key: _formKey, // Assign the key
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Welcome Back!',
                    style: textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please login to your account',
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Display error message if any
                  if (loginState.error != null) ...[
                     Text(
                       'Login Failed: ${loginState.error}', // Improve error presentation later
                       style: textTheme.labelSmall?.copyWith(color: colorScheme.error),
                       textAlign: TextAlign.center,
                     ),
                     const SizedBox(height: 10),
                  ],

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) { // Basic validation
                      if (value == null || value.isEmpty || !value.contains('@')) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                    enabled: !loginState.isLoading, // Disable when loading
                  ),
                  const SizedBox(height: 20),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton( // Toggle visibility
                         icon: Icon(
                           _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                         ),
                         onPressed: () {
                           setState(() {
                             _obscurePassword = !_obscurePassword;
                           });
                         },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) { // Basic validation
                      if (value == null || value.isEmpty || value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => loginState.isLoading ? null : _submitLogin(), // Submit on keyboard done
                    enabled: !loginState.isLoading, // Disable when loading
                  ),
                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: loginState.isLoading ? null : () {
                        print('Forgot Password pressed');
                        // TODO: Implement forgot password flow
                      },
                      child: Text(
                        'Forgot Password?',
                         style: textTheme.labelSmall?.copyWith(color: colorScheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Login Button
                  ElevatedButton(
                    // Disable button and show indicator when loading
                    onPressed: loginState.isLoading ? null : _submitLogin,
                    child: loginState.isLoading
                        ? const SizedBox( // Show progress indicator
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('LOGIN'),
                  ),
                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: loginState.isLoading ? null : () {
                          // --- START CHANGE ---
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                          );
                          // --- END CHANGE ---
                        },
                        child: Text(
                          'Sign Up',
                           style: textTheme.bodyMedium?.copyWith(
                             fontWeight: FontWeight.bold,
                             color: colorScheme.primary,
                           ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}