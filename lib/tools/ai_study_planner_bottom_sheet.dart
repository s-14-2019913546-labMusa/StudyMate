import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:open_filex/open_filex.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

import '../daily_routine.dart';
import '../dashboard_screen.dart';
import '../calendar_screen.dart';
import '../focus_music_screen.dart';
import '../flashcards_screen.dart';
import '../dictionary_screen.dart';
import '../ai_service.dart';
import '../revision_147_screen.dart';
import '../islamic_life_screen.dart';
import '../theme_manager.dart';
import '../local_notification_service.dart';
import '../study_analytics_screen.dart';
import '../weekly_overview_screen.dart';
import '../task_history_screen.dart';
import '../gamification_service.dart';
import '../language_manager.dart';
import '../study_folder_manager_screen.dart';
import '../special_day_countdown_screen.dart';
import '../daily_diary_screen.dart';
import '../bookmarks_screen.dart';
import '../news_reader_screen.dart';
import '../social_hub_screen.dart';
import '../google_sheet_sync_screen.dart';
import '../multi_sheet_manager_screen.dart';
import '../notifications_hub_screen.dart';
import '../widgets/sound_picker_widget.dart';
import '../tools_screen.dart';

// ==========================================
// AI Study Planner Bottom Sheet
// ==========================================
class SubjectItem {
  TextEditingController nameCtrl = TextEditingController();
  TextEditingController topicCtrl = TextEditingController();
}

class AIStudyPlannerBottomSheet extends StatefulWidget {
  final Function(List<Task>) onTasksGenerated;
  const AIStudyPlannerBottomSheet({super.key, required this.onTasksGenerated});

  @override
  State<AIStudyPlannerBottomSheet> createState() => _AIStudyPlannerBottomSheetState();
}

