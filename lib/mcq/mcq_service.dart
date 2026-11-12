import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

/// একটি MCQ প্রশ্ন
class McqQuestion {
  final String id;
  final String subject;
  final String question;
  final List<String> options;
  final int answer; // সঠিক অপশনের index (0-3)
  final String explanation;
  final String source; // 'bank' | 'custom' | 'ai'

  const McqQuestion({
    required this.id,
    required this.subject,
    required this.question,
    required this.options,
    required this.answer,
    this.explanation = '',
    this.source = 'bank',
  });

  String get correctText => options[answer];

  Map<String, dynamic> toMap() => {
        'id': id,
        'subject': subject,
        'question': question,
        'options': options,
        'answer': answer,
        'explanation': explanation,
        'source': source,
      };

  factory McqQuestion.fromMap(Map<String, dynamic> m, {String? id}) => McqQuestion(
        id: id ?? (m['id'] ?? '').toString(),
        subject: (m['subject'] ?? 'অন্যান্য').toString(),
        question: (m['question'] ?? '').toString(),
        options: List<String>.from((m['options'] as List? ?? []).map((e) => e.toString())),
        answer: (m['answer'] as num?)?.toInt() ?? 0,
        explanation: (m['explanation'] ?? '').toString(),
        source: (m['source'] ?? 'custom').toString(),
      );

  /// প্রশ্নের লেখা থেকে স্থায়ী id (একই প্রশ্ন দুবার জমা হয় না)
  static String stableId(String prefix, String text) {
    var h = 0x811c9dc5;
    for (final c in text.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return '${prefix}_${h.toRadixString(16)}';
  }
}

/// এক পরীক্ষার ফলাফল
class McqResult {
  final int total;
  final int correct;
  final int wrong;
  final int skipped;
  final double negativePerWrong;
  final int seconds;
  final String mode; // 'practice' | 'test' | 'review'
  final String exam;
  final Map<String, List<int>> perSubject; // subject → [correct, total]

  McqResult({
    required this.total,
    required this.correct,
    required this.wrong,
    required this.skipped,
    required this.negativePerWrong,
    required this.seconds,
    required this.mode,
    required this.exam,
    required this.perSubject,
  });

  double get marks => correct - wrong * negativePerWrong;
  double get percent => total == 0 ? 0 : correct * 100 / total;

  Map<String, dynamic> toMap() => {
        'total': total,
        'correct': correct,
        'wrong': wrong,
        'skipped': skipped,
        'negativePerWrong': negativePerWrong,
        'marks': marks,
        'seconds': seconds,
        'mode': mode,
        'exam': exam,
        'perSubject': perSubject.map((k, v) => MapEntry(k, {'correct': v[0], 'total': v[1]})),
        'createdAt': FieldValue.serverTimestamp(),
      };
}

class McqService {
  static const examNames = {
    'all': ('All', 'সব'),
    'bcs': ('BCS', 'বিসিএস'),
    'bank': ('Bank', 'ব্যাংক'),
    'primary': ('Primary', 'প্রাইমারি'),
  };

  static List<McqQuestion>? _bank;
  static Map<String, List<String>> _subjectExams = {};

  static DocumentReference<Map<String, dynamic>>? get _userRef {
    final u = FirebaseAuth.instance.currentUser;
    return u == null ? null : FirebaseFirestore.instance.collection('users').doc(u.uid);
  }

