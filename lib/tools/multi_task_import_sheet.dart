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
class MultiTaskImportSheet extends StatefulWidget {
  final String roomCode;
  final Map<String, dynamic> participantNames;

  const MultiTaskImportSheet({
    super.key,
    required this.roomCode,
    required this.participantNames,
  });

  @override
  State<MultiTaskImportSheet> createState() => _MultiTaskImportSheetState();
}

class _MultiTaskImportSheetState extends State<MultiTaskImportSheet> {
  String _selectedUserId = '';
  List<Task> _tasks = [];
  bool _isLoading = false;
  final Set<Task> _selectedTasks = {};

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _selectedUserId = user.uid;
      _fetchTasksFor(_selectedUserId);
    } else if (widget.participantNames.isNotEmpty) {
      _selectedUserId = widget.participantNames.keys.first;
      _fetchTasksFor(_selectedUserId);
    }
  }

  Future<void> _fetchTasksFor(String userId) async {
    setState(() {
      _isLoading = true;
      _tasks = [];
    });

    final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dayOfWeek = DateFormat('EEEE').format(DateTime.now());

    List<Task> dailyTasks = [];
    try {
      final dailyDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('dailyRoutines')
          .doc(todayDate)
          .get();

      if (dailyDoc.exists) {
        final data = dailyDoc.data() as Map<String, dynamic>;
        if (data['tasks'] != null) {
          for (var taskMap in data['tasks']) {
            dailyTasks.add(Task.fromMap(taskMap, taskMap['id'] ?? UniqueKey().toString()));
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching daily routine tasks: $e");
    }

    List<Task> weeklyTasks = [];
    try {
      final weeklySnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('weeklyRoutines')
          .doc(dayOfWeek)
          .collection('tasks')
          .get();

      for (var doc in weeklySnap.docs) {
        weeklyTasks.add(Task.fromMap(doc.data(), doc.id));
      }
    } catch (e) {
      debugPrint("Error fetching weekly tasks: $e");
    }

    if (mounted) {
      setState(() {
        _tasks = [...dailyTasks, ...weeklyTasks];
        _isLoading = false;
      });
    }
  }

  void _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _selectedTasks.isEmpty) return;
    
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Review & Add'.tr()),
        content: Text('Are you sure you want to add ${_selectedTasks.length} tasks to this partner space?'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel'.tr())),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Yes, Add'.tr())),
        ],
      )
    );
    
    if (confirm != true) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final t in _selectedTasks) {
      final docRef = FirebaseFirestore.instance
          .collection('partner_rooms')
          .doc(widget.roomCode)
          .collection('tasks')
          .doc();
          
      batch.set(docRef, {
        'title': t.title,
        'totalDurationMinutes': t.totalDurationMinutes,
        'isCompleted': false,
        'createdBy': user.uid,
        'createdByName': user.displayName ?? 'Anonymous',
        'timestamp': FieldValue.serverTimestamp(),
        'subject': t.subject,
        'notes': t.notes,
        'topic': t.topic,
        'challenges': t.challenges,
        'category': t.category,
        'startTime': t.startTime != null ? Timestamp.fromDate(t.startTime!) : null,
        'endTime': t.endTime != null ? Timestamp.fromDate(t.endTime!) : null,
      });
    }
    
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully added ${_selectedTasks.length} tasks!'.tr())));
      Navigator.pop(context); // close sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Import Tasks'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (widget.participantNames.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: widget.participantNames.containsKey(_selectedUserId) ? _selectedUserId : null,
              decoration: InputDecoration(
                labelText: 'Select Partner'.tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: widget.participantNames.entries.map((e) {
                return DropdownMenuItem<String>(
                  value: e.key,
                  child: Text(e.value),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null && val != _selectedUserId) {
                  _selectedUserId = val;
                  _fetchTasksFor(val);
                }
              },
            ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? Center(child: Text('No tasks found for this user today!'.tr(), style: const TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _tasks.length,
                        itemBuilder: (context, index) {
                          final t = _tasks[index];
                          final isSelected = _selectedTasks.any((st) => st.id == t.id && st.title == t.title);
                          return Card(
                            child: CheckboxListTile(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedTasks.add(t);
                                  } else {
                                    _selectedTasks.removeWhere((st) => st.id == t.id && st.title == t.title);
                                  }
                                });
                              },
                              secondary: const Icon(Icons.task_alt_rounded, color: Colors.blue),
                              title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${t.totalDurationMinutes} ${'mins'.tr()}'),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _selectedTasks.isEmpty ? null : _submit,
            icon: const Icon(Icons.check_circle_rounded),
            label: Text('${'Review & Add'.tr()} (${_selectedTasks.length})'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )
        ],
      ),
    );
  }
}
