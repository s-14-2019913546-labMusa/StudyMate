import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:open_filex/open_filex.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

import '../daily_routine.dart';
import '../dashboard_screen.dart';
import '../calendar_screen.dart';
import '../focus_music_screen.dart';
import '../flashcards_screen.dart';
import '../dictionary_screen.dart';
import '../ai_service.dart';
import '../revision_147_screen.dart';
import '../islamic_life_screen.dart';
import '../theme_manager.dart';
import '../local_notification_service.dart';
import '../study_analytics_screen.dart';
import '../weekly_overview_screen.dart';
import '../task_history_screen.dart';
import '../gamification_service.dart';
import '../language_manager.dart';
import '../study_folder_manager_screen.dart';
import '../special_day_countdown_screen.dart';
import '../daily_diary_screen.dart';
import '../bookmarks_screen.dart';
import '../news_reader_screen.dart';
import '../social_hub_screen.dart';
import '../google_sheet_sync_screen.dart';
import '../multi_sheet_manager_screen.dart';
import '../notifications_hub_screen.dart';
import '../widgets/sound_picker_widget.dart';
import '../tools_screen.dart';

// ==========================================
// 10. Sleep Tracker Screen (স্লিপ ট্র্যাকার ও অ্যালার্ম)
// ==========================================
class SleepTrackerScreen extends StatefulWidget {
  const SleepTrackerScreen({super.key});

  @override
  State<SleepTrackerScreen> createState() => _SleepTrackerScreenState();
}

