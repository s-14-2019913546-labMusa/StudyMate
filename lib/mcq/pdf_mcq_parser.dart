import 'bijoy_converter.dart';
import 'mcq_service.dart';

/// PDF থেকে পাওয়া একটা প্রশ্নের খসড়া (সেভের আগে ব্যবহারকারী দেখে ঠিক করবে)
class McqDraft {
  int? number; // PDF-এ প্রশ্নের নম্বর (উত্তরপত্র মেলাতে)
  String question;
  List<String> options;
  int answer; // -1 = উত্তর পাওয়া যায়নি
  String explanation;
  bool include;

  McqDraft({
    this.number,
    this.question = '',
    List<String>? options,
    this.answer = -1,
    this.explanation = '',
    this.include = true,
  }) : options = options ?? [];

  bool get complete => question.trim().isNotEmpty && options.length == 4;
  bool get ready => complete && answer >= 0 && answer < 4;

  McqQuestion toQuestion(String subject) => McqQuestion(
        id: McqQuestion.stableId('custom', question.trim()),
        subject: subject,
        question: question.trim(),
        options: options.map((e) => e.trim()).toList(),
        answer: answer,
        explanation: explanation.trim(),
        source: 'pdf',
      );
}

class PdfParseResult {
  final List<McqDraft> drafts;
  final int keyAnswers; // উত্তরপত্রে কতগুলো উত্তর পাওয়া গেল
  final int filledFromKey; // উত্তরপত্র থেকে কতগুলো প্রশ্নে উত্তর বসল
  PdfParseResult(this.drafts, this.keyAnswers, this.filledFromKey);
}

class PdfMcqParser {
  static const _digitsBn = '০১২৩৪৫৬৭৮৯';

  static int? toInt(String s) {
    final b = StringBuffer();
    for (final c in s.split('')) {
      final i = _digitsBn.indexOf(c);
      b.write(i >= 0 ? i : c);
    }
    return int.tryParse(b.toString());
  }

  /// ক/খ/গ/ঘ, a-d, A-D, ১-৪, 1-4 → 0-3
  static int letterIndex(String k) {
    const maps = ['কখগঘ', 'abcd', 'ABCD', '1234', '১২৩৪'];
    for (final m in maps) {
      final i = m.indexOf(k);
      if (i >= 0) return i;
    }
    return -1;
  }

  /// বিজয় হলে ইউনিকোডে বদলানো, উল্টো ক্রমের কার ঠিক করা, ফাঁকা জায়গা গোছানো
  static String normalize(String raw, {bool? bijoy}) {
    var t = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceAll(' ', ' ');
    if (bijoy ?? BijoyConverter.looksLikeBijoy(t)) {
      t = t.split('\n').map(BijoyConverter.convert).join('\n');
    } else if (BijoyConverter.hasVisualOrder(t)) {
      t = BijoyConverter.reorder(t);
    }
    t = t.replaceAll(RegExp(r'[ \t]+'), ' ');
    return t;
  }

  // ---------- উত্তরপত্র ("১.ক ২.খ ৩.গ" / "1-a, 2-b" / "1(c) 2(d)") ----------
  static final _keyPair = RegExp(r'([0-9০-৯]{1,4})\s*[\.\-:)।=]?\s*\(?([কখগঘa-dA-D])\)?(?=[\s,;|।]|$)');
  static final _keyHeading = RegExp(r'^\s*(উত্তরমালা|উত্তরপত্র|উত্তর সমূহ|উত্তরসমূহ|answer\s*key|answers?)\s*[:ঃ\-]?\s*', caseSensitive: false);

  /// লেখা থেকে উত্তরপত্র বের করে, আর সেই লাইনগুলো বাদ দেওয়া লেখা ফেরত দেয়
  static (Map<int, int>, String) extractAnswerKey(String text) {
    final key = <int, int>{};
    final keep = <String>[];
    for (final line in text.split('\n')) {
      final body = line.replaceFirst(_keyHeading, '');
      final pairs = _keyPair.allMatches(body).toList();
      final covered = pairs.fold<int>(0, (s, m) => s + m.group(0)!.length);
      final letters = body.replaceAll(RegExp(r'[\s,;|।]'), '').length;
      if (pairs.length >= 3 && letters > 0 && covered >= letters * 0.8) {
        for (final m in pairs) {
          final n = toInt(m.group(1)!);
          final a = letterIndex(m.group(2)!);
          if (n != null && a >= 0) key[n] = a;
        }
      } else {
        keep.add(line);
      }
    }
    return (key, keep.join('\n'));
  }

