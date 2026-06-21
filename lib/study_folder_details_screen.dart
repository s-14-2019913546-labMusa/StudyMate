import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'language_manager.dart';
import 'daily_routine.dart';
import 'task_details_screen.dart';

class StudyFolderDetailsScreen extends StatefulWidget {
  final String folderId;
  final String folderName;
  final String colorHex;

  const StudyFolderDetailsScreen({
    super.key,
    required this.folderId,
    required this.folderName,
    required this.colorHex,
  });

  @override
  State<StudyFolderDetailsScreen> createState() => _StudyFolderDetailsScreenState();
}

class _StudyFolderDetailsScreenState extends State<StudyFolderDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color get _folderColor {
    try {
      return Color(int.parse(widget.colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF6366F1);
    }
  }

  // --- Firestore Syllabus Operations ---

  Future<void> _updateSubjectsInFirestore(List<dynamic> updatedSubjects) async {
    if (_currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .collection('studyFolders')
          .doc(widget.folderId)
          .update({'subjects': updatedSubjects});
    } catch (e) {
      debugPrint('Error updating subjects in Firestore: $e');
    }
  }

  Future<void> _addSubject(List<dynamic> currentSubjects) async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Subject'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter subject name'.tr(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text('Add Subject'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final name = controller.text.trim();
      // Check for duplicates
      if (currentSubjects.any((s) => s['name'] == name)) {
        return;
      }
      final updated = List.from(currentSubjects);
      updated.add({
        'name': name,
        'targetNote': '',
        'topics': [],
      });
      await _updateSubjectsInFirestore(updated);
    }
  }

  Future<void> _editTargetNote(List<dynamic> currentSubjects, String subjectName, String currentNote) async {
    final controller = TextEditingController(text: currentNote);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Target'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter subject target or timeline...'.tr(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel'.tr())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Save'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final updated = currentSubjects.map((s) {
        if (s['name'] == subjectName) {
          return {
            'name': s['name'],
            'targetNote': controller.text.trim(),
            'topics': s['topics'],
          };
        }
        return s;
      }).toList();
      await _updateSubjectsInFirestore(updated);
    }
  }

