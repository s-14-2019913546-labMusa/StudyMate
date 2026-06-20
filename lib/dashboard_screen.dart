import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'daily_routine.dart';
import 'todays_tasks_screen.dart';
import 'task_details_screen.dart'; // নতুন ফাইলটি ইমপোর্ট করা হলো
import 'tools_screen.dart'; // Tools স্ক্রিন ইমপোর্ট
import 'profile_screen.dart'; // Profile স্ক্রিন ইমপোর্ট
import 'chat_screen.dart';

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
  final String _todayDateFormatted = DateFormat('EEEE, d MMMM').format(DateTime.now());
  final String _todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now()); // e.g., "2023-10-27"

  Stream<DailyRoutine?>? _todaysRoutineStream;
  int _bottomNavIndex = 0; // বটম নেভিগেশন বারের ইনডেক্স

  @override
  void initState() {
    super.initState();
    if (user != null) {
      _todaysRoutineStream = _fetchTodaysRoutine();
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
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task Added Successfully!')));
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
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI Routine Added Successfully!')));
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
      }
    }
  }

  // সব মিসড টাস্ক দেখানোর বটম শিট
  void _showAllMissedTasks(List<Task> missedTasks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "All Missed Tasks", 
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.build_circle_outlined), selectedIcon: Icon(Icons.build_circle_rounded), label: 'Tools'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
      floatingActionButton: _bottomNavIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true, // কিবোর্ড উঠলে ফর্ম স্ক্রল করার জন্য
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => AddTaskBottomSheet(
                    onTaskAdded: (newTask) {
                      _addTaskToFirestore(newTask);
                    },
                  ),
                );
              },
              label: Text(
                'New Task',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              icon: const Icon(Icons.add),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 8,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
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
                    Text(
                      'Welcome back!',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
                _buildMessageIcon(context),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _todayDateFormatted,
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
                      "Today's Tasks",
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
                          "আজকের এখন কোনো টাস্ক লিস্টেড নেই।",
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
                            "Missed Tasks",
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                          TextButton(
                            onPressed: () => _showAllMissedTasks(missedTasks),
                            child: const Text("সব দেখুন", style: TextStyle(fontWeight: FontWeight.bold)),
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
                        "Other Tasks",
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final DailyRoutine? routine = snapshot.data;

        if (routine == null || routine.tasks.isEmpty) {
          // No routine or no tasks for today
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      'No routine set for today. Progress is 0%.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        // For demonstration, add a dummy routine
                        _addDummyRoutine();
                      },
                      child: const Text('Set Today\'s Routine'),
                    )
                  ],
                ),
              ),
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

  // Dummy routine for testing and initial setup
  Future<void> _addDummyRoutine() async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to set a routine.')));
      return;
    }

    final dummyRoutine = DailyRoutine(
      id: _todayDocId,
      userId: user!.uid,
      date: DateTime.now(),
      tasks: [
        Task(id: 'task1', title: 'Complete Flutter UI', totalDurationMinutes: 90, completedDurationMinutes: 45),
        Task(id: 'task2', title: 'Review Math Chapter', totalDurationMinutes: 60, completedDurationMinutes: 0),
        Task(id: 'task3', title: 'Read English Novel', totalDurationMinutes: 45, completedDurationMinutes: 30),
      ],
    );

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('dailyRoutines')
        .doc(_todayDocId)
        .set(dummyRoutine.toMap());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dummy routine added for today!')));
  }
}

// ==========================================
// Add Task Form (টাস্ক যুক্ত করার ফর্ম)
// ==========================================
class AddTaskBottomSheet extends StatefulWidget {
  final Function(Task) onTaskAdded;
  const AddTaskBottomSheet({super.key, required this.onTaskAdded});

  @override
  State<AddTaskBottomSheet> createState() => _AddTaskBottomSheetState();
}

