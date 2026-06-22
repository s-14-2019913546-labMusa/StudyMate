import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:developer';

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
  }

  static Future<void> scheduleAllSleepNotifications(DateTime bedTime, DateTime? wakeUpTime) async {
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
    await _notificationsPlugin.cancelAll();
  }
}
