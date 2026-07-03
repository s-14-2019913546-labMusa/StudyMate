import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'focus_mode_screen.dart';
import 'language_manager.dart';
import 'fcm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// 3. Sign Up Screen (সাইন আপ স্ক্রিন)
// ==========================================
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>(); // Add a GlobalKey for the Form

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // সাইন-আপ করার ফায়ারবেস লজিক
  Future<void> _signUp() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Passwords do not match!'.tr())));
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return; // If form is not valid, do not proceed
    }

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await userCredential.user?.updateDisplayName(_nameController.text.trim());
      
      // Create user document in Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'displayName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'streak': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sync FCM token upon successful registration
      await FcmService.syncToken();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_password_login_timestamp', DateTime.now().millisecondsSinceEpoch);

      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const FocusModeScreen()), (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message;
        if (e.code == 'weak-password') {
          message = 'The password provided is too weak.'.tr();
        } else if (e.code == 'email-already-in-use') {
          message = 'The email address is already in use by another account.'.tr();
        } else if (e.code == 'invalid-email') {
          message = 'The email address is not valid.'.tr();
        } else if (e.code == 'operation-not-allowed') {
          message = 'Email/password accounts are not enabled.'.tr();
        } else {
          message = (e.message ?? 'Sign up failed. Please try again.').tr();
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () {
            Navigator.pop(context); // আগের পেইজে (Login) ফিরে যাওয়ার লজিক
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              // Wrap your Column with a Form widget
              key: _formKey, // Assign the form key
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // শিরোনাম
                  Text(
                    'Create Account'.tr(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sign up to get started!'.tr(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 40),

                  // নাম ইনপুট
                  TextFormField(
                    // Use TextFormField for validation
                    controller: _nameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name'.tr();
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'Full Name'.tr(),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ইমেইল ইনপুট
                  TextFormField(
                    // Use TextFormField for validation
                    controller: _emailController,
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
                  const SizedBox(height: 16),

                  // পাসওয়ার্ড ইনপুট
                  TextFormField(
                    // Use TextFormField for validation
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password'.tr();
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters long'.tr();
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
                    ),
                  ),
                  const SizedBox(height: 16),

                  // কনফার্ম পাসওয়ার্ড ইনপুট
                  TextFormField(
                    // Use TextFormField for validation
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password'.tr();
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match'.tr();
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'Confirm Password'.tr(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // সাইন আপ বাটন
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
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
                            'Sign Up'.tr(),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}