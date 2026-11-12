import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_entry.dart';
import 'exam_presets.dart';
import 'language_manager.dart';

/// প্রথমবার অ্যাপ খুললে ছোট পরিচিতি (৩টা স্লাইড + পরীক্ষা বাছাই)
class OnboardingScreen extends StatefulWidget {
  /// Profile থেকে খোলা হলে শেষে আগের স্ক্রিনে ফিরে যায়
  final bool fromSettings;
  const OnboardingScreen({super.key, this.fromSettings = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;
  String? _exam; // 'bcs' | 'bank' | 'primary' | 'none'
  bool _withRoutine = true;
  bool _saving = false;

  List<_Slide> get _slides => [
        _Slide(
          icon: Icons.add_task_rounded,
          color: const Color(0xFF6366F1),
          title: trx('Add tasks in seconds', 'সহজে টাস্ক যোগ করুন'),
          body: trx(
            'Tap "New Task" on Home for the full form.\nLong-press it and just type "English 8–10pm" — subject and time are understood automatically.',
            'হোমের "নতুন টাস্ক" চাপলে পুরো ফর্ম আসবে।\nলম্বা করে চাপলে শুধু লিখুন "বাংলা ব্যাকরণ ৮টা–১০টা", বিষয় আর সময় অ্যাপ নিজে বুঝে নেবে।',
          ),
        ),
        _Slide(
          icon: Icons.timer_rounded,
          color: const Color(0xFFEF4444),
          title: trx('Pomodoro: focus, then rest', 'পোমোডোরো: মনোযোগ, তারপর বিশ্রাম'),
          body: trx(
            'Study for 25 minutes, rest for 5. A tree grows while you focus — leave the app and it withers.\nFind it in Tools → Pomodoro.',
            '২৫ মিনিট পড়া, ৫ মিনিট বিশ্রাম। মনোযোগ দিয়ে পড়লে একটা গাছ বড় হয়, অ্যাপ ছেড়ে গেলে গাছ মরে যায়।\nTools → পোমোডোরো থেকে চালু করুন।',
          ),
        ),
        _Slide(
          icon: Icons.folder_copy_rounded,
          color: const Color(0xFF14B8A6),
          title: trx('Study Map: your whole syllabus', 'স্টাডি ম্যাপ: পুরো সিলেবাস এক জায়গায়'),
          body: trx(
            'Keep subjects and chapters in folders and tick them off as you finish. You always see how much is left.',
            'বিষয় আর অধ্যায় ফোল্ডারে সাজিয়ে রাখুন, পড়া শেষ হলে টিক দিন। কতটা বাকি তা সবসময় দেখা যাবে।',
          ),
        ),
      ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _finish({bool skipped = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final preset = (!skipped && _exam != null) ? ExamPresets.byId(_exam!) : null;
      if (preset != null) {
        await ExamPresets.apply(preset, withRoutine: _withRoutine);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppEntry.onboardingDoneKey, true);
      await prefs.setBool(AppEntry.onboardingPendingKey, false);
      if (preset != null) {
        messenger.showSnackBar(SnackBar(
          content: Text(trx('${preset.nameEn} syllabus${_withRoutine ? ' and weekly routine' : ''} added ✓',
              '${preset.nameBn}-এর সিলেবাস${_withRoutine ? ' ও সাপ্তাহিক রুটিন' : ''} বসানো হয়েছে ✓')),
        ));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(trx('Could not set up the syllabus: $e', 'সিলেবাস বসানো যায়নি: $e')),
      ));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppEntry.onboardingDoneKey, true);
    }
    if (!mounted) return;
    if (widget.fromSettings) {
      Navigator.of(context).pop();
      return;
    }
    final next = await AppEntry.afterOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(AppEntry.fadeRoute(next));
  }

  void _next() {
    if (_index < _slides.length) {
      _page.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final slides = _slides;
    final total = slides.length + 1;
    final isLast = _index == total - 1;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: TextButton(
                  onPressed: _saving ? null : () => _finish(skipped: true),
                  child: Text(trx('Skip', 'বাদ দিন')),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  for (final s in slides) _buildSlide(s),
                  _buildExamPage(),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < total; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? scheme.primary : scheme.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving || (isLast && _exam == null) ? null : _next,
                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(
                          isLast ? trx('Start using StudyMate', 'শুরু করুন') : trx('Next', 'পরবর্তী'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(_Slide s) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: s.color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(s.icon, size: 72, color: s.color),
          ),
          const SizedBox(height: 36),
          Text(
            s.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
          ),
          const SizedBox(height: 16),
          Text(
            s.body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildExamPage() {
    final scheme = Theme.of(context).colorScheme;
    final bn = LanguageManager().isBengali;
    Widget option(String id, String title, String subtitle, IconData icon, Color color) {
      final selected = _exam == id;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: selected ? color.withValues(alpha: 0.12) : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _exam = id),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: selected ? color : Colors.transparent, width: 2),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        if (subtitle.isNotEmpty)
                          Text(subtitle, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (selected) Icon(Icons.check_circle_rounded, color: color),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trx('Which exam are you preparing for?', 'কোন পরীক্ষার প্রস্তুতি নিচ্ছেন?'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            trx('We will add its syllabus to Study Map so you can start right away.',
                'সেই অনুযায়ী Study Map-এ সিলেবাস বসিয়ে দেওয়া হবে, যাতে সাথে সাথে শুরু করতে পারেন।'),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          for (final p in ExamPresets.all)
            option(p.id, bn ? p.nameBn : p.nameEn,
                trx('${p.syllabus.length} subjects', '${p.syllabus.length}টি বিষয়'), p.icon, p.color),
          option('none', trx('Something else / I will set it up myself', 'অন্য কিছু / নিজে সাজাবো'), '',
              Icons.edit_note_rounded, Colors.blueGrey),
          if (_exam != null && _exam != 'none')
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _withRoutine,
              onChanged: (v) => setState(() => _withRoutine = v ?? true),
              title: Text(trx('Also create a sample weekly routine', 'একটা নমুনা সাপ্তাহিক রুটিনও বসিয়ে দাও')),
              subtitle: Text(trx('Sat–Thu: 7:00–8:30 AM and 8:00–9:30 PM. You can edit it later.',
                  'শনি–বৃহস্পতি: সকাল ৭টা–৮:৩০ ও রাত ৮টা–৯:৩০। পরে বদলাতে পারবেন।')),
            ),
        ],
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Slide({required this.icon, required this.color, required this.title, required this.body});
}
