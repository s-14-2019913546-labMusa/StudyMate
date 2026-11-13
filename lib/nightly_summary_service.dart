import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_notification_service.dart';

/// রাতের সারাংশ নোটিফিকেশন: "আজ ৩ ঘণ্টা ২০ মিনিট পড়েছেন, ৫টার মধ্যে ৪টা টাস্ক শেষ, কাল ৬টা টাস্ক আছে"
/// অ্যাপ খুললে আর টাস্ক বদলালে আজকের হিসাব দিয়ে আবার সেট করা হয়।
class NightlySummaryService {
  /// রাতের সারাংশের গায়ে চাপলে বটে "কালকের প্ল্যান" খোলে
  static const String openBotPlan = 'open:bot_plan';

  static const int notificationId = 777001;
  static const String enabledKey = 'nightly_summary_enabled';
  static const String hourKey = 'nightly_summary_hour';
  static const String minuteKey = 'nightly_summary_minute';
  static const String languageKey = 'app_language';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(enabledKey) ?? true;
  }

  static Future<(int, int)> getTime() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(hourKey) ?? 21, prefs.getInt(minuteKey) ?? 30);
  }

  static Future<void> setEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, v);
    if (v) {
      await refresh();
    } else {
      await LocalNotificationService.cancelNotification(notificationId);
    }
  }

  static Future<void> setTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(hourKey, hour);
    await prefs.setInt(minuteKey, minute);
    await refresh();
  }

  static String _bnNum(Object n) {
    const bn = '০১২৩৪৫৬৭৮৯';
    return n.toString().split('').map((c) {
      final i = c.codeUnitAt(0) - 48;
      return (i >= 0 && i <= 9) ? bn[i] : c;
    }).join();
  }

  static int _taskSeconds(Map<String, dynamic> t) {
    final status = t['status'];
    final elapsed = (t['elapsedSeconds'] as num?)?.toInt() ?? 0;
    if (elapsed > 0) return elapsed;
    if (status == 'completed' || t['isCompleted'] == true) {
      return ((t['totalDurationMinutes'] as num?)?.toInt() ?? 0) * 60;
    }
    return 0;
  }

  /// আজকের হিসাব নিয়ে আজ রাতের নোটিফিকেশন আবার সেট করে
  static Future<void> refresh() async {
    if (kIsWeb) return;
    try {
      if (!await isEnabled()) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final (hour, minute) = await getTime();
      final now = DateTime.now();
      var when = DateTime(now.year, now.month, now.day, hour, minute);
      if (!when.isAfter(now)) {
        // আজকের সময় পার হয়ে গেছে: কালকের জন্য রাখা হবে (কাল অ্যাপ খুললে আবার হালনাগাদ হবে)
        when = when.add(const Duration(days: 1));
      }
      final reportDay = DateTime(when.year, when.month, when.day);
      final nextDay = reportDay.add(const Duration(days: 1));
      final fmt = DateFormat('yyyy-MM-dd');
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // আজকের টাস্ক
      final todaySnap = await userRef.collection('dailyRoutines').doc(fmt.format(reportDay)).get();
      final todayTasks = List<Map<String, dynamic>>.from(
        (todaySnap.data()?['tasks'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      final total = todayTasks.length;
      final done = todayTasks.where((t) => t['status'] == 'completed' || t['isCompleted'] == true).length;
      final seconds = todayTasks.fold<int>(0, (s, t) => s + _taskSeconds(t));
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;

      // কালকের টাস্ক: next-day রুটিন + সাপ্তাহিক রুটিনের ঐ দিনের টাস্ক
      final nextSnap = await userRef.collection('dailyRoutines').doc(fmt.format(nextDay)).get();
      int tomorrow = (nextSnap.data()?['tasks'] as List<dynamic>? ?? []).length;
      try {
        final weekday = DateFormat('EEEE', 'en').format(nextDay);
        final weekly = await userRef.collection('weeklyRoutines').doc(weekday).collection('tasks').get();
        tomorrow += weekly.docs.length;
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      final bn = (prefs.getString(languageKey) ?? 'en') == 'bn';

      String title;
      String body;
      if (bn) {
        title = '🌙 আজকের সারাংশ';
        final studied = seconds >= 60
            ? 'আজ ${h > 0 ? '${_bnNum(h)} ঘণ্টা ' : ''}${_bnNum(m)} মিনিট পড়েছেন'
            : 'আজ এখনো পড়ার সময় রেকর্ড হয়নি';
        final tasksLine = total > 0 ? '${_bnNum(total)}টার মধ্যে ${_bnNum(done)}টা টাস্ক শেষ' : 'আজ কোনো টাস্ক ছিল না';
        final tomorrowLine = tomorrow > 0 ? 'কাল ${_bnNum(tomorrow)}টা টাস্ক আছে' : 'কালকের রুটিন এখনো ঠিক করা হয়নি';
        body = '$studied, $tasksLine, $tomorrowLine।';
      } else {
        title = '🌙 Today\'s summary';
        final studied = seconds >= 60
            ? 'You studied ${h > 0 ? '${h}h ' : ''}${m}m today'
            : 'No study time recorded today yet';
        final tasksLine = total > 0 ? '$done of $total tasks done' : 'no tasks today';
        final tomorrowLine = tomorrow > 0 ? '$tomorrow tasks tomorrow' : 'tomorrow is not planned yet';
        body = '$studied, $tasksLine, $tomorrowLine.';
      }

      await LocalNotificationService.scheduleNightlySummary(
        id: notificationId,
        title: title,
        body: body,
        when: when,
        planButton: bn ? '📝 কালকের রুটিন' : '📝 Plan tomorrow',
        payload: openBotPlan,
      );
      log('Nightly summary scheduled for $when: $body');
    } catch (e) {
      log('Nightly summary refresh failed: $e');
    }
  }
}
