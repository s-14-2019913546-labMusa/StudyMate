import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'mcq_service.dart';

/// ভুলের খাতা: MCQ-তে যত প্রশ্ন ভুল হয় সব এখানে জমা থাকে।
/// ১-৪-৭ নিয়মে আবার সামনে আসে: ভুলের ১ দিন পর, ৪ দিন পর, ৭ দিন পর।
/// তিনবার ঠিক হলে "শিখে ফেলেছি" হয়ে যায়।
class MistakeEntry {
  final McqQuestion question;
  final int wrongCount;
  final int stage; // ০ = নতুন ভুল, ৩ = শেখা শেষ
  final DateTime? nextReview;
  final bool mastered;
  final int? lastChosen;

  MistakeEntry({
    required this.question,
    required this.wrongCount,
    required this.stage,
    required this.nextReview,
    required this.mastered,
    this.lastChosen,
  });

  bool get isDue => !mastered && (nextReview == null || !nextReview!.isAfter(DateTime.now()));
}

class MistakeBookService {
  // stage → পরের রিভিশন কত দিন পরে (ভুলের দিন থেকে ১, ৪, ৭ দিনে পড়ে)
  static const List<int> _gapDays = [1, 3, 3];

  static CollectionReference<Map<String, dynamic>>? get _col {
    final u = FirebaseAuth.instance.currentUser;
    return u == null
        ? null
        : FirebaseFirestore.instance.collection('users').doc(u.uid).collection('mistakes');
  }

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  static Future<void> recordWrong(McqQuestion q, int? chosen) async {
    final col = _col;
    if (col == null) return;
    final ref = col.doc(q.id);
    final snap = await ref.get();
    final prev = (snap.data()?['wrongCount'] as num?)?.toInt() ?? 0;
    await ref.set({
      ...q.toMap(),
      'wrongCount': prev + 1,
      'stage': 0,
      'mastered': false,
      'lastChosen': chosen,
      'lastWrongAt': FieldValue.serverTimestamp(),
      'nextReview': Timestamp.fromDate(_dayStart(DateTime.now()).add(const Duration(days: 1))),
      if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// রিভিশনে উত্তর দিলে: ঠিক হলে পরের ধাপে, ভুল হলে আবার শুরু থেকে
  static Future<void> recordReview(McqQuestion q, bool correct, int? chosen) async {
    final col = _col;
    if (col == null) return;
    final ref = col.doc(q.id);
    final snap = await ref.get();
    if (!snap.exists) {
      if (!correct) await recordWrong(q, chosen);
      return;
    }
    if (!correct) {
      await recordWrong(q, chosen);
      return;
    }
    final stage = ((snap.data()?['stage'] as num?)?.toInt() ?? 0) + 1;
    if (stage >= 3) {
      await ref.update({'stage': 3, 'mastered': true, 'masteredAt': FieldValue.serverTimestamp()});
    } else {
      await ref.update({
        'stage': stage,
        'nextReview': Timestamp.fromDate(_dayStart(DateTime.now()).add(Duration(days: _gapDays[stage]))),
      });
    }
  }

  static Future<List<MistakeEntry>> loadAll() async {
    final col = _col;
    if (col == null) return [];
    final snap = await col.get();
    final list = snap.docs.map((d) {
      final m = d.data();
      return MistakeEntry(
        question: McqQuestion.fromMap(m, id: d.id),
        wrongCount: (m['wrongCount'] as num?)?.toInt() ?? 1,
        stage: (m['stage'] as num?)?.toInt() ?? 0,
        nextReview: (m['nextReview'] as Timestamp?)?.toDate(),
        mastered: m['mastered'] == true,
        lastChosen: (m['lastChosen'] as num?)?.toInt(),
      );
    }).where((e) => e.question.options.length == 4).toList();
    list.sort((a, b) => (a.nextReview ?? DateTime(2000)).compareTo(b.nextReview ?? DateTime(2000)));
    return list;
  }

  static Future<int> dueCount() async {
    try {
      final col = _col;
      if (col == null) return 0;
      final snap = await col
          .where('mastered', isEqualTo: false)
          .where('nextReview', isLessThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      // index না থাকলে সব এনে গোনা
      final all = await loadAll();
      return all.where((e) => e.isDue).length;
    }
  }

  static Future<void> delete(String id) async => _col?.doc(id).delete();

  /// ভুল প্রশ্নগুলো "ভুল প্রশ্ন (MCQ)" ফ্ল্যাশকার্ড ডেকে যোগ করে
  static Future<int> addToFlashcards(List<McqQuestion> wrong) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || wrong.isEmpty) return 0;
    final decks = FirebaseFirestore.instance.collection('users').doc(u.uid).collection('flashcard_decks');
    const title = 'ভুল প্রশ্ন (MCQ)';
    final existing = await decks.where('title', isEqualTo: title).limit(1).get();
    DocumentReference<Map<String, dynamic>> ref;
    List<dynamic> cards = [];
    if (existing.docs.isEmpty) {
      ref = decks.doc();
      await ref.set({
        'title': title,
        'description': 'MCQ প্র্যাকটিসে যেসব প্রশ্ন ভুল হয়েছে, সেগুলো এখানে নিজে থেকে জমা হয়।',
        'cards': [],
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      ref = existing.docs.first.reference;
      cards = List<dynamic>.from(existing.docs.first.data()['cards'] ?? []);
    }
    final ids = cards.map((c) => (c as Map)['id']).toSet();
    var added = 0;
    for (final q in wrong) {
      if (ids.contains(q.id)) continue;
      cards.add({
        'id': q.id,
        'front': q.question,
        'back': q.explanation.isEmpty ? q.correctText : '${q.correctText}\n\n${q.explanation}',
        'difficulty': 'hard',
      });
      added++;
    }
    if (added > 0) await ref.update({'cards': cards});
    return added;
  }
}
