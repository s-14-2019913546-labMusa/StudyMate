import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'daily_routine.dart';
import 'language_manager.dart';
import 'task_details_screen.dart';

class TaskHistoryScreen extends StatefulWidget {
  final String? userId;
  final String? userName;
  final bool isFriendView;

  const TaskHistoryScreen({
    super.key,
    this.userId,
    this.userName,
    this.isFriendView = false,
  });

  @override
  State<TaskHistoryScreen> createState() => _TaskHistoryScreenState();
}

class _TaskHistoryScreenState extends State<TaskHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  // Date State variables
  DateTime _selectedDay = DateTime.now();
  DateTime _selectedWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  DateTime _selectedMonth = DateTime.now();
  
  // Filter variables
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Study', 'Work', 'Sports', 'Other'];
  final List<Map<String, dynamic>> _folders = [];

  // Cache/Routines list loaded for week/month
  List<DailyRoutine> _loadedRoutines = [];
  bool _isLoading = false;

  String get _effectiveUserId => widget.userId ?? _currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadDataForActiveTab();
      }
    });
    _loadDataForActiveTab();
    _loadCustomFolders();
  }

  Future<void> _loadCustomFolders() async {
    if (_effectiveUserId.isEmpty) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_effectiveUserId)
          .collection('studyFolders')
          .get();
      final list = snapshot.docs.map((doc) => doc.data()).toList();
      if (mounted) {
        setState(() {
          _folders.addAll(list);
          for (var f in list) {
            final name = f['name'] as String;
            if (!_categories.contains(name)) {
              _categories.add(name);
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading folders in TaskHistoryScreen: $e");
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadDataForActiveTab() {
    if (_tabController.index == 0) {
      // Day view loads via StreamBuilder or simple fetch
      setState(() {});
    } else if (_tabController.index == 1) {
      _loadWeekData();
    } else {
      _loadMonthData();
    }
  }

  // --- Data Loading Logic ---

  Future<void> _loadWeekData() async {
    if (_effectiveUserId.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final start = DateTime(_selectedWeekStart.year, _selectedWeekStart.month, _selectedWeekStart.day);
      final end = start.add(const Duration(days: 7));
      
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_effectiveUserId)
          .collection('dailyRoutines')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .get();

      final routines = snapshot.docs.map((doc) => DailyRoutine.fromMap(doc.data(), doc.id)).toList();
      setState(() {
        _loadedRoutines = routines;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading week tasks: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMonthData() async {
    if (_effectiveUserId.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      // Get first day of next month
      final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_effectiveUserId)
          .collection('dailyRoutines')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .get();

      final routines = snapshot.docs.map((doc) => DailyRoutine.fromMap(doc.data(), doc.id)).toList();
      setState(() {
        _loadedRoutines = routines;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading month tasks: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- Deletion Logic ---

  Future<void> _deleteTaskFromFirestore(String dateDocId, Task task) async {
    if (widget.isFriendView || _effectiveUserId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Task'.tr()),
        content: Text('Are you sure you want to delete this task from history?'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text('Delete'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_effectiveUserId)
        .collection('dailyRoutines')
        .doc(dateDocId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data() as Map<String, dynamic>;
          final routine = DailyRoutine.fromMap(data, snapshot.id);
          
          routine.tasks.removeWhere((t) => t.id == task.id);
          
          if (routine.tasks.isEmpty) {
            transaction.delete(docRef);
          } else {
            transaction.update(docRef, {
              'tasks': routine.tasks.map((t) => t.toMap()).toList()
            });
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task Deleted Successfully!'.tr())),
        );
      }
      
      _loadDataForActiveTab();
    } catch (e) {
      debugPrint("Error deleting task: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete task!'.tr())),
        );
      }
    }
  }

  // --- Navigation & Pickers ---

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDay = picked;
      });
      _loadDataForActiveTab();
    }
  }

  Future<void> _pickWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedWeekStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        // Find Monday of the picked week
        _selectedWeekStart = picked.subtract(Duration(days: picked.weekday - 1));
      });
      _loadWeekData();
    }
  }

  Future<void> _pickMonth() async {
    // Standard Flutter DatePicker capped at month granularity
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      _loadMonthData();
    }
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.isFriendView ? '${widget.userName ?? 'Friend'}\'s Tasks' : 'Task History'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: [
            Tab(text: 'Day'.tr()),
            Tab(text: 'Week'.tr()),
            Tab(text: 'Month'.tr()),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Bar
          _buildFilterBar(),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDayView(),
                _buildWeekView(),
                _buildMonthView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Text(
            'Filter by Category:'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor, width: 0.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  icon: const Icon(Icons.filter_list_rounded, size: 20),
                  isExpanded: true,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    }
                  },
                  items: _categories.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value.tr()),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Day View Screen ---
  Widget _buildDayView() {
    if (_effectiveUserId.isEmpty) return const SizedBox.shrink();

    final dateDocId = DateFormat('yyyy-MM-dd').format(_selectedDay);

    return Column(
      children: [
        _buildDateNavigator(
          label: LanguageManager.formatDate(_selectedDay),
          onPrev: () {
            setState(() => _selectedDay = _selectedDay.subtract(const Duration(days: 1)));
          },
          onNext: () {
            setState(() => _selectedDay = _selectedDay.add(const Duration(days: 1)));
          },
          onPick: _pickDay,
        ),
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_effectiveUserId)
                .collection('dailyRoutines')
                .doc(dateDocId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Error loading history: ${snapshot.error}'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data() == null) {
                return _buildEmptyState();
              }

              final routine = DailyRoutine.fromMap(snapshot.data!.data() as Map<String, dynamic>, snapshot.data!.id);
              final filteredTasks = _filterTasks(routine.tasks);

              if (filteredTasks.isEmpty) {
                return _buildEmptyState();
              }

              return _buildTaskList(dateDocId, filteredTasks);
            },
          ),
        ),
      ],
    );
  }

  // --- Week View Screen ---
  Widget _buildWeekView() {
    final startStr = DateFormat('d MMM').format(_selectedWeekStart);
    final endStr = DateFormat('d MMM, yyyy').format(_selectedWeekStart.add(const Duration(days: 6)));

    return Column(
      children: [
        _buildDateNavigator(
          label: '$startStr - $endStr',
          onPrev: () {
            setState(() => _selectedWeekStart = _selectedWeekStart.subtract(const Duration(days: 7)));
            _loadWeekData();
          },
          onNext: () {
            setState(() => _selectedWeekStart = _selectedWeekStart.add(const Duration(days: 7)));
            _loadWeekData();
          },
          onPick: _pickWeek,
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildGroupedRoutinesList(),
        ),
      ],
    );
  }

  // --- Month View Screen ---
  Widget _buildMonthView() {
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Column(
      children: [
        _buildDateNavigator(
          label: monthLabel,
          onPrev: () {
            setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));
            _loadMonthData();
          },
          onNext: () {
            setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1));
            _loadMonthData();
          },
          onPick: _pickMonth,
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildGroupedRoutinesList(),
        ),
      ],
    );
  }

  Widget _buildDateNavigator({
    required String label,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    required VoidCallback onPick,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: onPrev,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onPick,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary, size: 18),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedRoutinesList() {
    // Aggregate tasks from all loaded routines
    List<Map<String, dynamic>> allTasksWithDate = [];
    for (var routine in _loadedRoutines) {
      final dateDocId = routine.id;
      final filtered = _filterTasks(routine.tasks);
      for (var task in filtered) {
        allTasksWithDate.add({
          'dateDocId': dateDocId,
          'date': routine.date,
          'task': task,
        });
      }
    }

    if (allTasksWithDate.isEmpty) {
      return _buildEmptyState();
    }

    // Sort tasks in reverse chronological order
    allTasksWithDate.sort((a, b) {
      int dateComp = (b['date'] as DateTime).compareTo(a['date'] as DateTime);
      if (dateComp != 0) return dateComp;
      return (b['task'] as Task).id.compareTo((a['task'] as Task).id);
    });

    // Group tasks by date string for section headers
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in allTasksWithDate) {
      final dateLabel = LanguageManager.formatDate(item['date'] as DateTime);
      if (!grouped.containsKey(dateLabel)) {
        grouped[dateLabel] = [];
      }
      grouped[dateLabel]!.add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: grouped.keys.length,
      itemBuilder: (context, index) {
        final dateLabel = grouped.keys.elementAt(index);
        final list = grouped[dateLabel]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: Text(
                dateLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            ...list.map((item) {
              final dateDocId = item['dateDocId'] as String;
              final task = item['task'] as Task;
              return _buildTaskTile(dateDocId, task);
            }),
            const Divider(height: 16, thickness: 0.5),
          ],
        );
      },
    );
  }

  List<Task> _filterTasks(List<Task> tasks) {
    if (_selectedCategory == 'All') return tasks;
    return tasks.where((t) => t.category == _selectedCategory).toList();
  }

  bool _isTaskSuccessful(Task task) {
    final isCompleted = task.isCompleted || task.status == 'completed';
    if (!isCompleted) return false;

    final fromElapsed = task.totalDurationMinutes > 0
        ? (task.elapsedSeconds / (task.totalDurationMinutes * 60))
        : 0.0;
    final fromMinutes = task.totalDurationMinutes > 0
        ? (task.completedDurationMinutes / task.totalDurationMinutes)
        : 0.0;
    final actualProgress = fromElapsed > fromMinutes ? fromElapsed : fromMinutes;

    return actualProgress >= 0.70;
  }

  Widget _buildTaskList(String dateDocId, List<Task> tasks) {
    // Separate into Completed and Missed/Pending based on >= 70% progress validation
    final successful = tasks.where((t) => _isTaskSuccessful(t)).toList();
    final missed = tasks.where((t) => !_isTaskSuccessful(t)).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (missed.isNotEmpty) ...[
          _buildSectionHeader('Missed/Pending Tasks'.tr(), Colors.redAccent),
          ...missed.map((task) => _buildTaskTile(dateDocId, task)),
          const SizedBox(height: 16),
        ],
        if (successful.isNotEmpty) ...[
          _buildSectionHeader('Successful Tasks'.tr(), Colors.green),
          ...successful.map((task) => _buildTaskTile(dateDocId, task)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      child: Row(
        children: [
          Container(width: 4, height: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(String dateDocId, Task task) {
    final theme = Theme.of(context);
    final isSuccess = _isTaskSuccessful(task);
    
    final fromElapsed = task.totalDurationMinutes > 0 ? (task.elapsedSeconds / (task.totalDurationMinutes * 60)) : 0.0;
    final fromMinutes = task.totalDurationMinutes > 0 ? (task.completedDurationMinutes / task.totalDurationMinutes) : 0.0;
    final progressVal = (fromElapsed > fromMinutes ? fromElapsed : fromMinutes).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _navigateToTaskDetails(dateDocId, task),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isSuccess ? Colors.green : Colors.orange).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.pending_rounded,
            color: isSuccess ? Colors.green : Colors.orange,
            size: 24,
          ),
        ),
        title: Text(
          task.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                if (task.category != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(task.category!).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getCategoryColor(task.category!).withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      task.category!.tr(),
                      style: TextStyle(
                        color: _getCategoryColor(task.category!),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '${task.completedDurationMinutes} min / ${task.totalDurationMinutes} min',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressVal,
                minHeight: 5,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(isSuccess ? Colors.green : theme.colorScheme.primary),
              ),
            ),
          ],
        ),
        trailing: widget.isFriendView 
            ? null 
            : IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error, size: 22),
                onPressed: () => _deleteTaskFromFirestore(dateDocId, task),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No tasks found for this period'.tr(),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- Navigate to Details Screen ---
  void _navigateToTaskDetails(String dateDocId, Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailsScreen(
          task: task,
          isFriendView: widget.isFriendView,
          onUpdate: (updatedTask) => _updateTaskInFirestore(dateDocId, updatedTask),
        ),
      ),
    );
  }

  Future<void> _updateTaskInFirestore(String dateDocId, Task updatedTask) async {
    if (_effectiveUserId.isEmpty) return;
    try {
      final String newDocId = updatedTask.startTime != null
          ? DateFormat('yyyy-MM-dd').format(updatedTask.startTime!)
          : dateDocId;

      final oldDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_effectiveUserId)
          .collection('dailyRoutines')
          .doc(dateDocId);

      final String cleanOldId = updatedTask.id.replaceFirst('resumed_', '');

      if (dateDocId == newDocId) {
        // Same day update
        final snapshot = await oldDocRef.get();
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data != null && data['tasks'] != null) {
            List<dynamic> tasksList = data['tasks'];
            int index = tasksList.indexWhere((t) => t['id'] == updatedTask.id || t['id'] == cleanOldId);
            if (index != -1) {
              tasksList[index] = updatedTask.toMap();
              await oldDocRef.update({'tasks': tasksList});
            }
          }
        }
      } else {
        // Moved to another day (Rescheduled/Resumed)
        // 1. Remove from old day
        final snapshot = await oldDocRef.get();
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data != null && data['tasks'] != null) {
            List<dynamic> tasksList = data['tasks'];
            tasksList.removeWhere((t) => t['id'] == updatedTask.id || t['id'] == cleanOldId);
            await oldDocRef.update({'tasks': tasksList});
          }
        }

        // 2. Add to new day
        final newDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(_effectiveUserId)
            .collection('dailyRoutines')
            .doc(newDocId);

        final newSnapshot = await newDocRef.get();
        if (newSnapshot.exists) {
          final data = newSnapshot.data();
          if (data != null) {
            List<dynamic> tasksList = data['tasks'] ?? [];
            tasksList.removeWhere((t) => t['id'] == updatedTask.id || t['id'] == cleanOldId);
            tasksList.add(updatedTask.toMap());
            await newDocRef.update({'tasks': tasksList});
          }
        } else {
          final newRoutine = DailyRoutine(
            id: newDocId,
            userId: _effectiveUserId,
            date: DateFormat('yyyy-MM-dd').parse(newDocId),
            tasks: [updatedTask],
          );
          await newDocRef.set(newRoutine.toMap());
        }
      }

      // Update local cache state
      if (mounted) {
        setState(() {
          _loadMonthData();
          _loadWeekData();
        });
      }
    } catch (e) {
      debugPrint("Error updating task in Firestore: $e");
    }
  }
}
