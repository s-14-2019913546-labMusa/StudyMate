import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:developer';
import 'dart:io';
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
    final sound = await _getAndroidSoundForType(true);
    await _scheduleNotification(
      id: 4,
      title: '⏰ Good Morning!',
      body: 'Time to wake up and shine!',
      scheduledDate: wakeUpTime,
      playSound: true,
      sound: sound,
      channelId: 'morning_alarm_channel',
      channelName: 'Morning Alarm Notifications',
      channelDescription: 'Handles wake-up alarms with louder sounds',
      enableVibration: true,
      actions: [
        const AndroidNotificationAction('alarm_snooze', 'Snooze (5m)', showsUserInterface: true),
        const AndroidNotificationAction('alarm_off', 'Turn Off', showsUserInterface: true),
      ],
    );
  }

  static Future<AndroidNotificationSound?> _getAndroidSoundForType(bool isAlarm) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final soundKey = isAlarm ? 'selectedAlarmSound' : 'selectedPushSound';
      final defaultSound = isAlarm ? 'Alarm' : 'Notification';
      final soundPath = prefs.getString(soundKey) ?? defaultSound;

      if (soundPath.startsWith('content://') || soundPath.startsWith('file://')) {
        return UriAndroidNotificationSound(soundPath);
      }
      
      // Check if it is a premium built-in sound downloaded locally
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$soundPath.wav');
      if (await file.exists()) {
        return UriAndroidNotificationSound('file://${file.path}');
      }
      
      // If it's a premium built-in sound not downloaded, map it to Alarm system sound or default Notification system sound
      if (soundPath == 'Alarm' || soundPath == 'retro_alarm' || soundPath == 'gentle_buzzer' || (isAlarm && soundPath != 'Notification')) {
        return const UriAndroidNotificationSound('content://settings/system/alarm_alert');
      } else if (soundPath == 'Ringtone') {
        return const UriAndroidNotificationSound('content://settings/system/ringtone');
      } else {
        return const UriAndroidNotificationSound('content://settings/system/notification_sound');
      }
    } catch (e) {
      log('Error getting sound for notification: $e');
      return null;
    }
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    bool playSound = true,
    AndroidNotificationSound? sound,
    String channelId = 'sleep_tracker_channel',
    String channelName = 'Sleep Tracker Notifications',
    String channelDescription = 'Handles sleep reminders and alarms',
    bool enableVibration = false,
    List<AndroidNotificationAction>? actions,
  }) async {
    if (kIsWeb) return;
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
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
    final sound = await _getAndroidSoundForType(false); // Push sound
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_alerts_channel',
      'Task Alerts',
      channelDescription: 'Reminds you when tasks are starting or ending',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: sound,
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
}

class SoundPlayer {
  static final Map<String, String> _builtInSoundUrls = {
    'lively_chime': 'https://assets.mixkit.co/active_storage/sfx/2869/2869-120.wav',
    'sweet_melody': 'https://assets.mixkit.co/active_storage/sfx/2019/2019-120.wav',
    'gentle_buzzer': 'https://assets.mixkit.co/active_storage/sfx/911/911-120.wav',
    'retro_alarm': 'https://assets.mixkit.co/active_storage/sfx/903/903-120.wav',
    'calm_bell': 'https://assets.mixkit.co/active_storage/sfx/1657/1657-120.wav',
  };

  static final AudioPlayer _appAudioPlayer = AudioPlayer();

