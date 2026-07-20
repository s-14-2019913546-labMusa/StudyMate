import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:developer';
import 'dart:io';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'daily_routine.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handle background actions here
  log(
    'Background Notification Action Triggered: ${notificationResponse.actionId}',
  );
  _handleNotificationAction(notificationResponse.actionId);
}

Future<void> _handleNotificationAction(String? actionId) async {
  if (actionId == null) return;

  // Initialize timezone in background isolate before using any tz functions
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

  final prefs = await SharedPreferences.getInstance();

  if (actionId == 'sleep_awake' || actionId == 'sleep_awake_dismissed') {
    // User is awake, show warning popup
    log('User is awake, showing warning popup.');
    await LocalNotificationService.scheduleNotification(
      id: 5,
      title: 'দুষ্টু, ঘুমিয়ে পড়ো!',
      body: 'এখনই ঘুমাতে যান, না হলে কাল সকালে উঠতে কষ্ট হবে।',
      scheduledDate: DateTime.now().add(const Duration(seconds: 2)),
      fullScreenIntent: true,
      actions: [
        const AndroidNotificationAction(
          'sleep_reschedule_30m',
          'নতুন টাইমার (+30m)',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'sleep_now_ok',
          'এখনি ঘুমুচ্ছি',
          showsUserInterface: true,
        ),
      ],
    );
  } else if (actionId == 'sleep_reschedule_30m' || actionId == 'sleep_reschedule_1h') {
    final int extraMins = actionId == 'sleep_reschedule_30m' ? 30 : 60;
    log('Rescheduling bedtime by $extraMins mins.');
    final currentBedTimeStr = prefs.getString('bed_time');
    if (currentBedTimeStr != null) {
      final newBedTime = DateTime.parse(currentBedTimeStr).add(Duration(minutes: extraMins));
      await prefs.setString('bed_time', newBedTime.toIso8601String());
      await prefs.setString('expected_sleep_start', newBedTime.toIso8601String());
      await LocalNotificationService.scheduleAllSleepNotifications(newBedTime, null);
    }
  } else if (actionId == 'sleep_prepare_ok') {
    log('User is preparing to sleep. Bedtime alarm will ring at exact time.');
    // Nothing to do, exact bedtime alarm is already scheduled.
  } else if (actionId == 'sleep_now_ok') {
    log('User started sleeping now.');
    final now = DateTime.now();
    await prefs.setString('expected_sleep_start', now.toIso8601String());
    
    // Schedule checkup for 15 mins later
    await LocalNotificationService.scheduleCheckupNotification(const Duration(minutes: 15));
  } else if (actionId == 'alarm_snooze') {
    log('Snoozing morning alarm for 5 mins.');
    final snoozeTime = DateTime.now().add(const Duration(minutes: 5));
    await LocalNotificationService.scheduleMorningAlarm(snoozeTime);
  } else if (actionId == 'alarm_off') {
    log('Turning off alarm and saving sleep history.');
    await prefs.setBool('needs_to_save_sleep_history', true);
    await LocalNotificationService.cancelAllNotifications();
  }
}

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (kIsWeb) {
      log(
        'LocalNotificationService: Web platform detected. Skipping local notifications initialization.',
      );
      return;
    }
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(
        tz.getLocation('Asia/Dhaka'),
      ); // Defaulting to local, should be dynamic if possible

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // For iOS
      final DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      final InitializationSettings initializationSettings =
          InitializationSettings(
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
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
      }

      // Clear past notifications right away on initialization
      await clearPastPrayerNotifications();

      // Schedule daily special day countdown reminder
      await scheduleDailySpecialDayCountdownReminder();
    } catch (e) {
      log('Error initializing local notifications: $e');
    }
  }

  static Future<void> scheduleAllSleepNotifications(
    DateTime bedTime,
    DateTime? wakeUpTime,
  ) async {
    if (kIsWeb) return;
    await cancelAllNotifications();
    final prefs = await SharedPreferences.getInstance();

    // 1. 15 mins before bedtime
    final reminderTime = bedTime.subtract(const Duration(minutes: 15));
    if (reminderTime.isAfter(DateTime.now())) {
      await scheduleNotification(
        id: 1,
        title: 'Sleep Reminder',
        body: 'বিছানা গুছাও, ঘুমানোর সময় হয়েছে',
        scheduledDate: reminderTime,
        fullScreenIntent: true,
        actions: [
          const AndroidNotificationAction(
            'sleep_reschedule_30m',
            '+ 30m',
            showsUserInterface: true,
          ),
          const AndroidNotificationAction(
            'sleep_reschedule_1h',
            '+ 1h',
            showsUserInterface: true,
          ),
          const AndroidNotificationAction(
            'sleep_prepare_ok',
            'ওকে প্রস্তুতি নিচ্ছি',
            showsUserInterface: true,
          ),
        ],
      );
    }

    // 2. Exact bedtime
    if (bedTime.isAfter(DateTime.now())) {
      await scheduleNotification(
        id: 2,
        title: 'Bed Time',
        body: 'ঘুমানোর সময় হয়েছে, ঘুমাও!',
        scheduledDate: bedTime,
        fullScreenIntent: true,
        actions: [
          const AndroidNotificationAction(
            'sleep_now_ok',
            'ওকে',
            showsUserInterface: true,
          ),
        ],
      );
      await prefs.setString('expected_sleep_start', bedTime.toIso8601String());
    } else {
      await prefs.setString(
        'expected_sleep_start',
        DateTime.now().toIso8601String(),
      );
    }

    // 3. 15 mins after bedtime checkup
    final checkupTime = bedTime.add(const Duration(minutes: 15));
    if (checkupTime.isAfter(DateTime.now())) {
      await scheduleCheckupNotification(const Duration(minutes: 15), fromNow: false, checkupTime: checkupTime);
    }

    // 4. Wake up alarm
    if (wakeUpTime != null && wakeUpTime.isAfter(DateTime.now())) {
      await scheduleMorningAlarm(wakeUpTime);
    }
  }

  static Future<void> scheduleCheckupNotification(Duration delay, {bool fromNow = true, DateTime? checkupTime}) async {
    if (kIsWeb) return;
    await scheduleNotification(
      id: 3,
      title: 'Sleep Checkup',
      body: 'ঘুমিয়েছ?',
      scheduledDate: fromNow ? DateTime.now().add(delay) : checkupTime!,
      playSound: false, // Silent
      fullScreenIntent: true,
      timeoutAfter: 60000, // 1 minute timeout
      actions: [
        const AndroidNotificationAction(
          'sleep_awake',
          'আমি জেগে আছি',
          showsUserInterface: true,
        ),
      ],
    );
  }

  static Future<void> scheduleMorningAlarm(DateTime wakeUpTime) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final repeatCount = prefs.getString('sleepAlarmRepeatCount') ?? 'loop';
    final isInsistent = repeatCount == 'loop';
    final sound = await _getAndroidSoundForType(true, isSleepAlarm: true);
    await scheduleNotification(
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
      insistent: isInsistent,
      fullScreenIntent: true,
      actions: [
        const AndroidNotificationAction(
          'alarm_snooze',
          'Snooze (5m)',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'alarm_off',
          'Turn Off',
          showsUserInterface: true,
        ),
      ],
    );
  }

  static Future<AndroidNotificationSound?> _getAndroidSoundForType(
    bool isAlarm, {
    bool isSleepAlarm = false,
    bool isPrayerAlarm = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String soundPath = isAlarm ? 'Alarm' : 'Notification';

      if (isSleepAlarm) {
        soundPath = prefs.getString('selectedSleepAlarmSound') ?? 'Alarm';
      } else if (isPrayerAlarm) {
        try {
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/islamic_notif_settings.json');
          if (await file.exists()) {
            final decoded =
                json.decode(await file.readAsString()) as Map<String, dynamic>;
            soundPath =
                decoded['selectedPrayerAlarmSound'] as String? ?? 'Alarm';
          }
        } catch (e) {
          log('Error loading prayer alarm sound: $e');
        }
      } else {
        final soundKey = isAlarm ? 'selectedAlarmSound' : 'selectedPushSound';
        final defaultSound = isAlarm ? 'Alarm' : 'Notification';
        soundPath = prefs.getString(soundKey) ?? defaultSound;
      }

      if (soundPath.startsWith('content://') ||
          soundPath.startsWith('file://')) {
        return UriAndroidNotificationSound(soundPath);
      }

      // Check if it is a premium built-in sound downloaded locally
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$soundPath.wav');
      if (await file.exists()) {
        return UriAndroidNotificationSound('file://${file.path}');
      }

      // If it's a premium built-in sound not downloaded, map it to Alarm system sound or default Notification system sound
      if (soundPath == 'Alarm' ||
          soundPath == 'retro_alarm' ||
          soundPath == 'gentle_buzzer' ||
          (isAlarm && soundPath != 'Notification')) {
        return const UriAndroidNotificationSound(
          'content://settings/system/alarm_alert',
        );
      } else if (soundPath == 'Ringtone') {
        return const UriAndroidNotificationSound(
          'content://settings/system/ringtone',
        );
      } else {
        return const UriAndroidNotificationSound(
          'content://settings/system/notification_sound',
        );
      }
    } catch (e) {
      log('Error getting sound for notification: $e');
      return null;
    }
  }

  static Future<void> schedulePrayerNotifications(
    Map<String, String> timings,
    Map<String, dynamic> settings,
  ) async {
    if (kIsWeb) return;

    // Cancel existing scheduled prayer notifications (range 1000 to 1100)
    for (int id = 1000; id <= 1100; id++) {
      await _notificationsPlugin.cancel(id: id);
    }

    final now = DateTime.now();
    final List<String> prayerKeys = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final Map<String, String> prayerNames = {
      'Fajr': 'ফজর',
      'Dhuhr': 'যোহর',
      'Asr': 'আসর',
      'Maghrib': 'মাগরিব',
      'Isha': 'এশা',
    };
    final Map<String, int> prayerIndices = {
      'Fajr': 0,
      'Dhuhr': 1,
      'Asr': 2,
      'Maghrib': 3,
      'Isha': 4,
    };

    // Schedule for today and the next 6 days (total 7 days)
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final targetDate = now.add(Duration(days: dayOffset));

      for (final pKey in prayerKeys) {
        final startStr = timings[pKey];
        if (startStr == null) continue;

        // Parse start time for target date
        final startParts = startStr.split(':');
        final startHour = int.parse(startParts[0]);
        final startMin = int.parse(startParts[1]);
        final start = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          startHour,
          startMin,
        );

        // Determine end time to calculate warning
        DateTime end;
        if (pKey == 'Fajr') {
          final sunriseStr = timings['Sunrise'] ?? '06:00';
          final sunriseParts = sunriseStr.split(':');
          end = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            int.parse(sunriseParts[0]),
            int.parse(sunriseParts[1]),
          );
        } else if (pKey == 'Dhuhr') {
          final asrStr = timings['Asr'] ?? '16:00';
          final asrParts = asrStr.split(':');
          end = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            int.parse(asrParts[0]),
            int.parse(asrParts[1]),
          );
        } else if (pKey == 'Asr') {
          final maghribStr = timings['Maghrib'] ?? '18:30';
          final maghribParts = maghribStr.split(':');
          end = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            int.parse(maghribParts[0]),
            int.parse(maghribParts[1]),
          );
        } else if (pKey == 'Maghrib') {
          final ishaStr = timings['Isha'] ?? '20:00';
          final ishaParts = ishaStr.split(':');
          end = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            int.parse(ishaParts[0]),
            int.parse(ishaParts[1]),
          );
        } else {
          // Isha
          // End of Isha is Fajr of next day
          final nextDay = targetDate.add(const Duration(days: 1));
          final fajrStr = timings['Fajr'] ?? '04:30';
          final fajrParts = fajrStr.split(':');
          end = DateTime(
            nextDay.year,
            nextDay.month,
            nextDay.day,
            int.parse(fajrParts[0]),
            int.parse(fajrParts[1]),
          );
        }

        final pIndex = prayerIndices[pKey]!;
        // Deterministic IDs: 1000 + (dayOffset * 10) + (pIndex * 2) + type
        final int startId = 1000 + (dayOffset * 10) + (pIndex * 2) + 0;
        final int endId = 1000 + (dayOffset * 10) + (pIndex * 2) + 1;

        // 1. 5 minutes after start
        if (settings['prayerStart'] ?? true) {
          final alarmTime = start.add(const Duration(minutes: 5));
          if (alarmTime.isAfter(now)) {
            final pName =
                (pKey == 'Dhuhr' && targetDate.weekday == DateTime.friday)
                ? 'জুমা'
                : prayerNames[pKey]!;
            final isAlarmEnabled = settings['prayerAlarmEnabled'] ?? false;
            final sound = isAlarmEnabled
                ? await _getAndroidSoundForType(true, isPrayerAlarm: true)
                : null;

            // Get sound path for unique channel ID
            String soundSuffix = 'default';
            if (isAlarmEnabled) {
              try {
                final directory = await getApplicationDocumentsDirectory();
                final file = File(
                  '${directory.path}/islamic_notif_settings.json',
                );
                if (await file.exists()) {
                  final decoded =
                      json.decode(await file.readAsString())
                          as Map<String, dynamic>;
                  soundSuffix =
                      (decoded['selectedPrayerAlarmSound'] as String? ??
                              'Alarm')
                          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
                }
              } catch (_) {}
            }
            final channelId = isAlarmEnabled
                ? 'islamic_prayers_alarm_$soundSuffix'
                : 'islamic_prayers_channel';

            await scheduleNotification(
              id: startId,
              title: "সালাতের ওয়াক্ত",
              body:
                  "$pName সালাতের ওয়াক্ত শুরু হয়েছে! ৫ মিনিট অতিবাহিত হয়েছে।",
              scheduledDate: alarmTime,
              channelId: channelId,
              channelName: isAlarmEnabled
                  ? 'Prayer Time Alarms'
                  : 'Prayer Time Alerts',
              channelDescription: 'Reminders for daily prayer times',
              enableVibration: true,
              playSound: true,
              sound: sound,
              insistent: isAlarmEnabled,
            );
          }
        }

        // 2. 20 minutes before end
        if (settings['prayerWarning'] ?? true) {
          final alarmTime = end.subtract(const Duration(minutes: 20));
          if (alarmTime.isAfter(now)) {
            final pName = prayerNames[pKey]!;
            await scheduleNotification(
              id: endId,
              title: "তাড়াতাড়ি করুন!",
              body:
                  "সতর্কতা: $pName নামাজের ওয়াক্ত শেষ হতে আর মাত্র ২০ মিনিট বাকি আছে!",
              scheduledDate: alarmTime,
              channelId: 'islamic_prayers_channel',
              channelName: 'Prayer Time Alerts',
              channelDescription: 'Reminders for daily prayer times',
              enableVibration: true,
              playSound: true,
            );
          }
        }
      }
    }
  }

  static Future<void> clearPastPrayerNotifications() async {
    if (kIsWeb) return;
    try {
      final now = DateTime.now();
      // Load cached prayer times to know the timings
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/prayer_times_cache.json');
      if (!await file.exists()) return;

      final data = json.decode(await file.readAsString());
      final timings = Map<String, String>.from(data['timings']);

      final List<String> prayerKeys = [
        'Fajr',
        'Dhuhr',
        'Asr',
        'Maghrib',
        'Isha',
      ];
      final Map<String, int> prayerIndices = {
        'Fajr': 0,
        'Dhuhr': 1,
        'Asr': 2,
        'Maghrib': 3,
        'Isha': 4,
      };

      for (final pKey in prayerKeys) {
        // Determine end time
        DateTime end;
        if (pKey == 'Fajr') {
          final sunriseStr = timings['Sunrise'] ?? '06:00';
          final sunriseParts = sunriseStr.split(':');
          end = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(sunriseParts[0]),
            int.parse(sunriseParts[1]),
          );
        } else if (pKey == 'Dhuhr') {
          final asrStr = timings['Asr'] ?? '16:00';
          final asrParts = asrStr.split(':');
          end = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(asrParts[0]),
            int.parse(asrParts[1]),
          );
        } else if (pKey == 'Asr') {
          final maghribStr = timings['Maghrib'] ?? '18:30';
          final maghribParts = maghribStr.split(':');
          end = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(maghribParts[0]),
            int.parse(maghribParts[1]),
          );
        } else if (pKey == 'Maghrib') {
          final ishaStr = timings['Isha'] ?? '20:00';
          final ishaParts = ishaStr.split(':');
          end = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(ishaParts[0]),
            int.parse(ishaParts[1]),
          );
        } else {
          // Isha
          final nextDay = now.add(const Duration(days: 1));
          final fajrStr = timings['Fajr'] ?? '04:30';
          final fajrParts = fajrStr.split(':');
          end = DateTime(
            nextDay.year,
            nextDay.month,
            nextDay.day,
            int.parse(fajrParts[0]),
            int.parse(fajrParts[1]),
          );

          // If we are currently after midnight but before Fajr, the Isha start and end are from yesterday
          if (now.hour < 12 &&
              now.isBefore(end.subtract(const Duration(days: 1)))) {
            end = end.subtract(const Duration(days: 1));
          }
        }

        // If the current time is past the end time of this prayer, cancel its notifications
        if (now.isAfter(end)) {
          final pIndex = prayerIndices[pKey]!;
          final int startId = 1000 + (0 * 10) + (pIndex * 2) + 0;
          final int endId = 1000 + (0 * 10) + (pIndex * 2) + 1;
          await _notificationsPlugin.cancel(id: startId);
          await _notificationsPlugin.cancel(id: endId);
          log(
            'Cleared past prayer notifications for $pKey (IDs: $startId, $endId)',
          );
        }
      }
    } catch (e) {
      log('Error clearing past prayer notifications: $e');
    }
  }

  static Future<void> scheduleNotification({
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
    DateTimeComponents? matchDateTimeComponents,
    bool insistent = false,
    bool fullScreenIntent = false,
    int? timeoutAfter,
  }) async {
    if (kIsWeb) return;

    // Generate dynamic channel ID to force Android to update sounds when changed
    String finalChannelId = channelId;
    if (sound != null && sound is UriAndroidNotificationSound) {
      // We don't have direct access to the string safely across all versions,
      // but we can just use the hashcode of the sound object to make it unique
      finalChannelId = '${channelId}_${sound.hashCode}';
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          finalChannelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: playSound,
          sound: sound,
          enableVibration: enableVibration,
          actions: actions,
          additionalFlags: insistent ? Int32List.fromList([4]) : null,
          fullScreenIntent: fullScreenIntent,
          timeoutAfter: timeoutAfter,
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
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  static Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancelAll();
  }

  // ============================================================
  // Special Day Countdown Notification Method
  // Notification ID: 1500 (reserved for this daily reminder)
  // ============================================================
  static Future<void> scheduleDailySpecialDayCountdownReminder() async {
    if (kIsWeb) return;

    final now = DateTime.now();
    // Schedule for 11:00 PM today
    DateTime scheduledDate = DateTime(now.year, now.month, now.day, 23, 0);

    // If it's already past 11 PM today, schedule for 11 PM tomorrow
    if (now.isAfter(scheduledDate)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await scheduleNotification(
      id: 1500, // Fixed ID for the daily countdown reminder
      title: 'Special Day Countdown ⏳',
      body:
          'চেক করুন স্পেশাল ডে কাউন্টডাউন। আপনার ইভেন্টগুলোর আর কতদিন বাকি দেখে নিন!',
      scheduledDate: scheduledDate,
      channelId: 'special_day_channel',
      channelName: 'Special Day Reminders',
      channelDescription:
          'Daily reminders to check your special day countdowns',
      matchDateTimeComponents:
          DateTimeComponents.time, // Repeats daily at the same time
    );
    log('Scheduled daily Special Day Countdown reminder at 11:00 PM.');
  }

  // ============================================================
  // 1-4-7 Revision Notification Methods
  // Notification ID range: 2000 - 2999
  // ============================================================

  /// Schedule push notifications for a task on day 1, day 4, and day 7 from [taskDate].
  /// Each unique task title uses a consistent hash-based ID range within 2000-2999.
  static Future<void> scheduleRevisionNotifications({
    required String taskTitle,
    required String taskSubject,
    required DateTime taskDate,
  }) async {
    if (kIsWeb) return;

    final String label = taskSubject.isNotEmpty ? taskSubject : taskTitle;
    final int baseId = 2000 + (taskTitle.hashCode.abs() % 900);

    final List<int> revisionDays = [1, 4, 7];

    for (int i = 0; i < revisionDays.length; i++) {
      final int dayOffset = revisionDays[i];
      // Schedule at 8:00 AM on the revision day
      final DateTime revisionDate = DateTime(
        taskDate.year,
        taskDate.month,
        taskDate.day + dayOffset,
        8, // 8:00 AM
        0,
      );

      if (revisionDate.isAfter(DateTime.now())) {
        final int notifId = baseId + i;
        final String dayLabel = dayOffset == 1
            ? '১ দিন'
            : (dayOffset == 4 ? '৪ দিন' : '৭ দিন');

        await scheduleNotification(
          id: notifId,
          title: '📖 রিভিশনের সময়! ($dayLabel পূর্বে)',
          body:
              '"$label" রিভিশন দেওয়ার এখনই সময়। ১-৪-৭ পদ্ধতিতে পড়া মনে রাখুন!',
          scheduledDate: revisionDate,
          channelId: 'revision_147_channel',
          channelName: '1-4-7 Revision Reminders',
          channelDescription:
              'Reminds you to revise topics using the 1-4-7 spaced repetition method',
          playSound: true,
          enableVibration: true,
        );
        log(
          'Scheduled 1-4-7 revision notification for "$taskTitle" on day $dayOffset at $revisionDate (id=$notifId)',
        );
      }
    }
  }

  /// Cancel all revision notifications for a specific task title.
  static Future<void> cancelRevisionNotifications(String taskTitle) async {
    if (kIsWeb) return;
    final int baseId = 2000 + (taskTitle.hashCode.abs() % 900);
    for (int i = 0; i < 3; i++) {
      await _notificationsPlugin.cancel(id: baseId + i);
    }
    log('Cancelled 1-4-7 revision notifications for task: $taskTitle');
  }

  static Future<void> scheduleTaskNotifications(Task task) async {
    if (kIsWeb) {
      log(
        'LocalNotificationService: scheduleTaskNotifications called on Web. Bypassing native notifications.',
      );
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

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Just save to Firestore so it appears in history
        await NotificationService.sendNotification(
          user.uid,
          '⏰ Task Starting: ${task.title}',
          'It is time to start your scheduled task: ${task.title}.',
          type: 'task',
          scheduledTime: task.startTime!,
        );
      }
      log(
        'Scheduled start notification for task "${task.title}" at ${task.startTime}',
      );
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
        log(
          'Scheduled end warning notification for task "${task.title}" at $warningTime',
        );
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
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
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
  static final AudioPlayer _appAudioPlayer = AudioPlayer();

  static Future<void> playNotificationSoundAndVibration({
    required String soundName,
    required double volume,
    required bool soundEnabled,
    required bool vibrationEnabled,
    bool isAlarm = false,
    bool looping = false,
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

    String finalSoundPath = soundName;
    if (!soundName.startsWith('content://') &&
        !soundName.startsWith('file://') &&
        soundName != 'Alarm' &&
        soundName != 'Notification' &&
        soundName != 'Ringtone' &&
        soundName != 'retro_alarm' &&
        soundName != 'gentle_buzzer') {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$soundName.wav');
        if (await file.exists()) {
          finalSoundPath = 'file://${file.path}';
        }
      } catch (e) {
        log('Error resolving custom sound path: $e');
      }
    }

    // If a custom sound URI is selected, use AudioPlayer to play it.
    if (finalSoundPath.startsWith('content://') ||
        finalSoundPath.startsWith('file://')) {
      try {
        final path = finalSoundPath.replaceFirst('file://', '');
        await _appAudioPlayer.setVolume(volume);
        if (looping) {
          await _appAudioPlayer.setReleaseMode(ReleaseMode.loop);
        } else {
          await _appAudioPlayer.setReleaseMode(ReleaseMode.release);
        }
        await _appAudioPlayer.play(DeviceFileSource(path));
        log('Playing custom local sound: $finalSoundPath (looping: $looping)');
      } catch (e) {
        log('Error playing custom local sound: $e');
      }
      return;
    }

    try {
      // Using system sounds which is reliable offline
      if (isAlarm) {
        if (soundName == 'Ringtone') {
          await FlutterRingtonePlayer().playRingtone(
            volume: volume,
            looping: looping,
          );
        } else if (soundName == 'Notification') {
          await FlutterRingtonePlayer().playNotification(
            volume: volume,
            looping: looping,
          );
        } else {
          await FlutterRingtonePlayer().playAlarm(
            volume: volume,
            looping: looping,
          );
        }
      } else {
        // Push notification / General sounds
        if (soundName == 'Alarm') {
          await FlutterRingtonePlayer().playAlarm(
            volume: volume,
            looping: looping,
          );
        } else if (soundName == 'Ringtone') {
          await FlutterRingtonePlayer().playRingtone(
            volume: volume,
            looping: looping,
          );
        } else {
          await FlutterRingtonePlayer().playNotification(
            volume: volume,
            looping: looping,
          );
        }
      }
      log(
        'Playing system sound: $soundName (isAlarm: $isAlarm, looping: $looping)',
      );
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
      final String soundName =
          prefs.getString('selectedPushSound') ?? 'Notification';

      await playNotificationSoundAndVibration(
        soundName: soundName,
        volume: volume,
        soundEnabled: soundEnabled,
        vibrationEnabled: vibrationEnabled,
        isAlarm: false,
        looping: false,
      );
    } catch (e) {
      log('Error playing Push sound: $e');
    }
  }

  // Wrapper method to play Alarm sound
  static Future<void> playAlarmNotificationSound({bool looping = false}) async {
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
        looping: looping,
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
