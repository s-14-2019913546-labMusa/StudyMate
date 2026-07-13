import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
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
import 'package:markdown/markdown.dart' as md;
import 'daily_routine.dart'; // Task মডেল ইমপোর্ট করার জন্য
import 'dashboard_screen.dart';
import 'calendar_screen.dart';
import 'focus_music_screen.dart';
import 'flashcards_screen.dart';
import 'dictionary_screen.dart';
import 'ai_service.dart';
import 'revision_147_screen.dart';
import 'islamic_life_screen.dart';
import 'theme_manager.dart';
import 'local_notification_service.dart';
import 'study_analytics_screen.dart';
import 'weekly_overview_screen.dart';
import 'task_history_screen.dart';
import 'gamification_service.dart';
import 'language_manager.dart';
import 'study_folder_manager_screen.dart';
import 'special_day_countdown_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:open_filex/open_filex.dart';
import 'daily_diary_screen.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'bookmarks_screen.dart';
import 'social_hub_screen.dart';
import 'notifications_hub_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

class ToolsScreen extends StatefulWidget {
  final Function(List<Task>) onTasksGenerated;
  const ToolsScreen({super.key, required this.onTasksGenerated});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  bool _isOffline = false;
  late final StreamSubscription _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (!mounted) return;
      setState(() {
        _isOffline = result.contains(ConnectivityResult.none);
      });
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOffline = result.contains(ConnectivityResult.none);
      });
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> categories = [
      {
        'name': 'Study Tools',
        'icon': Icons.school_rounded,
        'tools': [
          {'title': 'Calculator', 'icon': Icons.calculate_rounded, 'color': Colors.blueAccent, 'action': 'calc'},
          {'title': 'Pomodoro', 'icon': Icons.timer_rounded, 'color': Colors.redAccent, 'action': 'pomodoro'},
          {'title': 'Stopwatch', 'icon': Icons.timer_outlined, 'color': Colors.deepOrangeAccent, 'action': 'stopwatch'},
          {'title': 'Notes', 'icon': Icons.note_alt_rounded, 'color': Colors.amber.shade600, 'action': 'notes'},
          {'title': 'PDF Reader', 'icon': Icons.picture_as_pdf_rounded, 'color': Colors.redAccent, 'action': 'pdf_reader'},
          {'title': 'Daily Diary', 'icon': Icons.book_rounded, 'color': Colors.brown, 'action': 'daily_diary'},
          {'title': '1-4-7 Revision', 'icon': Icons.published_with_changes_rounded, 'color': Colors.indigo, 'action': 'revision_147'},
          {'title': 'Flashcards', 'icon': Icons.style_rounded, 'color': Colors.purpleAccent, 'action': 'flash'},
          {'title': 'Task History', 'icon': Icons.history_rounded, 'color': Colors.blueGrey, 'action': 'task_history'},
          {'title': 'Dictionary', 'icon': Icons.menu_book_rounded, 'color': Colors.orangeAccent, 'action': 'dict', 'requiresInternet': true},
          {'title': 'Special Hub', 'icon': Icons.folder_copy_rounded, 'color': Colors.teal, 'action': 'study_folders'},
          {'title': 'Countdown', 'icon': Icons.event_note_rounded, 'color': const Color(0xFF6366F1), 'action': 'countdown'},
          {'title': 'Calendar', 'icon': Icons.calendar_month_rounded, 'color': Colors.teal, 'action': 'calendar'},
        ]
      },
      {
        'name': 'Focus',
        'icon': Icons.bolt_rounded,
        'tools': [
          {'title': 'Islamic Life', 'icon': Icons.mosque_rounded, 'color': Colors.teal, 'action': 'islamic', 'requiresInternet': true},
          {'title': 'Breathing Exercise', 'icon': Icons.air_rounded, 'color': Colors.lightBlueAccent, 'action': 'breath'},
          {'title': 'Focus Music', 'icon': Icons.headphones_rounded, 'color': Colors.teal, 'action': 'music', 'requiresInternet': true},
        ]
      },
      {
        'name': 'Collaborative Studying',
        'icon': Icons.people_rounded,
        'tools': [
          {'title': 'Social Hub', 'icon': Icons.people_alt_rounded, 'color': Colors.blueAccent, 'action': 'social_hub', 'requiresInternet': true},
          {'title': 'Study Room', 'icon': Icons.video_camera_front_rounded, 'color': Colors.deepPurpleAccent, 'action': 'study_room', 'requiresInternet': true},
          {'title': 'Partner Tasks', 'icon': Icons.group_add_rounded, 'color': Colors.green, 'action': 'partner_tasks', 'requiresInternet': true},
          {'title': 'Web Bookmarks', 'icon': Icons.bookmarks_rounded, 'color': Colors.blue, 'action': 'bookmarks', 'requiresInternet': true},
          {'title': 'Study Analytics', 'icon': Icons.analytics_rounded, 'color': Colors.teal, 'action': 'analytics'},
          {'title': 'Notifications', 'icon': Icons.notifications_active_rounded, 'color': Colors.redAccent, 'action': 'notifications'},
        ]
      },
      {
        'name': 'Well-being & Utilities',
        'icon': Icons.favorite_rounded,
        'tools': [
          {'title': 'Mood Tracker', 'icon': Icons.mood_rounded, 'color': Colors.pinkAccent, 'action': 'mood'},
          {'title': 'Sleep Tracker', 'icon': Icons.bedtime_rounded, 'color': Colors.indigoAccent, 'action': 'sleep'},
          {'title': 'Theme', 'icon': Icons.palette_rounded, 'color': Colors.amber, 'action': 'theme'},
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
              'Study Tools'.tr(),
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
                            (category['name'] as String).tr(),
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
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: cardDeco.borderRadius as BorderRadius?,
                                  onTap: () {
                                    if (tool['action'] == 'mood') {
                                      showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent, builder: (_) => const MoodTrackerBottomSheet());
                                    } else if (tool['action'] == 'breath') {
                                      showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent, builder: (_) => const BreathingExerciseBottomSheet());
                                    } else if (tool['action'] == 'routine') {
                                      showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent, builder: (_) => const RoutinePlannerBottomSheet());
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
                                    } else if (tool['action'] == 'social_hub') {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SocialHubScreen()));
                                    } else if (tool['action'] == 'notifications') {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsHubScreen()));
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
                                    } else if (tool['action'] == 'task_history') {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskHistoryScreen()));
                                    } else if (tool['action'] == 'study_folders') {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyFolderManagerScreen()));
                                    } else if (tool['action'] == 'countdown') {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SpecialDayCountdownScreen()));
                                    } else if (tool['action'] == 'calendar') {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen()));
                                    } else if (tool['action'] == 'islamic') {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const IslamicLifeScreen()));
                                    } else if (tool['action'] == 'daily_diary') {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyDiaryScreen()));
                                    } else if (tool['action'] == 'bookmarks') {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BookmarksScreen()));
                                    } else if (tool['action'] == 'theme') {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        useSafeArea: true,
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
                                          (tool['title'] as String).tr(),
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
                              if (tool['requiresInternet'] == true && _isOffline)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Tooltip(
                                    message: 'Offline - Requires Internet'.tr(),
                                    child: const Icon(
                                      Icons.wifi_off_rounded,
                                      size: 13,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                            ],
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
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (context) => AIStudyPlannerBottomSheet(
            onTasksGenerated: widget.onTasksGenerated,
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
                  Text('AI Study Planner'.tr(), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Plan your study smartly in one click!'.tr(), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                  const SizedBox(height: 6),
                  if (_isOffline)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            'Offline - Requires Internet'.tr(),
                            style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
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
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (context) => AddTaskBottomSheet(
            title: 'Add to Next-day Routine'.tr(),
            submitButtonText: 'Save'.tr(),
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
                  Text('Next-day Routine (নেক্সট ডে রুটিন)'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('Create your study routine for tomorrow.'.tr(), style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
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
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WeeklyOverviewScreen()),
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
                  Text('Weekly Routine (উইকলি রুটিন)'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('Customize and update your weekly routine.'.tr(), style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
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

    final task = Task(
      id: taskId,
      title: taskSubject,
      subject: taskSubject,
      topic: _topicController.text.trim(),
      challenges: _challengesController.text.trim(),
      notes: _notesController.text.trim(),
      startTime: startDateTime,
      endTime: endDateTime,
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
                    'উইকলি রুটিনে টাস্ক যুক্ত করুন',
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
                'দিন বাছুন (Select Day)',
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
                validator: (val) => val == null || val.isEmpty ? 'বিষয়ের নাম দিন' : null,
              ),
              const SizedBox(height: 16),

              // Topic
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

              // Challenges
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

              // Notes
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
  Stream<QuerySnapshot>? _sleepHistoryStream;

  TimeOfDay _bedTime = const TimeOfDay(hour: 23, minute: 45);
  TimeOfDay _morningTime = const TimeOfDay(hour: 6, minute: 0);
  
  bool _isSleeping = false;
  DateTime? _sleepStartTime;
  Timer? _uiUpdateTimer;
  Timer? _alarmRingingTimer;
  bool _alarmTriggered = false;
  bool _bedTimeTriggered = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _startUIUpdateTimer(); // Start timer immediately to watch for bedtime
    _loadSleepState();
    if (currentUser != null) {
      _sleepHistoryStream = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('sleep_history')
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
  }

  Future<void> _loadSleepState() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if there's an ongoing sleep session
    final expectedStartStr = prefs.getString('expected_sleep_start');
    if (expectedStartStr != null) {
      final expectedStart = DateTime.parse(expectedStartStr);
      // If expected sleep start is in the past, user is considered sleeping
      if (expectedStart.isBefore(DateTime.now())) {
        setState(() {
          _isSleeping = true;
          _sleepStartTime = expectedStart;
        });
        _startUIUpdateTimer();
      }
    }

    // Check if alarm was turned off in background and we need to save history
    final needsSave = prefs.getBool('needs_to_save_sleep_history') ?? false;
    if (needsSave && _sleepStartTime != null) {
      await _saveSleepHistoryToFirebase();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _uiUpdateTimer?.cancel();
    _alarmRingingTimer?.cancel();
    super.dispose();
  }

  void _startUIUpdateTimer() {
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      
      final now = DateTime.now();
      
      // Check for BedTime
      if (!_bedTimeTriggered && now.hour == _bedTime.hour && now.minute == _bedTime.minute) {
        _bedTimeTriggered = true;
        _showBedTimePopup();
      }
      if (now.minute != _bedTime.minute) {
        _bedTimeTriggered = false;
      }

      // Check for WakeTime
      if (!_alarmTriggered && now.hour == _morningTime.hour && now.minute == _morningTime.minute && _isSleeping) {
        _alarmTriggered = true;
        _triggerAlarm();
      }
      if (now.minute != _morningTime.minute) {
        _alarmTriggered = false;
      }
    });
  }

  void _showBedTimePopup() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🌙 Bed Time!', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Your sleep session has started. Please put your phone away.', textAlign: TextAlign.center),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (!_isSleeping) _startSleep();
            },
            child: const Text('Go to Sleep'),
          ),
        ],
      ),
    );
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

  void _snoozeAlarm() async {
    final snoozeTime = DateTime.now().add(const Duration(minutes: 5));
    setState(() {
      _morningTime = TimeOfDay.fromDateTime(snoozeTime);
      _alarmTriggered = false; // Reset trigger for snooze
    });
    // Reschedule background alarm
    await LocalNotificationService.scheduleMorningAlarm(snoozeTime);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alarm snoozed. Will ring again in 5 minutes.')));
    }
  }

  Future<void> _startSleep() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _isSleeping = true;
      _sleepStartTime = DateTime.now();
    });
    
    await prefs.setString('expected_sleep_start', _sleepStartTime!.toIso8601String());
    
    // Schedule all notifications via background service
    final now = DateTime.now();
    DateTime actualBedTime = DateTime(now.year, now.month, now.day, _bedTime.hour, _bedTime.minute);
    if (actualBedTime.isBefore(now)) actualBedTime = actualBedTime.add(const Duration(days: 1));
    
    DateTime actualWakeTime = DateTime(now.year, now.month, now.day, _morningTime.hour, _morningTime.minute);
    if (actualWakeTime.isBefore(now)) actualWakeTime = actualWakeTime.add(const Duration(days: 1));

    await LocalNotificationService.scheduleAllSleepNotifications(actualBedTime, actualWakeTime);
    _startUIUpdateTimer();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sleep tracked & Alarms set for background!')));
    }
  }

  Future<void> _saveSleepHistoryToFirebase() async {
    if (_sleepStartTime == null || currentUser == null) return;
    
    final now = DateTime.now();
    final duration = now.difference(_sleepStartTime!);

    await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('sleep_history').add({
      'bedTime': Timestamp.fromDate(_sleepStartTime!),
      'wakeTime': Timestamp.fromDate(now),
      'durationMinutes': duration.inMinutes,
      'timestamp': FieldValue.serverTimestamp(),
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('expected_sleep_start');
    await prefs.setBool('needs_to_save_sleep_history', false);

    setState(() {
      _isSleeping = false;
      _sleepStartTime = null;
    });
    _uiUpdateTimer?.cancel();
  }

  Future<void> _stopSleepAndSave() async {
    _alarmRingingTimer?.cancel();
    await LocalNotificationService.cancelAllNotifications();
    await _saveSleepHistoryToFirebase();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sleep session saved to history!')));
    }
  }

  Future<void> _pickTime(bool isBedTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isBedTime ? _bedTime : _morningTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isBedTime) {
          _bedTime = picked;
        } else {
          _morningTime = picked;
        }
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(isBedTime ? 'bed_time' : 'morning_time', picked.toString());
      
      // Reschedule if they are not sleeping yet
      if (!_isSleeping) {
        final now = DateTime.now();
        DateTime actualBedTime = DateTime(now.year, now.month, now.day, _bedTime.hour, _bedTime.minute);
        if (actualBedTime.isBefore(now)) actualBedTime = actualBedTime.add(const Duration(days: 1));
        
        DateTime actualWakeTime = DateTime(now.year, now.month, now.day, _morningTime.hour, _morningTime.minute);
        if (actualWakeTime.isBefore(now)) actualWakeTime = actualWakeTime.add(const Duration(days: 1));
        
        await LocalNotificationService.scheduleAllSleepNotifications(actualBedTime, actualWakeTime);
      }
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String h = twoDigits(d.inHours);
    String m = twoDigits(d.inMinutes.remainder(60));
    String s = twoDigits(d.inSeconds.remainder(60));
    return "$h:$m:$s";
  }

  Future<void> _deleteSleepRecord(String docId) async {
    if (currentUser == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Sleep Record'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this sleep record?'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('sleep_history')
            .doc(docId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sleep record deleted successfully!'.tr())),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete sleep record!'.tr())),
          );
        }
      }
    }
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
    if (currentUser == null || _sleepHistoryStream == null) return const Center(child: Text("Please log in to view sleep history."));

    return StreamBuilder<QuerySnapshot>(
      stream: _sleepHistoryStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No sleep records found.", style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Total Sleep', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text('${hours}h ${mins}m', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      onPressed: () => _deleteSleepRecord(doc.id),
                    ),
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
  final String? noteId;
  final String? initialTitle;
  final String? initialContent;

  const QuickNotesScreen({
    super.key,
    this.noteId,
    this.initialTitle,
    this.initialContent,
  });

  @override
  State<QuickNotesScreen> createState() => _QuickNotesScreenState();
}

class _QuickNotesScreenState extends State<QuickNotesScreen> {
  final TextEditingController _titleController = TextEditingController();
  late final RichTextEditingController _contentController;
  final FocusNode _contentFocusNode = FocusNode();
  TextSelection _lastSelection = const TextSelection.collapsed(offset: 0);
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isSaving = false;
  bool _isProcessingAI = false;
  String? _geminiApiKey;
  Stream<QuerySnapshot>? _notesLimitStream;
  Stream<QuerySnapshot>? _notesAllStream;

  // Custom Undo variables
  final List<String> _undoHistory = [];
  bool _isUndoing = false;
  Timer? _historyTimer;