class _AddTaskBottomSheetState extends State<AddTaskBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isPrivate = false;
  String _selectedCategory = 'Study'; // Default category

  final List<String> _categories = ['Study', 'Work', 'Sports', 'Other'];

  @override
  void dispose() {
    _subjectController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select both Start and End Time.')));
        return;
      }

      // সময় ক্যালকুলেশন
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, _startTime!.hour, _startTime!.minute);
      var end = DateTime(now.year, now.month, now.day, _endTime!.hour, _endTime!.minute);

      // যদি শেষের সময় শুরুর সময়ের আগে হয়, ধরে নেওয়া হবে এটি পরের দিনের সময়
      if (end.isBefore(start)) {
        end = end.add(const Duration(days: 1));
      }

      final durationMinutes = end.difference(start).inMinutes;

      final newTask = Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _subjectController.text.trim(),
        subject: _subjectController.text.trim(),
        notes: _notesController.text.trim(),
        startTime: start,
        endTime: end,
        isPrivate: _isPrivate,
        category: _selectedCategory,
        totalDurationMinutes: durationMinutes,
      );

      widget.onTaskAdded(newTask);
      Navigator.pop(context); // ফর্ম বন্ধ করে দেবে
    }
  }

  @override
  Widget build(BuildContext context) {
    // কিবোর্ডের জন্য নিচে প্যাডিং যোগ করা
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: bottomInset + 24.0),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add New Task',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // সাবজেক্টের নাম
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: 'Subject Name', prefixIcon: Icon(Icons.subject)),
                validator: (val) => val == null || val.isEmpty ? 'Enter a subject name' : null,
              ),
              const SizedBox(height: 16),
              
              // টাস্ক গোল বা নোটস
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Task Goal / Notes', prefixIcon: Icon(Icons.notes)),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // সময় নির্বাচন
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(true),
                      icon: const Icon(Icons.access_time),
                      label: Text(_startTime?.format(context) ?? 'Start Time'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(false),
                      icon: const Icon(Icons.access_time),
                      label: Text(_endTime?.format(context) ?? 'End Time'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ক্যাটাগরি চিপস
              Text('Category', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10.0,
                children: _categories.map((cat) {
                  return ChoiceChip(
                    label: Text(cat),
                    selected: _selectedCategory == cat,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCategory = cat);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // প্রাইভেট টগল
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Private Task', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Hide task name from others'),
                value: _isPrivate,
                activeColor: Theme.of(context).colorScheme.primary,
                onChanged: (val) => setState(() => _isPrivate = val),
              ),
              const SizedBox(height: 24),

              // যুক্ত করার বাটন
              ElevatedButton(
                onPressed: _submit,
                child: const Text('টাস্ক যুক্ত করুন (Add Task)'),
              ),
            ],
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

  @override
  void initState() {
    super.initState();
    _elapsedSeconds = widget.task.elapsedSeconds;
    _status = widget.task.status;
    if (_status == 'running') {
      _startTimer(saveToDb: false);
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
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _elapsedSeconds = 0;
                    _status = 'pending';
                  });
                  widget.onUpdate(widget.task.copyWith(status: 'pending', elapsedSeconds: 0));
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _timer?.cancel();
                    widget.onUpdate(widget.task.copyWith(
                      status: 'completed',
                      isCompleted: true,
                      elapsedSeconds: _elapsedSeconds,
                      completedDurationMinutes: _elapsedSeconds ~/ 60,
                      completionNote: noteController.text.trim(),
                    ));
                  },
                  child: const Text('Submit & Done'),
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
     TextEditingController titleController = TextEditingController(text: widget.task.subject ?? widget.task.title);

     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
          title: const Text('Edit Task (Once)'),
          content: TextField(
             controller: titleController,
             decoration: const InputDecoration(labelText: 'Task Subject Name'),
          ),
          actions: [
             TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
             ElevatedButton(
               onPressed: () {
                  Navigator.pop(ctx);
                  widget.onUpdate(widget.task.copyWith(
                     subject: titleController.text.trim(),
                     title: titleController.text.trim(),
                     hasBeenEdited: true, // একবার এডিট করা হয়ে গেল
                  ));
               },
               child: const Text('Save'),
             ),
          ]
       )
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // শিরোনাম এবং ডেট/টাইম
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.task.subject ?? widget.task.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateText,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // স্টপওয়াচ টাইমার
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      timeText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: isOverdue ? Colors.red : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, size: 22),
                      color: Theme.of(context).colorScheme.secondary,
                      tooltip: 'টাস্ক দেখুন (View Task)',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(), // আইকনের ডিফল্ট প্যাডিং কমানোর জন্য
                      onPressed: () {
                        Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => TaskDetailsScreen(
                            task: widget.task,
                            onUpdate: widget.onUpdate, // ডাটাবেস আপডেটের ফাংশনটি পাস করা হলো
                          )),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // প্রোগ্রেসবার
            Row(
              children: [
                Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade300,
                    color: Theme.of(context).colorScheme.primary,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // কন্ট্রোল বাটনগুলো (Start, Done, Edit)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_status == 'pending' || _status == 'paused')
                  ElevatedButton.icon(
                    icon: Icon(_status == 'paused' ? Icons.play_arrow_rounded : Icons.play_circle_fill_rounded),
                    label: Text(_status == 'paused' ? 'Resume' : 'Start'),
                    onPressed: () => _startTimer(saveToDb: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  )
                else if (_status == 'running')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.pause_rounded),
                    label: const Text('Pause'),
                    onPressed: _pauseTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEF3C7), // Light Amber
                      foregroundColor: const Color(0xFFD97706), // Amber 600
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Done'),
                  onPressed: _showDoneDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDCFCE7), // Light Green
                    foregroundColor: const Color(0xFF16A34A), // Green 600
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  color: widget.task.hasBeenEdited ? Colors.grey : Theme.of(context).colorScheme.primary,
                  onPressed: widget.task.hasBeenEdited ? null : _editTask,
                  tooltip: 'Edit Task (Once)',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}