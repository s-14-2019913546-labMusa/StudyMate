import 'package:flutter/material.dart';
import '../language_manager.dart';
import 'mcq_service.dart';
import 'mcq_test_screen.dart';

class McqResultScreen extends StatelessWidget {
  final McqResult result;
  final List<McqQuestion> questions;
  final List<int?> answers;
  final int addedToFlashcards;

  const McqResultScreen({
    super.key,
    required this.result,
    required this.questions,
    required this.answers,
    this.addedToFlashcards = 0,
  });

  String _fmtMarks(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = result.percent;
    final color = pct >= 70 ? Colors.green : (pct >= 40 ? Colors.orange : Colors.red);
    final wrongQs = <McqQuestion>[];
    for (int i = 0; i < questions.length; i++) {
      final a = answers[i];
      if (a != null && a != questions[i].answer) wrongQs.add(questions[i]);
    }
    final subjects = result.perSubject.entries.toList()
      ..sort((a, b) => (a.value[0] / a.value[1]).compareTo(b.value[0] / b.value[1]));
    final weak = subjects.where((e) => e.value[1] >= 2 && e.value[0] / e.value[1] < 0.6).map((e) => e.key).toList();
    final mins = result.seconds ~/ 60, secs = result.seconds % 60;

    return Scaffold(
      appBar: AppBar(title: Text(trx('Result', 'ফলাফল'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text('${pct.round()}%', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: color)),
                Text(
                  pct >= 70
                      ? trx('Excellent! Keep it up.', 'দারুণ! এভাবেই চালিয়ে যান।')
                      : (pct >= 40 ? trx('Good, but there is room to improve.', 'ভালো, তবে আরও উন্নতির সুযোগ আছে।')
                          : trx('Keep practising — the Mistake Book will help.', 'চর্চা চালিয়ে যান, ভুলের খাতা কাজে দেবে।')),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat(trx('Correct', 'সঠিক'), '${result.correct}', Colors.green),
                    _stat(trx('Wrong', 'ভুল'), '${result.wrong}', Colors.red),
                    _stat(trx('Skipped', 'বাদ'), '${result.skipped}', Colors.grey),
                    _stat(trx('Marks', 'নম্বর'), _fmtMarks(result.marks), scheme.primary),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  trx('Time: ${mins}m ${secs}s${result.negativePerWrong > 0 ? ' · −${result.negativePerWrong} per wrong' : ''}',
                      'সময়: $mins মিনিট $secs সেকেন্ড${result.negativePerWrong > 0 ? ' · প্রতি ভুলে −${result.negativePerWrong}' : ''}'),
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (weak.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_down_rounded, color: Colors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(trx('Weak subjects: ${weak.join(', ')}', 'দুর্বল বিষয়: ${weak.join(', ')}'),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
          if (addedToFlashcards > 0 || wrongQs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              trx('Wrong answers were saved to your Mistake Book${addedToFlashcards > 0 ? ' and $addedToFlashcards new cards were added to the "ভুল প্রশ্ন (MCQ)" flashcard deck' : ''}.',
                  'ভুল প্রশ্নগুলো ভুলের খাতায় জমা হয়েছে${addedToFlashcards > 0 ? ', আর "ভুল প্রশ্ন (MCQ)" ফ্ল্যাশকার্ড ডেকে $addedToFlashcardsটি নতুন কার্ড যোগ হয়েছে' : ''}।'),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 18),
          Text(trx('By subject', 'বিষয়ভিত্তিক'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final e in subjects)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text('${e.value[0]}/${e.value[1]}'),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: e.value[1] == 0 ? 0 : e.value[0] / e.value[1],
                      minHeight: 8,
                      color: (e.value[0] / e.value[1]) >= 0.6 ? Colors.green : Colors.orange,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
          if (wrongQs.isNotEmpty) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => McqTestScreen(questions: wrongQs, mode: 'review')),
              ),
              icon: const Icon(Icons.replay_rounded),
              label: Text(trx('Retry the wrong ones (${wrongQs.length})', 'ভুলগুলো আবার করুন (${wrongQs.length})')),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ],
          const SizedBox(height: 18),
          Text(trx('Answers', 'উত্তরগুলো'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (int i = 0; i < questions.length; i++) _answerTile(context, i),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color c) => Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );

  Widget _answerTile(BuildContext context, int i) {
    final q = questions[i];
    final a = answers[i];
    final ok = a == q.answer;
    final icon = a == null ? Icons.remove_circle_outline : (ok ? Icons.check_circle_rounded : Icons.cancel_rounded);
    final color = a == null ? Colors.grey : (ok ? Colors.green : Colors.red);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Text('${i + 1}. ${q.question}', maxLines: 2, overflow: TextOverflow.ellipsis),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (a != null && !ok)
            Text(trx('Your answer: ${q.options[a]}', 'আপনার উত্তর: ${q.options[a]}'), style: const TextStyle(color: Colors.red)),
          Text(trx('Correct: ${q.correctText}', 'সঠিক: ${q.correctText}'),
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
          if (q.explanation.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(q.explanation)),
        ],
      ),
    );
  }
}