  void _initUndoListener() {
    _undoHistory.add(_contentController.text);
    int prevWordCount = _getWordCount(_contentController.text);

    _contentController.addListener(() {
      if (_contentController.selection.isValid) {
        _lastSelection = _contentController.selection;
        _checkIfImageSelected();
      }
      if (_isUndoing) return;

      final currentText = _contentController.text;
      final currentWordCount = _getWordCount(currentText);

      // Check if a word boundary was just typed
      final bool isWordBoundary = currentText.isNotEmpty &&
          (currentText.endsWith(' ') ||
           currentText.endsWith('\n') ||
           currentText.endsWith('.') ||
           currentText.endsWith(',') ||
           currentText.endsWith('?') ||
           currentText.endsWith('!'));

      // If word count changed or a word boundary is typed, save state immediately
      if (currentWordCount != prevWordCount || isWordBoundary) {
        prevWordCount = currentWordCount;
        _historyTimer?.cancel();
        if (_undoHistory.isEmpty || _undoHistory.last != currentText) {
          if (_undoHistory.length >= 6) {
            _undoHistory.removeAt(0);
          }
          _undoHistory.add(currentText);
        }
      } else {
        // Fallback debounce: if typing is paused for 1.2s, record the state
        _historyTimer?.cancel();
        _historyTimer = Timer(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          final pauseText = _contentController.text;
          if (_undoHistory.isEmpty || _undoHistory.last != pauseText) {
            if (_undoHistory.length >= 6) {
              _undoHistory.removeAt(0);
            }
            _undoHistory.add(pauseText);
          }
        });
      }
    });
  }

  int _getWordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  void _performUndo() {
    if (_undoHistory.length > 1) {
      setState(() {
        _isUndoing = true;
        _undoHistory.removeLast();
        final prevText = _undoHistory.last;
        _contentController.text = prevText;
        _contentController.selection = TextSelection.collapsed(offset: _contentController.text.length);
        _isUndoing = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No more undo steps available (Max 5 steps)')),
      );
    }
  }

  @override
  void initState() {
    _contentController = RichTextEditingController(
      context: context,
      isDarkMode: () => _isNoteDarkMode,
    );
    super.initState();
    _initUndoListener();
    _loadApiKey();
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialContent != null) {
      _contentController.setMarkdownText(widget.initialContent!);
    }
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
    final selection = _lastSelection;
    _contentFocusNode.requestFocus();
    if (selection.isValid && selection.start >= 0 && selection.end <= text.length) {
      final selectedText = selection.textInside(text);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
      final int newOffset = selection.start + prefix.length + selectedText.length + suffix.length;
      final newSelection = TextSelection.collapsed(offset: newOffset);
      _contentController.value = TextEditingValue(
        text: newText,
        selection: newSelection,
      );
      _lastSelection = newSelection;
    } else {
      final newText = text + prefix + suffix;
      final int newOffset = newText.length - suffix.length;
      final newSelection = TextSelection.collapsed(offset: newOffset);
      _contentController.value = TextEditingValue(
        text: newText,
        selection: newSelection,
      );
      _lastSelection = newSelection;
    }
  }

  void _insertBullet() {
    final text = _contentController.text;
    final selection = _lastSelection;
    final prefix = '\n• ';
    _contentFocusNode.requestFocus();
    if (selection.isValid && selection.start >= 0 && selection.end <= text.length) {
      final newText = text.replaceRange(selection.start, selection.end, prefix);
      final newSelection = TextSelection.collapsed(offset: selection.start + prefix.length);
       _contentController.value = TextEditingValue(
        text: newText,
        selection: newSelection,
      );
      _lastSelection = newSelection;
    } else {
      _insertFormatting(prefix, '');
    }
  }

  void _pickTextColor() {
    // Save the current selection before opening dialog (dialog causes focus loss)
    final savedSelection = _lastSelection;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isNoteDarkMode ? const Color(0xFF2D2D2D) : Theme.of(context).cardColor,
        title: Text('Select Text Color', style: TextStyle(color: _isNoteDarkMode ? Colors.white : Theme.of(context).colorScheme.onSurface)),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildColorItem('Red', Colors.red, 'red', savedSelection),
              _buildColorItem('Blue', Colors.blue, 'blue', savedSelection),
              _buildColorItem('Green', Colors.green, 'green', savedSelection),
              _buildColorItem('Yellow', Colors.yellow, 'yellow', savedSelection),
              _buildColorItem('Orange', Colors.orange, 'orange', savedSelection),
              _buildColorItem('Purple', Colors.purple, 'purple', savedSelection),
              _buildColorItem('Pink', Colors.pink, 'pink', savedSelection),
              _buildColorItem('Teal', Colors.teal, 'teal', savedSelection),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Widget _buildColorItem(String name, Color color, String colorKey, TextSelection savedSelection) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        if (savedSelection.isValid && !savedSelection.isCollapsed &&
            savedSelection.start >= 0 && savedSelection.end <= _contentController.text.length) {
          // Text is selected, apply color style to selected text
          _contentController.toggleStyle(TextStyle(color: color), savedSelection);
        } else {
          // No text selected, insert color formatting tags so user can type colored text
          _contentController.toggleStyle(TextStyle(color: color), savedSelection);
        }
        // Restore focus to the text field
        _contentFocusNode.requestFocus();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
          ),
          const SizedBox(height: 4),
          Text(name, style: TextStyle(fontSize: 12, color: _isNoteDarkMode ? Colors.white70 : Colors.black87)),
        ],
      ),
    );
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
          _contentController.setMarkdownText('${_contentController.toMarkdown()}\n\n$summary');
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
                    _contentController.setMarkdownText(generatedContent);
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
        _contentController.insertImage(pickedFile.path);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  bool _isEditingImageDialogOpened = false;

  void _checkIfImageSelected() {
    if (_isEditingImageDialogOpened) return;
    
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (!selection.isValid || !selection.isCollapsed) return;
    
    final imageRegex = RegExp(r'!\[(.*?)\]\((.*?)\)');
    for (final match in imageRegex.allMatches(text)) {
      if (selection.start >= match.start && selection.start <= match.end) {
        _isEditingImageDialogOpened = true;
        final altText = match.group(1) ?? 'Image';
        final pathWithParams = match.group(2) ?? '';
        
        // Use a post frame callback to avoid showing sheet while building text span
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showImageEditDialog(match.start, match.end, altText, pathWithParams);
        });
        break;
      }
    }
  }

  void _showImageEditDialog(int start, int end, String altText, String pathWithParams) {
    String basePath = pathWithParams;
    double rotation = 0;
    double shadow = 0;
    double cropFactor = 1.0;
    
    try {
      final uri = Uri.parse(pathWithParams);
      basePath = uri.path;
      rotation = double.tryParse(uri.queryParameters['rotate'] ?? '0') ?? 0;
      shadow = double.tryParse(uri.queryParameters['shadow'] ?? '0') ?? 0;
      cropFactor = double.tryParse(uri.queryParameters['crop'] ?? '1.0') ?? 1.0;
    } catch (_) {
      basePath = pathWithParams;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: _isNoteDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isNetwork = basePath.startsWith('http') || basePath.startsWith('https') || basePath.startsWith('blob:');
            Widget imageWidget;
            if (isNetwork) {
              imageWidget = Image.network(
                basePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_rounded, size: 40),
              );
            } else {
              if (kIsWeb) {
                imageWidget = const Icon(Icons.broken_image_rounded, size: 40);
              } else {
                imageWidget = Image.file(
                  File(basePath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_rounded, size: 40),
                );
              }
            }

            if (cropFactor < 1.0) {
              imageWidget = ClipRect(
                child: Align(
                  alignment: Alignment.center,
                  widthFactor: cropFactor,
                  heightFactor: cropFactor,
                  child: imageWidget,
                ),
              );
            }

            // Apply dark vignette overlay ON the image (not around it)
            if (shadow > 0) {
              final double opacity = (shadow / 20.0).clamp(0.0, 0.75);
              imageWidget = Stack(
                children: [
                  imageWidget,
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.0,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: opacity),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            final int quarters = (rotation ~/ 90) % 4;
            if (quarters > 0) {
              imageWidget = RotatedBox(quarterTurns: quarters, child: imageWidget);
            }

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Image Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _isNoteDarkMode ? Colors.white : Colors.black87), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  
                  // Preview box — clean, no box shadow
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(height: 120, child: imageWidget),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Rotate option
                  ListTile(
                    leading: const Icon(Icons.rotate_right_rounded, color: Colors.blueAccent),
                    title: Text('Rotate 90°', style: TextStyle(color: _isNoteDarkMode ? Colors.white : Colors.black87)),
                    trailing: Text('${rotation.toInt()}°', style: TextStyle(color: _isNoteDarkMode ? Colors.white70 : Colors.black54)),
                    onTap: () {
                      rotation = (rotation + 90) % 360;
                      setModalState(() {});
                      _updateImageParamsInText(start, end, altText, basePath, rotation, shadow, cropFactor);
                    },
                  ),
                  
                  // Shadow option — vignette on the image
                  ListTile(
                    leading: const Icon(Icons.brightness_3_rounded, color: Colors.blueGrey),
                    title: Text('Vignette Shadow', style: TextStyle(color: _isNoteDarkMode ? Colors.white : Colors.black87)),
                    subtitle: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.blueAccent,
                        inactiveTrackColor: Colors.blueAccent.withValues(alpha: 0.2),
                        thumbColor: Colors.blueAccent,
                        overlayColor: Colors.blueAccent.withValues(alpha: 0.15),
                      ),
                      child: Slider(
                        value: shadow,
                        min: 0,
                        max: 20,
                        divisions: 10,
                        onChanged: (v) {
                          shadow = v;
                          setModalState(() {});
                          _updateImageParamsInText(start, end, altText, basePath, rotation, shadow, cropFactor);
                        },
                      ),
                    ),
                    trailing: Text('${shadow.toInt()}', style: TextStyle(color: _isNoteDarkMode ? Colors.white70 : Colors.black54)),
                  ),
                  
                  // Crop option
                  ListTile(
                    leading: const Icon(Icons.crop_rounded, color: Colors.green),
                    title: Text('Crop / Zoom Factor', style: TextStyle(color: _isNoteDarkMode ? Colors.white : Colors.black87)),
                    subtitle: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.green,
                        inactiveTrackColor: Colors.green.withValues(alpha: 0.2),
                        thumbColor: Colors.green,
                        overlayColor: Colors.green.withValues(alpha: 0.15),
                      ),
                      child: Slider(
                        value: cropFactor,
                        min: 0.5,
                        max: 1.0,
                        onChanged: (v) {
                          cropFactor = v;
                          setModalState(() {});
                          _updateImageParamsInText(start, end, altText, basePath, rotation, shadow, cropFactor);
                        },
                      ),
                    ),
                    trailing: Text('${(cropFactor * 100).toInt()}%', style: TextStyle(color: _isNoteDarkMode ? Colors.white70 : Colors.black54)),
                  ),
                  
                  // Delete option
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                    title: const Text('Delete Image', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(ctx);
                      final updatedText = _contentController.text.replaceRange(start, end, '');
                      _contentController.value = TextEditingValue(
                        text: updatedText,
                        selection: TextSelection.collapsed(offset: start),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      _isEditingImageDialogOpened = false;
    });
  }

  void _updateImageParamsInText(int start, int end, String alt, String path, double rot, double shad, double crop) {
    final text = _contentController.text;
    final newPath = '$path?rotate=${rot.toInt()}&shadow=${shad.toInt()}&crop=$crop';
    final newFullMatch = '![$alt]($newPath)';
    final updatedText = text.replaceRange(start, end, newFullMatch);
    
    _contentController.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: start + newFullMatch.length),
    );
  }

  Widget _buildInlineImageCards(Color textColor) {
    return AnimatedBuilder(
      animation: _contentController,
      builder: (context, _) {
        final currentText = _contentController.text;
        final imageRegex = RegExp(r'!\[(.*?)\]\((.*?)\)');
        final currentMatches = imageRegex.allMatches(currentText).toList();
        if (currentMatches.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.photo_library_rounded, size: 14,
                        color: _isNoteDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Attached Images (${currentMatches.length})',
                      style: TextStyle(
                          fontSize: 12,
                          color: _isNoteDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              ...currentMatches.asMap().entries.map((entry) {
                final idx = entry.key;
                final match = entry.value;
                final altText = match.group(1) ?? 'Image';
                final pathWithParams = match.group(2) ?? '';

                String basePath = pathWithParams;
                double rotation = 0;
                try {
                  final uri = Uri.parse(pathWithParams);
                  basePath = uri.path;
                  rotation = double.tryParse(uri.queryParameters['rotate'] ?? '0') ?? 0;
                } catch (_) {}

                final isNetwork = basePath.startsWith('http') ||
                    basePath.startsWith('https') ||
                    basePath.startsWith('blob:');
                final quarters = (rotation ~/ 90).toInt() % 4;

                Widget thumbnail = _buildThumbnail(basePath, isNetwork, quarters);

                return Draggable<int>(
                  data: idx,
                  feedback: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isNoteDarkMode ? const Color(0xFF333333) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [thumbnail, const SizedBox(width: 8), Expanded(child: Text(altText, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))]),
                    ),
                  ),
                  childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _imageCard(thumbnail, altText, idx, match, currentText, textColor)),
                  child: DragTarget<int>(
                    onAcceptWithDetails: (details) {
                      final fromIdx = details.data;
                      final toIdx = idx;
                      if (fromIdx == toIdx) return;
                      final allM = imageRegex.allMatches(currentText).toList();
                      if (fromIdx >= allM.length || toIdx >= allM.length) return;
                      final fromM = allM[fromIdx];
                      final toM = allM[toIdx];
                      String newText = currentText;
                      if (fromM.start > toM.start) {
                        newText = newText.replaceRange(fromM.start, fromM.end, toM.group(0)!);
                        newText = newText.replaceRange(toM.start, toM.end, fromM.group(0)!);
                      } else {
                        newText = newText.replaceRange(toM.start, toM.end, fromM.group(0)!);
                        newText = newText.replaceRange(fromM.start, fromM.end, toM.group(0)!);
                      }
                      _contentController.value = TextEditingValue(
                        text: newText,
                        selection: _contentController.selection,
                      );
                    },
                    builder: (ctx, candidateData, _) => _imageCard(
                      thumbnail, altText, idx, match, currentText, textColor,
                      highlight: candidateData.isNotEmpty,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(String basePath, bool isNetwork, int quarters) {
    Widget img;
    if (isNetwork) {
      img = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          basePath, width: 72, height: 72, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _brokenImageBox(),
        ),
      );
    } else if (kIsWeb) {
      img = Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.image_rounded, color: Colors.blue, size: 28),
          SizedBox(height: 2),
          Text('Image', style: TextStyle(fontSize: 10, color: Colors.blue)),
        ]),
      );
    } else {
      img = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(basePath), width: 72, height: 72, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _brokenImageBox(),
        ),
      );
    }
    if (quarters > 0) img = RotatedBox(quarterTurns: quarters, child: img);
    return img;
  }

  Widget _brokenImageBox() => Container(
    width: 72, height: 72, color: Colors.grey.shade200,
    child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 28)),
  );

  Widget _imageCard(Widget thumbnail, String altText, int idx, RegExpMatch match,
      String currentText, Color textColor, {bool highlight = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: highlight
            ? (_isNoteDarkMode ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50)
            : (_isNoteDarkMode ? const Color(0xFF2A2A2A) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? Colors.blue : (_isNoteDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
          width: highlight ? 2 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(Icons.drag_indicator_rounded,
                color: _isNoteDarkMode ? Colors.grey.shade600 : Colors.grey.shade400, size: 20),
            const SizedBox(width: 6),
            thumbnail,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(altText,
                      style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('Image ${idx + 1}  •  Hold to reorder',
                      style: TextStyle(fontSize: 11,
                          color: _isNoteDarkMode ? Colors.grey.shade500 : Colors.grey.shade500)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _showImageEditDialog(match.start, match.end, altText, match.group(2) ?? ''),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.tune_rounded, size: 16, color: Colors.blue),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    final updatedText = currentText.replaceRange(match.start, match.end, '');
                    _contentController.value = TextEditingValue(
                      text: updatedText,
                      selection: TextSelection.collapsed(offset: match.start),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.delete_rounded, size: 16, color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _saveNote() async {
    if (_titleController.text.trim().isEmpty && _contentController.text.trim().isEmpty && _audioFilePath == null && _imageFilePath == null) return;
    if (currentUser == null) return;

    setState(() => _isSaving = true);

    String? audioUrl;
    String? imageUrl = _imageFilePath;
    
    if (_audioFilePath != null) {
      try {
        final File audioFile = File(_audioFilePath!);
        // ফায়ারবেস ক্লাউড স্টোরেজে আপলোড
        final storageRef = FirebaseStorage.instance.ref().child('notes_audio/${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.m4a');
        final uploadTask = kIsWeb
            ? await storageRef.putData(await audioFile.readAsBytes())
            : await storageRef.putFile(audioFile);
        audioUrl = await uploadTask.ref.getDownloadURL();
      } catch (e) {
        debugPrint("Audio Upload Error: $e");
      }
    }

    // ছবি ফায়ারবেস ক্লাউড স্টোরেজে আপলোড (লেগাসি অ্যাটাচমেন্ট থাকলে)
    if (_imageFilePath != null && !_contentController.text.contains(_imageFilePath!)) {
      try {
        final File imageFile = File(_imageFilePath!);
        final storageRef = FirebaseStorage.instance.ref().child('notes_images/${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        final uploadTask = kIsWeb
            ? await storageRef.putData(await imageFile.readAsBytes())
            : await storageRef.putFile(imageFile);
        imageUrl = await uploadTask.ref.getDownloadURL();
      } catch (e) {
        debugPrint("Image Upload Error: $e");
      }
    }

    // আপলোড এম্বেডেড লোকাল ইমেজ ফাইল বা ব্রাউজার ব্লব ফাইল
    String noteContent = _contentController.toMarkdown();
    final imageRegex = RegExp(r'!\[(.*?)\]\((.*?)\)');
    final matches = imageRegex.allMatches(noteContent).toList();
    
    for (final match in matches) {
      final altText = match.group(1) ?? 'Image';
      final pathWithParams = match.group(2) ?? '';
      
      final uri = Uri.parse(pathWithParams);
      final basePath = uri.path;
      
      if (!basePath.startsWith('http') && !basePath.startsWith('https')) {
        try {
          Uint8List bytes;
          if (kIsWeb || basePath.startsWith('blob:')) {
            // ব্রাউজার ব্লব URL থেকে রিড করা
            final response = await http.get(Uri.parse(basePath));
            bytes = response.bodyBytes;
          } else {
            // লোকাল স্টোরেজ থেকে রিড করা
            bytes = await File(basePath).readAsBytes();
          }

          final storageRef = FirebaseStorage.instance.ref().child('notes_images/${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(10000)}.jpg');
          final uploadTask = await storageRef.putData(bytes);
          final networkUrl = await uploadTask.ref.getDownloadURL();
          
          final queryStr = uri.hasQuery ? '?${uri.query}' : '';
          final newPathWithParams = '$networkUrl$queryStr';
          
          final oldMatch = match.group(0)!;
          final newMatch = '![$altText]($newPathWithParams)';
          noteContent = noteContent.replaceAll(oldMatch, newMatch);
        } catch (e) {
          debugPrint("Error uploading inline image: $e");
        }
      }
    }

    final noteData = {
      'title': _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Untitled Note',
      'content': noteContent.trim(),
      'audioUrl': audioUrl,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (widget.noteId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('notes')
          .doc(widget.noteId)
          .set(noteData, SetOptions(merge: true));
    } else {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('notes')
          .add(noteData);
    }

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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved securely!')));
      if (widget.noteId != null) {
        Navigator.pop(context); // Return after editing existing note
      }
    }
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
            Text('Version History', style: TextStyle(color: _isNoteDarkMode ? Colors.white : Theme.of(context).colorScheme.onSurface)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Restore a previous version of this note if you made a mistake.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Today, 10:30 AM', style: TextStyle(color: _isNoteDarkMode ? Colors.white : Theme.of(context).colorScheme.onSurface)),
              subtitle: Text('Auto-saved', style: TextStyle(color: Colors.grey.shade500)),
              trailing: TextButton(onPressed: () { Navigator.pop(ctx); _simulateAction('Restored to 10:30 AM version'); }, child: const Text('Restore')),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Yesterday, 5:15 PM', style: TextStyle(color: _isNoteDarkMode ? Colors.white : Theme.of(context).colorScheme.onSurface)),
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

  Future<void> _confirmDeleteNote(String docId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isNoteDarkMode ? const Color(0xFF2D2D2D) : Theme.of(context).cardColor,
        title: Text('Delete Note?', style: TextStyle(color: _isNoteDarkMode ? Colors.white : Theme.of(context).colorScheme.onSurface)),
        content: Text('Are you sure you want to delete this note? This action cannot be undone.', 
          style: TextStyle(color: _isNoteDarkMode ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('notes')
            .doc(docId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting note: $e')),
          );
        }
      }
    }
  }

  void _showPreviousNotesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isDark = _isNoteDarkMode; 
        Color cardColor = isDark ? const Color(0xFF2D2D2D) : Theme.of(context).cardColor;
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
                  Text('Previous Notes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface)),
                  IconButton(icon: Icon(Icons.close, color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface), onPressed: () => Navigator.pop(context)),
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
                            final content = _stripMarkdown(data['content'] ?? '');
                            final timestamp = data['timestamp'] as Timestamp?;
                            final audioUrl = data['audioUrl'] as String?;
                            final imageUrl = data['imageUrl'] as String?;
                            String dateStr = 'Just now';
                            if (timestamp != null) {
                              dateStr = DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate());
                            }

                            return Card(
                              color: cardColor,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.pop(context); // Close bottom sheet
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => NoteDetailScreen(
                                    noteId: doc.id,
                                    title: title,
                                    content: data['content'] ?? '',
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
                                          Expanded(child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                          if (audioUrl != null)
                                            Icon(Icons.mic_rounded, color: isDark ? Colors.grey.shade400 : Colors.grey, size: 20),
                                          if (imageUrl != null)
                                            Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.image_rounded, color: isDark ? Colors.grey.shade400 : Colors.grey, size: 20)),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                            tooltip: 'Delete Note',
                                            onPressed: () => _confirmDeleteNote(doc.id),
                                          ),
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
    _contentFocusNode.dispose();
    _audioRecorder.dispose();
    _historyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = _isNoteDarkMode ? const Color(0xFF1E1E1E) : Theme.of(context).colorScheme.surface;
    Color textColor = _isNoteDarkMode ? Colors.white : Theme.of(context).colorScheme.onSurface;
    Color cardColor = _isNoteDarkMode ? const Color(0xFF2D2D2D) : Theme.of(context).cardColor;

    return Scaffold(
      resizeToAvoidBottomInset: true, // কিবোর্ড উঠলে ভিউ উপরে উঠে যাবে
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text('Smart Notes', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'Undo (Max 5 steps)',
            onPressed: _performUndo,
          ),
          IconButton(
            icon: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Icon(Icons.save_rounded),
            tooltip: 'Save Note',
            onPressed: _isSaving ? null : _saveNote,
          ),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isProcessingAI)
              const LinearProgressIndicator(color: Colors.indigoAccent),
            
            // 1. Plain Bold Title Field (Directly on Page Background)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: TextField(
                controller: _titleController,
                style: TextStyle(
                  fontSize: 26, 
                  fontWeight: FontWeight.w900, 
                  color: _isNoteDarkMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Note Title...',
                  hintStyle: TextStyle(
                    color: _isNoteDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),

            // 2. Smart Editor Container
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
                            focusNode: _contentFocusNode,
                            maxLines: null,
                            minLines: 10,
                            style: TextStyle(fontSize: _fontSize, color: textColor, height: 1.5),
                            decoration: InputDecoration(
                              hintText: 'Start writing your notes here...',
                              hintStyle: TextStyle(
                                color: _isNoteDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              filled: false,
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
                          _buildFormatBtn(Icons.format_bold_rounded, () => _contentController.toggleStyle(const TextStyle(fontWeight: FontWeight.bold), _lastSelection), tooltip: 'Bold'),
                          _buildFormatBtn(Icons.format_italic_rounded, () => _contentController.toggleStyle(const TextStyle(fontStyle: FontStyle.italic), _lastSelection), tooltip: 'Italic'),
                          _buildFormatBtn(Icons.format_quote_rounded, () => _insertFormatting('\n> ', ''), tooltip: 'Quote'),
                          _buildFormatBtn(Icons.format_list_bulleted_rounded, _insertBullet, tooltip: 'Bullet List'),
                          _buildFormatBtn(Icons.format_color_text_rounded, _pickTextColor, tooltip: 'Text Color'),
                          Container(width: 1, height: 24, color: Colors.grey, margin: const EdgeInsets.symmetric(horizontal: 8)),
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
                  Text('Previous Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor.withValues(alpha: 0.7))),
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
                        final content = _stripMarkdown(data['content'] ?? '');
                        final timestamp = data['timestamp'] as Timestamp?;
                        final audioUrl = data['audioUrl'] as String?;
                        final imageUrl = data['imageUrl'] as String?;
                        String dateStr = 'Just now';
                        if (timestamp != null) {
                          dateStr = DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate());
                        }

                        return Card(
                          color: cardColor,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => NoteDetailScreen(
                                noteId: doc.id,
                                title: title,
                                content: data['content'] ?? '',
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
                                        Icon(Icons.mic_rounded, color: textColor.withValues(alpha: 0.6), size: 20),
                                      if (imageUrl != null)
                                        Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.image_rounded, color: textColor.withValues(alpha: 0.6), size: 20)),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                        tooltip: 'Delete Note',
                                        onPressed: () => _confirmDeleteNote(doc.id),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: textColor.withValues(alpha: 0.7)),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(dateStr, style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.5), fontStyle: FontStyle.italic)),
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

  String _stripMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*|\*'), '')
        .replaceAll(RegExp(r'<color=[^>]*>|<\/color>'), '')
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)|\[.*?\]\(.*?\)'), '[Image]');
  }
}

// ==========================================
// Note Detail Screen (নোট পড়ার স্ক্রিন)
// ==========================================
class NoteDetailScreen extends StatefulWidget {
  final String noteId;
  final String title;
  final String content;
  final String date;
  final String? audioUrl;
  final String? imageUrl;

  const NoteDetailScreen({
    super.key,
    required this.noteId,
    required this.title,
    required this.content,
    required this.date,
    this.audioUrl,
    this.imageUrl,
  });

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  bool _isNoteDarkMode = false;
  bool _isPlayingAudio = false;
  bool _isPlayingAttachedAudio = false; // User Recorded Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() => _isPlayingAttachedAudio = false);
    });
    _flutterTts.setCompletionHandler(() {
      setState(() => _isPlayingAudio = false);
    });
    _flutterTts.setErrorHandler((msg) {
      setState(() => _isPlayingAudio = false);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _flutterTts.stop();
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

  String _stripMarkdownForTTS(String text) {
    return text
        .replaceAll(RegExp(r'\*\*|\*'), '')
        .replaceAll(RegExp(r'<color=[^>]*>|<\/color>'), '')
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)|\[.*?\]\(.*?\)'), '');
  }

  Future<void> _toggleAudio() async {
    if (_isPlayingAudio) {
      await _flutterTts.stop();
      setState(() {
        _isPlayingAudio = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio paused.'),
          backgroundColor: Colors.deepPurple,
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      final textToRead = _stripMarkdownForTTS(widget.content);
      if (textToRead.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note is empty or has no readable text.')),
        );
        return;
      }
      
      final bool hasBengali = RegExp(r'[\u0980-\u09FF]').hasMatch(textToRead);
      if (hasBengali) {
        await _flutterTts.setLanguage("bn-BD");
      } else {
        await _flutterTts.setLanguage("en-US");
      }
      
      setState(() {
        _isPlayingAudio = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.volume_up_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(hasBengali ? 'নোটটি পড়ে শোনানো হচ্ছে...' : 'Reading note aloud...'),
            ],
          ),
          backgroundColor: Colors.deepPurple,
          duration: const Duration(seconds: 2),
        ),
      );
      
      await _flutterTts.speak(textToRead);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = _isNoteDarkMode ? const Color(0xFF1E1E1E) : Theme.of(context).colorScheme.surface;
    Color textColor = _isNoteDarkMode ? Colors.white : Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
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
            SelectionArea(
              child: MarkdownBody(
                selectable: true,
                data: widget.content,
                softLineBreak: true,
                extensionSet: md.ExtensionSet(
                  md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                  [
                    ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                    ColorSyntax(),
                  ],
                ),
                builders: {
                  'color': ColorElementBuilder(context, isDarkMode: _isNoteDarkMode),
                },
                sizedImageBuilder: (config) => _NoteDetailImageWidget(pathWithParams: config.uri.toString()),
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: TextStyle(fontSize: 18, height: 1.8, color: textColor),
                  h1: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                  h2: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                  h3: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                  h4: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  h5: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                  h6: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                  em: TextStyle(fontStyle: FontStyle.italic, color: textColor),
                  strong: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                  listBullet: TextStyle(fontSize: 18, color: textColor),
                  blockquote: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: textColor.withValues(alpha: 0.8)),
                  blockquoteDecoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    border: Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 4)),
                  ),
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

            const SizedBox(height: 24),
            
            // Edit Note Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuickNotesScreen(
                        noteId: widget.noteId,
                        initialTitle: widget.title,
                        initialContent: widget.content,
                      ),
                    ),
                  ).then((_) {
                    // Pop this screen when returning from editing to refresh list view
                    Navigator.pop(context);
                  });
                },
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Edit Note'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),

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

