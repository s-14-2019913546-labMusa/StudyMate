import 'dart:async';
import 'package:flutter/material.dart';
import '../language_manager.dart';
import 'mcq_result_screen.dart';
import 'mcq_service.dart';
import 'mistake_book_service.dart';

/// mode: 'practice' = প্রতিটা উত্তর সাথে সাথে দেখায়
///       'test'     = মডেল টেস্ট, সময় ধরা, শেষে ফলাফল
///       'review'   = ভুলের খাতার রিভিশন (practice-এর মতো, ১-৪-৭ ধাপ হালনাগাদ হয়)
class McqTestScreen extends StatefulWidget {
  final List<McqQuestion> questions;
  final String mode;
  final String exam;
  final int secondsPerQuestion;
  final double negativePerWrong;

  const McqTestScreen({
    super.key,
    required this.questions,
    required this.mode,
    this.exam = 'all',
    this.secondsPerQuestion = 36,
    this.negativePerWrong = 0,
  });

  @override
  State<McqTestScreen> createState() => _McqTestScreenState();
}

class _McqTestScreenState extends State<McqTestScreen> {
  late final List<int?> _answers = List<int?>.filled(widget.questions.length, null);
  int _index = 0;
  Timer? _timer;
  late int _remaining = widget.questions.length * widget.secondsPerQuestion;
  final Stopwatch _watch = Stopwatch()..start();
  bool _finished = false;

