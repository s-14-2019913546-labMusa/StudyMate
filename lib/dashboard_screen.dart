import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'daily_routine.dart';
import 'todays_tasks_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBarContent(context), // Use a regular AppBar for sticky header content
      body: SingleChildScrollView(
        // Changed from CustomScrollView to SingleChildScrollView
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 80), // Adjust padding as AppBar now handles top
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // তারিখ
            Text(
              _todayDateFormatted,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),

            // আজকের প্রোগ্রেসবার
            _buildTodayProgressCard(context),
            const SizedBox(height: 30),

            // Other Active Tasks section will go here
            Text(
              "Active Tasks",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 10),
            
            // Active Tasks Stream List
            StreamBuilder<DailyRoutine?>(
              stream: _todaysRoutineStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data == null || snapshot.data!.tasks.isEmpty) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('No active tasks for now.'),
                  ));
                }

                // সম্পন্ন হয়নি এমন টাস্কগুলো ফিল্টার করা
                List<Task> activeTasks = snapshot.data!.tasks.where((t) => t.status != 'completed').toList();
                
                // সময় অনুযায়ী সর্টিং (Current time or later first)
                activeTasks.sort((a, b) {
                  if (a.startTime == null && b.startTime == null) return 0;
                  if (a.startTime == null) return 1;
                  if (b.startTime == null) return -1;
                  return a.startTime!.compareTo(b.startTime!);
                });

                // সর্বোচ্চ ৫টি টাস্ক দেখানো হবে
                List<Task> visibleTasks = activeTasks.take(5).toList();

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleTasks.length,
                  itemBuilder: (context, index) {
                    return ActiveTaskCard(
                      task: visibleTasks[index],
                      onUpdate: _updateTaskInFirestore,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
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
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  AppBar _buildAppBarContent(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      toolbarHeight: 150.0, // Adjust height to fit content
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top: App Name in a Box with shadow
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'StudyMate',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            const SizedBox(height: 20),
            // Bottom: User name, welcome and Message Icon
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
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
          ],
        ),
      ),
    );
  }

  Widget _buildMessageIcon(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(Icons.message_outlined, color: Theme.of(context).colorScheme.onSurface, size: 30),
          onPressed: () {
            // মেসেজ পেইজে যাওয়ার লজিক এখানে হবে
            // print('Message icon pressed');
          },
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              '3', // মেসেজের সংখ্যা এখানে দেখাবে
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
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
            elevation: 4,
            shadowColor: Colors.black.withValues(alpha: 0.08), // Card style shadow
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Theme.of(context).cardColor, // Card style color
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
          child: Card(
            elevation: 4,
            shadowColor: Colors.black.withValues(alpha: 0.08), // Card style shadow
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Theme.of(context).cardColor, // Card style color
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's Progress",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      Text(
                        '$progressPercentage%',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                    borderRadius: BorderRadius.circular(6),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                Text(
                  timeText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: isOverdue ? Colors.red : Theme.of(context).colorScheme.primary,
                  ),
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
                    icon: Icon(_status == 'paused' ? Icons.play_arrow : Icons.play_circle_fill),
                    label: Text(_status == 'paused' ? 'Resume' : 'Start'),
                    onPressed: () => _startTimer(saveToDb: true),
                  )
                else if (_status == 'running')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                    onPressed: _pauseTimer,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  ),
                
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Done'),
                  onPressed: _showDoneDialog,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),

                IconButton(
                  icon: const Icon(Icons.edit),
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