// ==========================================
// Custom Markdown Editor & Renderer Helper Classes
// ==========================================

Color getAdaptiveColor(Color color, bool isDark) {
  final int val = color.value & 0xFFFFFF;
  if (isDark) {
    switch (val) {
      case 0xF44336: // Colors.red
      case 0xD32F2F:
        return const Color(0xFFE57373); // red 300
      case 0x2196F3: // Colors.blue
      case 0x1976D2:
        return const Color(0xFF64B5F6); // blue 300
      case 0x4CAF50: // Colors.green
      case 0x388E3C:
        return const Color(0xFF81C784); // green 300
      case 0xFFEB3B: // Colors.yellow
      case 0xFBC02D:
        return const Color(0xFFFFF176); // yellow 300
      case 0xFF9800: // Colors.orange
      case 0xF57C00:
        return const Color(0xFFFFB74D); // orange 300
      case 0x9C27B0: // Colors.purple
      case 0x7B1FA2:
        return const Color(0xFFBA68C8); // purple 300
      case 0xE91E63: // Colors.pink
      case 0xC2185B:
        return const Color(0xFFF06292); // pink 300
      case 0x009688: // Colors.teal
      case 0x00796B:
        return const Color(0xFF4DB6AC); // teal 300
      default:
        return color;
    }
  } else {
    switch (val) {
      case 0xF44336: // Colors.red
        return const Color(0xFFD32F2F); // red 700
      case 0x2196F3: // Colors.blue
        return const Color(0xFF1976D2); // blue 700
      case 0x4CAF50: // Colors.green
        return const Color(0xFF388E3C); // green 700
      case 0xFFEB3B: // Colors.yellow
        return const Color(0xFFF57C00); // map to dark gold/orange for readability
      case 0xFF9800: // Colors.orange
        return const Color(0xFFE65100); // orange 900
      case 0x9C27B0: // Colors.purple
        return const Color(0xFF7B1FA2); // purple 700
      case 0xE91E63: // Colors.pink
        return const Color(0xFFC2185B); // pink 700
      case 0x009688: // Colors.teal
        return const Color(0xFF00796B); // teal 700
      default:
        return color;
    }
  }
}

class _TagToken {
  final String type; // 'color_start', 'color_end', 'bold', 'italic', 'text'
  final String value;
  _TagToken(this.type, this.value);
}

class _StyleScope {
  final String type; // 'bold', 'italic', 'color'
  final int startIndex;
  final Color? color;
  _StyleScope(this.type, this.startIndex, {this.color});
}

class _StyleSpan {
  final int start;
  final int end;
  final TextStyle style;

  _StyleSpan({required this.start, required this.end, required this.style});
}

class _TagInsertion {
  final int index;
  final String tag;
  _TagInsertion({required this.index, required this.tag});
}

class RichTextEditingController extends TextEditingController {
  final BuildContext context;
  final bool Function() isDarkMode;
  List<_StyleSpan> spans = [];
  TextStyle currentToggleStyle = const TextStyle();

  RichTextEditingController({super.text, required this.context, required this.isDarkMode});

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final newText = newValue.text;
    
    if (oldText != newText) {
      _updateSpans(oldText, newText, newValue.selection);
      
      // Apply currentToggleStyle to newly typed characters
      if (currentToggleStyle != const TextStyle() && newText.length > oldText.length) {
        // Find the insertion point
        int startDiff = 0;
        while (startDiff < oldText.length &&
               startDiff < newText.length &&
               oldText[startDiff] == newText[startDiff]) {
          startDiff++;
        }
        final int insertedLen = newText.length - oldText.length;
        if (insertedLen > 0) {
          spans.add(_StyleSpan(
            start: startDiff,
            end: startDiff + insertedLen,
            style: currentToggleStyle,
          ));
          _mergeAdjacentSpans();
        }
      }
    }
    
    super.value = newValue;
  }

  void _updateSpans(String oldText, String newText, TextSelection newSelection) {
    int startDiff = 0;
    while (startDiff < oldText.length &&
           startDiff < newText.length &&
           oldText[startDiff] == newText[startDiff]) {
      startDiff++;
    }
    
    int oldEnd = oldText.length;
    int newEnd = newText.length;
    while (oldEnd > startDiff &&
           newEnd > startDiff &&
           oldText[oldEnd - 1] == newText[newEnd - 1]) {
      oldEnd--;
      newEnd--;
    }
    
    final int deletedLen = oldEnd - startDiff;
    final int insertedLen = newEnd - startDiff;
    
    final List<_StyleSpan> updatedSpans = [];
    
    for (final span in spans) {
      int s = span.start;
      int e = span.end;
      
      if (startDiff <= s) {
        s -= deletedLen;
        s += insertedLen;
        e -= deletedLen;
        e += insertedLen;
      }
      else if (startDiff > s && startDiff < e) {
        e -= deletedLen;
        e += insertedLen;
      }
      
      if (s < e && s >= 0 && e <= newText.length) {
        updatedSpans.add(_StyleSpan(start: s, end: e, style: span.style));
      }
    }
    
    spans = updatedSpans;
  }

  void toggleStyle(TextStyle styleToToggle, TextSelection selection) {
    if (!selection.isValid || selection.isCollapsed) {
      // Toggle the style for future typing
      if (styleToToggle.color != null) {
        if (currentToggleStyle.color == styleToToggle.color) {
          // Remove the color if same color is toggled again
          currentToggleStyle = currentToggleStyle.copyWith(color: null);
        } else {
          currentToggleStyle = currentToggleStyle.copyWith(color: styleToToggle.color);
        }
      } else {
        currentToggleStyle = currentToggleStyle.merge(styleToToggle);
      }
      notifyListeners();
      return;
    }
    
    final int start = selection.start;
    final int end = selection.end;
    
    bool isApplied = true;
    for (int i = start; i < end; i++) {
      if (!_isStyleAppliedAt(i, styleToToggle)) {
        isApplied = false;
        break;
      }
    }
    
    if (isApplied) {
      _removeStyleFromRange(start, end, styleToToggle);
    } else {
      _addStyleToRange(start, end, styleToToggle);
    }
    
    notifyListeners();
  }

  bool _isStyleAppliedAt(int index, TextStyle targetStyle) {
    for (final span in spans) {
      if (index >= span.start && index < span.end) {
        if (targetStyle.fontWeight == FontWeight.bold && span.style.fontWeight == FontWeight.bold) return true;
        if (targetStyle.fontStyle == FontStyle.italic && span.style.fontStyle == FontStyle.italic) return true;
        if (targetStyle.color != null && span.style.color == targetStyle.color) return true;
      }
    }
    return false;
  }

  void _addStyleToRange(int start, int end, TextStyle styleToAdd) {
    _removeStyleFromRange(start, end, styleToAdd); // clear overlaps of same attribute type
    spans.add(_StyleSpan(start: start, end: end, style: styleToAdd));
    _mergeAdjacentSpans();
  }

  void _removeStyleFromRange(int start, int end, TextStyle styleToRemove) {
    final List<_StyleSpan> newSpans = [];
    for (final span in spans) {
      bool isMatch = false;
      if (styleToRemove.fontWeight == FontWeight.bold && span.style.fontWeight == FontWeight.bold) isMatch = true;
      if (styleToRemove.fontStyle == FontStyle.italic && span.style.fontStyle == FontStyle.italic) isMatch = true;
      if (styleToRemove.color != null && span.style.color != null) isMatch = true;
      
      if (!isMatch) {
        newSpans.add(span);
        continue;
      }
      
      if (end <= span.start || start >= span.end) {
        newSpans.add(span);
      }
      else if (start <= span.start && end >= span.end) {
        // Discard span
      }
      else if (start > span.start && end < span.end) {
        newSpans.add(_StyleSpan(start: span.start, end: start, style: span.style));
        newSpans.add(_StyleSpan(start: end, end: span.end, style: span.style));
      }
      else if (start <= span.start && end < span.end) {
        newSpans.add(_StyleSpan(start: end, end: span.end, style: span.style));
      }
      else if (start > span.start && end >= span.end) {
        newSpans.add(_StyleSpan(start: span.start, end: start, style: span.style));
      }
    }
    spans = newSpans;
  }

  void _mergeAdjacentSpans() {
    spans.sort((a, b) => a.start.compareTo(b.start));
    final List<_StyleSpan> merged = [];
    
    for (final span in spans) {
      if (merged.isEmpty) {
        merged.add(span);
      } else {
        final last = merged.last;
        bool canMerge = last.end == span.start && _areStylesEqual(last.style, span.style);
        if (canMerge) {
          merged[merged.length - 1] = _StyleSpan(start: last.start, end: span.end, style: last.style);
        } else {
          merged.add(span);
        }
      }
    }
    spans = merged;
  }

  bool _areStylesEqual(TextStyle a, TextStyle b) {
    return a.fontWeight == b.fontWeight &&
           a.fontStyle == b.fontStyle &&
           a.color == b.color;
  }

  String toMarkdown() {
    final String plainText = text;
    if (plainText.isEmpty) return '';
    if (spans.isEmpty) return plainText;

    // Build per-character style info
    final List<TextStyle?> charStyles = List.filled(plainText.length, null);
    for (final span in spans) {
      for (int i = span.start; i < span.end && i < plainText.length; i++) {
        charStyles[i] = charStyles[i] == null ? span.style : charStyles[i]!.merge(span.style);
      }
    }

    // Group consecutive chars with same style into segments
    final StringBuffer result = StringBuffer();
    int i = 0;
    while (i < plainText.length) {
      final TextStyle? style = charStyles[i];
      int j = i + 1;
      while (j < plainText.length && _styleEquivalent(charStyles[j], style)) {
        j++;
      }
      final segText = plainText.substring(i, j);
      if (style == null) {
        result.write(segText);
      } else {
        String seg = segText;
        // innermost: wrap with bold/italic
        final isBold = style.fontWeight == FontWeight.bold;
        final isItalic = style.fontStyle == FontStyle.italic;
        if (isBold && isItalic) {
          seg = '***$seg***';
        } else if (isBold) {
          seg = '**$seg**';
        } else if (isItalic) {
          seg = '*$seg*';
        }
        // outermost: wrap with color if set
        if (style.color != null) {
          final colorHex = _getColorHex(style.color!);
          seg = '<color=$colorHex>$seg</color>';
        }
        result.write(seg);
      }
      i = j;
    }
    return result.toString();
  }

  bool _styleEquivalent(TextStyle? a, TextStyle? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.fontWeight == b.fontWeight &&
           a.fontStyle == b.fontStyle &&
           a.color == b.color;
  }

  String _getColorHex(Color color) {
    if (color == Colors.red) return 'red';
    if (color == Colors.blue) return 'blue';
    if (color == Colors.green) return 'green';
    if (color == Colors.yellow) return 'yellow';
    if (color == Colors.orange) return 'orange';
    if (color == Colors.purple) return 'purple';
    if (color == Colors.pink) return 'pink';
    if (color == Colors.teal) return 'teal';
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  void setMarkdownText(String markdown) {
    final parsed = parseMarkdownToSpans(markdown);
    value = TextEditingValue(
      text: parsed.plainText,
      selection: TextSelection.collapsed(offset: parsed.plainText.length),
    );
    spans = parsed.spans;
    notifyListeners();
  }

  ParsedMarkdown parseMarkdownToSpans(String markdown) {
    final List<_TagToken> tokens = [];
    int i = 0;
    while (i < markdown.length) {
      if (markdown.startsWith('**', i)) {
        tokens.add(_TagToken('bold', '**'));
        i += 2;
      } else if (markdown.startsWith('*', i)) {
        tokens.add(_TagToken('italic', '*'));
        i += 1;
      } else if (markdown.startsWith('</color>', i)) {
        tokens.add(_TagToken('color_end', '</color>'));
        i += 8;
      } else if (markdown.startsWith('<color=', i)) {
        int endIdx = markdown.indexOf('>', i);
        if (endIdx != -1) {
          final tag = markdown.substring(i, endIdx + 1);
          tokens.add(_TagToken('color_start', tag));
          i = endIdx + 1;
        } else {
          tokens.add(_TagToken('text', markdown[i]));
          i++;
        }
      } else {
        tokens.add(_TagToken('text', markdown[i]));
        i++;
      }
    }

    final List<_StyleSpan> spans = [];
    final StringBuffer plainText = StringBuffer();
    final List<_StyleScope> activeScopes = [];

    for (final token in tokens) {
      if (token.type == 'text') {
        plainText.write(token.value);
      } else if (token.type == 'color_start') {
        final colorStr = token.value.substring(7, token.value.length - 1);
        Color? tagColor;
        if (colorStr.startsWith('#')) {
          final hex = colorStr.substring(1);
          final val = int.tryParse(hex, radix: 16);
          if (val != null) tagColor = Color(val | 0xFF000000);
        } else {
          switch (colorStr.toLowerCase()) {
            case 'red': tagColor = Colors.red; break;
            case 'blue': tagColor = Colors.blue; break;
            case 'green': tagColor = Colors.green; break;
            case 'yellow': tagColor = Colors.yellow; break;
            case 'orange': tagColor = Colors.orange; break;
            case 'purple': tagColor = Colors.purple; break;
            case 'pink': tagColor = Colors.pink; break;
            case 'teal': tagColor = Colors.teal; break;
          }
        }
        activeScopes.add(_StyleScope('color', plainText.length, color: tagColor));
      } else if (token.type == 'color_end') {
        int idx = activeScopes.lastIndexWhere((s) => s.type == 'color');
        if (idx != -1) {
          final scope = activeScopes.removeAt(idx);
          if (scope.color != null) {
            spans.add(_StyleSpan(start: scope.startIndex, end: plainText.length, style: TextStyle(color: scope.color)));
          }
        }
      } else if (token.type == 'bold') {
        int idx = activeScopes.lastIndexWhere((s) => s.type == 'bold');
        if (idx == -1) {
          activeScopes.add(_StyleScope('bold', plainText.length));
        } else {
          final scope = activeScopes.removeAt(idx);
          spans.add(_StyleSpan(start: scope.startIndex, end: plainText.length, style: const TextStyle(fontWeight: FontWeight.bold)));
        }
      } else if (token.type == 'italic') {
        int idx = activeScopes.lastIndexWhere((s) => s.type == 'italic');
        if (idx == -1) {
          activeScopes.add(_StyleScope('italic', plainText.length));
        } else {
          final scope = activeScopes.removeAt(idx);
          spans.add(_StyleSpan(start: scope.startIndex, end: plainText.length, style: const TextStyle(fontStyle: FontStyle.italic)));
        }
      }
    }

    // Clean up any unmatched scopes by closing them at plainText.length
    for (final scope in activeScopes) {
      if (scope.type == 'bold') {
        spans.add(_StyleSpan(start: scope.startIndex, end: plainText.length, style: const TextStyle(fontWeight: FontWeight.bold)));
      } else if (scope.type == 'italic') {
        spans.add(_StyleSpan(start: scope.startIndex, end: plainText.length, style: const TextStyle(fontStyle: FontStyle.italic)));
      } else if (scope.type == 'color' && scope.color != null) {
        spans.add(_StyleSpan(start: scope.startIndex, end: plainText.length, style: TextStyle(color: scope.color)));
      }
    }

    return ParsedMarkdown(plainText: plainText.toString(), spans: spans);
  }

  void insertImage(String imagePath) {
    final currentText = this.text;
    final sel = selection;
    // Always ensure there is a blank line before and after the image tag
    // so the cursor can easily land below it for continued typing.
    final String prefix = (sel.isValid && sel.start > 0 && currentText[sel.start - 1] != '\n') ? '\n' : '';
    final imageTag = '${prefix}![Image]($imagePath?rotate=0&shadow=0&crop=1.0)\n';
    
    if (sel.isValid && sel.start >= 0 && sel.end <= currentText.length) {
      final newText = currentText.replaceRange(sel.start, sel.end, imageTag);
      // Cursor goes right AFTER the trailing newline so user can type immediately
      final cursorPos = sel.start + imageTag.length;
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursorPos),
      );
    } else {
      final newText = currentText + imageTag;
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final String text = this.text;
    if (text.isEmpty) return TextSpan(text: '', style: style);

    final int len = text.length;
    final List<TextStyle> charStyles = List.generate(len, (_) => style ?? const TextStyle());

    // Apply bold, italic, color spans — with bounds guard
    for (final span in spans) {
      final int s = span.start.clamp(0, len);
      final int e = span.end.clamp(0, len);
      for (int i = s; i < e; i++) {
        TextStyle spanStyle = span.style;
        if (spanStyle.color != null) {
          spanStyle = spanStyle.copyWith(color: getAdaptiveColor(spanStyle.color!, isDarkMode()));
        }
        charStyles[i] = charStyles[i].merge(spanStyle);
      }
    }

    // Apply inline image tag styling (renders as styled text, no WidgetSpan crash)
    final imageRegex = RegExp(r'!\[(.*?)\]\((.*?)\)');
    for (final match in imageRegex.allMatches(text)) {
      final int mStart  = match.start.clamp(0, len);
      final int mEnd    = match.end.clamp(0, len);
      final int altStart = (mStart + 2).clamp(0, len);
      final int altEnd   = (altStart + (match.group(1) ?? '').length).clamp(0, len);
      final int pathStart = (altEnd + 1).clamp(0, len); // ']('
      final int pathEnd   = mEnd;

      for (int i = mStart;    i < altStart  && i < len; i++) charStyles[i] = const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold);
      for (int i = altStart;  i < altEnd    && i < len; i++) charStyles[i] = const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline);
      for (int i = altEnd;    i < pathStart && i < len; i++) charStyles[i] = const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold);
      for (int i = pathStart; i < pathEnd   && i < len; i++) charStyles[i] = const TextStyle(fontSize: 0, color: Colors.transparent);
    }

    // Quote/bullet paragraph formatting — with bounds guard
    final quoteRegex  = RegExp(r'(^|\n)>\s*(.*)');
    final bulletRegex = RegExp(r'(^|\n)[•\*\-]\s+(.*)');

    void applyParagraphStyle(RegExp regex, TextStyle paraStyle) {
      for (final match in regex.allMatches(text)) {
        int startIdx = match.start.clamp(0, len);
        if (startIdx < len && text[startIdx] == '\n') startIdx++;
        final int endIdx = match.end.clamp(0, len);
        for (int i = startIdx; i < endIdx; i++) {
          charStyles[i] = charStyles[i].merge(paraStyle);
        }
      }
    }

    applyParagraphStyle(
      quoteRegex,
      TextStyle(fontStyle: FontStyle.italic, color: isDarkMode() ? Colors.grey.shade400 : Colors.grey.shade600),
    );
    applyParagraphStyle(
      bulletRegex,
      const TextStyle(fontWeight: FontWeight.w500),
    );

    // Build final TextSpan list by grouping consecutive same-style chars
    final List<TextSpan> children = [];
    int start = 0;
    TextStyle currentStyle = charStyles[0];
    for (int i = 1; i < len; i++) {
      if (charStyles[i] != currentStyle) {
        children.add(TextSpan(text: text.substring(start, i), style: currentStyle));
        start = i;
        currentStyle = charStyles[i];
      }
    }
    children.add(TextSpan(text: text.substring(start), style: currentStyle));

    return TextSpan(children: children, style: style);
  }


}

