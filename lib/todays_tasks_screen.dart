import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'daily_routine.dart';
import 'dashboard_screen.dart'; // For AddTaskBottomSheet
import 'language_manager.dart';

// ==========================================
// 6. Today's Tasks Screen (আজকের টাস্ক স্ক্রিন)
// ==========================================
class TodaysTasksScreen extends StatefulWidget {
  final DailyRoutine? dailyRoutine;
  const TodaysTasksScreen({super.key, this.dailyRoutine});

  @override
  State<TodaysTasksScreen> createState() => _TodaysTasksScreenState();
}

class _TodaysTasksScreenState extends State<TodaysTasksScreen> {
  // We need to manage the state of tasks here to update checkboxes
  // For now, we'll just use a local list and print, but in a real app
  // this would update Firestore.
  List<Task> _tasks = [];

  @override
  void initState() {
    super.initState();
    if (widget.dailyRoutine != null) {
      // Create a deep copy of tasks to manage local state
      _tasks = widget.dailyRoutine!.tasks.map((task) => task.copyWith()).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Today's Tasks",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface, // Consistent background
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface), // Back button color
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _tasks.isEmpty
          ? Center(
              child: Text(
                "No tasks for today.",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                final bool isCompleted = task.isCompleted;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 5, // শ্যাডোকে স্পষ্ট করার জন্য Elevation সামান্য বাড়ানো হলো
                  shadowColor: isCompleted
                      ? Colors.green.withValues(alpha: 0.5) // সম্পন্ন হলে সবুজ শ্যাডো
                      : Colors.red.withValues(alpha: 0.4), // অসম্পূর্ণ থাকলে লাল শ্যাডো
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: Theme.of(context).cardColor, // Card style color
                  child: ListTile(
                    title: Text(
                      task.isPrivate ? '🔒 Private Task' : task.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            decoration: task.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                            color: isCompleted
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    subtitle: Text(
                      '${task.completedDurationMinutes} / ${task.totalDurationMinutes} minutes',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            decoration: isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                            color: isCompleted
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18, color: Colors.teal),
                          tooltip: 'Duplicate Task'.tr(),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              builder: (context) => AddTaskBottomSheet(
                                onTaskAdded: (newTask) async {
                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user == null) return;
                                  final todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now());
                                  final docRef = FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .collection('dailyRoutines')
                                      .doc(todayDocId);
                                  
                                  try {
                                    await docRef.update({
                                      'tasks': FieldValue.arrayUnion([newTask.toMap()])
                                    });
                                    setState(() {
                                      _tasks.add(newTask);
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Task Duplicated Successfully!'.tr())),
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint("Error duplicating task to today's routine: $e");
                                  }
                                },
                                title: 'Duplicate Task'.tr(),
                              ),
                            );
                          },
                        ),
                        Checkbox(
                          value: task.isCompleted,
                          onChanged: (bool? newValue) {
                            setState(() {
                              task.isCompleted = newValue ?? false;
                              if (task.isCompleted) {
                                task.completedDurationMinutes = task.totalDurationMinutes;
                              } else {
                                task.completedDurationMinutes = 0;
                              }
                            });
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              final todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now());
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection('dailyRoutines')
                                  .doc(todayDocId)
                                  .update({
                                    'tasks': _tasks.map((t) => t.toMap()).toList()
                                  });
                            }
                          },
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}