import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'flashcard_study_screen.dart';
import 'language_manager.dart';
import 'mcq/mcq_home_screen.dart';
import 'mcq/mcq_test_screen.dart';
import 'mcq/mistake_book_service.dart';
import 'widgets/skeleton.dart';

/// আজ কী রিভিশন দিতে হবে: সব ডেকের "আজ দেখার" ফ্ল্যাশকার্ড + ভুলের খাতার প্রশ্ন।
/// ফ্ল্যাশকার্ডে সহজ/কঠিন অনুযায়ী পরের রিভিশনের দিন অ্যাপ নিজে ঠিক করে (spaced repetition)।
class ReviewCounts {
  final List<Map<String, dynamic>> dueCards;
  final List<MistakeEntry> dueMistakes;
  const ReviewCounts(this.dueCards, this.dueMistakes);
  int get total => dueCards.length + dueMistakes.length;
}

class DailyReviewService {
  static Future<ReviewCounts> load() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return const ReviewCounts([], []);
    final now = DateTime.now();
    final decks = await FirebaseFirestore.instance
        .collection('users')
        .doc(u.uid)
        .collection('flashcard_decks')
        .get();
    final cards = <Map<String, dynamic>>[];
    for (final d in decks.docs) {
      for (final c in (d.data()['cards'] as List<dynamic>? ?? [])) {
        if (c is! Map) continue;
        final next = (c['nextReviewDate'] as Timestamp?)?.toDate();
        // কখনো পড়া হয়নি এমন কার্ড এখানে নয় (সেগুলো ডেক থেকে নতুন করে পড়বেন); শুধু রিভিশনের দিন এসেছে এমন
        if (next != null && !next.isAfter(now)) {
          cards.add({...Map<String, dynamic>.from(c), '_deckId': d.id, '_deckTitle': d.data()['title'] ?? ''});
        }
      }
    }
    List<MistakeEntry> mistakes = [];
    try {
      mistakes = (await MistakeBookService.loadAll()).where((e) => e.isDue).toList();
    } catch (_) {}
    return ReviewCounts(cards, mistakes);
  }
}

class DailyReviewScreen extends StatefulWidget {
  const DailyReviewScreen({super.key});

  @override
  State<DailyReviewScreen> createState() => _DailyReviewScreenState();
}

class _DailyReviewScreenState extends State<DailyReviewScreen> {
  ReviewCounts? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await DailyReviewService.load();
    if (mounted) setState(() => _data = d);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(trx("Today's Revision", 'আজকের রিভিশন'))),
      body: d == null
          ? const SkeletonCardList(count: 2)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.psychology_rounded, color: Colors.white, size: 40),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.total == 0
                                  ? trx('All caught up! 🎉', 'আজকের সব রিভিশন শেষ! 🎉')
                                  : trx('${d.total} items to revise today', 'আজ ${d.total}টি জিনিস রিভিশন দিতে হবে'),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              trx('Revising right before you forget makes it stick.', 'ভুলে যাওয়ার ঠিক আগে রিভিশন দিলে মনে থাকে বেশি দিন।'),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _tile(
                  icon: Icons.style_rounded,
                  color: Colors.purple,
                  title: trx('Flashcards', 'ফ্ল্যাশকার্ড'),
                  subtitle: d.dueCards.isEmpty
                      ? trx('No cards due today', 'আজ কোনো কার্ড নেই')
                      : trx('${d.dueCards.length} cards from ${d.dueCards.map((c) => c['_deckId']).toSet().length} decks',
                          '${d.dueCards.map((c) => c['_deckId']).toSet().length}টি ডেক থেকে ${d.dueCards.length}টি কার্ড'),
                  enabled: d.dueCards.isNotEmpty,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FlashcardStudyScreen(
                        deckId: d.dueCards.first['_deckId'] as String,
                        deckTitle: trx("Today's Revision", 'আজকের রিভিশন'),
                        cards: List<dynamic>.from(d.dueCards)..shuffle(),
                      ),
                    ),
                  ).then((_) => _load()),
                ),
                _tile(
                  icon: Icons.menu_book_rounded,
                  color: Colors.red,
                  title: trx('Mistake Book', 'ভুলের খাতা'),
                  subtitle: d.dueMistakes.isEmpty
                      ? trx('No mistakes due today', 'আজ কোনো ভুল রিভিশন নেই')
                      : trx('${d.dueMistakes.length} questions', '${d.dueMistakes.length}টি প্রশ্ন'),
                  enabled: d.dueMistakes.isNotEmpty,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => McqTestScreen(
                        questions: d.dueMistakes.map((e) => e.question).toList()..shuffle(),
                        mode: 'review',
                      ),
                    ),
                  ).then((_) => _load()),
                ),
                const SizedBox(height: 8),
                Text(
                  trx('Flashcards: swipe right = easy (comes back later), left = hard (tomorrow). Mistakes come back after 1, 4 and 7 days.',
                      'ফ্ল্যাশকার্ডে ডানে টানুন = সহজ (অনেক দিন পরে আসবে), বাঁয়ে = কঠিন (কালই আসবে)। ভুল প্রশ্ন আসে ১, ৪ ও ৭ দিন পরে।'),
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const McqHomeScreen())),
                  icon: const Icon(Icons.quiz_rounded),
                  label: Text(trx('Practise new MCQs', 'নতুন MCQ প্র্যাকটিস')),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                ),
              ],
            ),
    );
  }

  Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        minVerticalPadding: 16,
        enabled: enabled,
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: enabled ? const Icon(Icons.play_circle_fill_rounded, size: 32) : const Icon(Icons.check_circle_rounded, color: Colors.green),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