class _SleepTrackerScreenState extends State<SleepTrackerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  Stream<QuerySnapshot>? _sleepHistoryStream;

  TimeOfDay _bedTime = const TimeOfDay(hour: 23, minute: 45);
  TimeOfDay _morningTime = const TimeOfDay(hour: 6, minute: 0);
  
  bool _isSleeping = false;
  DateTime? _sleepStartTime;
  Timer? _uiUpdateTimer;
  Timer? _alarmRingingTimer;
  bool _alarmTriggered = false;
  bool _bedTimeTriggered = false;

  String _selectedSleepAlarmSound = 'rooster';
  String _selectedSleepAlarmSoundName = 'মুরগির ডাক (Rooster)';
  String _sleepAlarmRepeatCount = 'loop';
  
  final Map<String, String> _builtInSounds = {
    'rooster': 'মুরগির ডাক (Rooster)',
    'clock': 'ঘড়ির শব্দ (Clock)',
    'emergency': 'ইমার্জেন্সি (Emergency)',
  };

  final Map<String, String> _systemAlarmSounds = {
    'Alarm': 'System Default Alarm',
    'Ringtone': 'System Default Ringtone',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _startUIUpdateTimer(); // Start timer immediately to watch for bedtime
    _loadSleepState();
    _loadSleepAlarmSettings();
    _checkAndSaveMissedDays();
    if (currentUser != null) {
      _sleepHistoryStream = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('sleep_history')
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
  }

  Future<void> _checkAndSaveMissedDays() async {
    if (currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    final String? lastCheckedDateStr = prefs.getString('last_sleep_checked_date');
    
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    if (lastCheckedDateStr != null) {
      final lastCheckedDate = DateTime.parse(lastCheckedDateStr);
      final differenceInDays = todayStart.difference(lastCheckedDate).inDays;
      
      if (differenceInDays > 0) {
        final collection = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('sleep_history');
        
        for (int i = 1; i <= differenceInDays; i++) {
          final missedDay = lastCheckedDate.add(Duration(days: i));
          if (missedDay.isBefore(todayStart)) {
            final dayStart = missedDay;
            final dayEnd = missedDay.add(const Duration(days: 1));
            
            final records = await collection
                .where('wakeTime', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
                .where('wakeTime', isLessThan: Timestamp.fromDate(dayEnd))
                .limit(1)
                .get();
                
            if (records.docs.isEmpty) {
              await collection.add({
                'bedTime': Timestamp.fromDate(dayStart),
                'wakeTime': Timestamp.fromDate(dayStart.add(const Duration(hours: 0))),
                'durationMinutes': 0,
                'timestamp': FieldValue.serverTimestamp(),
                'note': 'স্লিপ ট্রাকার ব্যবহার হয়নি',
              });
            }
          }
        }
      }
    } else {
      // First time using the app/tracker, just set the date to today
    }
    
    await prefs.setString('last_sleep_checked_date', todayStart.toIso8601String());
  }

  TimeOfDay _parseTimeOfDay(String str, TimeOfDay fallback) {
    try {
      if (str.startsWith('TimeOfDay(')) {
        final parts = str.substring(10, str.length - 1).split(':');
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    return fallback;
  }

  Future<void> _loadSleepAlarmSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final String? savedBedTime = prefs.getString('bed_time');
      if (savedBedTime != null) _bedTime = _parseTimeOfDay(savedBedTime, const TimeOfDay(hour: 23, minute: 45));
      
      final String? savedMorningTime = prefs.getString('morning_time');
      if (savedMorningTime != null) _morningTime = _parseTimeOfDay(savedMorningTime, const TimeOfDay(hour: 6, minute: 0));

      _selectedSleepAlarmSound = prefs.getString('selectedSleepAlarmSound') ?? 'rooster';
      
      if (!_builtInSounds.containsKey(_selectedSleepAlarmSound) && !_systemAlarmSounds.containsKey(_selectedSleepAlarmSound)) {
        _selectedSleepAlarmSound = 'rooster';
        _selectedSleepAlarmSoundName = _builtInSounds['rooster']!;
      } else {
        _selectedSleepAlarmSoundName = _builtInSounds[_selectedSleepAlarmSound] ?? _systemAlarmSounds[_selectedSleepAlarmSound]!;
      }
      _sleepAlarmRepeatCount = prefs.getString('sleepAlarmRepeatCount') ?? 'loop';
    });
  }



  Future<void> _loadSleepState() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if there's an ongoing sleep session
    final expectedStartStr = prefs.getString('expected_sleep_start');
    if (expectedStartStr != null) {
      final expectedStart = DateTime.parse(expectedStartStr);
      // If expected sleep start is in the past, user is considered sleeping
      if (expectedStart.isBefore(DateTime.now())) {
        setState(() {
          _isSleeping = true;
          _sleepStartTime = expectedStart;
        });
        _startUIUpdateTimer();
      }
    }

    // Check if alarm was turned off in background and we need to save history
    final needsSave = prefs.getBool('needs_to_save_sleep_history') ?? false;
    if (needsSave && _sleepStartTime != null) {
      await _saveSleepHistoryToFirebase();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _uiUpdateTimer?.cancel();
    _alarmRingingTimer?.cancel();
    super.dispose();
  }



  void _startUIUpdateTimer() {
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      
      final now = DateTime.now();
    });
  }



  Future<void> _startSleep() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _isSleeping = true;
      _sleepStartTime = DateTime.now();
    });
    
    await prefs.setString('expected_sleep_start', _sleepStartTime!.toIso8601String());
    
    // Schedule all notifications via background service
    final now = DateTime.now();
    DateTime actualBedTime = DateTime(now.year, now.month, now.day, _bedTime.hour, _bedTime.minute);
    if (actualBedTime.isBefore(now)) actualBedTime = actualBedTime.add(const Duration(days: 1));
    
    DateTime actualWakeTime = DateTime(now.year, now.month, now.day, _morningTime.hour, _morningTime.minute);
    if (actualWakeTime.isBefore(now)) actualWakeTime = actualWakeTime.add(const Duration(days: 1));

    await LocalNotificationService.scheduleAllSleepNotifications(actualBedTime, actualWakeTime);
    _startUIUpdateTimer();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Sleep tracked & Alarms set for background!'.tr())));
    }
  }

  Future<void> _saveSleepHistoryToFirebase() async {
    if (_sleepStartTime == null || currentUser == null) return;
    
    final now = DateTime.now();
    final duration = now.difference(_sleepStartTime!);
    final startOfDay = DateTime(now.year, now.month, now.day);
    
    final collection = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('sleep_history');
    
    final todayRecords = await collection
        .where('wakeTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .orderBy('wakeTime', descending: true)
        .get();

    bool isDuplicate = false;
    for (var doc in todayRecords.docs) {
      final data = doc.data();
      final savedBedTime = (data['bedTime'] as Timestamp).toDate();
      if (savedBedTime.difference(_sleepStartTime!).inMinutes.abs() < 2) {
        isDuplicate = true;
        break;
      }
    }

    if (isDuplicate) {
      // Clear local state without saving
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('expected_sleep_start');
      await prefs.setBool('needs_to_save_sleep_history', false);
      setState(() {
        _isSleeping = false;
        _sleepStartTime = null;
      });
      _uiUpdateTimer?.cancel();
      return;
    }

    if (todayRecords.docs.length >= 3) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Maximum 3 sleep records allowed per day!'.tr())));
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('expected_sleep_start');
      await prefs.setBool('needs_to_save_sleep_history', false);
      setState(() {
        _isSleeping = false;
        _sleepStartTime = null;
      });
      _uiUpdateTimer?.cancel();
      return;
    }

    await collection.add({
      'bedTime': Timestamp.fromDate(_sleepStartTime!),
      'wakeTime': Timestamp.fromDate(now),
      'durationMinutes': duration.inMinutes,
      'timestamp': FieldValue.serverTimestamp(),
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('expected_sleep_start');
    await prefs.setBool('needs_to_save_sleep_history', false);

    setState(() {
      _isSleeping = false;
      _sleepStartTime = null;
    });
    _uiUpdateTimer?.cancel();
  }

  Future<void> _stopSleepAndSave() async {
    _alarmRingingTimer?.cancel();
    await LocalNotificationService.cancelAllNotifications();
    await _saveSleepHistoryToFirebase();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Sleep session saved to history!'.tr())));
    }
  }

  Future<void> _pickTime(bool isBedTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isBedTime ? _bedTime : _morningTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isBedTime) {
          _bedTime = picked;
        } else {
          _morningTime = picked;
        }
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bed_time', _bedTime.toString());
    await prefs.setString('morning_time', _morningTime.toString());
    
    // Reschedule if they are not sleeping yet
    if (!_isSleeping) {
      final now = DateTime.now();
      DateTime actualBedTime = DateTime(now.year, now.month, now.day, _bedTime.hour, _bedTime.minute);
      if (actualBedTime.isBefore(now)) actualBedTime = actualBedTime.add(const Duration(days: 1));
      
      DateTime actualWakeTime = DateTime(now.year, now.month, now.day, _morningTime.hour, _morningTime.minute);
      if (actualWakeTime.isBefore(now)) actualWakeTime = actualWakeTime.add(const Duration(days: 1));
      
      await LocalNotificationService.scheduleAllSleepNotifications(actualBedTime, actualWakeTime);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Sleep time saved!', 'স্লিপ টাইম সেভ করা হয়েছে!'))));
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String h = twoDigits(d.inHours);
    String m = twoDigits(d.inMinutes.remainder(60));
    String s = twoDigits(d.inSeconds.remainder(60));
    return "$h:$m:$s";
  }

  Future<void> _deleteSleepRecord(String docId) async {
    if (currentUser == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Sleep Record'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this sleep record?'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('sleep_history')
            .doc(docId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sleep record deleted successfully!'.tr())),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete sleep record!'.tr())),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(trx('Sleep Tracker', 'ঘুমের হিসাব'), style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [Tab(text: 'Tracker & Alarm'), Tab(text: 'Sleep History')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTrackerTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildTrackerTab() {
    if (_isSleeping) {
      // ঘুমানোর সময়ের লাইভ টাইমার স্ক্রিন
      final duration = DateTime.now().difference(_sleepStartTime!);
      return Container(
        color: const Color(0xFF0F172A), // Dark night background
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.nightlight_round, size: 80, color: Colors.amberAccent),
            const SizedBox(height: 24),
            Text(trx('Good Night!', 'শুভ রাত্রি!'), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(trx('Sleep timer is running...', 'ঘুমের টাইমার চলছে...'), style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 40),
            Text(
              _formatDuration(duration),
              style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w300, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 60),
            ElevatedButton.icon(
              onPressed: _stopSleepAndSave,
              icon: const Icon(Icons.stop_circle_rounded),
              label: Text(trx('Wake Up Now (Stop)', 'এখন উঠেছি (বন্ধ)')),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.bedtime_rounded, size: 80, color: Colors.indigoAccent),
          const SizedBox(height: 24),
          Text(trx('Set Your Sleep Schedule', 'ঘুমের সময় ঠিক করুন'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 8),
          Text(trx('The alarm will ring at the morning time and snooze every 5 minutes if not turned off.', 'সকালের সময়ে অ্যালার্ম বাজবে, বন্ধ না করলে প্রতি ৫ মিনিট পর আবার বাজবে।'), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          
          Row(
            children: [
              Expanded(
                child: _buildTimeCard('Bed Time', _bedTime, true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTimeCard('Morning Time', _morningTime, false),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          _buildSleepDurationInfo(),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save_rounded),
            label: Text(trx('Save Time', 'সময় সেভ'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
               padding: const EdgeInsets.symmetric(vertical: 14),
               backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
               foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // Sound Selector Row
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.music_note_rounded, color: Colors.indigo),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(trx('Morning Alarm Sound', 'সকালের অ্যালার্মের সুর'),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              SoundPickerWidget(
                                selectedSoundKey: _selectedSleepAlarmSound,
                                selectedSoundName: _selectedSleepAlarmSoundName,
                                systemSounds: _systemAlarmSounds,
                                favoriteSounds: _builtInSounds,
                                isAlarm: true,
                                primaryColor: Colors.indigo,
                                onSoundSelected: (value) async {
                                  final prefs = await SharedPreferences.getInstance();
                                  setState(() {
                                    _selectedSleepAlarmSound = value;
                                    _selectedSleepAlarmSoundName = _systemAlarmSounds[value] ?? _builtInSounds[value] ?? value;
                                  });
                                  await prefs.setString('selectedSleepAlarmSound', _selectedSleepAlarmSound);
                                  await prefs.setString('selectedSleepAlarmSoundName', _selectedSleepAlarmSoundName);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.black12),
                  // Repeat Selector Row
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.repeat_rounded, color: Colors.indigo),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(trx('Alarm Repeat', 'অ্যালার্ম কতবার'),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              SizedBox(height: 2),
                              Text(trx('Alarm repeat', 'অ্যালার্ম পুনরাবৃত্তি'),
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        DropdownButton<String>(
                          value: _sleepAlarmRepeatCount,
                          underline: Container(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
                          onChanged: (String? val) async {
                            if (val != null) {
                              final prefs = await SharedPreferences.getInstance();
                              setState(() {
                                _sleepAlarmRepeatCount = val;
                              });
                              await prefs.setString('sleepAlarmRepeatCount', val);
                            }
                          },
                          items: [
                            DropdownMenuItem(value: 'loop', child: Text(trx('Loop Continuously', 'বন্ধ না করা পর্যন্ত'))),
                            DropdownMenuItem(value: '1', child: Text(trx('1 Time', '১ বার'))),
                            DropdownMenuItem(value: '2', child: Text(trx('2 Times', '২ বার'))),
                            DropdownMenuItem(value: '3', child: Text(trx('3 Times', '৩ বার'))),
                            DropdownMenuItem(value: '4', child: Text(trx('4 Times', '৪ বার'))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _startSleep,
            icon: const Icon(Icons.bed_rounded, size: 28),
            label: Text(trx('Go to Sleep', 'ঘুমাতে যান'), style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepDurationInfo() {
    final now = DateTime.now();
    DateTime actualBedTime = DateTime(now.year, now.month, now.day, _bedTime.hour, _bedTime.minute);
    DateTime actualWakeTime = DateTime(now.year, now.month, now.day, _morningTime.hour, _morningTime.minute);
    
    if (actualWakeTime.isBefore(actualBedTime) || actualWakeTime == actualBedTime) {
      actualWakeTime = actualWakeTime.add(const Duration(days: 1));
    }
    
    final duration = actualWakeTime.difference(actualBedTime);
    final int totalMinutes = duration.inMinutes;
    final int hours = totalMinutes ~/ 60;
    final int minutes = totalMinutes % 60;
    
    // A standard sleep cycle is roughly 90 minutes
    final double sleepCycles = totalMinutes / 90.0;
    
    final int remainingMinutes = totalMinutes % 90;
    // We consider a margin of +/- 15 minutes as acceptable cycle boundary
    bool isOptimal = remainingMinutes <= 15 || remainingMinutes >= 75;

    Widget suggestionWidget = const SizedBox.shrink();
    if (!isOptimal) {
      final int lowerCycleMinutes = (totalMinutes ~/ 90) * 90;
      final int upperCycleMinutes = ((totalMinutes ~/ 90) + 1) * 90;
      
      final DateTime lowerWakeTime = actualBedTime.add(Duration(minutes: lowerCycleMinutes));
      final DateTime upperWakeTime = actualBedTime.add(Duration(minutes: upperCycleMinutes));
      
      final TimeOfDay lowerTime = TimeOfDay.fromDateTime(lowerWakeTime);
      final TimeOfDay upperTime = TimeOfDay.fromDateTime(upperWakeTime);
      
      suggestionWidget = Column(
        children: [
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text('স্লিপ সাইকেল পূর্ণ করতে ওঠার সময় পরিবর্তন করুন:', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ActionChip(
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                label: Text('${lowerTime.format(context)} (${lowerCycleMinutes ~/ 90} cycle)'),
                onPressed: () {
                  setState(() {
                    _morningTime = lowerTime;
                  });
                },
              ),
              ActionChip(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                label: Text('${upperTime.format(context)} (${upperCycleMinutes ~/ 90} cycle)'),
                onPressed: () {
                  setState(() {
                    _morningTime = upperTime;
                  });
                },
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Total Sleep: $hours hr ${minutes} min',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.loop_rounded, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                'Sleep Cycles: ${sleepCycles.toStringAsFixed(1)} (Ideal: 4-6 cycles)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          suggestionWidget,
        ],
      ),
    );
  }

  Widget _buildTimeCard(String title, TimeOfDay time, bool isBedTime) {
    final cardDeco = ThemeManager.getCardDecoration(context);
    final String time24h = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () => _pickTime(isBedTime),
      borderRadius: cardDeco.borderRadius as BorderRadius?,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: cardDeco,
        child: Column(
          children: [
            Icon(isBedTime ? Icons.hotel_rounded : Icons.wb_sunny_rounded, color: isBedTime ? Colors.indigoAccent : Colors.orangeAccent, size: 32),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(time.format(context), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('($time24h)', style: const TextStyle(fontSize: 14, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (currentUser == null || _sleepHistoryStream == null) return Center(child: Text(trx('Please log in to view sleep history.', 'ঘুমের ইতিহাস দেখতে লগইন করুন।')));

    return StreamBuilder<QuerySnapshot>(
      stream: _sleepHistoryStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final allDocs = snapshot.hasData ? snapshot.data!.docs : [];
        
        Map<String, List<QueryDocumentSnapshot>> groupedByDate = {};
        DateTime oldestDate = DateTime.now();
        for (var doc in allDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final wakeTime = (data['wakeTime'] as Timestamp).toDate();
          if (wakeTime.isBefore(oldestDate)) {
            oldestDate = wakeTime;
          }
          String dateKey = DateFormat('yyyy-MM-dd').format(wakeTime);
          if (!groupedByDate.containsKey(dateKey)) {
            groupedByDate[dateKey] = [];
          }
          if (groupedByDate[dateKey]!.length < 3) {
            groupedByDate[dateKey]!.add(doc);
          }
        }

        int daysCount = 7; // Show at least 7 days
        if (allDocs.isNotEmpty) {
          int diff = DateTime.now().difference(oldestDate).inDays;
          if (diff + 1 > daysCount) {
            daysCount = diff + 1;
          }
        }

        List<DateTime> allDaysList = List.generate(daysCount, (index) => DateTime.now().subtract(Duration(days: index)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allDaysList.length,
          itemBuilder: (context, index) {
            final day = allDaysList[index];
            final dateKey = DateFormat('yyyy-MM-dd').format(day);
            final docsForDay = groupedByDate[dateKey] ?? [];

            String dayHeader = DateFormat('MMM dd, yyyy').format(day);
            if (index == 0) dayHeader = "Today ($dayHeader)".tr();
            else if (index == 1) dayHeader = "Yesterday ($dayHeader)".tr();

            List<Widget> dayWidgets = [];
            dayWidgets.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(dayHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigoAccent)),
              )
            );

            if (docsForDay.isEmpty) {
              dayWidgets.add(
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    leading: const Icon(Icons.history_toggle_off_rounded, color: Colors.grey),
                    title: Text("No sleep history".tr(), style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                  ),
                )
              );
            } else {
              for (var doc in docsForDay) {
                final data = doc.data() as Map<String, dynamic>;
                final wakeTime = (data['wakeTime'] as Timestamp).toDate();
                final bedTime = (data['bedTime'] as Timestamp).toDate();
                final durationMins = data['durationMinutes'] ?? 0;
                
                int hours = durationMins ~/ 60;
                int mins = durationMins % 60;

                String bedStr = DateFormat('hh:mm a').format(bedTime);
                String wakeStr = DateFormat('hh:mm a').format(wakeTime);

                dayWidgets.add(
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.nights_stay_rounded, color: Colors.indigo),
                      ),
                      title: Text('Bed: $bedStr  •  Wake: $wakeStr'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Total Sleep'.tr(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              Text('${hours}h ${mins}m', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                            onPressed: () => _deleteSleepRecord(doc.id),
                          ),
                        ],
                      ),
                    ),
                  )
                );
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: dayWidgets,
            );
          },
        );
      },
    );
  }

}

