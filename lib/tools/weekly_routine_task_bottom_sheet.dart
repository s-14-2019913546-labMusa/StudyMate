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
class AddWeeklyRoutineTaskBottomSheet extends StatefulWidget {
  final Task? taskToEdit;
  final String? initialDay;
  final bool isDuplicate;

  const AddWeeklyRoutineTaskBottomSheet({
    super.key,
    this.taskToEdit,
    this.initialDay,
    this.isDuplicate = false,
  });

  @override
  State<AddWeeklyRoutineTaskBottomSheet> createState() => _AddWeeklyRoutineTaskBottomSheetState();
}

class _AddWeeklyRoutineTaskBottomSheetState extends State<AddWeeklyRoutineTaskBottomSheet> {
  String _selectedDay = 'Saturday';
  String _selectedCategory = 'Study';
  String _selectedSubCategory = 'None';
  bool _isPrivate = false;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _topicController = TextEditingController();
  final _challengesController = TextEditingController();
  final _notesController = TextEditingController();

  final List<String> _categories = ['Study', 'Work', 'Sports', 'Other'];
  List<String> _studyFolders = [];
  final List<String> _days = ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  @override
  void initState() {
    super.initState();
    _loadCustomFolders();
    if (widget.initialDay != null) {
      _selectedDay = widget.initialDay!;
    }
    if (widget.taskToEdit != null) {
      _subjectController.text = widget.taskToEdit!.subject ?? widget.taskToEdit!.title;
      _topicController.text = widget.taskToEdit!.topic ?? '';
      _challengesController.text = widget.taskToEdit!.challenges ?? '';
      _notesController.text = widget.taskToEdit!.notes ?? '';
      _isPrivate = widget.taskToEdit!.isPrivate;
      if (widget.taskToEdit!.startTime != null) {
        _startTime = TimeOfDay.fromDateTime(widget.taskToEdit!.startTime!);
      }
      if (widget.taskToEdit!.endTime != null) {
        _endTime = TimeOfDay.fromDateTime(widget.taskToEdit!.endTime!);
      }
      _selectedCategory = widget.taskToEdit!.category ?? 'Study';
      if (!_categories.contains(_selectedCategory)) {
        _selectedSubCategory = _selectedCategory;
        _selectedCategory = 'Study';
      }
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _topicController.dispose();
    _challengesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomFolders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('studyFolders')
          .get();
      final folderNames = snapshot.docs.map((doc) => doc.data()['name'] as String).toList();
      if (mounted && folderNames.isNotEmpty) {
        setState(() {
          _studyFolders = folderNames;
        });
      }
    } catch (e) {
      debugPrint("Error loading custom folders for weekly routine: $e");
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? TimeOfDay.now()),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  DateTime _getNextWeekdayDate(String dayName) {
    const dayMap = {
      'Saturday': DateTime.saturday,
      'Sunday': DateTime.sunday,
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
    };
    final target = dayMap[dayName] ?? DateTime.saturday;
    final now = DateTime.now();
    int daysUntil = (target - now.weekday + 7) % 7;
    if (daysUntil == 0) daysUntil = 7;
    return now.add(Duration(days: daysUntil));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select start and end time.'.tr())),
      );
      return;
    }
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('End time must be after start time.'.tr())),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final targetDate = _getNextWeekdayDate(_selectedDay);
    final startDateTime = DateTime(
      targetDate.year, targetDate.month, targetDate.day,
      _startTime!.hour, _startTime!.minute,
    );
    final endDateTime = DateTime(
      targetDate.year, targetDate.month, targetDate.day,
      _endTime!.hour, _endTime!.minute,
    );

    final taskSubject = _subjectController.text.trim();
    final taskId = (widget.taskToEdit != null && !widget.isDuplicate)
        ? widget.taskToEdit!.id
        : UniqueKey().toString();

    final durationMinutes = endDateTime.difference(startDateTime).inMinutes;

    final task = Task(
      id: taskId,
      title: taskSubject,
      subject: taskSubject,
      topic: _topicController.text.trim(),
      challenges: _challengesController.text.trim(),
      notes: _notesController.text.trim(),
      startTime: startDateTime,
      endTime: endDateTime,
      totalDurationMinutes: durationMinutes > 0 ? durationMinutes : 0,
      category: (_selectedCategory == 'Study' && _selectedSubCategory != 'None') ? _selectedSubCategory : _selectedCategory,
      isPrivate: _isPrivate,
    );

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('weeklyRoutines');

      if (widget.taskToEdit != null && !widget.isDuplicate) {
        if (widget.initialDay == _selectedDay) {
          await userRef
              .doc(_selectedDay)
              .collection('tasks')
              .doc(taskId)
              .set(task.toMap());
        } else {
          if (widget.initialDay != null) {
            await userRef
                .doc(widget.initialDay)
                .collection('tasks')
                .doc(taskId)
                .delete();
          }
          await userRef
              .doc(_selectedDay)
              .collection('tasks')
              .doc(taskId)
              .set(task.toMap());
        }
      } else {
        await userRef
            .doc(_selectedDay)
            .collection('tasks')
            .doc(taskId)
            .set(task.toMap());
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task Added Successfully!'.tr())),
        );
      }
    } catch (e) {
      debugPrint("Error saving weekly task: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save task.'.tr())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurfaceColor = colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.82)
                : Colors.white.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'à¦‰à¦‡à¦•à¦²à¦¿ à¦°à§à¦Ÿà¦¿à¦¨à§‡ à¦Ÿà¦¾à¦¸à§à¦• à¦¯à§à¦•à§à¦¤ à¦•à¦°à§à¦¨',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: onSurfaceColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Day selector
              Text(
                'à¦¦à¦¿à¦¨ à¦¬à¦¾à¦›à§à¦¨ (Select Day)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: onSurfaceColor,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedDay,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: onSurfaceColor.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                  prefixIcon: Icon(Icons.calendar_today, color: colorScheme.primary),
                ),
                dropdownColor: colorScheme.surface,
                style: TextStyle(color: onSurfaceColor),
                items: _days.map((day) => DropdownMenuItem(
                  value: day,
                  child: Text(day, style: TextStyle(color: onSurfaceColor)),
                )).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedDay = val);
                },
              ),
              const SizedBox(height: 16),

              // Subject
              Text(
                'Subject Name (à¦¬à¦¿à¦·à¦¯à¦¼)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: onSurfaceColor,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectController,
                style: TextStyle(color: onSurfaceColor),
                decoration: InputDecoration(
                  hintText: 'Enter Subject Name',
                  hintStyle: TextStyle(color: onSurfaceColor.withValues(alpha: 0.6)),
                  prefixIcon: Icon(Icons.subject, color: colorScheme.primary),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: onSurfaceColor.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                ),
                validator: (val) => val == null || val.isEmpty ? 'à¦¬à¦¿à¦·à¦¯à¦¼à§‡à¦° à¦¨à¦¾à¦® à¦¦à¦¿à¦¨' : null,
              ),
              const SizedBox(height: 16),

              // Topic
              Text(
                'Topic Name (à¦¬à¦¿à¦·à¦¯à¦¼à¦¬à¦¸à§à¦¤à§)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: onSurfaceColor,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _topicController,
                style: TextStyle(color: onSurfaceColor),
                decoration: InputDecoration(
                  hintText: 'Enter Topic Name',
                  hintStyle: TextStyle(color: onSurfaceColor.withValues(alpha: 0.6)),
                  prefixIcon: Icon(Icons.title_rounded, color: colorScheme.primary),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: onSurfaceColor.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Challenges
              Text(
                'Possible Challenges (à¦¸à¦®à§à¦­à¦¾à¦¬à§à¦¯ à¦¸à¦®à¦¸à§à¦¯à¦¾)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: onSurfaceColor,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _challengesController,
                style: TextStyle(color: onSurfaceColor),
                decoration: InputDecoration(
                  hintText: 'Describe potential issues or difficulties...',
                  hintStyle: TextStyle(color: onSurfaceColor.withValues(alpha: 0.6)),
                  prefixIcon: Icon(Icons.warning_amber_rounded, color: colorScheme.primary),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: onSurfaceColor.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notes
              Text(
                'Task Goal / Notes (à¦²à¦•à§à¦·à§à¦¯ à¦“ à¦¨à§‹à¦Ÿ)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: onSurfaceColor,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                style: TextStyle(color: onSurfaceColor),
                decoration: InputDecoration(
                  hintText: 'Enter notes or specific goals...',
                  hintStyle: TextStyle(color: onSurfaceColor.withValues(alpha: 0.6)),
                  prefixIcon: Icon(Icons.notes, color: colorScheme.primary),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: onSurfaceColor.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Time pickers
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(true),
                      icon: Icon(Icons.access_time, color: colorScheme.primary),
                      label: Text(
                        _startTime?.format(context) ?? 'Start Time',
                        style: TextStyle(color: onSurfaceColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: onSurfaceColor.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(false),
                      icon: Icon(Icons.access_time, color: colorScheme.primary),
                      label: Text(
                        _endTime?.format(context) ?? 'End Time',
                        style: TextStyle(color: onSurfaceColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: onSurfaceColor.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category
              Text(
                'Category',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: onSurfaceColor),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10.0,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(
                      cat,
                      style: TextStyle(color: isSelected ? Colors.white : onSurfaceColor),
                    ),
                    selected: isSelected,
                    selectedColor: colorScheme.primary,
                    backgroundColor: colorScheme.surface,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = cat;
                          if (cat != 'Study') {
                            _selectedSubCategory = 'None';
                          }
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              
              // Sub-category (Folder) Selection
              if (_selectedCategory == 'Study') ...[
                Text(
                  'Sub-category (Folder)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: onSurfaceColor),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSubCategory,
                  items: {'None', _selectedSubCategory, ..._studyFolders}.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: onSurfaceColor)))).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedSubCategory = v ?? 'None';
                    });
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Private toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Private Task',
                  style: TextStyle(fontWeight: FontWeight.bold, color: onSurfaceColor),
                ),
                subtitle: Text(
                  'Hide task name from others',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                value: _isPrivate,
                activeThumbColor: colorScheme.primary,
                onChanged: (val) => setState(() => _isPrivate = val),
              ),
              const SizedBox(height: 24),

              // Submit button
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text('Add to Weekly Routine'.tr()),
              ),
              const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



// ==========================================
// 10. Sleep Tracker Screen (à¦¸à§à¦²à¦¿à¦ª à¦Ÿà§à¦°à§à¦¯à¦¾à¦•à¦¾à¦° à¦“ à¦…à§à¦¯à¦¾à¦²à¦¾à¦°à§à¦®)