  /// অ্যাপের সাথে দেওয়া প্রশ্নব্যাংক (assets/data/mcq_bank.json)
  static Future<List<McqQuestion>> loadBank() async {
    if (_bank != null) return _bank!;
    final raw = await rootBundle.loadString('assets/data/mcq_bank.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _subjectExams = (data['subjects'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, List<String>.from(v as List)));
    _bank = (data['questions'] as List).map((e) {
      final m = e as Map<String, dynamic>;
      final q = m['q'] as String;
      return McqQuestion(
        id: McqQuestion.stableId('bank', q),
        subject: m['s'] as String,
        question: q,
        options: List<String>.from(m['o'] as List),
        answer: (m['a'] as num).toInt(),
        explanation: (m['e'] ?? '') as String,
        source: 'bank',
      );
    }).toList();
    return _bank!;
  }

  /// ব্যবহারকারীর নিজের যোগ করা প্রশ্ন (পেস্ট বা AI থেকে)
  static Future<List<McqQuestion>> loadCustom() async {
    final ref = _userRef;
    if (ref == null) return [];
    final snap = await ref.collection('mcq_questions').get();
    return snap.docs.map((d) => McqQuestion.fromMap(d.data(), id: d.id)).toList();
  }

  static Future<List<McqQuestion>> loadAll() async {
    final bank = await loadBank();
    List<McqQuestion> custom = [];
    try {
      custom = await loadCustom();
    } catch (_) {}
    return [...bank, ...custom];
  }

  static bool subjectInExam(String subject, String exam) {
    if (exam == 'all') return true;
    final exams = _subjectExams[subject];
    return exams == null || exams.contains(exam); // নিজের বিষয় সব পরীক্ষায় দেখাবে
  }

  static Future<int> saveCustom(List<McqQuestion> list) async {
    final ref = _userRef;
    if (ref == null || list.isEmpty) return 0;
    final batch = FirebaseFirestore.instance.batch();
    for (final q in list) {
      batch.set(ref.collection('mcq_questions').doc(q.id), q.toMap());
    }
    await batch.commit();
    return list.length;
  }

  static Future<void> deleteCustom(String id) async {
    await _userRef?.collection('mcq_questions').doc(id).delete();
  }

  static Future<void> saveResult(McqResult r) async {
    await _userRef?.collection('mcq_results').add(r.toMap());
  }

  /// শেষ ৩০টা পরীক্ষা থেকে বিষয়ভিত্তিক সঠিকতার হার (দুর্বল বিষয় বের করতে)
  static Future<Map<String, double>> subjectAccuracy() async {
    final ref = _userRef;
    if (ref == null) return {};
    final snap = await ref.collection('mcq_results').orderBy('createdAt', descending: true).limit(30).get();
    final c = <String, int>{}, t = <String, int>{};
    for (final d in snap.docs) {
      final ps = (d.data()['perSubject'] as Map<String, dynamic>?) ?? {};
      ps.forEach((subject, v) {
        final m = v as Map<String, dynamic>;
        c[subject] = (c[subject] ?? 0) + ((m['correct'] as num?)?.toInt() ?? 0);
        t[subject] = (t[subject] ?? 0) + ((m['total'] as num?)?.toInt() ?? 0);
      });
    }
    return {for (final s in t.keys) if (t[s]! > 0) s: c[s]! * 100 / t[s]!};
  }

  /// পেস্ট করা লেখা থেকে প্রশ্ন বের করা। প্রতিটা প্রশ্ন ফাঁকা লাইন দিয়ে আলাদা:
  ///   প্রশ্ন?
  ///   ক) ...   খ) ...   গ) ...   ঘ) ...   (অথবা A) B) C) D) / a. b. c. d. / 1. 2. 3. 4.)
  ///   উত্তর: খ   (অথবা Ans: B / Answer: 2, অথবা সঠিক অপশনের আগে *)
  static List<McqQuestion> parsePasted(String text, String subject) {
    final out = <McqQuestion>[];
    final norm = text.replaceAll('\r\n', '\n');
    final blocks = norm.split(RegExp(r'\n\s*\n'));
    final optRe = RegExp(r'^\s*\(?([কখগঘ]|[A-Da-d]|[1-4১-৪])[\).:\-]\s*(.+)$');
    final ansRe = RegExp(r'^\s*(?:উত্তর|উঃ|উ:|ans(?:wer)?|সঠিক উত্তর)\s*[:ঃ\-]?\s*\(?([কখগঘ]|[A-Da-d]|[1-4১-৪])\)?', caseSensitive: false);
    final expRe = RegExp(r'^\s*(?:ব্যাখ্যা|explanation|exp)\s*[:ঃ\-]\s*(.+)$', caseSensitive: false);

    int idx(String k) {
      const maps = ['কখগঘ', 'ABCD', 'abcd', '1234', '১২৩৪'];
      for (final m in maps) {
        final i = m.indexOf(k);
        if (i >= 0) return i;
      }
      return -1;
    }

    for (final block in blocks) {
      final lines = block.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.length < 5) continue;
      final qLines = <String>[];
      final opts = <String>[];
      int answer = -1;
      String exp = '';
      for (final l in lines) {
        final a = ansRe.firstMatch(l);
        final e = expRe.firstMatch(l);
        final o = optRe.firstMatch(l);
        if (a != null) {
          answer = idx(a.group(1)!);
        } else if (e != null) {
          exp = e.group(1)!.trim();
        } else if (o != null && opts.length < 4 && (qLines.isNotEmpty)) {
          var t = o.group(2)!.trim();
          if (t.startsWith('*') || t.endsWith('*')) {
            answer = opts.length;
            t = t.replaceAll('*', '').trim();
          }
          opts.add(t);
        } else if (opts.isEmpty) {
          qLines.add(l.replaceFirst(RegExp(r'^\s*(?:\d+|[০-৯]+)[\).:]\s*'), ''));
        }
      }
      final q = qLines.join(' ').trim();
      if (q.isEmpty || opts.length != 4 || answer < 0 || answer > 3) continue;
      out.add(McqQuestion(
        id: McqQuestion.stableId('custom', q),
        subject: subject,
        question: q,
        options: opts,
        answer: answer,
        explanation: exp,
        source: 'custom',
      ));
    }
    return out;
  }
}
