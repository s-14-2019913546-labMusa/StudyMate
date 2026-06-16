import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBarContent(context), // Use a regular AppBar for sticky header content
      body: SingleChildScrollView(
        // Changed from CustomScrollView to SingleChildScrollView
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 80), // Adjust padding as AppBar now handles top
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
            // You can add a list of other tasks here
            // For now, a placeholder
            Container(
              height: 100,
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
              alignment: Alignment.center,
              child: Text(
                'No active tasks for now.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // New Task বাটন লজিক এখানে হবে
          // print('New Task button pressed');
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
      toolbarHeight: 100.0, // Adjust height to fit content
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: User name and welcome
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            // Center: App Name with Glow
            Text(
              'StudyMate',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    shadows: [
                      Shadow(
                        blurRadius: 15.0,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
            ),
            // Right: Message Icon
            _buildMessageIcon(context),
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