  // ---------- প্রশ্ন ভাগ করা ----------
  static final _qStart = RegExp(r'^\s*(?:প্রশ্ন\s*[:ঃ]?\s*)?(?:Q\.?\s*)?\(?([0-9০-৯]{1,4})\s*[\.\)।:]\s*(.*)$', caseSensitive: false);
  static final _opt = RegExp(r'^\s*\(?([কখগঘ]|[a-dA-D])\s*[\)\.।:]\s*(.*)$');
  static final _optParen = RegExp(r'^\s*\(([কখগঘa-dA-D])\)\s*(.*)$');
  static final _ans = RegExp(r'^\s*(?:সঠিক\s*উত্তর|উত্তর|উঃ|উ:|ans(?:wer)?|correct)\s*[:ঃ\-=]?\s*(.*)$', caseSensitive: false);
  static final _exp = RegExp(r'^\s*(?:ব্যাখ্যা|explanation|exp|সমাধান)\s*[:ঃ\-]\s*(.*)$', caseSensitive: false);
  static final _correctMark = RegExp(r'[*✓✔√]');

  /// এক লাইনে থাকা একাধিক অপশন ("ক) .. খ) .. গ) .. ঘ) ..") আলাদা লাইনে ভাঙা।
  /// লাইনের মাঝে "উত্তর:" থাকলে সেটাও আলাদা হয়।
  static String splitInline(String text) {
    final families = [
      ['ক', 'খ', 'গ', 'ঘ'],
      ['a', 'b', 'c', 'd'],
      ['A', 'B', 'C', 'D'],
    ];
    final out = <String>[];
    for (var line in text.split('\n')) {
      line = line.replaceAllMapped(
          RegExp(r'\s+((?:সঠিক\s*)?উত্তর\s*[:ঃ]|Ans(?:wer)?\s*[:\-])', caseSensitive: false), (m) => '\n${m.group(1)}');
      for (final f in families) {
        String marker(String l) => '(?:\\($l\\)|$l\\s*[\\)\\.।:])';
        // একই লাইনে অন্তত দুটো অপশন-চিহ্ন থাকলেই ভাঙা হবে ("গ. ৭ ঘ. ৯" ও চলবে)
        final present = f.where((l) => RegExp('(^|\\s)${marker(l)}\\s*\\S').hasMatch(line)).length;
        if (present < 2) continue;
        for (final l in f.skip(1)) {
          line = line.replaceAllMapped(RegExp('\\s+(${marker(l)})'), (m) => '\n${m.group(1)}');
        }
        // প্রশ্নের শেষে প্রথম অপশন থাকলে ("...কোনটি? ক) গোলাপ")
        line = line.replaceAllMapped(RegExp('(\\S)\\s+(${marker(f[0])})'), (m) => '${m.group(1)}\n${m.group(2)}');
        break;
      }
      out.add(line);
    }
    return out.join('\n');
  }

