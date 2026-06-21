import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter/services.dart'; // ভাইব্রেশন এবং সিস্টেম সাউন্ডের জন্য
import 'package:flutter/cupertino.dart'; // টাইমার পিকারের জন্য
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'daily_routine.dart'; // Task মডেল ইমপোর্ট করার জন্য
import 'focus_music_screen.dart';
import 'flashcards_screen.dart';
import 'dictionary_screen.dart';
import 'ai_service.dart';
import 'revision_147_screen.dart';
import 'islamic_life_screen.dart';
import 'theme_manager.dart';
import 'dashboard_screen.dart';

class ToolsScreen extends StatelessWidget {
  final Function(List<Task>) onTasksGenerated;
  const ToolsScreen({super.key, required this.onTasksGenerated});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> categories = [
      {
        'name': 'Study & Revision',
        'icon': Icons.school_rounded,
        'tools': [
          {'title': 'Study Analytics', 'icon': Icons.analytics_rounded, 'color': Colors.teal, 'action': 'analytics'},
          {'title': 'PDF Reader', 'icon': Icons.picture_as_pdf_rounded, 'color': Colors.redAccent, 'action': 'pdf_reader'},
          {'title': '1-4-7 Revision', 'icon': Icons.published_with_changes_rounded, 'color': Colors.indigo, 'action': 'revision_147'},
          {'title': 'Flashcards', 'icon': Icons.style_rounded, 'color': Colors.purpleAccent, 'action': 'flash'},
          {'title': 'Dictionary', 'icon': Icons.menu_book_rounded, 'color': Colors.orangeAccent, 'action': 'dict'},
        ]
      },
      {
        'name': 'Focus & Productivity',
        'icon': Icons.bolt_rounded,
        'tools': [
          {'title': 'Pomodoro', 'icon': Icons.timer_rounded, 'color': Colors.redAccent, 'action': 'pomodoro'},
          {'title': 'Stopwatch', 'icon': Icons.timer_outlined, 'color': Colors.deepOrangeAccent, 'action': 'stopwatch'},
          {'title': 'Focus Music', 'icon': Icons.headphones_rounded, 'color': Colors.teal, 'action': 'music'},
          {'title': 'Quick Notes', 'icon': Icons.note_alt_rounded, 'color': Colors.amber.shade600, 'action': 'notes'},
        ]
      },
      {
        'name': 'Collaborative Studying',
        'icon': Icons.people_rounded,
        'tools': [
          {'title': 'Study Room', 'icon': Icons.video_camera_front_rounded, 'color': Colors.deepPurpleAccent, 'action': 'study_room'},
          {'title': 'Partner Tasks', 'icon': Icons.group_add_rounded, 'color': Colors.green, 'action': 'partner_tasks'},
        ]
      },
      {
        'name': 'Well-being & Utilities',
        'icon': Icons.favorite_rounded,
        'tools': [
          {'title': 'Breathing', 'icon': Icons.air_rounded, 'color': Colors.lightBlueAccent, 'action': 'breath'},
          {'title': 'Mood Tracker', 'icon': Icons.mood_rounded, 'color': Colors.pinkAccent, 'action': 'mood'},
          {'title': 'Sleep Tracker', 'icon': Icons.bedtime_rounded, 'color': Colors.indigoAccent, 'action': 'sleep'},
          {'title': 'Islamic Life', 'icon': Icons.mosque_rounded, 'color': Colors.teal, 'action': 'islamic'},
          {'title': 'Calculator', 'icon': Icons.calculate_rounded, 'color': Colors.blueAccent, 'action': 'calc'},
          {'title': 'Theme Option', 'icon': Icons.palette_rounded, 'color': Colors.amber, 'action': 'theme'},
        ]
      },
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Study Tools',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 24),
            
            // AI Study Planner Banner (First Tool)
            _buildAIPlannerBanner(context),
            const SizedBox(height: 12),
            _buildNextDayRoutineButton(context),
            const SizedBox(height: 12),
            _buildWeeklyRoutineButton(context),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: categories.map((category) {
                final List<Map<String, dynamic>> catTools = category['tools'];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 28.0, bottom: 12.0),
                      child: Row(
                        children: [
                          Icon(category['icon'], size: 20, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            category['name'],
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                ),
                          ),
                        ],
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, // এক লাইনে ৩টি করে বক্স থাকবে
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.95, // ৩ কলামের মানানসই অনুপাত
                      ),
                      itemCount: catTools.length,
                      itemBuilder: (context, index) {
                        final tool = catTools[index];
                        final cardDeco = ThemeManager.getCardDecoration(context);
                        return Container(
                          decoration: cardDeco,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: cardDeco.borderRadius as BorderRadius?,
                              onTap: () {
                                if (tool['action'] == 'mood') {
                                  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const MoodTrackerBottomSheet());
                                } else if (tool['action'] == 'breath') {
                                  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const BreathingExerciseBottomSheet());
                                } else if (tool['action'] == 'routine') {
                                  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const RoutinePlannerBottomSheet());
                                } else if (tool['action'] == 'analytics') {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyAnalyticsScreen()));
                                } else if (tool['action'] == 'pdf_reader') {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfReaderScreen()));
                                } else if (tool['action'] == 'pomodoro') {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PomodoroTimerScreen()));
                                } else if (tool['action'] == 'stopwatch') {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const StopwatchScreen()));
                                } else if (tool['action'] == 'calc') {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CalculatorScreen()));
                                } else if (tool['action'] == 'study_room') {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyRoomScreen()));
                                } else if (tool['action'] == 'partner_tasks') {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PartnerTasksScreen()));
                                } else if (tool['action'] == 'notes') {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickNotesScreen()));
                                } else if (tool['action'] == 'sleep') {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SleepTrackerScreen()));
                                } else if (tool['action'] == 'music') {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusMusicScreen()));
                                } else if (tool['action'] == 'flash') {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FlashcardDecksScreen()));
                                } else if (tool['action'] == 'dict') {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DictionaryScreen()));
                                } else if (tool['action'] == 'revision_147') {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const Revision147Screen()));
                                } else if (tool['action'] == 'islamic') {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const IslamicLifeScreen()));
                                } else if (tool['action'] == 'theme') {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => const ThemeCustomizerBottomSheet(),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${tool['title']} is coming soon!')),
                                  );
                                }
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: tool['color'].withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(tool['icon'], size: 22, color: tool['color']),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    child: Text(
                                      tool['title'],
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIPlannerBanner(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => AIStudyPlannerBottomSheet(
            onTasksGenerated: onTasksGenerated,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)], // Purple gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Study Planner', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Plan your study smartly in one click!', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildNextDayRoutineButton(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return GestureDetector(
      onTap: () {
        if (user == null) return;
        final tomorrowDate = DateTime.now().add(const Duration(days: 1));
        final tomorrowDocId = DateFormat('yyyy-MM-dd').format(tomorrowDate);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => AddTaskBottomSheet(
            onTaskAdded: (newTask) async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('dailyRoutines')
                  .doc(tomorrowDocId)
                  .get()
                  .then((doc) async {
                if (doc.exists) {
                  await doc.reference.update({
                    'tasks': FieldValue.arrayUnion([newTask.toMap()])
                  });
                } else {
                  final newRoutine = DailyRoutine(
                    id: tomorrowDocId,
                    userId: user.uid,
                    date: tomorrowDate,
                    tasks: [newTask],
                  );
                  await doc.reference.set(newRoutine.toMap());
                }
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Added to tomorrow\'s routine!')),
                );
              }
            },
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.next_plan_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Next-day Routine (নেক্সট ডে রুটিন)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('আগামীকালের পড়ার রুটিন তৈরি করুন', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyRoutineButton(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return GestureDetector(
      onTap: () {
        if (user == null) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const AddWeeklyRoutineTaskBottomSheet(),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF047857)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.calendar_view_week_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Weekly Routine (উইকলি রুটিন)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('সাপ্তাহিক রুটিন কাস্টমাইজ ও আপডেট করুন', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }
}

class AddWeeklyRoutineTaskBottomSheet extends StatefulWidget {
  const AddWeeklyRoutineTaskBottomSheet({super.key});

  @override
  State<AddWeeklyRoutineTaskBottomSheet> createState() => _AddWeeklyRoutineTaskBottomSheetState();
}

class _AddWeeklyRoutineTaskBottomSheetState extends State<AddWeeklyRoutineTaskBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _challengesController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isPrivate = false;
  String _selectedCategory = 'Study';
  String _selectedDay = 'Saturday';

  final List<String> _categories = ['Study', 'Work', 'Sports', 'Other'];
  final List<String> _days = ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  @override
  void dispose() {
    _subjectController.dispose();
    _topicController.dispose();
    _challengesController.dispose();
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

  void _submit() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_formKey.currentState!.validate()) {
      if (_startTime == null || _endTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select both Start and End Time.')));
        return;
      }

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, _startTime!.hour, _startTime!.minute);
      var end = DateTime(now.year, now.month, now.day, _endTime!.hour, _endTime!.minute);

      if (end.isBefore(start)) {
        end = end.add(const Duration(days: 1));
      }

      final durationMinutes = end.difference(start).inMinutes;

      final newTask = Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _subjectController.text.trim(),
        subject: _subjectController.text.trim(),
        topic: _topicController.text.trim(),
        challenges: _challengesController.text.trim(),
        notes: _notesController.text.trim(),
        startTime: start,
        endTime: end,
        isPrivate: _isPrivate,
        category: _selectedCategory,
        totalDurationMinutes: durationMinutes,
      );

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('weeklyRoutines')
          .doc(_selectedDay);

      final snapshot = await docRef.get();
      if (snapshot.exists) {
        await docRef.update({
          'tasks': FieldValue.arrayUnion([newTask.toMap()])
        });
      } else {
        await docRef.set({
          'day': _selectedDay,
          'tasks': [newTask.toMap()],
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to $_selectedDay weekly routine!')));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final colorScheme = Theme.of(context).colorScheme;
    final onSurfaceColor = colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: bottomInset + 24.0),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Weekly Routine Task',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: onSurfaceColor,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              Text(
                'Select Day (দিন নির্বাচন)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: onSurfaceColor,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedDay,
                dropdownColor: colorScheme.surface,
                style: TextStyle(color: onSurfaceColor),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: onSurfaceColor.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _days.map((d) => DropdownMenuItem(
                  value: d,
                  child: Text(d, style: TextStyle(color: onSurfaceColor)),
                )).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedDay = val);
                },
              ),
              const SizedBox(height: 16),
              
              Text(
                'Subject Name (বিষয়)',
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
                validator: (val) => val == null || val.isEmpty ? 'Enter a subject name' : null,
              ),
              const SizedBox(height: 16),

              Text(
                'Topic Name (বিষয়বস্তু)',
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

              Text(
                'Possible Challenges (সম্ভাব্য সমস্যা)',
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
              
              Text(
                'Task Goal / Notes (লক্ষ্য ও নোট)',
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
                      if (selected) setState(() => _selectedCategory = cat);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

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

              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                child: const Text('উইকলি রুটিনে যুক্ত করুন (Add to Weekly)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 10. Sleep Tracker Screen (স্লিপ ট্র্যাকার ও অ্যালার্ম)
// ==========================================
class SleepTrackerScreen extends StatefulWidget {
  const SleepTrackerScreen({super.key});

  @override
  State<SleepTrackerScreen> createState() => _SleepTrackerScreenState();
}

class _SleepTrackerScreenState extends State<SleepTrackerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  TimeOfDay _bedTime = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _morningTime = const TimeOfDay(hour: 6, minute: 0);
  
  bool _isSleeping = false;
  DateTime? _sleepStartTime;
  Timer? _tickTimer;
  Timer? _alarmRingingTimer;
  bool _alarmTriggered = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tickTimer?.cancel();
    _alarmRingingTimer?.cancel();
    super.dispose();
  }

  void _startSleep() {
    setState(() {
      _isSleeping = true;
      _sleepStartTime = DateTime.now();
      _alarmTriggered = false;
    });

    // লাইভ টাইমার এবং অ্যালার্ম চেকার
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {}); // UI আপডেট (টাইমার চলতে থাকবে)

      final now = DateTime.now();
      // চেক করবো মর্নিং টাইম হয়েছে কিনা (এবং একবারই বাজবে)
      if (!_alarmTriggered && now.hour == _morningTime.hour && now.minute == _morningTime.minute) {
        _alarmTriggered = true;
        _triggerAlarm();
      }
      
      // অন্য মিনিট হলে ট্রিগার রিসেট হবে (যাতে পরের দিন বা স্নুজে আবার বাজতে পারে)
      if (now.minute != _morningTime.minute) {
        _alarmTriggered = false;
      }
    });
  }

  void _triggerAlarm() {
    HapticFeedback.heavyImpact();
    _alarmRingingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.alert);
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('⏰ Good Morning!', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('It is time to rise and shine. Do you want to snooze or turn off the alarm?', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () {
              _alarmRingingTimer?.cancel();
              Navigator.pop(ctx);
              _snoozeAlarm();
            },
            child: const Text('Snooze (5m)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              _alarmRingingTimer?.cancel();
              Navigator.pop(ctx);
              _stopSleepAndSave();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Turn Off'),
          ),
        ],
      ),
    );
  }

  void _snoozeAlarm() {
    final snoozeTime = DateTime.now().add(const Duration(minutes: 5));
    setState(() {
      _morningTime = TimeOfDay.fromDateTime(snoozeTime);
      _alarmTriggered = false; // স্নুজের জন্য আবার ট্রিগার রেডি করা হলো
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alarm snoozed. Will ring again in 5 minutes.')));
  }

  Future<void> _stopSleepAndSave() async {
    _tickTimer?.cancel();
    _alarmRingingTimer?.cancel();

    if (_sleepStartTime == null || currentUser == null) {
      setState(() => _isSleeping = false);
      return;
    }

    final now = DateTime.now();
    final duration = now.difference(_sleepStartTime!);

    setState(() => _isSleeping = false);

    // ফায়ারবেসে স্লিপ হিস্ট্রি সেভ করা
    await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('sleep_history').add({
      'bedTime': Timestamp.fromDate(_sleepStartTime!),
      'wakeTime': Timestamp.fromDate(now),
      'durationMinutes': duration.inMinutes,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sleep session saved to history!')));
    }
  }

  void _pickTime(bool isBedTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isBedTime ? _bedTime : _morningTime,
    );
    if (picked != null) {
      setState(() {
        if (isBedTime) {
          _bedTime = picked;
        } else {
          _morningTime = picked;
        }
      });
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String h = twoDigits(d.inHours);
    String m = twoDigits(d.inMinutes.remainder(60));
    String s = twoDigits(d.inSeconds.remainder(60));
    return "$h:$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Sleep Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [Tab(text: 'Tracker & Alarm'), Tab(text: 'Sleep History')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTrackerTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildTrackerTab() {
    if (_isSleeping) {
      // ঘুমানোর সময়ের লাইভ টাইমার স্ক্রিন
      final duration = DateTime.now().difference(_sleepStartTime!);
      return Container(
        color: const Color(0xFF0F172A), // Dark night background
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.nightlight_round, size: 80, color: Colors.amberAccent),
            const SizedBox(height: 24),
            const Text('Good Night!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('Sleep timer is running...', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 40),
            Text(
              _formatDuration(duration),
              style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w300, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 60),
            ElevatedButton.icon(
              onPressed: _stopSleepAndSave,
              icon: const Icon(Icons.stop_circle_rounded),
              label: const Text('Wake Up Now (Stop)'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.bedtime_rounded, size: 80, color: Colors.indigoAccent),
          const SizedBox(height: 24),
          Text('Set Your Sleep Schedule', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 8),
          const Text('The alarm will ring at the morning time and snooze every 5 minutes if not turned off.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          
          Row(
            children: [
              Expanded(
                child: _buildTimeCard('Bed Time', _bedTime, true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTimeCard('Morning Time', _morningTime, false),
              ),
            ],
          ),
          
          const SizedBox(height: 60),
          ElevatedButton.icon(
            onPressed: _startSleep,
            icon: const Icon(Icons.bed_rounded, size: 28),
            label: const Text('Go to Sleep', style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard(String title, TimeOfDay time, bool isBedTime) {
    final cardDeco = ThemeManager.getCardDecoration(context);
    return InkWell(
      onTap: () => _pickTime(isBedTime),
      borderRadius: cardDeco.borderRadius as BorderRadius?,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: cardDeco,
        child: Column(
          children: [
            Icon(isBedTime ? Icons.hotel_rounded : Icons.wb_sunny_rounded, color: isBedTime ? Colors.indigoAccent : Colors.orangeAccent, size: 32),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(time.format(context), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (currentUser == null) return const Center(child: Text("Please log in to view sleep history."));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('sleep_history')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No sleep records found.", style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final wakeTime = (data['wakeTime'] as Timestamp).toDate();
            final bedTime = (data['bedTime'] as Timestamp).toDate();
            final durationMins = data['durationMinutes'] ?? 0;
            
            int hours = durationMins ~/ 60;
            int mins = durationMins % 60;

            String dateStr = DateFormat('MMM dd, yyyy').format(wakeTime);
            String bedStr = DateFormat('hh:mm a').format(bedTime);
            String wakeStr = DateFormat('hh:mm a').format(wakeTime);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.nights_stay_rounded, color: Colors.indigo),
                ),
                title: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('Bed: $bedStr  •  Wake: $wakeStr'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Total Sleep', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('${hours}h ${mins}m', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 16)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ==========================================
// 9. Quick Notes Screen (ইন্টারন্যাশনাল মানের নোটস)
// ==========================================
class QuickNotesScreen extends StatefulWidget {
  const QuickNotesScreen({super.key});

  @override
  State<QuickNotesScreen> createState() => _QuickNotesScreenState();
}

class _QuickNotesScreenState extends State<QuickNotesScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isSaving = false;
  bool _isProcessingAI = false;
  String? _geminiApiKey;
  Stream<QuerySnapshot>? _notesLimitStream;
  Stream<QuerySnapshot>? _notesAllStream;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    if (currentUser != null) {
      _notesLimitStream = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('notes')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots();
      _notesAllStream = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('notes')
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
  }

  Future<void> _loadApiKey() async {
    if (currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _geminiApiKey = doc.data()?['geminiApiKey'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading API key in notes: $e');
    }
  }

  // Advanced Note States
  bool _isNoteDarkMode = false;
  double _fontSize = 16.0;
  bool _isRecording = false;

  // Audio Recording States
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioFilePath;

  // Image Attachment States
  final ImagePicker _imagePicker = ImagePicker();
  String? _imageFilePath;

  void _insertFormatting(String prefix, String suffix) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (selection.isValid) {
      final selectedText = selection.textInside(text);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + prefix.length + selectedText.length + suffix.length),
      );
    } else {
      final newText = text + prefix + suffix;
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length - suffix.length),
      );
    }
  }

  void _insertBullet() {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final prefix = '\n• ';
    if (selection.isValid) {
      final newText = text.replaceRange(selection.start, selection.end, prefix);
       _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + prefix.length),
      );
    } else {
      _insertFormatting(prefix, '');
    }
  }

  void _simulateAction(String actionName) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$actionName activated. (Simulation)')));
  }

  Future<void> _summarizeNoteWithAI() async {
    final noteContent = _contentController.text.trim();
    if (noteContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot summarize an empty note.')),
      );
      return;
    }

    setState(() => _isProcessingAI = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI is summarizing your note...')),
    );

    try {
      final summary = await AIService.summarizeNote(noteContent, _geminiApiKey);
      if (!mounted) return;
      if (summary.isNotEmpty) {
        setState(() {
          _contentController.text = '${_contentController.text}\n\n$summary';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Summary added to note!'), backgroundColor: Colors.purple),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to summarize: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingAI = false);
      }
    }
  }

  void _writeWithAI() {
    final TextEditingController promptController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.auto_awesome_rounded, color: Colors.indigoAccent),
            SizedBox(width: 8),
            Text('Write with AI'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter a topic or question (e.g. "Write about Kazi Nazrul" or "Explain photosynthesis"). AI will write a comprehensive study note.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: promptController,
              decoration: const InputDecoration(
                hintText: 'Enter topic prompt...',
                prefixIcon: Icon(Icons.psychology_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final prompt = promptController.text.trim();
              if (prompt.isEmpty) return;
              Navigator.pop(ctx);
              
              setState(() => _isProcessingAI = true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI is researching and writing...')),
              );

              try {
                final generatedContent = await AIService.generateNoteContent(prompt, _geminiApiKey);
                if (!mounted) return;
                if (generatedContent.isNotEmpty) {
                  setState(() {
                    _contentController.text = generatedContent;
                    if (_titleController.text.trim().isEmpty) {
                      _titleController.text = prompt.length > 20 ? '${prompt.substring(0, 20)}...' : prompt;
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('AI study note generated successfully!'), backgroundColor: Colors.indigo),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Generation failed: $e'), backgroundColor: Colors.redAccent),
                );
              } finally {
                if (mounted) {
                  setState(() => _isProcessingAI = false);
                }
              }
            },
            child: const Text('Write Note'),
          ),
        ],
      ),
    );
  }

  // অডিও রেকর্ডিং টগল করার মূল লজিক
  Future<void> _toggleAudioRecording() async {
    if (_isRecording) {
      // রেকর্ডিং বন্ধ করা
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _audioFilePath = path;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio recorded! Will be saved with the note.')));
    } else {
      // পারমিশন চেক করে রেকর্ডিং শুরু করা
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/note_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _audioFilePath = null;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording audio...')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission required.')));
      }
    }
  }

  // গ্যালারি থেকে ছবি সিলেক্ট করার লজিক
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (pickedFile != null) {
        setState(() {
          _imageFilePath = pickedFile.path;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image attached!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick image.')));
    }
  }

  Future<void> _saveNote() async {
    if (_titleController.text.trim().isEmpty && _contentController.text.trim().isEmpty && _audioFilePath == null && _imageFilePath == null) return;
    if (currentUser == null) return;

    setState(() => _isSaving = true);

    String? audioUrl;
    String? imageUrl;
    if (_audioFilePath != null) {
      try {
        final File audioFile = File(_audioFilePath!);
        // ফায়ারবেস ক্লাউড স্টোরেজে আপলোড
        final storageRef = FirebaseStorage.instance.ref().child('notes_audio/${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.m4a');
        final uploadTask = await storageRef.putFile(audioFile);
        audioUrl = await uploadTask.ref.getDownloadURL();
      } catch (e) {
        debugPrint("Audio Upload Error: $e");
      }
    }

    // ছবি ফায়ারবেস ক্লাউড স্টোরেজে আপলোড
    if (_imageFilePath != null) {
      try {
        final File imageFile = File(_imageFilePath!);
        final storageRef = FirebaseStorage.instance.ref().child('notes_images/${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        final uploadTask = await storageRef.putFile(imageFile);
        imageUrl = await uploadTask.ref.getDownloadURL();
      } catch (e) {
        debugPrint("Image Upload Error: $e");
      }
    }

    await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('notes').add({
      'title': _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Untitled Note',
      'content': _contentController.text.trim(),
      'audioUrl': audioUrl,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _titleController.clear();
    _contentController.clear();
    if (mounted) {
      FocusScope.of(context).unfocus(); // কিবোর্ড নামিয়ে দেওয়ার জন্য
    }
    
    setState(() {
      _isSaving = false;
      _audioFilePath = null;
      _imageFilePath = null;
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved securely!')));
  }

  void _showVersionHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isNoteDarkMode ? const Color(0xFF2D2D2D) : Theme.of(context).cardColor,
        title: Row(
          children: [
            const Icon(Icons.restore_rounded, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Version History', style: TextStyle(color: _isNoteDarkMode ? Colors.white : Colors.black87)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Restore a previous version of this note if you made a mistake.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Today, 10:30 AM', style: TextStyle(color: _isNoteDarkMode ? Colors.white : Colors.black)),
              subtitle: Text('Auto-saved', style: TextStyle(color: Colors.grey.shade500)),
              trailing: TextButton(onPressed: () { Navigator.pop(ctx); _simulateAction('Restored to 10:30 AM version'); }, child: const Text('Restore')),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Yesterday, 5:15 PM', style: TextStyle(color: _isNoteDarkMode ? Colors.white : Colors.black)),
              subtitle: Text('Manual save', style: TextStyle(color: Colors.grey.shade500)),
              trailing: TextButton(onPressed: () { Navigator.pop(ctx); _simulateAction('Restored to Yesterday version'); }, child: const Text('Restore')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showPreviousNotesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isDark = _isNoteDarkMode; 
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Previous Notes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  IconButton(icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black), onPressed: () => Navigator.pop(context)),
                ],
              ),
              Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
              Expanded(
                child: currentUser == null 
                  ? Center(child: Text('Please log in to view notes.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)))
                  : StreamBuilder<QuerySnapshot>(
                      stream: _notesAllStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('No notes found. Create your first note above!', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey)));

                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final doc = snapshot.data!.docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final title = data['title'] ?? 'Untitled';
                            final content = data['content'] ?? '';
                            final timestamp = data['timestamp'] as Timestamp?;
                            final audioUrl = data['audioUrl'] as String?;
                            final imageUrl = data['imageUrl'] as String?;
                            String dateStr = 'Just now';
                            if (timestamp != null) {
                              dateStr = DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate());
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.pop(context); // Close bottom sheet
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => NoteDetailScreen(
                                    title: title,
                                    content: content,
                                    date: dateStr,
                                    audioUrl: audioUrl,
                                    imageUrl: imageUrl,
                                  )));
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                          if (audioUrl != null)
                                            Icon(Icons.mic_rounded, color: isDark ? Colors.grey.shade400 : Colors.grey, size: 20),
                                          if (imageUrl != null)
                                            Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.image_rounded, color: isDark ? Colors.grey.shade400 : Colors.grey, size: 20)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        content,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(dateStr, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade500 : Colors.black38, fontStyle: FontStyle.italic)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = _isNoteDarkMode ? const Color(0xFF1E1E1E) : Theme.of(context).colorScheme.surface;
    Color textColor = _isNoteDarkMode ? Colors.white : Colors.black87;
    Color cardColor = _isNoteDarkMode ? const Color(0xFF2D2D2D) : Theme.of(context).cardColor;

    return Scaffold(
      resizeToAvoidBottomInset: false, // FAB এর সাথে কিবোর্ডের সমস্যা এড়ানোর জন্য
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Smart Notes', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(_isNoteDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: 'Toggle Dark Mode',
            onPressed: () => setState(() => _isNoteDarkMode = !_isNoteDarkMode),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Version History',
            onPressed: () => _showVersionHistory(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100), // FAB এর জন্য জায়গা
        child: Column(
          children: [
            if (_isProcessingAI)
              const LinearProgressIndicator(color: Colors.indigoAccent),
            // 1. Smart Editor Box
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _isNoteDarkMode ? Colors.grey.shade800 : Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                children: [
                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: TextField(
                      controller: _titleController,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Note Title...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  Divider(height: 1, color: _isNoteDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
                  
                  // Boxed Content Body
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isNoteDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _isNoteDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          // ডায়েরির মতো দাগ দেওয়ার জন্য
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _LinedPaperPainter(lineHeight: _fontSize * 1.5, isDarkMode: _isNoteDarkMode),
                            ),
                          ),
                          TextField(
                            controller: _contentController,
                            maxLines: 10, // একটি নির্দিষ্ট উচ্চতা দেওয়া হলো
                            minLines: 8,
                            style: TextStyle(fontSize: _fontSize, color: textColor, height: 1.5),
                            decoration: InputDecoration(
                              hintText: 'Start writing your notes here...',
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Rich Text Toolbar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isNoteDarkMode ? const Color(0xFF333333) : Colors.grey.shade100,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                      border: Border(top: BorderSide(color: _isNoteDarkMode ? Colors.grey.shade800 : Colors.grey.shade200)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFormatBtn(Icons.format_bold_rounded, () => _insertFormatting('**', '**'), tooltip: 'Bold'),
                          _buildFormatBtn(Icons.format_italic_rounded, () => _insertFormatting('*', '*'), tooltip: 'Italic'),
                          _buildFormatBtn(Icons.format_quote_rounded, () => _insertFormatting('\n> ', ''), tooltip: 'Quote'),
                          _buildFormatBtn(Icons.format_list_bulleted_rounded, _insertBullet, tooltip: 'Bullet List'),
                          _buildFormatBtn(Icons.format_color_text_rounded, () => _simulateAction('Text Color Picker'), tooltip: 'Text Color'),
                          Container(width: 1, height: 24, color: Colors.grey, margin: const EdgeInsets.symmetric(horizontal: 8)),
                          _buildFormatBtn(Icons.camera_alt_rounded, () => _simulateAction('Camera Scanner (OCR)'), tooltip: 'Scan Text', color: Colors.teal),
                          _buildFormatBtn(Icons.image_rounded, _pickImage, tooltip: 'Add Image', color: Colors.blue),
                          _buildFormatBtn(_isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded, _toggleAudioRecording, tooltip: 'Record Audio', color: _isRecording ? Colors.red : Colors.deepOrange),
                          Container(width: 1, height: 24, color: Colors.grey, margin: const EdgeInsets.symmetric(horizontal: 8)),
                          _buildFormatBtn(Icons.summarize_rounded, _summarizeNoteWithAI, tooltip: 'AI Summary', color: Colors.purple),
                          _buildFormatBtn(Icons.auto_awesome_rounded, _writeWithAI, tooltip: 'Write with AI', color: Colors.indigo),
                          Container(width: 1, height: 24, color: Colors.grey, margin: const EdgeInsets.symmetric(horizontal: 8)),
                          _buildFormatBtn(Icons.text_increase_rounded, () => setState(() => _fontSize += 2), tooltip: 'Increase Font'),
                          _buildFormatBtn(Icons.text_decrease_rounded, () => setState(() => _fontSize > 10 ? _fontSize -= 2 : null), tooltip: 'Decrease Font'),
                        ],
                      ),
                    ),
                  ),

                  // Audio Attachment Indicator
                  if (_audioFilePath != null && !_isRecording)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          const Text('Voice note attached', style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red), constraints: const BoxConstraints(), padding: EdgeInsets.zero, onPressed: () => setState(() => _audioFilePath = null)),
                        ],
                      ),
                    ),

                  // Image Attachment Indicator
                  if (_imageFilePath != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(_imageFilePath!), width: 40, height: 40, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 12),
                          const Text('Image attached', style: TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red), constraints: const BoxConstraints(), padding: EdgeInsets.zero, onPressed: () => setState(() => _imageFilePath = null)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // 2. Previous Notes Section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Previous Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.7))),
                  TextButton(onPressed: _showPreviousNotesBottomSheet, child: const Text('View All'))
                ],
              ),
            ),
            currentUser == null 
              ? const Center(child: Text('Please log in to view notes.'))
              : StreamBuilder<QuerySnapshot>(
                  stream: _notesLimitStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('No notes found. Create your first note above!', style: TextStyle(color: Colors.grey)));

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final title = data['title'] ?? 'Untitled';
                        final content = data['content'] ?? '';
                        final timestamp = data['timestamp'] as Timestamp?;
                        final audioUrl = data['audioUrl'] as String?;
                        final imageUrl = data['imageUrl'] as String?;
                        String dateStr = 'Just now';
                        if (timestamp != null) {
                          dateStr = DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate());
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => NoteDetailScreen(
                                title: title,
                                content: content,
                                date: dateStr,
                                audioUrl: audioUrl,
                                imageUrl: imageUrl,
                              )));
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      if (audioUrl != null)
                                        Icon(Icons.mic_rounded, color: textColor.withOpacity(0.6), size: 20),
                                      if (imageUrl != null)
                                        Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.image_rounded, color: textColor.withOpacity(0.6), size: 20)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: textColor.withOpacity(0.7)),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(dateStr, style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.5), fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                          ),
                        );
                    },
                  );
                  },
                ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveNote,
        label: _isSaving ? const Text('Saving...') : const Text('Save Note'),
        icon: _isSaving 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
            : const Icon(Icons.save_rounded),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildFormatBtn(IconData icon, VoidCallback onTap, {String? tooltip, Color? color}) {
    return IconButton(
      icon: Icon(icon, color: color ?? (_isNoteDarkMode ? Colors.grey.shade300 : Colors.black87)),
      tooltip: tooltip,
      onPressed: onTap,
      splashRadius: 20,
    );
  }
}

