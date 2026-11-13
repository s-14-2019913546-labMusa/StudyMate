import 'daily_routine.dart';
import 'quick_add_task.dart';

/// বটকে লেখা কথা থেকে রুটিনের কোন কাজ চাওয়া হয়েছে
enum RoutineIntentType {
  whatNow, // এখন কী পড়ব
  planTomorrow, // কালকের প্ল্যান
  moveUnfinished, // বাকিগুলো কালকে
  delete, // গণিত বাদ
  postpone, // গণিত ১৫ মিনিট পিছাও
  moveToDay, // ফিজিক্স কালকে দাও
  moveToTime, // ইংরেজিটা ৯টায় সরাও
  add, // কাল সকাল ৭টায় গণিত ২ ঘণ্টা
}

class RoutineIntent {
  final RoutineIntentType type;

  /// কোন টাস্কের কথা বলা হচ্ছে (বিষয়ের নাম), খালি হতে পারে
  final String query;

  /// postpone: কত মিনিট; moveToDay: কত দিন পরে (১ = কাল)
  final int amount;

  /// পুরো লেখা (moveToTime / add-এ সময় বের করতে লাগে)
  final String raw;

  const RoutineIntent(this.type, {this.query = '', this.amount = 0, this.raw = ''});

  @override
  String toString() => 'RoutineIntent($type, "$query", $amount)';
}

/// অফলাইনে, টাকা ছাড়া: কয়েকটা নিয়ম দিয়ে বাংলা / ইংরেজি / Banglish বোঝা
class RoutineIntentParser {
  static const _bnDigits = '০১২৩৪৫৬৭৮৯';

