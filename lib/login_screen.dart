import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_screen.dart';
import 'focus_mode_screen.dart';
import 'language_manager.dart';
import 'fcm_service.dart';

// ==========================================
// 2. Login Screen (লগইন স্ক্রিন)
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>(); // Add a GlobalKey for the Form

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // লগইন করার ফায়ারবেস লজিক
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return; // If form is not valid, do not proceed
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Sync FCM token upon successful login
      await FcmService.syncToken();

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FocusModeScreen()));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message;
        if (e.code == 'user-not-found') {
          message = 'No user found for that email.'.tr();
        } else if (e.code == 'wrong-password') {
          message = 'Wrong password provided for that user.'.tr();
        } else if (e.code == 'invalid-email') {
          message = 'The email address is not valid.'.tr();
        } else if (e.code == 'user-disabled') {
          message = 'This user account has been disabled.'.tr();
        } else {
          message = (e.message ?? 'Login failed. Please try again.').tr();
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final TextEditingController resetEmailController = TextEditingController(text: _emailController.text);
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Forgot Password?'.tr()),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your email address and we will send you a link to reset your password.'.tr(),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email'.tr();
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Please enter a valid email address'.tr();
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Email Address'.tr(),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final email = resetEmailController.text.trim();
                  try {
                    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${'Password reset email sent to '.tr()}$email')),
                      );
                    }
                  } on FirebaseAuthException catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text((e.message ?? 'An error occurred. Please try again.').tr())),
                      );
                    }
                  }
                }
              },
              child: Text('Reset Password'.tr()),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface, // Use theme surface color
      body: SafeArea(
        child: Center(
          child: Form(
            // Wrap your Column with a Form widget
            key: _formKey, // Assign the form key
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // লোগো এবং শিরোনাম
                  Icon(Icons.school, size: 80, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 10),
                  Text(
                    'StudyMate'.tr(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 40),

                  // ইমেইল ইনপুট
                  TextFormField(
                    // Use TextFormField for validation
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      // Add validator
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email'.tr();
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Please enter a valid email address'.tr();
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'Email Address'.tr(),
                      prefixIcon: const Icon(Icons.email_outlined),
                      // Using global InputDecorationTheme for border
                    ),
                  ),
                  const SizedBox(height: 16),

                  // পাসওয়ার্ড ইনপুট
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    validator: (value) {
                      // Add validator
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password'.tr();
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'Password'.tr(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      // Using global InputDecorationTheme for border
                    ),
                  ),

                  // ফরগেট পাসওয়ার্ড
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: Text('Forgot Password?'.tr()),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // লগইন বাটন (ইমেইল দিয়ে)
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Log In'.tr(),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // সাইন আপ বাটন
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?".tr(), // Style is now inherited from the global theme
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignUpScreen()),
                          );
                        },
                        // The style for this TextButton is defined globally in main.dart's theme
                        child: Text('Create New Account'.tr()),
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