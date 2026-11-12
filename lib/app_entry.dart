import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';
import 'focus_mode_screen.dart';
import 'onboarding_screen.dart';

/// লগইনের পরে কোন স্ক্রিনে যাবে তা এক জায়গা থেকে ঠিক করা হয়:
/// প্রথমবার → পরিচিতি (Onboarding), তারপর Focus Mode (সেটিং অনুযায়ী) → হোম।
class AppEntry {
  /// Focus Mode স্ক্রিন: 'auto' = ৩ সেকেন্ড পর নিজে হোমে যাবে, 'manual' = বাটন চাপতে হবে, 'off' = দেখাবে না
  static const String focusModePrefKey = 'focus_screen_mode';
  static const String onboardingDoneKey = 'onboarding_done_v1';

  static Future<String> getFocusMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(focusModePrefKey) ?? 'auto';
    } catch (_) {
      return 'auto';
    }
  }

  static Future<void> setFocusMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(focusModePrefKey, mode);
  }

  /// লগইন/স্প্ল্যাশের পরে প্রথম স্ক্রিন
  static Future<Widget> resolve() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(onboardingDoneKey) ?? false)) {
        return const OnboardingScreen();
      }
    } catch (_) {}
    return afterOnboarding();
  }

  static Future<Widget> afterOnboarding() async {
    final mode = await getFocusMode();
    if (mode == 'off') return const DashboardScreen();
    return const FocusModeScreen();
  }

  static Route<void> fadeRoute(Widget page, {int ms = 600}) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: Duration(milliseconds: ms),
    );
  }

  /// নেভিগেশন স্ট্যাক মুছে দিয়ে সঠিক প্রথম স্ক্রিনে যায়
  static Future<void> go(BuildContext context, {bool clearStack = false}) async {
    final page = await resolve();
    if (!context.mounted) return;
    if (clearStack) {
      Navigator.of(context).pushAndRemoveUntil(fadeRoute(page), (_) => false);
    } else {
      Navigator.of(context).pushReplacement(fadeRoute(page));
    }
  }
}
