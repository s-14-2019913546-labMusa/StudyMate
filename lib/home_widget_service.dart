import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ফোনের হোম স্ক্রিন উইজেটের ডেটা (আজকের পরের টাস্ক, streak, পরের নামাজ)।
/// Android অংশ: android/app/src/main/kotlin/.../StudyWidgetProvider.kt
class HomeWidgetService {
  static const String _androidProvider = 'StudyWidgetProvider';

  static String _bnNum(Object n) {
    const bn = '০১২৩৪৫৬৭৮৯';
    return n.toString().split('').map((c) {
      final i = c.codeUnitAt(0) - 48;
      return (i >= 0 && i <= 9) ? bn[i] : c;
    }).join();
  }

  static Future<void> refresh({int? streak}) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final bn = (prefs.getString('app_language') ?? 'en') == 'bn';
      String num(Object n) => bn ? _bnNum(n) : '$n';
      String time(DateTime t) {
        final s = DateFormat('h:mm a').format(t);
        return bn ? _bnNum(s).replaceAll('AM', 'এএম').replaceAll('PM', 'পিএম') : s;
      }

      if (streak != null) await prefs.setInt('widget_last_streak', streak);
      final st = streak ?? prefs.getInt('widget_last_streak') ?? 0;

      String nextLabel = bn ? 'পরের টাস্ক' : 'Next task';
      String nextTask = bn ? 'আজ আর কোনো টাস্ক নেই 🎉' : 'No more tasks today 🎉';
      String nextTime = '';
      String progress = '';

      if (user != null) {
        final now = DateTime.now();
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('dailyRoutines')
            .doc(DateFormat('yyyy-MM-dd').format(now))
            .get();
        final tasks = (doc.data()?['tasks'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final done = tasks.where((t) => t['status'] == 'completed' || t['isCompleted'] == true).length;
        if (tasks.isNotEmpty) {
          progress = bn ? '${num(tasks.length)}টার মধ্যে ${num(done)}টা শেষ' : '$done of ${tasks.length} done today';
        } else {
          nextTask = bn ? 'আজকের টাস্ক যোগ করুন' : 'Add today\'s tasks';
        }

        DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
        final pending = tasks
            .where((t) => t['status'] != 'completed' && t['isCompleted'] != true)
            .where((t) => (ts(t['endTime']) ?? now.add(const Duration(days: 1))).isAfter(now))
            .toList()
          ..sort((a, b) => (ts(a['startTime']) ?? now).compareTo(ts(b['startTime']) ?? now));
        if (pending.isNotEmpty) {
          final t = pending.first;
          final s = ts(t['startTime']);
          final e = ts(t['endTime']);
          final running = t['status'] == 'running' || (s != null && s.isBefore(now));
          nextLabel = running ? (bn ? 'এখন চলছে' : 'Now') : nextLabel;
          nextTask = (t['title'] ?? t['subject'] ?? '').toString();
          if (s != null && e != null) nextTime = '${time(s)} – ${time(e)}';
        }
      }

      final prayer = await _nextPrayer(bn, time);

      await HomeWidget.saveWidgetData<String>('next_label', nextLabel);
      await HomeWidget.saveWidgetData<String>('next_task', nextTask);
      await HomeWidget.saveWidgetData<String>('next_time', nextTime);
      await HomeWidget.saveWidgetData<String>('streak', '🔥 ${num(st)}');
      await HomeWidget.saveWidgetData<String>('progress', progress);
      await HomeWidget.saveWidgetData<String>('prayer', prayer);
      await HomeWidget.updateWidget(androidName: _androidProvider);
    } catch (e) {
      log('Home widget refresh failed: $e');
    }
  }

  /// ইসলামিক লাইফ স্ক্রিন যে নামাজের সময় ফোনে জমা রাখে, সেখান থেকে পরের ওয়াক্ত
  static Future<String> _nextPrayer(bool bn, String Function(DateTime) time) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/prayer_times_cache.json');
      if (!await f.exists()) return '';
      final data = json.decode(await f.readAsString());
      final timings = Map<String, String>.from(data['timings']);
      final now = DateTime.now();
      final names = bn
          ? {'Fajr': 'ফজর', 'Dhuhr': now.weekday == DateTime.friday ? 'জুমা' : 'যোহর', 'Asr': 'আসর', 'Maghrib': 'মাগরিব', 'Isha': 'এশা'}
          : {'Fajr': 'Fajr', 'Dhuhr': now.weekday == DateTime.friday ? 'Jumu\'ah' : 'Dhuhr', 'Asr': 'Asr', 'Maghrib': 'Maghrib', 'Isha': 'Isha'};
      for (final key in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
        final parts = (timings[key] ?? '').split(' ').first.split(':');
        if (parts.length < 2) continue;
        final t = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
        if (t.isAfter(now)) return '🕌 ${names[key]} ${time(t)}';
      }
      final f0 = (timings['Fajr'] ?? '').split(' ').first.split(':');
      if (f0.length >= 2) {
        final t = DateTime(now.year, now.month, now.day + 1, int.parse(f0[0]), int.parse(f0[1]));
        return '🕌 ${names['Fajr']} ${time(t)}';
      }
    } catch (_) {}
    return '';
  }
}
