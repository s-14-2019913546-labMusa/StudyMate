import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class AppLockService {
  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  static const String _keyAppLockEnabled = 'app_lock_enabled';
  static const String _keyAppLockPin = 'app_lock_pin';
  static const String _keyBiometricEnabled = 'app_lock_biometric_enabled';

  final LocalAuthentication _auth = LocalAuthentication();
  
  // Track if the app is currently unlocked for the session
  bool _isSessionUnlocked = false;
  
  // Track timestamp when app went to background
  DateTime? _backgroundTime;

  bool get isSessionUnlocked => _isSessionUnlocked;

  void lockSession() {
    _isSessionUnlocked = false;
  }

  void unlockSession() {
    _isSessionUnlocked = true;
  }

  // Set when app goes background
  void markBackgroundTime() {
    _backgroundTime = DateTime.now();
  }

  // Check if we should lock again on resume (e.g. if backgrounded > 15 seconds)
  bool shouldLockOnResume() {
    if (!isAppLockEnabled()) return false;
    if (_backgroundTime == null) return true;
    
    final elapsed = DateTime.now().difference(_backgroundTime!);
    // 15 seconds grace period
    if (elapsed.inSeconds > 15) {
      _isSessionUnlocked = false;
      return true;
    }
    return false;
  }

  // SharedPreferences instance caching
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool isAppLockEnabled() {
    return _prefs.getBool(_keyAppLockEnabled) ?? false;
  }

  bool isBiometricEnabled() {
    return _prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  String? getPin() {
    return _prefs.getString(_keyAppLockPin);
  }

  Future<void> enableAppLock(String pin, bool useBiometric) async {
    await _prefs.setBool(_keyAppLockEnabled, true);
    await _prefs.setString(_keyAppLockPin, pin);
    await _prefs.setBool(_keyBiometricEnabled, useBiometric);
    _isSessionUnlocked = true;
  }

  Future<void> disableAppLock() async {
    await _prefs.setBool(_keyAppLockEnabled, false);
    await _prefs.remove(_keyAppLockPin);
    await _prefs.setBool(_keyBiometricEnabled, false);
    _isSessionUnlocked = false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(_keyBiometricEnabled, enabled);
  }

  // Check if device supports biometrics
  Future<bool> isBiometricsSupported() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (_) {
      return false;
    }
  }

  // Authenticate using biometrics
  Future<bool> authenticateWithBiometrics() async {
    if (!isAppLockEnabled() || !isBiometricEnabled()) return false;
    
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'আনলক করতে আপনার ফিঙ্গারপ্রিন্ট বা ফেস আইডি ব্যবহার করুন',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (didAuthenticate) {
        _isSessionUnlocked = true;
      }
      return didAuthenticate;
    } on PlatformException catch (_) {
      return false;
    }
  }

  bool verifyPin(String enteredPin) {
    final storedPin = getPin();
    if (storedPin == null) return false;
    final verified = storedPin == enteredPin;
    if (verified) {
      _isSessionUnlocked = true;
    }
    return verified;
  }
}
