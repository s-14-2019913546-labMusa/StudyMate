import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../ai_service.dart';
import '../language_manager.dart';
import '../widgets/skeleton.dart';
import 'mcq_service.dart';
import 'mcq_test_screen.dart';
import 'mistake_book_screen.dart';
import 'mistake_book_service.dart';

/// MCQ প্র্যাকটিস ও মডেল টেস্ট: পরীক্ষা ও বিষয় বেছে প্রশ্ন, শেষে ফলাফল ও দুর্বল বিষয়
class McqHomeScreen extends StatefulWidget {
  const McqHomeScreen({super.key});

  @override
  State<McqHomeScreen> createState() => _McqHomeScreenState();
}

class _McqHomeScreenState extends State<McqHomeScreen> {
  List<McqQuestion> _all = [];
  bool _loading = true;
  String _exam = 'all';
  final Set<String> _subjects = {};
  int _count = 20;
  String _mode = 'practice';
  bool _negative = true;
  Map<String, double> _accuracy = {};
  int _mistakesDue = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await McqService.loadAll();
    Map<String, double> acc = {};
    int due = 0;
    try {
      acc = await McqService.subjectAccuracy();
      due = await MistakeBookService.dueCount();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _all = all;
      _accuracy = acc;
      _mistakesDue = due;
      _loading = false;
    });
  }

  List<String> get _availableSubjects {
    final s = <String>{};
    for (final q in _all) {
      if (McqService.subjectInExam(q.subject, _exam)) s.add(q.subject);
    }
    return s.toList();
  }

  List<McqQuestion> get _pool => _all
      .where((q) => McqService.subjectInExam(q.subject, _exam))
      .where((q) => _subjects.isEmpty || _subjects.contains(q.subject))
      .toList();

  void _start({List<McqQuestion>? custom, String? mode}) {
    final pool = List<McqQuestion>.from(custom ?? _pool)..shuffle(Random());
    if (pool.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(trx('No questions for this choice yet. Add some with "Add questions".',
              'এই বাছাইয়ে এখনো প্রশ্ন নেই। "প্রশ্ন যোগ করুন" দিয়ে যোগ করুন।'))));
      return;
    }
    final qs = pool.take(min(_count, pool.length)).toList();
    final m = mode ?? _mode;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => McqTestScreen(
          questions: qs,
          mode: m,
          exam: _exam,
          negativePerWrong: m == 'test' && _negative ? 0.5 : 0,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bn = LanguageManager().isBengali;
    final weak = _accuracy.entries.where((e) => e.value < 60).toList()..sort((a, b) => a.value.compareTo(b.value));

    return Scaffold(
      appBar: AppBar(
        title: Text(trx('MCQ Practice', 'MCQ প্র্যাকটিস')),
        actions: [
          IconButton(
            tooltip: trx('Add questions', 'প্রশ্ন যোগ করুন'),
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: () async {
              final added = await showModalBottomSheet<int>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => McqImportSheet(subjects: _availableSubjects),
              );
              if (added != null && added > 0) _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const SkeletonCardList(count: 5)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // ভুলের খাতা
                Card(
                  child: ListTile(
                    minVerticalPadding: 14,
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.withValues(alpha: 0.12),
                      child: const Icon(Icons.menu_book_rounded, color: Colors.red),
                    ),
                    title: Text(trx('Mistake Book', 'ভুলের খাতা'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_mistakesDue > 0
                        ? trx('$_mistakesDue questions to revise today', 'আজ $_mistakesDueটি প্রশ্ন রিভিশন বাকি')
                        : trx('Every wrong answer is saved here', 'যত প্রশ্ন ভুল হয়, সব এখানে জমা থাকে')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MistakeBookScreen()))
                        .then((_) => _load()),
                  ),
                ),
                if (weak.isNotEmpty)
                  Card(
                    color: Colors.orange.withValues(alpha: 0.07),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.trending_down_rounded, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(trx('Your weak subjects', 'আপনার দুর্বল বিষয়'),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final e in weak.take(4))
                                ActionChip(
                                  label: Text('${e.key} · ${e.value.round()}%'),
                                  onPressed: () => _start(
                                    custom: _all.where((q) => q.subject == e.key).toList(),
                                    mode: 'practice',
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(trx('Tap one to practise it now', 'যেকোনোটায় চাপলে এখনই সেই বিষয়ের প্র্যাকটিস'),
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _label(trx('Exam', 'পরীক্ষা')),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in McqService.examNames.entries)
                      ChoiceChip(
                        label: Text(bn ? e.value.$2 : e.value.$1),
                        selected: _exam == e.key,
                        onSelected: (_) => setState(() {
                          _exam = e.key;
                          _subjects.removeWhere((s) => !_availableSubjects.contains(s));
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _label(trx('Subjects (none selected = all)', 'বিষয় (কিছু না বাছলে সব)')),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final s in _availableSubjects)
                      FilterChip(
                        label: Text(s),
                        selected: _subjects.contains(s),
                        onSelected: (v) => setState(() => v ? _subjects.add(s) : _subjects.remove(s)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _label(trx('Number of questions', 'প্রশ্নের সংখ্যা')),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 10, label: Text('10')),
                    ButtonSegment(value: 20, label: Text('20')),
                    ButtonSegment(value: 50, label: Text('50')),
                    ButtonSegment(value: 100, label: Text('100')),
                  ],
                  selected: {_count},
                  onSelectionChanged: (v) => setState(() => _count = v.first),
                ),
                const SizedBox(height: 12),
                _label(trx('Mode', 'ধরন')),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'practice', icon: const Icon(Icons.school_outlined), label: Text(trx('Practice', 'প্র্যাকটিস'))),
                    ButtonSegment(value: 'test', icon: const Icon(Icons.timer_outlined), label: Text(trx('Model test', 'মডেল টেস্ট'))),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (v) => setState(() => _mode = v.first),
                ),
                const SizedBox(height: 6),
                Text(
                  _mode == 'practice'
                      ? trx('See the right answer after each question.', 'প্রতিটা প্রশ্নের পরেই সঠিক উত্তর দেখাবে।')
                      : trx('Timed like the real exam (36 s per question). Result at the end.',
                          'আসল পরীক্ষার মতো সময় ধরে (প্রতি প্রশ্নে ৩৬ সেকেন্ড)। শেষে ফলাফল।'),
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                if (_mode == 'test')
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(trx('Negative marking (−0.5 per wrong)', 'নেগেটিভ মার্কিং (প্রতি ভুলে −০.৫)')),
                    value: _negative,
                    onChanged: (v) => setState(() => _negative = v),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _start(),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    trx('Start (${min(_count, _pool.length)} of ${_pool.length} questions)',
                        'শুরু করুন (${_pool.length}টির মধ্যে ${min(_count, _pool.length)}টি প্রশ্ন)'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
                ),
                const SizedBox(height: 10),
                Text(
                  trx('The app includes ${_all.where((q) => q.source == 'bank').length} starter questions. Add more from the top-right button: paste your own or let AI write them.',
                      'অ্যাপে ${_all.where((q) => q.source == 'bank').length}টি শুরুর প্রশ্ন আছে। উপরে ডানের বাটন দিয়ে আরও যোগ করুন: নিজের প্রশ্ন পেস্ট করুন বা AI দিয়ে বানান।'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
      );
}

/// প্রশ্ন যোগ: পেস্ট করে বা AI দিয়ে
class McqImportSheet extends StatefulWidget {
  final List<String> subjects;
  final String? initialText;
  final bool startWithAi;
  const McqImportSheet({super.key, required this.subjects, this.initialText, this.startWithAi = false});

  @override
  State<McqImportSheet> createState() => _McqImportSheetState();
}

class _McqImportSheetState extends State<McqImportSheet> {
  late bool _ai = widget.startWithAi;
  late final TextEditingController _text = TextEditingController(text: widget.initialText ?? '');
  final TextEditingController _subjectCtrl = TextEditingController();
  late String _subject = widget.subjects.isNotEmpty ? widget.subjects.first : 'অন্যান্য';
  bool _busy = false;
  int _aiCount = 10;

  @override
  void dispose() {
    _text.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  String get _subjectName => _subjectCtrl.text.trim().isNotEmpty ? _subjectCtrl.text.trim() : _subject;

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      List<McqQuestion> qs;
      if (_ai) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final key = uid == null ? null : await AIService.getSavedApiKey(uid);
        if (key == null || key.isEmpty) {
          messenger.showSnackBar(SnackBar(
              content: Text(trx('Add your Gemini API key in Profile → AI Settings first.',
                  'আগে Profile → AI Settings-এ Gemini API Key দিন।'))));
          setState(() => _busy = false);
          return;
        }
        final text = _text.text.trim();
        final raw = await AIService.generateMcqs(
          topicOrText: text,
          apiKey: key,
          count: _aiCount,
          subject: _subjectName,
          fromText: text.length > 200,
        );
        qs = raw
            .map((m) => McqQuestion(
                  id: McqQuestion.stableId('ai', m['question'] as String),
                  subject: _subjectName,
                  question: m['question'] as String,
                  options: List<String>.from(m['options'] as List),
                  answer: m['answer'] as int,
                  explanation: (m['explanation'] ?? '') as String,
                  source: 'ai',
                ))
            .toList();
      } else {
        qs = McqService.parsePasted(_text.text, _subjectName);
      }
      if (qs.isEmpty) {
        messenger.showSnackBar(SnackBar(
            content: Text(trx('No questions found. Check the format shown below the box.',
                'কোনো প্রশ্ন পাওয়া যায়নি। বক্সের নিচের নিয়মটা দেখে নিন।'))));
        setState(() => _busy = false);
        return;
      }
      final n = await McqService.saveCustom(qs);
      messenger.showSnackBar(SnackBar(content: Text(trx('$n questions added ✓', '$nটি প্রশ্ন যোগ হয়েছে ✓'))));
      if (mounted) Navigator.pop(context, n);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(trx('Could not add questions: $e', 'প্রশ্ন যোগ করা যায়নি: $e'))));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trx('Add questions', 'প্রশ্ন যোগ করুন'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, icon: const Icon(Icons.content_paste_rounded), label: Text(trx('Paste', 'পেস্ট'))),
                ButtonSegment(value: true, icon: const Icon(Icons.auto_awesome_rounded), label: Text(trx('AI', 'AI দিয়ে'))),
              ],
              selected: {_ai},
              onSelectionChanged: (v) => setState(() => _ai = v.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: widget.subjects.contains(_subject) ? _subject : null,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: trx('Subject', 'বিষয়'), border: const OutlineInputBorder()),
                    items: [for (final s in widget.subjects) DropdownMenuItem(value: s, child: Text(s))],
                    onChanged: (v) => setState(() => _subject = v ?? _subject),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _subjectCtrl,
                    decoration: InputDecoration(labelText: trx('or new subject', 'অথবা নতুন বিষয়'), border: const OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              minLines: _ai ? 2 : 6,
              maxLines: 10,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: _ai
                    ? trx('Topic (e.g. "Liberation War 1971") or paste study text', 'বিষয় লিখুন (যেমন "মুক্তিযুদ্ধ ১৯৭১") অথবা পড়ার লেখা পেস্ট করুন')
                    : 'বাংলাদেশের জাতীয় ফুল কোনটি?\nক) গোলাপ\nখ) শাপলা\nগ) জবা\nঘ) বেলি\nউত্তর: খ',
              ),
            ),
            const SizedBox(height: 6),
            if (!_ai)
              Text(
                trx('One question per block, a blank line between questions. Options ক) খ) গ) ঘ) or A) B) C) D), then "উত্তর: খ" or "Ans: B". Optional "ব্যাখ্যা: ..." line.',
                    'প্রতিটা প্রশ্নের মাঝে একটা ফাঁকা লাইন। অপশন ক) খ) গ) ঘ) বা A) B) C) D), তারপর "উত্তর: খ" বা "Ans: B"। চাইলে "ব্যাখ্যা: ..." লাইন দিন।'),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              )
            else
              Row(
                children: [
                  Text(trx('How many:', 'কয়টি:')),
                  const SizedBox(width: 8),
                  for (final n in [5, 10, 20])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(label: Text('$n'), selected: _aiCount == n, onSelected: (_) => setState(() => _aiCount = n)),
                    ),
                ],
              ),
            if (_ai)
              Text(trx('AI can make mistakes — check the answers.', 'AI ভুল করতে পারে, উত্তরগুলো যাচাই করে নিন।'),
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              label: Text(_ai ? trx('Generate & save', 'বানিয়ে সেভ করুন') : trx('Save questions', 'প্রশ্ন সেভ করুন')),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ],
        ),
      ),
    );
  }
}
