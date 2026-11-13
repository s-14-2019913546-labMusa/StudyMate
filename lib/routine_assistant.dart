import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'daily_routine.dart';
import 'local_notification_service.dart';
import 'nightly_summary_service.dart';
import 'quick_add_task.dart';
import 'task_notification_actions.dart';

/// বট যে রুটিনের কাজগুলো করে: টাস্ক যোগ, সরানো, পিছানো, মোছা, কালকে নেওয়া।
/// সব লেখা হয় users/{uid}/dailyRoutines/{yyyy-MM-dd} ডকের `tasks` তালিকায়
/// (ড্যাশবোর্ড যেভাবে পড়ে)। নোটিফিকেশনও সাথে সাথে নতুন সময়ে বসানো হয়।
class RoutineAssistant {
  static String dayId(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  static DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static DocumentReference<Map<String, dynamic>>? _doc(DateTime day) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid).collection('dailyRoutines').doc(dayId(day));
  }

  static Future<List<Task>> loadDay(DateTime day) async {
    final ref = _doc(day);
    if (ref == null) return [];
    final snap = await ref.get();
    final raw = snap.data()?['tasks'] as List<dynamic>? ?? [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return Task.fromMap(m, (m['id'] ?? '').toString());
    }).toList();
  }

  static Future<void> _saveDay(DateTime day, List<Task> tasks) async {
    final ref = _doc(day);
    if (ref == null) return;
    final user = FirebaseAuth.instance.currentUser!;
    await ref.set({
      'userId': user.uid,
      'date': Timestamp.fromDate(dayOf(day)),
      'tasks': tasks.map((t) => t.toMap()).toList(),
    }, SetOptions(merge: true));
    if (dayId(day) == dayId(DateTime.now())) {
      NightlySummaryService.refresh();
    }
  }

  static Future<void> _reschedule(Task t) async {
    try {
      await LocalNotificationService.cancelTaskNotifications(t.id);
      if (t.alarmEnabled && !(t.isCompleted || t.status == 'completed')) {
        await LocalNotificationService.scheduleTaskNotifications(t);
      }
    } catch (_) {}
  }

  static Task _withStart(Task t, DateTime start) {
    final mins = t.totalDurationMinutes > 0
        ? t.totalDurationMinutes
        : (t.startTime != null && t.endTime != null ? t.endTime!.difference(t.startTime!).inMinutes : 60);
    return t.copyWith(startTime: start, endTime: start.add(Duration(minutes: mins)), totalDurationMinutes: mins, status: 'pending');
  }

  /// লেখা থেকে নতুন টাস্ক ("কাল সকাল ৭টায় গণিত ২ ঘণ্টা")
  static Future<(Task, DateTime)> addFromText(String text) async {
    final p = QuickTaskParser.parse(text);
    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: p.subject,
      subject: p.subject,
      topic: '',
      notes: '',
      challenges: '',
      startTime: p.start,
      endTime: p.end,
      category: 'Study',
      totalDurationMinutes: p.minutes,
      alarmEnabled: true,
    );
    final day = dayOf(p.start);
    final tasks = await loadDay(day);
    tasks.add(task);
    await _saveDay(day, tasks);
    if (dayId(day) == dayId(DateTime.now())) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('daily_imported_${dayId(day)}', true);
    }
    await _reschedule(task);
    return (task, day);
  }

  static Future<void> removeTask(DateTime day, String taskId) async {
    final tasks = await loadDay(day);
    tasks.removeWhere((t) => t.id == taskId);
    await _saveDay(day, tasks);
    try {
      await LocalNotificationService.cancelTaskNotifications(taskId);
    } catch (_) {}
  }

  /// মুছে ফেলা বা সরানো টাস্ক আগের জায়গায় ফেরত (Undo)
  static Future<void> restore(DateTime day, Task task, {DateTime? removeFromDay}) async {
    if (removeFromDay != null) {
      final other = await loadDay(removeFromDay);
      other.removeWhere((t) => t.id == task.id);
      await _saveDay(removeFromDay, other);
    }
    final tasks = await loadDay(day);
    tasks.removeWhere((t) => t.id == task.id);
    tasks.add(task);
    await _saveDay(day, tasks);
    await _reschedule(task);
  }

  /// একই দিনে নতুন সময়ে
  static Future<Task> moveToTime(DateTime day, Task task, DateTime newStart) async {
    final tasks = await loadDay(day);
    final i = tasks.indexWhere((t) => t.id == task.id);
    final moved = _withStart(i >= 0 ? tasks[i] : task, newStart);
    if (i >= 0) {
      tasks[i] = moved;
    } else {
      tasks.add(moved);
    }
    await _saveDay(day, tasks);
    await _reschedule(moved);
    return moved;
  }

  static Future<Task> postpone(DateTime day, Task task, int minutes) {
    final now = DateTime.now();
    var base = task.startTime ?? now;
    // সময় পেরিয়ে গেলে এখন থেকে গুনে পেছানো
    if (base.isBefore(now)) base = now;
    final start = DateTime(base.year, base.month, base.day, base.hour, base.minute).add(Duration(minutes: minutes));
    return moveToTime(day, task, start);
  }

  /// অন্য দিনে (একই ঘড়ির সময়ে)
  static Future<(Task, DateTime)> moveToDay(DateTime fromDay, Task task, int days) async {
    final to = dayOf(fromDay).add(Duration(days: days));
    final s = task.startTime ?? DateTime(to.year, to.month, to.day, 9);
    final moved = _withStart(task, DateTime(to.year, to.month, to.day, s.hour, s.minute));
    final from = await loadDay(fromDay);
    from.removeWhere((t) => t.id == task.id);
    await _saveDay(fromDay, from);
    final dest = await loadDay(to);
    dest.removeWhere((t) => t.id == task.id);
    dest.add(moved);
    await _saveDay(to, dest);
    await _reschedule(moved);
    return (moved, to);
  }

  /// আজকের যেগুলো শেষ হয়নি সব কালকে (আজ চলছে এমনটা বাদে)
  static Future<int> moveUnfinishedToTomorrow() async {
    final today = dayOf(DateTime.now());
    final tasks = await loadDay(today);
    final open = tasks.where((t) => !(t.isCompleted || t.status == 'completed') && t.status != 'running').toList();
    if (open.isEmpty) return 0;
    final tomorrow = today.add(const Duration(days: 1));
    final dest = await loadDay(tomorrow);
    final movedIds = <String>{};
    for (final t in open) {
      final s = t.startTime ?? DateTime(today.year, today.month, today.day, 9);
      final moved = _withStart(t, DateTime(tomorrow.year, tomorrow.month, tomorrow.day, s.hour, s.minute));
      dest.removeWhere((x) => x.id == t.id);
      dest.add(moved);
      movedIds.add(t.id);
      await _reschedule(moved);
    }
    tasks.removeWhere((t) => movedIds.contains(t.id));
    await _saveDay(today, tasks);
    await _saveDay(tomorrow, dest);
    return open.length;
  }

  /// কালকের সাপ্তাহিক রুটিনের টাস্ক (weeklyRoutines/{EEEE}/tasks)
  static Future<List<Task>> weeklyFor(DateTime day) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('weeklyRoutines')
        .doc(DateFormat('EEEE', 'en').format(day))
        .collection('tasks')
        .get();
    return snap.docs.map((d) => Task.fromMap(d.data(), d.id)).toList();
  }

  /// সাপ্তাহিক রুটিন ওই দিনের রুটিনে বসানো (ড্যাশবোর্ডের "Import" এর মতো [WR] চিহ্নসহ)
  static Future<int> copyWeeklyTo(DateTime day) async {
    final weekly = await weeklyFor(day);
    if (weekly.isEmpty) return 0;
    final d = dayOf(day);
    final dest = await loadDay(d);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    var n = 0;
    for (final t in weekly) {
      final s = t.startTime ?? DateTime(d.year, d.month, d.day, 9);
      final title = t.title.startsWith('[WR]') ? t.title : '[WR] ${t.title}';
      final already = dest.any((x) => x.title == title && x.startTime?.hour == s.hour && x.startTime?.minute == s.minute);
      if (already) continue;
      final copy = _withStart(
        t.copyWith(id: '${stamp}_$n', title: title, subject: t.subject != null ? (t.subject!.startsWith('[WR]') ? t.subject : '[WR] ${t.subject}') : title),
        DateTime(d.year, d.month, d.day, s.hour, s.minute),
      );
      dest.add(copy);
      n++;
      await _reschedule(copy);
    }
    await _saveDay(d, dest);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('weekly_imported_${dayId(d)}', true);
    return n;
  }

  /// নোটিফিকেশনের ▶ Start / ✓ Complete যেভাবে কাজ করে, ঠিক সেভাবে
  static Future<void> start(DateTime day, Task t) =>
      TaskNotificationActions.handle(TaskNotificationActions.actionStart, TaskNotificationActions.payloadFor(t.id, day));
  static Future<void> complete(DateTime day, Task t) =>
      TaskNotificationActions.handle(TaskNotificationActions.actionComplete, TaskNotificationActions.payloadFor(t.id, day));

  // ---- বটের মেসেজে বাটনের ডেটা হিসেবে রাখার জন্য (JSON-এ Timestamp চলে না) ----
  static Map<String, dynamic> taskToJson(Task t) {
    final m = t.toMap();
    m['startTime'] = t.startTime?.millisecondsSinceEpoch;
    m['endTime'] = t.endTime?.millisecondsSinceEpoch;
    return m;
  }

  static Task taskFromJson(Map<String, dynamic> j) {
    final m = Map<String, dynamic>.from(j);
    m['startTime'] = j['startTime'] != null ? Timestamp.fromMillisecondsSinceEpoch(j['startTime'] as int) : null;
    m['endTime'] = j['endTime'] != null ? Timestamp.fromMillisecondsSinceEpoch(j['endTime'] as int) : null;
    return Task.fromMap(m, (m['id'] ?? '').toString());
  }
}
