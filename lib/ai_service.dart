import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class AIService {
  // Gemini models to try, in order. Old models (gemini-1.5-flash, gemini-pro) were
  // shut down by Google, so calls to them always failed and the app silently
  // fell back to offline templates. "gemini-flash-latest" is Google's alias that
  // always points to the newest Flash model; the others are fallbacks.
  static const List<String> _geminiModels = [
    'gemini-flash-latest',
    'gemini-3.5-flash',
    'gemini-3.1-flash-lite',
    'gemini-2.5-flash',
  ];

  /// Last Gemini error (shown to the user when AI falls back to offline mode)
  static String? lastGeminiError;

  static Future<String> _queryGemini(String prompt, String apiKey) async {
    Object? lastError;
    for (final modelName in _geminiModels) {
      try {
        final model = GenerativeModel(model: modelName, apiKey: apiKey);
        // সময়সীমা: উত্তর না এলে অনন্তকাল লোডিং না দেখিয়ে পরের মডেলে যাওয়া
        final response = await model.generateContent([Content.text(prompt)]).timeout(const Duration(seconds: 45));
        final text = response.text;
        if (text != null && text.trim().isNotEmpty) {
          lastGeminiError = null;
          return text;
        }
        lastError = Exception('Empty response from $modelName');
      } catch (e) {
        debugPrint('AIService: $modelName failed: $e');
        lastError = e;
        final msg = e.toString().toLowerCase();
        // Wrong/expired key → no point trying other models
        if (msg.contains('api key') || msg.contains('api_key') || msg.contains('permission')) {
          break;
        }
      }
    }
    lastGeminiError = lastError?.toString();
    throw Exception('Gemini request failed: $lastError');
  }

  /// Returns null if the key works, otherwise a short error message
  static Future<String?> testApiKey(String apiKey) async {
    if (apiKey.isEmpty) return 'Key খালি';
    try {
      await _queryGemini('Reply with the single word: OK', apiKey);
      return null;
    } catch (e) {
      final msg = (lastGeminiError ?? e.toString());
      return msg.length > 160 ? '${msg.substring(0, 160)}...' : msg;
    }
  }

  // Fetch API Key from user's Firestore document
  static Future<String?> getSavedApiKey(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()?['geminiApiKey'] as String?;
      }
    } catch (e) {
      debugPrint('AIService: Error fetching API Key: $e');
    }
    return null;
  }

  // -------------------------------------------------------------
  // 0. Quiz from a note (used by "Generate AI Quiz" in Notes)
  // -------------------------------------------------------------
  static String cleanNoteText(String raw) {
    return raw
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), ' ') // images
        .replaceAll(RegExp(r'<color=[^>]*>|</color>'), '')
        .replaceAllMapped(RegExp(r'\[(.*?)\]\(.*?\)'), (m) => m.group(1) ?? '')
        .replaceAll(RegExp(r'[*_#>`]'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  /// Returns flashcard-style quiz questions ({front, back}) built from the note.
  /// Uses Gemini when a key is available, otherwise builds questions offline.
  static Future<List<Map<String, String>>> generateQuizFromNote(String noteContent, String? apiKey) async {
    final text = cleanNoteText(noteContent);
    if (text.isEmpty) return [];

    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final limited = text.length > 6000 ? text.substring(0, 6000) : text;
        final prompt = """
You are a study assistant. Read the student's note below and create 6 to 8 quiz questions that test the most important facts in it.
Use the same language as the note (Bengali note → Bengali questions).
Return ONLY a raw JSON array like [{"front": "question", "back": "answer"}]. No markdown, no explanations.

NOTE:
$limited
""";
        final response = await _queryGemini(prompt, apiKey);
        final first = response.indexOf('[');
        final last = response.lastIndexOf(']');
        if (first != -1 && last > first) {
          final List<dynamic> list = jsonDecode(response.substring(first, last + 1));
          final cards = <Map<String, String>>[];
          for (final item in list) {
            if (item is Map && (item['front'] ?? '').toString().trim().isNotEmpty) {
              cards.add({
                'front': item['front'].toString().trim(),
                'back': (item['back'] ?? '').toString().trim(),
              });
            }
          }
          if (cards.isNotEmpty) return cards;
        }
      } catch (e) {
        debugPrint('AIService: generateQuizFromNote via Gemini failed: $e');
      }
    }

    // ---- Offline quiz builder ----
    final cards = <Map<String, String>>[];
    final lines = text
        .split(RegExp(r'\n+'))
        .map((l) => l.replaceFirst(RegExp(r'^[•\-\d\.\)\s]+'), '').trim())
        .where((l) => l.length > 3)
        .toList();

    // 1) "Term: definition" / "Term – definition" lines → "Term কী?"
    for (final line in lines) {
      final m = RegExp(r'^(.{2,60}?)\s*[:：–—]\s*(.{3,})$').firstMatch(line);
      if (m != null) {
        cards.add({'front': '${m.group(1)!.trim()} — কী/কে?', 'back': m.group(2)!.trim()});
      }
      if (cards.length >= 8) break;
    }

    // 2) Fill in the blank: hide the longest word of a sentence
    if (cards.length < 8) {
      final sentences = text
          .split(RegExp(r'(?<=[।\.\?!])\s+|\n+'))
          .map((s) => s.trim())
          .where((s) => s.split(' ').length >= 5 && !s.contains(':'))
          .toList();
      for (final sentence in sentences) {
        final words = sentence.split(' ');
        String longest = '';
        for (final w in words) {
          final clean = w.replaceAll(RegExp(r'[,;।\.\?!()"]'), '');
          if (clean.length > longest.length) longest = clean;
        }
        if (longest.length < 3) continue;
        cards.add({
          'front': 'শূন্যস্থান পূরণ করুন:\n${sentence.replaceFirst(longest, '______')}',
          'back': longest,
        });
        if (cards.length >= 8) break;
      }
    }
    return cards;
  }

  // -------------------------------------------------------------
  // 1. Flashcards Generator
  // -------------------------------------------------------------
  static Future<List<Map<String, String>>> generateFlashcards(String topic, String? apiKey) async {
    final cleanTopic = topic.trim().toLowerCase();

    // Check if API Key is available
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final prompt = '''
You are a helpful study assistant. Generate exactly 5 flashcards for active recall study on the topic or prompt: "$topic".
Return ONLY a valid JSON array of objects, where each object has exactly two fields: "front" (the question) and "back" (the answer).
Return the questions and answers in the same language as the prompt (if the prompt is in Bengali, return in Bengali; if in English, return in English).
Do not write any markdown code blocks (like ```json), explanations, or preamble. Just return the raw JSON array.
Example format:
[
  {"front": "Question 1", "back": "Answer 1"},
  {"front": "Question 2", "back": "Answer 2"}
]
''';
        final response = await _queryGemini(prompt, apiKey);
        
        String cleanText = response;
        int firstBracket = cleanText.indexOf('[');
        int lastBracket = cleanText.lastIndexOf(']');
        if (firstBracket != -1 && lastBracket != -1 && lastBracket > firstBracket) {
          cleanText = cleanText.substring(firstBracket, lastBracket + 1);
        }

        final List<dynamic> parsedList = jsonDecode(cleanText.trim());
        final List<Map<String, String>> cards = [];
        for (var item in parsedList) {
          if (item is Map) {
            cards.add({
              'front': (item['front'] ?? '').toString(),
              'back': (item['back'] ?? '').toString(),
            });
          }
        }
        return cards;
      } catch (e) {
        debugPrint('AIService: generateFlashcards failed: $e. Falling back to local...');
      }
    }

    // Local catalog fallback
    if (cleanTopic.contains('নজরুল') || cleanTopic.contains('nazrul')) {
      return [
        {
          'front': 'কাজী নজরুল ইসলামকে কী উপাধি দেওয়া হয়েছে?',
          'back': 'তাঁকে বাংলাদেশের "জাতীয় কবি" এবং বাংলা সাহিত্যের ইতিহাসে "বিদ্রোহী কবি" উপাধি দেওয়া হয়েছে।'
        },
        {
          'front': 'কাজী নজরুল ইসলামের জন্ম কত সালে এবং কোথায়?',
          'back': 'তিনি ২৪শে মে, ১৮৯৯ সালে ভারতের পশ্চিমবঙ্গের বর্ধমান জেলার চুরুলিয়া গ্রামে জন্মগ্রহণ করেন।'
        },
        {
          'front': 'নজরুলের বিখ্যাত "বিদ্রোহী" কবিতাটি কত সালে প্রকাশিত হয়?',
          'back': '"বিদ্রোহী" কবিতাটি ১৯২১ সালের ডিসেম্বর মাসে রচিত হয় এবং ১৯২২ সালে তাঁর "অগ্নিবীণা" কাব্যের অংশ হিসেবে প্রকাশিত হয়।'
        },
        {
          'front': 'কাজী নজরুল ইসলামের কয়েকটি বিখ্যাত সাহিত্যকর্মের নাম বলুন।',
          'back': 'তাঁর বিখ্যাত কাব্যের মধ্যে রয়েছে অগ্নিবীণা, বিষের বাঁশী, দোলন-চাঁপা। উপন্যাসের মধ্যে বাঁধন হারা, এবং বিখ্যাত নাটক ঝিলিমিলি।'
        },
        {
          'front': 'নজরুল কবে বাংলাদেশে স্থায়ীভাবে আসেন এবং কবে মৃত্যুবরণ করেন?',
          'back': '১৯৭২ সালে স্বাধীন বাংলাদেশের তৎকালীন সরকার তাঁকে সপরিবারে ঢাকায় আনেন। তিনি ২৯শে আগস্ট, ১৯৭৬ সালে ঢাকায় মৃত্যুবরণ করেন।'
        },
      ];
    } else if (cleanTopic.contains('রবীন্দ্রনাথ') || cleanTopic.contains('রবী') || cleanTopic.contains('tagore') || cleanTopic.contains('ঠাকুর')) {
      return [
        {
          'front': 'রবীন্দ্রনাথ ঠাকুর কত সালে নোবেল পুরস্কার লাভ করেন এবং কোন গ্রন্থের জন্য?',
          'back': 'তিনি ১৯১৩ সালে তাঁর বিখ্যাত কাব্যগ্রন্থ "গীতাঞ্জলি" (Song Offerings) এর জন্য প্রথম অ-ইউরোপীয় হিসেবে সাহিত্যে নোবেল পুরস্কার লাভ করেন।'
        },
        {
          'front': 'রবীন্দ্রনাথ ঠাকুরের জন্ম ও মৃত্যু সাল কত?',
          'back': 'তিনি ৭ই মে, ১৮৬১ সালে কলকাতার জোড়াসাঁকোর ঠাকুর পরিবারে জন্মগ্রহণ করেন এবং ৭ই আগস্ট, ১৯৪১ সালে মৃত্যুবরণ করেন।'
        },
        {
          'front': 'রবীন্দ্রনাথ ঠাকুর রচিত কোন কোন গান দুটি দেশের জাতীয় সঙ্গীত হিসেবে গৃহীত হয়েছে?',
          'back': 'ভারতের জাতীয় সঙ্গীত "জনগণমন-অধিনায়ক জয় হে" এবং বাংলাদেশের জাতীয় সঙ্গীত "আমার সোনার বাংলা" রবীন্দ্রনাথ ঠাকুরের রচনা।'
        },
        {
          'front': 'রবীন্দ্রনাথের কয়েকটি বিখ্যাত উপন্যাসের নাম বলুন।',
          'back': 'তাঁর বিখ্যাত উপন্যাসগুলোর মধ্যে চোখের বালি, গোরা, ঘরে বাইরে, এবং শেষের কবিতা অন্যতম।'
        },
        {
          'front': 'শান্তিনিকেতনে রবীন্দ্রনাথ ঠাকুর কর্তৃক প্রতিষ্ঠিত বিখ্যাত বিশ্ববিদ্যালয়ের নাম কী?',
          'back': 'বিশ্বভারতী বিশ্ববিদ্যালয় (Visva-Bharati University), যা ১৯২১ সালে তিনি শান্তিনিকেতনে প্রতিষ্ঠা করেন।'
        },
      ];
    } else if (cleanTopic.contains('flutter') || cleanTopic.contains('dart')) {
      return [
        {
          'front': 'What is Flutter?',
          'back': 'Flutter is an open-source UI software development kit created by Google for building natively compiled applications for mobile, web, and desktop from a single codebase.'
        },
        {
          'front': 'What programming language is used in Flutter?',
          'back': 'Flutter applications are written in Dart, an object-oriented, class-based language with static typing, also developed by Google.'
        },
        {
          'front': 'Difference between Stateless and Stateful widgets?',
          'back': 'StatelessWidgets are immutable and cannot change their state during runtime. StatefulWidgets maintain a mutable state that can trigger a UI redraw when updated using setState().'
        },
        {
          'front': 'What is Hot Reload in Flutter?',
          'back': 'Hot Reload injects updated source code files into the running Dart VM, allowing developers to see code changes instantly in the UI without losing the current app state.'
        },
        {
          'front': 'What is Impeller in Flutter?',
          'back': 'Impeller is Flutter\'s next-generation rendering engine designed to deliver predictable, high-performance graphics and eliminate shader compilation jank.'
        },
      ];
    }

    // Default tips
    return [
      {
        'front': 'What is Active Recall?',
        'back': 'Active recall is an efficient learning method that involves testing your memory by actively retrieving information from your brain, rather than passively reading a textbook.'
      },
      {
        'front': 'What is Spaced Repetition?',
        'back': 'Spaced repetition is a learning technique performed with flashcards, where cards are reviewed at increasing intervals (e.g., 1 day, 3 days, 7 days) to strengthen long-term memory retention.'
      },
      {
        'front': 'What is the Pomodoro Technique?',
        'back': 'A time management system that breaks work into intervals, traditionally 25 minutes of studying followed by a 5-minute break, to maintain focus and prevent fatigue.'
      },
    ];
  }

  // -------------------------------------------------------------
  // 2. Note Summarization
  // -------------------------------------------------------------
  static Future<String> summarizeNote(String content, String? apiKey) async {
    if (content.trim().isEmpty) return '';

    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final prompt = '''
You are an expert academic summarizer. Summarize the following note content in a clean, structured way.
Include:
- A brief general summary paragraph.
- Key Takeaways (bullet points).
Format the response using clean Markdown.
Keep the summary in the same language as the input content (e.g. if the note is in Bengali, write in Bengali).

Content:
$content
''';
        final response = await _queryGemini(prompt, apiKey);
        return response.trim();
      } catch (e) {
        debugPrint('AIService: summarizeNote failed: $e. Falling back to local...');
      }
    }

    // Local fallback summarizer (basic paragraph extraction)
    final words = content.split(' ');
    final sample = words.take(min(words.length, 30)).join(' ');
    
    return '''
### 📝 AI Summary (Fallback Mode)
*এই সামারিটি এপিআই কী ছাড়া লোকাল ডেমো হিসেবে দেখানো হয়েছে। সম্পূর্ণ সামারির জন্য এপিআই কী সেট করুন।*

**মূল সারসংক্ষেপ:**
$sample...

**মূল আলোচ্য বিষয়সমূহ:**
- নোটে সংক্ষেপে আপনার আলোচনার মূল বিষয়গুলো চিহ্নিত করা হয়েছে।
- পড়াশোনা সহজ করতে গুরুত্বপূর্ণ পয়েন্টগুলো নিয়মিত রিভিউ করুন।
''';
  }

  // -------------------------------------------------------------
  // 3. Write Note Content on a Topic
  // -------------------------------------------------------------
  static Future<String> generateNoteContent(String userPrompt, String? apiKey) async {
    if (userPrompt.trim().isEmpty) return '';
    final cleanPrompt = userPrompt.trim().toLowerCase();

    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final prompt = '''
You are an advanced academic research assistant. Write a comprehensive, well-structured, and highly informative study note on the topic: "$userPrompt".
Provide:
- An introduction.
- Main detailed sections with bullet points or subheadings.
- A summary/conclusion.
Use clean Markdown formatting.
Search the web / use your knowledge to construct a deep and detailed overview.
Write in the same language as the prompt (if the prompt is in Bengali, write in Bengali; if in English, write in English).
''';
        final response = await _queryGemini(prompt, apiKey);
        return response.trim();
      } catch (e) {
        debugPrint('AIService: generateNoteContent failed: $e. Falling back to local...');
      }
    }

    // Local Fallbacks
    if (cleanPrompt.contains('নজরুল') || cleanPrompt.contains('nazrul')) {
      return '''# কাজী নজরুল ইসলাম: বিদ্রোহী কবি

**কাজী নজরুল ইসলাম** (২৪ মে ১৮ญ৯ - ২৯ আগস্ট ১৯৭৬) ছিলেন বিংশ শতাব্দীর অন্যতম জনপ্রিয় বাঙালি কবি, সঙ্গীতজ্ঞ, ঔপন্যাসিক, নাট্যকার ও প্রাবন্ধিক। তিনি বাংলা সাহিত্যের অন্যতম অগ্রদূত এবং বাংলাদেশের **জাতীয় কবি**।

### বাল্যকাল ও শিক্ষা
- ১৮৯৯ সালের ২৪ মে ভারতের পশ্চিমবঙ্গের বর্ধমান জেলার চুরুলিয়া গ্রামে জন্মগ্রহণ করেন।
- তাঁর ডাকনাম ছিল "দুখু মিয়া"। 
- শৈশবে মক্তবে শিক্ষা অর্জন করেন এবং পরবর্তীতে লেটো দলে যোগ দিয়ে গান রচনা শুরু করেন।

### সাহিত্যকর্ম ও অবদান
- **বিদ্রোহী কবি:** ১৯২২ সালে প্রকাশিত "বিদ্রোহী" কবিতার মাধ্যমে তিনি সমকালীন সমাজে অবিচার ও ব্রিটিশ বিরোধী আন্দোলনের মূল প্রতীক হয়ে ওঠেন।
- **সঙ্গীত জগতে অবদান:** তিনি প্রায় ৩,০০০-এর বেশি গান রচনা ও সুরারোপ করেন, যা আজ "নজরুল গীতি" নামে পরিচিত।
- **বিখ্যাত কাব্যগ্রন্থ:** অগ্নিবীণা, বিষের বাঁশী, ছায়ানট, প্রলয়শিখা।

### বাংলাদেশের জাতীয় কবি
১৯৭২ সালে স্বাধীন বাংলাদেশের তৎকালীন সরকার তাঁকে সপরিবারে ঢাকায় নিয়ে আসে এবং রাষ্ট্রীয় মর্যাদা ও জাতীয়তা প্রদান করে। তিনি ২৯ আগস্ট ১৯৭৬ সালে ঢাকায় মৃত্যুবরণ করেন।
''';
    } else if (cleanPrompt.contains('রবীন্দ্রনাথ') || cleanPrompt.contains('tagore') || cleanPrompt.contains('ঠাকুর')) {
      return '''# বিশ্বকবি রবীন্দ্রনাথ ঠাকুর

**রবীন্দ্রনাথ ঠাকুর** (৭ মে ১৮৬১ - ৭ আগস্ট ১৯৪১) ছিলেন অগ্রণী বাঙালি কবি, ঔপন্যাসিক, সঙ্গীতস্রষ্টা, নাট্যকার, চিত্রশিল্পী, প্রাবন্ধিক ও দার্শনিক। তাঁকে বাংলা সাহিত্যের অন্যতম শ্রেষ্ঠ সাহিত্যিক হিসেবে গণ্য করা হয়।

### নোবেল অর্জন ও সম্মাননা
- **১৯১৩ সালে সাহিত্যে নোবেল পুরস্কার লাভ করেন** তাঁর বিখ্যাত অনুবাদ কাব্যগ্রন্থ "গীতাঞ্জলি" (Song Offerings)-এর জন্য। তিনিই ছিলেন প্রথম অ-ইউরোপীয় নোবেল বিজয়ী।
- তিনি বিশ্বভারতী বিশ্ববিদ্যালয় প্রতিষ্ঠা করেন যা শান্তিনিকেতনে অবস্থিত।

### জাতীয় সঙ্গীত
তিনি বিশ্বের একমাত্র কবি যার লেখা গান দুটি পৃথক স্বাধীন দেশের জাতীয় সঙ্গীত হিসেবে ব্যবহৃত হয়:
1. **বাংলাদেশ:** "আমার সোনার বাংলা"
2. **ভারত:** "জনগণমন-অধিনায়ক জয় হে"

### বিখ্যাত সাহিত্যকর্ম
- **কাব্য:** সোনার তরী, মানসী, গীতাঞ্জলি, বলাকা।
- **উপন্যাস:** চোখের বালি, গোরা, ঘরে বাইরে, শেষের কবিতা।
- **ছোটগল্প:** কাবুলিওয়ালা, পোস্টমাস্টার, হৈমন্তী।
''';
    }

    return '''# $userPrompt
*(এটি একটি ডেমো স্টাডি নোট। সম্পূর্ণ অনলাইন জেনারেশনের জন্য ফ্ল্যাশকার্ড পেজের চাবি আইকনে ক্লিক করে আপনার Gemini API Key সেট করুন)*

### আলোচনার বিষয়বস্তু
- **$userPrompt** সম্পর্কিত প্রাসঙ্গিক তথ্য খুব শীঘ্রই যুক্ত করা হবে।
- এপিআই কী যুক্ত থাকলে এআই সরাসরি গুগল জেমিনি নেটওয়ার্ক ব্যবহার করে এই টপিকের ওপর একটি সম্পূর্ণ ৩-৪ পৃষ্ঠার একাডেমিক নোট তৈরি করে দিত।

### কিভাবে এপিআই যুক্ত করবেন?
১. স্টাডিমেট অ্যাপের **Tools -> Flashcards** পেজে যান。
২. ওপরে ডান কোণায় থাকা **VPN Key আইকন**-এ ক্লিক করে আপনার Gemini API Key সেট করুন।
''';
  }

  // -------------------------------------------------------------
  // 4. Study Planner
  // -------------------------------------------------------------
  static bool _hasBengali(String text) {
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (code >= 0x0980 && code <= 0x09FF) {
        return true;
      }
    }
    return false;
  }

  // -------------------------------------------------------------
  // 4. Study Planner
  // -------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> generateStudyPlan(
    String goals,
    String? apiKey, {
    List<Map<String, String>>? subjects,
    double studyHours = 2.0,
  }) async {
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final prompt = '''
You are an expert AI academic counselor. Help a student create a daily study routine containing exactly 4 detailed tasks based on their goals/subject constraints: "$goals".
Return ONLY a valid JSON array of objects, where each object has exactly three fields:
- "title" (String - the main task title, e.g. "Read Biology Chapter 3")
- "category" (String - must be exactly one of: "Study", "Work", "Sports", "Other")
- "durationMinutes" (int - time required in minutes, e.g. 60)

Return the titles in the same language as the prompt (if prompt is in Bengali, return in Bengali).
Do not write any markdown code blocks (like ```json), explanations, or preamble. Just return the raw JSON array.
''';
        final response = await _queryGemini(prompt, apiKey);
        
        String cleanText = response;
        int firstBracket = cleanText.indexOf('[');
        int lastBracket = cleanText.lastIndexOf(']');
        if (firstBracket != -1 && lastBracket != -1 && lastBracket > firstBracket) {
          cleanText = cleanText.substring(firstBracket, lastBracket + 1);
        }

        final List<dynamic> parsedList = jsonDecode(cleanText.trim());
        final List<Map<String, dynamic>> tasks = [];
        for (var item in parsedList) {
          if (item is Map) {
            tasks.add({
              'title': (item['title'] ?? '').toString(),
              'category': (item['category'] ?? 'Study').toString(),
              'durationMinutes': int.tryParse(item['durationMinutes'].toString()) ?? 45,
            });
          }
        }
        return tasks;
      } catch (e) {
        debugPrint('AIService: generateStudyPlan failed: $e. Falling back to local...');
      }
    }

    // Local smart dynamic fallback
    if (subjects == null || subjects.isEmpty) {
      return [
        {'title': 'পড়া শুরু করার প্রস্তুতি ও পরিকল্পনা', 'category': 'Study', 'durationMinutes': 15},
        {'title': 'মূল বিষয়ের গুরুত্বপূর্ণ অধ্যায় রিভিশন', 'category': 'Study', 'durationMinutes': 60},
        {'title': 'পড়াশোনার মাঝে ফোকাস ও মাইন্ড রিফ্রেশমেন্ট', 'category': 'Other', 'durationMinutes': 10},
        {'title': 'নিজের শেখা বিষয়গুলো লিখে নোট তৈরি', 'category': 'Study', 'durationMinutes': 45},
      ];
    }

    final int totalMinutes = (studyHours * 60).toInt();
    final int N = subjects.length;
    
    // Determine break duration
    int breakDuration = 10;
    int totalBreaks = N - 1;
    int totalBreakMinutes = totalBreaks * breakDuration;
    int totalStudyMinutes = totalMinutes - totalBreakMinutes;

    if (totalStudyMinutes < 15 * N) {
      breakDuration = 5;
      totalBreakMinutes = totalBreaks * breakDuration;
      totalStudyMinutes = totalMinutes - totalBreakMinutes;
      if (totalStudyMinutes < 15 * N) {
        breakDuration = 0;
        totalBreakMinutes = 0;
        totalStudyMinutes = totalMinutes;
      }
    }

    final int studyMinutesPerSubject = totalStudyMinutes ~/ N;
    final int remainderMinutes = totalStudyMinutes % N;

    // Detect language: if any subject name or topic has Bengali characters, use Bengali
    bool useBengali = false;
    for (var s in subjects) {
      final subName = s['subject'] ?? '';
      final subTopic = s['topic'] ?? '';
      if (_hasBengali(subName) || _hasBengali(subTopic)) {
        useBengali = true;
        break;
      }
    }

    final List<Map<String, dynamic>> localTasks = [];
    for (int i = 0; i < N; i++) {
      final subMap = subjects[i];
      final String subName = (subMap['subject'] ?? '').trim();
      final String subTopic = (subMap['topic'] ?? '').trim();

      int currentSlotDuration = studyMinutesPerSubject;
      if (i == 0) {
        currentSlotDuration += remainderMinutes;
      }

      // Generate localized titles and notes
      String title = '';
      String notes = '';

      if (useBengali) {
        if (subTopic.isNotEmpty) {
          title = '$subName - $subTopic';
          notes = 'টপিক: $subTopic এর ওপর বিস্তারিত পড়াশোনা ও অনুশীলন সেশন।';
        } else {
          title = '$subName রিভিশন';
          notes = '$subName বিষয়ের গুরুত্বপূর্ণ অংশসমূহ রিভিশন ও প্র্যাকটিস সেশন।';
        }
      } else {
        if (subTopic.isNotEmpty) {
          title = '$subName - $subTopic';
          notes = 'Focus on topic: $subTopic in $subName. Study concepts & practice.';
        } else {
          title = 'Study $subName';
          notes = 'Review key concepts and practice problems for $subName.';
        }
      }

      localTasks.add({
        'title': title,
        'category': 'Study',
        'durationMinutes': currentSlotDuration,
        'subject': subName,
        'notes': notes,
      });

      // Add break if not the last subject and breakDuration > 0
      if (i < N - 1 && breakDuration > 0) {
        String breakTitle = useBengali ? '১০ মিনিটের রিফ্রেশমেন্ট বিরতি' : '10 Mins Refreshment Break';
        String breakNotes = useBengali 
            ? 'একটু হেঁটে আসুন, পানি পান করুন এবং চোখের বিশ্রাম দিন।' 
            : 'Stretch, hydrate, and relax your eyes.';
        localTasks.add({
          'title': breakTitle,
          'category': 'Other',
          'durationMinutes': breakDuration,
          'subject': 'Break',
          'notes': breakNotes,
        });
      }
    }

    return localTasks;
  }

  // -------------------------------------------------------------
  // 5. Dictionary Search (Bilingual English-Bengali)
  // -------------------------------------------------------------
  static Future<Map<String, dynamic>> searchDictionaryWord(String word, String? apiKey) async {
    final cleanWord = word.trim().toLowerCase();

    // 1. If we have the Gemini API key, use it (it is more context-aware and high-quality)
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final prompt = '''
You are a bilingual English-Bengali academic dictionary. Search and analyze the word: "$word".
Return ONLY a valid JSON object with the following fields:
- "word" (String: the queried word, capitalized)
- "pronunciation" (String: English pronunciation hint in Bengali characters, e.g. "নলেজ" or "সাকসেস")
- "ipa" (String: IPA phonetic spelling, e.g. "/ˈnɒl.ɪdʒ/")
- "partOfSpeech" (String: Part of speech in English, e.g. "Noun", "Verb", "Adjective")
- "bengaliMeaning" (String: Primary Bengali meaning)
- "definition" (String: Brief English definition)
- "example" (String: An example sentence in English using the word)
- "exampleBengali" (String: The Bengali translation of that example sentence)
- "synonyms" (List of Strings: 3 synonyms)

Do not write any markdown code blocks (like ```json), explanations, or preamble. Just return the raw JSON object.
''';
        final response = await _queryGemini(prompt, apiKey);
        
        String cleanText = response;
        int firstBrace = cleanText.indexOf('{');
        int lastBrace = cleanText.lastIndexOf('}');
        if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
          cleanText = cleanText.substring(firstBrace, lastBrace + 1);
        }

        final Map<String, dynamic> parsed = jsonDecode(cleanText.trim());
        return {
          'word': (parsed['word'] ?? word).toString(),
          'pronunciation': (parsed['pronunciation'] ?? '').toString(),
          'ipa': (parsed['ipa'] ?? '').toString(),
          'partOfSpeech': (parsed['partOfSpeech'] ?? 'Noun').toString(),
          'bengaliMeaning': (parsed['bengaliMeaning'] ?? '').toString(),
          'definition': (parsed['definition'] ?? '').toString(),
          'example': (parsed['example'] ?? '').toString(),
          'exampleBengali': (parsed['exampleBengali'] ?? '').toString(),
          'synonyms': List<String>.from(parsed['synonyms'] ?? []),
        };
      } catch (e) {
        debugPrint('AIService: searchDictionaryWord Gemini failed: $e. Falling back to public APIs...');
      }
    }

    // 2. Fallback to free public APIs (api.dictionaryapi.dev + Google Translate API) if Gemini fails or is not configured
    try {
      final dictUrl = Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$cleanWord');
      final dictResponse = await http.get(dictUrl);
      
      if (dictResponse.statusCode == 200) {
        final List<dynamic> parsed = jsonDecode(utf8.decode(dictResponse.bodyBytes));
        if (parsed.isNotEmpty) {
          final wordData = parsed[0];
          final wordName = (wordData['word'] ?? word).toString();
          final ipa = (wordData['phonetic'] ?? '').toString();
          
          String partOfSpeech = 'Word';
          String definition = '';
          String example = '';
          List<String> synonyms = [];
          
          if (wordData['meanings'] != null && wordData['meanings'] is List && wordData['meanings'].isNotEmpty) {
            final meaning = wordData['meanings'][0];
            partOfSpeech = (meaning['partOfSpeech'] ?? 'Word').toString();
            
            if (meaning['definitions'] != null && meaning['definitions'] is List && meaning['definitions'].isNotEmpty) {
              final defObj = meaning['definitions'][0];
              definition = (defObj['definition'] ?? '').toString();
              example = (defObj['example'] ?? '').toString();
            }
            if (meaning['synonyms'] != null) {
              synonyms = List<String>.from(meaning['synonyms'].take(3));
            }
          }
          
          // Translate using Google's public translation endpoint
          String bengaliMeaning = '';
          String exampleBengali = '';
          
          try {
            final translateWordUrl = Uri.parse('https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=bn&dt=t&q=${Uri.encodeComponent(wordName)}');
            final twResponse = await http.get(translateWordUrl);
            if (twResponse.statusCode == 200) {
              final twParsed = jsonDecode(utf8.decode(twResponse.bodyBytes));
              bengaliMeaning = twParsed[0][0][0].toString();
            }
            
            if (example.isNotEmpty) {
              final translateExUrl = Uri.parse('https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=bn&dt=t&q=${Uri.encodeComponent(example)}');
              final teResponse = await http.get(translateExUrl);
              if (teResponse.statusCode == 200) {
                final teParsed = jsonDecode(utf8.decode(teResponse.bodyBytes));
                exampleBengali = teParsed[0][0][0].toString();
              }
            }
          } catch (e) {
            debugPrint('AIService: Translation fallback failed: $e');
          }
          
          return {
            'word': wordName,
            'pronunciation': '',
            'ipa': ipa,
            'partOfSpeech': partOfSpeech,
            'bengaliMeaning': bengaliMeaning.isNotEmpty ? bengaliMeaning : 'অনুবাদ পাওয়া যায়নি',
            'definition': definition,
            'example': example,
            'exampleBengali': exampleBengali,
            'synonyms': synonyms,
          };
        }
      }
    } catch (e) {
      debugPrint('AIService: Free Dictionary API fallback failed: $e');
    }

    // 3. Fallback to offline local database if online calls fail
    final Map<String, Map<String, dynamic>> localDb = {
      'knowledge': {
        'word': 'Knowledge',
        'pronunciation': 'নলেজ',
        'ipa': '/ˈnɒl.ɪdʒ/',
        'partOfSpeech': 'Noun',
        'bengaliMeaning': 'জ্ঞান',
        'definition': 'Facts, information, and skills acquired through experience or education.',
        'example': 'Knowledge is power.',
        'exampleBengali': 'জ্ঞানই শক্তি।',
        'synonyms': ['Information', 'Understanding', 'Wisdom']
      },
      'success': {
        'word': 'Success',
        'pronunciation': 'সাকসেস',
        'ipa': '/səkˈses/',
        'partOfSpeech': 'Noun',
        'bengaliMeaning': 'সাফল্য',
        'definition': 'The accomplishment of an aim or purpose.',
        'example': 'Hard work is the key to success.',
        'exampleBengali': 'পরিশ্রমই সাফল্যের চাবিকাঠি।',
        'synonyms': ['Achievement', 'Victory', 'Prosperity']
      },
      'study': {
        'word': 'Study',
        'pronunciation': 'স্টাডি',
        'ipa': '/ˈstʌd.i/',
        'partOfSpeech': 'Noun / Verb',
        'bengaliMeaning': 'অধ্যয়ন করা',
        'definition': 'The devotion of time and attention to acquiring knowledge.',
        'example': 'She is studying for her exams.',
        'exampleBengali': 'সে তার পরীক্ষার জন্য পড়াশোনা করছে।',
        'synonyms': ['Learn', 'Research', 'Analyze']
      },
      'persistence': {
        'word': 'Persistence',
        'pronunciation': 'পারসিসটেন্স',
        'ipa': '/pəˈsɪs.təns/',
        'partOfSpeech': 'Noun',
        'bengaliMeaning': 'অধ্যবসায়',
        'definition': 'Firm or obstinate continuance in a course of action in spite of difficulty.',
        'example': 'His persistence paid off when he won the championship.',
        'exampleBengali': 'যখন সে চ্যাম্পিয়নশিপ জিতেছিল তখন তার অধ্যবসায় কাজে লেগেছিল।',
        'synonyms': ['Perseverance', 'Determination', 'Diligence']
      },
      'curiosity': {
        'word': 'Curiosity',
        'pronunciation': 'কিউরিওসিটি',
        'ipa': '/ˌkjʊə.riˈɒs.ə.ti/',
        'partOfSpeech': 'Noun',
        'bengaliMeaning': 'কৌতূহল',
        'definition': 'A strong desire to know or learn something.',
        'example': 'Her curiosity drove her to explore the ancient ruins.',
        'exampleBengali': 'তার কৌতূহল তাকে প্রাচীন ধ্বংসাবশেষ অন্বেষণ করতে পরিচালিত করেছিল।',
        'synonyms': ['Inquisitiveness', 'Interest', 'Wonder']
      }
    };

    if (localDb.containsKey(cleanWord)) {
      return localDb[cleanWord]!;
    }

    // Default dynamic placeholder if word is not found locally and no internet is available
    return {
      'word': word.toUpperCase(),
      'pronunciation': 'শব্দ',
      'ipa': '/.../',
      'partOfSpeech': 'Word',
      'bengaliMeaning': 'শব্দটির অর্থ খুজে পাওয়া যায়নি',
      'definition': 'Please connect to the internet or add your Gemini API key to query this word.',
      'example': 'You can add your API key in the Flashcards screen.',
      'exampleBengali': 'ফ্ল্যাশকার্ড স্ক্রিনে চাবি আইকন চেপে এপিআই কী বসাতে পারেন।',
      'synonyms': ['Learn', 'Expand', 'Grow']
    };
  }

  // -------------------------------------------------------------
  // ছবি থেকে লেখা (বইয়ের পাতা / খাতার ছবি → টেক্সট), বাংলা ও ইংরেজি দুটোই
  // -------------------------------------------------------------
  static Future<String> extractTextFromImage(Uint8List bytes, String mimeType, String apiKey) async {
    Object? lastError;
    const prompt = '''
Read all the text in this photo of a book page, notes or a whiteboard.
Write it out exactly as it appears, keeping the original language (Bengali stays Bengali, English stays English).
Keep headings, numbered points and line breaks. Use Markdown for headings and lists.
Do not add explanations or translate anything. If no text is visible, reply with: NO_TEXT''';
    for (final modelName in _geminiModels) {
      try {
        final model = GenerativeModel(model: modelName, apiKey: apiKey);
        final response = await model.generateContent([
          Content.multi([TextPart(prompt), DataPart(mimeType, bytes)]),
        ]).timeout(const Duration(seconds: 60));
        final text = response.text?.trim();
        if (text != null && text.isNotEmpty) {
          lastGeminiError = null;
          return text == 'NO_TEXT' ? '' : text;
        }
        lastError = Exception('Empty response from $modelName');
      } catch (e) {
        debugPrint('AIService: image OCR with $modelName failed: $e');
        lastError = e;
        final msg = e.toString().toLowerCase();
        if (msg.contains('api key') || msg.contains('api_key') || msg.contains('permission')) break;
      }
    }
    lastGeminiError = lastError?.toString();
    throw Exception('Could not read the image: $lastError');
  }

  // -------------------------------------------------------------
  // MCQ তৈরি (বিষয় বা নোট থেকে) — [{question, options[4], answer(index), explanation}]
  // -------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> generateMcqs({
    required String topicOrText,
    required String apiKey,
    int count = 10,
    String? subject,
    bool fromText = false,
  }) async {
    final limited = topicOrText.length > 6000 ? topicOrText.substring(0, 6000) : topicOrText;
    final source = fromText
        ? 'Make the questions ONLY from this study text:\n$limited'
        : 'Topic: $limited${subject != null ? ' (subject: $subject)' : ''}. Use the style of Bangladesh competitive exams (BCS, bank jobs, primary teacher).';
    final prompt = '''
You are an exam question writer. Create $count multiple-choice questions with exactly 4 options each and one correct answer.
Write in the same language as the topic/text (Bengali → Bengali). Facts must be correct; skip anything you are not sure about.
$source
Return ONLY a raw JSON array, no markdown:
[{"question": "...", "options": ["...","...","...","..."], "answer": 0, "explanation": "one short line"}]
"answer" is the 0-based index of the correct option.''';
    final response = await _queryGemini(prompt, apiKey);
    final first = response.indexOf('[');
    final last = response.lastIndexOf(']');
    if (first == -1 || last <= first) return [];
    final List<dynamic> list = jsonDecode(response.substring(first, last + 1));
    final out = <Map<String, dynamic>>[];
    for (final item in list) {
      if (item is! Map) continue;
      final options = (item['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final answer = (item['answer'] as num?)?.toInt() ?? -1;
      final q = item['question']?.toString().trim() ?? '';
      if (q.isEmpty || options.length != 4 || answer < 0 || answer > 3) continue;
      out.add({
        'question': q,
        'options': options,
        'answer': answer,
        'explanation': item['explanation']?.toString() ?? '',
      });
    }
    return out;
  }
}
