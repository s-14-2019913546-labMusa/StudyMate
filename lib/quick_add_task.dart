import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'daily_routine.dart';
import 'language_manager.dart';

/// এক লাইনের লেখা থেকে টাস্ক বোঝার ফলাফল
class QuickTaskParse {
  final String subject;
  final DateTime start;
  final DateTime end;
  final bool timeFound;
  const QuickTaskParse({required this.subject, required this.start, required this.end, required this.timeFound});

  int get minutes => end.difference(start).inMinutes;
}

/// "বাংলা ব্যাকরণ ৮টা–১০টা", "English 7:30pm-9pm", "গণিত বিকাল ৪টা ২ ঘণ্টা", "Physics 45 min"
/// এমন লেখা থেকে বিষয় আর সময় বের করে।
class QuickTaskParser {
  static const _bnDigits = '০১২৩৪৫৬৭৮৯';

  static String _normalizeDigits(String s) {
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = _bnDigits.indexOf(ch);
      b.write(i >= 0 ? '$i' : ch);
    }
    return b.toString();
  }

  // সময়ের অংশ: ঐচ্ছিক দিনের ভাগ + ঘণ্টা[:মিনিট] + ঐচ্ছিক টা/am/pm
  static const String _period = r'(সকাল|ভোর|দুপুর|বিকাল|বিকেল|সন্ধ্যা|সন্ধ্যা|রাত|morning|noon|afternoon|evening|night)?\s*';
  static const String _time = r'(\d{1,2})(?:[:.](\d{2}))?\s*(টা[য়ে]?|টার|am|pm|a\.m\.|p\.m\.)?';

  static final RegExp _rangeRe = RegExp(
    '$_period$_time\\s*(?:-|–|—|~|থেকে|হতে|to|till|until)\\s*$_period$_time(?:\\s*(?:পর্যন্ত|টা পর্যন্ত))?',
    caseSensitive: false,
  );
  static final RegExp _singleRe = RegExp('$_period$_time', caseSensitive: false);
  static final RegExp _durationRe = RegExp(
    r'(\d+(?:\.\d+)?)\s*(ঘণ্টা|ঘন্টা|hours?|hrs?|h|মিনিট|minutes?|mins?|m)(?![a-zA-Z])',
    caseSensitive: false,
  );

  static String? _periodOf(String? p) {
    if (p == null || p.isEmpty) return null;
    final s = p.toLowerCase();
    if (s == 'সকাল' || s == 'ভোর' || s == 'morning') return 'am';
    if (s == 'দুপুর' || s == 'noon') return 'noon';
    return 'pm'; // বিকাল, সন্ধ্যা, রাত, afternoon, evening, night
  }

  static String? _markerOf(String? m) {
    if (m == null) return null;
    final s = m.toLowerCase().replaceAll('.', '');
    if (s == 'am') return 'am';
    if (s == 'pm') return 'pm';
    return null;
  }

  static int _to24(int h, String? ampm) {
    if (ampm == 'am') return h == 12 ? 0 : h;
    if (ampm == 'pm') return h < 12 ? h + 12 : h;
    if (ampm == 'noon') return (h >= 1 && h <= 4) ? h + 12 : h; // দুপুর ১টা = ১৩টা
    return h;
  }

  static QuickTaskParse parse(String input, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final text = _normalizeDigits(input.trim());
    String rest = text;
    DateTime? start;
    DateTime? end;
    bool? clockFound;

    DateTime at(int h, int m) => DateTime(n.year, n.month, n.day, h, m);

    final r = _rangeRe.firstMatch(text);
    if (r != null) {
      int h1 = int.parse(r.group(2)!), m1 = int.tryParse(r.group(3) ?? '') ?? 0;
      int h2 = int.parse(r.group(6)!), m2 = int.tryParse(r.group(7) ?? '') ?? 0;
      if (h1 <= 23 && h2 <= 23 && m1 < 60 && m2 < 60) {
        final p1 = _markerOf(r.group(4)) ?? _periodOf(r.group(1));
        final p2 = _markerOf(r.group(8)) ?? _periodOf(r.group(5)) ?? p1;
        int s24 = _to24(h1, p1 ?? (p2 == 'pm' && h1 <= h2 ? 'pm' : null));
        int e24 = _to24(h2, p2);
        if (p1 == null && p2 == null && h1 <= 12) {
          // কোনো সকাল/বিকাল দেওয়া নেই: সময়টা পার হয়ে গেলে বিকালের সময় ধরা
          if (at(s24, m1).isBefore(n.subtract(const Duration(minutes: 30))) && s24 + 12 < 24) {
            s24 += 12;
            if (e24 < 12) e24 += 12;
          }
        }
        if (e24 * 60 + m2 <= s24 * 60 + m1 && e24 < 12) e24 += 12; // ১১টা–১টা = ১১–১৩
        start = at(s24, m1);
        end = at(e24 % 24, m2);
        if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
        rest = text.replaceRange(r.start, r.end, ' ');
      }
    }

    if (start == null) {
      // একটা সময় + ঐচ্ছিক সময়কাল
      Duration? dur;
      final d = _durationRe.firstMatch(text);
      if (d != null) {
        final v = double.parse(d.group(1)!);
        final unit = d.group(2)!.toLowerCase();
        final isHour = unit.startsWith('ঘ') || unit.startsWith('h');
        dur = Duration(minutes: (isHour ? v * 60 : v).round());
        rest = rest.replaceFirst(d.group(0)!, ' ');
      }
      // সময়কালের সংখ্যাকে আবার সময় ভাবা থেকে বাঁচাতে rest-এ খোঁজা হয়
      RegExpMatch? s;
      for (final m in _singleRe.allMatches(rest)) {
        final hasHint = (m.group(1) ?? '').isNotEmpty || (m.group(4) ?? '').isNotEmpty || (m.group(3) ?? '').isNotEmpty;
        if (hasHint) {
          s = m;
          break;
        }
      }
      if (s != null) {
        final h = int.parse(s.group(2)!), m = int.tryParse(s.group(3) ?? '') ?? 0;
        if (h <= 23 && m < 60) {
          final p = _markerOf(s.group(4)) ?? _periodOf(s.group(1));
          int h24 = _to24(h, p);
          if (p == null && h <= 12 && at(h24, m).isBefore(n.subtract(const Duration(minutes: 30))) && h24 + 12 < 24) {
            h24 += 12;
          }
          start = at(h24, m);
          rest = rest.replaceRange(s.start, s.end, ' ');
        }
      }
      clockFound = start != null;
      if (start != null || dur != null) {
        start ??= _nextSlot(n);
        end = start.add(dur ?? const Duration(hours: 1));
      }
    }

    final timeFound = clockFound ?? start != null;
    start ??= _nextSlot(n);
    end ??= start.add(const Duration(hours: 1));

    // বাকি লেখা থেকে অপ্রয়োজনীয় শব্দ বাদ দিয়ে বিষয়ের নাম
    var subject = rest
        .replaceAll(RegExp(r'\b(from|at|for|to)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'(থেকে|পর্যন্ত|সময়|সময়ে|পড়ব|পড়বো|পড়া)'), ' ')
        .replaceAll(RegExp(r'[,;|]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    subject = subject.replaceAll(RegExp(r'^[-–—:]+|[-–—:]+$'), '').trim();
    if (subject.isEmpty) subject = input.trim();

    return QuickTaskParse(subject: subject, start: start, end: end, timeFound: timeFound);
  }

  static DateTime _nextSlot(DateTime n) {
    final m = ((n.minute / 5).ceil() * 5) + 5;
    return DateTime(n.year, n.month, n.day, n.hour).add(Duration(minutes: m));
  }
}

/// "+" লম্বা করে চাপলে আসা এক লাইনের টাস্ক ফর্ম
class QuickAddTaskSheet extends StatefulWidget {
  final void Function(Task task) onTaskAdded;
  final VoidCallback onOpenFullForm;
  const QuickAddTaskSheet({super.key, required this.onTaskAdded, required this.onOpenFullForm});

  @override
  State<QuickAddTaskSheet> createState() => _QuickAddTaskSheetState();
}

class _QuickAddTaskSheetState extends State<QuickAddTaskSheet> {
  final _controller = TextEditingController();
  QuickTaskParse? _parsed;
  bool _reminder = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _parsed = v.trim().isEmpty ? null : QuickTaskParser.parse(v));
  }

  void _submit() {
    final p = _parsed;
    if (p == null) return;
    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: p.subject,
      subject: p.subject,
      topic: '',
      notes: '',
      challenges: '',
      startTime: p.start,
      endTime: p.end,
      category: 'Study',
      totalDurationMinutes: p.minutes,
      alarmEnabled: _reminder,
    );
    Navigator.pop(context);
    widget.onTaskAdded(task);
  }

  String _fmt(DateTime t) {
    final s = DateFormat('h:mm a').format(t);
    if (!LanguageManager().isBengali) return s;
    const bn = '০১২৩৪৫৬৭৮৯';
    return s
        .split('')
        .map((c) => (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) ? bn[c.codeUnitAt(0) - 48] : c)
        .join()
        .replaceAll('AM', 'এএম')
        .replaceAll('PM', 'পিএম');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = _parsed;
    final h = p == null ? 0 : p.minutes ~/ 60;
    final m = p == null ? 0 : p.minutes % 60;
    final durText = p == null
        ? ''
        : trx('${h > 0 ? '${h}h ' : ''}${m > 0 ? '${m}m' : ''}'.trim(),
            '${h > 0 ? '$h ঘণ্টা ' : ''}${m > 0 ? '$m মিনিট' : ''}'.trim());

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: scheme.primary),
              const SizedBox(width: 8),
              Text(trx('Quick add', 'দ্রুত টাস্ক যোগ'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            onSubmitted: (_) => _submit(),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: trx('e.g. English grammar 8–10pm', 'যেমন: বাংলা ব্যাকরণ ৮টা–১০টা'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              suffixIcon: IconButton(
                tooltip: trx('Add', 'যোগ করুন'),
                icon: Icon(Icons.send_rounded, color: scheme.primary),
                onPressed: p == null ? null : _submit,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (p != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.menu_book_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p.subject, style: const TextStyle(fontWeight: FontWeight.bold))),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.schedule_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${_fmt(p.start)} – ${_fmt(p.end)}  ($durText)')),
                  ]),
                  if (!p.timeFound) ...[
                    const SizedBox(height: 6),
                    Text(
                      trx('No time found, so it starts soon for 1 hour. Write e.g. "8–10pm".',
                          'সময় পাওয়া যায়নি, তাই একটু পরে ১ ঘণ্টার জন্য ধরা হলো। যেমন লিখুন "৮টা–১০টা"।'),
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            )
          else
            Text(
              trx('Write the subject and time in one line. The app understands the rest.',
                  'বিষয় আর সময় এক লাইনে লিখুন, বাকিটা অ্যাপ নিজে বুঝে নেবে।'),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _reminder,
            onChanged: (v) => setState(() => _reminder = v),
            title: Text(trx('Remind me at start time', 'শুরুর সময় রিমাইন্ডার দিন')),
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onOpenFullForm();
                },
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(trx('Full form', 'পুরো ফর্ম')),
              ),
              const Spacer(),
              FilledButton(
                onPressed: p == null ? null : _submit,
                style: FilledButton.styleFrom(minimumSize: const Size(110, 48)),
                child: Text(trx('Add', 'যোগ করুন')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
