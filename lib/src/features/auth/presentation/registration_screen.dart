// lib/src/features/auth/presentation/registration_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caption_hook/src/features/auth/data/auth_providers.dart'; // Import auth providers
import 'package:caption_hook/src/features/auth/data/auth_repository.dart'; // Import Login screen

// --- State Notifier ---

// State class tracks loading and errors
@immutable
class RegistrationScreenState {
  const RegistrationScreenState({this.isLoading = false, this.error});
  final bool isLoading;
  final String? error;

  RegistrationScreenState copyWith({bool? isLoading, String? error}) {
    return RegistrationScreenState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Controller for registration logic
class RegistrationScreenController extends StateNotifier<RegistrationScreenState> {
 // --- START CHANGE ---
  final AuthRepository _authRepository;
  RegistrationScreenController(this._authRepository) : super(const RegistrationScreenState());
 // --- END CHANGE ---

  Future<void> register(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // --- START CHANGE ---
      // Remove simulation delay
      print('Attempting registration with Email: $email'); // Don't log password
      // Call the repository method
      await _authRepository.createUserWithEmailAndPassword(email, password);
      // --- END CHANGE ---

      // Auth state change handled by AuthGate
      // Clear loading state explicitly.
      state = state.copyWith(isLoading: false);

    } on AuthException catch (e) { // Catch our custom exception
        print('Registration failed: $e');
        state = state.copyWith(isLoading: false, error: e.message); // Use message from AuthException
    } catch (e) { // Catch any other unexpected errors
      print('Unexpected Registration error: $e');
      state = state.copyWith(isLoading: false, error: 'An unexpected error occurred.');
    }
  }
}

// --- Provider ---

final registrationScreenControllerProvider =
    StateNotifierProvider.autoDispose<RegistrationScreenController, RegistrationScreenState>((ref) { // Use autoDispose
  // --- START CHANGE ---
  // Inject the repository dependency
  return RegistrationScreenController(ref.watch(authRepositoryProvider));
  // --- END CHANGE ---
});


// --- UI Widget ---

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController(); // Added confirm password
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose(); // Dispose new controller
    super.dispose();
  }

  // Method to trigger registration
  Future<void> _submitRegistration() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      // Call the register method on the controller
      await ref.read(registrationScreenControllerProvider.notifier).register(email, password);
      // Navigation handled by Auth Gate later
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final registrationState = ref.watch(registrationScreenControllerProvider); // Watch registration state

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        // --- START CHANGE ---
        // Automatically adds a back button if the screen can be popped
        automaticallyImplyLeading: true,
        // Optional: Explicitly add back button handling if needed
        // leading: Navigator.canPop(context) ? IconButton(
        //   icon: const Icon(Icons.arrow_back),
        //   onPressed: () => Navigator.of(context).pop(),
        // ) : null,
        // --- END CHANGE ---
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Get Started',
                    style: textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create an account to continue',
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                   // Display error message if any
                  if (registrationState.error != null) ...[
                     Text(
                       'Registration Failed: ${registrationState.error}',
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
                    validator: (value) {
                      if (value == null || value.isEmpty || !value.contains('@')) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                    enabled: !registrationState.isLoading,
                  ),
                  const SizedBox(height: 20),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Choose a strong password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                         icon: Icon(
                           _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                         ),
                         onPressed: () {
                           setState(() { _obscurePassword = !_obscurePassword; });
                         },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                    enabled: !registrationState.isLoading,
                  ),
                  const SizedBox(height: 20),

                  // Confirm Password Field
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Re-enter your password',
                      prefixIcon: const Icon(Icons.lock_outline),
                       suffixIcon: IconButton(
                         icon: Icon(
                           _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                         ),
                         onPressed: () {
                           setState(() { _obscureConfirmPassword = !_obscureConfirmPassword; });
                         },
                      ),
                    ),
                    obscureText: _obscureConfirmPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) { // Check if passwords match
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => registrationState.isLoading ? null : _submitRegistration(),
                    enabled: !registrationState.isLoading,
                  ),
                  const SizedBox(height: 30),

                  // Register Button
                  ElevatedButton(
                    onPressed: registrationState.isLoading ? null : _submitRegistration,
                    child: registrationState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('REGISTER'),
                  ),
                  const SizedBox(height: 30),

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account?",
                        style: textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: registrationState.isLoading ? null : () {
                           // --- START CHANGE ---
                           // Navigate back to the previous screen (LoginScreen)
                           Navigator.pop(context);
                           // --- END CHANGE ---
                        },
                        child: Text(
                          'Login',
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