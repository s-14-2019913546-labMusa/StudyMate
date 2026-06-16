import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'focus_mode_screen.dart';

// ==========================================
// 1. Splash Screen (স্প্ল্যাশ স্ক্রিন)
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // ২ সেকেন্ড পর স্বয়ংক্রিয়ভাবে লগইন পেইজে চলে যাবে
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      
      // চেক করবে ইউজার আগে থেকে লগইন করা আছে কিনা
      if (FirebaseAuth.instance.currentUser != null) {
        Navigator.pushReplacement(
          context, // Navigate to FocusModeScreen if logged in
          MaterialPageRoute(builder: (context) => const FocusModeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary, // Use theme primary color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.school,
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            Text(
              'StudyMate',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your Educational Companion',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}