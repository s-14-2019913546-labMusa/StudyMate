import 'package:flutter/material.dart';
import 'dnd_service.dart';
import 'focus_music_screen.dart';
import 'language_manager.dart';
import 'study_habits_service.dart';
import 'tools/breathing_player_screen.dart';
import 'tools/pomodoro_timer_screen.dart';
import 'tools/stopwatch_screen.dart';
import 'weekly_report_screen.dart';

/// নিচের "Focus" ট্যাব: মনোযোগের সব টুল এক জায়গায় + আজকের হিসাব + নোটিফিকেশন নীরব
class FocusHubScreen extends StatefulWidget {
  const FocusHubScreen({super.key});

  @override
  State<FocusHubScreen> createState() => _FocusHubScreenState();
}

class _FocusHubScreenState extends State<FocusHubScreen> with WidgetsBindingObserver {
  int _minutes = 0;
  int _goal = 240;
  int _distractions = 0;
  bool _dndAccess = false;
  bool _dndOn = false;
  bool _autoDnd = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ফোনের সেটিংস থেকে অনুমতি দিয়ে ফিরলে আবার দেখা
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final results = await Future.wait([
      StudyHabitsService.studyMinutesOn(now),
      StudyHabitsService.getDailyGoal(),
      StudyHabitsService.distractionsOn(now),
    ]);
    final access = await DndService.hasAccess();
    final on = await DndService.isOn();
    final auto = await DndService.autoInFocus();
    if (!mounted) return;
    setState(() {
      _minutes = results[0];
      _goal = results[1];
      _distractions = results[2];
      _dndAccess = access;
      _dndOn = on;
      _autoDnd = auto;
    });
  }

  String _hm(int minutes) {
    final h = minutes ~/ 60, m = minutes % 60;
    return trx('${h > 0 ? '${h}h ' : ''}${m}m', '${h > 0 ? '$h ঘ ' : ''}$m মি');
  }

  void _open(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) => _load());

  Future<void> _toggleDnd(bool v) async {
    if (!_dndAccess) {
      await _askAccess();
      return;
    }
    await DndService.set(v);
    _load();
  }

  Future<void> _askAccess() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trx('Allow "Do Not Disturb"', '"বিরক্ত করবেন না" অনুমতি দিন')),
        content: Text(trx(
          'Android asks you once to let StudyMate turn on Do Not Disturb. On the next screen, find StudyMate and switch it on, then come back.',
          'Android একবার অনুমতি চায় যাতে StudyMate "বিরক্ত করবেন না" চালু করতে পারে। পরের স্ক্রিনে StudyMate খুঁজে চালু করুন, তারপর ফিরে আসুন।',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel'.tr())),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(trx('Open settings', 'সেটিংস খুলুন'))),
        ],
      ),
    );
    if (go == true) await DndService.openSettings();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = _goal == 0 ? 0.0 : (_minutes / _goal).clamp(0.0, 1.0);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Text(trx('Focus', 'মনোযোগ'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF047857)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: Stack(alignment: Alignment.center, children: [
                      CircularProgressIndicator(
                        value: p,
                        strokeWidth: 7,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                        strokeCap: StrokeCap.round,
                      ),
                      Text('${(p * 100).round()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trx('Studied today', 'আজ পড়েছেন'), style: const TextStyle(color: Colors.white70)),
                        Text('${_hm(_minutes)} / ${_hm(_goal)}',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(trx('Focus broken: $_distractions times', 'মনোযোগ ভেঙেছে: $_distractions বার'),
                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _tile(Icons.timer_rounded, Colors.redAccent, 'Pomodoro'.tr(), trx('25 min focus', '২৫ মিনিট ফোকাস'),
                    () => _open(const PomodoroTimerScreen())),
                _tile(Icons.timer_outlined, Colors.deepOrange, 'Stopwatch'.tr(), trx('Free timing', 'নিজের মতো সময়'),
                    () => _open(const StopwatchScreen())),
                _tile(Icons.headphones_rounded, Colors.teal, 'Focus Music'.tr(), trx('Rain, forest, lo-fi', 'বৃষ্টি, বন, লো-ফাই'),
                    () => _open(const FocusMusicScreen())),
                _tile(Icons.air_rounded, Colors.lightBlue, 'Breathing'.tr(), trx('Calm down in 1 min', '১ মিনিটে শান্ত হোন'),
                    () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const BreathingExerciseBottomSheet(),
                        )),
              ],
            ),
            const SizedBox(height: 18),
            if (DndService.supported)
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.do_not_disturb_on_rounded),
                      title: Text(trx('Silence other notifications now', 'এখন অন্য নোটিফিকেশন নীরব')),
                      subtitle: Text(_dndAccess
                          ? trx('Turns on Do Not Disturb (calls from favourites still ring)', '"বিরক্ত করবেন না" চালু হবে (পছন্দের কল তবুও আসবে)')
                          : trx('Needs a one-time permission', 'একবার অনুমতি দিতে হবে')),
                      value: _dndOn,
                      onChanged: _toggleDnd,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.auto_mode_rounded),
                      title: Text(trx('Automatically during Pomodoro focus', 'Pomodoro ফোকাসের সময় নিজে থেকে')),
                      subtitle: Text(trx('Turns back off when the focus ends', 'ফোকাস শেষ হলে আবার বন্ধ হবে')),
                      value: _autoDnd,
                      onChanged: (v) async {
                        if (v && !_dndAccess) {
                          await _askAccess();
                          return;
                        }
                        await DndService.setAutoInFocus(v);
                        _load();
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.bar_chart_rounded),
                title: Text(trx('Weekly report', 'সাপ্তাহিক রিপোর্ট')),
                subtitle: Text(trx('This week vs last week, by subject', 'এই সপ্তাহ বনাম আগের সপ্তাহ, বিষয় অনুযায়ী')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _open(const WeeklyReportScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(IconData icon, Color color, String title, String subtitle, VoidCallback onTap) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 30),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(subtitle, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
