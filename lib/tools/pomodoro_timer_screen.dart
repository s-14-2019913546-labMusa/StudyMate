import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../local_notification_service.dart';
import '../gamification_service.dart';
import '../language_manager.dart';
import '../study_habits_service.dart';
import '../dnd_service.dart';

// ==========================================
// 4. Pomodoro Timer Screen (Forest Edition)
// ==========================================
class PomodoroTimerScreen extends StatefulWidget {
  const PomodoroTimerScreen({super.key});

  @override
  State<PomodoroTimerScreen> createState() => _PomodoroTimerScreenState();
}

/// নিয়ম:
/// - ফোকাস ডিফল্টে সবসময় ২৫ মিনিট; চাইলে এই বারের জন্য বাড়ানো যায় (পাতা আবার খুললে ২৫-এ ফেরে)।
/// - ফোকাস শুরু হলে (চলুক বা Pause থাকুক) অ্যাপ থেকে ১০ সেকেন্ডের বেশি বাইরে থাকলে গাছ মরে।
/// - ফোকাস চলার মাঝে পাতা ছেড়ে গেলে আগে জিজ্ঞেস করা হয়; বের হলে গাছ মরে।
/// - "মনোযোগ ভেঙেছে" গোনা হয় শুধু যখন সত্যিই গাছ মরে (দেরিতে ফেরা বা মাঝপথে বের হওয়া)।
/// - প্রতি ৪টা ফোকাসের পর ১৫ মিনিটের বড় বিরতি, বাকি সময় ৫ মিনিট।
class _PomodoroTimerScreenState extends State<PomodoroTimerScreen> with WidgetsBindingObserver {
  static const int defaultFocusMinutes = 25;
  static const int shortBreakMinutes = 5;
  static const int longBreakMinutes = 15;
  static const int sessionsPerLongBreak = 4;
  static const List<int> focusChoices = [25, 30, 40, 45, 50, 60, 90];

  static const String _focus = 'Focus', _short = 'Short Break', _long = 'Long Break';

  int _focusMinutes = defaultFocusMinutes;
  String _currentMode = _focus;
  int _selectedDuration = defaultFocusMinutes * 60;
  int _remainingSeconds = defaultFocusMinutes * 60;
  bool _isRunning = false;
  bool _sessionActive = false; // ফোকাস শুরু হয়েছে, এখনো শেষ/রিসেট হয়নি (Pause থাকলেও true)
  DateTime? _endAt; // চলার সময় কখন শেষ হবে (ঘড়ি ধরে হিসাব, তাই ব্যাকগ্রাউন্ডেও ঠিক থাকে)
  Timer? _timer;

  bool _treeKilled = false;
  int _sessionCount = 0; // মোট গাছ
  int _cyclesToday = 0; // আজ কয়টা ফোকাস শেষ হলো (বড় বিরতির হিসাবের জন্য)

  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  static const int _graceSeconds = 10;
  static const int _focusWarningId = 777010;
  DateTime? _leftAt;
  int _distractionsToday = 0;

  String _modeLabel(String m) => switch (m) {
        _focus => trx('Focus', 'ফোকাস'),
        _short => trx('Short break', 'ছোট বিরতি'),
        _ => trx('Long break', 'বড় বিরতি'),
      };

  String _getTreeStage(double progress) {
    if (progress <= 0.0) return '🌱';
    if (progress < 0.3) return '🌿';
    if (progress < 0.6) return '🌳';
    return '🌲';
  }

