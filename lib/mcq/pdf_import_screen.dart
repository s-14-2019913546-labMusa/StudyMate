import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../language_manager.dart';
import 'bijoy_converter.dart';
import 'mcq_service.dart';
import 'pdf_mcq_parser.dart';
import 'pdf_text_service.dart';

/// PDF থেকে MCQ প্রশ্ন যোগ: PDF বাছাই → লেখা বের করা (দরকারে OCR) → প্রশ্ন ভাগ → দেখে ঠিক করে সেভ।
/// সবকিছু ফোনেই হয়, কোনো টাকা লাগে না।
class PdfImportScreen extends StatefulWidget {
  final List<String> subjects;
  final String? initialSubject;
  const PdfImportScreen({super.key, required this.subjects, this.initialSubject});

  @override
  State<PdfImportScreen> createState() => _PdfImportScreenState();
}

enum _Step { pick, reading, review }

class _PdfImportScreenState extends State<PdfImportScreen> {
  static const _letters = ['ক', 'খ', 'গ', 'ঘ'];

  _Step _step = _Step.pick;
  String? _path, _name;
  int _pages = 0;
  final _fromCtrl = TextEditingController(text: '1');
  final _toCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  late String _subject = widget.initialSubject ??
      (widget.subjects.isNotEmpty ? widget.subjects.first : 'অন্যান্য');
  bool _forceOcr = false;

  // পড়ার অবস্থা
  int _done = 0, _total = 0;
  bool _ocrNow = false, _cancel = false;
  int _ocrPages = 0, _textPages = 0;

  // ফলাফল
  String _raw = '';
  bool _bijoy = false;
  List<McqDraft> _drafts = [];
  int _keyAnswers = 0, _fromKey = 0;
  bool _onlyMissing = false;
  bool _saving = false;

