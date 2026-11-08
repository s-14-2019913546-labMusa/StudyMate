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
  bool _alarmEnabled = true; // à¦à¦²à¦¾à¦°à§à¦® à¦…à¦¨/à¦…à¦«

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
    if (!_alarmEnabled) return; // à¦à¦²à¦¾à¦°à§à¦® à¦¬à¦¨à§à¦§ à¦¥à¦¾à¦•à¦²à§‡ à¦¬à¦¾à¦œà¦¾à¦¬à§‡ à¦¨à¦¾
    SoundPlayer.playAlarmNotificationSound(looping: true);
    showDialog(
      context: context,
      barrierDismissible: false, // à¦¬à§à¦¯à¦¾à¦•à¦—à§à¦°à¦¾à¦‰à¦¨à§à¦¡à§‡ à¦Ÿà§à¦¯à¦¾à¦ª à¦•à¦°à¦²à§‡ à¦¬à¦¨à§à¦§ à¦¨à¦¾ à¦¹à¦“à¦¯à¦¼à¦¾à¦° à¦œà¦¨à§à¦¯
      builder: (_) => AlertDialog(
        title: const Text('â° Timer Finished!', textAlign: TextAlign.center),
        content: const Text('à¦†à¦ªà¦¨à¦¾à¦° à¦•à¦¾à¦‰à¦¨à§à¦Ÿà¦¡à¦¾à¦‰à¦¨ à¦Ÿà¦¾à¦‡à¦®à¦¾à¦° à¦¶à§‡à¦· à¦¹à¦¯à¦¼à§‡à¦›à§‡à¥¤', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              SoundPlayer.stopAlarm(); // à¦†à¦—à§‡ à¦¸à¦¾à¦‰à¦¨à§à¦¡ à¦¬à¦¨à§à¦§ à¦•à¦°à§‹
              Navigator.pop(context);  // à¦¤à¦¾à¦°à¦ªà¦° à¦¡à¦¾à¦¯à¦¼à¦¾à¦²à¦— à¦¬à¦¨à§à¦§
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('â¹ Stop Alarm', style: TextStyle(color: Colors.white)),
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
          // â”€â”€â”€ à¦à¦²à¦¾à¦°à§à¦® à¦Ÿà¦—à¦² â”€â”€â”€
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
                          'à¦à¦²à¦¾à¦°à§à¦®',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _alarmEnabled ? 'à¦Ÿà¦¾à¦‡à¦®à¦¾à¦° à¦¶à§‡à¦·à§‡ à¦à¦²à¦¾à¦°à§à¦® à¦¬à¦¾à¦œà¦¬à§‡' : 'à¦Ÿà¦¾à¦‡à¦®à¦¾à¦° à¦¶à§‡à¦·à§‡ à¦à¦²à¦¾à¦°à§à¦® à¦¬à¦¾à¦œà¦¬à§‡ à¦¨à¦¾',
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
          // â”€â”€â”€ à¦Ÿà¦¾à¦‡à¦®à¦¾à¦° à¦ªà¦¿à¦•à¦¾à¦° / à¦•à¦¾à¦‰à¦¨à§à¦Ÿà¦¡à¦¾à¦‰à¦¨ à¦¡à¦¿à¦¸à¦ªà§à¦²à§‡ â”€â”€â”€
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
          // â”€â”€â”€ à¦¬à¦¾à¦Ÿà¦¨à¦—à§à¦²à§‹ â”€â”€â”€
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
