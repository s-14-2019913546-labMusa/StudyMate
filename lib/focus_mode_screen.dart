import 'package:flutter/material.dart';
import 'dart:math';
import 'dashboard_screen.dart';
import 'language_manager.dart';

// ==========================================
// 5. Focus Mode Screen (ফোকাস মোড স্ক্রিন)
// ==========================================
class FocusModeScreen extends StatefulWidget {
  const FocusModeScreen({super.key});

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen> {
  String _randomQuote = '';

  // আপনার দেওয়া বাণীগুলির তালিকা
  final List<String> _quotes = [
    "\"স্বপ্ন সেটা নয় যা তুমি ঘুমিয়ে দেখো, স্বপ্ন হলো সেটাই যা তোমাকে ঘুমাতে দেয় না।\"\n– এ. পি. জে. আব্দুল কালাম",
    "\"সাফল্য হলো প্রতিদিনের ছোট ছোট প্রচেষ্টার নিরলস যোগফল।\"\n– রবার্ট কলিয়ার",
    "\"কাজ শুরু করার সেরা উপায় হলো কথা বলা বন্ধ করে কাজে লেগে পড়া।\"\n– ওয়াল্ট ডিজনি",
    "\"সময়ের সঠিক ব্যবহারই সাফল্যের মূল চাবিকাঠি।\"\n– বেঞ্জামিন ফ্র্যাঙ্কলিন",
    "\"শুরু করার জন্য মহান হওয়ার দরকার নেই, কিন্তু মহান হতে হলে তোমাকে শুরু করতে হবে।\"\n– জিগ জিগলার",
    "\"তুমি যদি তোমার সময়কে মূল্যায়ন না করো, তবে অন্যরাও করবে না।\"\n– কিম গার্স্ট",
    "\"ভবিষ্যৎ তাদেরই যারা তাদের স্বপ্নের সৌন্দর্যে বিশ্বাস করে।\"\n– এলিনর রুজভেল্ট",
    "\"পরাজয় মানেই সব শেষ নয়, বরং এটি নতুন করে আরও বুদ্ধিমানের মতো শুরু করার সুযোগ।\"\n– হেনরি ফোর্ড",
    "\"নিজেকে বদলাও, ভাগ্য নিজেই বদলে যাবে।\"\n– স্বামী বিবেকানন্দ",
    "\"তুমি যদি ক্লান্ত হয়ে পড়ো, তবে বিশ্রাম নিতে শেখো, হাল ছাড়তে নয়।\"\n– ব্যাংকসি",
    "\"সাফল্যের কোনো শর্টকাট নেই, কঠোর পরিশ্রমই একমাত্র পথ।\"\n– কলিন পাওয়েল",
    "\"যেখানে পরিশ্রম নেই, সেখানে কোনো সাফল্য নেই।\"\n– সোফোক্লিস",
    "\"সুযোগ আসে না, সুযোগ তৈরি করে নিতে হয়।\"\n– ক্রিস গ্রসার",
    "\"বিদ্যা অর্জন হলো এমন এক সম্পদ, যা কেউ তোমার কাছ থেকে কেড়ে নিতে পারবে না।\"\n– বি. বি. কিং",
    "\"ব্যর্থতা হলো সাফল্যের মশলা যা এর স্বাদ বাড়িয়ে দেয়।\"\n– ট্রুম্যান ক্যাপোটে",
    "\"তোমার আজকের পরিশ্রম তোমার আগামীকালের ভবিষ্যৎ নির্ধারণ করবে।\"\n– সংগৃহীত",
    "\"আজকের দিনটি আর কখনো ফিরে আসবে না, তাই প্রতিটি মুহূর্ত কাজে লাগাও।\"\n– সংগৃহীত",
    "\"তুমি যা হতে চাও, তার জন্য আজ থেকেই কাজ শুরু করো।\"\n– সংগৃহীত",
    "\"নিজের প্রতি বিশ্বাস রাখো, তুমি তোমার ধারণার চেয়েও বেশি শক্তিশালী।\"\n– সংগৃহীত",
    "\"আজকের কষ্ট কালকের সাফল্যের সবচেয়ে বড় ভিত্তি।\"\n– সংগৃহীত",
    "\"The secret of getting ahead is getting started.\"\n– Mark Twain",
    "\"Don't watch the clock; do what it does. Keep going.\"\n– Sam Levenson",
    "\"It always seems impossible until it's done.\"\n– Nelson Mandela",
    "\"The future depends on what you do today.\"\n– Mahatma Gandhi",
    "\"Focus on being productive instead of busy.\"\n– Tim Ferriss",
    "\"Success is no accident. It is hard work, perseverance, learning, studying, sacrifice.\"\n– Pelé",
    "\"Believe you can and you're halfway there.\"\n– Theodore Roosevelt",
    "\"Work hard in silence, let your success be your noise.\"\n– Frank Ocean",
    "\"The only place where success comes before work is in the dictionary.\"\n– Vidal Sassoon",
    "\"You don't have to be great to start, but you have to start to be great.\"\n– Zig Ziglar",
  ];

  @override
  void initState() {
    super.initState();
    _selectRandomQuote();
  }

  void _selectRandomQuote() {
    final isBengali = LanguageManager().isBengali;
    final filtered = _quotes.where((q) {
      final hasBengali = q.contains(RegExp(r'[\u0980-\u09FF]'));
      return isBengali ? hasBengali : !hasBengali;
    }).toList();

    if (filtered.isEmpty) {
      setState(() {
        _randomQuote = _quotes.first;
      });
      return;
    }

    final random = Random();
    final index = random.nextInt(filtered.length);
    setState(() {
      _randomQuote = filtered[index];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Focus Mode On'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 60),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 800), // ফেড-ইন অ্যানিমেশন কোটের জন্য
                  child: Text(
                    _randomQuote,
                    key: ValueKey<String>(_randomQuote),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          height: 1.6, 
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 80),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => const DashboardScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      transitionDuration: const Duration(milliseconds: 600),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue to Home'.tr(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}