  static String normalize(String s) {
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = _bnDigits.indexOf(ch);
      b.write(i >= 0 ? '$i' : ch);
    }
    return b.toString().toLowerCase().replaceAll(RegExp(r'[?।!.,]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static final _whatNow = RegExp(
    r'(এখন|ekhon|akhon)\s*(কী|কি|ki|কোনটা|kon)|what.{0,24}now|now what|next task|what.{0,6}next|পরের টাস্ক|এখনকার টাস্ক|এখন কোন টাস্ক|কী পড়া উচিত|কি পড়া উচিত',
  );
  static final _planTomorrow = RegExp(
    r'(কালকের|আগামীকালের|kalker|tomorrow.?s?)\s*(প্ল্যান|পরিকল্পনা|রুটিন|plan|routine|rutin)|plan\s*(for\s*)?tomorrow|(কাল|আগামীকাল|kal)\s*(কী|কি|ki)\s*(পড়|পড়|por)',
  );
  static final _unfinished = RegExp(r'(বাকি|বাকিগুলো|অসম্পূর্ণ|unfinished|remaining|incomplete|baki)');
  static final _tomorrowWord = RegExp(r'(?<![ঀ-৿a-z])(কালকে|আগামীকাল|কাল|tomorrow|kalke|kal)(?![ঀ-৿a-z])');
  static final _dayAfterWord = RegExp(r'(পরশু|day after tomorrow|porshu)');
  static final _deleteWord = RegExp(r'(?<![ঀ-৿])(বাদ\s*(দাও|দিন)?|মুছে\s*(ফেলো|দাও|দিন)?|মুছো|মুছুন|ডিলিট|delete|remove|cancel|বাতিল)');
  static final _moveWord = RegExp(
    r'(সরাও|সরিয়ে|সরিয়ে|সরান|পিছাও|পিছিয়ে|পিছিয়ে|পেছাও|পেছাও|নিয়ে\s*যাও|নিয়ে\s*যাও|move|shift|postpone|delay|push|sorao|pichao)',
  );
  static final _giveTomorrow = RegExp(r'(কালকে|আগামীকাল|tomorrow|kalke)\s*(দাও|দিয়ে\s*দাও|দিয়ে\s*দাও|দিন|দেও|dao)');
  static final _minutes = RegExp(r'(\d+(?:\.\d+)?)\s*(মিনিট|মিঃ|min|mins|minute|minutes|ঘণ্টা|ঘন্টা|hour|hours|hr|ghonta)');
  static final _clock = RegExp(r'\d{1,2}(?:[:.]\d{2})?\s*(টায়|টায়|টাতে|টার|টা|am|pm|a\.m|p\.m)|\d{1,2}[:.]\d{2}');
  static final _addWord = RegExp(r'^(যোগ\s*কর(ো|ুন)?|add|নতুন টাস্ক|new task)\s*:?');

  // বিষয়ের নাম বের করার সময় যে শব্দগুলো ফেলে দিতে হয়
  static final _filler = RegExp(
    r'(আজকের|আজকে|আজ|today|todays|টাস্কটা|টাস্কটি|টাস্ক|task|এর|টা|টি|টাকে|কে|গুলো|গুলি|দাও|দিন|দিয়ে|দিয়ে|ফেলো|করো|করুন|please|প্লিজ|the|my|আমার|মিনিট|ঘণ্টা|ঘন্টা|min|mins|minutes|hour|hours|to|পর্যন্ত|থেকে|এ|ে)(?![ঀ-৿a-z])',
  );

  static RoutineIntent? parse(String input) {
    final text = normalize(input);
    if (text.isEmpty) return null;

    if (_whatNow.hasMatch(text)) return const RoutineIntent(RoutineIntentType.whatNow);
    if (_planTomorrow.hasMatch(text)) return const RoutineIntent(RoutineIntentType.planTomorrow);
    if (_unfinished.hasMatch(text) && (_tomorrowWord.hasMatch(text) || _moveWord.hasMatch(text))) {
      return const RoutineIntent(RoutineIntentType.moveUnfinished);
    }

    final hasMove = _moveWord.hasMatch(text) || _giveTomorrow.hasMatch(text);
    final hasClock = _clock.hasMatch(text);

    if (_deleteWord.hasMatch(text) && !hasMove) {
      final q = _subject(text.replaceAll(_deleteWord, ' '));
      if (q.isNotEmpty) return RoutineIntent(RoutineIntentType.delete, query: q, raw: input);
    }

    if (hasMove) {
      final dayAfter = _dayAfterWord.hasMatch(text);
      final tomorrow = _tomorrowWord.hasMatch(text);
      if (!hasClock && (tomorrow || dayAfter)) {
        final q = _subject(text.replaceAll(_moveWord, ' ').replaceAll(_giveTomorrow, ' ').replaceAll(_dayAfterWord, ' ').replaceAll(_tomorrowWord, ' '));
        return RoutineIntent(RoutineIntentType.moveToDay, query: q, amount: dayAfter ? 2 : 1, raw: input);
      }
      if (hasClock) {
        final q = _subject(text.replaceAll(_moveWord, ' ').replaceAll(_clock, ' ').replaceAll(RegExp(r'(সকাল|ভোর|দুপুর|বিকাল|বিকেল|সন্ধ্যা|সন্ধ্যা|রাত|morning|evening|night|at)'), ' '));
        return RoutineIntent(RoutineIntentType.moveToTime, query: q, raw: input);
      }
      final m = _minutes.firstMatch(text);
      int mins = 15;
      if (m != null) {
        final v = double.parse(m.group(1)!);
        final u = m.group(2)!;
        mins = (u.startsWith('ঘ') || u.startsWith('h') || u.startsWith('g') ? v * 60 : v).round();
      }
      final q = _subject(text.replaceAll(_moveWord, ' ').replaceAll(_minutes, ' ').replaceAll(RegExp(r'(পরে|later)'), ' '));
      return RoutineIntent(RoutineIntentType.postpone, query: q, amount: mins.clamp(5, 600), raw: input);
    }

    final explicitAdd = _addWord.hasMatch(text);
    if (explicitAdd || hasClock || _minutes.hasMatch(text)) {
      final cleaned = input.replaceFirst(RegExp(r'^\s*(যোগ\s*কর(ো|ুন)?|add|নতুন টাস্ক|new task)\s*:?', caseSensitive: false), '').trim();
      final p = QuickTaskParser.parse(cleaned);
      final subject = p.subject.trim();
      // শুধু সংখ্যা/সময় দিয়ে প্রশ্ন (যেমন "৫০*৪") হলে টাস্ক নয়
      if (subject.isNotEmpty && RegExp(r'[A-Za-zঀ-৿]').hasMatch(subject) && (explicitAdd || p.timeFound || _minutes.hasMatch(text))) {
        return RoutineIntent(RoutineIntentType.add, query: subject, raw: cleaned);
      }
    }
    return null;
  }

  static String _subject(String s) {
    return s.replaceAll(_filler, ' ').replaceAll(RegExp(r'\d+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // ---------- টাস্ক খোঁজা ----------

  static const Map<String, List<String>> _synonyms = {
    'ইংরেজি': ['english', 'eng', 'ইংলিশ'],
    'বাংলা': ['bangla', 'bengali'],
    'গণিত': ['math', 'maths', 'mathematics', 'অংক', 'অঙ্ক'],
    'বিজ্ঞান': ['science'],
    'পদার্থ': ['physics', 'ফিজিক্স'],
    'রসায়ন': ['chemistry', 'কেমিস্ট্রি', 'রসায়ন'],
    'জীববিজ্ঞান': ['biology', 'বায়োলজি'],
    'আইসিটি': ['ict', 'কম্পিউটার', 'computer'],
    'সাধারণ জ্ঞান': ['gk', 'general knowledge'],
    'ইতিহাস': ['history'],
    'ভূগোল': ['geography'],
  };

  static List<String> _variants(String q) {
    final base = normalize(q);
    final out = <String>{base};
    // ইংরেজিটা / ইংরেজির / ইংরেজিকে → ইংরেজি
    out.add(base.replaceAll(RegExp(r'(টাকে|টা|টি|কে|এর|র)$'), ''));
    for (final e in _synonyms.entries) {
      final all = [e.key, ...e.value];
      if (all.any((w) => out.any((v) => v.contains(w)))) out.addAll(all);
    }
    out.removeWhere((v) => v.length < 2);
    return out.toList();
  }

  /// [tasks]-এর মধ্যে যেগুলোর নাম/বিষয়ে [query] আছে (শেষ না হওয়াগুলো আগে)
  static List<Task> findTasks(List<Task> tasks, String query) {
    final open = tasks.where((t) => !(t.isCompleted || t.status == 'completed')).toList();
    if (query.trim().isEmpty) return open;
    final vs = _variants(query);
    bool hit(Task t) {
      final hay = normalize('${t.title} ${t.subject ?? ''} ${t.topic ?? ''}'.replaceAll('[WR]', ''));
      return vs.any((v) => hay.contains(v));
    }
    final a = open.where(hit).toList();
    if (a.isNotEmpty) return a;
    return tasks.where(hit).toList();
  }

  /// এখন চলছে বা এখনকার সময়ের টাস্ক, আর পরের টাস্ক
  static (Task?, Task?) currentAndNext(List<Task> tasks, DateTime now) {
    final timed = tasks.where((t) => t.startTime != null).toList()..sort((a, b) => a.startTime!.compareTo(b.startTime!));
    bool done(Task t) => t.isCompleted || t.status == 'completed';
    Task? current = timed.where((t) => t.status == 'running' && !done(t)).firstOrNull;
    current ??= timed.where((t) {
      final end = t.endTime ?? t.startTime!.add(Duration(minutes: t.totalDurationMinutes > 0 ? t.totalDurationMinutes : 60));
      return !done(t) && !t.startTime!.isAfter(now) && end.isAfter(now);
    }).firstOrNull;
    final next = timed.where((t) => !done(t) && t.startTime!.isAfter(now) && t.id != current?.id).firstOrNull;
    return (current, next);
  }

  /// সময় পেরিয়ে গেছে কিন্তু শেষ হয়নি
  static List<Task> missed(List<Task> tasks, DateTime now) {
    return tasks.where((t) {
      if (t.isCompleted || t.status == 'completed' || t.status == 'running' || t.startTime == null) return false;
      final end = t.endTime ?? t.startTime!.add(Duration(minutes: t.totalDurationMinutes > 0 ? t.totalDurationMinutes : 60));
      return end.isBefore(now);
    }).toList();
  }

  /// একই দিনে সময় মিলে যাওয়া টাস্ক
  static List<Task> overlaps(List<Task> tasks, DateTime start, DateTime end, {String? exceptId}) {
    return tasks.where((t) {
      if (t.id == exceptId || t.startTime == null || t.isCompleted || t.status == 'completed') return false;
      final te = t.endTime ?? t.startTime!.add(const Duration(hours: 1));
      return t.startTime!.isBefore(end) && te.isAfter(start);
    }).toList();
  }
}
