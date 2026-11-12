import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'language_manager.dart';
import 'study_habits_service.dart';
import 'widgets/skeleton.dart';

/// সাপ্তাহিক রিপোর্ট: এই সপ্তাহে (শনি–শুক্র) কত পড়লেন, কোন বিষয়ে বেশি/কম, আগের সপ্তাহের সাথে তুলনা
class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeekData {
  final List<int> days; // শনি..শুক্র মিনিট
  final Map<String, int> subjects;
  final int distractions;
  _WeekData(this.days, this.subjects, this.distractions);
  int get total => days.fold(0, (a, b) => a + b);
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  _WeekData? _thisWeek;
  _WeekData? _lastWeek;
  late DateTime _start;

  @override
  void initState() {
    super.initState();
    _start = StudyHabitsService.weekStart(DateTime.now());
    _load();
  }

  Future<_WeekData> _loadWeek(DateTime start, {bool untilToday = false}) async {
    final days = <int>[];
    final subjects = <String, int>{};
    var distractions = 0;
    final today = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      if (untilToday && d.isAfter(today)) {
        days.add(0);
        continue;
      }
      days.add(await StudyHabitsService.studyMinutesOn(d, perSubject: subjects));
      distractions += await StudyHabitsService.distractionsOn(d);
    }
    return _WeekData(days, subjects, distractions);
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _loadWeek(_start, untilToday: true),
      _loadWeek(_start.subtract(const Duration(days: 7))),
    ]);
    if (mounted) {
      setState(() {
        _thisWeek = results[0];
        _lastWeek = results[1];
      });
    }
  }

  String _hm(int minutes) {
    final h = minutes ~/ 60, m = minutes % 60;
    return trx('${h > 0 ? '${h}h ' : ''}${m}m', '${h > 0 ? '$h ঘণ্টা ' : ''}$m মিনিট');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = _thisWeek, l = _lastWeek;
    final bn = LanguageManager().isBengali;
    final dayNames = bn ? ['শনি', 'রবি', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র'] : ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final range = '${DateFormat('d MMM').format(_start)} – ${DateFormat('d MMM').format(_start.add(const Duration(days: 6)))}';

    return Scaffold(
      appBar: AppBar(title: Text(trx('Weekly report', 'সাপ্তাহিক রিপোর্ট'))),
      body: t == null || l == null
          ? const SkeletonCardList(count: 4)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(range, style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                _summaryCard(t, l, scheme),
                const SizedBox(height: 16),
                Text(trx('Day by day', 'দিন অনুযায়ী'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                _dayBars(t, l, dayNames, scheme),
                const SizedBox(height: 18),
                Text(trx('By subject', 'বিষয় অনুযায়ী'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ..._subjectRows(t, l, scheme),
                const SizedBox(height: 18),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.phonelink_erase_rounded, color: Colors.orange),
                    title: Text(trx('Focus broken this week: ${t.distractions} times', 'এই সপ্তাহে মনোযোগ ভেঙেছে: ${t.distractions} বার')),
                    subtitle: Text(trx('Last week: ${l.distractions}', 'আগের সপ্তাহে: ${l.distractions}')),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _summaryCard(_WeekData t, _WeekData l, ColorScheme scheme) {
    final diff = t.total - l.total;
    final up = diff >= 0;
    final pct = l.total == 0 ? null : (diff * 100 / l.total).round();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trx('Studied this week', 'এই সপ্তাহে পড়েছেন'), style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 4),
          Text(_hm(t.total), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: Colors.white),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pct == null
                      ? trx('Last week: ${_hm(l.total)}', 'আগের সপ্তাহে: ${_hm(l.total)}')
                      : (up
                          ? trx('${_hm(diff)} more than last week (+$pct%)', 'আগের সপ্তাহের চেয়ে ${_hm(diff)} বেশি (+$pct%)')
                          : trx('${_hm(-diff)} less than last week ($pct%)', 'আগের সপ্তাহের চেয়ে ${_hm(-diff)} কম ($pct%)')),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            trx('Daily average: ${_hm(t.total ~/ 7)}', 'দৈনিক গড়: ${_hm(t.total ~/ 7)}'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _dayBars(_WeekData t, _WeekData l, List<String> names, ColorScheme scheme) {
    final maxV = [...t.days, ...l.days, 1].reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < 7; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(t.days[i] == 0 ? '' : '${(t.days[i] / 60).toStringAsFixed(1)}', style: const TextStyle(fontSize: 10)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 8,
                        height: 110 * l.days[i] / maxV + 2,
                        decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(width: 3),
                      Container(
                        width: 14,
                        height: 110 * t.days[i] / maxV + 2,
                        decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(4)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(names[i], style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _subjectRows(_WeekData t, _WeekData l, ColorScheme scheme) {
    final keys = {...t.subjects.keys, ...l.subjects.keys}.toList()
      ..sort((a, b) => (t.subjects[b] ?? 0).compareTo(t.subjects[a] ?? 0));
    if (keys.isEmpty) {
      return [
        Text(trx('No study time recorded yet. Use task timers or Pomodoro and it will show here.',
            'এখনো পড়ার সময় রেকর্ড হয়নি। টাস্কের টাইমার বা Pomodoro চালালে এখানে দেখাবে।'),
            style: TextStyle(color: scheme.onSurfaceVariant)),
      ];
    }
    final maxV = keys.map((k) => t.subjects[k] ?? 0).fold(1, (a, b) => a > b ? a : b);
    return [
      for (final k in keys.take(10))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(k, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(_hm(t.subjects[k] ?? 0)),
                const SizedBox(width: 6),
                _delta((t.subjects[k] ?? 0) - (l.subjects[k] ?? 0)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (t.subjects[k] ?? 0) / maxV,
                  minHeight: 7,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _delta(int d) {
    if (d == 0) return const SizedBox(width: 0);
    final up = d > 0;
    return Text(
      '${up ? '▲' : '▼'}${_hm(d.abs())}',
      style: TextStyle(fontSize: 11, color: up ? Colors.green : Colors.red, fontWeight: FontWeight.w600),
    );
  }
}
