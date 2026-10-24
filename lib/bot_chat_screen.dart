import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_service.dart';

class BotChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String mode; // 'ai', 'cmd', 'quiz', 'system'
  final Map<String, dynamic>? quizData;
  int? selectedOption;
  bool isAnswered;

  BotChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.mode = 'system',
    this.quizData,
    this.selectedOption,
    this.isAnswered = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'mode': mode,
    'quizData': quizData,
    'selectedOption': selectedOption,
    'isAnswered': isAnswered,
  };

  factory BotChatMessage.fromJson(Map<String, dynamic> json) => BotChatMessage(
    id: json['id'] ?? UniqueKey().toString(),
    text: json['text'] ?? '',
    isUser: json['isUser'] ?? false,
    timestamp: json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
        : DateTime.now(),
    mode: json['mode'] ?? 'system',
    quizData: json['quizData'] != null ? Map<String, dynamic>.from(json['quizData']) : null,
    selectedOption: json['selectedOption'],
    isAnswered: json['isAnswered'] ?? false,
  );
}

class BotChatScreen extends StatefulWidget {
  const BotChatScreen({super.key});

  @override
  State<BotChatScreen> createState() => _BotChatScreenState();
}

class _BotChatScreenState extends State<BotChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<BotChatMessage> _messages = [];
  bool _isTyping = false;
  String? _geminiApiKey;

  // Local Offline Quiz Bank
  final List<Map<String, dynamic>> _localQuizBank = [
    {
      'question': '‘আমার ভাইয়ের রক্তে রাঙানো একুশে ফেব্রুয়ারি’ গানটির রচয়িতা কে?',
      'options': ['আব্দুল গাফফার চৌধুরী', 'আলতাফ মাহমুদ', 'শামসুর রাহমান', 'কাজী নজরুল ইসলাম'],
      'answer': 0,
      'explanation': 'আব্দুল গাফফার চৌধুরী ১৯৫২ সালে এই কালজয়ী গানটি রচনা করেন এবং আলতাফ মাহমুদ পরবর্তীতে এতে সুরারোপ করেন।'
    },
    {
      'question': 'বাংলাদেশের জাতীয় সংবিধান কোন তারিখে কার্যকর হয়?',
      'options': ['১৬ ডিসেম্বর ১৯৭২', '৪ নভেম্বর ১৯৭২', '২৬ মার্চ ১৯৭২', '১০ জানুয়ারি ১৯৭২'],
      'answer': 0,
      'explanation': '৪ নভেম্বর ১৯৭২ সংবিধান গৃহীত হয় এবং ১৬ ডিসেম্বর ১৯৭২ বিজয় দিবসে তা কার্যকর হয়।'
    },
    {
      'question': 'Which one is the correct spelling?',
      'options': ['Lieutenant', 'Leutenant', 'Lieutennant', 'Leutennent'],
      'answer': 0,
      'explanation': 'সঠিক বানান: Lieutenant (Lie-u-ten-ant)।'
    },
    {
      'question': 'কোন রঙের আলোর তরঙ্গদৈর্ঘ্য সবচেয়ে বেশি?',
      'options': ['লাল', 'বেগুনী', 'নীল', 'হলুদ'],
      'answer': 0,
      'explanation': 'লাল আলোর তরঙ্গদৈর্ঘ্য সবচেয়ে বেশি (প্রায় ৭০০ ন্যানোমিটার) এবং বেগুনী আলোর সবচেয়ে কম।'
    },
    {
      'question': 'পদ্মা সেতু আনুষ্ঠানিকভাবে কবে উদ্বোধন করা হয়?',
      'options': ['২৫ জুন ২০২২', '২৩ জুন ২০২২', '১ জুলাই ২০২২', '২৬ মার্চ ২০২২'],
      'answer': 0,
      'explanation': '২৫ জুন ২০২২ পদ্মা সেতু যানবাহন চলাচলের জন্য প্রধানমন্ত্রী শেখ হাসিনা উদ্বোধন করেন।'
    },
    {
      'question': 'What is the synonym of "Candid"?',
      'options': ['Frank / Honest', 'Secretive', 'Deceptive', 'Shy'],
      'answer': 0,
      'explanation': 'Candid অর্থ অকপট, সরল বা স্পষ্টবাদী (Frank, Honest)।'
    },
    {
      'question': '১ থেকে ৫০ পর্যন্ত মৌলিক সংখ্যা কয়টি?',
      'options': ['১৫টি', '১০টি', '২৫টি', '১২টি'],
      'answer': 0,
      'explanation': '১ থেকে ৫০ পর্যন্ত মৌলিক সংখ্যা ১৫টি এবং ১ থেকে ১০০ পর্যন্ত মোট ২৫টি।'
    },
  ];

  // Local Motivational Quotes
  final List<String> _motivationalQuotes = [
    '“পরিশ্রম কখনো বৃথা যায় না। তুমি যদি প্রতিদিন একটু একটু করে এগিয়ে যাও, সফলতা একদিন তোমার দরজায় কড়া নাড়বেই।”',
    '“আজকের ত্যাগ ও ক্লান্তি তোমার আগামীকালের উজ্জ্বল ভবিষ্যতের ভিত্তি তৈরি করছে।”',
    '“সফলতার কোনো গোপন সূত্র নেই; এটি কেবল প্রস্তুতি, কঠোর পরিশ্রম এবং ব্যর্থতা থেকে শেখার ফলাফল।” - কলিন পাওয়েল',
    '“পড়াশোনায় মন বসছে না? একবার ভাবো কেন তুমি এই লক্ষ্যটি বেছে নিয়েছিলে এবং তোমার স্বপ্ন কত বড়।”',
    '“ছোট ছোট দৈনন্দিন অভ্যাসই একদিন বড় জয়ে রূপান্তরিত হয়। আজকের কাজ কালকের জন্য ফেলে রেখো না।”',
    '“The expert in anything was once a beginner. Keep learning, keep pushing!”',
  ];

  @override
  void initState() {
    super.initState();
    _loadApiKeyAndHistory();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKeyAndHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    // Load API Key
    String? key = prefs.getString('user_gemini_api_key');
    if (key == null && user != null) {
      key = await AIService.getSavedApiKey(user.uid);
      if (key != null && key.isNotEmpty) {
        await prefs.setString('user_gemini_api_key', key);
      }
    }

    // Load Chat History
    final savedChatsJson = prefs.getString('bot_chat_history');
    List<BotChatMessage> loadedMessages = [];
    if (savedChatsJson != null && savedChatsJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(savedChatsJson);
        loadedMessages = decoded.map((e) => BotChatMessage.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Error parsing saved bot chats: $e');
      }
    }

    if (loadedMessages.isEmpty) {
      loadedMessages.add(
        BotChatMessage(
          id: 'welcome_1',
          text: '👋 **স্বাগতম! আমি StudyMate Hybrid Assistant!**\n\n'
              'আমি আপনার পড়াশোনা, কুইজ এবং রুটিনের সার্বক্ষণিক সঙ্গী।\n\n'
              '⚡ **আমার দুটি মোড আছে:**\n'
              '১. **অফলাইন মোড:** কোনো ইন্টারনেট বা এআই ছাড়াই কুইজ, অনুপ্রেরণা এবং রুটিন দেখতে পারেন।\n'
              '২. **স্মার্ট এআই মোড:** যেকোনো পড়াশোনার জটিল প্রশ্নের বিস্তারিত ব্যাখ্যা পেতে পারেন (Gemini AI দিয়ে)।\n\n'
              '💡 নিচে দেয়া বাটনগুলো চাপুন অথবা `/help` টাইপ করুন।',
          isUser: false,
          timestamp: DateTime.now(),
          mode: 'system',
        ),
      );
    }

    if (mounted) {
      setState(() {
        _geminiApiKey = key;
        _messages.clear();
        _messages.addAll(loadedMessages);
      });
      _scrollToBottom();
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    // Keep last 40 messages to prevent excessive memory usage
    final toSave = _messages.length > 40 ? _messages.sublist(_messages.length - 40) : _messages;
    final encoded = jsonEncode(toSave.map((e) => e.toJson()).toList());
    await prefs.setString('bot_chat_history', encoded);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSubmitted(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _inputController.clear();
    final userMsg = BotChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
      mode: 'user',
    );

    setState(() {
      _messages.add(userMsg);
    });
    _saveChatHistory();
    _scrollToBottom();

    // Process Bot Response
    _processMessage(trimmed);
  }

  Future<void> _processMessage(String input) async {
    final lower = input.toLowerCase().trim();

    // 1. Check Offline Commands
    if (lower.startsWith('/')) {
      _handleCommand(lower, input);
      return;
    }

    // Direct keywords without slash
    if (lower == 'quiz' || lower == 'কুইজ') {
      _sendQuizQuestion();
      return;
    }
    if (lower == 'motivate' || lower == 'অনুপ্রেরণা' || lower == 'উক্তি') {
      _sendMotivation();
      return;
    }
    if (lower == 'routine' || lower == 'রুটিন' || lower == 'আজকের পড়া') {
      _sendTodayRoutine();
      return;
    }
    if (lower == 'help' || lower == 'সাহায্য') {
      _sendHelpMenu();
      return;
    }

    // 2. Fallback to Gemini AI if available
    if (_geminiApiKey != null && _geminiApiKey!.trim().isNotEmpty) {
      await _callGeminiAI(input);
    } else {
      // Offline fallback explanation with direct call-to-action
      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '🤖 **অফলাইন মোড সক্রিয় রয়েছে!**\n\n'
                'আপনার ডিভাইসে সরাসরি AI সক্রিয় নেই বা কোনো Gemini API Key যুক্ত করা নেই।\n\n'
                '📌 **আপনি অফলাইনে যেসব চালাতে পারবেন:**\n'
                '• `/quiz` — বিসিএস ও সাধারণ জ্ঞান কুইজ\n'
                '• `/motivate` — পড়াশোনার অনুপ্রেরণামূলক উক্তি\n'
                '• `/routine` — আপনার আজকের পড়ার তালিকা\n'
                '• `/calc 25*4` — দ্রুত হিসাব ক্যালকুলেটর\n'
                '• `/help` — সকল কমান্ডের তালিকা\n\n'
                '✨ যেকোনো প্রশ্নের বিস্তারিত উত্তর পাওয়ার জন্য উপরের **🔑 কী আইকনে** ক্লিক করে বিনামূল্যে Gemini API Key সেট করে নিন।',
            isUser: false,
            timestamp: DateTime.now(),
            mode: 'cmd',
          ),
        );
      });
      _saveChatHistory();
      _scrollToBottom();
    }
  }

  void _handleCommand(String lowerCmd, String originalInput) {
    if (lowerCmd == '/start' || lowerCmd == '/help') {
      _sendHelpMenu();
    } else if (lowerCmd.startsWith('/quiz')) {
      _sendQuizQuestion();
    } else if (lowerCmd.startsWith('/motivate') || lowerCmd == '/quote') {
      _sendMotivation();
    } else if (lowerCmd.startsWith('/routine') || lowerCmd == '/tasks') {
      _sendTodayRoutine();
    } else if (lowerCmd.startsWith('/tasbeeh')) {
      _sendTasbeeh();
    } else if (lowerCmd.startsWith('/calc')) {
      _handleCalculator(originalInput);
    } else if (lowerCmd == '/clear') {
      _clearChat();
    } else if (lowerCmd == '/status') {
      _sendStatus();
    } else {
      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '❓ **অজানা কমান্ড:** `$lowerCmd`\n\nসব কমান্ড দেখতে `/help` টাইপ করুন অথবা নিচের সাজেস্টেড বাটনগুলো ব্যবহার করুন।',
            isUser: false,
            timestamp: DateTime.now(),
            mode: 'cmd',
          ),
        );
      });
      _saveChatHistory();
      _scrollToBottom();
    }
  }

  void _sendHelpMenu() {
    setState(() {
      _messages.add(
        BotChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: '📋 **StudyMate Bot কমান্ড তালিকা:**\n\n'
              '🎯 `/quiz` — বিসিএস, সাধারণ জ্ঞান ও ইংরেজির লাইভ কুইজ\n'
              '💡 `/motivate` — পড়ার মন বসানোর অনুপ্রেরণামূলক উক্তি\n'
              '📅 `/routine` — আজকের রুটিন ও টাস্ক লিস্ট\n'
              '📿 `/tasbeeh` — দ্রুত তাসবীহ ও যিকির স্মরণিকা\n'
              '🧮 `/calc [হিসাব]` — যেমন: `/calc 150 / 3`\n'
              '⚡ `/status` — এআই ও অফলাইন সংযোগের স্থিতি\n'
              '🧹 `/clear` — মেসেজ হিস্ট্রি পরিষ্কার করা\n\n'
              '💡 এছাড়া ফ্রি Gemini API কী দিয়ে যেকোনো একাডেমিক প্রশ্ন জিজ্ঞেস করতে পারেন!',
          isUser: false,
          timestamp: DateTime.now(),
          mode: 'cmd',
        ),
      );
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  void _sendQuizQuestion() {
    final random = Random();
    final quiz = _localQuizBank[random.nextInt(_localQuizBank.length)];

    setState(() {
      _messages.add(
        BotChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: '🎯 **কুইজ প্রশ্ন:**\n\n${quiz['question']}',
          isUser: false,
          timestamp: DateTime.now(),
          mode: 'quiz',
          quizData: quiz,
        ),
      );
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  void _answerQuiz(BotChatMessage message, int selectedIdx) {
    if (message.isAnswered || message.quizData == null) return;

    final correctIdx = message.quizData!['answer'] as int;
    final isCorrect = selectedIdx == correctIdx;
    final explanation = message.quizData!['explanation'] ?? '';

    setState(() {
      message.selectedOption = selectedIdx;
      message.isAnswered = true;

      _messages.add(
        BotChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: isCorrect
              ? '🎉 **চমৎকার! আপনার উত্তরটি সঠিক হয়েছে!**\n\n💡 $explanation'
              : '❌ **ভুল উত্তর!**\n\nসঠিক উত্তর ছিল: **${message.quizData!['options'][correctIdx]}**\n\n💡 $explanation',
          isUser: false,
          timestamp: DateTime.now(),
          mode: 'quiz',
        ),
      );
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  void _sendMotivation() {
    final random = Random();
    final quote = _motivationalQuotes[random.nextInt(_motivationalQuotes.length)];
    setState(() {
      _messages.add(
        BotChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: '💡 **আজকের অনুপ্রেরণা:**\n\n$quote',
          isUser: false,
          timestamp: DateTime.now(),
          mode: 'cmd',
        ),
      );
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  Future<void> _sendTodayRoutine() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '⚠️ রুটিন দেখতে আপনাকে লগইন করা থাকতে হবে।',
            isUser: false,
            timestamp: DateTime.now(),
            mode: 'cmd',
          ),
        );
      });
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .limit(10)
          .get();

      if (snap.docs.isEmpty) {
        setState(() {
          _messages.add(
            BotChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: '📅 **আজকের রুটিন:**\n\nআপনার কোনো পেন্ডিং টাস্ক পাওয়া যায়নি। চমৎকার!',
              isUser: false,
              timestamp: DateTime.now(),
              mode: 'cmd',
            ),
          );
        });
      } else {
        final buffer = StringBuffer('📅 **আপনার পড়ার রুটিন ও টাস্কসমূহ:**\n\n');
        int count = 1;
        for (var doc in snap.docs) {
          final data = doc.data();
          final title = data['title'] ?? data['taskName'] ?? 'Unnamed Task';
          final isCompleted = data['isCompleted'] ?? false;
          buffer.writeln('$count. ${isCompleted ? "✅" : "⏳"} **$title**');
          count++;
        }
        setState(() {
          _messages.add(
            BotChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: buffer.toString(),
              isUser: false,
              timestamp: DateTime.now(),
              mode: 'cmd',
            ),
          );
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '⚠️ রুটিন লোড করতে অফলাইন বা নেটওয়ার্ক সমস্যা হয়েছে। আপনার ইন্টারনেট চেক করুন।',
            isUser: false,
            timestamp: DateTime.now(),
            mode: 'cmd',
          ),
        );
      });
    }
    _saveChatHistory();
    _scrollToBottom();
  }

  void _sendTasbeeh() {
    setState(() {
      _messages.add(
        BotChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: '📿 **দৈনিক সংক্ষিপ্ত যিকির স্মরণিকা:**\n\n'
              '• সুবহানাল্লাহ (৩৩ বার) — আল্লাহ অতি পবিত্র\n'
              '• আলহামদুলিল্লাহ (৩৩ বার) — সকল প্রশংসা আল্লাহর\n'
              '• আল্লাহু আকবার (৩৪ বার) — আল্লাহ মহান\n'
              '• লা ইলাহা ইল্লাল্লাহু ওয়াহদাহু লা শারীকা লাহু...\n\n'
              '*(পূর্ণাঙ্গ কাউন্টারের জন্য অ্যাপের তাসবীহ স্ক্রিন ব্যবহার করুন)*',
          isUser: false,
          timestamp: DateTime.now(),
          mode: 'cmd',
        ),
      );
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  void _handleCalculator(String input) {
    final expr = input.replaceFirst(RegExp(r'/calc\s*', caseSensitive: false), '').trim();
    if (expr.isEmpty) {
      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '🧮 **ব্যবহার পদ্ধতি:** `/calc ৫ + ১০` অথবা `/calc 120 / 60`',
            isUser: false,
            timestamp: DateTime.now(),
            mode: 'cmd',
          ),
        );
      });
      return;
    }

    try {
      // Simple parser for basic math (+, -, *, /)
      String clean = expr.replaceAll(' ', '');
      double? result;
      if (clean.contains('+')) {
        final p = clean.split('+');
        result = double.parse(p[0]) + double.parse(p[1]);
      } else if (clean.contains('-')) {
        final p = clean.split('-');
        result = double.parse(p[0]) - double.parse(p[1]);
      } else if (clean.contains('*')) {
        final p = clean.split('*');
        result = double.parse(p[0]) * double.parse(p[1]);
      } else if (clean.contains('/')) {
        final p = clean.split('/');
        final denom = double.parse(p[1]);
        if (denom == 0) throw Exception('Division by zero');
        result = double.parse(p[0]) / denom;
      }

      if (result != null) {
        final formattedResult = result % 1 == 0 ? result.toInt().toString() : result.toStringAsFixed(2);
        setState(() {
          _messages.add(
            BotChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: '🧮 **হিসাব:** `$expr` = **$formattedResult**',
              isUser: false,
              timestamp: DateTime.now(),
              mode: 'cmd',
            ),
          );
        });
      } else {
        throw Exception('Unsupported operator');
      }
    } catch (e) {
      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '⚠️ হিসাবটি সমাধান করা যায়নি। উদাহরণ: `/calc 120 / 4`',
            isUser: false,
            timestamp: DateTime.now(),
            mode: 'cmd',
          ),
        );
      });
    }
    _saveChatHistory();
    _scrollToBottom();
  }

  void _sendStatus() {
    final hasAi = _geminiApiKey != null && _geminiApiKey!.trim().isNotEmpty;
    setState(() {
      _messages.add(
        BotChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: '⚡ **StudyMate Bot স্ট্যাটাস রিপোর্ট:**\n\n'
              '• **অফলাইন ইঞ্জিন:** 🟢 সক্রিয় (কুইজ, রুটিন, মোটিভেশন প্রস্তুত)\n'
              '• **জেমিনি এআই:** ${hasAi ? "🟢 সক্রিয় (স্মার্ট চ্যাট প্রস্তুত)" : "🟡 নিষ্ক্রিয় (API Key প্রয়োজন)"}\n'
              '• **স্থানীয় মেমরি:** ${_messages.length} টি মেসেজ সংরক্ষিত রয়েছে\n\n'
              '💡 এআই সক্রিয় করতে ওপরের কি (🔑) আইকন ব্যবহার করুন।',
          isUser: false,
          timestamp: DateTime.now(),
          mode: 'system',
        ),
      );
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('চ্যাট হিস্ট্রি মুছবেন?'),
        content: const Text('বটের সাথে হওয়া সকল মেসেজ হিস্ট্রি মুছে ফেলা হবে।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('না')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('bot_chat_history');
              setState(() {
                _messages.clear();
                _messages.add(
                  BotChatMessage(
                    id: 'cleared_1',
                    text: '🧹 চ্যাট হিস্ট্রি সম্পূর্ণ খালি করা হয়েছে। নতুন করে প্রশ্ন করুন বা `/help` লিখুন।',
                    isUser: false,
                    timestamp: DateTime.now(),
                    mode: 'system',
                  ),
                );
              });
            },
            child: const Text('মুছে ফেলুন', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _callGeminiAI(String prompt) async {
    setState(() {
      _isTyping = true;
    });
    _scrollToBottom();

    String reply = '';
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _geminiApiKey!,
        systemInstruction: Content.system(
          'You are StudyMate Assistant, an expert, friendly and encouraging study companion for Bangladeshi students preparing for competitive exams (BCS, Bank, University Admission, Board Exams). Provide structured, accurate, beautifully formatted answers with bullet points, examples, and Bengali/English as requested. Keep it concise, motivational and focused.',
        ),
      );

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      reply = response.text ?? 'দুঃখিত, কোনো উত্তর পাওয়া যায়নি।';
    } catch (e) {
      debugPrint('Gemini 1.5 flash failed, trying gemini-pro: $e');
      try {
        final model = GenerativeModel(
          model: 'gemini-pro',
          apiKey: _geminiApiKey!,
        );
        final response = await model.generateContent([Content.text(prompt)]);
        reply = response.text ?? 'দুঃখিত, কোনো উত্তর পাওয়া যায়নি।';
      } catch (e2) {
        reply = '⚠️ **এআই সংযোগে সমস্যা হয়েছে:** $e2\n\nআপনি চাইলে অফলাইন কমান্ডগুলো (যেমন: `/quiz`, `/motivate`) ব্যবহার করতে পারেন।';
      }
    }

    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: reply,
            isUser: false,
            timestamp: DateTime.now(),
            mode: 'ai',
          ),
        );
      });
      _saveChatHistory();
      _scrollToBottom();
    }
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController(text: _geminiApiKey ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.vpn_key_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Gemini API Key'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'স্মার্ট এআই চ্যাট সক্রিয় করার জন্য আপনার ফ্রি Gemini API কী দিন:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'AIzaSy...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '🔑 আপনি aistudio.google.com থেকে বিনামূল্যে API কী পেতে পারেন। এটি আপনার ফোনে নিরাপদে সংরক্ষিত থাকবে।',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newKey = controller.text.trim();
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final prefs = await SharedPreferences.getInstance();
              if (newKey.isEmpty) {
                await prefs.remove('user_gemini_api_key');
              } else {
                await prefs.setString('user_gemini_api_key', newKey);
              }
              final user = FirebaseAuth.instance.currentUser;
              if (user != null && newKey.isNotEmpty) {
                await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                  'geminiApiKey': newKey,
                }, SetOptions(merge: true));
              }
              if (mounted) {
                setState(() {
                  _geminiApiKey = newKey.isEmpty ? null : newKey;
                });
              }
              nav.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(newKey.isEmpty ? 'API Key সরানো হয়েছে' : '✅ Gemini API Key সফলভাবে সংরক্ষিত হয়েছে!'),
                  backgroundColor: Colors.teal,
                ),
              );
            },
            child: const Text('সংরক্ষণ করুন'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAi = _geminiApiKey != null && _geminiApiKey!.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: const Icon(Icons.smart_toy_rounded, color: Colors.teal),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: hasAi ? Colors.green : Colors.amber,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('StudyMate Bot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('BOT', style: TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Text(
                  hasAi ? '🟢 AI + অফলাইন সক্রিয়' : '🟡 অফলাইন প্রস্তুত (হাইব্রিড)',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Gemini API Key',
            icon: Icon(
              hasAi ? Icons.vpn_key_rounded : Icons.vpn_key_outlined,
              color: hasAi ? Colors.amber : null,
            ),
            onPressed: _showApiKeyDialog,
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'clear') _clearChat();
              if (val == 'status') _sendStatus();
              if (val == 'help') _sendHelpMenu();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'help', child: Text('কমান্ড তালিকা (/help)')),
              const PopupMenuItem(value: 'status', child: Text('সংযোগ স্ট্যাটাস (/status)')),
              const PopupMenuItem(value: 'clear', child: Text('চ্যাট মুছুন (/clear)')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Message List
            Expanded(
              child: _messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return _buildMessageBubble(msg);
                      },
                    ),
            ),

            // Typing Indicator
            if (_isTyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.smart_toy_rounded, size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('বট লিখছে...', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Suggestion Chips (Telegram style quick command buttons)
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _buildQuickChip('🎯 কুইজ', () => _sendQuizQuestion()),
                  _buildQuickChip('💡 মোটিভেশন', () => _sendMotivation()),
                  _buildQuickChip('📅 পড়ার রুটিন', () => _sendTodayRoutine()),
                  _buildQuickChip('📿 তাসবীহ', () => _sendTasbeeh()),
                  _buildQuickChip('❓ সাহায্য', () => _sendHelpMenu()),
                ],
              ),
            ),

            const Divider(height: 1),

            // Text Input Field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: theme.colorScheme.surface,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.bolt_rounded, color: Colors.teal),
                    tooltip: 'কুইজ খেলুন',
                    onPressed: _sendQuizQuestion,
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _inputController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _handleSubmitted,
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: 'মেসেজ বা কমান্ড লিখুন (/help)...',
                          hintStyle: TextStyle(fontSize: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: () => _handleSubmitted(_inputController.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        onPressed: onTap,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
        side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildMessageBubble(BotChatMessage msg) {
    final theme = Theme.of(context);
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.teal.shade700,
              child: const Icon(Icons.smart_toy_rounded, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceVariant.withOpacity(0.7),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mode indicator badge for bot
                  if (!isUser && msg.mode != 'system')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        msg.mode == 'ai' ? '🤖 Gemini AI' : '⚡ অফলাইন ইঞ্জিন',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: msg.mode == 'ai' ? Colors.deepPurple : Colors.teal,
                        ),
                      ),
                    ),

                  // Message Text with Markdown support
                  MarkdownBody(
                    data: msg.text,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: isUser ? Colors.white : theme.colorScheme.onSurface,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      strong: TextStyle(
                        color: isUser ? Colors.white : theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      code: TextStyle(
                        backgroundColor: isUser ? Colors.black26 : Colors.black12,
                        color: isUser ? Colors.amberAccent : Colors.teal.shade800,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),

                  // Interactive Quiz Card Options
                  if (msg.quizData != null && !msg.isAnswered) ...[
                    const SizedBox(height: 10),
                    ...List.generate(
                      (msg.quizData!['options'] as List).length,
                      (idx) {
                        final optionText = msg.quizData!['options'][idx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            onTap: () => _answerQuiz(msg, idx),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withOpacity(0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                                    child: Text(
                                      String.fromCharCode(65 + idx), // A, B, C, D
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      optionText,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  // Timestamp
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isUser ? Colors.white70 : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
