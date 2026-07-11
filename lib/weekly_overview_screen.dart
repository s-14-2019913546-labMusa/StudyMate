import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'daily_routine.dart';
import 'tools_screen.dart'; // To use AddWeeklyRoutineTaskBottomSheet
import 'language_manager.dart';

class WeeklyOverviewScreen extends StatefulWidget {
  const WeeklyOverviewScreen({super.key});

  @override
  State<WeeklyOverviewScreen> createState() => _WeeklyOverviewScreenState();
}

class _WeeklyOverviewScreenState extends State<WeeklyOverviewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _days = ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  @override
  void initState() {
    super.initState();
    // Default tab to today's day if possible
    final todayDay = DateFormat('EEEE').format(DateTime.now());
    int initialIndex = _days.indexOf(todayDay);
    if (initialIndex == -1) initialIndex = 0;
    
    _tabController = TabController(length: 7, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteTask(String day, String taskId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Task'.tr()),
        content: Text('Are you sure you want to delete this task from your weekly routine?'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('weeklyRoutines')
          .doc(day)
          .collection('tasks')
          .doc(taskId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task deleted successfully.'.tr())),
        );
      }
    } catch (e) {
      debugPrint("Error deleting weekly task: $e");
    }
  }

  Future<void> _duplicateDay(String sourceDay) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? targetDay = _days.firstWhere((d) => d != sourceDay);

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Duplicate Day Routine'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${'Copy all tasks from'.tr()} $sourceDay ${'to:'.tr()}'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: targetDay,
                items: _days
                    .where((d) => d != sourceDay)
                    .map((d) => DropdownMenuItem(value: d, child: Text(d.tr())))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      targetDay = val;
                    });
                  }
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Duplicate'.tr()),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || targetDay == null) return;

    try {
      // 1. Get source tasks
      final sourceSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('weeklyRoutines')
          .doc(sourceDay)
          .collection('tasks')
          .get();

      if (sourceSnap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No tasks found on source day to copy.'.tr())),
          );
        }
        return;
      }

      // 2. Copy to target day
      final batch = FirebaseFirestore.instance.batch();
      final targetCollectionRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('weeklyRoutines')
          .doc(targetDay)
          .collection('tasks');

      for (var doc in sourceSnap.docs) {
        final newId = UniqueKey().toString();
        final data = doc.data();
        data['id'] = newId; // Update inside map
        batch.set(targetCollectionRef.doc(newId), data);
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'Successfully copied tasks to'.tr()} ${targetDay!.tr()}!')),
        );
      }
    } catch (e) {
      debugPrint("Error duplicating day tasks: $e");
    }
  }

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Weekly Routine Overview'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _days.map((day) => Tab(text: day.tr())).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _days.map((day) => _buildDayTabContent(day)).toList(),
      ),
    );
  }

  Widget _buildDayTabContent(String day) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("User not logged in"));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('weeklyRoutines')
          .doc(day)
          .collection('tasks')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        final List<Task> tasks = docs.map((doc) {
          return Task.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();

        // Sort tasks by start time
        tasks.sort((a, b) {
          if (a.startTime == null && b.startTime == null) return 0;
          if (a.startTime == null) return 1;
          if (b.startTime == null) return -1;
          final aMinutes = a.startTime!.hour * 60 + a.startTime!.minute;
          final bMinutes = b.startTime!.hour * 60 + b.startTime!.minute;
          return aMinutes.compareTo(bMinutes);
        });

        return Column(
          children: [
            // Quick action buttons for the day
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _duplicateDay(day),
                      icon: const Icon(Icons.copy_all),
                      label: Text('Duplicate Day'.tr()),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => AddWeeklyRoutineTaskBottomSheet(initialDay: day),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: Text('Add Task'.tr()),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, size: 64, color: Theme.of(context).disabledColor),
                          const SizedBox(height: 16),
                          Text('No tasks set for this day.'.tr(), style: TextStyle(color: Theme.of(context).disabledColor)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        final String timeStr = task.startTime != null && task.endTime != null
                            ? '${DateFormat.jm().format(task.startTime!)} - ${DateFormat.jm().format(task.endTime!)}'
                            : 'No time set';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            task.category == 'Work'
                                                ? Icons.work_outline
                                                : task.category == 'Sports'
                                                    ? Icons.sports_soccer
                                                    : Icons.book_outlined,
                                            size: 18,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            (task.category ?? 'Study').tr(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        task.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                        ],
                                      ),
                                      if (task.notes != null && task.notes!.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          task.notes!,
                                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                                      onPressed: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          useSafeArea: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (context) => AddWeeklyRoutineTaskBottomSheet(
                                            taskToEdit: task,
                                            initialDay: day,
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 18, color: Colors.teal),
                                      onPressed: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          useSafeArea: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (context) => AddWeeklyRoutineTaskBottomSheet(
                                            taskToEdit: task,
                                            initialDay: day,
                                            isDuplicate: true,
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      onPressed: () => _deleteTask(day, task.id),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