class _ParagraphFormatRange {
  final int start;
  final int end;
  final TextStyle style;

  _ParagraphFormatRange({required this.start, required this.end, required this.style});
}

class ParsedMarkdown {
  final String plainText;
  final List<_StyleSpan> spans;
  ParsedMarkdown({required this.plainText, required this.spans});
}

class ColorSyntax extends md.InlineSyntax {
  // dotAll:true so it spans across line breaks inside the tag
  ColorSyntax() : super(r'<color=(#[0-9a-fA-F]{6}|[a-zA-Z]+)>([\s\S]*?)</color>');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final colorVal = match.group(1) ?? '';
    final innerMarkdown = match.group(2) ?? '';

    // Parse the inner content so **bold** and *italic* inside color work
    final innerDocument = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );
    // Parse inline content from inner markdown string
    final innerNodes = innerDocument.parseInline(innerMarkdown);

    final element = md.Element('color', innerNodes);
    element.attributes['value'] = colorVal;
    parser.addNode(element);
    return true;
  }
}

class ColorElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  final bool isDarkMode;
  ColorElementBuilder(this.context, {required this.isDarkMode});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final baseStyle = preferredStyle ?? const TextStyle();
    return Text.rich(
      _buildSpan(element, baseStyle),
    );
  }

  TextSpan _buildSpan(md.Node node, TextStyle baseStyle) {
    if (node is md.Text) {
      return TextSpan(text: node.text, style: baseStyle);
    }
    if (node is md.Element) {
      TextStyle style = baseStyle;
      if (node.tag == 'strong' || node.tag == 'b') {
        style = style.copyWith(fontWeight: FontWeight.bold);
      }
      if (node.tag == 'em' || node.tag == 'i') {
        style = style.copyWith(fontStyle: FontStyle.italic);
      }
      if (node.tag == 'color') {
        final colorStr = node.attributes['value'] ?? '';
        Color? tagColor;
        if (colorStr.startsWith('#')) {
          final hex = colorStr.substring(1);
          final val = int.tryParse(hex, radix: 16);
          if (val != null) {
            tagColor = Color(val | 0xFF000000);
          }
        } else {
          switch (colorStr.toLowerCase()) {
            case 'red': tagColor = Colors.red; break;
            case 'blue': tagColor = Colors.blue; break;
            case 'green': tagColor = Colors.green; break;
            case 'yellow': tagColor = Colors.yellow; break;
            case 'orange': tagColor = Colors.orange; break;
            case 'purple': tagColor = Colors.purple; break;
            case 'pink': tagColor = Colors.pink; break;
            case 'teal': tagColor = Colors.teal; break;
          }
        }
        if (tagColor != null) {
          style = style.copyWith(color: getAdaptiveColor(tagColor, isDarkMode));
        }
      }
      
      return TextSpan(
        children: node.children?.map((c) => _buildSpan(c, style)).toList(),
        style: style,
      );
    }
    return const TextSpan();
  }
}

class InlineImageWidget extends StatefulWidget {
  final String pathWithParams;
  final void Function(String newPathWithParams) onChanged;
  final VoidCallback onDelete;

  const InlineImageWidget({super.key, required this.pathWithParams, required this.onChanged, required this.onDelete});

  @override
  State<InlineImageWidget> createState() => _InlineImageWidgetState();
}

class _InlineImageWidgetState extends State<InlineImageWidget> {
  late double _rotation;
  late double _shadow;
  late double _cropFactor;
  late String _basePath;

  @override
  void initState() {
    super.initState();
    _parseParams();
  }

  @override
  void didUpdateWidget(InlineImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pathWithParams != widget.pathWithParams) {
      _parseParams();
    }
  }

  void _parseParams() {
    try {
      final uri = Uri.parse(widget.pathWithParams);
      _basePath = uri.path;
      _rotation = double.tryParse(uri.queryParameters['rotate'] ?? '0') ?? 0;
      _shadow = double.tryParse(uri.queryParameters['shadow'] ?? '0') ?? 0;
      _cropFactor = double.tryParse(uri.queryParameters['crop'] ?? '1.0') ?? 1.0;
    } catch (e) {
      _basePath = widget.pathWithParams;
      _rotation = 0;
      _shadow = 0;
      _cropFactor = 1.0;
    }
  }

  void _updateParams() {
    final newPath = '$_basePath?rotate=${_rotation.toInt()}&shadow=${_shadow.toInt()}&crop=$_cropFactor';
    widget.onChanged(newPath);
  }

  void _showEditDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Edit Image', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  
                  // Rotate option
                  ListTile(
                    leading: const Icon(Icons.rotate_right_rounded, color: Colors.blueAccent),
                    title: const Text('Rotate 90°', style: TextStyle(color: Colors.black87)),
                    trailing: Text('${_rotation.toInt()}°', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                    onTap: () {
                      setState(() {
                        _rotation = (_rotation + 90) % 360;
                      });
                      setModalState(() {});
                      _updateParams();
                    },
                  ),
                  
                  // Shadow option — vignette overlay on image
                  ListTile(
                    leading: const Icon(Icons.brightness_3_rounded, color: Colors.blueGrey),
                    title: const Text('Vignette Shadow', style: TextStyle(color: Colors.black87)),
                    subtitle: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.blueAccent,
                        inactiveTrackColor: Colors.blueAccent.withValues(alpha: 0.2),
                        thumbColor: Colors.blueAccent,
                        overlayColor: Colors.blueAccent.withValues(alpha: 0.15),
                      ),
                      child: Slider(
                        value: _shadow,
                        min: 0,
                        max: 20,
                        divisions: 10,
                        onChanged: (v) {
                          setState(() { _shadow = v; });
                          setModalState(() {});
                          _updateParams();
                        },
                      ),
                    ),
                    trailing: Text('${_shadow.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                  ),
                  
                  // Crop option
                  ListTile(
                    leading: const Icon(Icons.crop_rounded, color: Colors.green),
                    title: const Text('Crop / Zoom Factor', style: TextStyle(color: Colors.black87)),
                    subtitle: Slider(
                      value: _cropFactor,
                      min: 0.5,
                      max: 1.0,
                      onChanged: (v) {
                        setState(() {
                          _cropFactor = v;
                        });
                        setModalState(() {});
                        _updateParams();
                      },
                    ),
                    trailing: Text('${(_cropFactor * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                  ),
                  
                  // Delete option
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                    title: const Text('Delete Image', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onDelete();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNetwork = _basePath.startsWith('http') || _basePath.startsWith('https') || _basePath.startsWith('blob:');
    
    Widget imageWidget;
    if (isNetwork) {
      imageWidget = Image.network(
        _basePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 120,
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
        ),
      );
    } else {
      if (kIsWeb) {
        imageWidget = Container(
          height: 120,
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
        );
      } else {
        imageWidget = Image.file(
          File(_basePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 120,
            color: Colors.grey.shade200,
            child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
          ),
        );
      }
    }

    if (_cropFactor < 1.0) {
      imageWidget = ClipRect(
        child: Align(
          alignment: Alignment.center,
          widthFactor: _cropFactor,
          heightFactor: _cropFactor,
          child: imageWidget,
        ),
      );
    }

    // Vignette shadow overlay ON the image itself
    if (_shadow > 0) {
      final double opacity = (_shadow / 20.0).clamp(0.0, 0.75);
      imageWidget = Stack(
        children: [
          imageWidget,
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: opacity)],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final int quarters = (_rotation ~/ 90) % 4;
    if (quarters > 0) {
      imageWidget = RotatedBox(quarterTurns: quarters, child: imageWidget);
    }

    return GestureDetector(
      onTap: _showEditDialog,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageWidget,
        ),
      ),
    );
  }
}

class _NoteDetailImageWidget extends StatelessWidget {
  final String pathWithParams;
  const _NoteDetailImageWidget({required this.pathWithParams});

  @override
  Widget build(BuildContext context) {
    String basePath = pathWithParams;
    double rotation = 0;
    double shadow = 0;
    double cropFactor = 1.0;

    try {
      final uri = Uri.parse(pathWithParams);
      basePath = uri.path;
      rotation = double.tryParse(uri.queryParameters['rotate'] ?? '0') ?? 0;
      shadow = double.tryParse(uri.queryParameters['shadow'] ?? '0') ?? 0;
      cropFactor = double.tryParse(uri.queryParameters['crop'] ?? '1.0') ?? 1.0;
    } catch (e) {
      basePath = pathWithParams;
    }

    final isNetwork = basePath.startsWith('http') || basePath.startsWith('https') || basePath.startsWith('blob:');
    
    Widget imageWidget;
    if (isNetwork) {
      imageWidget = Image.network(
        basePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 120,
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
        ),
      );
    } else {
      if (kIsWeb) {
        imageWidget = Container(
          height: 120,
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
        );
      } else {
        imageWidget = Image.file(
          File(basePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 120,
            color: Colors.grey.shade200,
            child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
          ),
        );
      }
    }

    if (cropFactor < 1.0) {
      imageWidget = ClipRect(
        child: Align(
          alignment: Alignment.center,
          widthFactor: cropFactor,
          heightFactor: cropFactor,
          child: imageWidget,
        ),
      );
    }

