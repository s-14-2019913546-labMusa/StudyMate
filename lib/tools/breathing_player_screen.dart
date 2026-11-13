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
// 2. Breathing Exercise Bottom Sheet
// ==========================================
class BreathingExerciseBottomSheet extends StatelessWidget {
  const BreathingExerciseBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final patterns = [
      {'title': trx('4-7-8 Relaxing Breath', '৪-৭-৮ আরামের শ্বাস'), 'desc': trx('Inhale 4s, Hold 7s, Exhale 8s.', 'শ্বাস নিন ৪ সে., ধরে রাখুন ৭ সে., ছাড়ুন ৮ সে.।'), 'icon': Icons.self_improvement_rounded, 'phases': [4, 7, 8, 0]},
      {'title': trx('Box Breathing', 'বক্স ব্রিদিং'), 'desc': trx('Inhale 4s, Hold 4s, Exhale 4s, Hold 4s.', 'শ্বাস নিন ৪ সে., ধরে রাখুন ৪ সে., ছাড়ুন ৪ সে., থামুন ৪ সে.।'), 'icon': Icons.crop_square_rounded, 'phases': [4, 4, 4, 4]},
      {'title': trx('Equal Breathing', 'সমান শ্বাস'), 'desc': trx('Inhale 5s, Exhale 5s.', 'শ্বাস নিন ৫ সে., ছাড়ুন ৫ সে.।'), 'icon': Icons.balance_rounded, 'phases': [5, 0, 5, 0]},
      {'title': trx('Deep Calm', 'গভীর প্রশান্তি'), 'desc': trx('Inhale 4s, Exhale 6s.', 'শ্বাস নিন ৪ সে., ছাড়ুন ৬ সে.।'), 'icon': Icons.waves_rounded, 'phases': [4, 0, 6, 0]},
    ];

    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(trx('Breathing Exercises', 'শ্বাসের ব্যায়াম'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.lightBlue)),
          const SizedBox(height: 8),
          Text(trx('Choose a pattern to boost your focus and calm your mind.', 'একটা ধরন বেছে নিন: মনোযোগ বাড়বে, মন শান্ত হবে।'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
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
    if (!_isRunning) return trx('Ready?', 'প্রস্তুত?');
    switch (_phaseIndex) {
      case 0: return trx('Inhale', 'শ্বাস নিন');
      case 1: return trx('Hold', 'ধরে রাখুন');
      case 2: return trx('Exhale', 'শ্বাস ছাড়ুন');
      case 3: return trx('Hold', 'থামুন');
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
                    trx('${remaining}s', '${LanguageManager.toBnDigits('$remaining')} সে.'),
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

