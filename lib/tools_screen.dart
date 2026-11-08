import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'daily_routine.dart';
import 'dashboard_screen.dart';
import 'calendar_screen.dart';
import 'focus_music_screen.dart';
import 'flashcards_screen.dart';
import 'dictionary_screen.dart';
import 'revision_147_screen.dart';
import 'islamic_life_screen.dart';
import 'theme_manager.dart';
import 'study_analytics_screen.dart';
import 'weekly_overview_screen.dart';
import 'task_history_screen.dart';
import 'language_manager.dart';
import 'study_folder_manager_screen.dart';
import 'special_day_countdown_screen.dart';
import 'daily_diary_screen.dart';
import 'bookmarks_screen.dart';
import 'news_reader_screen.dart';
import 'social_hub_screen.dart';
import 'google_sheet_sync_screen.dart';
import 'multi_sheet_manager_screen.dart';
import 'notifications_hub_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
// ==========================================
// IMPORT TOOLS MODULES
// ==========================================
import 'tools/weekly_routine_task_bottom_sheet.dart';
import 'tools/sleep_tracker_screen.dart';
import 'tools/quick_notes_screen.dart';
import 'tools/study_room_screen.dart';
import 'tools/partner_tasks_screen.dart';
import 'tools/calculator_screen.dart';
import 'tools/stopwatch_screen.dart';
import 'tools/pomodoro_timer_screen.dart';
import 'tools/mood_tracker_sheets.dart';
import 'tools/breathing_player_screen.dart';
import 'tools/routine_planner_bottom_sheet.dart';
import 'tools/ai_study_planner_bottom_sheet.dart';
import 'tools/theme_customizer_bottom_sheet.dart';
import 'tools/pdf_reader_screen.dart';
import 'tools/multi_task_import_sheet.dart';

// ==========================================
// EXPORT TOOLS MODULES
// ==========================================
export 'tools/weekly_routine_task_bottom_sheet.dart';
export 'tools/sleep_tracker_screen.dart';
export 'tools/quick_notes_screen.dart';
export 'tools/study_room_screen.dart';
export 'tools/partner_tasks_screen.dart';
export 'tools/calculator_screen.dart';
export 'tools/stopwatch_screen.dart';
export 'tools/pomodoro_timer_screen.dart';
export 'tools/mood_tracker_sheets.dart';
export 'tools/breathing_player_screen.dart';
export 'tools/routine_planner_bottom_sheet.dart';
export 'tools/ai_study_planner_bottom_sheet.dart';
export 'tools/theme_customizer_bottom_sheet.dart';
export 'tools/pdf_reader_screen.dart';
export 'tools/multi_task_import_sheet.dart';
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
          {'title': 'Daily News', 'icon': Icons.article_rounded, 'color': Colors.blueGrey, 'action': 'news', 'requiresInternet': true},
          {'title': 'Dictionary', 'icon': Icons.menu_book_rounded, 'color': Colors.orangeAccent, 'action': 'dict', 'requiresInternet': true},
          {'title': 'Study Map', 'icon': Icons.folder_copy_rounded, 'color': Colors.teal, 'action': 'study_folders'},
          {'title': 'Countdown', 'icon': Icons.event_note_rounded, 'color': const Color(0xFF6366F1), 'action': 'countdown'},
          {'title': 'Calendar', 'icon': Icons.calendar_month_rounded, 'color': Colors.teal, 'action': 'calendar'},
          {'title': 'My Study Sheets', 'icon': Icons.folder_special_rounded, 'color': const Color(0xFF6366F1), 'action': 'multi_sheet', 'requiresInternet': true},
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
          {'title': 'Web Study', 'icon': Icons.bookmarks_rounded, 'color': Colors.blue, 'action': 'bookmarks', 'requiresInternet': true},
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
                        crossAxisCount: 3, // à¦à¦• à¦²à¦¾à¦‡à¦¨à§‡ à§©à¦Ÿà¦¿ à¦•à¦°à§‡ à¦¬à¦•à§à¦¸ à¦¥à¦¾à¦•à¦¬à§‡
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.95, // à§© à¦•à¦²à¦¾à¦®à§‡à¦° à¦®à¦¾à¦¨à¦¾à¦¨à¦¸à¦‡ à¦…à¦¨à§à¦ªà¦¾à¦¤
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
                                    } else if (tool['action'] == 'news') {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NewsReaderScreen()));
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
                                    } else if (tool['action'] == 'gsheet_sync') {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const GoogleSheetSyncScreen()));
                                    } else if (tool['action'] == 'multi_sheet') {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MultiSheetManagerScreen()));
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
                  Text('Next-day Routine (à¦¨à§‡à¦•à§à¦¸à¦Ÿ à¦¡à§‡ à¦°à§à¦Ÿà¦¿à¦¨)'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
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
                  Text('Weekly Routine (à¦‰à¦‡à¦•à¦²à¦¿ à¦°à§à¦Ÿà¦¿à¦¨)'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
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

