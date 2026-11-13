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
import 'package:shared_preferences/shared_preferences.dart';
import 'tools/tool_arrange_screen.dart';
import 'mcq/mcq_home_screen.dart';
import 'mcq/mistake_book_screen.dart';
import 'daily_review_screen.dart';
import 'photo_to_note_screen.dart';
import 'forum_screen.dart';
import 'weekly_report_screen.dart';

// ==========================================
// IMPORT TOOLS MODULES
// ==========================================
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

/// আগামীকালের (next-day) রুটিনে টাস্ক যোগ করার ফর্ম। রাতের সারাংশ নোটিফিকেশন থেকেও খোলে।
void showNextDayRoutineSheet(BuildContext context) {
  final User? user = FirebaseAuth.instance.currentUser;
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
              SnackBar(content: Text('Added to tomorrow\'s routine!'.tr())),
            );
          }
        },
      ),
    );
}

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
    _loadToolPrefs();
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
    _searchController.dispose();
    super.dispose();
  }

  // ---------- পিন করা ও সম্প্রতি ব্যবহৃত টুল ----------
  static const _prefPinned = 'tools_pinned_v1';
  static const _prefRecent = 'tools_recent_v1';
  static const _prefLayout = 'tools_layout_v1';
  static const int _maxRecent = 6;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  List<String> _pinned = [];
  List<String> _recent = [];
  List<ToolSection>? _layout; // ব্যবহারকারীর নিজের সাজানো ক্রম (null = অ্যাপের ক্রম)

  Future<void> _loadToolPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _pinned = prefs.getStringList(_prefPinned) ?? [];
        _recent = prefs.getStringList(_prefRecent) ?? [];
        _layout = decodeToolLayout(prefs.getString(_prefLayout));
      });
    } catch (_) {}
  }

  Future<void> _saveToolPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefPinned, _pinned);
      await prefs.setStringList(_prefRecent, _recent);
    } catch (_) {}
  }

  Future<void> _openArrange() async {
    final result = await Navigator.push<ToolArrangeResult>(
      context,
      MaterialPageRoute(builder: (_) => ToolArrangeScreen(categories: _buildCategories())),
    );
    if (result == null || !mounted) return;
    setState(() => _layout = result.reset ? null : result.layout);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (result.reset) {
        await prefs.remove(_prefLayout);
      } else {
        await prefs.setString(_prefLayout, encodeToolLayout(result.layout));
      }
    } catch (_) {}
  }

  void _markRecent(String action) {
    setState(() {
      _recent.remove(action);
      _recent.insert(0, action);
      if (_recent.length > _maxRecent) _recent = _recent.sublist(0, _maxRecent);
    });
    _saveToolPrefs();
  }

  void _togglePin(Map<String, dynamic> tool) {
    final action = tool['action'] as String;
    final wasPinned = _pinned.contains(action);
    setState(() {
      if (wasPinned) {
        _pinned.remove(action);
      } else {
        _pinned.add(action);
      }
    });
    _saveToolPrefs();
    final name = (tool['title'] as String).tr();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(wasPinned
          ? trx('$name removed from favourites', '$name পছন্দের তালিকা থেকে সরানো হয়েছে')
          : trx('$name pinned to the top ⭐', '$name উপরে পিন করা হয়েছে ⭐')),
      duration: const Duration(seconds: 2),
    ));
  }

  void _showToolOptions(Map<String, dynamic> tool) {
    final isPinned = _pinned.contains(tool['action']);
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(tool['icon'] as IconData, color: tool['color'] as Color),
              title: Text((tool['title'] as String).tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(isPinned ? Icons.star_outline_rounded : Icons.star_rounded, color: Colors.amber),
              title: Text(isPinned
                  ? trx('Remove from favourites', 'পছন্দের তালিকা থেকে সরান')
                  : trx('Pin to favourites', 'পছন্দের তালিকায় পিন করুন')),
              onTap: () {
                Navigator.pop(ctx);
                _togglePin(tool);
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: Text(trx('Open', 'খুলুন')),
              onTap: () {
                Navigator.pop(ctx);
                _openTool(tool);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_vert_rounded),
              title: Text(trx('Arrange tools', 'টুল সাজান')),
              onTap: () {
                Navigator.pop(ctx);
                _openArrange();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// অ্যাপের নিজের সাজানো ক্রম (গুরুত্ব অনুযায়ী)। ব্যবহারকারী "সাজান" দিয়ে বদলালে applyToolLayout সেটা বসায়।
  List<Map<String, dynamic>> _defaultCategories() {
    return [
      {
        'name': 'Study Tools',
        'icon': Icons.school_rounded,
        'tools': [
          {'title': 'Pomodoro', 'icon': Icons.timer_rounded, 'color': Colors.redAccent, 'action': 'pomodoro'},
          {'title': 'Notes', 'icon': Icons.note_alt_rounded, 'color': Colors.amber.shade600, 'action': 'notes'},
          {'title': 'Flashcards', 'icon': Icons.style_rounded, 'color': Colors.purpleAccent, 'action': 'flash'},
          {'title': '1-4-7 Revision', 'icon': Icons.published_with_changes_rounded, 'color': Colors.indigo, 'action': 'revision_147'},
          {'title': 'Study Map', 'icon': Icons.folder_copy_rounded, 'color': Colors.teal, 'action': 'study_folders'},
          {'title': 'Countdown', 'icon': Icons.event_note_rounded, 'color': const Color(0xFF6366F1), 'action': 'countdown'},
          {'title': 'PDF Reader', 'icon': Icons.picture_as_pdf_rounded, 'color': Colors.redAccent, 'action': 'pdf_reader'},
          {'title': 'Photo to Note', 'icon': Icons.document_scanner_rounded, 'color': Colors.cyan.shade700, 'action': 'photo_note', 'requiresInternet': true},
          {'title': 'Task History', 'icon': Icons.history_rounded, 'color': Colors.blueGrey, 'action': 'task_history'},
          // Calendar এখন শুধু হোমের তারিখে চাপলে খোলে (একই জিনিসের দুই জায়গা বাদ)
          {'title': 'My Study Sheets', 'icon': Icons.folder_special_rounded, 'color': const Color(0xFF6366F1), 'action': 'multi_sheet', 'requiresInternet': true},
          {'title': 'Calculator', 'icon': Icons.calculate_rounded, 'color': Colors.blueAccent, 'action': 'calc'},
          {'title': 'Stopwatch', 'icon': Icons.timer_outlined, 'color': Colors.deepOrangeAccent, 'action': 'stopwatch'},
          {'title': 'Dictionary', 'icon': Icons.menu_book_rounded, 'color': Colors.orangeAccent, 'action': 'dict', 'requiresInternet': true},
          {'title': 'Daily Diary', 'icon': Icons.book_rounded, 'color': Colors.brown, 'action': 'daily_diary'},
          {'title': 'Daily News', 'icon': Icons.article_rounded, 'color': Colors.blueGrey, 'action': 'news', 'requiresInternet': true},
        ]
      },
      {
        'name': 'Focus',
        'icon': Icons.bolt_rounded,
        'tools': [
          {'title': 'Focus Music', 'icon': Icons.headphones_rounded, 'color': Colors.teal, 'action': 'music'},
          {'title': 'Breathing Exercise', 'icon': Icons.air_rounded, 'color': Colors.lightBlueAccent, 'action': 'breath'},
          {'title': 'Islamic Life', 'icon': Icons.mosque_rounded, 'color': Colors.teal, 'action': 'islamic', 'requiresInternet': true},
        ]
      },
      {
        'name': 'Collaborative Studying',
        'icon': Icons.people_rounded,
        'tools': [
          {'title': 'Study Analytics', 'icon': Icons.analytics_rounded, 'color': Colors.teal, 'action': 'analytics'},
          {'title': 'Weekly Report', 'icon': Icons.bar_chart_rounded, 'color': Colors.deepPurple, 'action': 'weekly_report'},
          {'title': 'Social Hub', 'icon': Icons.people_alt_rounded, 'color': Colors.blueAccent, 'action': 'social_hub', 'requiresInternet': true},
          {'title': 'Study Room', 'icon': Icons.video_camera_front_rounded, 'color': Colors.deepPurpleAccent, 'action': 'study_room', 'requiresInternet': true},
          {'title': 'Q&A Forum', 'icon': Icons.forum_rounded, 'color': Colors.indigo, 'action': 'forum', 'requiresInternet': true},
          {'title': 'Partner Tasks', 'icon': Icons.group_add_rounded, 'color': Colors.green, 'action': 'partner_tasks', 'requiresInternet': true},
          {'title': 'Web Study', 'icon': Icons.bookmarks_rounded, 'color': Colors.blue, 'action': 'bookmarks', 'requiresInternet': true},
          // Notifications এখন শুধু হোমের 🔔 আইকনে
        ]
      },
      {
        'name': 'Well-being & Utilities',
        'icon': Icons.favorite_rounded,
        'tools': [
          {'title': 'Sleep Tracker', 'icon': Icons.bedtime_rounded, 'color': Colors.indigoAccent, 'action': 'sleep'},
          {'title': 'Mood Tracker', 'icon': Icons.mood_rounded, 'color': Colors.pinkAccent, 'action': 'mood'},
          {'title': 'Theme', 'icon': Icons.palette_rounded, 'color': Colors.amber, 'action': 'theme'},
        ]
      },
      {
        // মালিকের কথামতো MCQ-র টুলগুলো তালিকার একেবারে শেষে
        'name': 'MCQ & Revision',
        'icon': Icons.quiz_rounded,
        'tools': [
          {'title': 'MCQ Practice', 'icon': Icons.quiz_rounded, 'color': const Color(0xFF16A34A), 'action': 'mcq'},
          {'title': 'Mistake Book', 'icon': Icons.menu_book_rounded, 'color': Colors.red, 'action': 'mistakes'},
          {'title': "Today's Revision", 'icon': Icons.psychology_rounded, 'color': const Color(0xFF8B5CF6), 'action': 'review'},
        ]
      },
    ];
  }

  List<Map<String, dynamic>> _buildCategories() => applyToolLayout(_defaultCategories(), _layout);

  void _openTool(Map<String, dynamic> tool) {
    final action = tool['action'] as String;
    _markRecent(action);
    void push(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    void sheet(Widget child) => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) => child,
        );
    switch (action) {
      case 'mood':
        sheet(const MoodTrackerBottomSheet());
      case 'breath':
        sheet(const BreathingExerciseBottomSheet());
      case 'routine':
        sheet(const RoutinePlannerBottomSheet());
      case 'theme':
        sheet(const ThemeCustomizerBottomSheet());
      case 'mcq':
        push(const McqHomeScreen());
      case 'mistakes':
        push(const MistakeBookScreen());
      case 'review':
        push(const DailyReviewScreen());
      case 'photo_note':
        push(const PhotoToNoteScreen());
      case 'forum':
        push(const ForumScreen());
      case 'weekly_report':
        push(const WeeklyReportScreen());
      case 'analytics':
        push(const StudyAnalyticsScreen());
      case 'pdf_reader':
        push(const PdfReaderScreen());
      case 'pomodoro':
        push(const PomodoroTimerScreen());
      case 'stopwatch':
        push(const StopwatchScreen());
      case 'calc':
        push(const CalculatorScreen());
      case 'study_room':
        push(const StudyRoomScreen());
      case 'partner_tasks':
        push(const PartnerTasksScreen());
      case 'social_hub':
        push(const SocialHubScreen());
      case 'notifications':
        push(const NotificationsHubScreen());
      case 'notes':
        push(const QuickNotesScreen());
      case 'sleep':
        push(const SleepTrackerScreen());
      case 'music':
        push(const FocusMusicScreen());
      case 'flash':
        push(const FlashcardDecksScreen());
      case 'news':
        push(const NewsReaderScreen());
      case 'dict':
        push(const DictionaryScreen());
      case 'revision_147':
        push(const Revision147Screen());
      case 'task_history':
        push(const TaskHistoryScreen());
      case 'study_folders':
        push(const StudyFolderManagerScreen());
      case 'countdown':
        push(const SpecialDayCountdownScreen());
      case 'calendar':
        push(const CalendarScreen());
      case 'gsheet_sync':
        push(const GoogleSheetSyncScreen());
      case 'multi_sheet':
        push(const MultiSheetManagerScreen());
      case 'islamic':
        push(const IslamicLifeScreen());
      case 'daily_diary':
        push(const DailyDiaryScreen());
      case 'bookmarks':
        push(const BookmarksScreen());
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${(tool['title'] as String).tr()} ${'is coming soon!'.tr()}')),
        );
    }
  }

  bool _matches(Map<String, dynamic> tool, String q) {
    final title = (tool['title'] as String);
    final hay = '${title.toLowerCase()} ${title.tr().toLowerCase()}';
    return hay.contains(q);
  }

  Widget _buildToolTile(Map<String, dynamic> tool) {
    final cardDeco = ThemeManager.getCardDecoration(context);
    final isPinned = _pinned.contains(tool['action']);
    final Color color = tool['color'] as Color;
    return Container(
      decoration: cardDeco,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: cardDeco.borderRadius as BorderRadius?,
              onTap: () => _openTool(tool),
              onLongPress: () => _showToolOptions(tool),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(tool['icon'] as IconData, size: 22, color: color),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      (tool['title'] as String).tr(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, height: 1.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isPinned)
            const Positioned(
              top: 6,
              left: 6,
              child: Icon(Icons.star_rounded, size: 14, color: Colors.amber),
            ),
          if (tool['requiresInternet'] == true && _isOffline)
            Positioned(
              top: 8,
              right: 8,
              child: Tooltip(
                message: 'Offline - Requires Internet'.tr(),
                child: const Icon(Icons.wifi_off_rounded, size: 13, color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolGrid(List<Map<String, dynamic>> tools) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // এক লাইনে ৩টি করে বক্স থাকবে
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) => _buildToolTile(tools[index]),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, {Color? iconColor, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(top: 28.0, bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor ?? Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  /// সম্প্রতি ব্যবহৃত টুলগুলোর এক সারির ছোট চিপ
  Widget _buildRecentRow(List<Map<String, dynamic>> recentTools) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recentTools.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final tool = recentTools[i];
          final color = tool['color'] as Color;
          return ActionChip(
            avatar: Icon(tool['icon'] as IconData, size: 18, color: color),
            label: Text((tool['title'] as String).tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
            backgroundColor: color.withValues(alpha: 0.08),
            side: BorderSide(color: color.withValues(alpha: 0.25)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            labelStyle: TextStyle(color: scheme.onSurface, fontSize: 12),
            onPressed: () => _openTool(tool),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _buildCategories();
    final allTools = <String, Map<String, dynamic>>{
      for (final c in categories)
        for (final t in (c['tools'] as List<Map<String, dynamic>>)) t['action'] as String: t,
    };
    final pinnedTools = _pinned.where(allTools.containsKey).map((a) => allTools[a]!).toList();
    final recentTools = _recent.where(allTools.containsKey).map((a) => allTools[a]!).toList();
    final q = _query.trim().toLowerCase();
    final searchResults = q.isEmpty ? <Map<String, dynamic>>[] : allTools.values.where((t) => _matches(t, q)).toList();
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Study Tools'.tr(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _openArrange,
                  icon: const Icon(Icons.swap_vert_rounded, size: 20),
                  label: Text(trx('Arrange', 'সাজান')),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // সার্চ বার
            TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: trx('Search tools… (e.g. notes, pomodoro)', 'টুল খুঁজুন… (যেমন: নোট, পোমোডোরো)'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: trx('Clear', 'মুছুন'),
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                          FocusScope.of(context).unfocus();
                        },
                      ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),

            if (q.isNotEmpty) ...[
              _buildSectionHeader(Icons.search_rounded, trx('Results (${searchResults.length})', 'ফলাফল (${searchResults.length})')),
              if (searchResults.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      trx('No tool found for "$_query".', '"$_query" নামে কোনো টুল পাওয়া যায়নি।'),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              else
                _buildToolGrid(searchResults),
            ] else ...[
              if (pinnedTools.isNotEmpty) ...[
                _buildSectionHeader(Icons.star_rounded, trx('Favourites', 'পছন্দের টুল'), iconColor: Colors.amber),
                _buildToolGrid(pinnedTools),
              ],
              if (recentTools.isNotEmpty) ...[
                _buildSectionHeader(Icons.history_rounded, trx('Recently used', 'সম্প্রতি ব্যবহৃত')),
                _buildRecentRow(recentTools),
              ],
              if (pinnedTools.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    trx('Tip: long-press any tool to pin it here ⭐. Tap "Arrange" to change the order.',
                        'টিপস: যেকোনো টুল লম্বা করে চেপে ধরে উপরে পিন করুন ⭐। ক্রম বদলাতে "সাজান" চাপুন।'),
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ),
              const SizedBox(height: 20),

              // AI Study Planner Banner (First Tool)
              _buildAIPlannerBanner(context),
              const SizedBox(height: 12),
              _buildNextDayRoutineButton(context),
              const SizedBox(height: 12),
              _buildWeeklyRoutineButton(context),

              for (final category in categories)
                if ((category['tools'] as List).isNotEmpty) ...[
                _buildSectionHeader(category['icon'] as IconData, (category['name'] as String).tr()),
                _buildToolGrid(category['tools'] as List<Map<String, dynamic>>),
              ],
            ],
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
    return GestureDetector(
      onTap: () => showNextDayRoutineSheet(context),
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