  static Future<void> playNotificationSoundAndVibration({
    required String soundName,
    required double volume,
    required bool soundEnabled,
    required bool vibrationEnabled,
    bool isAlarm = false,
  }) async {
    // Stop any currently playing sound first
    try {
      await FlutterRingtonePlayer().stop();
      await _appAudioPlayer.stop();
    } catch (e) {
      log('Could not stop ringtone player: $e');
    }

    if (vibrationEnabled) {
      try {
        await HapticFeedback.vibrate();
      } catch (e) {
        log('Haptic feedback error: $e');
      }
    }

    if (!soundEnabled) return;

    // If a custom sound URI is selected, use that.
    if (soundName.startsWith('content://') || soundName.startsWith('file://')) {
      // This part is for instant playback preview.
      // The actual notification sound is handled by `_scheduleNotificationForTask`.
      // `flutter_ringtone_player` cannot play URIs, so we'll rely on the notification itself for sound.
      // For a quick preview, we can play a default system click.
      await SystemSound.play(SystemSoundType.click);
      return;
    }

    // Configure audio context based on stream type (Alarm vs Notification)
    try {
      if (isAlarm) {
        await _appAudioPlayer.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              usageType: AndroidUsageType.alarm,
              contentType: AndroidContentType.music,
              audioFocus: AndroidAudioFocus.gainTransient,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: {
                AVAudioSessionOptions.duckOthers,
                AVAudioSessionOptions.defaultToSpeaker,
              },
            ),
          ),
        );
      } else {
        await _appAudioPlayer.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              usageType: AndroidUsageType.notification,
              contentType: AndroidContentType.sonification,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.ambient,
              options: {
                AVAudioSessionOptions.duckOthers,
              },
            ),
          ),
        );
      }
    } catch (e) {
      log('Error setting audio context: $e');
    }

    // Try playing local downloaded custom sound file first
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$soundName.wav');
      if (await file.exists()) {
        await _appAudioPlayer.stop();
        await _appAudioPlayer.setVolume(volume);
        await _appAudioPlayer.play(DeviceFileSource(file.path));
        log('Successfully playing local custom sound: $soundName from path: ${file.path}');
        return;
      }
    } catch (e) {
      log('Error playing local cached sound $soundName: $e. Checking online fallback.');
    }

    // Try playing built-in custom premium sound via AudioPlayer
    if (_builtInSoundUrls.containsKey(soundName)) {
      try {
        final audioUrl = _builtInSoundUrls[soundName]!;
        await _appAudioPlayer.stop();
        await _appAudioPlayer.setVolume(volume);
        await _appAudioPlayer.play(UrlSource(audioUrl));
        log('Successfully playing premium sound: $soundName from URL: $audioUrl');
        return;
      } catch (e) {
        log('Error playing premium sound $soundName via AudioPlayer: $e. Falling back to system default.');
        // Fall through to standard system sounds
      }
    }

    try {
      // Using system sounds which is more reliable
      if (isAlarm) {
        if (soundName == 'Ringtone') {
          await FlutterRingtonePlayer().playRingtone(volume: volume, looping: false);
        } else {
          await FlutterRingtonePlayer().playAlarm(volume: volume, looping: false);
        }
      } else {
        // Push notification / General sounds always play via playNotification stream (shorter and quieter)
        await FlutterRingtonePlayer().playNotification(volume: volume, looping: false);
      }
      log('Playing system sound: $soundName (isAlarm: $isAlarm)');
    } catch (e) {
      log('Error playing system sound: $e. Falling back to system click.');
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (fallbackError) {
        log('Could not play system fallback sound: $fallbackError');
      }
    }
  }

  // Wrapper method to play Push sound
  static Future<void> playPushNotificationSound() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool soundEnabled = prefs.getBool('soundEnabled') ?? true;
      final bool vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
      final double volume = prefs.getDouble('volumeLevel') ?? 0.8;
      final String soundName = prefs.getString('selectedPushSound') ?? 'Notification';

      await playNotificationSoundAndVibration(
        soundName: soundName,
        volume: volume,
        soundEnabled: soundEnabled,
        vibrationEnabled: vibrationEnabled,
        isAlarm: false,
      );
    } catch (e) {
      log('Error playing Push sound: $e');
    }
  }

  // Wrapper method to play Alarm sound
  static Future<void> playAlarmNotificationSound() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool soundEnabled = prefs.getBool('soundEnabled') ?? true;
      final bool vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
      final double volume = prefs.getDouble('volumeLevel') ?? 0.8;
      final String soundName = prefs.getString('selectedAlarmSound') ?? 'Alarm';

      await playNotificationSoundAndVibration(
        soundName: soundName,
        volume: volume,
        soundEnabled: soundEnabled,
        vibrationEnabled: vibrationEnabled,
        isAlarm: true,
      );
    } catch (e) {
      log('Error playing Alarm sound: $e');
    }
  }

  // Stop any currently playing alarm / audio
  static Future<void> stopAlarm() async {
    try {
      await _appAudioPlayer.stop();
    } catch (e) {
      log('Error stopping AudioPlayer: $e');
    }
    try {
      await FlutterRingtonePlayer().stop();
    } catch (e) {
      log('Error stopping FlutterRingtonePlayer: $e');
    }
  }
}

Future<void> playCustomNotificationSound() async {
  await SoundPlayer.playPushNotificationSound();
}
