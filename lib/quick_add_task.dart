import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'daily_routine.dart';
import 'language_manager.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// এক লাইনের লেখা থেকে টাস্ক বোঝার ফলাফল
class QuickTaskParse {
  final String subject;
  final DateTime start;
  final DateTime end;
  final bool timeFound;
  /// ০ = আজ, ১ = আগামীকাল, ২ = পরশু
  final int dayOffset;
  const QuickTaskParse({
    required this.subject,
    required this.start,
    required this.end,
    required this.timeFound,
    this.dayOffset = 0,
  });

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
  static const String _time = r'(\d{1,2})(?:[:.](\d{2}))?\s*(টা(?:য়|ে)?|টার|am|pm|a\.m\.|p\.m\.)?';

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

  // বাংলা অক্ষরের সীমা (শব্দের মাঝখানে মিল এড়াতে)
  static const String _bnLetter = '[ঀ-৿]';

  /// কথায় বলা লেখা ("কাল সকাল আটটায় গণিত দুই ঘণ্টা") সংখ্যায় রূপান্তর, আর দিন (আজ/কাল/পরশু) আলাদা করা
  static (String, int) _preprocess(String input) {
    // য়, ড়, ঢ় দুইভাবে লেখা যায়; এক রকম করে নেওয়া
    var s = input
        .replaceAll('য়', 'য়')
        .replaceAll('ড়', 'ড়')
        .replaceAll('ঢ়', 'ঢ়');
    s = _normalizeDigits(s);

    // দিন
    var day = 0;
    final dayWords = <RegExp, int>{
      RegExp('(?<!$_bnLetter)(পরশুদিন|পরশু)(?!$_bnLetter)'): 2, // পরশুদিন|পরশু
      RegExp('(?<!$_bnLetter)(আগামীকাল|আগামী কাল|কালকে|কাল)(?!$_bnLetter)'): 1, // আগামীকাল|আগামী কাল|কালকে|কাল
      RegExp(r'\bday after tomorrow\b', caseSensitive: false): 2,
      RegExp(r'\btomorrow\b', caseSensitive: false): 1,
      RegExp('(?<!$_bnLetter)(আজকে|আজ)(?!$_bnLetter)'): 0, // আজকে|আজ
      RegExp(r'\b(today|tonight)\b', caseSensitive: false): 0,
    };
    for (final e in dayWords.entries) {
      final m = e.key.firstMatch(s);
      if (m != null) {
        day = e.value;
        final w = m.group(0)!.toLowerCase();
        s = s.replaceRange(m.start, m.end, w == 'tonight' ? ' night ' : ' ');
        break;
      }
    }

    const hourWord = '(?:ঘণ্টা|ঘন্টা)'; // ঘণ্টা|ঘন্টা
    const minuteWord = 'মিনিট'; // মিনিট
    const ta = 'টা'; // টা

    // ভগ্নাংশ শব্দ
    s = s
        .replaceAll(RegExp('(আধা|আধ)\\s*$hourWord'), '30 $minuteWord') // আধা/আধ ঘণ্টা
        .replaceAll(RegExp(r'half an? hour', caseSensitive: false), '30 min')
        .replaceAll(RegExp(r'\ban hour\b', caseSensitive: false), '1 hour')
        .replaceAll(RegExp('দেড়\\s*$hourWord'), '1.5 ঘণ্টা') // দেড় ঘণ্টা
        .replaceAll(RegExp('আড়াই\\s*$hourWord'), '2.5 ঘণ্টা') // আড়াই ঘণ্টা
        .replaceAll('দেড়$ta', '1:30$ta') // দেড়টা
        .replaceAll('আড়াই$ta', '2:30$ta'); // আড়াইটা

    // সংখ্যা-শব্দ → অঙ্ক (শুধু টা/ঘণ্টা/মিনিটের আগে, যাতে বিষয়ের নামের শব্দ না বদলায়)
    const words = {
      'একটা': 1, // একটা
      'এক': 1, // এক
      'দুই': 2, // দুই
      'দুটো': 2, // দুটো
      'দু': 2, // দু
      'তিন': 3, // তিন
      'চার': 4, // চার
      'পাঁচ': 5, // পাঁচ
      'ছয়': 6, // ছয়
      'ছ': 6, // ছ
      'সাত': 7, // সাত
      'আট': 8, // আট
      'নয়': 9, // নয়
      'দশ': 10, // দশ
      'এগারো': 11, // এগারো
      'বারো': 12, // বারো
    };
    final sorted = words.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    final wordRe = RegExp('(?<!$_bnLetter)(${sorted.join('|')})(?=$ta|\\s*(?:$hourWord|$minuteWord))');
    s = s.replaceAllMapped(wordRe, (m) => '${words[m.group(1)]}');
    const en = {
      'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
      'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11, 'twelve': 12,
    };
    s = s.replaceAllMapped(
      RegExp(r'\b(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b(?=\s*(am|pm|a\.m\.|p\.m\.|o.clock|hours?|hrs?|minutes?|mins?)\b)',
          caseSensitive: false),
      (m) => '${en[m.group(1)!.toLowerCase()]}',
    );
    s = s.replaceAll(RegExp(r"\s*o.clock\b", caseSensitive: false), '');

    // সাড়ে ৮টা = ৮:৩০, সাড়ে ২ ঘণ্টা = ২.৫ ঘণ্টা
    const sare = 'সাড়ে';
    s = s
        .replaceAllMapped(RegExp('$sare\\s*(\\d{1,2})(?=$ta)'), (m) => '${m.group(1)}:30')
        .replaceAllMapped(RegExp('$sare\\s*(\\d{1,2})(?=\\s*$hourWord)'), (m) => '${m.group(1)}.5');
    return (s, day);
  }

