import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'main.dart'; // for navigatorKey
import 'local_notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SleepTimerService {
  static final SleepTimerService _instance = SleepTimerService._internal();
  factory SleepTimerService() => _instance;
  SleepTimerService._internal();

  Timer? _globalTimer;
  Timer? _alarmRingingTimer;
  bool _bedTimeTriggered = false;
  bool _alarmTriggered = false;

  void start() {
    _globalTimer?.cancel();
    _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkSleepTimes();
    });
  }

  void stop() {
    _globalTimer?.cancel();
    _alarmRingingTimer?.cancel();
  }

  Future<void> _checkSleepTimes() async {
    final prefs = await SharedPreferences.getInstance();
    
    final String? expectedStartStr = prefs.getString('expected_sleep_start');
    final String? morningTimeStr = prefs.getString('morning_time');
    final String? bedTimeStr = prefs.getString('bed_time');
    
    final now = DateTime.now();

    // Check if expected_sleep_start is valid and in the past = user is sleeping.
    bool isSleeping = false;
    if (expectedStartStr != null) {
      DateTime expectedStart = DateTime.parse(expectedStartStr);
      if (expectedStart.isBefore(now)) {
        isSleeping = true;
      }
    }

    // Bed Time Check (only if NOT sleeping)
    if (!isSleeping && bedTimeStr != null) {
      final timeRegex = RegExp(r'TimeOfDay\(([0-9]{2}):([0-9]{2})\)');
      final match = timeRegex.firstMatch(bedTimeStr);
      if (match != null) {
        int bedHour = int.parse(match.group(1)!);
        int bedMinute = int.parse(match.group(2)!);
        
        if (!_bedTimeTriggered && now.hour == bedHour && now.minute == bedMinute) {
          _bedTimeTriggered = true;
          _showGlobalBedTimePopup();
        }
        if (now.minute != bedMinute) {
          _bedTimeTriggered = false;
        }
      }
    }

    // Wake Time Check (only if sleeping)
    if (isSleeping && morningTimeStr != null) {
      final timeRegex = RegExp(r'TimeOfDay\(([0-9]{2}):([0-9]{2})\)');
      final match = timeRegex.firstMatch(morningTimeStr);
      if (match != null) {
        int morningHour = int.parse(match.group(1)!);
        int morningMinute = int.parse(match.group(2)!);
        
        if (!_alarmTriggered && now.hour == morningHour && now.minute == morningMinute) {
          _alarmTriggered = true;
          _triggerGlobalAlarm();
        }
        if (now.minute != morningMinute) {
          _alarmTriggered = false;
        }
      }
    }
  }

  void _showGlobalBedTimePopup() {
    final context = navigatorKey.currentState?.overlay?.context;
    if (context == null) return;
    
    SoundPlayer.playPushNotificationSound();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Bed Time!'.tr(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Your sleep session has started. Please put your phone away.'.tr(), textAlign: TextAlign.center),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              final now = DateTime.now();
              await prefs.setString('expected_sleep_start', now.toIso8601String());
              
              // Reschedule checkup (10 mins after as requested)
              await LocalNotificationService.scheduleCheckupNotification(const Duration(minutes: 10));
            },
            child: Text('Go to Sleep'.tr()),
          ),
        ],
      ),
    );
  }

  void _triggerGlobalAlarm() {
    final context = navigatorKey.currentState?.overlay?.context;
    if (context == null) return;

    HapticFeedback.heavyImpact();
    _alarmRingingTimer?.cancel();
    _alarmRingingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.alert);
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('⏰ Good Morning!', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('It is time to rise and shine. Do you want to snooze or turn off the alarm?', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () async {
              _alarmRingingTimer?.cancel();
              Navigator.pop(ctx);
              
              final snoozeTime = DateTime.now().add(const Duration(minutes: 5));
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('morning_time', TimeOfDay.fromDateTime(snoozeTime).toString());
              await LocalNotificationService.scheduleMorningAlarm(snoozeTime);
              _alarmTriggered = false;
            },
            child: const Text('Snooze (5m)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              _alarmRingingTimer?.cancel();
              Navigator.pop(ctx);
              await _stopSleepAndSaveGlobally(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Turn Off'),
          ),
        ],
      ),
    );
  }

  Future<void> _stopSleepAndSaveGlobally(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final expectedStartStr = prefs.getString('expected_sleep_start');
    if (expectedStartStr == null) return;

    final sleepStartTime = DateTime.parse(expectedStartStr);
    final now = DateTime.now();
    final duration = now.difference(sleepStartTime);
    final startOfDay = DateTime(now.year, now.month, now.day);
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      await _clearSleepState(prefs);
      return;
    }

    final collection = FirebaseFirestore.instance.collection('users').doc(currentUser.uid).collection('sleep_history');
    
    final todayRecords = await collection
        .where('wakeTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .orderBy('wakeTime', descending: true)
        .get();

    bool isDuplicate = false;
    for (var doc in todayRecords.docs) {
      final data = doc.data();
      final savedBedTime = (data['bedTime'] as Timestamp).toDate();
      if (savedBedTime.difference(sleepStartTime).inMinutes.abs() < 2) {
        isDuplicate = true;
        break;
      }
    }

    if (isDuplicate || todayRecords.docs.length >= 3) {
      await _clearSleepState(prefs);
      return;
    }

    await collection.add({
      'bedTime': Timestamp.fromDate(sleepStartTime),
      'wakeTime': Timestamp.fromDate(now),
      'durationMinutes': duration.inMinutes,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _clearSleepState(prefs);
    if (context.mounted) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sleep history saved!')));
    }
  }

  Future<void> _clearSleepState(SharedPreferences prefs) async {
    await prefs.remove('expected_sleep_start');
    await prefs.setBool('needs_to_save_sleep_history', false);
    await LocalNotificationService.cancelAllNotifications();
  }
}