  static List<McqDraft> parse(String text) {
    final lines = splitInline(text).split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final drafts = <McqDraft>[];
    McqDraft? cur;
    var inExp = false;

    void finish() {
      if (cur != null && cur!.question.trim().isNotEmpty && cur!.options.isNotEmpty) drafts.add(cur!);
      cur = null;
      inExp = false;
    }

    for (final l in lines) {
      final ans = _ans.firstMatch(l);
      final exp = _exp.firstMatch(l);
      final q = _qStart.firstMatch(l);
      final o = _optParen.firstMatch(l) ?? _opt.firstMatch(l);
      final c = cur;

      if (c != null && ans != null && c.options.isNotEmpty) {
        c.answer = _answerFrom(ans.group(1)!, c.options);
        inExp = false;
        continue;
      }
      if (c != null && exp != null && c.options.isNotEmpty) {
        c.explanation = exp.group(1)!.trim();
        inExp = true;
        continue;
      }
      if (q != null) {
        final n = toInt(q.group(1)!)!;
        // ১-৪ নম্বর দিয়ে লেখা অপশন (প্রশ্ন নয়)
        final numericOption = c != null &&
            c.question.isNotEmpty &&
            n == c.options.length + 1 &&
            n <= 4 &&
            (c.options.isNotEmpty || c.number != null);
        if (!numericOption) {
          finish();
          cur = McqDraft(number: n, question: q.group(2)!.trim());
          continue;
        }
        _addOption(c, q.group(2)!);
        continue;
      }
      if (c != null && o != null && c.question.isNotEmpty && c.options.length < 4 && !inExp) {
        _addOption(c, o.group(2)!);
        continue;
      }
      if (c == null || (c.complete && !inExp)) {
        // নম্বর ছাড়া নতুন প্রশ্ন
        finish();
        cur = McqDraft(question: l);
        continue;
      }
      if (inExp) {
        c.explanation = '${c.explanation} $l'.trim();
      } else if (c.options.isEmpty) {
        c.question = '${c.question} $l'.trim();
      } else if (c.options.length < 4) {
        c.options[c.options.length - 1] = '${c.options.last} $l';
      }
    }
    finish();
    // প্রশ্নের শুরুতে লেগে থাকা "প্রশ্ন:" ইত্যাদি ঝেড়ে ফেলা
    for (final d in drafts) {
      d.question = d.question.replaceFirst(RegExp(r'^(?:প্রশ্ন|Q)\s*[:ঃ.]\s*', caseSensitive: false), '').trim();
      d.include = d.complete;
    }
    return drafts;
  }

  static void _addOption(McqDraft d, String raw) {
    var t = raw.trim();
    if (_correctMark.hasMatch(t) && d.answer < 0) {
      d.answer = d.options.length;
      t = t.replaceAll(_correctMark, '').trim();
    }
    d.options.add(t);
  }

  /// "খ", "(খ)", "B", "2", বা অপশনের লেখা থেকে উত্তরের index
  static int _answerFrom(String raw, List<String> options) {
    final s = raw.trim().replaceAll(RegExp(r'^[\(\[]'), '');
    if (s.isEmpty) return -1;
    final m = RegExp(r'^([কখগঘa-dA-D১-৪1-4])(?:[\)\.।:\s]|$)').firstMatch(s);
    if (m != null) return letterIndex(m.group(1)!);
    final low = s.toLowerCase();
    for (var i = 0; i < options.length; i++) {
      final o = options[i].trim().toLowerCase();
      if (o.isNotEmpty && (low == o || low.startsWith(o) || o.startsWith(low))) return i;
    }
    return -1;
  }

  /// পুরো কাজ: স্বাভাবিক করা → উত্তরপত্র আলাদা → প্রশ্ন ভাগ → উত্তরপত্র মেলানো
  static PdfParseResult parseDocument(String raw, {bool? bijoy}) {
    final norm = normalize(raw, bijoy: bijoy);
    final (key, body) = extractAnswerKey(norm);
    final drafts = parse(body);
    final filled = applyKey(drafts, key);
    return PdfParseResult(drafts, key.length, filled);
  }

  /// উত্তরপত্র থেকে যেসব প্রশ্নের উত্তর নেই সেগুলোতে উত্তর বসানো। কতগুলো বসল তা ফেরত দেয়।
  static int applyKey(List<McqDraft> drafts, Map<int, int> key) {
    if (key.isEmpty) return 0;
    final numbered = drafts.any((d) => d.number != null);
    var filled = 0;
    for (var i = 0; i < drafts.length; i++) {
      final d = drafts[i];
      if (d.answer >= 0) continue;
      final a = key[numbered ? (d.number ?? -1) : i + 1];
      if (a != null) {
        d.answer = a;
        filled++;
      }
    }
    return filled;
  }
}
