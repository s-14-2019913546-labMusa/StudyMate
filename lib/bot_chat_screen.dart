import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class BotChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String mode; // 'cmd', 'quiz', 'system', 'study_info'
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
    {
      'question': 'চর্যাপদ কোন ছন্দে রচিত?',
      'options': ['মাত্রাবৃত্ত', 'অক্ষরবৃত্ত', 'মাত্রামুক্তক', 'পয়ার'],
      'answer': 0,
      'explanation': 'বাংলা সাহিত্যের প্রাচীনতম নিদর্শন চর্যাপদ মাত্রাবৃত্ত ছন্দে রচিত।'
    },
    {
      'question': 'রক্তে হিমোগ্লোবিনের প্রধান কাজ কী?',
      'options': ['অক্সিজেন পরিবহন করা', 'রোগ প্রতিরোধ করা', 'রক্ত জমাট বাঁধতে সাহায্য করা', 'শক্তি উৎপাদন করা'],
      'answer': 0,
      'explanation': 'লোহিত রক্তকণিকার হিমোগ্লোবিন ফুসফুস থেকে সারা দেহে অক্সিজেন (O2) পরিবহন করে।'
    },
    {
      'question': 'মুক্তিযুদ্ধে বাংলাদেশকে কয়টি সেক্টরে ভাগ করা হয়েছিল?',
      'options': ['১১টি সেক্টর', '৮টি সেক্টর', '১২টি সেক্টর', '১০টি সেক্টর'],
      'answer': 0,
      'explanation': '১৯৭১ সালের মহান মুক্তিযুদ্ধে সমগ্র বাংলাদেশকে ১১টি সেক্টর এবং ৬৪টি সাব-সেক্টরে বিভক্ত করা হয়।'
    },
    {
      'question': 'ঐতিহাসিক ৬ দফা দাবি বঙ্গবন্ধু শেখ মুজিবুর রহমান কত সালে এবং কোথায় পেশ করেন?',
      'options': ['১৯৬৬ সালে, লাহোরে', '১৯৬৯ সালে, ঢাকায়', '১৯৭১ সালে, রেসকোর্স ময়দানে', '১৯৫৪ সালে, করাচিতে'],
      'answer': 0,
      'explanation': '১৯৬৬ সালের ৫-৬ ফেব্রুয়ারি পাকিস্তানের লাহোরে অনুষ্ঠিত সর্বদলীয় বিরোধী রাজনৈতিক সম্মেলনে বঙ্গবন্ধু ৬ দফা পেশ করেন।'
    },
    {
      'question': 'Who is the author of "Hamlet" and "Macbeth"?',
      'options': ['William Shakespeare', 'John Milton', 'William Wordsworth', 'George Bernard Shaw'],
      'answer': 0,
      'explanation': 'William Shakespeare (1564-1616) রচিত এই দুটি বিখ্যাত ট্র্যাজেডি।'
    },
    {
      'question': 'কম্পিউটারের স্থায়ী মেমোরি (Non-volatile memory) কোনটি?',
      'options': ['ROM', 'RAM', 'Cache', 'Virtual Memory'],
      'answer': 0,
      'explanation': 'ROM (Read Only Memory) হলো স্থায়ী মেমোরি, বিদ্যুৎ চলে গেলেও এর সংরক্ষিত তথ্য মুছে যায় না।'
    },
    {
      'question': 'মুজিবনগর সরকার আনুষ্ঠানিকভাবে কবে শপথ গ্রহণ করে?',
      'options': ['১৭ এপ্রিল ১৯৭১', '১০ এপ্রিল ১৯৭১', '২৬ মার্চ ১৯৭১', '২৫ মার্চ ১৯৭১'],
      'answer': 0,
      'explanation': '১০ এপ্রিল ১৯৭১ মুজিবনগর সরকার গঠিত হয় এবং ১৭ এপ্রিল মেহেরপুরের বৈদ্যনাথতলায় (মুজিবনগর) শপথ গ্রহণ করে।'
    },
    {
      'question': 'A person who knows many languages is called a —',
      'options': ['Polyglot', 'Linguist', 'Grammarian', 'Philologist'],
      'answer': 0,
      'explanation': 'Polyglot অর্থ বহুভাষাবিদ (যিনি একাধিক ভাষা জানেন বা অনর্গল বলতে পারেন)।'
    },
    {
      'question': '১০ থেকে ৬০ পর্যন্ত যে সকল মৌলিক সংখ্যার একক স্থানীয় অংক ৯, তাদের সমষ্টি কত?',
      'options': ['১০৭', '১২৬', '১০৫', '৯৯'],
      'answer': 0,
      'explanation': '১০ থেকে ৬০ পর্যন্ত ৯ দিয়ে শেষ হওয়া মৌলিক সংখ্যা হলো: ১৯, ২৯, ৫৯ (৩৯ মৌলিক নয় কারণ ৩৯ = ৩ × ১৩)। সমষ্টি = ১৯ + ২৯ + ৫৯ = ১০৭।'
    },
    {
      'question': 'আন্তর্জাতিক মাতৃভাষা দিবস হিসেবে ২১শে ফেব্রুয়ারিকে ইউনেস্কো কবে স্বীকৃতি দেয়?',
      'options': ['১৭ নভেম্বর ১৯৯৯', '২১ ফেব্রুয়ারি ২০০০', '২৬ মার্চ ১৯৯৯', '১৬ ডিসেম্বর ১৯৯৯'],
      'answer': 0,
      'explanation': '১৭ নভেম্বর ১৯৯৯ প্যারিসে ইউনেস্কোর ৩০তম সাধারণ অধিবেশনে ২১শে ফেব্রুয়ারিকে আন্তর্জাতিক মাতৃভাষা দিবস হিসেবে ঘোষণা করা হয়।'
    },
    {
      'question': '‘ভানুসিংহ ঠাকুর’ কার ছদ্মনাম?',
      'options': ['রবীন্দ্রনাথ ঠাকুর', 'কাজী নজরুল ইসলাম', 'বঙ্কিমচন্দ্র চট্টোপাধ্যায়', 'শরৎচন্দ্র চট্টোপাধ্যায়'],
      'answer': 0,
      'explanation': '‘ভানুসিংহ ঠাকুর’ ছিল রবীন্দ্রনাথ ঠাকুরের বিখ্যাত ছদ্মনাম, যার অধীনে তিনি "ভানুসিংহ ঠাকুরের পদাবলী" রচনা করেন।'
    },
  ];

  // Local Vocabulary Bank for BCS & Bank Aspirants
  final List<Map<String, dynamic>> _vocabList = [
    {
      'word': 'Ephemeral',
      'phonetic': '/ɪˈfem.ər.əl/',
      'pos': 'Adjective',
      'meaning': 'ক্ষণস্থায়ী, ক্ষণভঙ্গুর, স্বল্পস্থায়ী',
      'synonyms': 'Transient, Fleeting, Momentary, Short-lived',
      'antonyms': 'Permanent, Eternal, Everlasting',
      'example': 'Fame in the digital world is often ephemeral.',
    },
    {
      'word': 'Pragmatic',
      'phonetic': '/præɡˈmæt.ɪk/',
      'pos': 'Adjective',
      'meaning': 'বাস্তবসম্মত, বাস্তবধর্মী, বাস্তববাদী',
      'synonyms': 'Practical, Realistic, Sensible',
      'antonyms': 'Idealistic, Impractical, Theoretical',
      'example': 'We need a pragmatic approach to achieve our study routine goals.',
    },
    {
      'word': 'Meticulous',
      'phonetic': '/məˈtɪk.jə.ləs/',
      'pos': 'Adjective',
      'meaning': 'খুঁতখুঁতে, অত্যন্ত সতর্ক ও নিখুঁত',
      'synonyms': 'Painstaking, Scrupulous, Diligent, Precise',
      'antonyms': 'Careless, Sloppy, Negligent',
      'example': 'He was meticulous about keeping his daily study and revision records.',
    },
    {
      'word': 'Resilient',
      'phonetic': '/rɪˈzɪl.jənt/',
      'pos': 'Adjective',
      'meaning': 'প্রতিকূলতা কাটিয়ে ওঠার মতো শক্তিধর, সহনশীল',
      'synonyms': 'Tough, Hardy, Adaptable, Buoyant',
      'antonyms': 'Fragile, Vulnerable, Weak',
      'example': 'A successful candidate must be resilient in the face of exam challenges.',
    },
    {
      'word': 'Eloquent',
      'phonetic': '/ˈel.ə.kwənt/',
      'pos': 'Adjective',
      'meaning': 'মিষ্টভাষী, বাকপটু, চিত্তাকর্ষক কথাবলা',
      'synonyms': 'Fluent, Expressive, Articulate, Persuasive',
      'antonyms': 'Inarticulate, Hesitant, Dull',
      'example': 'His eloquent answer impressed the interview viva board.',
    },
    {
      'word': 'Ambiguous',
      'phonetic': '/æmˈbɪɡ.ju.əs/',
      'pos': 'Adjective',
      'meaning': 'দ্ব্যর্থবোধক, অস্পষ্ট, একাধিক অর্থ হতে পারে এমন',
      'synonyms': 'Equivocal, Obscure, Vague, Unclear',
      'antonyms': 'Clear, Explicit, Lucid, Unambiguous',
      'example': 'The law was phrased in an ambiguous manner.',
    },
    {
      'word': 'Benevolent',
      'phonetic': '/bəˈnev.əl.ənt/',
      'pos': 'Adjective',
      'meaning': 'দয়ালু, পরোপকারী, কল্যাণকামী',
      'synonyms': 'Kind, Altruistic, Charitable, Generous',
      'antonyms': 'Malevolent, Spiteful, Cruel',
      'example': 'A benevolent teacher always guides students with boundless patience.',
    },
    {
      'word': 'Diligent',
      'phonetic': '/ˈdɪl.ɪ.dʒənt/',
      'pos': 'Adjective',
      'meaning': 'পরিশ্রমী, অধ্যবসায়ী',
      'synonyms': 'Hardworking, Industrious, Assiduous',
      'antonyms': 'Lazy, Idle, Lethargic',
      'example': 'Diligent candidates achieve outstanding results in competitive exams.',
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
    '“হার মেনে নেওয়া সবচেয়ে সহজ কাজ, কিন্তু চেষ্টা চালিয়ে যাওয়াই বিজয়ীদের আসল বৈশিষ্ট্য।”',
    '“প্রতিদিন অন্তত ১% হলেও নিজেকে গতকালের চেয়ে উন্নত করো; এক বছরে তুমি ৩৭ গুণ এগিয়ে যাবে।”',
  ];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
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
          text: '👋 **স্বাগতম! আমি StudyMate Smart Study Bot!**\n\n'
              'আমি আপনার পড়াশোনা, রুটিন বিশ্লেষণ এবং কুইজের সার্বক্ষণিক সহচর। কোনো ইন্টারনেট বা এপিআই কী ছাড়াই আমি শতভাগ কাজ করি।\n\n'
              '📌 **আমি যা যা করতে পারি:**\n'
              '• 📅 **আজকের রুটিন বিশ্লেষণ:** আপনার অ্যাপের পড়া ট্র্যাক ও বিশ্লেষণ\n'
              '• 🎯 **লাইভ কুইজ:** বিসিএস, ইংরেজি ও সাধারণ জ্ঞান কুইজ\n'
              '• 📖 **পড়ার তথ্য ও টিপস:** বাংলা সাহিত্য, ব্যাকরণ, ইংরেজি রুলস, গণিত সূত্র ও সাধারণ জ্ঞান\n'
              '• 💡 **মনোযোগ ও মোটিভেশন:** পড়ার মন বসানোর উপায় ও উক্তি\n\n'
              '💡 নিচে দেওয়া সাজেস্টেড বাটনগুলোতে চাপুন অথবা আপনার প্রশ্ন লিখুন!',
          isUser: false,
          timestamp: DateTime.now(),
          mode: 'system',
        ),
      );
    }

    if (mounted) {
      setState(() {
        _messages.clear();
        _messages.addAll(loadedMessages);
      });
      _scrollToBottom();
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final toSave = _messages.length > 50 ? _messages.sublist(_messages.length - 50) : _messages;
    final encoded = jsonEncode(toSave.map((e) => e.toJson()).toList());
    await prefs.setString('bot_chat_history', encoded);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
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

    // Process Bot Response instantly with local logic engine
    _processMessage(trimmed);
  }

  Future<void> _processMessage(String input) async {
    final lower = input.toLowerCase().trim();

    // 1. Commands
    if (lower.startsWith('/')) {
      _handleCommand(lower, input);
      return;
    }

    // Direct Keywords for quick actions
    if (lower.contains('quiz') || lower.contains('কুইজ')) {
      _sendQuizQuestion();
      return;
    }
    if (lower.contains('motivate') || lower.contains('অনুপ্রেরণা') || lower.contains('উক্তি') || lower.contains('মন বসে না') || lower.contains('পড়তে ইচ্ছা করে না')) {
      _sendMotivation();
      return;
    }
    if (lower.contains('revision') || lower.contains('রিভিশন') || lower.contains('১-৪-৭') || lower.contains('147') || lower.contains('spaced')) {
      await _sendRevisionAnalysis();
      return;
    }
    if (lower.contains('routine') || lower.contains('রুটিন') || lower.contains('আজকের পড়া') || lower.contains('টাস্ক') || lower.contains('কী বাকি')) {
      await _sendRoutineAnalysis();
      return;
    }
    if (lower.contains('countdown') || lower.contains('কাউন্টডাউন') || lower.contains('পরীক্ষা') || lower.contains('দিন বাকি') || lower.contains('exam')) {
      await _sendExamCountdown();
      return;
    }
    if (lower.contains('নামাজ') || lower.contains('ওয়াক্ত') || lower.contains('আজান') || lower.contains('prayer') || lower.contains('দুআ') || lower.contains('দোয়া')) {
      await _sendPrayerTimes();
      return;
    }
    if (lower.contains('vocab') || lower.contains('ভোকাব') || lower.contains('শব্দার্থ') || lower.contains('ইংরেজি শব্দ') || lower.contains('vocabulary')) {
      await _sendVocabChallenge();
      return;
    }
    if (lower.contains('flashcard') || lower.contains('ফ্ল্যাশকার্ড') || lower.contains('ডেক') || lower.contains('deck')) {
      await _sendFlashcardReview();
      return;
    }
    if (lower.contains('analytics') || lower.contains('অ্যানালিটিক্স') || lower.contains('স্টাডি সময়') || lower.contains('কত সময় পড়েছি') || lower.contains('পরিসংখ্যান') || lower.contains('পড়ার হিসাব')) {
      await _sendStudyAnalyticsSummary();
      return;
    }
    if (lower.contains('help') || lower.contains('সাহায্য') || lower.contains('কমান্ড')) {
      _sendHelpMenu();
      return;
    }

    // 2. Intelligent Knowledge Base Matcher (মুখস্ত প্রশ্নোত্তর ও লজিক)
    final answer = _matchKnowledgeBase(lower, input);
    setState(() {
      _messages.add(
        BotChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: answer,
          isUser: false,
          timestamp: DateTime.now(),
          mode: 'study_info',
        ),
      );
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  void _handleCommand(String lowerCmd, String originalInput) {
    if (lowerCmd == '/start' || lowerCmd == '/help') {
      _sendHelpMenu();
    } else if (lowerCmd.startsWith('/quiz')) {
      _sendQuizQuestion();
    } else if (lowerCmd.startsWith('/motivate') || lowerCmd == '/quote') {
      _sendMotivation();
    } else if (lowerCmd.startsWith('/routine') || lowerCmd == '/tasks') {
      _sendRoutineAnalysis();
    } else if (lowerCmd.startsWith('/revision') || lowerCmd == '/147') {
      _sendRevisionAnalysis();
    } else if (lowerCmd.startsWith('/countdown') || lowerCmd == '/exam') {
      _sendExamCountdown();
    } else if (lowerCmd.startsWith('/prayer') || lowerCmd == '/namaz') {
      _sendPrayerTimes();
    } else if (lowerCmd.startsWith('/vocab') || lowerCmd.startsWith('/word')) {
      _sendVocabChallenge();
    } else if (lowerCmd.startsWith('/flashcard') || lowerCmd.startsWith('/deck')) {
      _sendFlashcardReview();
    } else if (lowerCmd.startsWith('/analytics') || lowerCmd.startsWith('/stat')) {
      _sendStudyAnalyticsSummary();
    } else if (lowerCmd.startsWith('/tasbeeh')) {
      _sendTasbeeh();
    } else if (lowerCmd.startsWith('/calc')) {
      _handleCalculator(originalInput);
    } else if (lowerCmd == '/clear') {
      _clearChat();
    } else if (lowerCmd == '/bcs') {
      _sendBcsInfo();
    } else {
      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '❓ **অজানা কমান্ড:** `$lowerCmd`\n\nসব কমান্ড দেখতে `/help` টাইপ করুন অথবা নিচের বাটনগুলো ব্যবহার করুন।',
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

  // ==================== KNOWLEDGE BASE (মুখস্ত প্রশ্নোত্তর ও লজিক) ====================
  String _matchKnowledgeBase(String lower, String raw) {
    // বাংলা সাহিত্য: কাজী নজরুল ইসলাম
    if (lower.contains('নজরুল') || lower.contains('nazrul')) {
      return '📚 **কাজী নজরুল ইসলাম (১৮৯৯ - ১৯৭৬):**\n\n'
          '• **পরিচিতি:** বাংলাদেশের জাতীয় কবি এবং ‘বিদ্রোহী কবি’।\n'
          '• **জন্ম:** ২৪ মে ১৮৯৯ (১১ জ্যৈষ্ঠ ১৩০৬), ভারতের বর্ধমান জেলার চুরুলিয়া গ্রামে।\n'
          '• **মৃত্যু:** ২৯ আগস্ট ১৯৭৬ (১২ ভাদ্র ১৩৮৩), ঢাকায়।\n'
          '• **বিখ্যাত কাব্যগ্রন্থ:** অগ্নিবীণা (১৯২২), বিষের বাঁশী, দোলনচাঁপা, সাম্যবাদী, সর্বহারা, সিন্ধু-হিন্দোল।\n'
          '• **প্রথম প্রকাশিত কবিতা:** ‘মুক্তি’ (বঙ্গীয় মুসলমান সাহিত্য পত্রিকা, ১৯১৯)।\n'
          '• **প্রথম কাব্যগ্রন্থ:** অগ্নিবীণা (১২টি কবিতা; প্রথম কবিতা ‘প্রলয়োল্লাস’, দ্বিতীয় ‘বিদ্রোহী’)।\n'
          '• **উপন্যাস:** বাঁধন-হারা (প্রথম পত্রোপন্যাস), মৃত্যুক্ষুধা, কুহেলিকা।\n'
          '• **নাটক:** ঝিলিমিলি, আলেয়া, পুতুলের বিয়ে।\n'
          '• **পুরস্কার:** জগত্তারিনী স্বর্ণপদক (১৯৪৫), পদ্মভূষণ (১৯৬০), একুশে পদক (১৯৭৬)।';
    }

    // বাংলা সাহিত্য: রবীন্দ্রনাথ ঠাকুর
    if (lower.contains('রবীন্দ্রনাথ') || lower.contains('tagore') || lower.contains('rabindranath')) {
      return '📚 **রবীন্দ্রনাথ ঠাকুর (১৮৬১ - ১৯৪১):**\n\n'
          '• **পরিচিতি:** বিশ্বকবি, নাইট উপাধি ত্যাগকারী ও এশিয়ার প্রথম নোবেল বিজয়ী।\n'
          '• **জন্ম:** ৭ মে ১৮৬১ (২৫ বৈশাখ ১২৬৮), কলকাতার জোড়াসাঁকো ঠাকুরবাড়িতে।\n'
          '• **মৃত্যু:** ৭ আগস্ট ১৯৪১ (২২ শ্রাবণ ১৩৪৮)।\n'
          '• **নোবেল পুরস্কার:** ১৯১৩ সালে ‘Song Offerings’ (গীতাঞ্জলির ইংরেজি অনুবাদ) কাব্যের জন্য সাহিত্যে নোবেল পান।\n'
          '• **কাব্যগ্রন্থ:** বনফুল (প্রথম প্রকাশিত কাব্য), মানসী, সোনার তরী, চিত্রা, ক্ষণিকা, বলাকা, গীতাঞ্জলি।\n'
          '• **উপন্যাস (১২টি):** করুণা (প্রথম), চোখের বালি, গোরা, ঘরে-বাইরে, শেষের কবিতা, চার অধ্যায়।\n'
          '• **প্রথম সার্থক ছোটগল্প:** ‘ঘাটের কথা’ (১৮৮৪)।\n'
          '• **জাতীয় সংগীত:** বাংলাদেশ (আমার সোনার বাংলা) ও ভারতের (জনগণমন) জাতীয় সংগীতের রচয়িতা।';
    }

    // মুক্তিযুদ্ধ ও বীরশ্রেষ্ঠ
    if (lower.contains('মুক্তিযুদ্ধ') || lower.contains('বীরশ্রেষ্ঠ') || lower.contains('১৯৭১') || lower.contains('sector')) {
      return '🇧🇩 **মহান মুক্তিযুদ্ধ ও ৭ জন বীরশ্রেষ্ঠ (১৯৭১):**\n\n'
          '• **সেক্টর সংখ্যা:** সমগ্র বাংলাদেশকে ১১টি সেক্টর এবং ৬৪টি সাব-সেক্টরে ভাগ করা হয়।\n'
          '• **১০ নম্বর সেক্টর:** কোনো নিয়মিত সেক্টর কমান্ডার ছিলেন না (নৌ-কমান্ডোদের অধীনে পরিচালিত)।\n'
          '• **সর্বোচ্চ সামরিক খেতাব:** বীরশ্রেষ্ঠ (৭ জন)।\n\n'
          '🎖️ **৭ জন বীরশ্রেষ্ঠের তালিকা:**\n'
          '১. **মহিউদ্দীন জাহাঙ্গীর** (ক্যাপ্টেন - সেনাবাহিনী) — চাঁপাইনবাবগঞ্জ\n'
          '২. **মোস্তফা কামাল** (সিপাহী - সেনাবাহিনী) — ব্রাহ্মণবাড়িয়া\n'
          '৩. **হামিদুর রহমান** (সিপাহী - সেনাবাহিনী) — মৌলভীবাজার\n'
          '৪. **মোহাম্মদ রুহুল আমিন** (ইঞ্জিনরুম আর্টিফিসার - নৌবাহিনী) — রূপসা, খুলনা\n'
          '৫. **মতিউর রহমান** (ফ্লাইট লেফটেন্যান্ট - বিমানবাহিনী) — সিন্ধু, পাকিস্তান\n'
          '৬. **মুন্সী আব্দুর রউফ** (ল্যান্স নায়েক - ইপিআর) — নানিয়ারচর, রাঙামাটি\n'
          '৭. **নূর মোহাম্মদ শেখ** (ল্যান্স নায়েক - ইপিআর) — যশোর';
    }

    // বাংলাদেশ সংবিধান
    if (lower.contains('সংবিধান') || lower.contains('constitution') || lower.contains('অনুচ্ছেদ')) {
      return '📜 **গণপ্রজাতন্ত্রী বাংলাদেশের সংবিধান:**\n\n'
          '• **প্রণয়ন কমিটি:** ড. কামাল হোসেনের নেতৃত্বে ৩৪ সদস্যের খসড়া সংবিধান কমিটি।\n'
          '• **গৃহীত হয়:** ৪ নভেম্বর ১৯৭২ (জাতীয় সংবিধান দিবস)।\n'
          '• **কার্যকর হয়:** ১৬ ডিসেম্বর ১৯৭২ (বিজয় দিবস)।\n'
          '• **মোট অংশ:** ১১টি ভাগ, ১৫৩টি অনুচ্ছেদ, ৭টি তফসিল এবং ১টি প্রস্তাবনা।\n\n'
          '⭐ **গুরুত্বপূর্ণ অনুচ্ছেদসমূহ:**\n'
          '• অনুচ্ছেদ ২(ক) : রাষ্ট্রধর্ম (ইসলাম)\n'
          '• অনুচ্ছেদ ৩ : রাষ্ট্রভাষা (বাংলা)\n'
          '• অনুচ্ছেদ ৪(ক) : জাতির পিতার প্রতিকৃতি\n'
          '• অনুচ্ছেদ ৭ : সংবিধানের প্রাধান্য (জনগণই সকল ক্ষমতার উৎস)\n'
          '• অনুচ্ছেদ ৮ : মূলনীতি (জাতীয়তাবাদ, সমাজতন্ত্র, গণতন্ত্র ও ধর্মনিরপেক্ষতা)\n'
          '• অনুচ্ছেদ ১১ : গণতন্ত্র ও মানবাধিকার\n'
          '• অনুচ্ছেদ ১৭ : অবৈতনিক ও বাধ্যতামূলক প্রাথমিক শিক্ষা\n'
          '• অনুচ্ছেদ ২৭ : আইনের দৃষ্টিতে সবাই সমান\n'
          '• অনুচ্ছেদ ৩৬-৪৪ : মৌলিক অধিকারসমূহ';
    }

    // মেগা প্রজেক্ট: পদ্মা সেতু ও মেট্রোরেল
    if (lower.contains('পদ্মা সেতু') || lower.contains('মেট্রোরেল') || lower.contains('padma bridge')) {
      return '🌉 **বাংলাদেশের মেগা প্রজেক্ট তথ্য:**\n\n'
          '**১. পদ্মা বহুমুখী সেতু:**\n'
          '• দৈর্ঘ্য: ৬.১৫ কিমি (স্প্যান ৪১টি, পিলার ৪২টি)।\n'
          '• উদ্বোধন: ২৫ জুন ২০২২ (যানবাহন চলাচলের জন্য উন্মুক্ত)।\n'
          '• সংযোগস্থল: মুন্সীগঞ্জের মাওয়া এবং শরীয়তপুরের জাজিরা।\n'
          '• বিশ্বব্যাংক ছাড়া সম্পূর্ণ নিজস্ব অর্থায়নে নির্মিত।\n\n'
          '**২. ঢাকা মেট্রোরেল (MRT Line-6):**\n'
          '• প্রথম উদ্বোধন: ২৮ ডিসেম্বর ২০২২ (উত্তরা উত্তর থেকে আগারগাঁও)।\n'
          '• মতিঝিল পর্যন্ত উদ্বোধন: ৪ নভেম্বর ২০২৩।\n'
          '• সহযোগী দেশ: জাপান (JICA)।';
    }

    // বাংলা ব্যাকরণ: কারক ও সমাস
    if (lower.contains('কারক') || lower.contains('সমাস') || lower.contains('সন্ধি')) {
      return '📖 **বাংলা ব্যাকরণ সংক্ষেপ:**\n\n'
          '**১. কারক (ক্রিয়ার সাথে সম্পর্ক): ৬ প্রকার**\n'
          '• কর্তাকারক (কে/কারা? যেমন: রহিম পড়ে)\n'
          '• কর্মকারক (কী/কাকে? যেমন: ঘোড়া গাড়ি টানে)\n'
          '• করণকারক (কী দিয়ে/উপায়? যেমন: কলমে লিখি)\n'
          '• সম্প্রদানকারক (স্বত্ব ত্যাগ করে দান? যেমন: ভিক্ষুককে ভিক্ষা দাও)\n'
          '• অপাদানকারক (কোথা থেকে উৎপন্ন/বিচ্যুত/ভীত? যেমন: তিলে তৈল হয়, পাপে বিরত হও)\n'
          '• অধিকরণকারক (স্থান/কাল/বিষয়? যেমন: নদীতে মাছ আছে, তিনি ব্যাকরণে পণ্ডিত)\n\n'
          '**২. সমাস (সংক্ষেপকরণ): প্রধানত ৬ প্রকার**\n'
          '• দ্বন্দ্ব, কর্মধারয়, তৎপুরুষ, বহুব্রীহি, দ্বিগু ও অব্যয়ীভাব।';
    }

    // English Grammar: Tense & Rules
    if (lower.contains('tense') || lower.contains('grammar') || lower.contains('preposition') || lower.contains('voice')) {
      return '🇬🇧 **Essential English Grammar Cheat Sheet:**\n\n'
          '**1. Subject-Verb Agreement Rules:**\n'
          '• Singular subject takes singular verb: *"Neither of the boys was present."*\n'
          '• *"One of + Plural Noun + Singular Verb"*: *"One of my friends is a doctor."*\n'
          '• With *"As well as / along with / together with"*, verb follows the FIRST subject: *"The teacher as well as students was present."*\n\n'
          '**2. Preposition Hot Rules:**\n'
          '• Senior / Junior / Prior / Inferior ➔ followed by **"to"** (not than).\n'
          '• Good **at** (দক্ষ), Die **of** (রোগে মারা যাওয়া), Die **from** (অতিরিক্ত কারণে মারা যাওয়া), Abide **by** (মেনে চলা).\n\n'
          '**3. Conditionals:**\n'
          '• 1st: If + Present ➔ Future (*"If you study, you will pass."*)\n'
          '• 2nd: If + Past Simple ➔ would + V1 (*"If I knew, I would tell you."*)\n'
          '• 3rd: If + Past Perfect ➔ would have + V3 (*"If you had worked hard, you would have succeeded."*)';
    }

    // গণিত সূত্র ও শর্টকাট
    if (lower.contains('গণিত') || lower.contains('সূত্র') || lower.contains('শতকরা') || lower.contains('মৌলিক') || lower.contains('math')) {
      return '📐 **গুরুত্বপূর্ণ গণিত সূত্রাবলী ও শর্টকাট:**\n\n'
          '**১. মৌলিক সংখ্যা:**\n'
          '• ১-৫০ পর্যন্ত মোট ১৫টি (২, ৩, ৫, ৭, ১১, ১৩, ১৭, ১৯, ২৩, ২৯, ৩১, ৩৭, ৪১, ৪৩, ৪৭)।\n'
          '• ৫১-১০০ পর্যন্ত মোট ১০টি (৫৩, ৫৯, ৬১, ৬৭, ৭১, ৭৩, ৭৯, ৮৩, ৮৯, ৯৭)।\n'
          '• মোট ১-১০০ পর্যন্ত = ২৫টি মৌলিক সংখ্যা।\n\n'
          '**২. ধারার সূত্র:**\n'
          '• ১ম n সংখ্যক স্বাভাবিক সংখ্যার সমষ্টি = **[n(n + 1)] / 2**\n'
          '• ১ম n সংখ্যক স্বাভাবিক জোড় সংখ্যার সমষ্টি = **n(n + 1)**\n'
          '• ১ম n সংখ্যক স্বাভাবিক বিজোড় সংখ্যার সমষ্টি = **n²**\n'
          '• বর্গের সমষ্টি = **[n(n + 1)(2n + 1)] / 6**\n\n'
          '**৩. লাভ ও ক্ষতি:**\n'
          '• লাভ = বিক্রয়মূল্য - ক্রয়মূল্য\n'
          '• শতকরা লাভ = (মোট লাভ ÷ ক্রয়মূল্য) × ১০০%';
    }

    // পড়া মনে রাখার উপায় ও ফোকাস
    if (lower.contains('মনে থাকে না') || lower.contains('পড়ার উপায়') || lower.contains('স্মরণশক্তি') || lower.contains('পদ্ধতি')) {
      return '🧠 **পড়া দীর্ঘস্থায়ীভাবে মনে রাখার বৈজ্ঞানিক কৌশল:**\n\n'
          '১. **১-৪-৭ রিভিশন ফর্মুলা (Spaced Repetition):**\n'
          'যেকোনো নতুন টপিক পড়ার পর—\n'
          '• ১ম রিভিশন: পড়ার ২৪ ঘণ্টার মধ্যে (১০ মিনিট)\n'
          '• ২য় রিভিশন: ৪র্থ দিনে (৫ মিনিট)\n'
          '• ৩য় রিভিশন: ৭ম দিনে (৫ মিনিট)\n'
          'এতে পড়া সাবকনশাস মেমরিতে স্থায়ীভাবে জমা হয়।\n\n'
          '২. **পমোডোরো টেকনিক (Pomodoro):**\n'
          '• ২৫ মিনিট একটানা গভীর মনোযোগে পড়ুন।\n'
          '• ৫ মিনিটের শর্ট ব্রেক নিন।\n'
          '• এভাবে ৪টি সেশন পর একটি দীর্ঘ ২০ মিনিটের ব্রেক নিন।\n\n'
          '৩. **অ্যাক্টিভ রিকল (Active Recall):**\n'
          'রিডিং পড়ে পাতা বন্ধ করে খাতায় মূল পয়েন্টগুলো নিজের ভাষায় লিখুন।';
    }

    // BCS Preliminary সিলেবাস ও মানবণ্টন
    if (lower.contains('বিসিএস') || lower.contains('bcs') || lower.contains('মানবণ্টন') || lower.contains('সিলেবাস')) {
      return '📋 **বিসিএস প্রিলিমিনারি ২০০ নম্বরের মানবণ্টন:**\n\n'
          '১. বাংলা ভাষা ও সাহিত্য — **৩৫ নম্বর**\n'
          '২. ইংরেজি ভাষা ও সাহিত্য — **৩৫ নম্বর**\n'
          '৩. বাংলাদেশ বিষয়াবলি — **৩০ নম্বর**\n'
          '৪. আন্তর্জাতিক বিষয়াবলি — **২০ নম্বর**\n'
          '৫. ভূগোল, পরিবেশ ও দুর্যোগ ব্যবস্থাপনা — **১০ নম্বর**\n'
          '৬. সাধারণ বিজ্ঞান — **১৫ নম্বর**\n'
          '৭. কম্পিউটার ও তথ্যপ্রযুক্তি — **১৫ নম্বর**\n'
          '৮. গাণিতিক যুক্তি — **১৫ নম্বর**\n'
          '৯. মানসিক দক্ষতা — **১৫ নম্বর**\n'
          '১০. নৈতিকতা, মূল্যবোধ ও সুশাসন — **১০ নম্বর**\n\n'
          '⏱️ **সময়:** ২ ঘণ্টা | **মোট প্রশ্ন:** ২০০টি (প্রতিটি সঠিক উত্তরে ১, ভুলের জন্য ০.৫০ নেগেটিভ মার্ক)।';
    }

    // Default friendly guide
    return '💡 **আমি আপনার প্রশ্নটি বুঝতে পেরেছি!**\n\n'
        'আমি এই বিষয়গুলোতে আপনাকে দ্রুত সাহায্য করতে পারি:\n'
        '• 📅 **"রুটিন বিশ্লেষণ"** — আপনার আজকের পড়ার তালিকা পর্যালোচনা\n'
        '• 📚 **"কাজী নজরুল"** বা **"রবীন্দ্রনাথ"** — সাহিত্যিকদের গুরুত্বপূর্ণ তথ্য\n'
        '• 🇧🇩 **"মুক্তিযুদ্ধ"** বা **"সংবিধান"** — বাংলাদেশ বিষয়াবলির মূল পয়েন্ট\n'
        '• 📖 **"কারক"** বা **"সমাস"** — বাংলা ব্যাকরণ নিয়ম\n'
        '• 🇬🇧 **"Tense"** বা **"Preposition"** — ইংরেজি গ্রামার নিয়ম\n'
        '• 📐 **"গণিত সূত্র"** বা **"মৌলিক সংখ্যা"** — শর্টকাট গণিত\n'
        '• 🎯 **`/quiz`** — বিসিএস লাইভ কুইজ খেলুন\n'
        '• 🧮 **`/calc 50*4`** — সরাসরি হিসাব করুন\n\n'
        'নিচের বাটনগুলো চেপেও সরাসরি দেখতে পারেন!';
  }

  // ==================== LIVE STUDY ROUTINE ANALYZER ====================
  Future<void> _sendRoutineAnalysis() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '⚠️ আপনার পড়ার রুটিন দেখতে অনুগ্রহ করে অ্যাপে লগইন করুন।',
            isUser: false,
            timestamp: DateTime.now(),
            mode: 'cmd',
          ),
        );
      });
      return;
    }

    try {
      final now = DateTime.now();
      final todayDateId = DateFormat('yyyy-MM-dd').format(now);

      // 1. Check daily routine doc first
      final dailyDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('dailyRoutines')
          .doc(todayDateId)
          .get();

      List<Map<String, dynamic>> allTasks = [];

      if (dailyDoc.exists && dailyDoc.data() != null && dailyDoc.data()!['tasks'] != null) {
        final rawList = dailyDoc.data()!['tasks'] as List;
        for (var t in rawList) {
          if (t is Map) allTasks.add(Map<String, dynamic>.from(t));
        }
      }

      // 2. Also check general tasks collection
      final generalTasksSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .limit(25)
          .get();

      for (var doc in generalTasksSnap.docs) {
        final d = doc.data();
        final title = d['title'] ?? d['taskName'] ?? '';
        if (title.isNotEmpty && !allTasks.any((t) => (t['title'] ?? '') == title)) {
          allTasks.add(d);
        }
      }

      if (allTasks.isEmpty) {
        setState(() {
          _messages.add(
            BotChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: '📅 **আজকের রুটিন অ্যানালাইসিস (${DateFormat('dd MMMM, yyyy').format(now)}):**\n\n'
                  'আপনার অ্যাপে বর্তমানে কোনো পেন্ডিং টাস্ক যুক্ত নেই।\n\n'
                  '💡 **আজকের জন্য একটি স্টাডি টার্গেট সেট করুন:**\n'
                  '• 📖 বাংলা সাহিত্য: ২ ঘণ্টা\n'
                  '• 🇬🇧 ইংরেজি গ্রামার/ভোকাবুলারি: ১ ঘণ্টা\n'
                  '• 📐 গণিত শর্টকাট প্র্যাকটিস: ১ ঘণ্টা\n'
                  '• 🔄 বিগত দিনের পড়া রিভিশন: ৩০ মিনিট\n\n'
                  '*(টাস্ক যোগ করতে অ্যাপের `Today\'s Tasks` বা রুটিন স্ক্রিন ব্যবহার করুন)*',
              isUser: false,
              timestamp: DateTime.now(),
              mode: 'study_info',
            ),
          );
        });
      } else {
        int completed = 0;
        int pending = 0;
        int totalMinutesPlanned = 0;
        int totalMinutesSpent = 0;

        final buffer = StringBuffer('📊 **আজকের স্টাডি রুটিন ও প্রোগ্রেস (${DateFormat('dd MMM').format(now)}):**\n\n');

        int index = 1;
        for (var data in allTasks) {
          final title = data['title'] ?? data['taskName'] ?? 'Unnamed Task';
          final isDone = data['isCompleted'] == true || data['status'] == 'completed';
          final cat = data['category'] ?? data['subject'] ?? '';
          final duration = data['totalDurationMinutes'] ?? 0;
          final spent = data['completedDurationMinutes'] ?? 0;

          if (duration is int) totalMinutesPlanned += duration;
          if (spent is int) totalMinutesSpent += spent;

          if (isDone) {
            completed++;
          } else {
            pending++;
          }

          buffer.writeln('$index. ${isDone ? "✅ [সম্পন্ন]" : "⏳ [বাকি আছে]"} **$title** ${cat.isNotEmpty ? "• _${cat}_" : ""}');
          index++;
        }

        final total = allTasks.length;
        final percent = ((completed / total) * 100).toInt();

        buffer.writeln('\n📈 **অগ্রগতি সারাংশ:**');
        buffer.writeln('• মোট টাস্ক: **$total টি** | সম্পন্ন: **$completed টি** | বাকি: **$pending টি**');
        buffer.writeln('• আজকের সমাপ্তির হার: **$percent%**');
        if (totalMinutesPlanned > 0) {
          buffer.writeln('• পরিকল্পিত স্টাডি টাইম: **$totalMinutesPlanned মিনিট** (ব্যয়িত: **$totalMinutesSpent মিনিট**)');
        }

        if (percent == 100) {
          buffer.writeln('\n🎉 **অসাধারণ! আজকের সব পড়া সম্পন্ন হয়েছে! এবার একটি হালকা কুইজ দিয়ে নিজেকে যাচাই করুন।**');
        } else if (percent >= 50) {
          buffer.writeln('\n💪 **বেশ ভালো অগ্রগতি! অর্ধেকের বেশি সম্পন্ন হয়েছে। আর একটু মনোযোগ দিলেই বাকিটা শেষ হবে!**');
        } else {
          buffer.writeln('\n🎯 **পরামর্শ:** যে টাস্কটি সবচেয়ে কঠিন মনে হয়, সেটি দিয়ে এখন শুরু করুন। ২৫ মিনিট একটানা পড়ুন ও ৫ মিনিট ব্রেক নিন!');
        }

        setState(() {
          _messages.add(
            BotChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: buffer.toString(),
              isUser: false,
              timestamp: DateTime.now(),
              mode: 'study_info',
            ),
          );
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '📅 **আজকের রুটিন:** অফলাইনে আপনার টাস্ক লোড হতে সমস্যা হয়েছে। ইন্টারনেট সংযোগ চেক করুন।',
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

  // ==================== 1-4-7 SPACED REPETITION ANALYZER ====================
  Future<void> _sendRevisionAnalysis() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '⚠️ রিভিশন শিডিউল দেখতে অনুগ্রহ করে অ্যাপে লগইন করুন।',
            isUser: false,
            timestamp: DateTime.now(),
            mode: 'cmd',
          ),
        );
      });
      return;
    }

    final now = DateTime.now();
    final day1 = now.subtract(const Duration(days: 1));
    final day4 = now.subtract(const Duration(days: 4));
    final day7 = now.subtract(const Duration(days: 7));

    final date1Str = DateFormat('yyyy-MM-dd').format(day1);
    final date4Str = DateFormat('yyyy-MM-dd').format(day4);
    final date7Str = DateFormat('yyyy-MM-dd').format(day7);

    try {
      final doc1 = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('dailyRoutines').doc(date1Str).get();
      final doc4 = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('dailyRoutines').doc(date4Str).get();
      final doc7 = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('dailyRoutines').doc(date7Str).get();

      List<String> getTaskTitles(DocumentSnapshot snap) {
        if (!snap.exists || snap.data() == null) return [];
        final data = snap.data() as Map<String, dynamic>;
        final tasks = data['tasks'] as List?;
        if (tasks == null) return [];
        return tasks.map((t) {
          final title = t['title'] ?? t['taskName'] ?? '';
          final sub = t['subject'] ?? '';
          return sub.isNotEmpty ? '$title ($sub)' : title.toString();
        }).where((s) => s.trim().isNotEmpty).toList();
      }

      final tasks1 = getTaskTitles(doc1);
      final tasks4 = getTaskTitles(doc4);
      final tasks7 = getTaskTitles(doc7);

      final buffer = StringBuffer('🔄 **আজকের ১-৪-৭ স্পেসড রিপিটেশন রিভিশন শিডিউল:**\n\n');

      buffer.writeln('📌 **১ম রিভিশন (গতকাল যা পড়েছিলেন - ${DateFormat('dd MMM').format(day1)}):**');
      if (tasks1.isNotEmpty) {
        for (var t in tasks1) {
          buffer.writeln('  • $t');
        }
        buffer.writeln('  ⏱️ _পরামর্শ: ১০ মিনিট চোখ বুলিয়ে রিকল করুন_');
      } else {
        buffer.writeln('  • _গতকালের কোনো রুটিন টাস্ক পাওয়া যায়নি_');
      }

      buffer.writeln('\n📌 **২য় রিভিশন (৪ দিন আগে যা পড়েছিলেন - ${DateFormat('dd MMM').format(day4)}):**');
      if (tasks4.isNotEmpty) {
        for (var t in tasks4) {
          buffer.writeln('  • $t');
        }
        buffer.writeln('  ⏱️ _পরামর্শ: ৫ মিনিট কি-পয়েন্টগুলো স্মরণ করুন_');
      } else {
        buffer.writeln('  • _৪ দিন আগের কোনো রুটিন টাস্ক পাওয়া যায়নি_');
      }

      buffer.writeln('\n📌 **৩য় রিভিশন (৭ দিন আগে যা পড়েছিলেন - ${DateFormat('dd MMM').format(day7)}):**');
      if (tasks7.isNotEmpty) {
        for (var t in tasks7) {
          buffer.writeln('  • $t');
        }
        buffer.writeln('  ⏱️ _পরামর্শ: ৫ মিনিট রিভিশন দিলে এটি স্থায়ী স্মৃতিতে রূপ নেবে_');
      } else {
        buffer.writeln('  • _৭ দিন আগের কোনো রুটিন টাস্ক পাওয়া যায়নি_');
      }

      buffer.writeln('\n🧠 **বিজ্ঞান কী বলে?**');
      buffer.writeln('হারমান এবিংহাউসের বিস্মরণ সূত্র (Forgetting Curve) অনুসারে—পড়ার ১ দিন, ৪ দিন ও ৭ দিন পর দ্রুত রিভিশন দিলে পড়াটি সাবকনশাস মেমরিতে আজীবনের মতো সংরক্ষিত হয়ে যায়!');

      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: buffer.toString(),
            isUser: false,
            timestamp: DateTime.now(),
            mode: 'study_info',
          ),
        );
      });
    } catch (e) {
      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '🔄 **১-৪-৭ রিভিশন মেথড:**\n\n'
                '• **Day 1 (১ম দিন):** নতুন পড়া শেষে ২৪ ঘণ্টার মধ্যে ১০ মিনিট রিভিশন।\n'
                '• **Day 4 (৪র্থ দিন):** ৪র্থ দিনে ৫ মিনিট রিভিশন।\n'
                '• **Day 7 (৭ম দিন):** ৭ম দিনে শেষবারের মতো ৫ মিনিট রিভিশন।\n\n'
                '💡 এটি নিয়মিত চর্চা করলে কঠিন পড়া কখনোই ভুলবেন না!',
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

  // ==================== EXAM COUNTDOWN ====================
  Future<void> _sendExamCountdown() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '⚠️ পরীক্ষার কাউন্টডাউন দেখতে অ্যাপে লগইন করুন।',
            isUser: false,
            timestamp: DateTime.now(),
            mode: 'cmd',
          ),
        );
      });
      return;
    }

    try {
      final foldersSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('countdownFolders')
          .get();

      List<Map<String, dynamic>> allEvents = [];

      for (var fDoc in foldersSnap.docs) {
        final entriesSnap = await fDoc.reference.collection('entries').get();
        for (var eDoc in entriesSnap.docs) {
          final data = eDoc.data();
          allEvents.add(data);
        }
      }

      final now = DateTime.now();

      if (allEvents.isEmpty) {
        setState(() {
          _messages.add(
            BotChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: '⏳ **পরীক্ষার কাউন্টডাউন ও ডেডলাইন:**\n\n'
                  'আপনার কাউন্টডাউন তালিকায় বর্তমানে কোনো পরীক্ষা বা ডেডলাইন যুক্ত নেই।\n\n'
                  '💡 **পরামর্শ:**\n'
                  'অ্যাপের `Special Day Countdown` স্ক্রিন থেকে আপনার কাঙ্ক্ষিত পরীক্ষা (যেমন: ৪৭তম বিসিএস, কম্বাইন্ড ব্যাংক, শিক্ষক নিবন্ধন) যোগ করে রাখুন।\n\n'
                  '🎯 বট প্রতিদিন স্বয়ংক্রিয়ভাবে কত দিন বাকি আছে তা মনে করিয়ে দেবে!',
              isUser: false,
              timestamp: DateTime.now(),
              mode: 'study_info',
            ),
          );
        });
      } else {
        allEvents.sort((a, b) {
          final dateA = (a['examDate'] as Timestamp?)?.toDate() ?? (a['deadlineDate'] as Timestamp?)?.toDate() ?? DateTime.now();
          final dateB = (b['examDate'] as Timestamp?)?.toDate() ?? (b['deadlineDate'] as Timestamp?)?.toDate() ?? DateTime.now();
          return dateA.compareTo(dateB);
        });

        final buffer = StringBuffer('⏳ **আসন্ন পরীক্ষা ও ডেডলাইন কাউন্টডাউন:**\n\n');

        int activeCount = 0;
        for (var ev in allEvents) {
          final title = ev['title'] ?? 'পরীক্ষা';
          final org = ev['organization'] ?? '';
          final examDate = (ev['examDate'] as Timestamp?)?.toDate();
          final deadlineDate = (ev['deadlineDate'] as Timestamp?)?.toDate();

          final targetDate = examDate ?? deadlineDate;
          if (targetDate == null) continue;

          final diffDays = targetDate.difference(now).inDays;
          final isPast = targetDate.isBefore(now);

          if (!isPast) {
            activeCount++;
            final dateStr = DateFormat('dd MMMM, yyyy').format(targetDate);
            buffer.writeln('🎯 **$title** ${org.isNotEmpty ? "($org)" : ""}');
            buffer.writeln('• তারিখ: **$dateStr**');
            buffer.writeln('• সময় বাকি: ⏳ **${diffDays == 0 ? "আজই পরীক্ষা!" : "$diffDays দিন বাকি"}**\n');
          }
        }

        if (activeCount == 0) {
          buffer.writeln('আপনার সব পূর্বের ডেডলাইন অতিক্রান্ত হয়েছে। নতুন পরীক্ষার লক্ষ্য সেট করুন!');
        } else {
          buffer.writeln('💡 **স্টাডি স্ট্র্যাটেজি:** পরীক্ষার শেষ দিনগুলোতে নতুন টপিক ধরার চেয়ে বিগত বছরের প্রশ্ন এবং পূর্বের পড়া রিভিশনে ৮০% সময় দিন!');
        }

        setState(() {
          _messages.add(
            BotChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: buffer.toString(),
              isUser: false,
              timestamp: DateTime.now(),
              mode: 'study_info',
            ),
          );
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '⏳ **কাউন্টডাউন তথ্য:** অফলাইনে তথ্য লোড করা যায়নি। ইন্টারনেট সংযোগ নিশ্চিত করুন।',
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

  // ==================== PRAYER & ISLAMIC ROUTINE ====================
  Future<void> _sendPrayerTimes() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheFile = File('${dir.path}/prayer_times_cache.json');

      String prayerInfo = '';
      if (await cacheFile.exists()) {
        final data = json.decode(await cacheFile.readAsString());
        final timings = Map<String, dynamic>.from(data['timings'] ?? {});
        final fajr = timings['Fajr'] ?? '';
        final dhuhr = timings['Dhuhr'] ?? '';
        final asr = timings['Asr'] ?? '';
        final maghrib = timings['Maghrib'] ?? '';
        final isha = timings['Isha'] ?? '';

        prayerInfo = '🕌 **আজকের নামাজের সময়সূচি:**\n\n'
            '• ফজর: **$fajr**\n'
            '• যোহর: **$dhuhr**\n'
            '• আসর: **$asr**\n'
            '• মাগরিব: **$maghrib**\n'
            '• এশা: **$isha**\n\n';
      }

      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '${prayerInfo.isNotEmpty ? prayerInfo : "🕌 **নামাজ ও ইসলামিক রুটিন:**\n\n"}'
                '📖 **পড়াশোনায় বরকত ও স্মৃতিশক্তি বৃদ্ধির কুরআনীয় দু’আ:**\n\n'
                '**رَّبِّ زِدْنِي عِلْمًا**\n'
                '*(উচ্চারণ: রাব্বি যিদনি ইলমা)*\n'
                '**অর্থ:** "হে আমার প্রতিপালক! আমার জ্ঞান বৃদ্ধি করে দিন।" *(সূরা ত্বা-হা: ১১৪)*\n\n'
                '**رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي**\n'
                '*(উচ্চারণ: রাব্বিশ রাহলী সাদরী, ওয়া ইয়াসসিরলী আমরী)*\n'
                '**অর্থ:** "হে আমার প্রভু! আমার বক্ষ প্রশস্ত করে দিন এবং আমার কাজ সহজ করে দিন।" *(সূরা ত্বা-হা: ২৫-২৬)*\n\n'
                '💡 পড়া শুরু করার পূর্বে বিসমিল্লাহ বলে এই দু’আটি পড়ুন, ইনশাআল্লাহ পড়া সহজে মুখস্থ ও অনুধাবন হবে।',
            isUser: false,
            timestamp: DateTime.now(),
            mode: 'study_info',
          ),
        );
      });
    } catch (_) {
      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '📖 **পড়াশোনায় সফলতার দু’আ:**\n\n'
                '**رَّبِّ زِدْنِي عِلْمًا**\n'
                '*(উচ্চারণ: রাব্বি যিদনি ইলমা)*\n'
                '**অর্থ:** "হে আমার প্রতিপালক! আমার জ্ঞান বাড়িয়ে দিন।" *(সূরা ত্বা-হা: ১১৪)*',
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

  // ==================== VOCABULARY CHALLENGE ====================
  Future<void> _sendVocabChallenge() async {
    final random = Random();
    final item = _vocabList[random.nextInt(_vocabList.length)];

    final buffer = StringBuffer('📖 **ইংরেজি ভোকাবুলারি এক্সপ্লোরার:**\n\n');
    buffer.writeln('🔤 **${item['word']}**  _${item['phonetic']}_');
    buffer.writeln('• **Part of Speech:** ${item['pos']}');
    buffer.writeln('• **বাংলা অর্থ:** **${item['meaning']}**');
    buffer.writeln('• **Synonyms:** ${item['synonyms']}');
    buffer.writeln('• **Antonyms:** ${item['antonyms']}');
    buffer.writeln('• **Example:** *"${item['example']}"*\n');

    // Check user's favorite words in Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final favSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorite_words')
            .limit(5)
            .get();

        if (favSnap.docs.isNotEmpty) {
          buffer.writeln('⭐ **আপনার সেভ করা ফেভারিট শব্দসমূহ:**');
          for (var doc in favSnap.docs) {
            final w = doc.data()['word'] ?? '';
            final m = doc.data()['meaning'] ?? doc.data()['bengaliMeaning'] ?? '';
            if (w.toString().isNotEmpty) {
              buffer.writeln('• **$w** ${m.toString().isNotEmpty ? "— $m" : ""}');
            }
          }
          buffer.writeln('\n*(নতুন শব্দ সেভ ও শুনতে অ্যাপের ডিকশনারি স্ক্রিন দেখুন)*');
        }
      } catch (_) {}
    }

    setState(() {
      _messages.add(
        BotChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: buffer.toString(),
          isUser: false,
          timestamp: DateTime.now(),
          mode: 'study_info',
        ),
      );
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  // ==================== FLASHCARD REVIEW ====================
  Future<void> _sendFlashcardReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '⚠️ ফ্ল্যাশকার্ড পর্যালোচনা দেখতে অ্যাপে লগইন করুন।',
            isUser: false,
            timestamp: DateTime.now(),
            mode: 'cmd',
          ),
        );
      });
      return;
    }

    try {
      final decksSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('flashcard_decks')
          .limit(10)
          .get();

      if (decksSnap.docs.isEmpty) {
        setState(() {
          _messages.add(
            BotChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: '🃏 **ফ্ল্যাশকার্ড স্টাডি ডেক:**\n\n'
                  'আপনার অ্যাকাউন্টে বর্তমানে কোনো কাস্টম ফ্ল্যাশকার্ড ডেক নেই।\n\n'
                  '💡 **ফ্ল্যাশকার্ডের উপকারিতা:**\n'
                  'স্পেসড রিপিটেশন ফ্ল্যাশকার্ড ব্যবহার করে দ্রুত শব্দার্থ, সংবিধানের অনুচ্ছেদ, বিজ্ঞান ও ব্যাকরণের কঠিন নিয়ম সহজে মুখস্থ করা যায়।\n\n'
                  '🎯 **নমুনা ফ্ল্যাশকার্ড চ্যালেঞ্জ:**\n'
                  '📌 **প্রশ্ন:** *বাংলাদেশের সংবিধানের কত নম্বর অনুচ্ছেদে "মৌলিক অধিকার নিশ্চিতকরণ" ও "আইনের দৃষ্টিতে সমতা" উল্লেখ আছে?*\n\n'
                  '💡 **উত্তর:** **অনুচ্ছেদ ২৭** *(সকল নাগরিক আইনের দৃষ্টিতে সমান এবং আইনের সমান আশ্রয় লাভের অধিকারী)*',
              isUser: false,
              timestamp: DateTime.now(),
              mode: 'study_info',
            ),
          );
        });
      } else {
        int totalCards = 0;
        int dueCards = 0;
        int masteredCards = 0;
        Map<String, dynamic>? sampleCard;
        String sampleDeckTitle = '';

        final now = DateTime.now();

        for (var doc in decksSnap.docs) {
          final data = doc.data();
          final title = data['title'] ?? 'ডেক';
          final cards = data['cards'] as List<dynamic>? ?? [];

          totalCards += cards.length;

          for (var c in cards) {
            if (c is Map) {
              int interval = c['interval'] ?? 0;
              Timestamp? nextReviewTs = c['nextReviewDate'];
              DateTime? nextReview = nextReviewTs?.toDate();

              if (interval >= 21) {
                masteredCards++;
              }
              if (nextReview == null || nextReview.isBefore(now) || nextReview.isAtSameMomentAs(now)) {
                dueCards++;
                if (sampleCard == null && c['front'] != null && c['back'] != null) {
                  sampleCard = Map<String, dynamic>.from(c);
                  sampleDeckTitle = title;
                }
              }
            }
          }
        }

        final buffer = StringBuffer('🃏 **ফ্ল্যাশকার্ড ডেক সারসংক্ষেপ:**\n\n');
        buffer.writeln('• মোট ডেক: **${decksSnap.docs.length}টি**');
        buffer.writeln('• মোট কার্ড: **$totalCards টি**');
        buffer.writeln('• আজকে রিভিশন বাকি (Due): **$dueCards টি**');
        buffer.writeln('• সম্পূর্ণ আয়ত্তে (Mastered): **$masteredCards টি**\n');

        if (sampleCard != null) {
          buffer.writeln('🎯 **আজকের ফ্ল্যাশকার্ড কুইজ (`$sampleDeckTitle`):**');
          buffer.writeln('❓ **প্রশ্ন:** ${sampleCard['front']}');
          buffer.writeln('\n👉 **উত্তর:** ||${sampleCard['back']}||');
          buffer.writeln('\n*(সম্পূর্ণ ডেক প্র্যাকটিস করতে অ্যাপের Flashcards স্ক্রিন খুলুন)*');
        } else {
          buffer.writeln('🎉 আজকের মতো আপনার সব ফ্ল্যাশকার্ড রিভিশন সম্পন্ন হয়েছে!');
        }

        setState(() {
          _messages.add(
            BotChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: buffer.toString(),
              isUser: false,
              timestamp: DateTime.now(),
              mode: 'study_info',
            ),
          );
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '🃏 **ফ্ল্যাশকার্ড:** অফলাইনে ডেক লোড করা সম্ভব হয়নি। সংযোগ চেক করুন।',
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

  // ==================== STUDY ANALYTICS SUMMARY ====================
  Future<void> _sendStudyAnalyticsSummary() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '⚠️ স্টাডি অ্যানালিটিক্স দেখতে অনুগ্রহ করে অ্যাপে লগইন করুন।',
            isUser: false,
            timestamp: DateTime.now(),
            mode: 'cmd',
          ),
        );
      });
      return;
    }

    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('dailyRoutines')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      int totalCompletedTasks = 0;
      int totalMinutes = 0;
      Map<String, int> subjectMinutes = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final tasks = data['tasks'] as List<dynamic>? ?? [];

        for (var t in tasks) {
          if (t is Map) {
            final isDone = t['isCompleted'] == true || t['status'] == 'completed';
            final duration = (t['completedDurationMinutes'] ?? t['totalDurationMinutes'] ?? 0) as int;
            final sub = (t['subject'] ?? t['category'] ?? 'অন্যান্য').toString().trim();

            if (isDone) totalCompletedTasks++;
            totalMinutes += duration;

            if (duration > 0 && sub.isNotEmpty) {
              subjectMinutes[sub] = (subjectMinutes[sub] ?? 0) + duration;
            }
          }
        }
      }

      final totalHours = (totalMinutes / 60).toStringAsFixed(1);
      final daysTracked = snapshot.docs.length;

      final buffer = StringBuffer('📈 **গত ৩০ দিনের স্টাডি অ্যানালিটিক্স:**\n\n');
      buffer.writeln('⏱️ মোট পড়াশোনার সময়: **$totalHours ঘণ্টা** ($totalMinutes মিনিট)');
      buffer.writeln('✅ সম্পন্ন টাস্ক সংখ্যা: **$totalCompletedTasks টি**');
      buffer.writeln('📅 রুটিন রেকর্ডকৃত দিন: **$daysTracked দিন**\n');

      if (subjectMinutes.isNotEmpty) {
        final sortedSubs = subjectMinutes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        buffer.writeln('📚 **সর্বোচ্চ সময় দেওয়া বিষয়সমূহ:**');
        for (var entry in sortedSubs.take(4)) {
          final h = (entry.value / 60).toStringAsFixed(1);
          buffer.writeln('• ${entry.key}: **$h ঘণ্টা** (${entry.value} মিনিট)');
        }
      }

      buffer.writeln('\n💡 **বটের মতামত:** ');
      if (totalMinutes > 1200) {
        buffer.writeln('চমৎকার অধ্যবসায়! আপনি বেশ চমৎকার ধারাবাহিকতা বজায় রাখছেন। এভাবে চললে লক্ষ্য অর্জন সুনিশ্চিত!');
      } else if (totalMinutes > 0) {
        buffer.writeln('ভালো অগ্রগতি! তবে প্রতিদিন নির্দিষ্ট সময়ে একটানা ২-৩ ঘণ্টা পড়ার অভ্যাস গড়ে তুললে প্রগ্রেস দ্বিগুণ হবে।');
      } else {
        buffer.writeln('প্রতিদিন টাস্ক কমপ্লিট করার পর রুটিনে সময় রেকর্ড করুন, বট আপনার অগ্রগতি নিখুঁতভাবে বিশ্লেষণ করবে!');
      }

      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: buffer.toString(),
            isUser: false,
            timestamp: DateTime.now(),
            mode: 'study_info',
          ),
        );
      });
    } catch (e) {
      setState(() {
        _messages.add(
          BotChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '📈 **অ্যানালিটিক্স:** অফলাইনে স্টাডি হিস্ট্রি লোড করা সম্ভব হয়নি। সংযোগ চেক করুন।',
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

  void _sendHelpMenu() {
    setState(() {
      _messages.add(
        BotChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: '📋 **StudyMate Bot সকল কমান্ড ও গাইড:**\n\n'
              '📅 `/routine` — আজকের রুটিন ও লাইভ টাস্ক বিশ্লেষণ\n'
              '🔄 `/revision` — ১-৪-৭ স্পেসড রিপিটেশন রিভিশন শিডিউল\n'
              '⏳ `/countdown` — পরীক্ষার দিন গণনা ও ডেডলাইন ট্র্যাকিং\n'
              '🕌 `/prayer` — নামাজের সময়সূচি ও পড়াশোনার দু’আ\n'
              '📖 `/vocab` — বিসিএস ও ব্যাংক পরীক্ষার হাই-ফ্রিকোয়েন্সি ভোকাবুলারি\n'
              '🃏 `/flashcard` — সক্রিয় ডেক রিভিউ ও কুইজ চ্যালেঞ্জ\n'
              '📈 `/analytics` — পড়াশোনার মোট সময় ও বিষয়ভিত্তিক অগ্রগতি\n'
              '🎯 `/quiz` — বিসিএস ও সাধারণ জ্ঞানের লাইভ কুইজ খেলা\n'
              '💡 `/motivate` — পড়ার মন বসানোর অনুপ্রেরণামূলক উক্তি\n'
              '📚 `/bcs` — বিসিএস পরীক্ষার ২০০ নম্বরের মানবণ্টন ও গাইড\n'
              '📿 `/tasbeeh` — দৈনিক সংক্ষিপ্ত যিকির ও স্মরণিকা\n'
              '🧮 `/calc [হিসাব]` — যেমন: `/calc 120 / 4` সরাসরি হিসাব\n'
              '🧹 `/clear` — মেসেজ হিস্ট্রি পরিষ্কার করা\n\n'
              '💡 এছাড়া যেকোনো বিষয় যেমন *"নজরুল"*, *"সংবিধান"*, *"কারক"*, *"Tense"*, *"গণিত সূত্র"* লিখে পাঠালেই তাৎক্ষণিক নোট পেয়ে যাবেন!',
          isUser: false,
          timestamp: DateTime.now(),
          mode: 'cmd',
        ),
      );
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  void _sendBcsInfo() {
    setState(() {
      _messages.add(
        BotChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: _matchKnowledgeBase('বিসিএস', 'বিসিএস'),
          isUser: false,
          timestamp: DateTime.now(),
          mode: 'study_info',
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
              text: '🧮 **হিসাব ফলাফল:** `$expr` = **$formattedResult**',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                      color: Colors.greenAccent.shade700,
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
                        color: Colors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('BOT', style: TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Text(
                  '🟢 স্মার্ট স্টাডি অ্যাসিস্ট্যান্ট (১০০% প্রস্তুত)',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'রুটিন বিশ্লেষণ',
            icon: const Icon(Icons.analytics_rounded, color: Colors.teal),
            onPressed: _sendRoutineAnalysis,
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'clear') _clearChat();
              if (val == 'routine') _sendRoutineAnalysis();
              if (val == 'help') _sendHelpMenu();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'routine', child: Text('📊 রুটিন অ্যানালাইসিস')),
              const PopupMenuItem(value: 'help', child: Text('কমান্ড তালিকা (/help)')),
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

            // Suggestion Chips (Telegram style quick command buttons)
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _buildQuickChip('📊 আজকের রুটিন', () => _sendRoutineAnalysis()),
                  _buildQuickChip('🔄 ১-৪-৭ রিভিশন', () => _sendRevisionAnalysis()),
                  _buildQuickChip('⏳ পরীক্ষার কাউন্টডাউন', () => _sendExamCountdown()),
                  _buildQuickChip('🕌 নামাজের সময়', () => _sendPrayerTimes()),
                  _buildQuickChip('📖 ভোকাবুলারি', () => _sendVocabChallenge()),
                  _buildQuickChip('🃏 ফ্ল্যাশকার্ড', () => _sendFlashcardReview()),
                  _buildQuickChip('📈 স্টাডি সময়', () => _sendStudyAnalyticsSummary()),
                  _buildQuickChip('🎯 কুইজ', () => _sendQuizQuestion()),
                  _buildQuickChip('💡 মোটিভেশন', () => _sendMotivation()),
                  _buildQuickChip('📚 বিসিএস সিলেবাস', () => _sendBcsInfo()),
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
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _inputController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _handleSubmitted,
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: 'প্রশ্ন বা কমান্ড লিখুন (যেমন: নজরুল, রুটিন)...',
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
        backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
        side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
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
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
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
                                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
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
