import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'daily_routine.dart';

class Revision147Screen extends StatefulWidget {
  const Revision147Screen({super.key});

  @override
  State<Revision147Screen> createState() => _Revision147ScreenState();
}

class _Revision147ScreenState extends State<Revision147Screen> with SingleTickerProviderStateMixin {
  final User? _user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;
  DateTime _referenceDate = DateTime.now();

  Stream<DailyRoutine?>? _stream1Day;
  Stream<DailyRoutine?>? _stream4Days;
  Stream<DailyRoutine?>? _stream7Days;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initStreams();
  }

  void _initStreams() {
    final day1Ago = _referenceDate.subtract(const Duration(days: 1));
    final day4Ago = _referenceDate.subtract(const Duration(days: 4));
    final day7Ago = _referenceDate.subtract(const Duration(days: 7));

    _stream1Day = _getPastRoutineStream(day1Ago);
    _stream4Days = _getPastRoutineStream(day4Ago);
    _stream7Days = _getPastRoutineStream(day7Ago);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Adjust reference date
  void _changeDate(int days) {
    setState(() {
      _referenceDate = _referenceDate.add(Duration(days: days));
      _initStreams();
    });
  }

  // Open calendar date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _referenceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _referenceDate) {
      setState(() {
        _referenceDate = picked;
        _initStreams();
      });
    }
  }

  // Firestore stream for a specific past date
  Stream<DailyRoutine?> _getPastRoutineStream(DateTime date) {
    if (_user == null) return Stream.value(null);
    final dateId = DateFormat('yyyy-MM-dd').format(date);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_user.uid)
        .collection('dailyRoutines')
        .doc(dateId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return DailyRoutine.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }

  // Toggling task completion on past days in Firestore
  Future<void> _toggleTaskCompletion(DateTime date, Task task, bool? newValue) async {
    if (_user == null) return;
    final dateId = DateFormat('yyyy-MM-dd').format(date);
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_user.uid)
        .collection('dailyRoutines')
        .doc(dateId);

    try {
      final snapshot = await docRef.get();
      if (snapshot.exists && snapshot.data() != null) {
        final routine = DailyRoutine.fromMap(snapshot.data()!, snapshot.id);
        final index = routine.tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          routine.tasks[index].isCompleted = newValue ?? false;
          if (routine.tasks[index].isCompleted) {
            routine.tasks[index].completedDurationMinutes = routine.tasks[index].totalDurationMinutes;
          } else {
            routine.tasks[index].completedDurationMinutes = 0;
          }
          await docRef.update({
            'tasks': routine.tasks.map((t) => t.toMap()).toList()
          });
        }
      }
    } catch (e) {
      debugPrint('Error toggling task completion in 1-4-7: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update task: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final day1Ago = _referenceDate.subtract(const Duration(days: 1));
    final day4Ago = _referenceDate.subtract(const Duration(days: 4));
    final day7Ago = _referenceDate.subtract(const Duration(days: 7));

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('1-4-7 Spaced Revision', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Date Selector Panel
          _buildDateSelectorPanel(isDark),

          const SizedBox(height: 16),

          // 2. Revision Stats Panel
          _buildRevisionStatsRow(),

          const SizedBox(height: 20),

          // 3. TabBar for 1, 4, 7 options
          TabBar(
            controller: _tabController,
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: const [
              Tab(text: '1 Rule (1 Day)'),
              Tab(text: '4 Rules (4 Days)'),
              Tab(text: '7 Rules (7 Days)'),
            ],
          ),

          // 4. TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRevisionTab(day1Ago, _stream1Day!),
                _buildRevisionTab(day4Ago, _stream4Days!),
                _buildRevisionTab(day7Ago, _stream7Days!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelectorPanel(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)] 
              : [Colors.indigo.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.indigo.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.indigo),
            onPressed: () => _changeDate(-1),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _selectDate(context),
              child: Column(
                children: [
                  Text(
                    'Reference Date',
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.w600, 
                      color: Colors.grey.shade600
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, d MMM yyyy').format(_referenceDate),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.indigo),
            onPressed: () => _changeDate(1),
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(child: _buildMiniStatCard(_stream1Day!, '1-Day')),
          const SizedBox(width: 12),
          Expanded(child: _buildMiniStatCard(_stream4Days!, '4-Day')),
          const SizedBox(width: 12),
          Expanded(child: _buildMiniStatCard(_stream7Days!, '7-Day')),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(Stream<DailyRoutine?> stream, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<DailyRoutine?>(
      stream: stream,
      builder: (context, snapshot) {
        int completed = 0;
        int total = 0;
        double progress = 0.0;

        if (snapshot.hasData && snapshot.data != null) {
          final tasks = snapshot.data!.tasks;
          total = tasks.length;
          completed = tasks.where((t) => t.isCompleted).length;
          progress = total > 0 ? completed / total : 0.0;
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: progress == 1.0 
                  ? Colors.green.withValues(alpha: 0.4) 
                  : (progress > 0 ? Colors.amber.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.2)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.grey.shade500
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor: Colors.grey.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress == 1.0 
                            ? Colors.green 
                            : (progress > 0 ? Colors.amber : Colors.grey)
                      ),
                    ),
                    Text(
                      total > 0 ? '${(progress * 100).toInt()}%' : 'N/A',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                total > 0 ? '$completed/$total Done' : 'No Tasks',
                style: TextStyle(
                  fontSize: 11, 
                  fontWeight: FontWeight.bold, 
                  color: total > 0 ? (progress == 1.0 ? Colors.green : Colors.blueGrey) : Colors.grey
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevisionTab(DateTime date, Stream<DailyRoutine?> stream) {
    return StreamBuilder<DailyRoutine?>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
          );
        }

        final routine = snapshot.data;
        if (routine == null || routine.tasks.isEmpty) {
          return _buildEmptyState(date);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: routine.tasks.length,
          itemBuilder: (context, index) {
            final task = routine.tasks[index];
            final bool isCompleted = task.isCompleted;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              shadowColor: isCompleted ? Colors.green.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (task.category == 'Study' || task.category == null) 
                        ? Colors.indigo.withValues(alpha: 0.1) 
                        : Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    (task.category == 'Study' || task.category == null) 
                        ? Icons.school_rounded 
                        : Icons.work_rounded,
                    color: (task.category == 'Study' || task.category == null) 
                        ? Colors.indigo 
                        : Colors.orange,
                  ),
                ),
                title: Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted ? Colors.grey : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${task.completedDurationMinutes} / ${task.totalDurationMinutes} mins • Category: ${task.category ?? "Study"}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    if (task.notes != null && task.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Note: ${task.notes}',
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
                trailing: Checkbox(
                  value: isCompleted,
                  onChanged: (bool? val) => _toggleTaskCompletion(date, task, val),
                  activeColor: Colors.green,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(DateTime date) {
    final dateStr = DateFormat('EEEE, d MMM yyyy').format(date);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.menu_book_rounded, size: 64, color: Colors.indigo),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Study Tasks Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'No routines or tasks were recorded on $dateStr.',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
