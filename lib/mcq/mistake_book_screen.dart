import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../language_manager.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';
import 'mcq_test_screen.dart';
import 'mistake_book_service.dart';

/// ভুলের খাতা: আজকের রিভিশন, সব ভুল, আর শেখা হয়ে যাওয়া প্রশ্ন
class MistakeBookScreen extends StatefulWidget {
  const MistakeBookScreen({super.key});

  @override
  State<MistakeBookScreen> createState() => _MistakeBookScreenState();
}

class _MistakeBookScreenState extends State<MistakeBookScreen> {
  List<MistakeEntry>? _all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await MistakeBookService.loadAll();
    if (mounted) setState(() => _all = list);
  }

  void _review(List<MistakeEntry> list) {
    if (list.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => McqTestScreen(questions: list.map((e) => e.question).toList()..shuffle(), mode: 'review'),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final due = all?.where((e) => e.isDue).toList() ?? [];
    final active = all?.where((e) => !e.mastered).toList() ?? [];
    final mastered = all?.where((e) => e.mastered).toList() ?? [];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(trx('Mistake Book', 'ভুলের খাতা')),
          bottom: TabBar(tabs: [
            Tab(text: trx('Today (${due.length})', 'আজ (${due.length})')),
            Tab(text: trx('All (${active.length})', 'সব (${active.length})')),
            Tab(text: trx('Learned (${mastered.length})', 'শেখা হয়েছে (${mastered.length})')),
          ]),
        ),
        body: all == null
            ? const SkeletonCardList()
            : all.isEmpty
                ? EmptyStateGuide(
                    icon: Icons.menu_book_rounded,
                    color: Colors.red,
                    title: trx('No mistakes yet', 'এখনো কোনো ভুল জমা হয়নি'),
                    message: trx(
                      'Every MCQ you answer wrong lands here. It comes back after 1, 4 and 7 days until you get it right three times.',
                      'MCQ-তে যে প্রশ্ন ভুল হবে, তা এখানে জমা হবে। ১, ৪ ও ৭ দিন পরে আবার আসবে, তিনবার ঠিক হলে শেখা হয়ে গেছে ধরা হবে।',
                    ),
                    actionLabel: trx('Practise MCQ', 'MCQ প্র্যাকটিস করুন'),
                    onAction: () => Navigator.pop(context),
                  )
                : TabBarView(children: [
                    _list(due, showStart: true),
                    _list(active, showStart: true),
                    _list(mastered),
                  ]),
      ),
    );
  }

  Widget _list(List<MistakeEntry> list, {bool showStart = false}) {
    final scheme = Theme.of(context).colorScheme;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(trx('Nothing here right now 🎉', 'এখন এখানে কিছু নেই 🎉'),
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (showStart)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.icon(
              onPressed: () => _review(list),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(trx('Revise these ${list.length}', 'এই ${list.length}টি রিভিশন দিন')),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ),
        for (final e in list)
          Dismissible(
            key: ValueKey(e.question.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red.withValues(alpha: 0.15),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            ),
            onDismissed: (_) {
              MistakeBookService.delete(e.question.id);
              setState(() => _all!.remove(e));
            },
            child: Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                title: Text(e.question.question, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  e.mastered
                      ? trx('Learned ✓', 'শেখা হয়েছে ✓')
                      : '${e.question.subject} · ${trx('wrong ${e.wrongCount}×', '${e.wrongCount} বার ভুল')} · ${_dueText(e)}',
                  style: const TextStyle(fontSize: 12),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (e.lastChosen != null && e.lastChosen! >= 0 && e.lastChosen! < 4 && e.lastChosen != e.question.answer)
                    Text(trx('You chose: ${e.question.options[e.lastChosen!]}', 'আপনি দিয়েছিলেন: ${e.question.options[e.lastChosen!]}'),
                        style: const TextStyle(color: Colors.red)),
                  Text(trx('Correct: ${e.question.correctText}', 'সঠিক: ${e.question.correctText}'),
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                  if (e.question.explanation.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text(e.question.explanation)),
                  const SizedBox(height: 6),
                  Text(trx('Stage ${e.stage}/3 · swipe left to delete', 'ধাপ ${e.stage}/৩ · মুছতে বাঁয়ে টানুন'),
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _dueText(MistakeEntry e) {
    if (e.isDue) return trx('due today', 'আজ রিভিশন');
    final d = e.nextReview!;
    return trx('next: ${DateFormat('d MMM').format(d)}', 'পরের রিভিশন: ${DateFormat('d MMM').format(d)}');
  }
}
