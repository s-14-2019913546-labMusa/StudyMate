import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'daily_routine.dart';
import 'language_manager.dart';
import 'todays_tasks_screen.dart';
import 'gamification_service.dart';
import 'task_details_screen.dart'; // নতুন ফাইলটি ইমপোর্ট করা হলো
import 'tools_screen.dart'; // Tools স্ক্রিন ইমপোর্ট
import 'profile_screen.dart'; // Profile স্ক্রিন ইমপোর্ট
import 'chat_screen.dart';
import 'shared_task_form.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'local_notification_service.dart';

// ==========================================
// 4. Dashboard Screen (ড্যাশবোর্ড স্ক্রিন)
// ==========================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  String get _todayDateFormatted => DateFormat('EEEE, d MMMM', LanguageManager().currentLanguage).format(DateTime.now());
  final String _todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now()); // e.g., "2023-10-27"

  Stream<DailyRoutine?>? _todaysRoutineStream;
  int _bottomNavIndex = 0; // বটম নেভিগেশন বারের ইনডেক্স
  int _currentStreak = 0;
  Timer? _breathingTimer;
  Timer? _missedTasksSnoozeTimer;
  StreamSubscription<DailyRoutine?>? _routineSubscription;

  @override
  void initState() {
    super.initState();
    if (user != null) {
      _todaysRoutineStream = _fetchTodaysRoutine();
      _listenToTodaysRoutine();
      _loadStreak();
      _checkMissedTasksFromYesterday();
      _checkAndScheduleBreathingPopup();
      _startTaskAlertsTimer();
    }
  }

  void _listenToTodaysRoutine() {
    _routineSubscription?.cancel();
    _routineSubscription = _fetchTodaysRoutine().listen((routine) {
      if (mounted) {
        setState(() {
          _currentTasks = routine?.tasks ?? [];
        });
      }
    });
  }

  @override
  void dispose() {
    _breathingTimer?.cancel();
    _missedTasksSnoozeTimer?.cancel();
    _taskAlertsTimer?.cancel();
    _routineSubscription?.cancel();
    super.dispose();
  }

  Timer? _taskAlertsTimer;
  final Set<String> _triggeredStartAlerts = {};
  final Set<String> _triggeredEndAlerts = {};
  List<Task> _currentTasks = [];

  void _startTaskAlertsTimer() {
    _taskAlertsTimer?.cancel();
    _taskAlertsTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (user == null) return;
      _checkTaskTimes();
    });
  }

  void _checkTaskTimes() {
    if (!mounted) return;
    final now = DateTime.now();
    debugPrint('[TaskAlerts] Timer ticked. Current task count: ${_currentTasks.length}');

    if (_currentTasks.isEmpty) {
      debugPrint('[TaskAlerts] No tasks in _currentTasks yet.');
      return;
    }

    for (var task in _currentTasks) {
      debugPrint('[TaskAlerts] Task: "${task.title}", Status: "${task.status}", alarmEnabled: ${task.alarmEnabled}, isCompleted: ${task.isCompleted}, startTime: ${task.startTime}, endTime: ${task.endTime}');
      if (!task.alarmEnabled) continue;

      // 1. Check Start Time
      if (task.startTime != null) {
        final diff = now.difference(task.startTime!);
        final isAfterStart = now.isAfter(task.startTime!);
        debugPrint('[TaskAlerts] Start check for "${task.title}": isAfterStart=$isAfterStart, diffInMinutes=${diff.inMinutes}, status=${task.status}');
        
        if (task.status == 'pending' && 
            !task.isCompleted && 
            isAfterStart && 
            diff.inMinutes < 15) {
          
          final alertKey = '${task.id}_start';
          if (!_triggeredStartAlerts.contains(alertKey)) {
            _triggeredStartAlerts.add(alertKey);
            debugPrint('[TaskAlerts] Triggering start dialog for task "${task.title}"');
            _showInAppTaskStartDialog(task);
          }
        }
      }

      // 2. Check End Time
      if (task.endTime != null) {
        final diff = now.difference(task.endTime!);
        final isAfterEnd = now.isAfter(task.endTime!);
        debugPrint('[TaskAlerts] End check for "${task.title}": isAfterEnd=$isAfterEnd, diffInMinutes=${diff.inMinutes}, status=${task.status}');

        if (task.status == 'running' && 
            isAfterEnd && 
            diff.inMinutes < 15) {
            
          final alertKey = '${task.id}_end';
          if (!_triggeredEndAlerts.contains(alertKey)) {
            _triggeredEndAlerts.add(alertKey);
            debugPrint('[TaskAlerts] Triggering end dialog for task "${task.title}"');
            _showInAppTaskEndDialog(task);
          }
        }
      }
    }
  }

  void _showInAppTaskStartDialog(Task task) {
    LocalNotificationService.playCustomNotificationSound();
    final String timeRange = '${task.startTime != null ? DateFormat('h:mm a').format(task.startTime!) : 'N/A'} - ${task.endTime != null ? DateFormat('h:mm a').format(task.endTime!) : 'N/A'}';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.alarm_on_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
              const SizedBox(width: 8),
              const Text('টাস্ক শুরুর সময়!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'আপনার নির্ধারিত কাজ "${task.title}" শুরু করার সময় হয়েছে।',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'নির্ধারিত সময়: $timeRange',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'আপনি কি এটি এখন শুরু করতে চান?',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'এখন না',
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateTaskInFirestore(task.copyWith(status: 'running'));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'হ্যাঁ, শুরু করুন',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showInAppTaskEndDialog(Task task) {
    LocalNotificationService.playCustomNotificationSound();
    final String timeRange = '${task.startTime != null ? DateFormat('h:mm a').format(task.startTime!) : 'N/A'} - ${task.endTime != null ? DateFormat('h:mm a').format(task.endTime!) : 'N/A'}';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.timer_off_rounded, color: Colors.redAccent, size: 28),
              const SizedBox(width: 8),
              const Text('টাস্কের সময় শেষ!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'আপনার কাজ "${task.title}" এর নির্ধারিত সময় শেষ হয়েছে।',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 16, color: Colors.redAccent),
                  const SizedBox(width: 6),
                  Text(
                    'নির্ধারিত সময়: $timeRange',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'আপনি কি এটি সম্পন্ন হিসেবে মার্ক করতে চান?',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'পরে করব',
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateTaskInFirestore(task.copyWith(status: 'completed', isCompleted: true, completedDurationMinutes: task.totalDurationMinutes));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'সম্পন্ন (Done)',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }


  Future<void> _checkMissedTasksFromYesterday() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final shownKey = 'shown_missed_tasks_v2_$todayStr';
    final snoozeKey = 'snooze_yesterday_missed_$todayStr';
    
    if (prefs.getBool(shownKey) == true) return;
    
    // Check base time (11:10 AM)
    final targetTime = DateTime(now.year, now.month, now.day, 11, 10);
    if (now.isBefore(targetTime)) {
      _missedTasksSnoozeTimer?.cancel();
      _missedTasksSnoozeTimer = Timer(targetTime.difference(now), _checkMissedTasksFromYesterday);
      return;
    }

    // Check if snoozed
    final snoozeTimeStr = prefs.getString(snoozeKey);
    if (snoozeTimeStr != null) {
      final snoozeTime = DateTime.parse(snoozeTimeStr);
      if (now.isBefore(snoozeTime)) {
        _missedTasksSnoozeTimer?.cancel();
        _missedTasksSnoozeTimer = Timer(snoozeTime.difference(now), _checkMissedTasksFromYesterday);
        return;
      }
    }
    
    if (user == null) return;

    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayDocId = DateFormat('yyyy-MM-dd').format(yesterday);
    
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('dailyRoutines')
          .doc(yesterdayDocId)
          .get();
          
      if (!docSnapshot.exists || docSnapshot.data() == null) return;
      
      final routine = DailyRoutine.fromMap(docSnapshot.data()!, docSnapshot.id);
      final missedTasks = routine.tasks.where((t) => !t.isCompleted && t.status != 'completed').toList();
      
      if (missedTasks.isNotEmpty && mounted) {
        await prefs.setBool(shownKey, true);
        
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('গতকালের মিসড টাস্ক'),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 250,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('আপনার গতকালের কিছু টাস্ক বাকি আছে:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: missedTasks.length,
                          itemBuilder: (ctx, i) {
                            return ListTile(
                              leading: const Icon(Icons.circle, size: 10, color: Colors.red),
                              title: Text(missedTasks[i].title),
                              subtitle: Text('${missedTasks[i].startTime != null ? DateFormat.jm().format(missedTasks[i].startTime!) : "N/A"} - ${missedTasks[i].endTime != null ? DateFormat.jm().format(missedTasks[i].endTime!) : "N/A"}'),
                              contentPadding: EdgeInsets.zero,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        final snoozeTime = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
                        if (snoozeTime.isAfter(DateTime.now())) {
                          await prefs.setString(snoozeKey, snoozeTime.toIso8601String());
                          await prefs.remove(shownKey);
                          _checkMissedTasksFromYesterday();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('রিমাইন্ডার সেট করা হয়েছে ${picked.format(context)} এ')),
                            );
                          }
                        }
                      } else {
                        // User cancelled time picker, so mark as shown anyway or maybe ask again
                        await prefs.setBool(shownKey, true);
                      }
                    },
                    child: const Text('পরে মনে করান'),
                  ),
                  TextButton(
                    onPressed: () {
                      prefs.setBool(shownKey, true);
                      Navigator.of(context).pop();
                    },
                    child: const Text('ঠিক আছে'),
                  ),
                ],
              );
            }
          );
        });
      }
    } catch (e) {
      debugPrint("Error fetching yesterday's missed tasks: $e");
    }
  }

  Future<void> _checkAndScheduleBreathingPopup() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTimeStr = prefs.getString('last_breathing_time');
    DateTime? lastTime;
    if (lastTimeStr != null) {
      lastTime = DateTime.tryParse(lastTimeStr);
    }
    
    final now = DateTime.now();
    
    // Check if 4 hours have passed since the last popup
    if (lastTime == null || now.difference(lastTime).inHours >= 4) {
      Future.delayed(const Duration(seconds: 3), () {
        _showBreathingPopup();
      });
    } else {
      final remaining = const Duration(hours: 4) - now.difference(lastTime);
      _breathingTimer = Timer(remaining, _showBreathingPopup);
    }
  }

  void _showBreathingPopup() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_breathing_time', DateTime.now().toIso8601String());
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('একটু বিরতি নিন'),
          content: const Text('আপনি প্রায় চারঘণ্টা একাধারে কাজ করে যাচ্ছেন, একটু ব্রিথিং এক্সারসাইজ আপনার মনোযোগ বাড়াতে সাহায্য করবে।'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('এখন না'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BreathingPlayerScreen(
                  title: 'Box Breathing',
                  phases: [4, 4, 4, 4],
                )));
              },
              child: const Text('এক্সারসাইজ করুন'),
            ),
          ],
        );
      }
    );
    
    _breathingTimer?.cancel();
    _breathingTimer = Timer.periodic(const Duration(hours: 4), (timer) {
      _showBreathingPopup();
    });
  }

  Future<void> _loadStreak() async {
    try {
      final streak = await GamificationService.calculateStreak();
      if (mounted) {
        setState(() {
          _currentStreak = streak;
        });
      }
    } catch (e) {
      debugPrint("Error loading streak on dashboard: $e");
    }
  }

  Stream<DailyRoutine?> _fetchTodaysRoutine() {
    if (user == null) {
      return Stream.value(null); // Return an empty stream if user is null
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('dailyRoutines')
        .doc(_todayDocId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return DailyRoutine.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }

  // টাস্ক ডাটাবেজে যুক্ত করার ফাংশন
  Future<void> _addTaskToFirestore(Task newTask) async {
    if (user == null) return;
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('dailyRoutines')
        .doc(_todayDocId);

    final snapshot = await docRef.get();
    if (snapshot.exists) {
      await docRef.update({
        'tasks': FieldValue.arrayUnion([newTask.toMap()])
      });
    } else {
      final newRoutine = DailyRoutine(
        id: _todayDocId,
        userId: user!.uid,
        date: DateTime.now(),
        tasks: [newTask],
      );
      await docRef.set(newRoutine.toMap());
    }

    if (newTask.alarmEnabled) {
      await LocalNotificationService.scheduleTaskNotifications(newTask);
    }

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task Added Successfully!'.tr())));
  }

  // একাধিক টাস্ক ডাটাবেজে একসাথে যুক্ত করার ফাংশন (AI Planner এর জন্য)
  Future<void> _addTasksToFirestore(List<Task> newTasks) async {
    if (user == null || newTasks.isEmpty) return;
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('dailyRoutines')
        .doc(_todayDocId);

    final snapshot = await docRef.get();
    if (snapshot.exists) {
      await docRef.update({
        'tasks': FieldValue.arrayUnion(newTasks.map((t) => t.toMap()).toList())
      });
    } else {
      final newRoutine = DailyRoutine(id: _todayDocId, userId: user!.uid, date: DateTime.now(), tasks: newTasks);
      await docRef.set(newRoutine.toMap());
    }

    for (var t in newTasks) {
      if (t.alarmEnabled) {
        await LocalNotificationService.scheduleTaskNotifications(t);
      }
    }

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Routine Added Successfully!'.tr())));
  }

  // টাস্ক ডাটাবেজে আপডেট করার ফাংশন
  Future<void> _updateTaskInFirestore(Task updatedTask) async {
    if (user == null) return;
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('dailyRoutines')
        .doc(_todayDocId);

    final snapshot = await docRef.get();
    if (snapshot.exists) {
      DailyRoutine routine = DailyRoutine.fromMap(snapshot.data()!, snapshot.id);
      int index = routine.tasks.indexWhere((t) => t.id == updatedTask.id);
      if (index != -1) {
        routine.tasks[index] = updatedTask;
        await docRef.update({'tasks': routine.tasks.map((t) => t.toMap()).toList()});
        
        // local notification সিডিউল বা বাতিল করা
        if (updatedTask.alarmEnabled && updatedTask.status != 'completed' && !updatedTask.isCompleted) {
          await LocalNotificationService.scheduleTaskNotifications(updatedTask);
        } else {
          await LocalNotificationService.cancelTaskNotifications(updatedTask.id);
        }

        if (updatedTask.status == 'completed') {
          _loadStreak();
        }
      }
    }
  }

  // সব মিসড টাস্ক দেখানোর বটম শিট
  void _showAllMissedTasks(List<Task> missedTasks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (_, controller) {
            return SafeArea(
              top: true,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "All Missed Tasks".tr(), 
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold, 
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        controller: controller,
                        itemCount: missedTasks.length,
                        itemBuilder: (context, index) {
                          return ActiveTaskCard(
                            task: missedTasks[index],
                            onUpdate: _updateTaskInFirestore,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('নিশ্চিত করুন'),
            content: const Text('আপনি কি সত্যিই অ্যাপ থেকে বের হতে চান?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('না'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('হ্যাঁ', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: _bottomNavIndex == 0
            ? AppBar(
                backgroundColor: Theme.of(context).colorScheme.surface,
                elevation: 0,
                scrolledUnderElevation: 0, // স্ক্রল করার সময় ডিফল্ট শ্যাডো অফ রাখার জন্য
                titleSpacing: 20, // নিচের বডির প্যাডিংয়ের সাথে লোগোকে সমান্তরাল রাখার জন্য
                title: Row(
                  children: [
                    Icon(Icons.school_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'StudyMate',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ],
                ),
              )
            : null,
        body: _buildBodyContent(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomNavIndex,
        onDestinationSelected: (index) {
          setState(() {
            _bottomNavIndex = index;
          });
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_rounded), label: 'Home'.tr()),
          NavigationDestination(icon: const Icon(Icons.build_circle_outlined), selectedIcon: const Icon(Icons.build_circle_rounded), label: 'Tools'.tr()),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person_rounded), label: 'Profile'.tr()),
        ],
      ),
      floatingActionButton: _bottomNavIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true, // কিবোর্ড উঠলে ফর্ম স্ক্রল করার জন্য
                  useSafeArea: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => AddTaskBottomSheet(
                    title: 'নতুন টাস্ক যুক্ত করুন (Add New Task)',
                    submitButtonText: 'সেভ নিউ টাস্ক',
                    onTaskAdded: (newTask) {
                      _addTaskToFirestore(newTask);
                    },
                  ),
                );
              },
              label: Text(
                'New Task'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              icon: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 8,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    ));
  }

  Widget _buildBodyContent() {
    if (_bottomNavIndex == 1) {
      return ToolsScreen(onTasksGenerated: _addTasksToFirestore);
    } else if (_bottomNavIndex == 2) {
      return const ProfileScreen();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutQuad,
        builder: (context, double value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User name, welcome and Message Icon (Moved from header to scrollable body)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? "User",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Welcome back!'.tr(),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (_currentStreak > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 14),
                                const SizedBox(width: 2),
                                Text(
                                  '$_currentStreak ${'Day Streak'.tr()}',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                _buildMessageIcon(context),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              LanguageManager.formatDate(DateTime.now()),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 16),
            _buildTodayProgressCard(context),
            const SizedBox(height: 30),
            
            StreamBuilder<DailyRoutine?>(
              stream: _todaysRoutineStream,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  _currentTasks = snapshot.data!.tasks;
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final now = DateTime.now();
                List<Task> activeTasks = [];
                List<Task> missedTasks = [];
                List<Task> otherTasks = [];

                if (snapshot.hasData && snapshot.data != null && snapshot.data!.tasks.isNotEmpty) {
                  for (var t in snapshot.data!.tasks) {
                    if (t.status == 'completed') continue;

                    double progress = t.totalDurationMinutes > 0
                        ? (t.elapsedSeconds / (t.totalDurationMinutes * 60))
                        : 0.0;

                    // মিসড টাস্ক এর শর্ত (সময় শেষ এবং প্রোগ্রেস ১০% এর কম)
                    if (t.endTime != null && t.endTime!.isBefore(now) && progress < 0.1) {
                      missedTasks.add(t);
                    } 
                    // উইকলি রুটিন বা অন্য টাস্ক (যাদের নির্দিষ্ট সময় নেই)
                    else if (t.startTime == null || t.endTime == null) {
                      otherTasks.add(t);
                    } 
                    // রেগুলার অ্যাক্টিভ টাস্ক
                    else {
                      activeTasks.add(t);
                    }
                  }

                  // সময় অনুযায়ী সর্টিং
                  activeTasks.sort((a, b) => a.startTime!.compareTo(b.startTime!));
                  missedTasks.sort((a, b) => a.startTime!.compareTo(b.startTime!));
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Tasks".tr(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 10),
                    if (activeTasks.isNotEmpty) ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: activeTasks.take(5).length,
                        itemBuilder: (context, index) {
                          return ActiveTaskCard(task: activeTasks[index], onUpdate: _updateTaskInFirestore);
                        },
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0, top: 4.0),
                        child: Text(
                          "No tasks listed for today.".tr(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],

                    if (missedTasks.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Missed Tasks".tr(),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                          TextButton(
                            onPressed: () => _showAllMissedTasks(missedTasks),
                            child: Text("See all".tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: missedTasks.take(4).length,
                        itemBuilder: (context, index) {
                          return ActiveTaskCard(task: missedTasks[index], onUpdate: _updateTaskInFirestore);
                        },
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (otherTasks.isNotEmpty) ...[
                      Text(
                        "Other Tasks".tr(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 10),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: otherTasks.length,
                        itemBuilder: (context, index) {
                          return ActiveTaskCard(task: otherTasks[index], onUpdate: _updateTaskInFirestore);
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageIcon(BuildContext context) {
    if (user == null) {
      return IconButton(
        icon: Icon(Icons.message_outlined, color: Theme.of(context).colorScheme.onSurface, size: 30),
        onPressed: () {},
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        int totalUnread = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final lastMessageSenderId = data['lastMessageSenderId'] ?? '';
            if (lastMessageSenderId != user!.uid) {
              final Map<String, dynamic> unreadMap = data['unreadCount'] ?? {};
              totalUnread += (unreadMap[user!.uid] as num? ?? 0).toInt();
            }
          }
        }

        return Stack(
          children: [
            IconButton(
              icon: Icon(Icons.message_outlined, color: Theme.of(context).colorScheme.onSurface, size: 30),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ConversationsScreen()),
                );
              },
            ),
            if (totalUnread > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$totalUnread',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTodayProgressCard(BuildContext context) {
    return StreamBuilder<DailyRoutine?>(
      stream: _todaysRoutineStream,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          _currentTasks = snapshot.data!.tasks;
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('${'Error'.tr()}: ${snapshot.error}'));
        }

        final DailyRoutine? routine = snapshot.data;

        if (routine == null || routine.tasks.isEmpty) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_task_rounded,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "No tasks set for today".tr(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Tap the 'New Task' button at the bottom of the screen to plan your study routine and stay productive!".tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Routine exists, calculate progress
        double progress = routine.progress;
        int progressPercentage = (progress * 100).toInt();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TodaysTasksScreen(dailyRoutine: routine),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).colorScheme.primary, const Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's Progress",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                      ),
                      Text(
                        '$progressPercentage%',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


}

// ==========================================
// Add Task Form (টাস্ক যুক্ত করার ফর্ম)
// ==========================================
class AddTaskBottomSheet extends StatefulWidget {
  final Function(Task) onTaskAdded;
  final String title;
  final String submitButtonText;

  const AddTaskBottomSheet({
    super.key, 
    required this.onTaskAdded,
    this.title = 'টাস্ক যুক্ত করুন (Add Task)',
    this.submitButtonText = 'Save',
  });

  @override
  State<AddTaskBottomSheet> createState() => _AddTaskBottomSheetState();
}

class _AddTaskBottomSheetState extends State<AddTaskBottomSheet> {
  String? _timeError;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _challengesController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isPrivate = false;
  String _selectedCategory = 'Study';
  final List<String> _categories = ['Study', 'Work', 'Sports', 'Other'];
  final List<Map<String, dynamic>> _customFolders = [];
  String? _selectedFolderSubject;
  String? _selectedFolderTopic;

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? (_startTime ?? TimeOfDay.now()) : (_endTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_startTime == null || _endTime == null) {
        setState(() => _timeError = 'Please select both start and end times.');
        return;
      }
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, _startTime!.hour, _startTime!.minute);
      var end = DateTime(now.year, now.month, now.day, _endTime!.hour, _endTime!.minute);

      if (end.isBefore(start)) {
        end = end.add(const Duration(days: 1));
      }

      final bufferTime = now.subtract(const Duration(minutes: 1));
      if (start.isBefore(bufferTime)) {
        setState(() => _timeError = 'Start time cannot be in the past!');
        return;
      }
      if (end.isBefore(bufferTime)) {
        setState(() => _timeError = 'End time cannot be in the past!');
        return;
      }

      final durationMinutes = end.difference(start).inMinutes;

      final newTask = Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _subjectController.text.trim(),
        subject: _subjectController.text.trim(),
        topic: _topicController.text.trim(),
        challenges: _challengesController.text.trim(),
        notes: _notesController.text.trim(),
        startTime: start,
        endTime: end,
        isPrivate: _isPrivate,
        category: _selectedCategory,
        totalDurationMinutes: durationMinutes,
      );

      widget.onTaskAdded(newTask);
      Navigator.pop(context);
    }
  }



  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final colorScheme = Theme.of(context).colorScheme;
    final onSurfaceColor = colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: bottomInset + 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: onSurfaceColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SharedTaskForm(
              categories: _categories,
              submitButtonText: widget.submitButtonText,
              onSubmit: (Task newTask) {
                widget.onTaskAdded(newTask);
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}



class EditTaskBottomSheet extends StatefulWidget {
  final Task task;
  final Function(Task) onTaskUpdated;

  const EditTaskBottomSheet({
    super.key,
    required this.task,
    required this.onTaskUpdated,
  });

  @override
  State<EditTaskBottomSheet> createState() => _EditTaskBottomSheetState();
}

class _EditTaskBottomSheetState extends State<EditTaskBottomSheet> {
  String? _timeError;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _subjectController;
  late final TextEditingController _topicController;
  late final TextEditingController _challengesController;
  late final TextEditingController _notesController;
  late final TextEditingController _reasonController;

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  late bool _isPrivate;
  late String _selectedCategory;
  String _selectedSubCategory = 'None';

  final List<String> _categories = ['Study', 'Work', 'Sports', 'Other'];
  final List<Map<String, dynamic>> _customFolders = [];
  String? _selectedFolderSubject;
  String? _selectedFolderTopic;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: widget.task.subject ?? widget.task.title);
    _topicController = TextEditingController(text: widget.task.topic ?? '');
    _challengesController = TextEditingController(text: widget.task.challenges ?? '');
    _notesController = TextEditingController(text: widget.task.notes ?? '');
    _reasonController = TextEditingController();

    if (widget.task.startTime != null) {
      _startTime = TimeOfDay.fromDateTime(widget.task.startTime!);
    }
    if (widget.task.endTime != null) {
      _endTime = TimeOfDay.fromDateTime(widget.task.endTime!);
    }
    _isPrivate = widget.task.isPrivate;
    _selectedCategory = widget.task.category ?? 'Study';
    _loadCustomFolders();
  }

  Future<void> _loadCustomFolders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('studyFolders')
          .get();
      final folders = snapshot.docs.map((doc) => doc.data()).toList();
      if (mounted) {
        setState(() {
          _customFolders.addAll(folders);
          final folderNames = folders.map((f) => f['name'] as String).toList();
          
          // Map initial category if it's a folder
          if (folderNames.contains(widget.task.category)) {
            _selectedCategory = 'Study';
            _selectedSubCategory = widget.task.category!;
          } else {
            _selectedCategory = widget.task.category ?? 'Study';
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading custom folders in EditTaskBottomSheet: $e");
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _topicController.dispose();
    _challengesController.dispose();
    _notesController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? (_startTime ?? TimeOfDay.now()) : (_endTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_startTime == null || _endTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select both Start and End Time.')),
        );
        return;
      }

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, _startTime!.hour, _startTime!.minute);
      var end = DateTime(now.year, now.month, now.day, _endTime!.hour, _endTime!.minute);

      if (end.isBefore(start)) {
        end = end.add(const Duration(days: 1));
      }

      // Check if start or end times were changed to a past time
      final bufferTime = now.subtract(const Duration(minutes: 1));
      final bool startChanged = widget.task.startTime == null ||
          widget.task.startTime!.hour != _startTime!.hour ||
          widget.task.startTime!.minute != _startTime!.minute;
      final bool endChanged = widget.task.endTime == null ||
          widget.task.endTime!.hour != _endTime!.hour ||
          widget.task.endTime!.minute != _endTime!.minute;

      if (startChanged && start.isBefore(bufferTime)) {
          setState(() {
            _timeError = 'Start time cannot be in the past!';
          });
          return;
      }
      if (endChanged && end.isBefore(bufferTime)) {
          setState(() {
            _timeError = 'End time cannot be in the past!';
          });
          return;
      }

      final durationMinutes = end.difference(start).inMinutes;
      final reason = _reasonController.text.trim();
      final updatedNotes = widget.task.notes != null && widget.task.notes!.isNotEmpty
          ? '${_notesController.text.trim()}\n[Edit Log: $reason]'
          : '${_notesController.text.trim()}\n[Edit Log: $reason]';

      final updatedComments = List<String>.from(widget.task.comments)..add(reason);

      final updatedTask = widget.task.copyWith(
        title: _subjectController.text.trim(),
        subject: _subjectController.text.trim(),
        topic: _topicController.text.trim(),
        challenges: _challengesController.text.trim(),
        notes: updatedNotes,
        startTime: start,
        endTime: end,
        isPrivate: _isPrivate,
        category: (_selectedCategory == 'Study' && _selectedSubCategory != 'None') ? _selectedSubCategory : _selectedCategory,
        totalDurationMinutes: durationMinutes,
        hasBeenEdited: true, // Mark as edited
        comments: updatedComments,
      );

      widget.onTaskUpdated(updatedTask);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final colorScheme = Theme.of(context).colorScheme;
    final onSurfaceColor = colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: bottomInset + 24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Task (Once)',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: onSurfaceColor,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Subject Name (Read-only)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subject Name (Read-only)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: onSurfaceColor.withValues(alpha: 0.6), fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _subjectController,
                    enabled: false,
                    decoration: InputDecoration(
                      hintText: 'Subject Name',
                      prefixIcon: const Icon(Icons.subject),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: onSurfaceColor.withValues(alpha: 0.2)),
                      ),
                    ),
                    style: TextStyle(color: onSurfaceColor.withValues(alpha: 0.6)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Topic Name
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Topic Name',
                    style: TextStyle(fontWeight: FontWeight.bold, color: onSurfaceColor, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _topicController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Chapter 3, Algebra',
                      prefixIcon: const Icon(Icons.title),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    style: TextStyle(color: onSurfaceColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Possible Challenges
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Possible Challenges',
                    style: TextStyle(fontWeight: FontWeight.bold, color: onSurfaceColor, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _challengesController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Power outage, complex equations',
                      prefixIcon: const Icon(Icons.warning_amber_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    style: TextStyle(color: onSurfaceColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Task Goal / Notes
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task Goal / Notes',
                    style: TextStyle(fontWeight: FontWeight.bold, color: onSurfaceColor, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Complete exercise questions 1-10',
                      prefixIcon: const Icon(Icons.notes),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    maxLines: 3,
                    style: TextStyle(color: onSurfaceColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Mandatory Reason for Change
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What/Why did you change? *',
                    style: TextStyle(fontWeight: FontWeight.bold, color: onSurfaceColor, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _reasonController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Adjusting times, fixing target topic',
                      prefixIcon: const Icon(Icons.history_edu_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Reason for change is required'
                        : null,
                    style: TextStyle(color: onSurfaceColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Start/End Time pickers
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(true),
                      icon: Icon(Icons.access_time, color: onSurfaceColor),
                      label: Text(
                        _startTime?.format(context) ?? 'Start Time',
                        style: TextStyle(color: onSurfaceColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: onSurfaceColor.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(false),
                      icon: Icon(Icons.access_time, color: onSurfaceColor),
                      label: Text(
                        _endTime?.format(context) ?? 'End Time',
                        style: TextStyle(color: onSurfaceColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: onSurfaceColor.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category Choice Chips
              Text(
                'Category',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: onSurfaceColor),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10.0,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(
                      cat.tr(),
                      style: TextStyle(color: isSelected ? Colors.white : onSurfaceColor),
                    ),
                    selected: isSelected,
                    selectedColor: colorScheme.primary,
                    backgroundColor: colorScheme.surface,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = cat;
                          if (cat != 'Study') {
                            _selectedSubCategory = 'None';
                          }
                          _selectedFolderSubject = null;
                          _selectedFolderTopic = null;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              
              // Sub-category (Folder) Selection
              if (_selectedCategory == 'Study') ...[
                const SizedBox(height: 16),
                Text(
                  'Sub-category (Folder)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: onSurfaceColor),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedSubCategory,
                  items: ['None', ..._customFolders.map((f) => f['name'] as String)].toSet().map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: onSurfaceColor)))).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedSubCategory = v ?? 'None';
                      _selectedFolderSubject = null;
                      _selectedFolderTopic = null;
                    });
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
              // Syllabus Integration for custom folders
              Builder(
                builder: (context) {
                  final matchingFolder = _customFolders.firstWhere(
                    (f) => f['name'] == _selectedSubCategory,
                    orElse: () => {},
                  );
                  final subjects = matchingFolder['subjects'] as List<dynamic>? ?? [];

                  if (matchingFolder.isNotEmpty && subjects.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          'Select Subject from Syllabus'.tr(),
                          style: TextStyle(fontWeight: FontWeight.bold, color: onSurfaceColor, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: subjects.map((sub) {
                            final subName = sub['name'] as String;
                            final isSubSelected = _selectedFolderSubject == subName;
                            return ChoiceChip(
                              label: Text(subName),
                              selected: isSubSelected,
                              selectedColor: colorScheme.secondary,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedFolderSubject = selected ? subName : null;
                                  _selectedFolderTopic = null;
                                  if (selected) {
                                    _subjectController.text = subName;
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        if (_selectedFolderSubject != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Select Topic from Syllabus'.tr(),
                            style: TextStyle(fontWeight: FontWeight.bold, color: onSurfaceColor, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Builder(
                            builder: (context) {
                              final subMap = subjects.firstWhere(
                                (s) => s['name'] == _selectedFolderSubject,
                                orElse: () => {},
                              );
                              final topics = subMap['topics'] as List<dynamic>? ?? [];
                              if (topics.isEmpty) {
                                  return Text(
                                    'No topics in this subject'.tr(),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  );
                              }
                              return Wrap(
                                spacing: 8,
                                children: topics.map((t) {
                                  final topicName = t['name'] as String;
                                  final isTopicSelected = _selectedFolderTopic == topicName;
                                  return ChoiceChip(
                                    label: Text(topicName),
                                    selected: isTopicSelected,
                                    selectedColor: colorScheme.secondary.withValues(alpha: 0.8),
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedFolderTopic = selected ? topicName : null;
                                        if (selected) {
                                          _topicController.text = topicName;
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 16),

              // Private task switch toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Private Task',
                  style: TextStyle(fontWeight: FontWeight.bold, color: onSurfaceColor),
                ),
                subtitle: Text(
                  'Hide task name from others',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                value: _isPrivate,
                activeColor: colorScheme.primary,
                onChanged: (val) => setState(() => _isPrivate = val),
              ),
              const SizedBox(height: 24),

              // Submit button
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('পরিবর্তন সংরক্ষণ করুন (Save Changes)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
}
}

// ==========================================
// Active Task Card (অ্যাক্টিভ টাস্ক কার্ড - টাইমারসহ)
// ==========================================
class ActiveTaskCard extends StatefulWidget {
  final Task task;
  final Function(Task) onUpdate;

  const ActiveTaskCard({super.key, required this.task, required this.onUpdate});

  @override
  State<ActiveTaskCard> createState() => _ActiveTaskCardState();
}

class _ActiveTaskCardState extends State<ActiveTaskCard> {
  Timer? _timer;
  late int _elapsedSeconds;
  late String _status;
  final List<Map<String, dynamic>> _folders = [];

  @override
  void initState() {
    super.initState();
    _elapsedSeconds = widget.task.elapsedSeconds;
    _status = widget.task.status;
    if (_status == 'running') {
      _startTimer(saveToDb: false);
    }
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('studyFolders')
          .get();
      final list = snapshot.docs.map((doc) => doc.data()).toList();
      if (mounted) {
        setState(() {
          _folders.addAll(list);
        });
      }
    } catch (e) {
      debugPrint("Error loading folders in ActiveTaskCard: $e");
    }
  }

  Color _getCategoryColor(String category) {
    for (var folder in _folders) {
      if (folder['name'] == category && folder['color'] != null) {
        try {
          return Color(int.parse(folder['color'].replaceFirst('#', '0xFF')));
        } catch (_) {}
      }
    }
    switch (category) {
      case 'Study':
        return const Color(0xFF6366F1);
      case 'Work':
        return const Color(0xFFD97706);
      case 'Sports':
        return const Color(0xFF10B981);
      default:
        return Colors.blueGrey;
    }
  }

  @override
  void didUpdateWidget(covariant ActiveTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ড্যাশবোর্ডের ডাটাবেজ আপডেট হলে কার্ডের স্টেট সিঙ্ক করা
    if (oldWidget.task.id != widget.task.id) {
      _timer?.cancel();
      _elapsedSeconds = widget.task.elapsedSeconds;
      _status = widget.task.status;
      if (_status == 'running') {
         _startTimer(saveToDb: false);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer({bool saveToDb = true}) {
    if (!mounted) return;
    setState(() {
      _status = 'running';
    });
    if (saveToDb) {
       widget.onUpdate(widget.task.copyWith(status: 'running', elapsedSeconds: _elapsedSeconds));
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
        if (_elapsedSeconds > 0 && _elapsedSeconds % 30 == 0) {
          widget.onUpdate(widget.task.copyWith(status: 'running', elapsedSeconds: _elapsedSeconds));
        }
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _status = 'paused';
    });
    widget.onUpdate(widget.task.copyWith(status: 'paused', elapsedSeconds: _elapsedSeconds));
  }

  void _showMissedTaskWarningDialog() {
    String formatTime(DateTime? dt) {
      if (dt == null) return '';
      return DateFormat('h:mm a').format(dt);
    }
    String formatDate(DateTime? dt) {
      if (dt == null) return '';
      return DateFormat('MMM d, yyyy').format(dt);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              Text(
                'Missed Task Alert'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This was a missed task.'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              if (widget.task.startTime != null) ...[
                Text(
                  '${'Scheduled Start Time'.tr()}:',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                Text(
                  '${formatDate(widget.task.startTime)} at ${formatTime(widget.task.startTime)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
              ],
              if (widget.task.endTime != null) ...[
                Text(
                  '${'Scheduled End Time'.tr()}:',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                Text(
                  '${formatDate(widget.task.endTime)} at ${formatTime(widget.task.endTime)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'Do you want to start it now?'.tr(),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'No'.tr(),
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _startTimer(saveToDb: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Yes, Start'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDoneDialog() {
    bool wasRunning = _status == 'running';
    if (wasRunning) _timer?.cancel();

    final TextEditingController noteController = TextEditingController();
    int totalTargetSeconds = widget.task.totalDurationMinutes * 60;
    double progress = totalTargetSeconds > 0 ? _elapsedSeconds / totalTargetSeconds : 0.0;
    bool canReset = progress < 0.70; // ৭০% এর কম হলে রিসেট বাটন দেখাবে

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Complete Task', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('পড়তে গিয়ে কোনো সমস্যার সম্মুখীন হয়েছেন কি? (নোট)'),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'আপনার নোট লিখুন...',
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            if (canReset)
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _elapsedSeconds = 0;
                    _status = 'pending';
                  });
                  widget.onUpdate(widget.task.copyWith(status: 'pending', elapsedSeconds: 0));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              )
            else
              const SizedBox.shrink(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (wasRunning) _startTimer(saveToDb: false);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    _timer?.cancel();
                    
                    final completedTask = widget.task.copyWith(
                      status: 'completed',
                      isCompleted: true,
                      elapsedSeconds: _elapsedSeconds,
                      completedDurationMinutes: _elapsedSeconds ~/ 60,
                      completionNote: noteController.text.trim(),
                    );
                    
                    widget.onUpdate(completedTask);
                    
                    try {
                      final res = await GamificationService.awardXP(
                        GamificationService.xpTaskComplete,
                        reason: 'task_complete',
                      );
                      if (context.mounted && res.isNotEmpty) {
                        final int xpAwarded = res['xpAwarded'] ?? 0;
                        final List<String> newBadges = List<String>.from(res['newBadges'] ?? []);
                        
                        String message = '🎉 Task Completed! +$xpAwarded XP';
                        if (newBadges.isNotEmpty) {
                          message += '\n🏆 Unlocked new badge(s): ${newBadges.join(", ")}!';
                        }
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              message,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint('Error awarding XP: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

                  ),
                  child: const Text('Submit & Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _editTask() {
    if (widget.task.hasBeenEdited) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => EditTaskBottomSheet(
        task: widget.task,
        onTaskUpdated: widget.onUpdate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalTargetSeconds = widget.task.totalDurationMinutes * 60;
    int remainingSeconds = totalTargetSeconds - _elapsedSeconds;
    bool isOverdue = remainingSeconds < 0;
    
    double progress = totalTargetSeconds > 0 ? (_elapsedSeconds / totalTargetSeconds) : 0.0;
    if (progress > 1.0) progress = 1.0;

    String formatTime(int seconds) {
      int absSeconds = seconds.abs();
      int m = absSeconds ~/ 60;
      int s = absSeconds % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }

    String timeText = formatTime(remainingSeconds);
    if (isOverdue) timeText = '-$timeText'; // মাইনাস টাইম

    String dateText = '';
    if (widget.task.startTime != null) {
       dateText = DateFormat('MMM d, h:mm a').format(widget.task.startTime!);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Title and Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    widget.task.subject ?? widget.task.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Bell icon (Notification)
                GestureDetector(
                  onTap: () {
                     // Toggle alarmEnabled
                     widget.onUpdate(widget.task.copyWith(alarmEnabled: !widget.task.alarmEnabled));
                  },
                  child: Icon(
                    widget.task.alarmEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded, 
                    size: 18,
                    color: widget.task.alarmEnabled ? Theme.of(context).colorScheme.primary : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                // Open in full view icon
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => TaskDetailsScreen(
                        task: widget.task,
                        onUpdate: widget.onUpdate,
                      )),
                    );
                  },
                  child: Icon(Icons.open_in_new_rounded, size: 18, color: Theme.of(context).colorScheme.secondary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: Tags and Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Tags
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (widget.task.category != null && widget.task.category!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(widget.task.category!).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _getCategoryColor(widget.task.category!).withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              widget.task.category!.tr(),
                              style: TextStyle(
                                color: _getCategoryColor(widget.task.category!),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (widget.task.topic != null && widget.task.topic!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2), width: 1),
                            ),
                            child: Text(
                              widget.task.topic!,
                              style: const TextStyle(color: Colors.blueGrey, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Date
                Text(
                  dateText,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Row 3: Duration info right above progress bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Duration text (Slightly larger than progress percentage)
                Text(
                  '${widget.task.totalDurationMinutes} min',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                // Stopwatch timer text
                Text(
                  timeText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isOverdue ? Colors.red : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            
            // Row 4: Progress Bar
            Row(
              children: [
                Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade300,
                    color: Theme.of(context).colorScheme.primary,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Row 5: Control Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_status == 'pending' || _status == 'paused')
                  ElevatedButton.icon(
                    icon: Icon(_status == 'paused' ? Icons.play_arrow_rounded : Icons.play_circle_fill_rounded, size: 18),
                    label: Text(_status == 'paused' ? 'Resume' : 'Start', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final now = DateTime.now();
                      double progress = widget.task.totalDurationMinutes > 0
                          ? (_elapsedSeconds / (widget.task.totalDurationMinutes * 60))
                          : 0.0;
                      bool isMissed = widget.task.endTime != null && widget.task.endTime!.isBefore(now) && progress < 0.1;

                      if (isMissed && _status == 'pending') {
                        _showMissedTaskWarningDialog();
                      } else {
                        _startTimer(saveToDb: true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      elevation: 0,
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    ),
                  )
                else if (_status == 'running')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.pause_rounded, size: 18),
                    label: const Text('Pause', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    onPressed: _pauseTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEF3C7), // Light Amber
                      foregroundColor: const Color(0xFFD97706), // Amber 600
                      elevation: 0,
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    ),
                  ),
                
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Done', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  onPressed: _showDoneDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDCFCE7), // Light Green
                    foregroundColor: const Color(0xFF16A34A), // Green 600
                    elevation: 0,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  ),
                ),

                ElevatedButton.icon(
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  onPressed: widget.task.hasBeenEdited ? null : _editTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.task.hasBeenEdited ? Colors.grey.shade200 : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    foregroundColor: widget.task.hasBeenEdited ? Colors.grey : Theme.of(context).colorScheme.primary,
                    elevation: 0,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}