    final int quarters = (rotation ~/ 90) % 4;
    if (quarters > 0) {
      imageWidget = RotatedBox(quarterTurns: quarters, child: imageWidget);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        boxShadow: shadow > 0 ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: shadow,
            spreadRadius: shadow / 4,
          )
        ] : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imageWidget,
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
  final TextEditingController _roomNameCtrl = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingProof = false;

  // Generate 6 character random code
  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = math.Random();
    return List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  void _enterRoom(String code) {
    setState(() {
      _roomCode = code;
      _inRoom = true;
    });
    _cleanupExpiredProofs();
  }

  Future<void> _cleanupExpiredProofs() async {
    if (_roomCode.isEmpty) return;
    final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
    try {
      final query = await FirebaseFirestore.instance
          .collection('study_rooms')
          .doc(_roomCode)
          .collection('proofs')
          .where('timestamp', isLessThan: Timestamp.fromDate(twentyFourHoursAgo))
          .get();
      for (var doc in query.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint("Error cleaning up expired proofs: $e");
    }
  }

  Future<void> _createRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in first!')));
      return;
    }

    String roomName = _roomNameCtrl.text.trim();
    if (roomName.isEmpty) {
      roomName = '${user.displayName ?? 'Student'}\'s Study Room';
    }

    final code = 'RM-${_generateRoomCode()}';

    try {
      await FirebaseFirestore.instance.collection('study_rooms').doc(code).set({
        'roomId': code,
        'name': roomName,
        'creatorId': user.uid,
        'creatorName': user.displayName ?? 'Anonymous',
        'createdAt': FieldValue.serverTimestamp(),
        'participants': [user.uid],
        'participantNames': {user.uid: user.displayName ?? 'Anonymous'},
        'admins': [user.uid],
      });

      _roomNameCtrl.clear();
      _enterRoom(code);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Room $code created successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating room: $e')));
      }
    }
  }

  Future<void> _joinRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in first!')));
      return;
    }

    final code = _joinCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a room code!')));
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('study_rooms').doc(code).get();
      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room not found! Please check the code.')));
        }
        return;
      }

      await FirebaseFirestore.instance.collection('study_rooms').doc(code).update({
        'participants': FieldValue.arrayUnion([user.uid]),
        'participantNames.${user.uid}': user.displayName ?? 'Anonymous',
      });

      _joinCodeCtrl.clear();
      _enterRoom(code);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Joined Room $code!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error joining room: $e')));
      }
    }
  }

  Future<void> _leaveRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('study_rooms').doc(_roomCode).update({
        'participants': FieldValue.arrayRemove([user.uid]),
      });
      setState(() {
        _inRoom = false;
        _roomCode = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Left the room.')));
      }
    } catch (e) {
      setState(() {
        _inRoom = false;
        _roomCode = '';
      });
    }
  }

  Future<void> _requestProof(String targetId, String targetName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('study_rooms')
          .doc(_roomCode)
          .collection('proof_requests')
          .add({
        'fromId': user.uid,
        'fromName': user.displayName ?? 'Anonymous',
        'toId': targetId,
        'toName': targetName,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'seen': false,
        'seenAt': null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Study proof requested from $targetName. Waiting for upload...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error requesting proof: $e')));
      }
    }
  }

  Future<void> _confirmInviteFriend(String friendId, String friendName, bool isAdmin) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final title = isAdmin ? 'Add Member (মেম্বার যুক্ত করুন)'.tr() : 'Invite Friend (বন্ধু আমন্ত্রণ)'.tr();
    final message = isAdmin
        ? 'Do you want to add $friendName directly to this study room?'.tr()
        : 'Do you want to send a request to add $friendName to the Admin for approval?'.tr();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (isAdmin) {
        try {
          await FirebaseFirestore.instance.collection('study_rooms').doc(_roomCode).update({
            'participants': FieldValue.arrayUnion([friendId]),
            'participantNames.$friendId': friendName,
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$friendName added directly to the room!'.tr())),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to add member: $e'.tr())),
            );
          }
        }
      } else {
        try {
          await FirebaseFirestore.instance
              .collection('study_rooms')
              .doc(_roomCode)
              .collection('member_requests')
              .doc(friendId)
              .set({
            'requesterId': user.uid,
            'requesterName': user.displayName ?? 'Anonymous',
            'invitedId': friendId,
            'invitedName': friendName,
            'status': 'pending',
            'timestamp': FieldValue.serverTimestamp(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invitation request sent to the Admin!'.tr())),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to send invite request: $e'.tr())),
            );
          }
        }
      }
    }
  }

  void _showAddMemberSheet(List<String> currentParticipants, String creatorId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('friends')
              .where('status', isEqualTo: 'accepted')
              .snapshots(),
          builder: (context, friendsSnap) {
            if (friendsSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = friendsSnap.data?.docs ?? [];
            final inviteableFriends = docs.where((d) => !currentParticipants.contains(d.id)).toList();

            if (inviteableFriends.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text('No inviteable friends found.'.tr(), style: const TextStyle(color: Colors.grey)),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Invite Friends to Room'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: inviteableFriends.length,
                      itemBuilder: (context, index) {
                        final fId = inviteableFriends[index].id;

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(fId).get(),
                          builder: (ctx, userSnap) {
                            if (!userSnap.hasData) {
                              return const ListTile(
                                leading: CircleAvatar(child: Icon(Icons.person)),
                                title: Text('Loading Buddy...'),
                              );
                            }

                            final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                            final fName = userData['displayName'] ?? 'Study Buddy';
                            final photoUrl = userData['photoUrl'] as String?;
                            ImageProvider? avatarImage;
                            if (photoUrl != null && photoUrl.isNotEmpty) {
                              avatarImage = photoUrl.startsWith('http')
                                  ? NetworkImage(photoUrl)
                                  : FileImage(File(photoUrl)) as ImageProvider;
                            }

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: avatarImage,
                                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                child: avatarImage == null ? Icon(Icons.person, color: Theme.of(context).colorScheme.primary) : null,
                              ),
                              title: Text(fName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle_rounded, color: Colors.green),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _confirmInviteFriend(fId, fName, user.uid == creatorId);
                                },
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
      },
    );
  }

  Future<void> _uploadProofImage(String requestId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 30,
        maxWidth: 400,
        maxHeight: 400,
      );
      if (pickedFile == null) return;

      setState(() => _isUploadingProof = true);

      // Convert image file to Base64 data string
      String base64ImageUrl;
      try {
        final bytes = await pickedFile.readAsBytes();
        final base64String = base64Encode(bytes);
        base64ImageUrl = 'data:image/jpeg;base64,$base64String';
      } catch (e) {
        throw 'Failed to read and encode image: $e';
      }

      // Write proof document to Firestore
      try {
        await FirebaseFirestore.instance
            .collection('study_rooms')
            .doc(_roomCode)
            .collection('proofs')
            .add({
          'senderId': user.uid,
          'senderName': user.displayName ?? 'Anonymous',
          'imageUrl': base64ImageUrl,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        throw 'Firestore Save Proof Failed: $e';
      }

      // Complete request in Firestore
      if (requestId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('study_rooms')
              .doc(_roomCode)
              .collection('proof_requests')
              .doc(requestId)
              .update({'status': 'completed'});
        } catch (e) {
          throw 'Firestore Update Request Failed: $e';
        }
      }

      setState(() => _isUploadingProof = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Study proof uploaded successfully!')));
      }
    } catch (e) {
      setState(() => _isUploadingProof = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  Future<void> _uploadProofVoluntarily() async {
    await _uploadProofImage('');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Study Partner Room')),
        body: const Center(child: Text('Please log in to access Study Partner Rooms.')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(_inRoom ? 'Study Room: $_roomCode' : 'Study Partner Room'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: _inRoom
            ? [
                IconButton(
                  tooltip: 'Leave Room',
                  icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
                  onPressed: _leaveRoom,
                )
              ]
            : null,
      ),
      body: _inRoom ? _buildRoomUI(user) : _buildJoinCreateUI(user),
    );
  }

  Widget _buildJoinCreateUI(User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Icon(Icons.video_camera_front_rounded, size: 80, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Study Together'.tr(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Create a room and invite your friends to study together and track progress.'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),
          
          // Create Room Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create a New Room'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _roomNameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter room name (optional)'.tr(),
                      prefixIcon: const Icon(Icons.label_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _createRoom,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: Text('Create New Room'.tr()),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          // Join Room Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Join Room'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _joinCodeCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter Room Code (e.g. RM-XXXXXX)'.tr(),
                      prefixIcon: const Icon(Icons.meeting_room_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _joinRoom,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                    child: Text('Join Room'.tr()),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),

          // Your Rooms Section
          Text('Your Rooms (তোমার রুমসমূহ)'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('study_rooms')
                .where('participants', arrayContains: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text(
                      'You are not in any rooms yet.'.tr(),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final roomData = docs[index].data() as Map<String, dynamic>;
                  final name = roomData['name'] ?? 'Study Room';
                  final code = roomData['roomId'] ?? '';
                  final participants = List<String>.from(roomData['participants'] ?? []);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(Icons.school_rounded, color: Theme.of(context).colorScheme.primary),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${'Code:'.tr()} $code • ${participants.length} ${'members'.tr()}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Room code copied!'.tr())));
                            },
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          _roomCode = code;
                          _inRoom = true;
                        });
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoomUI(User user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('study_rooms').doc(_roomCode).snapshots(),
      builder: (context, roomSnap) {
        if (roomSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!roomSnap.hasData || !roomSnap.data!.exists) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Room not found or has been deleted.'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _inRoom = false;
                      _roomCode = '';
                    });
                  },
                  child: Text('Go Back'.tr()),
                ),
              ],
            ),
          );
        }

        final roomData = roomSnap.data!.data() as Map<String, dynamic>;
        final name = roomData['name'] ?? 'Study Room';
        final code = roomData['roomId'] ?? '';
        final participants = List<String>.from(roomData['participants'] ?? []);
        final participantNames = Map<String, dynamic>.from(roomData['participantNames'] ?? {});
        final creatorId = roomData['creatorId'] ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Room Header Summary
            Container(
              padding: const EdgeInsets.all(20),
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('${'Room Code:'.tr()} $code', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Room code copied!'.tr())));
                    },
                    icon: const Icon(Icons.copy_rounded),
                  ),
                ],
              ),
            ),

            // Pending Proof Requests for Me (With 30-Second dismiss countdowns)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('study_rooms')
                  .doc(_roomCode)
                  .collection('proof_requests')
                  .where('toId', isEqualTo: user.uid)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, requestsSnap) {
                final requests = requestsSnap.data?.docs ?? [];
                if (requests.isEmpty) return const SizedBox.shrink();

                return Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: requests.map((reqDoc) {
                      return ProofRequestBanner(
                        requestDoc: reqDoc,
                        onUpload: _uploadProofImage,
                      );
                    }).toList(),
                  ),
                );
              },
            ),

            // Pending Member Requests (Only for Admin)
            if (user.uid == creatorId)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('study_rooms')
                    .doc(_roomCode)
                    .collection('member_requests')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, requestsSnap) {
                  if (requestsSnap.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  final requests = requestsSnap.data?.docs ?? [];
                  if (requests.isEmpty) return const SizedBox.shrink();

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.amber.shade50,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.amber.shade200, width: 1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.group_add_rounded, color: Colors.amber),
                              const SizedBox(width: 8),
                              Text(
                                'New Member Requests (মেম্বার রিকোয়েস্ট)'.tr(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.brown),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: requests.length,
                            itemBuilder: (context, idx) {
                              final reqData = requests[idx].data() as Map<String, dynamic>;
                              final reqId = requests[idx].id;
                              final invitedName = reqData['invitedName'] ?? 'Friend';
                              final invitedId = reqData['invitedId'] ?? '';
                              final requesterName = reqData['requesterName'] ?? 'Member';

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '$invitedName (${'Invited by'.tr()} $requesterName)',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                                          onPressed: () async {
                                            await FirebaseFirestore.instance.collection('study_rooms').doc(_roomCode).update({
                                              'participants': FieldValue.arrayUnion([invitedId]),
                                              'participantNames.$invitedId': invitedName,
                                            });
                                            await FirebaseFirestore.instance
                                                .collection('study_rooms')
                                                .doc(_roomCode)
                                                .collection('member_requests')
                                                .doc(reqId)
                                                .update({'status': 'accepted'});
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.cancel_rounded, color: Colors.red, size: 24),
                                          onPressed: () async {
                                            await FirebaseFirestore.instance
                                                .collection('study_rooms')
                                                .doc(_roomCode)
                                                .collection('member_requests')
                                                .doc(reqId)
                                                .update({'status': 'rejected'});
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            // Active Members Heading & Invite/Upload Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text('Active Members'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showAddMemberSheet(participants, creatorId),
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: Text('Invite'.tr()),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      _isUploadingProof
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : TextButton.icon(
                              onPressed: _uploadProofVoluntarily,
                              icon: const Icon(Icons.upload_file_rounded, size: 18),
                              label: Text('Upload My Proof'.tr()),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ),

            // Active Members List
            Expanded(
              flex: 2,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: participants.length,
                itemBuilder: (context, index) {
                  final mId = participants[index];
                  final mName = participantNames[mId] ?? 'Anonymous';
                  final isMe = mId == user.uid;
                  final isAdmin = mId == creatorId;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isMe ? Colors.green.shade100 : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(Icons.person, color: isMe ? Colors.green : Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(
                      isMe ? '$mName (${'You'.tr()})' : mName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isAdmin ? 'Admin'.tr() : 'Member'.tr(),
                      style: TextStyle(fontSize: 12, color: isAdmin ? Colors.deepOrange : Colors.grey),
                    ),
                    trailing: isMe
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.camera_alt_rounded, color: Colors.deepPurpleAccent),
                            tooltip: 'Request Study Proof'.tr(),
                            onPressed: () => _requestProof(mId, mName),
                          ),
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Proof Gallery Heading
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text('Study Proofs (Last 24h)'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),

            // Proofs Gallery Grid
            Expanded(
              flex: 3,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('study_rooms')
                    .doc(_roomCode)
                    .collection('proofs')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, proofsSnap) {
                  if (proofsSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allProofs = proofsSnap.data?.docs ?? [];
                  final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
                  final proofs = allProofs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final timestamp = data['timestamp'] as Timestamp?;
                    if (timestamp == null) return true;
                    return timestamp.toDate().isAfter(twentyFourHoursAgo);
                  }).toList();

                  if (proofs.isEmpty) {
                    return Center(
                      child: Text(
                        'No proofs uploaded yet.'.tr(),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: proofs.length,
                    itemBuilder: (context, index) {
                      final pData = proofs[index].data() as Map<String, dynamic>;
                      final senderName = pData['senderName'] ?? 'Someone';
                      final imageUrl = pData['imageUrl'] ?? '';
                      final timestamp = pData['timestamp'] as Timestamp?;
                      String timeStr = '';
                      if (timestamp != null) {
                        timeStr = DateFormat('hh:mm a').format(timestamp.toDate());
                      }

                      return GestureDetector(
                        onTap: () {
                          // Show enlarged photo dialog
                          showDialog(
                            context: context,
                            builder: (ctx) => Dialog(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  imageUrl.startsWith('data:image/')
                                      ? Image.memory(
                                          base64Decode(imageUrl.split(',').last),
                                          fit: BoxFit.contain,
                                        )
                                      : Image.network(imageUrl, fit: BoxFit.contain),
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      '${'Uploaded by'.tr()} $senderName ${'at'.tr()} $timeStr',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            image: DecorationImage(
                              image: _getProofImageProvider(imageUrl),
                              fit: BoxFit.cover,
                            ),
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
                                Text(
                                  senderName,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(timeStr, style: const TextStyle(color: Colors.white70, fontSize: 10)),
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
        );
      },
    );
  }

  ImageProvider _getProofImageProvider(String imageUrl) {
    if (imageUrl.startsWith('data:image/')) {
      final base64Str = imageUrl.split(',').last;
      return MemoryImage(base64Decode(base64Str));
    }
    return NetworkImage(imageUrl);
  }
}

// Stateful helper widget for 30 seconds countdown auto-dismissal
class ProofRequestBanner extends StatefulWidget {
  final DocumentSnapshot requestDoc;
  final Function(String) onUpload;

  const ProofRequestBanner({super.key, required this.requestDoc, required this.onUpload});

  @override
  State<ProofRequestBanner> createState() => _ProofRequestBannerState();
}

class _ProofRequestBannerState extends State<ProofRequestBanner> {
  Timer? _timer;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() async {
    final data = widget.requestDoc.data() as Map<String, dynamic>? ?? {};
    final bool seen = data['seen'] ?? false;
    final Timestamp? seenAt = data['seenAt'] as Timestamp?;

    if (!seen) {
      // Mark as seen and initialize timer locally
      try {
        await widget.requestDoc.reference.update({
          'seen': true,
          'seenAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint("Error updating seen status: $e");
      }
      _secondsLeft = 30;
    } else if (seenAt != null) {
      final elapsed = DateTime.now().difference(seenAt.toDate()).inSeconds;
      _secondsLeft = 30 - elapsed;
      if (_secondsLeft <= 0) {
        _secondsLeft = 0;
        _expireRequest();
        return;
      }
    } else {
      _secondsLeft = 30;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          timer.cancel();
          _expireRequest();
        }
      });
    });
  }

  Future<void> _expireRequest() async {
    try {
      await widget.requestDoc.reference.update({'status': 'expired'});
    } catch (e) {
      debugPrint("Error expiring request: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_secondsLeft <= 0) return const SizedBox.shrink();

    final data = widget.requestDoc.data() as Map<String, dynamic>? ?? {};
    final fromName = data['fromName'] ?? 'Someone';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade800.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.add_a_photo_rounded, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$fromName ${'requested a study proof!'.tr()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '${'Camera capture only. Autodismiss in'.tr()} ${_secondsLeft}s',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => widget.onUpload(widget.requestDoc.id),
            icon: const Icon(Icons.camera_alt_rounded, size: 14),
            label: Text('Upload'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.amber.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            ),
          ),
        ],
      ),
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
  bool _inRoom = false;
  String _roomCode = '';
  String? _selectedPartnerId;
  final TextEditingController _joinCodeCtrl = TextEditingController();
  final TextEditingController _roomNameCtrl = TextEditingController();

  bool _isWarningDialogShowing = false;

  void _checkAnalyticsAndWarnings(User user, List<QueryDocumentSnapshot> taskDocs, Map<String, dynamic> roomData) {
    if (taskDocs.isEmpty) {
      final warningsMap = roomData['warnings'] as Map<String, dynamic>? ?? {};
      if (warningsMap[user.uid] != null) {
        _resetWarningCount(user.uid);
      }
      return;
    }

    // 1. Check who has completed >= 80% of ALL tasks in the room
    final participants = List<String>.from(roomData['participants'] ?? []);
    int helpersWith80Percent = 0;
    
    for (final pId in participants) {
      final completed = taskDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final completedUsers = List<String>.from(data['completedUsers'] ?? []);
        final oldIsCompleted = data['isCompleted'] ?? false;
        final oldCompletedBy = data['completedBy'];
        return completedUsers.contains(pId) || (oldIsCompleted && oldCompletedBy == pId);
      }).length;
      
      final rate = completed / taskDocs.length;
      if (rate >= 0.8) {
        helpersWith80Percent++;
      }
    }

    final completedCount = taskDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final completedUsers = List<String>.from(data['completedUsers'] ?? []);
      final oldIsCompleted = data['isCompleted'] ?? false;
      final oldCompletedBy = data['completedBy'];
      return completedUsers.contains(user.uid) || (oldIsCompleted && oldCompletedBy == user.uid);
    }).length;

    final completionRate = completedCount / taskDocs.length;

    final warningsMap = roomData['warnings'] as Map<String, dynamic>? ?? {};
    final userWarningData = warningsMap[user.uid] as Map<String, dynamic>?;

    if (completionRate >= 0.8) {
      if (userWarningData != null && (userWarningData['count'] ?? 0) > 0) {
        _resetWarningCount(user.uid);
      }
      return;
    }

    // 2. Check if warning system should be active (at least 2 people completed >= 80%)
    if (helpersWith80Percent < 2) {
      // Warning system is inactive because less than 2 people reached 80%
      if (userWarningData != null && (userWarningData['count'] ?? 0) > 0) {
        _resetWarningCount(user.uid);
      }
      return;
    }

    // Otherwise, completion rate is < 80% and warning system is active!
    int warningCount = userWarningData?['count'] ?? 0;
    DateTime? lastWarningTime;
    if (userWarningData?['lastWarningTime'] != null) {
      lastWarningTime = DateTime.tryParse(userWarningData!['lastWarningTime']);
    }

    final now = DateTime.now();

    if (warningCount == 0) {
      _showWarningPopup(user.uid, 1, now);
    } else if (warningCount < 3) {
      if (lastWarningTime != null && now.difference(lastWarningTime).inHours >= 3) {
        _showWarningPopup(user.uid, warningCount + 1, now);
      }
    } else {
      if (lastWarningTime != null && now.difference(lastWarningTime).inHours >= 3) {
        _kickOutUser(user.uid, user.displayName ?? 'Anonymous');
      }
    }
  }

  void _showWarningPopup(String userId, int count, DateTime now) async {
    if (_isWarningDialogShowing) return;
    _isWarningDialogShowing = true;

    await FirebaseFirestore.instance.collection('partner_rooms').doc(_roomCode).update({
      'warnings.$userId.count': count,
      'warnings.$userId.lastWarningTime': now.toIso8601String(),
    });

    if (!mounted) {
      _isWarningDialogShowing = false;
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            '${'Warning'.tr()} ($count/3)',
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'You have not completed 80% of your shared tasks. Please complete them. If you still do not complete them after being warned 3 times every 3 hours, you will be removed from this partner space.'.tr()
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _isWarningDialogShowing = false;
              },
              child: Text('OK'.tr()),
            ),
          ],
        );
      }
    ).then((_) {
      _isWarningDialogShowing = false;
    });
  }

  void _resetWarningCount(String userId) async {
    await FirebaseFirestore.instance.collection('partner_rooms').doc(_roomCode).update({
      'warnings.$userId': FieldValue.delete(),
    });
  }

  void _kickOutUser(String userId, String userName) async {
    await FirebaseFirestore.instance.collection('partner_rooms').doc(_roomCode).update({
      'participants': FieldValue.arrayRemove([userId]),
      'participantNames.$userId': FieldValue.delete(),
      'warnings.$userId': FieldValue.delete(),
    });
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = math.Random();
    return List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> _createSpace() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String name = _roomNameCtrl.text.trim();
    if (name.isEmpty) {
      name = '${user.displayName ?? 'Student'}\'s Partner Space';
    }

    final code = 'PR-${_generateRoomCode()}';

    try {
      await FirebaseFirestore.instance.collection('partner_rooms').doc(code).set({
        'roomId': code,
        'name': name,
        'creatorId': user.uid,
        'creatorName': user.displayName ?? 'Anonymous',
        'createdAt': FieldValue.serverTimestamp(),
        'participants': [user.uid],
        'participantNames': {user.uid: user.displayName ?? 'Anonymous'},
      });

      setState(() {
        _roomCode = code;
        _inRoom = true;
        _roomNameCtrl.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Space $code created!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _joinSpace() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final code = _joinCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('partner_rooms').doc(code).get();
      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Partner Space not found!')));
        }
        return;
      }

      await FirebaseFirestore.instance.collection('partner_rooms').doc(code).update({
        'participants': FieldValue.arrayUnion([user.uid]),
        'participantNames.${user.uid}': user.displayName ?? 'Anonymous',
      });

      setState(() {
        _roomCode = code;
        _inRoom = true;
        _joinCodeCtrl.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _leaveSpace() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _cleanupLocalHistoryForRoom(_roomCode, user.uid);
      await FirebaseFirestore.instance.collection('partner_rooms').doc(_roomCode).update({
        'participants': FieldValue.arrayRemove([user.uid]),
      });
      setState(() {
        _inRoom = false;
        _roomCode = '';
      });
    } catch (e) {
      setState(() {
        _inRoom = false;
        _roomCode = '';
      });
    }
  }

  Future<void> _confirmAddPartner(String friendId, String friendName, bool isAdmin, List<String> currentParticipants) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (currentParticipants.length >= 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Partner Space is full (Maximum 4 partners).'.tr())),
        );
      }
      return;
    }

    final title = isAdmin ? 'Add Partner (পার্টনার যুক্ত করুন)'.tr() : 'Request Partner (পার্টনার রিকোয়েস্ট)'.tr();
    final message = isAdmin
        ? 'Do you want to add $friendName directly as a partner in this space?'.tr()
        : 'Do you want to send a request to add $friendName to the Admin for approval?'.tr();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: Text('Yes'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (isAdmin) {
        await _addPartnerDirectly(friendId, friendName);
      } else {
        // Send request to Admin
        try {
          await FirebaseFirestore.instance
              .collection('partner_rooms')
              .doc(_roomCode)
              .collection('member_requests')
              .add({
            'invitedId': friendId,
            'invitedName': friendName,
            'requesterId': user.uid,
            'requesterName': user.displayName ?? 'Anonymous',
            'status': 'pending',
            'timestamp': FieldValue.serverTimestamp(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Request sent to Admin to add $friendName.'.tr())),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to send request: $e'.tr())),
            );
          }
        }
      }
    }
  }

  Future<void> _addPartnerDirectly(String friendId, String friendName) async {
    try {
      await FirebaseFirestore.instance.collection('partner_rooms').doc(_roomCode).update({
        'participants': FieldValue.arrayUnion([friendId]),
        'participantNames.$friendId': friendName,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $friendName as partner!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddPartnerSheet(List<String> currentParticipants, String creatorId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('friends')
              .where('status', isEqualTo: 'accepted')
              .snapshots(),
          builder: (context, friendsSnap) {
            if (friendsSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = friendsSnap.data?.docs ?? [];
            final inviteableFriends = docs.where((d) => !currentParticipants.contains(d.id)).toList();

            if (inviteableFriends.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text('No inviteable friends found.'.tr(), style: const TextStyle(color: Colors.grey)),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Add a Partner'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: inviteableFriends.length,
                      itemBuilder: (context, index) {
                        final fId = inviteableFriends[index].id;

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(fId).get(),
                          builder: (ctx, userSnap) {
                            if (!userSnap.hasData) {
                              return const ListTile(
                                leading: CircleAvatar(child: Icon(Icons.person)),
                                title: Text('Loading Buddy...'),
                              );
                            }

                            final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                            final fName = userData['displayName'] ?? 'Study Buddy';
                            final photoUrl = userData['photoUrl'] as String?;
                            ImageProvider? avatarImage;
                            if (photoUrl != null && photoUrl.isNotEmpty) {
                              avatarImage = photoUrl.startsWith('http')
                                  ? NetworkImage(photoUrl)
                                  : FileImage(File(photoUrl)) as ImageProvider;
                            }

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: avatarImage,
                                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                child: avatarImage == null ? Icon(Icons.person, color: Theme.of(context).colorScheme.primary) : null,
                              ),
                              title: Text(fName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: IconButton(
                                icon: const Icon(Icons.person_add_rounded, color: Colors.green),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _confirmAddPartner(fId, fName, user.uid == creatorId, currentParticipants);
                                },
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
      },
    );
  }

  Future<List<Task>> _fetchUserRoutineTasks(String userId) async {
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

    return [...dailyTasks, ...weeklyTasks];
  }

  Future<void> _showPartnersTasksSheet(List<String> participants, Map<String, dynamic> participantNames) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final otherPartners = participants.where((id) => id != user.uid).toList();
    if (otherPartners.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No other partners in this space yet.'.tr())),
        );
      }
      return;
    }

    // Default select first partner if not set
    if (_selectedPartnerId == null || !otherPartners.contains(_selectedPartnerId)) {
      _selectedPartnerId = otherPartners.first;
    }

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Partners' Tasks (পার্টনারদের টাস্ক)".tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Select Partner list
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: otherPartners.length,
                      itemBuilder: (ctx, idx) {
                        final pId = otherPartners[idx];
                        final pName = participantNames[pId] ?? 'Partner';
                        final isSelected = _selectedPartnerId == pId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(pName),
                            selected: isSelected,
                            onSelected: (val) {
                              setModalState(() {
                                _selectedPartnerId = pId;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _selectedPartnerId == null
                        ? Center(child: Text('Select a partner to view tasks.'.tr(), style: const TextStyle(color: Colors.grey)))
                        : FutureBuilder<List<Task>>(
                            future: _fetchUserRoutineTasks(_selectedPartnerId!),
                            builder: (ctx, snap) {
                              if (snap.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              final tasks = snap.data ?? [];
                              if (tasks.isEmpty) {
                                return Center(
                                  child: Text('No routine tasks found for this partner today.'.tr(), style: const TextStyle(color: Colors.grey)),
                                );
                              }

                              return ListView.builder(
                                itemCount: tasks.length,
                                itemBuilder: (ctx, idx) {
                                  final t = tasks[idx];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('${t.totalDurationMinutes} ${'mins'.tr()}'),
                                      trailing: ElevatedButton.icon(
                                        onPressed: () async {
                                          await FirebaseFirestore.instance
                                              .collection('partner_rooms')
                                              .doc(_roomCode)
                                              .collection('tasks')
                                              .add({
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
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Added to space: ${t.title}'.tr())),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.add, size: 14),
                                        label: Text('Add'.tr()),
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
      },
    );
  }

  void _showAddTaskOptions(Map<String, dynamic> participantNames) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Shared Task'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.add_task_rounded, color: Colors.green),
                title: Text('Create New Task'.tr()),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateTaskDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.import_export_rounded, color: Colors.blue),
                title: Text('Import Tasks'.tr()),
                onTap: () {
                  Navigator.pop(ctx);
                  _showImportTasksSheet(participantNames);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateTaskDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AddTaskBottomSheet(
        title: 'Add Shared Task'.tr(),
        submitButtonText: 'Save'.tr(),
        onTaskAdded: (newTask) async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;
          
          await FirebaseFirestore.instance
              .collection('partner_rooms')
              .doc(_roomCode)
              .collection('tasks')
              .add({
            'title': newTask.title,
            'subject': newTask.subject,
            'topic': newTask.topic,
            'challenges': newTask.challenges,
            'notes': newTask.notes,
            'startTime': newTask.startTime != null ? Timestamp.fromDate(newTask.startTime!) : null,
            'endTime': newTask.endTime != null ? Timestamp.fromDate(newTask.endTime!) : null,
            'isPrivate': newTask.isPrivate,
            'category': newTask.category,
            'totalDurationMinutes': newTask.totalDurationMinutes,
            'isCompleted': false,
            'createdBy': user.uid,
            'createdByName': user.displayName ?? 'Anonymous',
            'timestamp': FieldValue.serverTimestamp(),
          });
        },
      ),
    );
  }

  void _showImportTasksSheet(Map<String, dynamic> participantNames) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => MultiTaskImportSheet(
        roomCode: _roomCode,
        participantNames: participantNames,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Partner Tasks')),
        body: const Center(child: Text('Please log in to use Partner Tasks.')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(_inRoom ? 'Partner Tasks Space: $_roomCode' : 'Partner Tasks'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: _inRoom
            ? [
                IconButton(
                  tooltip: 'Leave Space',
                  icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
                  onPressed: _leaveSpace,
                )
              ]
            : null,
      ),
      body: _inRoom ? _buildSpaceUI(user) : _buildJoinCreateUI(user),
      floatingActionButton: null,
    );
  }

  Widget _buildJoinCreateUI(User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Icon(Icons.group_add_rounded, size: 80, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Study Partner Space'.tr(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Join or create a space to share tasks and study with your partners.'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),

          // Create Space Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create Partner Space'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _roomNameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter Space name (optional)'.tr(),
                      prefixIcon: const Icon(Icons.label_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _createSpace,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: Text('Create Partner Space'.tr()),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Join Space Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Join Partner Space'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _joinCodeCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter Space Code (e.g. PR-XXXXXX)'.tr(),
                      prefixIcon: const Icon(Icons.meeting_room_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _joinSpace,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                    child: Text('Join Space'.tr()),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Your Spaces Section
          Text('Your Spaces'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('partner_rooms')
                .where('participants', arrayContains: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text(
                      'You are not in any spaces yet.'.tr(),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final roomData = docs[index].data() as Map<String, dynamic>;
                  final name = roomData['name'] ?? 'Partner Space';
                  final code = roomData['roomId'] ?? '';
                  final participants = List<String>.from(roomData['participants'] ?? []);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(Icons.group_work_rounded, color: Theme.of(context).colorScheme.primary),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${'Code:'.tr()} $code • ${participants.length} ${'partners'.tr()}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Space code copied!'.tr())));
                            },
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          _roomCode = code;
                          _inRoom = true;
                        });
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSpaceUI(User user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('partner_rooms').doc(_roomCode).snapshots(),
      builder: (context, roomSnap) {
        if (roomSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!roomSnap.hasData || !roomSnap.data!.exists) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Space not found or has been deleted.'.tr()),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {
                    _inRoom = false;
                    _roomCode = '';
                  }),
                  child: Text('Go Back'.tr()),
                )
              ],
            ),
          );
        }

        final roomData = roomSnap.data!.data() as Map<String, dynamic>;
        final creatorId = roomData['creatorId'] ?? '';
        final participants = List<String>.from(roomData['participants'] ?? []);
        final participantNames = Map<String, dynamic>.from(roomData['participantNames'] ?? {});
        final isCreator = user.uid == creatorId;

        if (!participants.contains(user.uid)) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted && _inRoom) {
              await _cleanupLocalHistoryForRoom(_roomCode, user.uid);
              setState(() {
                _inRoom = false;
                _roomCode = '';
              });
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  title: Text('Removed'.tr(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  content: Text('You have been removed from this partner space for not completing 80% of your tasks on time. To enter again, you must obtain the code and join again.'.tr()),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('OK'.tr()),
                    ),
                  ],
                ),
              );
            }
          });
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('partner_rooms')
              .doc(_roomCode)
              .collection('tasks')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, tasksSnap) {
            if (tasksSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final taskDocs = tasksSnap.data?.docs ?? [];
            final pendingTaskDocs = <QueryDocumentSnapshot>[];
            final completedTaskDocs = <QueryDocumentSnapshot>[];

            for (final doc in taskDocs) {
              final tData = doc.data() as Map<String, dynamic>;
              final completedUsers = List<String>.from(tData['completedUsers'] ?? []);
              final oldIsCompleted = tData['isCompleted'] ?? false;
              final oldCompletedBy = tData['completedBy'];
              
              final isCompletedByMe = completedUsers.contains(user.uid) || 
                  (oldIsCompleted && oldCompletedBy == user.uid);

              if (isCompletedByMe) {
                completedTaskDocs.add(doc);
              } else {
                pendingTaskDocs.add(doc);
              }
            }

            // Trigger analytic check for 80% completion warnings / kick-out
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _checkAnalyticsAndWarnings(user, taskDocs, roomData);
              }
            });

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pending Requests Card (Admin only)
                if (isCreator)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('partner_rooms')
                        .doc(_roomCode)
                        .collection('member_requests')
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, requestsSnap) {
                      if (requestsSnap.connectionState == ConnectionState.waiting) {
                        return const SizedBox.shrink();
                      }
                      final requests = requestsSnap.data?.docs ?? [];
                      if (requests.isEmpty) return const SizedBox.shrink();

                      return Card(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        color: Colors.amber.shade50,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.amber.shade200, width: 1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.group_add_rounded, color: Colors.amber),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                    'New Partner Requests (নতুন পার্টনার রিকোয়েস্ট)'.tr(),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.brown),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: requests.length,
                                itemBuilder: (context, idx) {
                                  final reqData = requests[idx].data() as Map<String, dynamic>;
                                  final reqId = requests[idx].id;
                                  final invitedName = reqData['invitedName'] ?? 'Friend';
                                  final invitedId = reqData['invitedId'] ?? '';
                                  final requesterName = reqData['requesterName'] ?? 'Partner';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '$invitedName (${'Invited by'.tr()} $requesterName)',
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                                              onPressed: () async {
                                                if (participants.length >= 4) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Cannot accept. Partner Space is full (Maximum 4 partners).'.tr())),
                                                  );
                                                  return;
                                                }
                                                await FirebaseFirestore.instance.collection('partner_rooms').doc(_roomCode).update({
                                                  'participants': FieldValue.arrayUnion([invitedId]),
                                                  'participantNames.$invitedId': invitedName,
                                                });
                                                await FirebaseFirestore.instance
                                                    .collection('partner_rooms')
                                                    .doc(_roomCode)
                                                    .collection('member_requests')
                                                    .doc(reqId)
                                                    .update({'status': 'accepted'});
                                              },
                                            ),
                                            const SizedBox(width: 12),
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: const Icon(Icons.cancel_rounded, color: Colors.red, size: 24),
                                              onPressed: () async {
                                                await FirebaseFirestore.instance
                                                    .collection('partner_rooms')
                                                    .doc(_roomCode)
                                                    .collection('member_requests')
                                                    .doc(reqId)
                                                    .update({'status': 'rejected'});
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                // Partners Header Summary
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${'Space Code:'.tr()} $_roomCode', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text('${'Study Partners'.tr()} (${participants.length}/4)', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              IconButton.filled(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _roomCode));
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Space code copied!'.tr())));
                                },
                                icon: const Icon(Icons.copy_rounded, size: 18),
                              ),
                              if (participants.length < 4)
                                TextButton.icon(
                                  onPressed: () => _showAddPartnerSheet(participants, creatorId),
                                  icon: const Icon(Icons.person_add_rounded, size: 18),
                                  label: Text('Add'.tr()),
                                )
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: participants.map((mId) {
                          final mName = participantNames[mId] ?? 'Partner';
                          final isMe = mId == user.uid;

                          // Calculate percentage for this member (out of all tasks)
                          String percentStr = '0%';
                          if (taskDocs.isNotEmpty) {
                            final completed = taskDocs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final completedUsers = List<String>.from(data['completedUsers'] ?? []);
                              final oldIsCompleted = data['isCompleted'] ?? false;
                              final oldCompletedBy = data['completedBy'];
                              return completedUsers.contains(mId) || (oldIsCompleted && oldCompletedBy == mId);
                            }).length;
                            final percent = (completed / taskDocs.length * 100).toStringAsFixed(0);
                            percentStr = '$percent%';
                          }

                          final displayNameWithPercent = isMe
                              ? '$mName (${'You'.tr()}) - $percentStr'
                              : '$mName - $percentStr';

                          return ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Chip(
                              avatar: CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, size: 16, color: Theme.of(context).colorScheme.primary)),
                              label: Text(displayNameWithPercent, overflow: TextOverflow.ellipsis, maxLines: 1),
                              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              side: BorderSide.none,
                              onDeleted: (isCreator && !isMe)
                                  ? () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text('Remove Partner (পার্টনার রিমুভ করুন)'.tr()),
                                          content: Text('Are you sure you want to remove $mName from this space?'.tr()),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('No'.tr())),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                                              child: Text('Yes'.tr()),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await FirebaseFirestore.instance.collection('partner_rooms').doc(_roomCode).update({
                                          'participants': FieldValue.arrayRemove([mId]),
                                          'participantNames.$mId': FieldValue.delete(),
                                        });
                                      }
                                    }
                                  : null,
                              deleteIcon: (isCreator && !isMe) ? const Icon(Icons.cancel, size: 16, color: Colors.red) : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                // Shared Tasks Heading
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Shared Tasks for the Room'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (isCreator)
                        TextButton.icon(
                          onPressed: () => _showPartnersTasksSheet(participants, participantNames),
                          icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                          label: Text("Partners' Tasks".tr()),
                        ),
                    ],
                  ),
                ),

                // Tasks List
                Expanded(
                  child: taskDocs.isEmpty
                      ? Center(child: Text('No shared tasks yet. Add one!'.tr(), style: const TextStyle(color: Colors.grey)))
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          children: [
                            if (pendingTaskDocs.isNotEmpty) ...[
                              Text('Active Tasks'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).colorScheme.primary)),
                              const SizedBox(height: 8),
                              ...pendingTaskDocs.map((doc) => _buildSpaceTaskItem(doc, participants, participantNames, user, isCreator)),
                            ] else if (completedTaskDocs.isNotEmpty) ...[
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                                  child: Column(
                                    children: [
                                      Icon(Icons.stars_rounded, size: 48, color: Colors.green.shade400),
                                      const SizedBox(height: 8),
                                      Text(
                                        'All tasks completed!'.tr(),
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            if (completedTaskDocs.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  title: Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${'Done Tasks'.tr()} (${completedTaskDocs.length})',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 14, 
                                          color: Colors.green.shade700
                                        ),
                                      ),
                                    ],
                                  ),
                                  childrenPadding: EdgeInsets.zero,
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                                  children: completedTaskDocs.map((doc) => _buildSpaceTaskItem(doc, participants, participantNames, user, isCreator)).toList(),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
              floatingActionButton: isCreator
                  ? FloatingActionButton.extended(
                      onPressed: () => _showAddTaskOptions(participantNames),
                      icon: const Icon(Icons.add),
                      label: Text('Add Task'.tr()),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildSpaceTaskItem(
    QueryDocumentSnapshot doc, 
    List<String> participants, 
    Map<String, dynamic> participantNames,
    User user,
    bool isCreator
  ) {
    final tData = doc.data() as Map<String, dynamic>;
    final completedUsers = List<String>.from(tData['completedUsers'] ?? []);
    final oldIsCompleted = tData['isCompleted'] ?? false;
    final oldCompletedBy = tData['completedBy'];
    
    final isCompletedByMe = completedUsers.contains(user.uid) || 
        (oldIsCompleted && oldCompletedBy == user.uid);
        
    final completedOtherNames = <String>[];
    for (final mId in participants) {
      if (mId == user.uid) continue;
      final isCompletedByOther = completedUsers.contains(mId) || 
          (oldIsCompleted && oldCompletedBy == mId);
      if (isCompletedByOther) {
        completedOtherNames.add(participantNames[mId] ?? 'Partner');
      }
    }

    final baseTask = Task.fromMap(tData, 'partner_${_roomCode}_${isCreator ? 'admin' : 'member'}_${doc.id}');
    final resolvedStatus = isCompletedByMe 
        ? 'completed' 
        : (baseTask.status == 'completed' ? 'pending' : baseTask.status);
    final taskObj = baseTask.copyWith(
      isCompleted: isCompletedByMe,
      status: resolvedStatus,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ActiveTaskCard(
              task: taskObj,
              onUpdate: (updatedTask) async {
                final Map<String, dynamic> updateData = updatedTask.toMap();
                updateData['id'] = doc.id;
                
                String cleanTitle = updatedTask.title;
                final suffix = ' (${'P Task'.tr()})';
                if (cleanTitle.endsWith(suffix)) {
                  cleanTitle = cleanTitle.substring(0, cleanTitle.length - suffix.length);
                }
                updateData['title'] = cleanTitle;

                updateData['completedUsers'] = completedUsers;
                if (updatedTask.isCompleted || updatedTask.status == 'completed') {
                  if (!completedUsers.contains(user.uid)) {
                    completedUsers.add(user.uid);
                  }
                  updateData['completedUsers'] = completedUsers;
                  updateData['isCompleted'] = false;
                  updateData['status'] = 'completed';
                  await _addPartnerTaskToLocalHistory(user.uid, updatedTask, isCompleted: true);
                } else {
                  if (completedUsers.contains(user.uid)) {
                    completedUsers.remove(user.uid);
                  }
                  updateData['completedUsers'] = completedUsers;
                  updateData['isCompleted'] = false;
                  updateData['status'] = updatedTask.status == 'completed' ? 'pending' : updatedTask.status;
                  await _addPartnerTaskToLocalHistory(user.uid, updatedTask, isCompleted: false);
                }
                await doc.reference.update(updateData);
              },
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12.0, bottom: 8.0, right: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCompletedByMe)
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'You have done this task'.tr(),
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (completedOtherNames.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.people_outline_rounded, size: 14, color: Colors.blue),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${completedOtherNames.join(', ')} ${'done this task'.tr()}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPartnerTaskToLocalHistory(String userId, Task task, {required bool isCompleted}) async {
    final todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('dailyRoutines')
        .doc(todayDocId);

    final suffix = ' (${'P Task'.tr()})';
    String cleanTitle = task.title;
    if (cleanTitle.endsWith(suffix)) {
      cleanTitle = cleanTitle.substring(0, cleanTitle.length - suffix.length);
    }
    final historyTitle = '$cleanTitle$suffix';
    
    final localTask = task.copyWith(
      title: historyTitle,
      subject: task.subject != null ? '${task.subject}$suffix' : null,
      isCompleted: isCompleted,
      status: isCompleted ? 'completed' : 'pending',
    );

    final snapshot = await docRef.get();
    if (snapshot.exists) {
      final routine = DailyRoutine.fromMap(snapshot.data()!, snapshot.id);
      int index = routine.tasks.indexWhere((t) => t.id == localTask.id);
      if (index != -1) {
        routine.tasks[index] = localTask;
      } else {
        routine.tasks.add(localTask);
      }
      await docRef.update({'tasks': routine.tasks.map((t) => t.toMap()).toList()});
    } else {
      final newRoutine = DailyRoutine(
        id: todayDocId,
        userId: userId,
        date: DateTime.now(),
        tasks: [localTask],
      );
      await docRef.set(newRoutine.toMap());
    }
  }

  Future<void> _cleanupLocalHistoryForRoom(String roomCode, String userId) async {
    try {
      final todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('dailyRoutines')
          .doc(todayDocId);

      final snapshot = await docRef.get();
      if (snapshot.exists) {
        DailyRoutine routine = DailyRoutine.fromMap(snapshot.data()!, snapshot.id);
        final prefix = 'partner_${roomCode}_';
        routine.tasks.removeWhere((t) => t.id.startsWith(prefix));
        await docRef.update({'tasks': routine.tasks.map((t) => t.toMap()).toList()});
      }
    } catch (e) {
      debugPrint("Error cleaning up local history for room $roomCode: $e");
    }
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
  bool _isStandard = true;
  bool _isDegree = true;

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
          if (_equation.endsWith("sin(")) {
            _equation = _equation.substring(0, _equation.length - 4);
          } else if (_equation.endsWith("cos(")) {
            _equation = _equation.substring(0, _equation.length - 4);
          } else if (_equation.endsWith("tan(")) {
            _equation = _equation.substring(0, _equation.length - 4);
          } else if (_equation.endsWith("log(")) {
            _equation = _equation.substring(0, _equation.length - 4);
          } else if (_equation.endsWith("ln(")) {
            _equation = _equation.substring(0, _equation.length - 3);
          } else if (_equation.endsWith("√(")) {
            _equation = _equation.substring(0, _equation.length - 2);
          } else {
            _equation = _equation.substring(0, _equation.length - 1);
          }
        }
        _updateLiveResult();
      } else if (buttonText == "=") {
        if (_equation.isNotEmpty) {
          _result = _evaluateEquation(_equation);
          _equation = _result;
          _shouldReset = true;
        }
      } else if (buttonText == "deg" || buttonText == "rad") {
        _isDegree = buttonText == "deg";
        _updateLiveResult();
      } else if (buttonText == "sin" || buttonText == "cos" || buttonText == "tan" || buttonText == "log" || buttonText == "ln") {
        if (_shouldReset) {
          _equation = "";
          _shouldReset = false;
        }
        _equation += "$buttonText(";
        _updateLiveResult();
      } else if (buttonText == "√") {
        if (_shouldReset) {
          _equation = "";
          _shouldReset = false;
        }
        _equation += "√(";
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
            _equation = _equation.substring(0, _equation.length - 1) + buttonText;
          } else {
            _equation += buttonText;
          }
        }
      } else {
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
              List<String> parts = _equation.split(RegExp(r'[+\-×÷^]'));
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
    return char == "+" || char == "-" || char == "×" || char == "÷" || char == "^";
  }

  void _toggleSign() {
    if (_equation.isEmpty) return;
    int i = _equation.length - 1;
    while (i >= 0 && !_isOperator(_equation[i])) {
      i--;
    }
    if (i < 0) {
      if (_equation.startsWith("-")) {
        _equation = _equation.substring(1);
      } else {
        _equation = "-$_equation";
      }
    } else if (i == 0 && _equation[0] == "-") {
      _equation = _equation.substring(1);
    } else {
      String op = _equation[i];
      String left = _equation.substring(0, i);
      String right = _equation.substring(i + 1);
      if (op == "+") {
        _equation = "$left-$right";
      } else if (op == "-") {
        if (i == 0 || _isOperator(_equation[i - 1])) {
          _equation = left + right;
        } else {
          _equation = "$left+$right";
        }
      } else {
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
    String lastChar = _equation[_equation.length - 1];
    if (!_isOperator(lastChar) && lastChar != "(") {
      String eval = _evaluateEquation(_equation);
      if (eval != "Error") {
        _result = eval;
      }
    }
  }

  String _evaluateEquation(String expr) {
    try {
      if (expr.isEmpty) return "0";
      String sanitized = expr;
      int openCount = 0;
      int closeCount = 0;
      for (int i = 0; i < sanitized.length; i++) {
        if (sanitized[i] == '(') openCount++;
        if (sanitized[i] == ')') closeCount++;
      }
      if (openCount > closeCount) {
        sanitized += ')' * (openCount - closeCount);
      }
      sanitized = sanitized.replaceAll('×', '*').replaceAll('÷', '/');
      final parser = MathParser(sanitized, isDegree: _isDegree);
      double total = parser.parse();
      if (total.isInfinite || total.isNaN) return "Error";
      if (total == total.toInt()) {
        return total.toInt().toString();
      }
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
        ? const Color(0xFFFF9F0A)
        : isSpecial 
            ? const Color(0xFFA5A5A5)
            : const Color(0xFF333333);
            
    Color defaultTextColor = isSpecial ? Colors.black : Colors.white;

    return Expanded(
      flex: flex,
      child: Container(
        margin: const EdgeInsets.all(4),
        child: AspectRatio(
          aspectRatio: _isStandard 
              ? (flex == 1 ? 1 : 2.1)
              : (flex == 1 ? 1.4 : 3.0),
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
                fontSize: text.length > 1 && text != "+/-" ? 18 : 24, 
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScientificButton(String text, {bool isToggle = false}) {
    Color bgColor = const Color(0xFF2E2E3E);
    Color textColor = Colors.white70;
    
    if (isToggle) {
      bgColor = const Color(0xFF3F51B5);
      textColor = Colors.white;
    }
    
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        child: AspectRatio(
          aspectRatio: 1.6,
          child: ElevatedButton(
            onPressed: () {
              if (isToggle) {
                _buttonPressed(_isDegree ? 'rad' : 'deg');
              } else {
                _buttonPressed(text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor,
              foregroundColor: textColor,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab(String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isStandard = label == "Standard";
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF333333) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.white24 : Colors.transparent,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label.tr(),
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showScientificGuideline(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bool isBn = LanguageManager().currentLanguage == 'bn';
        final title = isBn ? 'সায়েন্টিফিক ক্যালকুলেটর গাইডলাইন' : 'Scientific Calculator Guideline';
        
        final List<Map<String, String>> guideItems = isBn ? [
          {'title': 'DEG / RAD', 'desc': 'কোণ পরিমাপের একক ডিগ্রি (DEG) বা রেডিয়ানে (RAD) পরিবর্তন করতে ব্যবহার করুন। ডিগ্রি মোডে sin(30) = 0.5 আসবে।'},
          {'title': 'sin, cos, tan', 'desc': 'ত্রিকোণমিতিক কোণ নির্ণয়ের জন্য ব্যবহার করুন। বাটনে চাপ দিলে ব্র্যাকেটসহ ফাংশন (যেমন: sin() আসবে।'},
          {'title': '^ (Power)', 'desc': 'কোনো সংখ্যার পাওয়ার বা ঘাত দিতে ব্যবহার করুন। যেমন: 2^3 = 8।'},
          {'title': 'ln', 'desc': 'ভিত্তি e বিশিষ্ট ন্যাচারাল লগারিদম (যেমন: ln(e) = 1) হিসাবের জন্য।'},
          {'title': 'log', 'desc': 'ভিত্তি 10 বিশিষ্ট সাধারণ লগারিদম (যেমন: log(100) = 2) হিসাবের জন্য।'},
          {'title': '√ (Square Root)', 'desc': 'যেকোনো সংখ্যার বর্গমূল বা রুট বের করতে ব্যবহার করুন (যেমন: √(16) = 4)।'},
          {'title': '( ) (ব্র্যাকেট)', 'desc': 'হিসাবের অগ্রাধিকার ঠিক করতে ও জটিল সমীকরণ সাজাতে বন্ধনী ব্যবহার করুন।'},
          {'title': 'π এবং e', 'desc': 'পাই (≈ ৩.১৪১৫৯) এবং অয়লার ধ্রুবক (≈ ২.৭১৮২৮) সরাসরি ইনপুটের জন্য ব্যবহার করুন।'},
          {'title': '! (Factorial)', 'desc': 'ধারাবাহিক গুণফল বের করতে ব্যবহার করুন (যেমন: 5! = 120)।'},
          {'title': '% (Percentage)', 'desc': 'শতকরা মান বের করার জন্য (যেমন: 50% = 0.5)।'},
          {'title': '+/-', 'desc': 'কোনো সংখ্যার আগে মাইনাস (-) বা প্লাস (+) চিহ্ন পরিবর্তন করতে ব্যবহার করুন।'},
          {'title': '⌫ (ব্যাকস্পেস বাটন)', 'desc': 'ইনপুট স্ক্রিনের বাম পাশে থাকা এই বাটনটি দিয়ে সমীকরণের টাইপ করা অক্ষরগুলো একটি একটি করে কেটে ফেলা বা মোছা যাবে।'},
        ] : [
          {'title': 'DEG / RAD', 'desc': 'Toggle angle unit between Degree (DEG) and Radian (RAD). In DEG mode, sin(30) = 0.5.'},
          {'title': 'sin, cos, tan', 'desc': 'Trigonometric functions. Pressing these inserts the function with parenthesis, e.g., sin().'},
          {'title': '^ (Power)', 'desc': 'Raises a number to the power of another. Example: 2^3 = 8.'},
          {'title': 'ln', 'desc': 'Natural logarithm base e (e.g., ln(e) = 1).'},
          {'title': 'log', 'desc': 'Common logarithm base 10 (e.g., log(100) = 2).'},
          {'title': '√ (Square Root)', 'desc': 'Calculates the square root of a number (e.g., √(16) = 4).'},
          {'title': '( ) (Parentheses)', 'desc': 'Used to define calculation precedence and group expressions.'},
          {'title': 'π and e', 'desc': 'Inserts math constants Pi (≈ 3.14159) and Euler\'s number (≈ 2.71828).'},
          {'title': '! (Factorial)', 'desc': 'Calculates product of all positive integers up to that number (e.g., 5! = 120).'},
          {'title': '% (Percentage)', 'desc': 'Converts value to a percentage (e.g., 50% = 0.5).'},
          {'title': '+/-', 'desc': 'Toggles the positive or negative sign of the current number segment.'},
          {'title': '⌫ (Backspace)', 'desc': 'Located on the left side of the input screen. Tap to delete equation characters one by one.'},
        ];

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.help_outline_rounded, color: const Color(0xFF3F51B5), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: guideItems.length,
                  itemBuilder: (context, index) {
                    final item = guideItems[index];
                    return _buildGuidelineItem(item['title']!, item['desc']!, isDark);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuidelineItem(String title, String description, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF9F0A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.4,
            ),
          ),
          const Divider(height: 16, color: Colors.white10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Calculator', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, 
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isStandard)
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              onPressed: () => _showScientificGuideline(context),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                // Display Area
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    alignment: Alignment.bottomRight,
                    child: SingleChildScrollView(
                      reverse: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (_equation.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.backspace_outlined, color: Colors.white54, size: 20),
                                  onPressed: () => _buttonPressed("⌫"),
                                )
                              else
                                const SizedBox.shrink(),
                              Expanded(
                                child: Text(
                                  _equation.isEmpty ? "0" : _equation, 
                                  style: const TextStyle(fontSize: 32, color: Colors.white54, fontFamily: 'monospace'),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _result, 
                              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w300, color: Colors.white, fontFamily: 'monospace'),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Mode Toggle Tab
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: _buildModeTab("Standard", _isStandard)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildModeTab("Scientific", !_isStandard)),
                    ],
                  ),
                ),

            if (!_isStandard) ...[
              // Scientific Keys Row 1
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Row(
                  children: [
                    _buildScientificButton(_isDegree ? 'DEG' : 'RAD', isToggle: true),
                    _buildScientificButton('sin'),
                    _buildScientificButton('cos'),
                    _buildScientificButton('tan'),
                    _buildScientificButton('^'),
                  ],
                ),
              ),
              // Scientific Keys Row 2
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Row(
                  children: [
                    _buildScientificButton('ln'),
                    _buildScientificButton('log'),
                    _buildScientificButton('√'),
                    _buildScientificButton('('),
                    _buildScientificButton(')'),
                  ],
                ),
              ),
              // Scientific Keys Row 3
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Row(
                  children: [
                    _buildScientificButton('π'),
                    _buildScientificButton('e'),
                    _buildScientificButton('!'),
                    _buildScientificButton('%'),
                    _buildScientificButton('+/-'),
                  ],
                ),
              ),
            ],
            
            // Standard/Numeric Keypad
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
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
    ),
  ),
);
  }
}

class MathParser {
  final String expression;
  final bool isDegree;
  int _pos = -1;
  int _ch = 0;

  MathParser(this.expression, {this.isDegree = true});

  void _nextChar() {
    _pos++;
    _ch = (_pos < expression.length) ? expression.codeUnitAt(_pos) : -1;
  }

  bool _eat(int charToEat) {
    while (_ch == 32) {
      _nextChar();
    }
    if (_ch == charToEat) {
      _nextChar();
      return true;
    }
    return false;
  }

  double parse() {
    _nextChar();
    double x = _parseExpression();
    if (_pos < expression.length) throw Exception();
    return x;
  }

  double _parseExpression() {
    double x = _parseTerm();
    for (;;) {
      if (_eat(43)) {
        x += _parseTerm();
      } else if (_eat(45)) {
        x -= _parseTerm();
      } else {
        return x;
      }
    }
  }

  double _parseTerm() {
    double x = _parseFactor();
    for (;;) {
      if (_eat(42)) {
        x *= _parseFactor();
      } else if (_eat(47)) {
        x /= _parseFactor();
      } else {
        return x;
      }
    }
  }

  double _parseFactor() {
    if (_eat(43)) return _parseFactor();
    if (_eat(45)) return -_parseFactor();

    double x;
    int startPos = _pos;
    if (_eat(40)) {
      x = _parseExpression();
      _eat(41);
    } else if ((_ch >= 48 && _ch <= 57) || _ch == 46) {
      while ((_ch >= 48 && _ch <= 57) || _ch == 46) {
        _nextChar();
      }
      x = double.parse(expression.substring(startPos, _pos));
    } else if ((_ch >= 97 && _ch <= 122) || _ch == 960 || _ch == 8730) {
      if (_ch == 960) {
        _nextChar();
        x = math.pi;
      } else if (_ch == 101 && (_pos + 1 >= expression.length || expression.codeUnitAt(_pos + 1) < 97 || expression.codeUnitAt(_pos + 1) > 122)) {
        _nextChar();
        x = math.e;
      } else if (_ch == 8730) {
        _nextChar();
        x = math.sqrt(_parseFactor());
      } else {
        while (_ch >= 97 && _ch <= 122) {
          _nextChar();
        }
        String func = expression.substring(startPos, _pos);
        double arg = _parseFactor();
        if (func == "sin") {
          x = math.sin(isDegree ? arg * math.pi / 180 : arg);
        } else if (func == "cos") {
          x = math.cos(isDegree ? arg * math.pi / 180 : arg);
        } else if (func == "tan") {
          x = math.tan(isDegree ? arg * math.pi / 180 : arg);
        } else if (func == "log") {
          x = math.log(arg) / math.ln10;
        } else if (func == "ln") {
          x = math.log(arg);
        } else if (func == "sqrt") {
          x = math.sqrt(arg);
        } else {
          throw Exception();
        }
      }
    } else {
      throw Exception();
    }

    for (;;) {
      if (_eat(94)) {
        x = math.pow(x, _parseFactor()).toDouble();
      } else if (_eat(37)) {
        x = x / 100.0;
      } else if (_eat(33)) {
        x = _factorial(x);
      } else {
        return x;
      }
    }
  }

  double _factorial(double val) {
    if (val < 0) return double.nan;
    int n = val.toInt();
    if (n.toDouble() != val) return double.nan;
    double result = 1.0;
    for (int i = 1; i <= n; i++) {
      result *= i;
    }
    return result;
  }
}

// ==========================================
// 6. Stopwatch & Timer Screen (স্টপওয়াচ ও টাইমার)
// ==========================================
class _LapRecord {
  final int durationMillis;
  final String formattedLapDuration;
  final String formattedTotalElapsed;

  _LapRecord(this.durationMillis, this.formattedLapDuration, this.formattedTotalElapsed);
}

class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  // Stopwatch Variables
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _stopwatchTimer;
  final List<_LapRecord> _laps = [];
  int _lastLapMillis = 0;

  // Animation Variables for Neon
  late AnimationController _neonRingController;
  late AnimationController _pulseController;

  // Timer (Countdown) Variables
  int _selectedTimerSeconds = 0;
  int _remainingTimerSeconds = 0;
  bool _isTimerRunning = false;
  Timer? _countdownTimer;
  bool _alarmEnabled = true; // এলার্ম অন/অফ

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _neonRingController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _stopwatchTimer?.cancel();
    _countdownTimer?.cancel();
    _tabController.dispose();
    _neonRingController.dispose();
    _pulseController.dispose();
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
      final currentTotal = _stopwatch.elapsedMilliseconds;
      final lapDuration = currentTotal - _lastLapMillis;
      _lastLapMillis = currentTotal;

      setState(() {
        _laps.insert(0, _LapRecord(lapDuration, _formatStopwatchTime(lapDuration), _formatStopwatchTime(currentTotal)));
      });
    } else {
      // Reset
      setState(() {
        _stopwatch.reset();
        _laps.clear();
        _lastLapMillis = 0;
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
    if (!_alarmEnabled) return; // এলার্ম বন্ধ থাকলে বাজাবে না
    SoundPlayer.playAlarmNotificationSound();
    showDialog(
      context: context,
      barrierDismissible: false, // ব্যাকগ্রাউন্ডে ট্যাপ করলে বন্ধ না হওয়ার জন্য
      builder: (_) => AlertDialog(
        title: const Text('⏰ Timer Finished!', textAlign: TextAlign.center),
        content: const Text('আপনার কাউন্টডাউন টাইমার শেষ হয়েছে।', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              SoundPlayer.stopAlarm(); // আগে সাউন্ড বন্ধ করো
              Navigator.pop(context);  // তারপর ডায়ালগ বন্ধ
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('⏹ Stop Alarm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- UI Builders ---
  Widget _buildClassicStopwatch() {
    final isRunning = _stopwatch.isRunning;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        const SizedBox(height: 40),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).cardColor,
                boxShadow: [
                  if (isRunning)
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.15 + 0.15 * _pulseController.value),
                      blurRadius: 40,
                      spreadRadius: 10 * _pulseController.value,
                    )
                  else
                    BoxShadow(
                      color: colorScheme.onSurface.withValues(alpha: 0.05),
                      blurRadius: 20,
                    ),
                ],
                border: Border.all(
                  color: isRunning 
                      ? colorScheme.primary.withValues(alpha: 0.5 + 0.5 * _pulseController.value)
                      : colorScheme.outline.withValues(alpha: 0.3),
                  width: isRunning ? 4 : 2,
                ),
              ),
              child: Center(
                child: Text(
                  _formatStopwatchTime(_stopwatch.elapsedMilliseconds),
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w300,
                    color: isRunning ? colorScheme.primary : colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    shadows: isRunning ? [Shadow(color: colorScheme.primary.withValues(alpha: 0.5), blurRadius: 10)] : null,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingActionButton(
              heroTag: 'lap_reset_classic',
              onPressed: _stopwatchAction,
              backgroundColor: Colors.grey.shade300,
              elevation: 0,
              child: Icon(_stopwatch.isRunning ? Icons.flag_rounded : Icons.refresh_rounded, color: Colors.black87),
            ),
            const SizedBox(width: 40),
            FloatingActionButton.large(
              heroTag: 'start_stop_classic',
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
              trailing: Text(_laps[i].formattedLapDuration, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNeonStopwatch() {
    final colorScheme = Theme.of(context).colorScheme;
    final isRunning = _stopwatch.isRunning;
    final timeStr = _formatStopwatchTime(_stopwatch.elapsedMilliseconds);
    final timeParts = timeStr.split('.'); // [MM:SS, ms]

    int? fastest = _laps.isNotEmpty ? _laps.map((l) => l.durationMillis).reduce((a, b) => a < b ? a : b) : null;
    int? slowest = _laps.isNotEmpty ? _laps.map((l) => l.durationMillis).reduce((a, b) => a > b ? a : b) : null;

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      colorScheme.primary.withValues(alpha: isRunning ? 0.05 + (0.05 * _pulseController.value) : 0.02),
                      Colors.transparent,
                    ],
                    center: Alignment.topCenter,
                    radius: 1.5,
                  ),
                ),
              );
            }
          ),
        ),
        Column(
          children: [
            const SizedBox(height: 40),
            // Glowing Circular Ring with Time
            Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (isRunning)
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.15 + 0.15 * _pulseController.value),
                            blurRadius: 40,
                            spreadRadius: 10,
                          )
                      ],
                    ),
                    child: child,
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isRunning)
                      AnimatedBuilder(
                        animation: _neonRingController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _neonRingController.value * 2 * 3.1415926535,
                            child: child,
                          );
                        },
                        child: CustomPaint(
                          size: const Size(280, 280),
                          painter: _NeonRingPainter(color: colorScheme.primary),
                        ),
                      )
                    else
                       CustomPaint(
                          size: const Size(280, 280),
                          painter: _NeonRingPainter(color: colorScheme.primary.withValues(alpha: 0.3)),
                        ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          timeParts[0],
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            color: colorScheme.primary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            shadows: [Shadow(color: colorScheme.primary, blurRadius: isRunning ? 10 : 0)],
                          ),
                        ),
                        Text(
                          '.${timeParts[1]}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w300,
                            color: colorScheme.primary.withValues(alpha: 0.7),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _stopwatchAction,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).cardColor,
                      border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.2), width: 2),
                    ),
                    child: Icon(isRunning ? Icons.flag_rounded : Icons.refresh_rounded, color: colorScheme.onSurface, size: 28),
                  ),
                ),
                const SizedBox(width: 40),
                GestureDetector(
                  onTap: _toggleStopwatch,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRunning ? Colors.redAccent.withValues(alpha: 0.2) : colorScheme.primary.withValues(alpha: 0.2),
                      border: Border.all(color: isRunning ? Colors.redAccent : colorScheme.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: isRunning ? Colors.redAccent.withValues(alpha: 0.4) : colorScheme.primary.withValues(alpha: 0.4),
                          blurRadius: 20,
                        )
                      ],
                    ),
                    child: Icon(isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, color: isRunning ? Colors.redAccent : colorScheme.primary, size: 40),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            // Lap List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _laps.length,
                itemBuilder: (ctx, i) {
                  final lap = _laps[i];
                  final bool isFastest = _laps.length > 1 && lap.durationMillis == fastest;
                  final bool isSlowest = _laps.length > 1 && lap.durationMillis == slowest;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isFastest ? Colors.green.withValues(alpha: 0.1) : (isSlowest ? Colors.red.withValues(alpha: 0.1) : colorScheme.surface),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isFastest ? Colors.green : (isSlowest ? Colors.red : colorScheme.onSurface.withValues(alpha: 0.1))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lap ${_laps.length - i}',
                          style: TextStyle(color: isFastest ? Colors.green : (isSlowest ? Colors.red : colorScheme.onSurface), fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            Text(
                              '+${lap.formattedLapDuration}',
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              lap.formattedTotalElapsed,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isFastest ? Colors.green : (isSlowest ? Colors.red : colorScheme.onSurface)),
                            ),
                          ],
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCountdownTimer() {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          // ─── এলার্ম টগল ───
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _alarmEnabled ? Icons.alarm_on_rounded : Icons.alarm_off_rounded,
                      color: _alarmEnabled ? Colors.orangeAccent : colorScheme.onSurfaceVariant,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'এলার্ম',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _alarmEnabled ? 'টাইমার শেষে এলার্ম বাজবে' : 'টাইমার শেষে এলার্ম বাজবে না',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: _alarmEnabled,
                  activeThumbColor: Colors.orangeAccent,
                  onChanged: (val) => setState(() => _alarmEnabled = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // ─── টাইমার পিকার / কাউন্টডাউন ডিসপ্লে ───
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
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final double progress = _selectedTimerSeconds > 0 
                    ? _remainingTimerSeconds / _selectedTimerSeconds 
                    : 0.0;
                
                return SizedBox(
                  width: 250,
                  height: 250,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        color: _isTimerRunning ? Colors.orangeAccent : Colors.orangeAccent.withValues(alpha: 0.5),
                      ),
                      if (_isTimerRunning)
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orangeAccent.withValues(alpha: 0.15 + 0.15 * _pulseController.value),
                                blurRadius: 40,
                                spreadRadius: 10 * _pulseController.value,
                              )
                            ],
                          ),
                        ),
                      Center(
                        child: Text(
                          '${(_remainingTimerSeconds ~/ 3600).toString().padLeft(2, '0')}:${((_remainingTimerSeconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(_remainingTimerSeconds % 60).toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 48, 
                            fontWeight: FontWeight.w300, 
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: _isTimerRunning ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                            shadows: _isTimerRunning ? [Shadow(color: Colors.orangeAccent.withValues(alpha: 0.5), blurRadius: 10)] : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 48),
          // ─── বাটনগুলো ───
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNeon = ThemeManager().currentLayoutStyle == AppLayoutStyle.neon;
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
          isNeon ? _buildNeonStopwatch() : _buildClassicStopwatch(),
          _buildCountdownTimer(),
        ],
      ),
    );
  }
}