  Future<void> _deleteSubject(List<dynamic> currentSubjects, String subjectName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this subject?'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel'.tr())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text('Delete'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final updated = List.from(currentSubjects);
      updated.removeWhere((s) => s['name'] == subjectName);
      await _updateSubjectsInFirestore(updated);
    }
  }

  Future<void> _addTopic(List<dynamic> currentSubjects, String subjectName) async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Topic'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter topic name'.tr(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text('Add Topic'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final name = controller.text.trim();
      final updated = currentSubjects.map((s) {
        if (s['name'] == subjectName) {
          final topicsList = List.from(s['topics'] ?? []);
          if (!topicsList.any((t) => t['name'] == name)) {
            topicsList.add({
              'name': name,
              'isCompleted': false,
            });
          }
          return {
            'name': s['name'],
            'topics': topicsList,
          };
        }
        return s;
      }).toList();

      await _updateSubjectsInFirestore(updated);
    }
  }

  Future<void> _toggleTopicCompletion(List<dynamic> currentSubjects, String subjectName, String topicName) async {
    final updated = currentSubjects.map((s) {
      if (s['name'] == subjectName) {
        final topicsList = (s['topics'] as List).map((t) {
          if (t['name'] == topicName) {
            return {
              'name': t['name'],
              'isCompleted': !(t['isCompleted'] ?? false),
            };
          }
          return t;
        }).toList();
        return {
          'name': s['name'],
          'topics': topicsList,
        };
      }
      return s;
    }).toList();

    await _updateSubjectsInFirestore(updated);
  }

  Future<void> _deleteTopic(List<dynamic> currentSubjects, String subjectName, String topicName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this topic?'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel'.tr())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text('Delete'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final updated = currentSubjects.map((s) {
        if (s['name'] == subjectName) {
          final topicsList = List.from(s['topics'] ?? []);
          topicsList.removeWhere((t) => t['name'] == topicName);
          return {
            'name': s['name'],
            'topics': topicsList,
          };
        }
        return s;
      }).toList();

      await _updateSubjectsInFirestore(updated);
    }
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.folderName, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _folderColor,
          labelColor: _folderColor,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: [
            Tab(text: 'Syllabus'.tr()),
            Tab(text: 'Tasks in Folder'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSyllabusTab(),
          _buildTasksTab(),
        ],
      ),
    );
  }

  // --- 1. Syllabus Tab ---

  Widget _buildSyllabusTab() {
    if (_currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .collection('studyFolders')
          .doc(widget.folderId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data() == null) {
          return const Center(child: Text('Folder not found'));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final subjects = data['subjects'] as List<dynamic>? ?? [];

        // Progress Calculation
        int totalTopics = 0;
        int completedTopics = 0;
        for (var sub in subjects) {
          final tList = sub['topics'] as List<dynamic>? ?? [];
          totalTopics += tList.length;
          completedTopics += tList.where((t) => t['isCompleted'] == true).length;
        }

        final double progress = totalTopics > 0 ? completedTopics / totalTopics : 0.0;

        return Column(
          children: [
            // Progress Header
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _folderColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _folderColor.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '$completedTopics/$totalTopics',
                        style: TextStyle(fontWeight: FontWeight.bold, color: _folderColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: _folderColor.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(_folderColor),
                    ),
                  ),
                ],
              ),
            ),

            // Subject Header add button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subjects'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  TextButton.icon(
                    onPressed: () => _addSubject(subjects),
                    icon: Icon(Icons.add, size: 18, color: _folderColor),
                    label: Text('Add Subject'.tr(), style: TextStyle(color: _folderColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // Syllabus content lists
            Expanded(
              child: subjects.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'No subjects added yet'.tr(),
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: subjects.length,
                      itemBuilder: (context, subIndex) {
                        final subject = subjects[subIndex] as Map<String, dynamic>;
                        final subName = subject['name'] ?? '';
                        final topics = subject['topics'] as List<dynamic>? ?? [];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 1,
                          child: ExpansionTile(
                            leading: Icon(Icons.subject_rounded, color: _folderColor),
                            title: Text(
                              subName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Text('${topics.length} ${'Topic'.tr()}'),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded),
                              onSelected: (val) {
                                if (val == 'add_topic') {
                                  _addTopic(subjects, subName);
                                } else if (val == 'delete_sub') {
                                  _deleteSubject(subjects, subName);
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'add_topic',
                                  child: Row(
                                    children: [
                                      Icon(Icons.add, size: 18, color: Theme.of(context).iconTheme.color),
                                      const SizedBox(width: 8),
                                      Text('Add Topic'.tr()),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete_sub',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Text('Delete'.tr(), style: const TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _folderColor.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _folderColor.withValues(alpha: 0.15)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Subject Target'.tr(),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.edit_rounded, size: 16, color: _folderColor),
                                            onPressed: () {
                                              final targetNote = subject['targetNote'] as String? ?? '';
                                              _editTargetNote(subjects, subName, targetNote);
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        (subject['targetNote'] as String? ?? '').isEmpty
                                            ? 'Set a study target for this subject...'.tr()
                                            : subject['targetNote'] as String,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: (subject['targetNote'] as String? ?? '').isEmpty ? Colors.grey : null,
                                          fontStyle: (subject['targetNote'] as String? ?? '').isEmpty ? FontStyle.italic : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (topics.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text('No notes recorded.'.tr(), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                ),
                              ...topics.map((t) {
                                final topicMap = t as Map<String, dynamic>;
                                final topicName = topicMap['name'] ?? '';
                                final isComp = topicMap['isCompleted'] ?? false;

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                                  leading: Checkbox(
                                    value: isComp,
                                    activeColor: _folderColor,
                                    onChanged: (val) => _toggleTopicCompletion(subjects, subName, topicName),
                                  ),
                                  title: Text(
                                    topicName,
                                    style: TextStyle(
                                      decoration: isComp ? TextDecoration.lineThrough : null,
                                      color: isComp ? Colors.grey : null,
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                                    onPressed: () => _deleteTopic(subjects, subName, topicName),
                                  ),
                                );
                              }),
                            ],
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

  // --- 2. Tasks Tab ---

  Widget _buildTasksTab() {
    if (_currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .collection('dailyRoutines')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyTasksState();
        }

        // Aggregate matching tasks
        List<Map<String, dynamic>> folderTasks = [];
        int totalMinutesSpent = 0;
        int successfulCount = 0;
        int totalCount = 0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final routineDate = (data['date'] as Timestamp).toDate();
          final dateDocId = doc.id;

          if (data['tasks'] != null) {
            for (var taskMap in data['tasks']) {
              final task = Task.fromMap(taskMap, taskMap['id'] ?? '');
              // Filter by matching category name
              if (task.category == widget.folderName) {
                folderTasks.add({
                  'dateDocId': dateDocId,
                  'date': routineDate,
                  'task': task,
                });

                totalMinutesSpent += task.completedDurationMinutes;
                totalCount++;
                if (task.isCompleted || task.status == 'completed') {
                  successfulCount++;
                }
              }
            }
          }
        }

        if (folderTasks.isEmpty) {
          return _buildEmptyTasksState();
        }

        // Sort reverse chronological
        folderTasks.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

        final double successRate = totalCount > 0 ? (successfulCount / totalCount) * 100 : 0.0;

        return Column(
          children: [
            // Analytics Summary Row
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Study Time'.tr(),
                      '${(totalMinutesSpent / 60).toStringAsFixed(1)} hr',
                      Icons.menu_book_rounded,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Success Rate'.tr(),
                      '${successRate.toStringAsFixed(0)}%',
                      Icons.trending_up_rounded,
                    ),
                  ),
                ],
              ),
            ),

            // Chronological List View
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: folderTasks.length,
                itemBuilder: (context, index) {
                  final item = folderTasks[index];
                  final date = item['date'] as DateTime;
                  final task = item['task'] as Task;
                  final isCompleted = task.isCompleted || task.status == 'completed';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TaskDetailsScreen(task: task),
                          ),
                        );
                      },
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isCompleted ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCompleted ? Icons.check_circle_rounded : Icons.pending_rounded,
                          color: isCompleted ? Colors.green : Colors.orange,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        task.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${DateFormat('EEEE, d MMMM').format(date)}\n${task.completedDurationMinutes} min / ${task.totalDurationMinutes} min',
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                      isThreeLine: true,
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

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      elevation: 0,
      color: _folderColor.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _folderColor.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: _folderColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTasksState() {
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
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
