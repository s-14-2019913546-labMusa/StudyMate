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
    SoundPlayer.playAlarmNotificationSound(looping: true);
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
              SoundPlayer.stopAlarm();
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

