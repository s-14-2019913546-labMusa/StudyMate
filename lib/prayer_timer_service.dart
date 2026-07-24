import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'main.dart'; // for navigatorKey
import 'local_notification_service.dart';

class PrayerTimerService {
  static final PrayerTimerService _instance = PrayerTimerService._internal();
  factory PrayerTimerService() => _instance;
  PrayerTimerService._internal();

  Timer? _globalTimer;
  Timer? _alarmRingingTimer;
  
  // Keep track of triggered prayers by day to prevent multiple triggers
  // Format: "YYYY-MM-DD_PrayerName" -> true
  final Map<String, bool> _triggeredPrayers = {};
  
  bool _isPopupActive = false;

  void start() {
    _globalTimer?.cancel();
    _globalTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _checkPrayerTimes();
    });
  }

  void stop() {
    _globalTimer?.cancel();
    _stopAlarm();
  }

  Future<void> _checkPrayerTimes() async {
    if (_isPopupActive) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      
      // 1. Load Settings
      final settingsFile = File('${dir.path}/islamic_notif_settings.json');
      Map<String, dynamic> settings = {};
      if (await settingsFile.exists()) {
        settings = json.decode(await settingsFile.readAsString());
      }
      
      final bool prayerStartEnabled = settings['prayerStart'] ?? true;
      final bool isAlarmEnabled = settings['prayerAlarmEnabled'] ?? false;
      
      if (!prayerStartEnabled) return;

      // 2. Load Timings
      final cacheFile = File('${dir.path}/prayer_times_cache.json');
      if (!await cacheFile.exists()) return;
      
      final data = json.decode(await cacheFile.readAsString());
      final timings = Map<String, String>.from(data['timings']);
      
      final now = DateTime.now();
      final dateKey = "${now.year}-${now.month}-${now.day}";
      
      final List<String> prayerKeys = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
      final Map<String, String> prayerNames = {
        'Fajr': 'ফজর',
        'Dhuhr': (now.weekday == DateTime.friday) ? 'জুমা' : 'যোহর',
        'Asr': 'আসর',
        'Maghrib': 'মাগরিব',
        'Isha': 'এশা',
      };
      
      for (final pKey in prayerKeys) {
        final startStr = timings[pKey];
        if (startStr == null) continue;
        
        final startParts = startStr.split(':');
        final startHour = int.parse(startParts[0]);
        final startMin = int.parse(startParts[1]);
        final start = DateTime(now.year, now.month, now.day, startHour, startMin);
        
        // Prayer time + 5 minutes
        final triggerTime = start.add(const Duration(minutes: 5));
        
        // Check if now is the trigger time (give 1 minute window)
        if (now.hour == triggerTime.hour && now.minute == triggerTime.minute) {
          final triggerKey = "${dateKey}_$pKey";
          
          if (_triggeredPrayers[triggerKey] != true) {
            _triggeredPrayers[triggerKey] = true;
            _showPrayerPopup(prayerNames[pKey]!, pKey, isAlarmEnabled);
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking prayer times: $e");
    }
  }

  void _showPrayerPopup(String prayerName, String pKey, bool isAlarmEnabled) {
    final context = navigatorKey.currentState?.overlay?.context;
    if (context == null) return;
    
    _isPopupActive = true;
    
    // Start alarm if enabled
    if (isAlarmEnabled) {
      _startAlarm();
    } else {
      HapticFeedback.mediumImpact();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mosque, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            const Text('সালাতের ওয়াক্ত', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
        content: Text(
          '$prayerName সালাতের ওয়াক্ত শুরু হয়েছে! ৫ মিনিট অতিবাহিত হয়েছে।',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                _stopAlarm();
                _isPopupActive = false;
                Navigator.pop(ctx);
                
                // Cancel active background notification to stop OS alarm
                _cancelBackgroundNotification(pKey);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('ঠিক আছে', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    ).then((_) {
      _stopAlarm();
      _isPopupActive = false;
    });
  }
  
  void _startAlarm() {
    _stopAlarm();
    HapticFeedback.heavyImpact();
    // Play a basic system sound in loop as a fallback if real Azaan isn't hooked up here.
    // The OS flutter_local_notifications will play the real Azaan in background simultaneously.
    _alarmRingingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.alert);
    });
  }
  
  void _stopAlarm() {
    _alarmRingingTimer?.cancel();
  }

  void _cancelBackgroundNotification(String pKey) {
    final Map<String, int> prayerIndices = {
      'Fajr': 0,
      'Dhuhr': 1,
      'Asr': 2,
      'Maghrib': 3,
      'Isha': 4,
    };
    
    final pIndex = prayerIndices[pKey];
    if (pIndex != null) {
      // Calculate startId: 1000 + (dayOffset=0 * 10) + (pIndex * 2) + 0
      final int startId = 1000 + 0 + (pIndex * 2) + 0;
      LocalNotificationService.cancelNotification(startId);
    }
  }
}