  String get _cycleKey => 'pomodoro_cycles_${StudyHabitsService.todayId()}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSessionCount();
    _loadDistractions();
    _loadCycles();
  }

  Future<void> _loadCycles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _cyclesToday = prefs.getInt(_cycleKey) ?? 0);
    } catch (_) {}
  }

  Future<void> _saveCycles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_cycleKey, _cyclesToday);
    } catch (_) {}
  }

  Future<void> _loadDistractions() async {
    final n = await StudyHabitsService.distractionsOn(DateTime.now());
    if (mounted) setState(() => _distractionsToday = n);
  }

  Future<void> _loadSessionCount() async {
    if (_user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(_user.uid).collection('pomodoroForest').doc('stats').get();
      if (doc.exists && mounted) {
        setState(() => _sessionCount = (doc.data()?['totalTrees'] ?? 0) as int);
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_currentMode != _focus || !_sessionActive) return;
    if (state == AppLifecycleState.paused && _leftAt == null) {
      _leftAt = DateTime.now();
      LocalNotificationService.scheduleNotification(
        id: _focusWarningId,
        title: trx('🌱 Come back to your tree!', '🌱 গাছের কাছে ফিরে আসুন!'),
        body: trx('Return within $_graceSeconds seconds or your focus tree will wither.',
            '১০ সেকেন্ডের মধ্যে ফিরে না এলে ফোকাসের গাছটা মরে যাবে।'),
        scheduledDate: DateTime.now().add(const Duration(seconds: 1)),
        channelId: 'focus_guard_channel',
        channelName: 'Focus Guard',
        channelDescription: 'Warns you when you leave the app during a Pomodoro focus session',
      );
    } else if (state == AppLifecycleState.resumed && _leftAt != null) {
      final away = DateTime.now().difference(_leftAt!);
      // বের হওয়ার ১০ সেকেন্ডের মধ্যেই সময় শেষ হয়ে গিয়ে থাকলে সেশনটা সফল
      final finishedInGrace = _isRunning &&
          _endAt != null &&
          !_endAt!.isAfter(_leftAt!.add(const Duration(seconds: _graceSeconds)));
      _leftAt = null;
      LocalNotificationService.cancelNotification(_focusWarningId);
      if (away.inSeconds > _graceSeconds && !finishedInGrace) {
        _killTree(countDistraction: true);
      } else {
        _tick(); // বাইরে থাকার সময় শেষ হয়ে গিয়ে থাকলে এখন গাছ লাগবে
        if (_sessionActive && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(trx('Welcome back — your tree is safe 🌱', 'ফিরে আসার জন্য ধন্যবাদ, গাছ বেঁচে আছে 🌱')),
            duration: const Duration(seconds: 2),
          ));
        }
      }
    }
  }

  // ফোকাস চলার সময় স্ক্রিন জাগিয়ে রাখা (MainActivity.kt-এর 'studymate/screen' চ্যানেল),
  // নইলে স্ক্রিন নিজে বন্ধ হয়ে অ্যাপ "paused" হয়ে গাছ মরে যেত।
  static const MethodChannel _screenChannel = MethodChannel('studymate/screen');
  bool? _screenKeptOn;

  void _syncScreenOn() {
    final bool want = _isRunning && _currentMode == _focus;
    if (_screenKeptOn == want) return;
    _screenKeptOn = want;
    _screenChannel.invokeMethod('keepOn', {'on': want}).catchError((_) {});
    DndService.onFocusChanged(want);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocalNotificationService.cancelNotification(_focusWarningId);
    if (_screenKeptOn == true) {
      _screenChannel.invokeMethod('keepOn', {'on': false}).catchError((_) {});
      DndService.onFocusChanged(false);
    }
    _timer?.cancel();
    super.dispose();
  }

  void _setMode(String mode) {
    _timer?.cancel();
    final minutes = switch (mode) { _focus => _focusMinutes, _short => shortBreakMinutes, _ => longBreakMinutes };
    setState(() {
      _currentMode = mode;
      _selectedDuration = minutes * 60;
      _remainingSeconds = _selectedDuration;
      _isRunning = false;
      _sessionActive = false;
      _endAt = null;
      _treeKilled = false;
    });
  }

  void _killTree({required bool countDistraction}) {
    _timer?.cancel();
    if (countDistraction) {
      StudyHabitsService.addDistraction().then((_) => _loadDistractions());
    }
    if (!mounted) return;
    setState(() {
      _isRunning = false;
      _sessionActive = false;
      _endAt = null;
      _treeKilled = true;
      _remainingSeconds = _selectedDuration;
    });
  }

  void _tick() {
    if (!_isRunning || _endAt == null) return;
    final left = _endAt!.difference(DateTime.now()).inMilliseconds;
    final secs = (left / 1000).ceil().clamp(0, _selectedDuration);
    if (secs > 0) {
      if (mounted) setState(() => _remainingSeconds = secs);
      return;
    }
    // অ্যাপের বাইরে থাকা অবস্থায় শেষ হলে ফিরে আসা পর্যন্ত অপেক্ষা (তখন দেরির নিয়ম আগে দেখা হবে)
    if (_leftAt != null) return;
    _timer?.cancel();
    setState(() {
      _remainingSeconds = 0;
      _isRunning = false;
      _sessionActive = false;
      _endAt = null;
    });
    _onTimerComplete();
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() {
        _isRunning = false;
        _endAt = null;
      });
      return;
    }
    setState(() {
      _isRunning = true;
      _treeKilled = false;
      if (_currentMode == _focus) _sessionActive = true;
      _endAt = DateTime.now().add(Duration(seconds: _remainingSeconds));
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  void _resetTimer() {
    if (_sessionActive && _currentMode == _focus) {
      _killTree(countDistraction: false); // নিজে রিসেট করলে গাছ মরে, কিন্তু "মনোযোগ ভাঙা" গোনা হয় না
      return;
    }
    _timer?.cancel();
    setState(() {
      _remainingSeconds = _selectedDuration;
      _isRunning = false;
      _endAt = null;
    });
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(trx('Focus is running', 'ফোকাস চলছে')),
        content: Text(trx('If you leave now, your tree will die and it counts as broken focus.',
            'এখন বের হলে গাছটা মরে যাবে, আর "মনোযোগ ভেঙেছে" হিসেবে গোনা হবে।')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(trx('Leave', 'বের হই'))),
          FilledButton(onPressed: () => Navigator.pop(c, false), child: Text(trx('Keep focusing', 'থাকি, পড়ি'))),
        ],
      ),
    );
    return leave == true;
  }

  Future<void> _pickFocusLength() async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (c) {
        final scheme = Theme.of(c).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trx('Focus length', 'ফোকাসের সময়'), style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(trx(
                      'Usually 25 minutes is the best way to hold your attention: focus 25 minutes, then a short break. Choose longer only if you really need it. Next time it starts at 25 again.',
                      'সাধারণত ২৫ মিনিটই মনোযোগ ধরে রাখার সেরা উপায়: ২৫ মিনিট ফোকাস, তারপর ছোট বিরতি। খুব দরকার হলেই বাড়ান। পরেরবার আবার ২৫ মিনিট থেকেই শুরু হবে।',
                    )),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in focusChoices)
                  ChoiceChip(
                    label: Text(m == defaultFocusMinutes
                        ? trx('$m min (best)', '${LanguageManager.toBnDigits('$m')} মিনিট (সেরা)')
                        : trx('$m min', '${LanguageManager.toBnDigits('$m')} মিনিট')),
                    selected: _focusMinutes == m,
                    selectedColor: scheme.primaryContainer,
                    onSelected: (_) => Navigator.pop(c, m),
                  ),
              ]),
            ],
          ),
        );
      },
    );
    if (chosen == null || !mounted) return;
    setState(() => _focusMinutes = chosen);
    _setMode(_focus);
  }

  void _onTimerComplete() {
    SoundPlayer.playAlarmNotificationSound(looping: true);
    final wasFocus = _currentMode == _focus;
    String nextMode = _focus;
    if (wasFocus) {
      _cyclesToday++;
      _saveCycles();
      _plantTreeAndAwardXP(_focusMinutes);
      nextMode = _cyclesToday % sessionsPerLongBreak == 0 ? _long : _short;
    }
    final mins = LanguageManager().isBengali ? LanguageManager.toBnDigits('$_focusMinutes') : '$_focusMinutes';
    final nth = _cyclesToday % sessionsPerLongBreak == 0 ? sessionsPerLongBreak : _cyclesToday % sessionsPerLongBreak;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          wasFocus ? trx('🌲 Tree planted!', '🌲 গাছ লাগানো হয়েছে!') : trx('⏰ Break over!', '⏰ বিরতি শেষ!'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          wasFocus
              ? (nextMode == _long
                  ? trx('Great! $mins minutes of focus. That was session $sessionsPerLongBreak of $sessionsPerLongBreak — take a long $longBreakMinutes-minute break now.',
                      'অসাধারণ! $mins মিনিট মনোযোগ ধরে রেখেছেন। এটা ছিল ৪টার মধ্যে ৪ নম্বর সেশন, এখন ১৫ মিনিটের বড় বিরতি নিন।')
                  : trx('Great! $mins minutes of focus. A new tree is in your garden. Session $nth of $sessionsPerLongBreak before a long break.',
                      'অসাধারণ! $mins মিনিট মনোযোগ ধরে রেখেছেন। বাগানে নতুন গাছ যোগ হয়েছে। বড় বিরতির আগে ৪টার মধ্যে ${LanguageManager.toBnDigits('$nth')} নম্বর সেশন।'))
              : trx('Break is over. Ready to focus again?', 'বিরতি শেষ। আবার ফোকাস করতে প্রস্তুত?'),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              SoundPlayer.stopAlarm();
              Navigator.pop(ctx);
              _setMode(nextMode);
            },
            child: Text(!wasFocus
                ? trx('Start focus', 'আবার শুরু করুন')
                : nextMode == _long
                    ? trx('Take a 15-min break', '১৫ মিনিট বিরতি নিন')
                    : trx('Take a 5-min break', '৫ মিনিট বিরতি নিন')),
          )
        ],
      ),
    );
  }

  Future<void> _plantTreeAndAwardXP(int minutes) async {
    if (_user == null) return;
    try {
      await _firestore.collection('users').doc(_user.uid).collection('pomodoroForest').doc('trees').collection('list').add({
        'plantedAt': FieldValue.serverTimestamp(),
        'type': '🌲',
        'sessionMinutes': minutes,
      });
      await _firestore.collection('users').doc(_user.uid).collection('pomodoroForest').doc('stats').set({
        'totalTrees': FieldValue.increment(1),
        'lastPlanted': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ২৫ মিনিটে ৮ XP; লম্বা সেশনে সময়ের অনুপাতে
      final xp = (GamificationService.xpPomodoroSession * minutes / defaultFocusMinutes).round();
      final res = await GamificationService.awardXP(xp, reason: 'pomodoro_session_complete');
      if (mounted && res.isNotEmpty) {
        final int xpAwarded = res['xpAwarded'] ?? 0;
        final List<String> newBadges = List<String>.from(res['newBadges'] ?? []);
        var msg = trx('🌲 Tree planted! +$xpAwarded XP', '🌲 গাছ লাগানো হয়েছে! +$xpAwarded XP');
        if (newBadges.isNotEmpty) msg += trx('\n🏆 Unlocked: ${newBadges.join(", ")}!', '\n🏆 নতুন ব্যাজ: ${newBadges.join(", ")}!');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green.shade700),
        );
      }
      if (mounted) setState(() => _sessionCount++);
    } catch (e) {
      debugPrint('Error planting tree: $e');
    }
  }

  String _digits(String s) => LanguageManager().isBengali ? LanguageManager.toBnDigits(s) : s;

  @override
  Widget build(BuildContext context) {
    _syncScreenOn();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final progress = 1 - (_remainingSeconds / _selectedDuration);
    final isFocus = _currentMode == _focus;
    final Color focusColor = Colors.green.shade700;
    const Color breakColor = Colors.teal;
    final inCycle = _cyclesToday % sessionsPerLongBreak;

    return PopScope(
      canPop: !(_sessionActive && isFocus),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave()) {
          _killTree(countDistraction: true);
          if (mounted) Navigator.of(this.context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0D1F13) : const Color(0xFFF0FAF2),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Pomodoro'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.forest_rounded),
              tooltip: trx('My garden', 'আমার বাগান'),
              onPressed: () => _showForestGarden(context),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildModeButton(_focus, focusColor),
                  _buildModeButton(_short, breakColor),
                  _buildModeButton(_long, breakColor),
                ],
              ),
              const SizedBox(height: 10),
              // বড় বিরতির আগে কয়টা সেশন হলো
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < sessionsPerLongBreak; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Icon(i < inCycle ? Icons.circle : Icons.circle_outlined, size: 11, color: focusColor),
                  ),
                const SizedBox(width: 6),
                Text(
                  trx('$inCycle of $sessionsPerLongBreak before a long break', 'বড় বিরতির আগে ৪টার মধ্যে ${LanguageManager.toBnDigits('$inCycle')}টা'),
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ]),
              const SizedBox(height: 22),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                child: _treeKilled
                    ? Column(
                        key: const ValueKey('dead'),
                        children: [
                          const Text('🥀', style: TextStyle(fontSize: 80)),
                          const SizedBox(height: 8),
                          Text(
                            trx('Oh no! The tree died 😢\nDon\'t break your focus!', 'ওহ না! গাছটি মরে গেছে 😢\nমনোযোগ ভাঙবেন না!'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600),
                          ),
                        ],
                      )
                    : Column(
                        key: ValueKey('tree_${_getTreeStage(progress)}_$isFocus'),
                        children: [
                          Text(isFocus ? _getTreeStage(progress) : '☁️', style: const TextStyle(fontSize: 90)),
                          const SizedBox(height: 8),
                          Text(
                            isFocus
                                ? (progress < 0.01
                                    ? trx('Ready to plant a seed...', 'বীজ রোপণের জন্য প্রস্তুত...')
                                    : trx('Your tree is growing...', 'গাছ বড় হচ্ছে...'))
                                : trx('Take a rest 🌤️', 'বিশ্রাম নিন 🌤️'),
                            style: TextStyle(color: isDark ? Colors.green.shade300 : Colors.green.shade700, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
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
                      color: isFocus ? focusColor : breakColor,
                    ),
                  ),
                  Column(
                    children: [
                      Text(_digits(timeString), style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      Text(_modeLabel(_currentMode),
                          style: TextStyle(fontSize: 13, color: isFocus ? focusColor : breakColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isFocus)
                TextButton.icon(
                  onPressed: _sessionActive ? null : _pickFocusLength,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(trx('$_focusMinutes min · change', '${LanguageManager.toBnDigits('$_focusMinutes')} মিনিট · বদলান')),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _resetTimer,
                    icon: Icon(Icons.refresh_rounded, size: 36, color: Colors.grey.shade500),
                    tooltip: isFocus ? trx('Reset (the tree will die!)', 'রিসেট (গাছ মরে যাবে!)') : trx('Reset', 'রিসেট'),
                  ),
                  const SizedBox(width: 20),
                  FloatingActionButton.large(
                    heroTag: 'pomodoro_play',
                    onPressed: _toggleTimer,
                    tooltip: _isRunning ? trx('Pause', 'থামান') : trx('Start', 'শুরু করুন'),
                    backgroundColor: isFocus ? focusColor : breakColor,
                    elevation: 6,
                    child: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 40),
                  ),
                  const SizedBox(width: 20),
                  Tooltip(
                    message: trx('Trees planted', 'মোট গাছ'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Column(children: [
                        const Text('🌲', style: TextStyle(fontSize: 18)),
                        Text(_digits('$_sessionCount'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                trx('Focus broken today: $_distractionsToday times', 'আজ মনোযোগ ভেঙেছে: ${LanguageManager.toBnDigits('$_distractionsToday')} বার'),
                style: TextStyle(fontSize: 12, color: _distractionsToday == 0 ? Colors.green : Colors.orange, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              if (isFocus && _sessionActive)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _isRunning
                        ? trx('⚠️ Leave the app for more than 10 s and the tree withers!', '⚠️ ১০ সেকেন্ডের বেশি অ্যাপের বাইরে থাকলে গাছটি মরে যাবে!')
                        : trx('⏸ Paused. Leaving the app for more than 10 s still kills the tree.',
                            '⏸ থামানো আছে। তবু ১০ সেকেন্ডের বেশি অ্যাপের বাইরে থাকলে গাছ মরে যাবে।'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orange.shade600, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text(trx('🌳 My garden', '🌳 আমার বাগান'),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.green.shade300 : Colors.green.shade800)),
              const SizedBox(height: 4),
              Text(trx('Each tree = 1 completed focus session', 'প্রতিটি গাছ = ১টি সফল ফোকাস সেশন'),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const Divider(height: 24),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(_user.uid)
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
                            Text(trx('No trees yet!\nStart your first focus session.', 'এখনো কোনো গাছ নেই!\nপ্রথম ফোকাস সেশন শুরু করুন।'),
                                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
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
                        final m = (data['sessionMinutes'] as num?)?.toInt() ?? defaultFocusMinutes;
                        final dateStr = ts != null ? '${ts.toDate().day}/${ts.toDate().month}' : '';
                        return Tooltip(
                          message: _digits(trx('$dateStr · $m min', '$dateStr · $m মিনিট')),
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

  Widget _buildModeButton(String mode, Color activeColor) {
    final isSelected = _currentMode == mode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(_modeLabel(mode), style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
        selected: isSelected,
        onSelected: (selected) {
          if (!selected || _isRunning) return;
          if (_sessionActive && _currentMode == _focus) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(trx('Finish or reset the focus first.', 'আগে ফোকাস শেষ করুন বা রিসেট করুন।')),
            ));
            return;
          }
          _setMode(mode);
        },
        selectedColor: activeColor.withValues(alpha: 0.2),
        labelStyle: TextStyle(color: isSelected ? activeColor : Colors.grey),
        side: isSelected ? BorderSide(color: activeColor, width: 1.5) : BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