  static QuickTaskParse parse(String input, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final (text, dayOffset) = _preprocess(input.trim());
    String rest = text;
    DateTime? start;
    DateTime? end;
    bool? clockFound;
    final base = DateTime(n.year, n.month, n.day).add(Duration(days: dayOffset));
    final isToday = dayOffset == 0;

    DateTime at(int h, int m) => DateTime(base.year, base.month, base.day, h, m);

    final r = _rangeRe.firstMatch(text);
    if (r != null) {
      int h1 = int.parse(r.group(2)!), m1 = int.tryParse(r.group(3) ?? '') ?? 0;
      int h2 = int.parse(r.group(6)!), m2 = int.tryParse(r.group(7) ?? '') ?? 0;
      if (h1 <= 23 && h2 <= 23 && m1 < 60 && m2 < 60) {
        final p1 = _markerOf(r.group(4)) ?? _periodOf(r.group(1));
        final p2 = _markerOf(r.group(8)) ?? _periodOf(r.group(5)) ?? p1;
        int s24 = _to24(h1, p1 ?? (p2 == 'pm' && h1 <= h2 ? 'pm' : null));
        int e24 = _to24(h2, p2);
        if (isToday && p1 == null && p2 == null && h1 <= 12) {
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
          if (isToday && p == null && h <= 12 && at(h24, m).isBefore(n.subtract(const Duration(minutes: 30))) && h24 + 12 < 24) {
            h24 += 12;
          }
          start = at(h24, m);
          rest = rest.replaceRange(s.start, s.end, ' ');
        }
      }
      clockFound = start != null;
      if (start != null || dur != null) {
        start ??= isToday ? _nextSlot(n) : at(9, 0);
        end = start.add(dur ?? const Duration(hours: 1));
      }
    }

    final timeFound = clockFound ?? start != null;
    start ??= isToday ? _nextSlot(n) : at(9, 0);
    end ??= start.add(const Duration(hours: 1));

    // বাকি লেখা থেকে অপ্রয়োজনীয় শব্দ বাদ দিয়ে বিষয়ের নাম
    var subject = rest
        .replaceAll(RegExp(r'\b(from|at|for|to)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'(থেকে|পর্যন্ত|সময়|সময়ে|পড়ব|পড়বো|পড়া)'), ' ')
        .replaceAll(RegExp('(?<!$_bnLetter)(সময়ে|সময়|পড়বো|পড়ব|পড়তে|পড়া|করবো|করব)(?!$_bnLetter)'), ' ')
        .replaceAll(RegExp('(?<=\\d|\\s|^)(টায়|টার|টা)(?!$_bnLetter)'), ' ')
        .replaceAll(RegExp(r'[,;|]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    subject = subject.replaceAll(RegExp(r'^[-–—:]+|[-–—:]+$'), '').trim();
    if (subject.isEmpty) subject = input.trim();

    return QuickTaskParse(subject: subject, start: start, end: end, timeFound: timeFound, dayOffset: dayOffset);
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
  /// খোলার সাথে সাথে কণ্ঠে শোনা শুরু
  final bool startWithVoice;
  const QuickAddTaskSheet({
    super.key,
    required this.onTaskAdded,
    required this.onOpenFullForm,
    this.startWithVoice = false,
  });

  @override
  State<QuickAddTaskSheet> createState() => _QuickAddTaskSheetState();
}

class _QuickAddTaskSheetState extends State<QuickAddTaskSheet> {
  final _controller = TextEditingController();
  QuickTaskParse? _parsed;
  bool _reminder = true;

  // কণ্ঠে বলা (ফোনের নিজস্ব ফ্রি কণ্ঠ-চেনা, কোনো খরচ নেই)
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;
  late bool _voiceBangla = LanguageManager().isBengali;

  @override
  void initState() {
    super.initState();
    if (widget.startWithVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toggleListen());
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleListen() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final ok = await _speech.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) setState(() => _listening = false);
      },
      onError: (e) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(trx('Voice input is not available. Allow the microphone and make sure Google voice typing is installed.',
              'কণ্ঠে লেখা চালু করা গেল না। মাইক্রোফোনের অনুমতি দিন আর Google ভয়েস টাইপিং আছে কিনা দেখুন।')),
        ));
      }
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) {
        _controller.text = r.recognizedWords;
        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
        _onChanged(r.recognizedWords);
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: _voiceBangla ? 'bn_BD' : 'en_US',
        partialResults: true,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      ),
    );
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
              hintText: _listening
                  ? trx('Listening… say e.g. "tomorrow 8am maths 2 hours"', 'শুনছি… বলুন যেমন "কাল সকাল আটটায় গণিত দুই ঘণ্টা"')
                  : trx('e.g. English grammar 8–10pm', 'যেমন: বাংলা ব্যাকরণ ৮টা–১০টা'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              prefixIcon: IconButton(
                tooltip: trx('Speak', 'কণ্ঠে বলুন'),
                icon: Icon(_listening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                    color: _listening ? Colors.red : scheme.primary),
                onPressed: _toggleListen,
              ),
              suffixIcon: IconButton(
                tooltip: trx('Add', 'যোগ করুন'),
                icon: Icon(Icons.send_rounded, color: scheme.primary),
                onPressed: p == null ? null : _submit,
              ),
            ),
          ),
          Row(
            children: [
              Text(trx('Voice language:', 'কণ্ঠের ভাষা:'), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('বাংলা'),
                selected: _voiceBangla,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _voiceBangla = true),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('English'),
                selected: !_voiceBangla,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _voiceBangla = false),
              ),
            ],
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
                    Expanded(
                      child: Text(
                        '${p.dayOffset == 0 ? '' : (p.dayOffset == 1 ? trx('Tomorrow, ', 'আগামীকাল, ') : trx('Day after tomorrow, ', 'পরশু, '))}'
                        '${_fmt(p.start)} – ${_fmt(p.end)}  ($durText)',
                      ),
                    ),
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