class _NeonRingPainter extends CustomPainter {
  final Color color;
  _NeonRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double radius = size.width / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    const int dashCount = 40;
    const double sweepAngle = (3.1415926535 * 2) / dashCount;
    for (int i = 0; i < dashCount; i++) {
      if (i % 2 == 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          i * sweepAngle,
          sweepAngle * 0.7,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==========================================
// 4. Pomodoro Timer Screen (Forest Edition)
// ==========================================
class PomodoroTimerScreen extends StatefulWidget {
  const PomodoroTimerScreen({super.key});

  @override
  State<PomodoroTimerScreen> createState() => _PomodoroTimerScreenState();
}

class _PomodoroTimerScreenState extends State<PomodoroTimerScreen> with WidgetsBindingObserver {
  static const int focusMinutes = 25;
  static const int shortBreakMinutes = 5;
  static const int longBreakMinutes = 15;

  int _selectedDuration = focusMinutes * 60;
  int _remainingSeconds = focusMinutes * 60;
  bool _isRunning = false;
  Timer? _timer;
  String _currentMode = 'Focus';

  // Forest state
  bool _treeKilled = false;
  int _sessionCount = 0; // total successful focus sessions ever (for display)

  // App lifecycle: detect if user leaves the app mid-focus
  bool _appWentBackground = false;

  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  // Tree emojis representing growth stages based on progress
  String _getTreeStage(double progress) {
    if (progress <= 0.0) return '🌱'; // seed
    if (progress < 0.3) return '🌿';  // sprout
    if (progress < 0.6) return '🌳';  // small tree
    if (progress < 0.9) return '🌲';  // growing tree
    return '🌲';                        // full tree
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSessionCount();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_currentMode == 'Focus' && _isRunning) {
      if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
        // User left the app mid-focus → kill the tree
        _appWentBackground = true;
        _timer?.cancel();
        setState(() {
          _isRunning = false;
          _treeKilled = true;
          _remainingSeconds = _selectedDuration; // reset
        });
      }
    }
  }

  Future<void> _loadSessionCount() async {
    if (_user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(_user!.uid).collection('pomodoroForest').doc('stats').get();
      if (doc.exists) {
        setState(() {
          _sessionCount = (doc.data()?['totalTrees'] ?? 0) as int;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      _treeKilled = false;
      _appWentBackground = false;
    });
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() {
        _isRunning = true;
        _treeKilled = false;
        _appWentBackground = false;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          setState(() => _remainingSeconds--);
        } else {
          _timer?.cancel();
          setState(() => _isRunning = false);
          _onTimerComplete();
        }
      });
    }
  }