  bool get _isTest => widget.mode == 'test';
  static const _letters = ['ক', 'খ', 'গ', 'ঘ'];
  static const _lettersEn = ['A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();
    if (_isTest) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _remaining--);
        if (_remaining <= 0) _finish(timeUp: true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _choose(int option) {
    if (_finished) return;
    if (!_isTest && _answers[_index] != null) return; // practice-এ একবারই উত্তর
    setState(() => _answers[_index] = option);
    if (!_isTest) {
      final q = widget.questions[_index];
      final correct = option == q.answer;
      if (widget.mode == 'review') {
        MistakeBookService.recordReview(q, correct, option);
      } else if (!correct) {
        MistakeBookService.recordWrong(q, option);
      }
    }
  }

  void _go(int delta) {
    final n = _index + delta;
    if (n < 0) return;
    if (n >= widget.questions.length) {
      _confirmFinish();
      return;
    }
    setState(() => _index = n);
  }

  Future<void> _confirmFinish() async {
    if (!_isTest) {
      _finish();
      return;
    }
    final unanswered = _answers.where((a) => a == null).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trx('Submit the test?', 'পরীক্ষা জমা দেবেন?')),
        content: Text(unanswered > 0
            ? trx('$unanswered questions are still unanswered.', 'এখনো $unansweredটি প্রশ্নের উত্তর দেননি।')
            : trx('All questions answered.', 'সব প্রশ্নের উত্তর দেওয়া হয়েছে।')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(trx('Keep going', 'চালিয়ে যাই'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(trx('Submit', 'জমা দিন'))),
        ],
      ),
    );
    if (ok == true) _finish();
  }

  Future<void> _finish({bool timeUp = false}) async {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    _watch.stop();

    int correct = 0, wrong = 0, skipped = 0;
    final perSubject = <String, List<int>>{};
    final wrongQs = <McqQuestion>[];
    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      final a = _answers[i];
      perSubject.putIfAbsent(q.subject, () => [0, 0]);
      perSubject[q.subject]![1]++;
      if (a == null) {
        skipped++;
      } else if (a == q.answer) {
        correct++;
        perSubject[q.subject]![0]++;
      } else {
        wrong++;
        wrongQs.add(q);
      }
    }
    final result = McqResult(
      total: widget.questions.length,
      correct: correct,
      wrong: wrong,
      skipped: skipped,
      negativePerWrong: widget.negativePerWrong,
      seconds: _watch.elapsed.inSeconds,
      mode: widget.mode,
      exam: widget.exam,
      perSubject: perSubject,
    );

    // মডেল টেস্টের ভুলগুলো এখন ভুলের খাতায় (practice-এ উত্তর দেওয়ার সময়ই জমা হয়)
    if (_isTest) {
      for (int i = 0; i < widget.questions.length; i++) {
        final a = _answers[i];
        if (a != null && a != widget.questions[i].answer) {
          MistakeBookService.recordWrong(widget.questions[i], a);
        }
      }
    }
    int addedToCards = 0;
    try {
      if (widget.mode != 'review') {
        McqService.saveResult(result);
        addedToCards = await MistakeBookService.addToFlashcards(wrongQs);
      }
    } catch (_) {}

    if (!mounted) return;
    if (timeUp) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Time is up!', 'সময় শেষ!'))));
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => McqResultScreen(
          result: result,
          questions: widget.questions,
          answers: List<int?>.from(_answers),
          addedToFlashcards: addedToCards,
        ),
      ),
    );
  }

  String _clock(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  Future<bool> _confirmLeave() async {
    if (_finished || _answers.every((a) => a == null)) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trx('Leave the test?', 'পরীক্ষা ছেড়ে যাবেন?')),
        content: Text(trx('Your answers will not be saved.', 'আপনার উত্তরগুলো সেভ হবে না।')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(trx('Stay', 'থাকি'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(trx('Leave', 'বের হই'))),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = widget.questions[_index];
    final chosen = _answers[_index];
    final revealed = !_isTest && chosen != null;
    final bn = LanguageManager().isBengali;
    final title = switch (widget.mode) {
      'test' => trx('Model test', 'মডেল টেস্ট'),
      'review' => trx('Mistake review', 'ভুলের রিভিশন'),
      _ => trx('Practice', 'প্র্যাকটিস'),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            if (_isTest)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (_remaining < 60 ? Colors.red : scheme.primary).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(children: [
                      Icon(Icons.timer_outlined, size: 18, color: _remaining < 60 ? Colors.red : scheme.primary),
                      const SizedBox(width: 4),
                      Text(_clock(_remaining.clamp(0, 99999)),
                          style: TextStyle(fontWeight: FontWeight.bold, color: _remaining < 60 ? Colors.red : scheme.primary)),
                    ]),
                  ),
                ),
              ),
            if (_isTest)
              TextButton(onPressed: _confirmFinish, child: Text(trx('Submit', 'জমা'))),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              LinearProgressIndicator(value: (_index + 1) / widget.questions.length, minHeight: 4),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(trx('Question ${_index + 1} of ${widget.questions.length}', 'প্রশ্ন ${_index + 1} / ${widget.questions.length}'),
                              style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(q.subject, style: TextStyle(fontSize: 12, color: scheme.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(q.question,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.4)),
                      const SizedBox(height: 20),
                      for (int i = 0; i < q.options.length; i++) _option(q, i, chosen, revealed, bn),
                      if (revealed) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: (chosen == q.answer ? Colors.green : Colors.orange).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chosen == q.answer
                                    ? trx('✓ Correct!', '✓ সঠিক!')
                                    : trx('✗ Correct answer: ${q.correctText}', '✗ সঠিক উত্তর: ${q.correctText}'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: chosen == q.answer ? Colors.green.shade700 : Colors.orange.shade800,
                                ),
                              ),
                              if (q.explanation.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(q.explanation, style: const TextStyle(height: 1.4)),
                              ],
                              if (chosen != q.answer && widget.mode != 'review') ...[
                                const SizedBox(height: 6),
                                Text(trx('Saved to your Mistake Book.', 'ভুলের খাতায় জমা হলো।'),
                                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_isTest) _palette(scheme),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    if (_index > 0)
                      OutlinedButton.icon(
                        onPressed: () => _go(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                        label: Text(trx('Back', 'আগের')),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: (!_isTest && chosen == null) ? null : () => _go(1),
                      icon: Icon(_index == widget.questions.length - 1 ? Icons.check_rounded : Icons.chevron_right_rounded),
                      label: Text(_index == widget.questions.length - 1
                          ? trx('Finish', 'শেষ করুন')
                          : (_isTest && chosen == null ? trx('Skip', 'বাদ দিন') : trx('Next', 'পরের'))),
                      style: FilledButton.styleFrom(minimumSize: const Size(130, 50)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _option(McqQuestion q, int i, int? chosen, bool revealed, bool bn) {
    final scheme = Theme.of(context).colorScheme;
    Color border = scheme.outlineVariant;
    Color fill = Colors.transparent;
    IconData? icon;
    if (revealed) {
      if (i == q.answer) {
        border = Colors.green;
        fill = Colors.green.withValues(alpha: 0.08);
        icon = Icons.check_circle_rounded;
      } else if (i == chosen) {
        border = Colors.red;
        fill = Colors.red.withValues(alpha: 0.08);
        icon = Icons.cancel_rounded;
      }
    } else if (i == chosen) {
      border = scheme.primary;
      fill = scheme.primary.withValues(alpha: 0.08);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _choose(i),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: border.withValues(alpha: 0.15),
                  child: Text(bn ? _letters[i] : _lettersEn[i],
                      style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(q.options[i], style: const TextStyle(fontSize: 16))),
                if (icon != null) Icon(icon, color: border),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// মডেল টেস্টে কোন প্রশ্নে উত্তর দেওয়া হয়েছে তার ছোট তালিকা
  Widget _palette(ColorScheme scheme) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: widget.questions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final answered = _answers[i] != null;
          final current = i == _index;
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _index = i),
            child: Container(
              width: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: answered ? scheme.primary.withValues(alpha: 0.85) : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: current ? Border.all(color: scheme.onSurface, width: 2) : null,
              ),
              child: Text('${i + 1}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: answered ? scheme.onPrimary : scheme.onSurface)),
            ),
          );
        },
      ),
    );
  }
}