  String get _subjectName => _subjectCtrl.text.trim().isNotEmpty ? _subjectCtrl.text.trim() : _subject;

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  void _snack(String en, String bn) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx(en, bn))));

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final path = r?.files.single.path;
    if (path == null) return;
    try {
      final n = await PdfTextService.pageCount(path);
      setState(() {
        _path = path;
        _name = r!.files.single.name;
        _pages = n;
        _fromCtrl.text = '1';
        _toCtrl.text = '$n';
      });
    } catch (e) {
      _snack('Could not open this PDF (it may be password-protected or damaged).',
          'এই PDF খোলা যায়নি (পাসওয়ার্ড দেওয়া বা নষ্ট ফাইল হতে পারে)।');
    }
  }

  Future<void> _read() async {
    final from = (int.tryParse(_fromCtrl.text.trim()) ?? 1).clamp(1, _pages);
    final to = (int.tryParse(_toCtrl.text.trim()) ?? _pages).clamp(from, _pages);
    setState(() {
      _step = _Step.reading;
      _done = 0;
      _total = to - from + 1;
      _cancel = false;
      _ocrNow = false;
    });
    try {
      final res = await PdfTextService.extract(
        _path!,
        from: from,
        to: to,
        forceOcr: _forceOcr,
        isCancelled: () => _cancel,
        onProgress: (d, t, ocr) {
          if (!mounted) return;
          setState(() {
            _done = d;
            _total = t;
            _ocrNow = ocr;
          });
        },
      );
      _raw = res.text;
      _ocrPages = res.ocrPages;
      _textPages = res.textPages;
      _bijoy = BijoyConverter.looksLikeBijoy(_raw);
      _parse();
      if (!mounted) return;
      setState(() => _step = _Step.review);
    } catch (e) {
      if (!mounted) return;
      setState(() => _step = _Step.pick);
      _snack('Could not read the PDF: $e. The first OCR needs internet once to download language files.',
          'PDF পড়া যায়নি: $e। প্রথমবার OCR-এর ভাষা-ফাইল নামাতে একবার ইন্টারনেট লাগে।');
    }
  }

  void _parse() {
    final r = PdfMcqParser.parseDocument(_raw, bijoy: _bijoy);
    var drafts = r.drafts;
    // কিছুই না মিললে পুরনো পেস্ট-পার্সার দিয়েও একবার চেষ্টা
    if (drafts.where((d) => d.complete).isEmpty) {
      final old = McqService.parsePasted(PdfMcqParser.normalize(_raw, bijoy: _bijoy), _subjectName);
      if (old.isNotEmpty) {
        drafts = [
          for (final q in old) McqDraft(question: q.question, options: [...q.options], answer: q.answer, explanation: q.explanation)
        ];
      }
    }
    _drafts = drafts;
    _keyAnswers = r.keyAnswers;
    _fromKey = r.filledFromKey;
  }

  Future<void> _save() async {
    final chosen = _drafts.where((d) => d.include).toList();
    final ready = chosen.where((d) => d.ready).toList();
    final notReady = chosen.length - ready.length;
    if (ready.isEmpty) {
      _snack('Pick the correct answer for at least one question first.', 'আগে অন্তত একটা প্রশ্নের সঠিক উত্তর বাছুন।');
      return;
    }
    if (notReady > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(trx('Some questions are not ready', 'কিছু প্রশ্ন অসম্পূর্ণ')),
          content: Text(trx(
              '$notReady ticked questions have no answer or not 4 options. They will be skipped. Save the other ${ready.length}?',
              'টিক দেওয়া $notReadyটি প্রশ্নে উত্তর নেই বা ৪টা অপশন নেই, সেগুলো বাদ যাবে। বাকি ${ready.length}টি সেভ করবেন?')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(trx('Go back', 'ফিরে যাই'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(trx('Save', 'সেভ করুন'))),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _saving = true);
    try {
      final n = await McqService.saveCustom(ready.map((d) => d.toQuestion(_subjectName)).toList());
      if (!mounted) return;
      _snack('$n questions added ✓', '$nটি প্রশ্ন যোগ হয়েছে ✓');
      Navigator.pop(context, n);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Could not save: $e', 'সেভ করা যায়নি: $e');
    }
  }

  Future<void> _edit(McqDraft d) async {
    final q = TextEditingController(text: d.question);
    final opts = List.generate(4, (i) => TextEditingController(text: i < d.options.length ? d.options[i] : ''));
    final exp = TextEditingController(text: d.explanation);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(trx('Edit question', 'প্রশ্ন ঠিক করুন')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: q, minLines: 2, maxLines: 5, decoration: InputDecoration(labelText: trx('Question', 'প্রশ্ন'))),
            for (var i = 0; i < 4; i++)
              TextField(controller: opts[i], decoration: InputDecoration(labelText: '${_letters[i]})')),
            TextField(controller: exp, maxLines: 3, decoration: InputDecoration(labelText: trx('Explanation (optional)', 'ব্যাখ্যা (ঐচ্ছিক)'))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(trx('Cancel', 'বাতিল'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(trx('OK', 'ঠিক আছে'))),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        d.question = q.text.trim();
        d.options = opts.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
        if (d.answer >= d.options.length) d.answer = -1;
        d.explanation = exp.text.trim();
        if (d.complete) d.include = true;
      });
    }
    for (final c in [q, exp, ...opts]) {
      c.dispose();
    }
  }

  void _showRaw() {
    final text = PdfMcqParser.normalize(_raw, bijoy: _bijoy);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(child: Text(trx('Text read from the PDF', 'PDF থেকে পড়া লেখা'), style: const TextStyle(fontWeight: FontWeight.bold))),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                Navigator.pop(c);
                _snack('Copied. You can fix it and paste in "Add questions → Paste".',
                    'কপি হয়েছে। ঠিক করে "প্রশ্ন যোগ → পেস্ট"-এ দিতে পারেন।');
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(trx('Copy', 'কপি')),
            ),
          ]),
          Expanded(child: SingleChildScrollView(child: SelectableText(text.trim().isEmpty ? '—' : text))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step != _Step.reading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == _Step.reading) setState(() => _cancel = true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(trx('Questions from PDF', 'PDF থেকে প্রশ্ন')),
          actions: [
            if (_step == _Step.review)
              IconButton(tooltip: trx('See text', 'লেখা দেখুন'), icon: const Icon(Icons.article_outlined), onPressed: _showRaw),
          ],
        ),
        body: switch (_step) {
          _Step.pick => _pickView(),
          _Step.reading => _readingView(),
          _Step.review => _reviewView(),
        },
        bottomNavigationBar: _step == _Step.review ? _saveBar() : null,
      ),
    );
  }

  Widget _pickView() {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        OutlinedButton.icon(
          onPressed: _pick,
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: Text(_path == null ? trx('Choose a PDF', 'PDF বাছুন') : trx('Choose another PDF', 'অন্য PDF বাছুন')),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
        ),
        const SizedBox(height: 10),
        Text(
          trx('Works with typed PDFs, Bijoy/SutonnyMJ PDFs and scanned (CamScanner) PDFs. Everything runs on your phone, free, with no page limit.',
              'টাইপ করা PDF, বিজয়/SutonnyMJ PDF আর স্ক্যান করা (ক্যামস্ক্যানার) PDF সবই চলবে। সব কাজ ফোনেই হয়, ফ্রি, পাতার কোনো সীমা নেই।'),
          style: muted,
        ),
        if (_path != null) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(_name ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(trx('$_pages pages', '$_pages পাতা')),
            ),
          ),
          const SizedBox(height: 12),
          Text(trx('Pages to read', 'কোন পাতা থেকে কোন পাতা'), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _fromCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: trx('From', 'শুরু'), border: const OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _toCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: trx('To', 'শেষ'), border: const OutlineInputBorder()),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
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
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _forceOcr,
            onChanged: (v) => setState(() => _forceOcr = v),
            title: Text(trx('Read every page as a photo (OCR)', 'সব পাতা ছবি হিসেবে পড়ুন (OCR)')),
            subtitle: Text(
                trx('Pages without text are read with OCR anyway. Turn this on only if the text comes out garbled.',
                    'যে পাতায় লেখা নেই সেগুলো এমনিতেই OCR হবে। লেখা ভাঙাচোরা এলে তবেই এটা চালু করুন।'),
                style: muted),
          ),
          Text(
            trx('Scanned pages take a few seconds each. The first OCR downloads language files once (needs internet).',
                'স্ক্যান করা প্রতি পাতায় কয়েক সেকেন্ড লাগে। প্রথমবার OCR-এর ভাষা-ফাইল একবার নামবে (ইন্টারনেট লাগবে)।'),
            style: muted,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _read,
            icon: const Icon(Icons.auto_fix_high_rounded),
            label: Text(trx('Find questions', 'প্রশ্ন খুঁজুন')),
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
          ),
        ],
      ],
    );
  }

  Widget _readingView() {
    final v = _total == 0 ? null : _done / _total;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          LinearProgressIndicator(value: v, minHeight: 8, borderRadius: BorderRadius.circular(8)),
          const SizedBox(height: 16),
          Text(trx('Page $_done of $_total', 'পাতা $_done / $_total'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            _ocrNow
                ? trx('Reading a scanned page (OCR)…', 'স্ক্যান করা পাতা পড়া হচ্ছে (OCR)…')
                : trx('Reading text…', 'লেখা পড়া হচ্ছে…'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _cancel ? null : () => setState(() => _cancel = true),
            icon: const Icon(Icons.stop_rounded),
            label: Text(_cancel ? trx('Stopping…', 'থামানো হচ্ছে…') : trx('Stop here and use what is read', 'এখানেই থামুন, যতটুকু পড়া হলো তা দিয়ে চলুন')),
          ),
        ]),
      ),
    );
  }

  Widget _reviewView() {
    final scheme = Theme.of(context).colorScheme;
    final complete = _drafts.where((d) => d.complete).length;
    final missing = _drafts.where((d) => d.complete && d.answer < 0).length;
    final list = _onlyMissing ? _drafts.where((d) => !d.ready).toList() : _drafts;

    final header = Card(
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(trx('$complete questions found', '$completeটি প্রশ্ন পাওয়া গেছে'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(trx(
              '${complete - missing} with answers · $missing need an answer. Tap the right option to choose it.',
              '${complete - missing}টির উত্তর আছে · $missingটির উত্তর বাছতে হবে। সঠিক অপশনে চাপ দিলেই উত্তর বাছা হবে।')),
          if (_keyAnswers > 0)
            Text(trx('Answer key found: $_keyAnswers answers ($_fromKey matched).',
                'উত্তরপত্র পাওয়া গেছে: $_keyAnswersটি উত্তর ($_fromKeyটি মিলেছে)।')),
          if (_ocrPages > 0)
            Text(trx('$_ocrPages pages read with OCR, $_textPages with text. Check OCR questions carefully.',
                '$_ocrPages পাতা OCR দিয়ে, $_textPages পাতা সরাসরি লেখা থেকে পড়া। OCR-এর প্রশ্নগুলো ভালো করে দেখে নিন।')),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            FilterChip(
              label: Text(trx('Bijoy → Unicode', 'বিজয় → ইউনিকোড')),
              selected: _bijoy,
              onSelected: (v) => setState(() {
                _bijoy = v;
                _parse();
              }),
            ),
            FilterChip(
              label: Text(trx('Only unfinished', 'শুধু অসম্পূর্ণগুলো')),
              selected: _onlyMissing,
              onSelected: (v) => setState(() => _onlyMissing = v),
            ),
          ]),
        ]),
      ),
    );

    if (_drafts.isEmpty) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        header,
        const SizedBox(height: 20),
        Icon(Icons.search_off_rounded, size: 56, color: scheme.onSurfaceVariant),
        const SizedBox(height: 10),
        Text(
          trx('No questions could be recognised. Tap "See text" (top right) to check what was read. If the text is garbled, go back and turn on "Read every page as a photo", or try the Bijoy switch above.',
              'কোনো প্রশ্ন চেনা যায়নি। উপরে ডানে "লেখা দেখুন" চেপে দেখুন কী পড়া হয়েছে। লেখা ভাঙাচোরা হলে ফিরে গিয়ে "সব পাতা ছবি হিসেবে পড়ুন" চালু করুন, অথবা উপরের বিজয় সুইচটা বদলে দেখুন।'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => setState(() => _step = _Step.pick), child: Text(trx('Back', 'ফিরে যান'))),
      ]);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: list.length + 1,
      itemBuilder: (_, i) => i == 0 ? header : _draftCard(list[i - 1]),
    );
  }

  Widget _draftCard(McqDraft d) {
    final scheme = Theme.of(context).colorScheme;
    final warn = !d.complete
        ? trx('Needs 4 options — tap ✎ to fix', '৪টা অপশন নেই, ✎ চেপে ঠিক করুন')
        : d.answer < 0
            ? trx('Choose the correct answer', 'সঠিক উত্তর বাছুন')
            : null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: warn != null && d.include ? scheme.error.withValues(alpha: 0.6) : Colors.transparent),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(value: d.include, onChanged: (v) => setState(() => d.include = v ?? false)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('${d.number != null ? '${d.number}. ' : ''}${d.question}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            IconButton(tooltip: trx('Edit', 'ঠিক করুন'), icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _edit(d)),
          ]),
          for (var i = 0; i < d.options.length && i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() {
                  d.answer = i;
                  if (d.complete) d.include = true;
                }),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 42),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: d.answer == i ? Colors.green.withValues(alpha: 0.18) : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: Border.all(color: d.answer == i ? Colors.green : Colors.transparent),
                  ),
                  child: Row(children: [
                    Text('${_letters[i]}) ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(d.options[i])),
                    if (d.answer == i) const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                  ]),
                ),
              ),
            ),
          if (warn != null)
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 6),
              child: Text(warn, style: TextStyle(color: scheme.error, fontSize: 12.5)),
            ),
        ]),
      ),
    );
  }

  Widget _saveBar() {
    final ready = _drafts.where((d) => d.include && d.ready).length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: FilledButton.icon(
          onPressed: _saving || ready == 0 ? null : _save,
          icon: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_rounded),
          label: Text(trx('Save $ready questions', '$readyটি প্রশ্ন সেভ করুন')),
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
        ),
      ),
    );
  }
}
