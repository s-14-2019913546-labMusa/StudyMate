import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// পড়ার সময় অন্য অ্যাপের নোটিফিকেশন নীরব রাখা (Android "Do Not Disturb")।
/// প্রথমবার ফোনের সেটিংসে StudyMate-কে অনুমতি দিতে হয়।
class DndService {
  static const _ch = MethodChannel('studymate/dnd');
  static const autoKey = 'auto_dnd_in_focus';
  static bool _turnedOnByUs = false;

  static bool get supported => Platform.isAndroid;

  static Future<bool> hasAccess() async {
    if (!supported) return false;
    try {
      return await _ch.invokeMethod<bool>('hasAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openSettings() async {
    if (!supported) return;
    try {
      await _ch.invokeMethod('openSettings');
    } catch (_) {}
  }

  static Future<bool> isOn() async {
    if (!supported) return false;
    try {
      return await _ch.invokeMethod<bool>('isOn') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> set(bool on) async {
    if (!supported) return false;
    try {
      final ok = await _ch.invokeMethod<bool>('set', {'on': on}) ?? false;
      if (ok) _turnedOnByUs = on;
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> autoInFocus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(autoKey) ?? false;
  }

  static Future<void> setAutoInFocus(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(autoKey, v);
  }

  /// Pomodoro ফোকাস শুরু/শেষে ডাকা হয়। শুধু আমরা চালু করে থাকলে বন্ধ করি।
  static Future<void> onFocusChanged(bool focusing) async {
    if (!await autoInFocus()) return;
    if (focusing) {
      if (!await isOn()) await set(true);
    } else if (_turnedOnByUs) {
      await set(false);
    }
  }
}