// ==========================================
// Note Detail Screen (নোট পড়ার স্ক্রিন)
// ==========================================
class NoteDetailScreen extends StatefulWidget {
  final String title;
  final String content;
  final String date;
  final String? audioUrl;
  final String? imageUrl;

  const NoteDetailScreen({super.key, required this.title, required this.content, required this.date, this.audioUrl, this.imageUrl});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  bool _isNoteDarkMode = false;
  bool _isPlayingAudio = false;
  bool _isPlayingAttachedAudio = false; // User Recorded Audio
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() => _isPlayingAttachedAudio = false);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAttachedAudio() async {
    if (widget.audioUrl == null) return;
    if (_isPlayingAttachedAudio) {
      await _audioPlayer.pause();
      setState(() => _isPlayingAttachedAudio = false);
    } else {
      await _audioPlayer.play(UrlSource(widget.audioUrl!));
      setState(() => _isPlayingAttachedAudio = true);
    }
  }

  void _toggleAudio() {
    setState(() {
      _isPlayingAudio = !_isPlayingAudio;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(_isPlayingAudio ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(_isPlayingAudio ? 'Reading note aloud... (TTS activated)' : 'Audio paused.'),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = _isNoteDarkMode ? const Color(0xFF1E1E1E) : Theme.of(context).colorScheme.surface;
    Color textColor = _isNoteDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(_isNoteDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: 'Toggle Dark Mode',
            onPressed: () => setState(() => _isNoteDarkMode = !_isNoteDarkMode),
          ),
          IconButton(
            icon: Icon(_isPlayingAudio ? Icons.stop_circle_rounded : Icons.record_voice_over_rounded, color: Colors.deepPurple),
            tooltip: 'Read Aloud (TTS)',
            onPressed: _toggleAudio,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: textColor)),
            const SizedBox(height: 8),
            Text(widget.date, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
            Divider(height: 40, color: _isNoteDarkMode ? Colors.grey.shade800 : Colors.grey.shade300),
            // Markdown রেন্ডার করার জন্য Text এর বদলে MarkdownBody ব্যবহার করা হলো
            MarkdownBody(
              data: widget.content,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: TextStyle(fontSize: 18, height: 1.8, color: textColor),
                blockquote: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: textColor.withOpacity(0.8)),
                blockquoteDecoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  border: Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 4)),
                ),
              ),
            ), 
            
            if (widget.imageUrl != null) ...[
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(widget.imageUrl!, fit: BoxFit.cover, width: double.infinity),
              ),
            ],
            
            if (widget.audioUrl != null) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: IconButton(
                        icon: Icon(_isPlayingAttachedAudio ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                        onPressed: _toggleAttachedAudio,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text('Recorded Voice Note', style: TextStyle(fontWeight: FontWeight.bold, color: textColor))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 80), // Fab এর জন্য জায়গা
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // AI Quiz Generator Simulation
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✨ Generating AI Quiz from this note...')));
        },
        icon: const Icon(Icons.quiz_rounded),
        label: const Text('Generate AI Quiz'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ডায়েরির মতো দাগ আঁকার জন্য কাস্টম পেইন্টার
class _LinedPaperPainter extends CustomPainter {
  final double lineHeight;
  final bool isDarkMode;
  _LinedPaperPainter({required this.lineHeight, this.isDarkMode = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300
      ..strokeWidth = 1.0;

    for (double y = lineHeight; y < size.height; y += lineHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// ==========================================
// 7. Study Room Screen (একসাথে পড়া)
// ==========================================
class StudyRoomScreen extends StatefulWidget {
  const StudyRoomScreen({super.key});

  @override
  State<StudyRoomScreen> createState() => _StudyRoomScreenState();
}

class _StudyRoomScreenState extends State<StudyRoomScreen> {
  bool _inRoom = false;
  String _roomCode = '';
  final TextEditingController _joinCodeCtrl = TextEditingController();

  // ডেমো মেম্বার এবং প্রুফ লিস্ট
  final List<Map<String, dynamic>> _members = [
    {'name': 'You (Admin)', 'isMe': true, 'isAdmin': true},
    {'name': 'Sakib', 'isMe': false, 'isAdmin': false},
    {'name': 'Rakib', 'isMe': false, 'isAdmin': false},
  ];
  final List<Map<String, String>> _proofs = [];

  void _createRoom() {
    setState(() {
      _roomCode = 'RM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _inRoom = true;
    });
  }

  void _joinRoom() {
    if (_joinCodeCtrl.text.isNotEmpty) {
      setState(() {
        _roomCode = _joinCodeCtrl.text.trim();
        _inRoom = true;
      });
    }
  }

  void _requestProof(String targetName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Study proof requested from $targetName. Waiting for upload...')),
    );
    
    // ডেমো: ৩ সেকেন্ড পর স্বয়ংক্রিয়ভাবে একটি প্রুফ আসবে
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _proofs.insert(0, {
            'sender': targetName,
            'time': DateFormat('hh:mm a').format(DateTime.now()),
            'image': 'https://via.placeholder.com/150/4F46E5/FFFFFF/?text=Proof', // ডেমো ছবি
          });
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$targetName uploaded a proof!')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Study Partner Room'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _inRoom ? _buildRoomUI() : _buildJoinCreateUI(),
    );
  }

  Widget _buildJoinCreateUI() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_camera_front_rounded, size: 100, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 24),
          Text('Study Together', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Create a room and invite your friends to study together and track progress.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _createRoom,
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Create New Room'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
          const SizedBox(height: 24),
          const Text('OR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 24),
          TextField(
            controller: _joinCodeCtrl,
            decoration: const InputDecoration(labelText: 'Enter Room Code', prefixIcon: Icon(Icons.meeting_room_rounded)),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _joinRoom,
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            child: const Text('Join Room'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Room Header
        Container(
          padding: const EdgeInsets.all(20),
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Room Code', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(_roomCode, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ],
              ),
              IconButton.filled(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _roomCode));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room code copied!')));
                },
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
        ),
        
        // Members List
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text('Active Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        Expanded(
          flex: 1,
          child: ListView.builder(
            itemCount: _members.length,
            itemBuilder: (context, index) {
              final member = _members[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: member['isMe'] ? Colors.green.shade100 : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.person, color: member['isMe'] ? Colors.green : Theme.of(context).colorScheme.primary),
                ),
                title: Text(member['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: member['isAdmin'] ? const Text('Admin', style: TextStyle(fontSize: 12, color: Colors.deepOrange)) : const Text('Member', style: TextStyle(fontSize: 12)),
                trailing: member['isMe'] 
                  ? null 
                  : IconButton(
                      icon: const Icon(Icons.camera_alt_rounded, color: Colors.deepPurpleAccent),
                      tooltip: 'Request Study Proof',
                      onPressed: () => _requestProof(member['name']),
                    ),
              );
            },
          ),
        ),
        
        // Proof Gallery
        const Divider(height: 1),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text('Study Proofs (Last 24h)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        Expanded(
          flex: 1,
          child: _proofs.isEmpty 
            ? const Center(child: Text('No proofs requested/uploaded yet.', style: TextStyle(color: Colors.grey)))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16),
                itemCount: _proofs.length,
                itemBuilder: (context, index) {
                  final proof = _proofs[index];
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(image: NetworkImage(proof['image']!), fit: BoxFit.cover),
                    ),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(proof['sender']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(proof['time']!, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }
}

// ==========================================
// 8. Partner Tasks Screen (পার্টনার অপশন)
// ==========================================
class PartnerTasksScreen extends StatefulWidget {
  const PartnerTasksScreen({super.key});

  @override
  State<PartnerTasksScreen> createState() => _PartnerTasksScreenState();
}

class _PartnerTasksScreenState extends State<PartnerTasksScreen> {
  final List<String> _partners = ['Rakib']; // Max 3 partners
  final List<Task> _sharedTasks = [];

  void _addPartner() {
    if (_partners.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can add maximum 3 partners!')));
      return;
    }
    setState(() {
      _partners.add('New Partner ${_partners.length + 1}');
    });
  }

  void _showAddTaskOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add Shared Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.add_task_rounded, color: Colors.green),
                title: const Text('Create New Task'),
                onTap: () {
                  Navigator.pop(ctx);
                  // ডেমো হিসেবে সরাসরি যুক্ত করা হচ্ছে
                  setState(() {
                    _sharedTasks.add(Task(id: DateTime.now().toString(), title: 'New Shared Task', totalDurationMinutes: 60));
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.import_export_rounded, color: Colors.blue),
                title: const Text('Import from My Tasks'),
                onTap: () {
                  Navigator.pop(ctx);
                  // ডেমো ইমপোর্ট
                  setState(() {
                    _sharedTasks.add(Task(id: DateTime.now().toString(), title: 'Imported: Physics Chapter 2', totalDurationMinutes: 45));
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Partner Tasks'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Partners Header
          Container(
            padding: const EdgeInsets.all(20),
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Study Partners (${_partners.length}/3)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (_partners.length < 3)
                      TextButton.icon(
                        onPressed: _addPartner,
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('Add'),
                      )
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: _partners.map((name) => Chip(
                    avatar: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, size: 16)),
                    label: Text(name),
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    side: BorderSide.none,
                  )).toList(),
                ),
              ],
            ),
          ),
          
          // Shared Tasks List
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('Shared Tasks for the Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Expanded(
            child: _sharedTasks.isEmpty
              ? const Center(child: Text('No shared tasks yet. Add one!', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sharedTasks.length,
                  itemBuilder: (context, index) {
                    final task = _sharedTasks[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.task_alt_rounded, color: Colors.green),
                        title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Target: ${task.totalDurationMinutes} mins'),
                        trailing: const Icon(Icons.more_vert_rounded),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskOptions,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }
}

// ==========================================
// 5. Calculator Screen (ক্যালকুলেটর স্ক্রিন)
// ==========================================
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _equation = "";
  String _result = "0";
  bool _shouldReset = false;

  void _buttonPressed(String buttonText) {
    setState(() {
      if (buttonText == "AC") {
        _equation = "";
        _result = "0";
        _shouldReset = false;
      } else if (buttonText == "⌫") {
        if (_shouldReset) {
          _equation = "";
          _shouldReset = false;
        } else if (_equation.isNotEmpty) {
          _equation = _equation.substring(0, _equation.length - 1);
        }
        _updateLiveResult();
      } else if (buttonText == "=") {
        if (_equation.isNotEmpty) {
          _result = _evaluateEquation(_equation);
          _equation = _result;
          _shouldReset = true;
        }
      } else if (buttonText == "%") {
        if (_shouldReset) {
          _equation = _result;
          _shouldReset = false;
        }
        if (_equation.isNotEmpty && !_isOperator(_equation[_equation.length - 1])) {
          _equation += "%";
        }
        _updateLiveResult();
      } else if (buttonText == "+/-") {
        if (_shouldReset) {
          _equation = _result;
          _shouldReset = false;
        }
        _toggleSign();
        _updateLiveResult();
      } else if (_isOperator(buttonText)) {
        if (_shouldReset) {
          _equation = _result;
          _shouldReset = false;
        }
        if (_equation.isEmpty) {
          if (buttonText == "-") {
            _equation = "-";
          }
        } else {
          String lastChar = _equation[_equation.length - 1];
          if (_isOperator(lastChar)) {
            // Replace last operator
            _equation = _equation.substring(0, _equation.length - 1) + buttonText;
          } else {
            _equation += buttonText;
          }
        }
      } else {
        // Numbers and dots
        if (_shouldReset) {
          _equation = "";
          _shouldReset = false;
        }
        if (buttonText == ".") {
          if (_equation.isEmpty) {
            _equation = "0.";
          } else {
            String lastChar = _equation[_equation.length - 1];
            if (_isOperator(lastChar)) {
              _equation += "0.";
            } else {
              // Check if the current number segment already has a dot
              List<String> parts = _equation.split(RegExp(r'[+\-×÷]'));
              if (parts.isNotEmpty && !parts.last.contains('.')) {
                _equation += ".";
              }
            }
          }
        } else {
          _equation += buttonText;
        }
        _updateLiveResult();
      }
    });
  }

  bool _isOperator(String char) {
    return char == "+" || char == "-" || char == "×" || char == "÷";
  }

  void _toggleSign() {
    if (_equation.isEmpty) return;
    // Find last number starting point
    int i = _equation.length - 1;
    while (i >= 0 && !_isOperator(_equation[i])) {
      i--;
    }
    if (i < 0) {
      // Entire equation is a number, toggle negative sign
      if (_equation.startsWith("-")) {
        _equation = _equation.substring(1);
      } else {
        _equation = "-$_equation";
      }
    } else if (i == 0 && _equation[0] == "-") {
      _equation = _equation.substring(1);
    } else {
      // Toggle sign of last number segment
      String op = _equation[i];
      String left = _equation.substring(0, i);
      String right = _equation.substring(i + 1);
      if (op == "+") {
        _equation = "$left-$right";
      } else if (op == "-") {
        if (i == 0 || _isOperator(_equation[i - 1])) {
          _equation = left + right; // remove negative
        } else {
          _equation = "$left+$right";
        }
      } else {
        // For * or /, toggle negative sign for the right number
        if (right.startsWith("-")) {
          _equation = "$left$op${right.substring(1)}";
        } else {
          _equation = "$left$op-$right";
        }
      }
    }
  }

  void _updateLiveResult() {
    if (_equation.isEmpty) {
      _result = "0";
      return;
    }
    // Only evaluate if last character is not an operator to avoid syntax error
    String lastChar = _equation[_equation.length - 1];
    if (!_isOperator(lastChar)) {
      String eval = _evaluateEquation(_equation);
      if (eval != "Error") {
        _result = eval;
      }
    }
  }

  String _evaluateEquation(String expr) {
    try {
      if (expr.isEmpty) return "0";
      // Sanitize equation: replace view operators with math operators
      String sanitized = expr.replaceAll('×', '*').replaceAll('÷', '/');
      
      // Parse tokens
      List<String> tokens = [];
      String numberBuffer = "";
      
      for (int i = 0; i < sanitized.length; i++) {
        String c = sanitized[i];
        if (c == '-' && (i == 0 || tokens.isEmpty || "+*/".contains(tokens.last))) {
          // Negative sign prefix, not subtraction
          numberBuffer += c;
        } else if ("+*/".contains(c) || (c == '-' && !"+*/".contains(tokens.last))) {
          if (numberBuffer.isNotEmpty) {
            tokens.add(numberBuffer);
            numberBuffer = "";
          }
          tokens.add(c);
        } else {
          numberBuffer += c;
        }
      }
      if (numberBuffer.isNotEmpty) {
        tokens.add(numberBuffer);
      }

      // Convert percentages (e.g. 50% -> 0.5)
      for (int i = 0; i < tokens.length; i++) {
        if (tokens[i].endsWith('%')) {
          String valStr = tokens[i].substring(0, tokens[i].length - 1);
          double val = double.parse(valStr) / 100.0;
          tokens[i] = val.toString();
        }
      }

      // First pass: multiplication and division (DMAS rule)
      List<String> pass1 = [];
      int idx = 0;
      while (idx < tokens.length) {
        String token = tokens[idx];
        if (token == "*" || token == "/") {
          double left = double.parse(pass1.removeLast());
          double right = double.parse(tokens[idx + 1]);
          double res = (token == "*") ? left * right : left / right;
          pass1.add(res.toString());
          idx += 2;
        } else {
          pass1.add(token);
          idx++;
        }
      }

      // Second pass: addition and subtraction
      double total = double.parse(pass1[0]);
      idx = 1;
      while (idx < pass1.length) {
        String op = pass1[idx];
        double right = double.parse(pass1[idx + 1]);
        if (op == "+") {
          total += right;
        } else if (op == "-") {
          total -= right;
        }
        idx += 2;
      }

      // Formatting response
      if (total.isInfinite || total.isNaN) return "Error";
      if (total == total.toInt()) {
        return total.toInt().toString();
      }
      // Trim scientific zeros
      String formatted = total.toStringAsFixed(10);
      if (formatted.contains('.')) {
        formatted = formatted.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
      }
      return formatted;
    } catch (e) {
      return "Error";
    }
  }

  Widget _buildButton(String text, {Color? textColor, Color? bgColor, int flex = 1}) {
    final bool isOp = _isOperator(text) || text == "=";
    final bool isSpecial = text == "AC" || text == "⌫" || text == "%" || text == "+/-";
    
    Color defaultBg = isOp 
        ? const Color(0xFFFF9F0A) // standard iOS gold-orange
        : isSpecial 
            ? const Color(0xFFA5A5A5) // light gray
            : const Color(0xFF333333); // dark gray
            
    Color defaultTextColor = isSpecial ? Colors.black : Colors.white;

    return Expanded(
      flex: flex,
      child: Container(
        margin: const EdgeInsets.all(6),
        child: AspectRatio(
          aspectRatio: flex == 1 ? 1 : 2.1,
          child: ElevatedButton(
            onPressed: () => _buttonPressed(text),
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor ?? defaultBg,
              foregroundColor: textColor ?? defaultTextColor,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
            ),
            child: Text(
              text, 
              style: TextStyle(
                fontSize: text.length > 1 && text != "+/-" ? 20 : 26, 
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Sleek Premium dark aesthetic
      appBar: AppBar(
        title: const Text('Calculator', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, 
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Display Area
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                alignment: Alignment.bottomRight,
                child: SingleChildScrollView(
                  reverse: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _equation.isEmpty ? "0" : _equation, 
                        style: const TextStyle(fontSize: 36, color: Colors.white54, fontFamily: 'monospace'),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _result, 
                          style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w300, color: Colors.white, fontFamily: 'monospace'),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Keypad Layout (International standard calculator layout)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
              child: Column(
                children: [
                  Row(children: [
                    _buildButton('AC'),
                    _buildButton('+/-'),
                    _buildButton('%'),
                    _buildButton('÷'),
                  ]),
                  Row(children: [
                    _buildButton('7'),
                    _buildButton('8'),
                    _buildButton('9'),
                    _buildButton('×'),
                  ]),
                  Row(children: [
                    _buildButton('4'),
                    _buildButton('5'),
                    _buildButton('6'),
                    _buildButton('-'),
                  ]),
                  Row(children: [
                    _buildButton('1'),
                    _buildButton('2'),
                    _buildButton('3'),
                    _buildButton('+'),
                  ]),
                  Row(children: [
                    _buildButton('0', flex: 2),
                    _buildButton('.'),
                    _buildButton('='),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 6. Stopwatch & Timer Screen (স্টপওয়াচ ও টাইমার)
// ==========================================
class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Stopwatch Variables
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _stopwatchTimer;
  final List<String> _laps = [];

  // Timer (Countdown) Variables
  int _selectedTimerSeconds = 0;
  int _remainingTimerSeconds = 0;
  bool _isTimerRunning = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _stopwatchTimer?.cancel();
    _countdownTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // --- Stopwatch Logic ---
  void _toggleStopwatch() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _stopwatchTimer?.cancel();
    } else {
      _stopwatch.start();
      _stopwatchTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
        if (mounted) setState(() {});
      });
    }
    setState(() {});
  }

  void _stopwatchAction() {
    if (_stopwatch.isRunning) {
      // Lap
      setState(() {
        _laps.insert(0, _formatStopwatchTime(_stopwatch.elapsedMilliseconds));
      });
    } else {
      // Reset
      setState(() {
        _stopwatch.reset();
        _laps.clear();
      });
    }
  }

  String _formatStopwatchTime(int milliseconds) {
    int hundreds = (milliseconds / 10).truncate() % 100;
    int seconds = (milliseconds / 1000).truncate() % 60;
    int minutes = (milliseconds / (1000 * 60)).truncate() % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${hundreds.toString().padLeft(2, '0')}';
  }

  // --- Countdown Timer Logic ---
  void _startCountdown() {
    if (_selectedTimerSeconds == 0) return;
    setState(() {
      _isTimerRunning = true;
      if (_remainingTimerSeconds == 0) _remainingTimerSeconds = _selectedTimerSeconds;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTimerSeconds > 0) {
        setState(() => _remainingTimerSeconds--);
      } else {
        _stopCountdown();
        _triggerAlarm();
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    setState(() => _isTimerRunning = false);
  }

  void _resetCountdown() {
    _stopCountdown();
    setState(() => _remainingTimerSeconds = 0);
  }

  void _triggerAlarm() {
    HapticFeedback.vibrate();
    SystemSound.play(SystemSoundType.alert);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⏰ Alarm!', textAlign: TextAlign.center),
        content: const Text('Your countdown timer has finished.', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Stop Alarm')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Stopwatch & Timer'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [Tab(text: 'Stopwatch'), Tab(text: 'Countdown')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Stopwatch
          Column(
            children: [
              const SizedBox(height: 60),
              Text(_formatStopwatchTime(_stopwatch.elapsedMilliseconds), style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w300, fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    heroTag: 'lap_reset',
                    onPressed: _stopwatchAction,
                    backgroundColor: Colors.grey.shade300,
                    elevation: 0,
                    child: Icon(_stopwatch.isRunning ? Icons.flag_rounded : Icons.refresh_rounded, color: Colors.black87),
                  ),
                  const SizedBox(width: 40),
                  FloatingActionButton.large(
                    heroTag: 'start_stop',
                    onPressed: _toggleStopwatch,
                    backgroundColor: _stopwatch.isRunning ? Colors.redAccent : Colors.green.shade600,
                    elevation: 2,
                    child: Icon(_stopwatch.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 36),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Expanded(
                child: ListView.builder(
                  itemCount: _laps.length,
                  itemBuilder: (ctx, i) => ListTile(
                    leading: Text('Lap ${_laps.length - i}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    trailing: Text(_laps[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ),
              ),
            ],
          ),

          // TAB 2: Countdown Timer
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isTimerRunning && _remainingTimerSeconds == 0)
                SizedBox(
                  height: 200,
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hms,
                    onTimerDurationChanged: (Duration newDuration) {
                      _selectedTimerSeconds = newDuration.inSeconds;
                    },
                  ),
                )
              else
                Text(
                  '${(_remainingTimerSeconds ~/ 3600).toString().padLeft(2, '0')}:${((_remainingTimerSeconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(_remainingTimerSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w300, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              const SizedBox(height: 60),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_remainingTimerSeconds > 0)
                    FloatingActionButton(
                      heroTag: 'timer_cancel',
                      onPressed: _resetCountdown,
                      backgroundColor: Colors.grey.shade300,
                      elevation: 0,
                      child: const Icon(Icons.close_rounded, color: Colors.black87),
                    ),
                  if (_remainingTimerSeconds > 0) const SizedBox(width: 40),
                  FloatingActionButton.large(
                    heroTag: 'timer_start_pause',
                    onPressed: _isTimerRunning ? _stopCountdown : _startCountdown,
                    backgroundColor: _isTimerRunning ? Colors.redAccent : Colors.green.shade600,
                    elevation: 2,
                    child: Icon(_isTimerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 36),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. Pomodoro Timer Screen
// ==========================================
class PomodoroTimerScreen extends StatefulWidget {
  const PomodoroTimerScreen({super.key});

  @override
  State<PomodoroTimerScreen> createState() => _PomodoroTimerScreenState();
}

class _PomodoroTimerScreenState extends State<PomodoroTimerScreen> {
  static const int focusMinutes = 25;
  static const int shortBreakMinutes = 5;
  static const int longBreakMinutes = 15;

  int _selectedDuration = focusMinutes * 60; // সেকেন্ডে কনভার্ট করা হলো
  int _remainingSeconds = focusMinutes * 60;
  bool _isRunning = false;
  Timer? _timer;
  String _currentMode = 'Focus'; // Focus, Short Break, Long Break

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setMode(String mode, int minutes) {
    _timer?.cancel();
    setState(() {
      _currentMode = mode;
      _selectedDuration = minutes * 60;
      _remainingSeconds = _selectedDuration;
      _isRunning = false;
    });
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          setState(() => _remainingSeconds--);
        } else {
          _timer?.cancel();
          setState(() => _isRunning = false);
          _onTimerComplete(); // সময় শেষ হলে অ্যালার্ম
        }
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = _selectedDuration;
      _isRunning = false;
    });
  }

  void _onTimerComplete() {
    // অ্যালার্ম সাউন্ড এবং ভাইব্রেশন
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('⏰ Time is up!', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          _currentMode == 'Focus'
              ? 'Great job! You have completed a 25-minute focus session. Take a break now.'
              : 'Break is over. Ready to focus again?',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (_currentMode == 'Focus') {
                _setMode('Short Break', shortBreakMinutes); // ফোকাস শেষে শর্ট ব্রেক
              } else {
                _setMode('Focus', focusMinutes); // ব্রেক শেষে আবার ফোকাস
              }
            },
            child: const Text('Continue'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int minutes = _remainingSeconds ~/ 60;
    int seconds = _remainingSeconds % 60;
    String timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    double progress = _remainingSeconds / _selectedDuration;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Pomodoro Timer', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mode Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildModeButton('Focus', focusMinutes),
              _buildModeButton('Short Break', shortBreakMinutes),
              _buildModeButton('Long Break', longBreakMinutes),
            ],
          ),
          const SizedBox(height: 60),
          
          // Circular Timer
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 250,
                height: 250,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: Colors.grey.shade200,
                  color: _currentMode == 'Focus' ? Colors.redAccent : Colors.teal,
                ),
              ),
              Text(
                timeString,
                style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ],
          ),
          const SizedBox(height: 60),
          
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _resetTimer,
                icon: const Icon(Icons.refresh_rounded, size: 36, color: Colors.grey),
              ),
              const SizedBox(width: 24),
              FloatingActionButton.large(
                onPressed: _toggleTimer,
                backgroundColor: _currentMode == 'Focus' ? Colors.redAccent : Colors.teal,
                elevation: 4,
                child: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String title, int minutes) {
    bool isSelected = _currentMode == title;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        selected: isSelected,
        onSelected: (selected) {
          if (selected && !_isRunning) _setMode(title, minutes);
        },
        selectedColor: (title == 'Focus' ? Colors.redAccent : Colors.teal).withValues(alpha: 0.2),
        labelStyle: TextStyle(color: isSelected ? (title == 'Focus' ? Colors.red : Colors.teal.shade700) : Colors.grey),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

// ==========================================
// 1. Mood Tracker Bottom Sheet
// ==========================================
class MoodTrackerBottomSheet extends StatefulWidget {
  const MoodTrackerBottomSheet({super.key});
  @override
  State<MoodTrackerBottomSheet> createState() => _MoodTrackerBottomSheetState();
}

class _MoodTrackerBottomSheetState extends State<MoodTrackerBottomSheet> {
  final List<Map<String, String>> moods = [
    {'emoji': '😁', 'label': 'Great'},
    {'emoji': '😊', 'label': 'Good'},
    {'emoji': '😐', 'label': 'Okay'},
    {'emoji': '😔', 'label': 'Sad'},
    {'emoji': '😫', 'label': 'Stressed'},
  ];
  int _selectedMoodIndex = -1;
  final TextEditingController _noteController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('How are you feeling?', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(moods.length, (index) {
              final isSelected = _selectedMoodIndex == index;
              return GestureDetector(
                onTap: () => setState(() => _selectedMoodIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(moods[index]['emoji']!, style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 4),
                      Text(moods[index]['label']!, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey)),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Add a quick note (Optional)', prefixIcon: Icon(Icons.edit_note_rounded)),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context); // বর্তমান শিট বন্ধ করে হিস্ট্রি শিট ওপেন করবে
              showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const MoodHistoryBottomSheet());
            },
            icon: const Icon(Icons.history_rounded),
            label: const Text('View Mood History'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              if (_selectedMoodIndex == -1) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a mood!')));
                return;
              }
              
              final User? user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('moods').add({
                  'emoji': moods[_selectedMoodIndex]['emoji'],
                  'label': moods[_selectedMoodIndex]['label'],
                  'note': _noteController.text.trim(),
                  'timestamp': FieldValue.serverTimestamp(),
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mood saved successfully!')));
                  Navigator.pop(context);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in first.')));
              }
            },
            child: const Text('Save Mood'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1.A Mood History Bottom Sheet
// ==========================================
class MoodHistoryBottomSheet extends StatelessWidget {
  const MoodHistoryBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mood History', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: user == null
                ? const Center(child: Text("Please log in to view history"))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('moods')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text("No mood history yet.", style: TextStyle(color: Colors.grey)));
                      }

                      // ডাটা গ্রুপিং লজিক (Today, Yesterday, বা Month অনুযায়ী)
                      Map<String, List<Map<String, dynamic>>> historyData = {};
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final yesterday = today.subtract(const Duration(days: 1));

                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final timestamp = data['timestamp'] as Timestamp?;
                        if (timestamp == null) continue;
                        
                        final date = timestamp.toDate();
                        final dateOnly = DateTime(date.year, date.month, date.day);

                        String groupKey;
                        if (dateOnly == today) {
                          groupKey = 'Today';
                        } else if (dateOnly == yesterday) {
                          groupKey = 'Yesterday';
                        } else {
                          groupKey = DateFormat('MMMM yyyy').format(date); // e.g. October 2023
                        }

                        if (!historyData.containsKey(groupKey)) {
                          historyData[groupKey] = [];
                        }
                        
                        historyData[groupKey]!.add({
                          'date': DateFormat('MMM d, h:mm a').format(date),
                          'emoji': data['emoji'] ?? '',
                          'note': data['note'] ?? '',
                        });
                      }

                      return ListView.builder(
                        itemCount: historyData.keys.length,
                        itemBuilder: (context, index) {
                          String section = historyData.keys.elementAt(index);
                          List<Map<String, dynamic>> items = historyData[section]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(section, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              ),
                              ...items.map((item) => Card(
                                    child: ListTile(
                                      leading: Text(item['emoji'], style: const TextStyle(fontSize: 28)),
                                      title: Text(item['date'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      subtitle: item['note'].toString().isNotEmpty
                                          ? Text(item['note'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87))
                                          : null,
                                    ),
                                  )),
                              const SizedBox(height: 16),
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 2. Breathing Exercise Bottom Sheet
// ==========================================
class BreathingExerciseBottomSheet extends StatelessWidget {
  const BreathingExerciseBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final patterns = [
      {'title': '4-7-8 Relaxing Breath', 'desc': 'Inhale 4s, Hold 7s, Exhale 8s.', 'icon': Icons.self_improvement_rounded, 'phases': [4, 7, 8, 0]},
      {'title': 'Box Breathing', 'desc': 'Inhale 4s, Hold 4s, Exhale 4s, Hold 4s.', 'icon': Icons.crop_square_rounded, 'phases': [4, 4, 4, 4]},
      {'title': 'Equal Breathing', 'desc': 'Inhale 5s, Exhale 5s.', 'icon': Icons.balance_rounded, 'phases': [5, 0, 5, 0]},
      {'title': 'Deep Calm', 'desc': 'Inhale 4s, Exhale 6s.', 'icon': Icons.waves_rounded, 'phases': [4, 0, 6, 0]},
    ];

    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Breathing Exercises', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.lightBlue)),
          const SizedBox(height: 8),
          const Text('Choose a pattern to boost your focus and calm your mind.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: patterns.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.lightBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(patterns[index]['icon'] as IconData, color: Colors.lightBlue),
                    ),
                    title: Text(patterns[index]['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(patterns[index]['desc'] as String, style: const TextStyle(height: 1.4)),
                    trailing: const Icon(Icons.play_circle_fill_rounded, color: Colors.lightBlue, size: 32),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BreathingPlayerScreen(
                        title: patterns[index]['title'] as String,
                        phases: patterns[index]['phases'] as List<int>,
                      )));
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 2.A Interactive Breathing Player Screen
// ==========================================
class BreathingPlayerScreen extends StatefulWidget {
  final String title;
  final List<int> phases; // Format: [Inhale, Hold, Exhale, Hold]

  const BreathingPlayerScreen({super.key, required this.title, required this.phases});

  @override
  State<BreathingPlayerScreen> createState() => _BreathingPlayerScreenState();
}

class _BreathingPlayerScreenState extends State<BreathingPlayerScreen> with SingleTickerProviderStateMixin {
  bool _isRunning = false;
  int _phaseIndex = 0; // 0: Inhale, 1: Hold, 2: Exhale, 3: Hold
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
    _animationController.addStatusListener((status) {
      if (!_isRunning || !mounted) return;
      
      bool phaseCompleted = false;
      if (_phaseIndex == 2) {
        // Exhale phase runs in reverse, so it completes when it reaches 0.0 (dismissed)
        if (status == AnimationStatus.dismissed) {
          phaseCompleted = true;
        }
      } else {
        // Other phases run forward, so they complete when they reach 1.0 (completed)
        if (status == AnimationStatus.completed) {
          phaseCompleted = true;
        }
      }

      if (phaseCompleted) {
        _advancePhase();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleBreathing() {
    if (_isRunning) {
      setState(() {
        _isRunning = false;
        _phaseIndex = 0;
      });
      _animationController.stop();
      _animationController.value = 0.0;
    } else {
      setState(() {
        _isRunning = true;
        _phaseIndex = 0;
      });
      _startPhase();
    }
  }

  void _startPhase() {
    if (!_isRunning || !mounted) return;

    int duration = widget.phases[_phaseIndex];
    if (duration <= 0) {
      // Use microtask to break synchronous recursion
      Future.microtask(() {
        if (mounted && _isRunning) {
          _advancePhase();
        }
      });
      return;
    }

    _animationController.duration = Duration(seconds: duration);

    if (_phaseIndex == 0) {
      // Inhale: Animate forward from 0.0 to 1.0
      _animationController.forward(from: 0.0);
    } else if (_phaseIndex == 1) {
      // Hold after Inhale: Animate forward from 0.0 to 1.0
      _animationController.forward(from: 0.0);
    } else if (_phaseIndex == 2) {
      // Exhale: Animate backward from 1.0 to 0.0
      _animationController.reverse(from: 1.0);
    } else if (_phaseIndex == 3) {
      // Hold after Exhale: Animate forward from 0.0 to 1.0
      _animationController.forward(from: 0.0);
    }
    setState(() {});
  }

  void _advancePhase() {
    if (!_isRunning || !mounted) return;
    setState(() {
      _phaseIndex = (_phaseIndex + 1) % 4;
    });
    _startPhase();
  }

  String get _currentInstruction {
    if (!_isRunning) return 'Ready?';
    switch (_phaseIndex) {
      case 0: return 'Inhale';
      case 1: return 'Hold';
      case 2: return 'Exhale';
      case 3: return 'Hold';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark relaxing background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Breathing Circle with Glowing Progress Ring
            SizedBox(
              height: 320,
              width: 320,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  double scale = 1.0;
                  if (_isRunning) {
                    if (_phaseIndex == 0) {
                      scale = 1.0 + (_animationController.value * 1.2);
                    } else if (_phaseIndex == 1) {
                      scale = 2.2;
                    } else if (_phaseIndex == 2) {
                      scale = 1.0 + (_animationController.value * 1.2);
                    } else if (_phaseIndex == 3) {
                      scale = 1.0;
                    }
                  }

                  double progress = 0.0;
                  Color ringColor = Colors.lightBlueAccent;
                  bool isReversed = false;

                  if (_isRunning) {
                    if (_phaseIndex == 0) {
                      progress = _animationController.value;
                      ringColor = Colors.cyanAccent;
                      isReversed = false;
                    } else if (_phaseIndex == 1) {
                      progress = 1.0; // Static filled circle during Hold
                      ringColor = Colors.purpleAccent;
                      isReversed = false;
                    } else if (_phaseIndex == 2) {
                      progress = 1.0 - _animationController.value; // Grow counter-clockwise from empty to full during exhale
                      ringColor = Colors.tealAccent;
                      isReversed = true; // Backward motion!
                    } else if (_phaseIndex == 3) {
                      progress = 0.0; // Static empty circle during Hold
                      ringColor = Colors.amberAccent;
                      isReversed = false;
                    }
                  }

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // 1. Glowing Circular Progress Ring
                      SizedBox(
                        width: 280,
                        height: 280,
                        child: CustomPaint(
                          painter: _GlowingProgressPainter(
                            progress: progress,
                            color: ringColor,
                            isReversed: isReversed,
                          ),
                        ),
                      ),
                      
                      // 2. Breathing Bubble
                      Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                ringColor.withValues(alpha: 0.6),
                                ringColor.withValues(alpha: 0.1),
                              ],
                            ),
                            border: Border.all(color: ringColor.withValues(alpha: 0.8), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: ringColor.withValues(alpha: 0.3),
                                blurRadius: 15,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 40),
            // Instruction Text
            Text(
              _currentInstruction,
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w300, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            // Seconds Counter
            if (_isRunning)
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, _) {
                  int duration = widget.phases[_phaseIndex];
                  double elapsed = _animationController.value * duration;
                  int remaining = (duration - elapsed).ceil();
                  if (remaining < 0) remaining = 0;
                  return Text(
                    '${remaining}s',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 24, fontWeight: FontWeight.w200),
                  );
                }
              ),
            const SizedBox(height: 40),
            // Play / Stop Button
            FloatingActionButton.large(
              onPressed: _toggleBreathing,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              elevation: 0,
              child: Icon(_isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 40),
            ),
          ],
        ),
      ),
    );
  }
}

// Glowing progress indicator painter for Breathing exercises
class _GlowingProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isReversed;

  _GlowingProgressPainter({
    required this.progress,
    required this.color,
    this.isReversed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;

    // 1. Draw background faint circle
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0) return;

    // 2. Draw glowing shadow layer
    final shadowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

    // 3. Draw active progress arc
    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress * (isReversed ? -1 : 1);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      shadowPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GlowingProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.isReversed != isReversed;
  }
}

// ==========================================
// 3. Routine Planner Bottom Sheet
// ==========================================
class RoutinePlannerBottomSheet extends StatefulWidget {
  const RoutinePlannerBottomSheet({super.key});
  @override
  State<RoutinePlannerBottomSheet> createState() => _RoutinePlannerBottomSheetState();
}

class _RoutinePlannerBottomSheetState extends State<RoutinePlannerBottomSheet> {
  DateTime? _selectedDate;
  final TextEditingController _nextTaskCtrl = TextEditingController();
  final TextEditingController _weeklyTaskCtrl = TextEditingController();
  
  List<String> _nextTasks = [];
  String _selectedDay = 'Saturday';
  final List<String> _days = ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  
  // Dummy storage for weekly routine
  final Map<String, List<String>> _weeklyRoutine = {
    'Saturday': [], 'Sunday': [], 'Monday': [], 'Tuesday': [], 'Wednesday': [], 'Thursday': [], 'Friday': [],
  };

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _showWeeklyPreview() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.calendar_view_week_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Weekly Preview', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _days.length,
            itemBuilder: (context, index) {
              String day = _days[index];
              List<String> tasks = _weeklyRoutine[day]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(day, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    if (tasks.isEmpty) const Text('- No tasks set', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                    ...tasks.map((t) => Text('• $t')),
                    const Divider(),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return DefaultTabController(
      length: 2,
      child: Container(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.only(top: 24, bottom: bottomInset),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          children: [
            Text('Routine Planner', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 16),
            const TabBar(
              tabs: [
                Tab(text: 'Next Routine'),
                Tab(text: 'Weekly Routine'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // TAB 1: Next Routine
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _selectDate,
                          icon: const Icon(Icons.calendar_today_rounded),
                          label: Text(_selectedDate == null ? 'Select Date' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nextTaskCtrl,
                                decoration: const InputDecoration(labelText: 'Task Name (e.g. Read Physics)'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: () {
                                if (_nextTaskCtrl.text.isNotEmpty) {
                                  setState(() {
                                    _nextTasks.add(_nextTaskCtrl.text);
                                    _nextTaskCtrl.clear();
                                  });
                                }
                              },
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('Tasks added:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _nextTasks.length,
                            itemBuilder: (ctx, i) => ListTile(
                              leading: const Icon(Icons.check_circle_outline),
                              title: Text(_nextTasks[i]),
                              trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _nextTasks.removeAt(i))),
                            ),
                          ),
                        ),
                        ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Save Routine')),
                      ],
                    ),
                  ),
                  // TAB 2: Weekly Routine
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedDay,
                          items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                          onChanged: (val) => setState(() => _selectedDay = val!),
                          decoration: const InputDecoration(labelText: 'Select Day'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _weeklyTaskCtrl,
                                decoration: const InputDecoration(labelText: 'Add Task for selected day'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: () {
                                if (_weeklyTaskCtrl.text.isNotEmpty) {
                                  setState(() {
                                    _weeklyRoutine[_selectedDay]!.add(_weeklyTaskCtrl.text);
                                    _weeklyTaskCtrl.clear();
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to weekly routine!')));
                                }
                              },
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: _showWeeklyPreview,
                          icon: const Icon(Icons.visibility_rounded),
                          label: const Text('Preview Week'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Save Weekly Routine')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
  final TextEditingController _daysController = TextEditingController();
  String? _geminiApiKey;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  List<Task> _generatedTasks = [];

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  @override
  void dispose() {
    _daysController.dispose();
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

    final promptContext = 'Subjects/topics: $goals. Total study hours: $_studyHours hours. Days remaining: ${_daysController.text.trim().isEmpty ? "unspecified" : _daysController.text.trim()}.';

    List<Map<String, dynamic>> rawTasks = [];
    try {
      rawTasks = await AIService.generateStudyPlan(promptContext, _geminiApiKey);
    } catch (e) {
      debugPrint('Error generating study plan with Gemini: $e');
    }

    int totalMinutes = (_studyHours * 60).toInt();
    DateTime currentTime = DateTime.now();
    List<Task> tempTasks = [];

    if (rawTasks.isNotEmpty) {
      for (int i = 0; i < rawTasks.length; i++) {
        var rawTask = rawTasks[i];
        final String title = rawTask['title'] ?? 'Study Session';
        final String category = rawTask['category'] ?? 'Study';
        final int duration = rawTask['durationMinutes'] ?? (totalMinutes ~/ rawTasks.length);
        
        DateTime taskEndTime = currentTime.add(Duration(minutes: duration));
        
        tempTasks.add(Task(
          id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
          title: title,
          subject: _subjects[0].nameCtrl.text.trim(),
          notes: 'AI generated study plan task',
          startTime: currentTime,
          endTime: taskEndTime,
          totalDurationMinutes: duration,
          category: category,
        ));
        
        if (i < rawTasks.length - 1) {
          currentTime = taskEndTime.add(const Duration(minutes: 10)); 
        }
      }
    } else {
      // Local fallback logic
      int timePerSubject = totalMinutes ~/ _subjects.length;
      for (int i = 0; i < _subjects.length; i++) {
        var sub = _subjects[i];
        DateTime taskEndTime = currentTime.add(Duration(minutes: timePerSubject));
        
        tempTasks.add(Task(
          id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
          title: sub.nameCtrl.text.trim(),
          subject: sub.nameCtrl.text.trim(),
          notes: 'Topic: ${sub.topicCtrl.text.trim().isEmpty ? "General review" : sub.topicCtrl.text.trim()}',
          startTime: currentTime,
          endTime: taskEndTime,
          totalDurationMinutes: timePerSubject,
          category: 'AI Planned',
        ));
        
        if (i < _subjects.length - 1) {
          currentTime = taskEndTime.add(const Duration(minutes: 10)); 
        }
      }
    }

    setState(() {
      _generatedTasks = tempTasks;
      _step = 3;
    });
  }

  void _recalculateTimeline() {
    if (_generatedTasks.isEmpty) return;
    DateTime currentTime = _generatedTasks.first.startTime ?? DateTime.now();
    for (int i = 0; i < _generatedTasks.length; i++) {
      var task = _generatedTasks[i];
      DateTime taskEndTime = currentTime.add(Duration(minutes: task.totalDurationMinutes));
      _generatedTasks[i] = task.copyWith(
        startTime: currentTime,
        endTime: taskEndTime,
      );
      if (i < _generatedTasks.length - 1) {
        currentTime = taskEndTime.add(const Duration(minutes: 10));
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
          const SizedBox(height: 16),
          TextField(
            controller: _daysController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Days until Exam (Optional)', prefixIcon: Icon(Icons.calendar_today_rounded)),
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

// ==========================================
// Premium Theme Customizer Bottom Sheet
// ==========================================
class ThemeCustomizerBottomSheet extends StatelessWidget {
  const ThemeCustomizerBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();

    final List<Map<String, dynamic>> themes = [
      {
        'type': AppThemeType.light,
        'name': 'Slate Minimal',
        'desc': 'Clean, crisp and high-contrast light theme.',
        'primary': const Color(0xFF4F46E5),
        'surface': const Color(0xFFF8FAFC),
        'accent': const Color(0xFF0EA5E9),
        'isDark': false,
      },
      {
        'type': AppThemeType.dark,
        'name': 'Midnight Indigo',
        'desc': 'Relaxing dark theme with indigo accents.',
        'primary': const Color(0xFF818CF8),
        'surface': const Color(0xFF0F172A),
        'accent': const Color(0xFF38BDF8),
        'isDark': true,
      },
      {
        'type': AppThemeType.aurora,
        'name': 'Aurora Dream',
        'desc': 'Emerald green tones for visual relaxation.',
        'primary': const Color(0xFF10B981),
        'surface': const Color(0xFF06231A),
        'accent': const Color(0xFF34D399),
        'isDark': true,
      },
      {
        'type': AppThemeType.ocean,
        'name': 'Ocean Blues',
        'desc': 'Deep sapphire blue that improves focus.',
        'primary': const Color(0xFF38BDF8),
        'surface': const Color(0xFF0F1E36),
        'accent': const Color(0xFF60A5FA),
        'isDark': true,
      },
      {
        'type': AppThemeType.sunset,
        'name': 'Sunset Velvet',
        'desc': 'Warm sunset colors that stimulate memory.',
        'primary': const Color(0xFFF43F5E),
        'surface': const Color(0xFF241216),
        'accent': const Color(0xFFF59E0B),
        'isDark': true,
      },
    ];

    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, _) {
        final currentTheme = themeManager.currentTheme;
        final theme = Theme.of(context);

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pull Bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.palette_rounded, color: theme.colorScheme.primary, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'Premium Theme Customizer',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a custom theme to personalize your study environment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 20),
  
                // Theme List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: themes.length,
                  itemBuilder: (context, index) {
                    final t = themes[index];
                    final isSelected = currentTheme == t['type'];
  
                    return GestureDetector(
                      onTap: () {
                        themeManager.setTheme(t['type']);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? theme.colorScheme.primary.withValues(alpha: 0.08) 
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected 
                                ? theme.colorScheme.primary 
                                : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Color Preview Palette
                            Container(
                              width: 50,
                              height: 30,
                              decoration: BoxDecoration(
                                color: t['surface'],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: t['primary'], shape: BoxShape.circle),
                                  ),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: t['accent'], shape: BoxShape.circle),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
  
                            // Text Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t['name'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    t['desc'],
                                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
  
                            // Checkbox Indicator
                            if (isSelected)
                              Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                            else
                              Icon(Icons.radio_button_off_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 16),
  
                // Font Style Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.font_download_rounded, color: theme.colorScheme.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'App Font Style',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
  
                // Font Style Row Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildFontOptionCard(
                        context, 
                        themeManager, 
                        AppFontStyle.modern, 
                        'Modern Dynamic', 
                        'Aa / অ', 
                        'Poppins & Hind'
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFontOptionCard(
                        context, 
                        themeManager, 
                        AppFontStyle.clean, 
                        'Clean Minimal', 
                        'Aa / অ', 
                        'Roboto & Noto'
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFontOptionCard(
                        context, 
                        themeManager, 
                        AppFontStyle.classic, 
                        'Classic Serif', 
                        'Aa / অ', 
                        'Lora & Anek'
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 16),
  
                // Layout Style Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.dashboard_customize_rounded, color: theme.colorScheme.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'App Layout Style',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
  
                // Layout Style Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.2,
                  children: [
                    _buildLayoutOptionCard(context, themeManager, AppLayoutStyle.classic, 'Classic Vintage', Icons.layers_outlined),
                    _buildLayoutOptionCard(context, themeManager, AppLayoutStyle.glassmorphism, 'Glassmorphism', Icons.blur_on_rounded),
                    _buildLayoutOptionCard(context, themeManager, AppLayoutStyle.neumorphic, 'Neumorphic Soft', Icons.filter_hdr_outlined),
                    _buildLayoutOptionCard(context, themeManager, AppLayoutStyle.neon, 'Neon Glow', Icons.lightbulb_outline_rounded),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFontOptionCard(
    BuildContext context, 
    ThemeManager themeManager, 
    AppFontStyle style, 
    String title, 
    String previewText, 
    String desc
  ) {
    final isSelected = themeManager.currentFontStyle == style;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => themeManager.setFontStyle(style),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.08) : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              previewText,
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutOptionCard(
    BuildContext context, 
    ThemeManager themeManager, 
    AppLayoutStyle style, 
    String name, 
    IconData icon
  ) {
    final isSelected = themeManager.currentLayoutStyle == style;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => themeManager.setLayoutStyle(style),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.08) : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon, 
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant, 
              size: 20
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 16),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// Study Analytics Screen (স্টাডি অ্যানালিটিক্স)
// ==========================================
class StudyAnalyticsScreen extends StatefulWidget {
  const StudyAnalyticsScreen({super.key});

  @override
  State<StudyAnalyticsScreen> createState() => _StudyAnalyticsScreenState();
}

class _StudyAnalyticsScreenState extends State<StudyAnalyticsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  List<DailyRoutine> _routines = [];
  
  // Aggregated Stats
  Map<String, int> _subjectTimes = {}; // Subject name -> Minutes
  Map<String, int> _categoryTimes = {}; // Category name -> Minutes
  List<double> _weeklyProgress = List.generate(7, (_) => 0.0); // Last 7 days progress
  List<String> _weeklyDays = [];
  int _totalHours = 0;
  int _totalTasksCompleted = 0;

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final now = DateTime.now();
      // Fetch routines from the last 7 days
      final lastWeek = now.subtract(const Duration(days: 7));
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('dailyRoutines')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(lastWeek))
          .get();

      final List<DailyRoutine> fetchedRoutines = [];
      for (var doc in querySnapshot.docs) {
        fetchedRoutines.add(DailyRoutine.fromMap(doc.data(), doc.id));
      }

      // Aggregate data
      int totalMinutes = 0;
      int completedTasks = 0;
      final Map<String, int> subTimes = {};
      final Map<String, int> catTimes = {};

      for (var routine in fetchedRoutines) {
        for (var task in routine.tasks) {
          if (task.isCompleted) {
            completedTasks++;
          }
          final int minutes = task.completedDurationMinutes;
          totalMinutes += minutes;

          if (minutes > 0) {
            // Subject aggregation
            final String subName = (task.subject == null || task.subject!.trim().isEmpty) ? 'General' : task.subject!.trim();
            subTimes[subName] = (subTimes[subName] ?? 0) + minutes;

            // Category aggregation
            final String catName = (task.category == null || task.category!.trim().isEmpty) ? 'Study' : task.category!.trim();
            catTimes[catName] = (catTimes[catName] ?? 0) + minutes;
          }
        }
      }

      // Calculate last 7 days daily progress values
      final List<double> progress = [];
      final List<String> days = [];
      final DateFormat dayFormat = DateFormat('E'); // Mon, Tue, etc.

      for (int i = 6; i >= 0; i--) {
        final targetDate = now.subtract(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
        days.add(dayFormat.format(targetDate));

        final routine = fetchedRoutines.firstWhere(
          (r) => DateFormat('yyyy-MM-dd').format(r.date) == dateStr,
          orElse: () => DailyRoutine(id: dateStr, userId: currentUser!.uid, date: targetDate, tasks: []),
        );

        progress.add(routine.progress);
      }

      setState(() {
        _routines = fetchedRoutines;
        _subjectTimes = subTimes;
        _categoryTimes = catTimes;
        _weeklyProgress = progress;
        _weeklyDays = days;
        _totalHours = totalMinutes ~/ 60;
        _totalTasksCompleted = completedTasks;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching analytics data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardDeco = ThemeManager.getCardDecoration(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Study Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: cardDeco,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Hours', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                              const SizedBox(height: 8),
                              Text('${_totalHours} hrs', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: cardDeco,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Completed Tasks', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                              const SizedBox(height: 8),
                              Text('$_totalTasksCompleted', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Weekly study progress bar chart card
                  Text('Weekly Performance', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: cardDeco,
                    child: CustomPaint(
                      painter: _WeeklyProgressPainter(
                        progress: _weeklyProgress,
                        days: _weeklyDays,
                        primaryColor: theme.colorScheme.primary,
                        textColor: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Subject-wise Breakdown Card
                  Text('Subject Breakdown', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _subjectTimes.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: cardDeco,
                          child: const Center(
                            child: Text('No study tasks logged this week.', style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(20),
                          decoration: cardDeco,
                          child: Column(
                            children: _subjectTimes.entries.map((entry) {
                              final int totalMin = _subjectTimes.values.fold(0, (sum, item) => sum + item);
                              final double percentage = totalMin > 0 ? entry.value / totalMin : 0.0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('${entry.value} min (${(percentage * 100).toInt()}%)', style: TextStyle(color: theme.colorScheme.primary)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: percentage,
                                        minHeight: 8,
                                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                  const SizedBox(height: 24),

                  // Category Distribution
                  Text('Category Breakdown', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _categoryTimes.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: cardDeco,
                          child: const Center(
                            child: Text('No categorized tasks logged.', style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(20),
                          decoration: cardDeco,
                          child: Column(
                            children: _categoryTimes.entries.map((entry) {
                              final int totalMin = _categoryTimes.values.fold(0, (sum, item) => sum + item);
                              final double percentage = totalMin > 0 ? entry.value / totalMin : 0.0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('${entry.value} min', style: const TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: percentage,
                                        minHeight: 8,
                                        backgroundColor: Colors.teal.withValues(alpha: 0.1),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                ],
              ),
            ),
    );
  }
}

class _WeeklyProgressPainter extends CustomPainter {
  final List<double> progress;
  final List<String> days;
  final Color primaryColor;
  final Color textColor;

  _WeeklyProgressPainter({
    required this.progress,
    required this.days,
    required this.primaryColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress.isEmpty) return;

    final paint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final bgPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final double width = size.width;
    final double height = size.height - 24;
    final int itemCount = progress.length;
    final double spacing = width / (itemCount + 1);
    final double barWidth = 16.0;

    for (int i = 0; i < itemCount; i++) {
      final double x = spacing * (i + 1) - (barWidth / 2);
      
      // Draw background track
      final RRect bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, barWidth, height),
        const Radius.circular(8),
      );
      canvas.drawRRect(bgRect, bgPaint);

      // Draw progress filled bar
      final double p = progress[i].clamp(0.0, 1.0);
      final double barHeight = height * p;
      final double y = height - barHeight;

      if (barHeight > 0) {
        final RRect progressRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(8),
        );
        canvas.drawRRect(progressRect, paint);
      }

      // Draw Day Label below bar
      final textPainter = TextPainter(
        text: TextSpan(
          text: days[i],
          style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + (barWidth / 2) - (textPainter.width / 2), height + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.days != days;
  }
}

// ==========================================
// PDF Reader Screen (পিডিএফ রিডার ও হ্যান্ডনোটস)
// ==========================================
class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({super.key});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  final ImagePicker _picker = ImagePicker();
  List<File> _pdfFiles = [];
  bool _isLoading = false;

  Future<void> _pickPdf() async {
    // Pick image or file as a simulated PDF / Handnotes document picker
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final path = pickedFile.path.toLowerCase();
        if (!path.endsWith('.pdf')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Only PDF files (.pdf) are allowed! This is a JPG/PNG image file.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }

        setState(() {
          _pdfFiles.add(File(pickedFile.path));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document imported successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing document: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardDeco = ThemeManager.getCardDecoration(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('PDF Reader & Notes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: cardDeco,
              child: Column(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, size: 60, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  const Text(
                    'Study Handnotes & PDFs',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Import Handnotes, Books or Lecture PDFs to study inside StudyMate.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _pickPdf,
                    icon: const Icon(Icons.add_to_photos_rounded),
                    label: const Text('Import Document'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'My Documents',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _pdfFiles.isEmpty
                  ? Center(
                      child: Text(
                        'No documents imported yet.',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _pdfFiles.length,
                      itemBuilder: (context, index) {
                        final file = _pdfFiles[index];
                        final String fileName = file.path.split('/').last.split('\\').last;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.redAccent,
                              child: Icon(Icons.menu_book_rounded, color: Colors.white),
                            ),
                            title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Size: ${(file.lengthSync() / 1024).toStringAsFixed(1)} KB'),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                            onTap: () {
                              // Open Viewer Simulation
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    appBar: AppBar(title: Text(fileName)),
                                    body: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.chrome_reader_mode_rounded, size: 100, color: Colors.blueAccent),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Viewing Document: $fileName',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text('Reading session started. Stay focused!', style: TextStyle(color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}