import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gamification_service.dart';
import 'local_notification_service.dart';

/// নিয়মিত থাকার সুবিধা: দৈনিক লক্ষ্য, পড়ার সময়ের হিসাব, streak-এর "ছুটি",
/// রাত ৯টার রিমাইন্ডার, মনোযোগ ভাঙার হিসাব আর সাপ্তাহিক মিনিট (গ্রুপ চ্যালেঞ্জের জন্য)।
class StudyHabitsService {
  static const int goalXp = 20;
  static const int freezesPerMonth = 2;
  static const int reminderId = 777002;
  static final _day = DateFormat('yyyy-MM-dd');

  static String todayId([DateTime? d]) => _day.format(d ?? DateTime.now());

  static DocumentReference<Map<String, dynamic>>? get _userRef {
    final u = FirebaseAuth.instance.currentUser;
    return u == null ? null : FirebaseFirestore.instance.collection('users').doc(u.uid);
  }

  // ---------- দৈনিক লক্ষ্য ----------
  static Future<int> getDailyGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('daily_goal_minutes') ?? 240;
  }

  static Future<void> setDailyGoal(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_goal_minutes', minutes);
    try {
      await _userRef?.set({'dailyGoalMinutes': minutes}, SetOptions(merge: true));
    } catch (_) {}
  }

  /// একটা টাস্কে কত সেকেন্ড পড়া হয়েছে (টাইমার না চালিয়ে শেষ করলে পুরো সময় ধরা হয়)
  static int taskSeconds(Map<String, dynamic> t) {
    final elapsed = (t['elapsedSeconds'] as num?)?.toInt() ?? 0;
    if (elapsed > 0) return elapsed;
    if (t['status'] == 'completed' || t['isCompleted'] == true) {
      return ((t['totalDurationMinutes'] as num?)?.toInt() ?? 0) * 60;
    }
    return 0;
  }

  /// একটা দিনের পড়ার মিনিট: টাস্কের সময় + Pomodoro-তে লাগানো গাছ
  static Future<int> studyMinutesOn(DateTime day, {Map<String, int>? perSubject}) async {
    final ref = _userRef;
    if (ref == null) return 0;
    var seconds = 0;
    try {
      final doc = await ref.collection('dailyRoutines').doc(todayId(day)).get();
      for (final e in (doc.data()?['tasks'] as List<dynamic>? ?? [])) {
        final t = Map<String, dynamic>.from(e as Map);
        final s = taskSeconds(t);
        seconds += s;
        if (perSubject != null && s > 0) {
          final key = ((t['subject'] ?? t['title'] ?? '') as String).replaceAll(RegExp(r'^\[[A-Z]+\]\s*'), '').trim();
          if (key.isNotEmpty) perSubject[key] = (perSubject[key] ?? 0) + s ~/ 60;
        }
      }
    } catch (_) {}
    try {
      final start = DateTime(day.year, day.month, day.day);
      final trees = await ref
          .collection('pomodoroForest')
          .doc('trees')
          .collection('list')
          .where('plantedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('plantedAt', isLessThan: Timestamp.fromDate(start.add(const Duration(days: 1))))
          .get();
      for (final t in trees.docs) {
        final m = (t.data()['sessionMinutes'] as num?)?.toInt() ?? 25;
        seconds += m * 60;
        if (perSubject != null) perSubject['Pomodoro'] = (perSubject['Pomodoro'] ?? 0) + m;
      }
    } catch (_) {}
    return seconds ~/ 60;
  }

  /// লক্ষ্য পূরণ হলে দিনে একবার XP
  static Future<bool> maybeAwardGoalXp(int minutes) async {
    final goal = await getDailyGoal();
    if (minutes < goal) return false;
    final prefs = await SharedPreferences.getInstance();
    final key = 'goal_xp_${todayId()}';
    if (prefs.getBool(key) ?? false) return false;
    await prefs.setBool(key, true);
    try {
      await GamificationService.awardXP(goalXp, reason: 'daily_goal');
    } catch (_) {}
    return true;
  }

  // ---------- Streak-এর ছুটি ----------
  static Future<Set<String>> getFreezes() async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList('streak_freezes') ?? []).toSet();
    try {
      final doc = await _userRef?.get();
      set.addAll(List<String>.from(doc?.data()?['streakFreezes'] ?? []));
    } catch (_) {}
    return set;
  }

  static Future<int> freezesLeftThisMonth() async {
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    final used = (await getFreezes()).where((d) => d.startsWith(month)).length;
    return (freezesPerMonth - used).clamp(0, freezesPerMonth);
  }

  static Future<bool> isFrozen(DateTime d) async => (await getFreezes()).contains(todayId(d));

  /// আজকের দিনটা "ছুটি" — streak ভাঙবে না
  static Future<bool> freezeToday() async {
    if (await freezesLeftThisMonth() <= 0) return false;
    final id = todayId();
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList('streak_freezes') ?? [])..add(id);
    await prefs.setStringList('streak_freezes', list.toSet().toList());
    try {
      await _userRef?.set({'streakFreezes': FieldValue.arrayUnion([id])}, SetOptions(merge: true));
    } catch (_) {}
    await LocalNotificationService.cancelNotification(reminderId);
    return true;
  }

  // ---------- রাত ৯টার রিমাইন্ডার ----------
  /// আজ এখনো পড়া না হলে রাত ৯টায় মনে করিয়ে দেয়; পড়া হলে বা ছুটি নিলে বাতিল
  static Future<void> refreshReminder(int todayMinutes) async {
    if (kIsWeb) return;
    try {
      final now = DateTime.now();
      final at = DateTime(now.year, now.month, now.day, 21, 0);
      if (todayMinutes > 0 || !at.isAfter(now) || await isFrozen(now)) {
        await LocalNotificationService.cancelNotification(reminderId);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('streak_reminder_enabled') ?? true)) return;
      final bn = (prefs.getString('app_language') ?? 'en') == 'bn';
      await LocalNotificationService.scheduleNotification(
        id: reminderId,
        title: bn ? '🔥 আজকের streak বাঁচান!' : '🔥 Save your streak!',
        body: bn
            ? 'আজ এখনো পড়া শুরু হয়নি। মাত্র ২৫ মিনিট পড়লেও streak থাকবে। ছুটি নিতে চাইলে অ্যাপে streak-এ চাপুন।'
            : "You haven't studied today yet. Even 25 minutes keeps your streak. Tap the streak in the app to take a day off.",
        scheduledDate: at,
        channelId: 'streak_reminder_channel',
        channelName: 'Streak Reminders',
        channelDescription: 'Reminds you at 9 PM if you have not studied today',
      );
    } catch (e) {
      log('Streak reminder failed: $e');
    }
  }

  // ---------- শুক্রবারের সাপ্তাহিক রিপোর্ট ----------
  static const int weeklyReportId = 777003;
  static const String openWeeklyReport = 'open:weekly_report';

  /// পরের শুক্রবার রাত ৮টায় "সাপ্তাহিক রিপোর্ট" নোটিফিকেশন (চাপলে রিপোর্ট খোলে)
  static Future<void> scheduleWeeklyReport() async {
    if (kIsWeb) return;
    try {
      final now = DateTime.now();
      var d = DateTime(now.year, now.month, now.day, 20, 0);
      while (d.weekday != DateTime.friday || !d.isAfter(now)) {
        d = d.add(const Duration(days: 1));
      }
      final prefs = await SharedPreferences.getInstance();
      final bn = (prefs.getString('app_language') ?? 'en') == 'bn';
      final week = await syncWeeklyMinutes();
      final h = week ~/ 60, m = week % 60;
      await LocalNotificationService.scheduleOpenNotification(
        id: weeklyReportId,
        title: bn ? '📊 এই সপ্তাহের রিপোর্ট তৈরি' : '📊 Your weekly report is ready',
        body: bn
            ? 'এই সপ্তাহে এ পর্যন্ত $h ঘণ্টা $m মিনিট পড়েছেন। কোন বিষয়ে বেশি-কম আর আগের সপ্তাহের সাথে তুলনা দেখতে চাপুন।'
            : 'So far this week you studied ${h}h ${m}m. Tap to see subjects and how it compares with last week.',
        when: d,
        payload: openWeeklyReport,
      );
    } catch (e) {
      log('Weekly report schedule failed: $e');
    }
  }

  // ---------- মনোযোগ ভাঙার হিসাব ----------
  static Future<void> addDistraction() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'distractions_${todayId()}';
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }

  static Future<int> distractionsOn(DateTime d) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('distractions_${todayId(d)}') ?? 0;
  }

  // ---------- সপ্তাহ (শনিবার থেকে শুক্রবার) ----------
  static DateTime weekStart(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final diff = (day.weekday - DateTime.saturday) % 7;
    return day.subtract(Duration(days: diff));
  }

  /// এই সপ্তাহের মোট মিনিট users/{uid}-এ রাখা হয়, গ্রুপ চ্যালেঞ্জের লিডারবোর্ড এটা পড়ে
  static Future<int> syncWeeklyMinutes() async {
    final ref = _userRef;
    if (ref == null) return 0;
    final start = weekStart(DateTime.now());
    var total = 0;
    for (int i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      if (d.isAfter(DateTime.now())) break;
      total += await studyMinutesOn(d);
    }
    try {
      await ref.set({
        'weeklyStudyMinutes': total,
        'weeklyStudyWeek': todayId(start),
      }, SetOptions(merge: true));
    } catch (_) {}
    return total;
  }
}
