import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:developer';
import 'daily_routine.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handle background actions here
  log('Background Notification Action Triggered: ${notificationResponse.actionId}');
  _handleNotificationAction(notificationResponse.actionId);
}

Future<void> _handleNotificationAction(String? actionId) async {
  if (actionId == null) return;
  
  // Initialize timezone in background isolate before using any tz functions
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
  
  final prefs = await SharedPreferences.getInstance();

  if (actionId == 'sleep_awake') {
    // User is awake, reschedule checkup for 20 mins later
    log('User is awake, rescheduling checkup.');
    await LocalNotificationService.scheduleCheckupNotification(Duration(minutes: 20));
    // Reset expected sleep time to 20 mins from now
    await prefs.setString('expected_sleep_start', DateTime.now().add(const Duration(minutes: 20)).toIso8601String());
  } else if (actionId == 'sleep_reschedule') {
    // Reschedule bedtime by 30 mins
    log('Rescheduling bedtime by 30 mins.');
    final currentBedTimeStr = prefs.getString('bed_time');
    if (currentBedTimeStr != null) {
      final newBedTime = DateTime.parse(currentBedTimeStr).add(const Duration(minutes: 30));
      await prefs.setString('bed_time', newBedTime.toIso8601String());
      await prefs.setString('expected_sleep_start', newBedTime.toIso8601String());
      await LocalNotificationService.scheduleAllSleepNotifications(newBedTime, null); // Keep old wake time for now
    }
  } else if (actionId == 'alarm_snooze') {
    log('Snoozing morning alarm for 5 mins.');
    final snoozeTime = DateTime.now().add(const Duration(minutes: 5));
    await LocalNotificationService.scheduleMorningAlarm(snoozeTime);
  } else if (actionId == 'alarm_off') {
    log('Turning off alarm and saving sleep history.');
    // Logic to save sleep history is usually handled in the UI when the user opens the app,
    // or we can flag it here.
    await prefs.setBool('needs_to_save_sleep_history', true);
    await LocalNotificationService.cancelAllNotifications();
  }
}

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (kIsWeb) {
      log('LocalNotificationService: Web platform detected. Skipping local notifications initialization.');
      return;
    }
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Dhaka')); // Defaulting to local, should be dynamic if possible

      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // For iOS
      final DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          log('Foreground Notification Action Triggered: ${response.actionId}');
          _handleNotificationAction(response.actionId);
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      // Request Android 13+ permissions
      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
      }
    } catch (e) {
      log('Error initializing local notifications: $e');
    }
  }

  static Future<void> scheduleAllSleepNotifications(DateTime bedTime, DateTime? wakeUpTime) async {
    if (kIsWeb) return;
    await cancelAllNotifications();
    final prefs = await SharedPreferences.getInstance();
    
    // 1. 15 mins before bedtime
    final reminderTime = bedTime.subtract(const Duration(minutes: 15));
    if (reminderTime.isAfter(DateTime.now())) {
      await _scheduleNotification(
        id: 1,
        title: 'Sleep Reminder',
        body: 'It is almost time for bed. Please get ready!',
        scheduledDate: reminderTime,
        actions: [
          const AndroidNotificationAction('sleep_reschedule', 'Reschedule (+30m)', showsUserInterface: true),
        ],
      );
    }

    // 2. Exact bedtime
    if (bedTime.isAfter(DateTime.now())) {
      await _scheduleNotification(
        id: 2,
        title: 'Bed Time',
        body: 'Your sleep session has started. Good night!',
        scheduledDate: bedTime,
      );
      await prefs.setString('expected_sleep_start', bedTime.toIso8601String());
    } else {
      // If bedtime already passed for today, maybe they are already sleeping
      await prefs.setString('expected_sleep_start', DateTime.now().toIso8601String());
    }

    // 3. 10 mins after bedtime
    final checkupTime = bedTime.add(const Duration(minutes: 10));
    if (checkupTime.isAfter(DateTime.now())) {
      await _scheduleNotification(
        id: 3,
        title: 'Sleep Checkup',
        body: 'Are you still awake?',
        scheduledDate: checkupTime,
        playSound: false, // Silent
        actions: [
          const AndroidNotificationAction('sleep_awake', 'Yes, I am awake', showsUserInterface: true),
        ],
      );
    }

    // 4. Wake up alarm
    if (wakeUpTime != null && wakeUpTime.isAfter(DateTime.now())) {
      await scheduleMorningAlarm(wakeUpTime);
    }
  }

  static Future<void> scheduleCheckupNotification(Duration delay) async {
    if (kIsWeb) return;
    await _scheduleNotification(
      id: 3,
      title: 'Sleep Checkup',
      body: 'Are you still awake?',
      scheduledDate: DateTime.now().add(delay),
      playSound: false,
      actions: [
        const AndroidNotificationAction('sleep_awake', 'Yes, I am awake', showsUserInterface: true),
      ],
    );
  }

  static Future<void> scheduleMorningAlarm(DateTime wakeUpTime) async {
    if (kIsWeb) return;
    await _scheduleNotification(
      id: 4,
      title: '⏰ Good Morning!',
      body: 'Time to wake up and shine!',
      scheduledDate: wakeUpTime,
      playSound: true,
      enableVibration: true,
      actions: [
        const AndroidNotificationAction('alarm_snooze', 'Snooze (5m)', showsUserInterface: true),
        const AndroidNotificationAction('alarm_off', 'Turn Off', showsUserInterface: true),
      ],
    );
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    bool playSound = true,
    AndroidNotificationSound? sound,
    bool enableVibration = false,
    List<AndroidNotificationAction>? actions,
  }) async {
    if (kIsWeb) return;
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'sleep_tracker_channel',
      'Sleep Tracker Notifications',
      channelDescription: 'Handles sleep reminders and alarms',
      importance: Importance.max,
      priority: Priority.high,
      playSound: playSound,
      sound: sound,
      enableVibration: enableVibration,
      actions: actions,
    );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentSound: playSound,
      presentAlert: true,
      presentBadge: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancelAll();
  }

  static Future<void> scheduleTaskNotifications(Task task) async {
    if (kIsWeb) {
      log('LocalNotificationService: scheduleTaskNotifications called on Web. Bypassing native notifications.');
      return;
    }
    final int startId = task.id.hashCode;
    final int endId = startId + 1;

    // Cancel any existing notifications for this task first to avoid duplicate schedules
    await cancelTaskNotifications(task.id);

    final now = DateTime.now();

    // 1. Alert at task start time
    if (task.startTime != null && task.startTime!.isAfter(now)) {
      await _scheduleNotificationForTask(
        id: startId,
        title: '⏰ Task Starting: ${task.title}',
        body: 'It is time to start your scheduled task: ${task.title}.',
        scheduledDate: task.startTime!,
      );
      log('Scheduled start notification for task "${task.title}" at ${task.startTime}');
    }

    // 2. Alert 5 minutes before task end time
    if (task.endTime != null) {
      final warningTime = task.endTime!.subtract(const Duration(minutes: 5));
      if (warningTime.isAfter(now)) {
        await _scheduleNotificationForTask(
          id: endId,
          title: '⏳ Task Ending Soon: ${task.title}',
          body: 'Your task is ending in 5 minutes.',
          scheduledDate: warningTime,
        );
        log('Scheduled end warning notification for task "${task.title}" at $warningTime');
      }
    }
  }

  static Future<void> cancelTaskNotifications(String taskId) async {
    if (kIsWeb) return;
    final int startId = taskId.hashCode;
    final int endId = startId + 1;
    await _notificationsPlugin.cancel(id: startId);
    await _notificationsPlugin.cancel(id: endId);
    log('Cancelled notifications for task ID: $taskId');
  }

  static Future<void> _scheduleNotificationForTask({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (kIsWeb) return;
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_alerts_channel',
      'Task Alerts',
      channelDescription: 'Reminds you when tasks are starting or ending',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentSound: true,
      presentAlert: true,
      presentBadge: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> playNotificationSoundAndVibration({
    required String soundName,
    required double volume,
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) async {
    if (vibrationEnabled) {
      try {
        await HapticFeedback.vibrate();
      } catch (e) {
        log('Haptic feedback error: $e');
      }
    }
    if (!soundEnabled) return;

    String url;
    switch (soundName) {
      case 'Beep':
        url = 'https://assets.mixkit.co/active_storage/sfx/2869/2869-600.wav';
        break;
      case 'Chime':
        url = 'https://assets.mixkit.co/active_storage/sfx/911/911-600.wav';
        break;
      case 'Marimba':
        url = 'https://assets.mixkit.co/active_storage/sfx/1653/1653-600.wav';
        break;
      case 'Bell':
        url = 'https://assets.mixkit.co/active_storage/sfx/1987/1987-600.wav';
        break;
      case 'Digital':
        url = 'https://assets.mixkit.co/active_storage/sfx/2568/2568-600.wav';
        break;
      default:
        url = 'https://assets.mixkit.co/active_storage/sfx/2869/2869-600.wav';
    }

    try {
      final player = AudioPlayer();
      await player.setVolume(volume);
      await player.play(UrlSource(url));
    } catch (e) {
      log('Error playing custom notification sound: $e');
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  static Future<void> playCustomNotificationSound() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final settings = data['notificationSettings'] as Map<String, dynamic>?;
        if (settings != null) {
          final bool soundEnabled = settings['soundEnabled'] as bool? ?? true;
          final bool vibrationEnabled = settings['vibrationEnabled'] as bool? ?? true;
          final double volume = (settings['volumeLevel'] as num?)?.toDouble() ?? 0.8;
          final String soundName = settings['selectedSound'] as String? ?? 'Beep';

          await playNotificationSoundAndVibration(
            soundName: soundName,
            volume: volume,
            soundEnabled: soundEnabled,
            vibrationEnabled: vibrationEnabled,
          );
          return;
        }
      }
    } catch (e) {
      log('Error playing current settings sound: $e');
    }

    // Default fallback if settings fail to load
    try {
      await HapticFeedback.vibrate();
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }
}