  void _resetTimer() {
    if (_isRunning && _currentMode == 'Focus') {
      // User abandoned a running focus session → tree dies
      setState(() => _treeKilled = true);
    }
    _timer?.cancel();
    setState(() {
      _remainingSeconds = _selectedDuration;
      _isRunning = false;
    });
  }

  void _onTimerComplete() {
    SoundPlayer.playAlarmNotificationSound();
    if (_currentMode == 'Focus') {
      _plantTreeAndAwardXP();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _currentMode == 'Focus' ? '🌲 গাছ লাগানো হয়েছে!' : '⏰ বিরতি শেষ!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          _currentMode == 'Focus'
              ? 'অসাধারণ! তুমি ২৫ মিনিট মনোযোগ ধরে রেখেছ। তোমার বাগানে একটি নতুন গাছ যোগ হয়েছে! 🌳'
              : 'বিরতি শেষ। আবার ফোকাস করতে প্রস্তুত?',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (_currentMode == 'Focus') {
                _setMode('Short Break', shortBreakMinutes);
              } else {
                _setMode('Focus', focusMinutes);
              }
            },
            child: Text(_currentMode == 'Focus' ? 'বিরতি নাও' : 'আবার শুরু করো'),
          )
        ],
      ),
    );
  }

  Future<void> _plantTreeAndAwardXP() async {
    if (_user == null) return;
    try {
      // Save tree to Firestore
      final treeData = {
        'plantedAt': FieldValue.serverTimestamp(),
        'type': '🌲',
        'sessionMinutes': focusMinutes,
      };
      await _firestore.collection('users').doc(_user!.uid).collection('pomodoroForest').doc('trees').collection('list').add(treeData);
      await _firestore.collection('users').doc(_user!.uid).collection('pomodoroForest').doc('stats').set({
        'totalTrees': FieldValue.increment(1),
        'lastPlanted': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Award XP
      final res = await GamificationService.awardXP(
        GamificationService.xpPomodoroSession,
        reason: 'pomodoro_session_complete',
      );
      if (mounted && res.isNotEmpty) {
        final int xpAwarded = res['xpAwarded'] ?? 0;
        final List<String> newBadges = List<String>.from(res['newBadges'] ?? []);
        String msg = '🌲 গাছ লাগানো হয়েছে! +$xpAwarded XP';
        if (newBadges.isNotEmpty) msg += '\n🏆 Unlocked: ${newBadges.join(", ")}!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green.shade700),
        );
      }

      setState(() => _sessionCount++);
    } catch (e) {
      debugPrint('Error planting tree: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    int minutes = _remainingSeconds ~/ 60;
    int seconds = _remainingSeconds % 60;
    String timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    double progress = 1 - (_remainingSeconds / _selectedDuration);

    final Color focusColor = Colors.green.shade700;
    final Color breakColor = Colors.teal;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1F13) : const Color(0xFFF0FAF2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Pomodoro'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.forest_rounded),
            tooltip: 'আমার বাগান',
            onPressed: () => _showForestGarden(context),
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mode Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildModeButton('Focus', focusMinutes, focusColor),
              _buildModeButton('Short Break', shortBreakMinutes, breakColor),
              _buildModeButton('Long Break', longBreakMinutes, breakColor),
            ],
          ),
          const SizedBox(height: 32),

          // Tree Growth Stage Display
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: _treeKilled
                ? Column(
                    key: const ValueKey('dead'),
                    children: [
                      const Text('🥀', style: TextStyle(fontSize: 80)),
                      const SizedBox(height: 8),
                      Text(
                        'ওহ না! গাছটি মরে গেছে 😢\nমনোযোগ ভাঙবেন না!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600),
                      ),
                    ],
                  )
                : Column(
                    key: ValueKey('tree_$progress'),
                    children: [
                      Text(
                        _currentMode == 'Focus' ? _getTreeStage(progress) : '☁️',
                        style: const TextStyle(fontSize: 90),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentMode == 'Focus'
                            ? (progress < 0.01 ? 'বীজ রোপণের জন্য প্রস্তুত...' : 'গাছ বড় হচ্ছে...')
                            : 'বিশ্রাম নাও 🌤️',
                        style: TextStyle(
                          color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),

          // Circular Timer
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 14,
                  backgroundColor: (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.15),
                  color: _currentMode == 'Focus' ? focusColor : breakColor,
                ),
              ),
              Column(
                children: [
                  Text(
                    timeString,
                    style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  Text(
                    _currentMode.tr(),
                    style: TextStyle(
                      fontSize: 13,
                      color: _currentMode == 'Focus' ? focusColor : breakColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 36),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _resetTimer,
                icon: Icon(Icons.refresh_rounded, size: 36, color: Colors.grey.shade500),
                tooltip: 'রিসেট (গাছ মরে যাবে!)',
              ),
              const SizedBox(width: 20),
              FloatingActionButton.large(
                onPressed: _toggleTimer,
                backgroundColor: _currentMode == 'Focus' ? focusColor : breakColor,
                elevation: 6,
                child: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text('🌲', style: TextStyle(fontSize: 18)),
                    Text('$_sessionCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_currentMode == 'Focus' && _isRunning)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '⚠️ অ্যাপ থেকে বের হলে গাছটি মরে যাবে!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.orange.shade600, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  void _showForestGarden(BuildContext context) {
    if (_user == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1F13) : const Color(0xFFF0FAF2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text('🌳 আমার বাগান', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.green.shade300 : Colors.green.shade800)),
              const SizedBox(height: 4),
              Text('প্রতিটি গাছ = ১টি সফল ২৫ মিনিট ফোকাস সেশন', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const Divider(height: 24),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(_user!.uid)
                      .collection('pomodoroForest')
                      .doc('trees')
                      .collection('list')
                      .orderBy('plantedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🌱', style: TextStyle(fontSize: 60)),
                            const SizedBox(height: 12),
                            Text('এখনো কোনো গাছ নেই!\nপ্রথম ফোকাস সেশন শুরু করো।', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final Timestamp? ts = data['plantedAt'];
                        final String dateStr = ts != null
                            ? '${ts.toDate().day}/${ts.toDate().month}'
                            : '';
                        return Tooltip(
                          message: dateStr,
                          child: const Text('🌲', style: TextStyle(fontSize: 28), textAlign: TextAlign.center),
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

  Widget _buildModeButton(String title, int minutes, Color activeColor) {
    bool isSelected = _currentMode == title;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(title.tr(), style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
        selected: isSelected,
        onSelected: (selected) {
          if (selected && !_isRunning) _setMode(title, minutes);
        },
        selectedColor: activeColor.withValues(alpha: 0.2),
        labelStyle: TextStyle(color: isSelected ? activeColor : Colors.grey),
        side: isSelected ? BorderSide(color: activeColor, width: 1.5) : BorderSide.none,
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
              showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent, builder: (_) => const MoodHistoryBottomSheet());
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
  
  final List<String> _nextTasks = [];
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
                          initialValue: _selectedDay,
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
      {
        'type': AppThemeType.cyberpunk,
        'name': 'Cyberpunk Wasp',
        'desc': 'High-contrast yellow and deep black cyberpunk theme.',
        'primary': const Color(0xFFFFD700),
        'surface': const Color(0xFF0D0D0D),
        'accent': const Color(0xFFFF9100),
        'isDark': true,
      },
      {
        'type': AppThemeType.sakura,
        'name': 'Sakura Dream',
        'desc': 'Soft pastel cherry blossom pink light theme.',
        'primary': const Color(0xFFEC4899),
        'surface': const Color(0xFFFFF5F7),
        'accent': const Color(0xFFF472B6),
        'isDark': false,
      },
      {
        'type': AppThemeType.nebula,
        'name': 'Nebula Purple',
        'desc': 'Cosmic dark theme with neon purple accents.',
        'primary': const Color(0xFFA855F7),
        'surface': const Color(0xFF120E2E),
        'accent': const Color(0xFFEC4899),
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
                                    (t['name'] as String).tr(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (t['desc'] as String).tr(),
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
                    _buildLayoutOptionCard(context, themeManager, AppLayoutStyle.iosGlassy, 'iOS Premium', Icons.phone_iphone_rounded),
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
// PDF Reader Screen (ইন-অ্যাপ পিডিএফ ভিউয়ার)
// ==========================================
class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({super.key});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  List<Map<String, dynamic>> _pdfFiles = []; // {path, name}
  bool _isLoading = false;
  final _prefs = SharedPreferences.getInstance();
  final _user = FirebaseAuth.instance.currentUser;

  static const _prefsKey = 'saved_pdf_files';

  @override
  void initState() {
    super.initState();
    _loadSavedFiles();
  }

  Future<void> _loadSavedFiles() async {
    final prefs = await _prefs;
    final savedPaths = prefs.getStringList(_prefsKey) ?? [];
    final validFiles = savedPaths
        .where((p) => File(p).existsSync())
        .map((p) => {'path': p, 'name': p.split('/').last.split('\\').last})
        .toList();
    setState(() => _pdfFiles = List.from(validFiles));
  }

  Future<void> _saveFileList() async {
    final prefs = await _prefs;
    await prefs.setStringList(_prefsKey, _pdfFiles.map((f) => f['path'] as String).toList());
  }

  Future<void> _pickPdf() async {
    try {
      setState(() => _isLoading = true);
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final newEntries = result.files
            .where((f) => f.path != null)
            .map((f) => {
                  'path': f.path!,
                  'name': f.name,
                })
            .toList();

        setState(() => _pdfFiles.addAll(newEntries));
        await _saveFileList();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${newEntries.length} ${'PDFs imported successfully!'.tr()}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'Error importing PDF:'.tr()} $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openPdf(Map<String, dynamic> fileEntry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppPdfViewerScreen(
          filePath: fileEntry['path'] as String,
          fileName: fileEntry['name'] as String,
          userId: _user?.uid ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardDeco = ThemeManager.getCardDecoration(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('PDF Reader'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_to_photos_rounded),
            tooltip: 'Import Document',
            onPressed: _pickPdf,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: _pdfFiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: cardDeco,
                            child: Column(
                              children: [
                                const Icon(Icons.picture_as_pdf_rounded, size: 64, color: Colors.redAccent),
                                const SizedBox(height: 16),
                                Text(
                                  'PDF Reader'.tr(),
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Import Handnotes, Books or Lecture PDFs to study inside StudyMate.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
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
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Documents (${_pdfFiles.length})',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _pdfFiles.length,
                            itemBuilder: (context, index) {
                              final fileEntry = _pdfFiles[index];
                              final file = File(fileEntry['path'] as String);
                              final String fileName = fileEntry['name'] as String;
                              final fileSize = file.existsSync()
                                  ? '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB'
                                  : 'File missing';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Colors.redAccent,
                                    child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                                  ),
                                  title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(fileSize),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                    onPressed: () {
                                      setState(() => _pdfFiles.removeAt(index));
                                      _saveFileList();
                                    },
                                  ),
                                  onTap: () => _openPdf(fileEntry),
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

/// In-App PDF Viewer with dark mode filter and bookmark system
class InAppPdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final String userId;

  const InAppPdfViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.userId,
  });

  @override
  State<InAppPdfViewerScreen> createState() => _InAppPdfViewerScreenState();
}

class _InAppPdfViewerScreenState extends State<InAppPdfViewerScreen> {
  PDFViewController? _pdfController;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isDarkMode = false;
  bool _showBookmarks = false;

  Set<int> _bookmarkedPages = {};
  final _firestore = FirebaseFirestore.instance;

  String get _bookmarkDocId =>
      '${widget.userId}_${widget.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    if (widget.userId.isEmpty) return;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('pdfBookmarks')
          .doc(_bookmarkDocId)
          .get();
      if (doc.exists) {
        final pages = List<int>.from(doc.data()?['pages'] ?? []);
        setState(() => _bookmarkedPages = pages.toSet());
      }
    } catch (_) {}
  }

  Future<void> _saveBookmarks() async {
    if (widget.userId.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('pdfBookmarks')
          .doc(_bookmarkDocId)
          .set({
        'fileName': widget.fileName,
        'pages': _bookmarkedPages.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  void _toggleBookmark() {
    setState(() {
      if (_bookmarkedPages.contains(_currentPage)) {
        _bookmarkedPages.remove(_currentPage);
      } else {
        _bookmarkedPages.add(_currentPage);
      }
    });
    _saveBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    final bool isBookmarked = _bookmarkedPages.contains(_currentPage);

    Widget pdfWidget = PDFView(
      filePath: widget.filePath,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      defaultPage: _currentPage,
      fitPolicy: FitPolicy.BOTH,
      onRender: (pages) => setState(() => _totalPages = pages ?? 0),
      onPageChanged: (page, total) => setState(() {
        _currentPage = page ?? 0;
        _totalPages = total ?? 0;
      }),
      onViewCreated: (controller) => _pdfController = controller,
    );

    if (_isDarkMode) {
      pdfWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]),
        child: pdfWidget,
      );
    }

    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: _isDarkMode ? Colors.grey.shade900 : null,
        elevation: 0,
        title: Text(
          widget.fileName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Dark mode toggle
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: _isDarkMode ? 'Light Mode' : 'Dark Mode',
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
          // Bookmark toggle
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: isBookmarked ? Colors.amber : null,
            ),
            tooltip: isBookmarked ? 'Remove Bookmark' : 'Bookmark Page ${_currentPage + 1}',
            onPressed: _toggleBookmark,
          ),
          // Show bookmark list
          if (_bookmarkedPages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.list_rounded),
              tooltip: 'My Bookmarks',
              onPressed: () => _showBookmarkPanel(context),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: pdfWidget),
          // Page navigation bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _isDarkMode ? Colors.grey.shade900 : Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, -2))],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _currentPage > 0
                      ? () => _pdfController?.setPage(_currentPage - 1)
                      : null,
                ),
                Expanded(
                  child: Text(
                    'পেজ ${_currentPage + 1} / $_totalPages${isBookmarked ? ' 🔖' : ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _currentPage < _totalPages - 1
                      ? () => _pdfController?.setPage(_currentPage + 1)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBookmarkPanel(BuildContext context) {
    final sortedBookmarks = _bookmarkedPages.toList()..sort();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔖 বুকমার্ক করা পেজ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sortedBookmarks.length,
                itemBuilder: (context, i) {
                  final page = sortedBookmarks[i];
                  return ListTile(
                    leading: const Icon(Icons.bookmark_rounded, color: Colors.amber),
                    title: Text('পেজ ${page + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      onPressed: () {
                        setState(() => _bookmarkedPages.remove(page));
                        _saveBookmarks();
                        Navigator.pop(ctx);
                      },
                    ),
                    onTap: () {
                      _pdfController?.setPage(page);
                      Navigator.pop(ctx);
                    },
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