class _AIStudyPlannerBottomSheetState extends State<AIStudyPlannerBottomSheet> {
  int _step = 1; // 1: Input, 2: Loading, 3: Result
  final List<SubjectItem> _subjects = [SubjectItem()];
  double _studyHours = 2.0;
  String? _geminiApiKey;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  List<Task> _generatedTasks = [];
  bool _isOfflineGeneration = true;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  @override
  void dispose() {
    for (var subject in _subjects) {
      subject.nameCtrl.dispose();
      subject.topicCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    if (_currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _geminiApiKey = doc.data()?['geminiApiKey'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading API key in study planner: $e');
    }
  }

  void _addSubject() {
    setState(() {
      _subjects.add(SubjectItem());
    });
  }

  void _removeSubject(int index) {
    setState(() {
      final sub = _subjects.removeAt(index);
      sub.nameCtrl.dispose();
      sub.topicCtrl.dispose();
    });
  }

  void _generateRoutine() async {
    if (_subjects.any((s) => s.nameCtrl.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter subject names for all fields.')));
      return;
    }

    setState(() {
      _step = 2;
    });

    final String goals = _subjects.map((sub) {
      final name = sub.nameCtrl.text.trim();
      final topic = sub.topicCtrl.text.trim();
      return topic.isEmpty ? name : '$name (Topic: $topic)';
    }).join(', ');

    final promptContext = 'Subjects/topics: $goals. Total study hours: $_studyHours hours.';

    final List<Map<String, String>> subjectsList = _subjects.map((sub) => {
      'subject': sub.nameCtrl.text.trim(),
      'topic': sub.topicCtrl.text.trim(),
    }).toList();

    List<Map<String, dynamic>> rawTasks = [];
    bool isOffline = true;
    try {
      if (_geminiApiKey != null && _geminiApiKey!.isNotEmpty) {
        rawTasks = await AIService.generateStudyPlan(
          promptContext,
          _geminiApiKey,
          subjects: subjectsList,
          studyHours: _studyHours,
        );
        if (rawTasks.isNotEmpty) {
          isOffline = false;
        }
      }
    } catch (e) {
      debugPrint('Error generating study plan with Gemini: $e');
    }

    if (rawTasks.isEmpty) {
      isOffline = true;
      rawTasks = await AIService.generateStudyPlan(
        promptContext,
        null,
        subjects: subjectsList,
        studyHours: _studyHours,
      );
    }

    int totalMinutes = (_studyHours * 60).toInt();
    DateTime currentTime = DateTime.now();
    List<Task> tempTasks = [];

    if (rawTasks.isNotEmpty) {
      final bool hasBreaksInRaw = rawTasks.any((t) => t['category'] == 'Other');
      for (int i = 0; i < rawTasks.length; i++) {
        var rawTask = rawTasks[i];
        final String title = rawTask['title'] ?? 'Study Session';
        final String category = rawTask['category'] ?? 'Study';
        final int duration = rawTask['durationMinutes'] ?? (totalMinutes ~/ rawTasks.length);
        
        DateTime taskEndTime = currentTime.add(Duration(minutes: duration));
        
        tempTasks.add(Task(
          id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
          title: title,
          subject: rawTask['subject'] ?? _subjects[0].nameCtrl.text.trim(),
          notes: rawTask['notes'] ?? 'AI generated study plan task',
          startTime: currentTime,
          endTime: taskEndTime,
          totalDurationMinutes: duration,
          category: category,
        ));
        
        if (i < rawTasks.length - 1) {
          currentTime = hasBreaksInRaw ? taskEndTime : taskEndTime.add(const Duration(minutes: 10)); 
        }
      }
    }

    setState(() {
      _isOfflineGeneration = isOffline;
      _generatedTasks = tempTasks;
      _step = 3;
    });
  }

  void _recalculateTimeline() {
    if (_generatedTasks.isEmpty) return;
    DateTime currentTime = DateTime.now();
    final bool hasBreaksInRaw = _generatedTasks.any((t) => t.category == 'Other');
    for (int i = 0; i < _generatedTasks.length; i++) {
      var task = _generatedTasks[i];
      DateTime taskEndTime = currentTime.add(Duration(minutes: task.totalDurationMinutes));
      _generatedTasks[i] = task.copyWith(
        startTime: currentTime,
        endTime: taskEndTime,
      );
      if (i < _generatedTasks.length - 1) {
        currentTime = hasBreaksInRaw ? taskEndTime : taskEndTime.add(const Duration(minutes: 10));
      }
    }
  }

  void _editTaskDuration(int index) {
    TextEditingController durationCtrl = TextEditingController(text: _generatedTasks[index].totalDurationMinutes.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Duration (mins)', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: durationCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutes'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              int newDuration = int.tryParse(durationCtrl.text) ?? _generatedTasks[index].totalDurationMinutes;
              setState(() {
                _generatedTasks[index] = _generatedTasks[index].copyWith(totalDurationMinutes: newDuration);
                _recalculateTimeline();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _saveAsSeparateTasks() {
    if (_generatedTasks.isNotEmpty) {
      DateTime currentTime = DateTime.now();
      final bool hasBreaksInRaw = _generatedTasks.any((t) => t.category == 'Other');
      for (int i = 0; i < _generatedTasks.length; i++) {
        var task = _generatedTasks[i];
        DateTime taskEndTime = currentTime.add(Duration(minutes: task.totalDurationMinutes));
        _generatedTasks[i] = task.copyWith(
          startTime: currentTime,
          endTime: taskEndTime,
        );
        if (i < _generatedTasks.length - 1) {
          currentTime = hasBreaksInRaw ? taskEndTime : taskEndTime.add(const Duration(minutes: 10));
        }
      }
    }
    widget.onTasksGenerated(_generatedTasks);
    Navigator.pop(context);
  }

  void _saveAsCombinedTask() {
    int totalMinutes = _generatedTasks.fold<int>(0, (int sum, Task task) => sum + task.totalDurationMinutes);
    int totalBreaks = (_generatedTasks.length > 1) ? (_generatedTasks.length - 1) * 10 : 0;
    String combinedNotes = "AI Combined Session Breakdown:\n";
    for (var t in _generatedTasks) {
      combinedNotes += "- ${t.title} (${t.totalDurationMinutes}m)\n";
    }
    
    Task combinedTask = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: "Combined AI Study Session",
      subject: "Mixed Subjects",
      notes: combinedNotes.trim(),
      startTime: DateTime.now(),
      endTime: DateTime.now().add(Duration(minutes: totalMinutes + totalBreaks)),
      totalDurationMinutes: totalMinutes,
      category: 'AI Planned',
    );

    widget.onTasksGenerated([combinedTask]);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: bottomInset + 24),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: _step == 1 
          ? _buildInputStep() 
          : _step == 2 
              ? _buildLoadingStep() 
              : _buildResultStep(),
    );
  }

  Widget _buildInputStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('AI Study Planner', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          Text('How much time do you have today?', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _studyHours,
                  min: 0.5,
                  max: 10.0,
                  divisions: 19,
                  label: '${_studyHours.toStringAsFixed(1)} Hrs',
                  onChanged: (val) => setState(() => _studyHours = val),
                ),
              ),
              Text('${_studyHours.toStringAsFixed(1)} Hrs', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          Text('Subjects & Topics', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...List.generate(_subjects.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _subjects[index].nameCtrl,
                      decoration: InputDecoration(labelText: 'Subject ${index + 1}', hintText: 'e.g., Math', contentPadding: const EdgeInsets.symmetric(horizontal: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _subjects[index].topicCtrl,
                      decoration: const InputDecoration(labelText: 'Topic', hintText: 'e.g., Algebra', contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                    ),
                  ),
                  if (_subjects.length > 1)
                    IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => _removeSubject(index)),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: _addSubject,
            icon: const Icon(Icons.add),
            label: const Text('Add Another Subject'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _generateRoutine,
            child: const Text('Generate Smart Routine'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text('🪄 AI is analyzing your subjects...', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Structuring topics, adding smart breaks...', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildResultStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('🎯 Your Smart Routine is Ready!', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.green.shade600)),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isOfflineGeneration 
                  ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isOfflineGeneration ? Icons.offline_bolt_rounded : Icons.bolt_rounded,
                  size: 16,
                  color: _isOfflineGeneration 
                      ? Theme.of(context).colorScheme.secondary 
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  _isOfflineGeneration ? 'Offline Smart Mode (অফলাইন স্মার্ট মোড)' : 'Online AI Mode (অনলাইন এআই মোড)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isOfflineGeneration 
                        ? Theme.of(context).colorScheme.secondary 
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _generatedTasks.length,
            itemBuilder: (context, index) {
              final task = _generatedTasks[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), child: Icon(Icons.book, color: Theme.of(context).colorScheme.primary)),
                title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(task.notes ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${task.totalDurationMinutes} min', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      color: Colors.grey,
                      onPressed: () => _editTaskDuration(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        const Text('Note: 10 mins break added between subjects.', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _saveAsSeparateTasks,
          icon: const Icon(Icons.format_list_bulleted_rounded),
          label: const Text('Add as Separate Tasks'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _saveAsCombinedTask,
          icon: const Icon(Icons.layers_rounded),
          label: const Text('Add as 1 Combined Session'),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        ),
      ],
    );
  }
}

