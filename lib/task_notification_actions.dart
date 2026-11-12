import 'dart:convert';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

/// নোটিফিকেশনের "▶ Start" / "✓ Complete" বাটন চাপলে অ্যাপ না খুলেই টাস্ক আপডেট করে।
/// এটা ব্যাকগ্রাউন্ড isolate থেকেও চলে, তাই নিজে Firebase চালু করে নেয়।
class TaskNotificationActions {
  static const String actionStart = 'task_start';
  static const String actionComplete = 'task_complete';
  static const String actionPlanTomorrow = 'plan_tomorrow';

  /// কখন নোটিফিকেশন থেকে Start চাপা হয়েছিল (অ্যাপ খুললে ততক্ষণের সময় যোগ হয়)
  static String startedAtKey(String taskId) => 'notif_started_at_$taskId';

  static String payloadFor(String taskId, DateTime taskDate) {
    final d = taskDate;
    final docId = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return jsonEncode({'taskId': taskId, 'date': docId});
  }

  static bool handles(String? actionId) => actionId == actionStart || actionId == actionComplete;

  static Future<void> handle(String actionId, String? payload) async {
    if (payload == null || payload.isEmpty) return;
    Map<String, dynamic> data;
    try {
      data = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final taskId = data['taskId'] as String?;
    final dateId = data['date'] as String?;
    if (taskId == null || dateId == null) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('dailyRoutines')
          .doc(dateId);
      final snap = await ref.get();
      final tasks = List<Map<String, dynamic>>.from(
        (snap.data()?['tasks'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      final i = tasks.indexWhere((t) => t['id'] == taskId);
      if (i < 0) return;
      final t = tasks[i];

      if (actionId == actionStart) {
        if (t['status'] == 'completed') return;
        t['status'] = 'running';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(startedAtKey(taskId), DateTime.now().millisecondsSinceEpoch);
      } else if (actionId == actionComplete) {
        final prefs = await SharedPreferences.getInstance();
        final startedAt = prefs.getInt(startedAtKey(taskId));
        int elapsed = (t['elapsedSeconds'] as num?)?.toInt() ?? 0;
        if (startedAt != null) {
          elapsed += DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(startedAt)).inSeconds;
          await prefs.remove(startedAtKey(taskId));
        }
        t['status'] = 'completed';
        t['isCompleted'] = true;
        t['elapsedSeconds'] = elapsed;
        t['completedDurationMinutes'] = elapsed ~/ 60;
        t['completionNote'] = t['completionNote'] ?? 'Completed from notification';
      }
      tasks[i] = t;
      await ref.update({'tasks': tasks});
      log('Task $taskId updated from notification: $actionId');
    } catch (e) {
      log('Task notification action failed: $e');
    }
  }

  /// অ্যাপ খুললে: নোটিফিকেশন থেকে Start করা টাস্কে ততক্ষণের সময় যোগ করে দেয়
  static Future<int> consumeBackgroundSeconds(String taskId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startedAt = prefs.getInt(startedAtKey(taskId));
      if (startedAt == null) return 0;
      await prefs.remove(startedAtKey(taskId));
      final secs = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(startedAt)).inSeconds;
      return secs > 0 ? secs : 0;
    } catch (_) {
      return 0;
    }
  }
}
