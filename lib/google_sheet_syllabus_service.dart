import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'google_sheet_routine_service.dart';

class GoogleSheetSyllabusService {
  static const String _prefKeyCachedSyllabus = 'cached_google_sheet_syllabus_json_v2';
  static const String _prefKeySyllabusUrl = 'saved_google_sheet_syllabus_url';

  /// Save custom syllabus sheet URL
  static Future<void> saveSyllabusUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeySyllabusUrl, url.trim());
  }

  /// Get saved syllabus sheet URL (or fallback to routine sheet url)
  static Future<String?> getSavedSyllabusUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_prefKeySyllabusUrl);
    if (url != null && url.isNotEmpty) return url;
    return GoogleSheetRoutineService.getSavedSheetUrl();
  }

  /// Built-in rich default syllabus tree with all 10 distinct BCS subjects & Bank Job track
  static Map<String, Map<String, List<String>>> getDefaultSyllabusTree() {
    return {
      "১. বাংলা ভাষা ও সাহিত্য (৩৫)": {
        "প্রাচীন যুগ": [
          "চর্যাপদ ও পদকর্তা",
          "প্রাচীন যুগের ভাষা ও সাহিত্যধারা",
          "সমকালীন সমাজ ও সংস্কৃতি"
        ],
        "মধ্যযুগ": [
          "শ্রীকৃষ্ণকীর্তন কাব্য",
          "মঙ্গলকাব্য (মনসামঙ্গল, চণ্ডীমঙ্গল, অন্নদামঙ্গল)",
          "বৈষ্ণব পদাবলী ও পদকর্তা",
          "অনুবাদ সাহিত্য ও প্রণয়োপাখ্যান",
          "মরমি ও নাথ সাহিত্য",
          "আরাকান রাজসভা ও শাহ মুহম্মদ সগীর"
        ],
        "আধুনিক যুগ": [
          "ফোর্ট উইলিয়াম কলেজ ও গদ্যের সূচনা",
          "ঈশ্বরচন্দ্র বিদ্যাসাগর ও অক্ষয়কুমার দত্ত",
          "মাইকেল মধুসূদন দত্ত ও মহাকাব্য",
          "বঙ্কিমচন্দ্র চট্টোপাধ্যায় ও উপন্যাস",
          "রবীন্দ্রনাথ ঠাকুর ও রবীন্দ্র সাহিত্য",
          "কাজী নজরুল ইসলাম ও বিদ্রোহী চেতনা",
          "আধুনিক নাটক, কাব্য ও সাময়িকপত্র",
          "পঞ্চপাণ্ডব ও মুক্তিযুদ্ধভিত্তিক সাহিত্য"
        ],
        "বাংলা ব্যাকরণ": [
          "ধ্বনি, বর্ণ ও উচ্চারণ",
          "বানান শুদ্ধি ও ণ-ত্ব ও ষ-ত্ব বিধান",
          "শব্দ ও শব্দের উৎস",
          "সন্ধি ও সমাস",
          "কারক ও বিভক্তি",
          "বাক্য রূপান্তর ও বাচ্য",
          "প্রত্যয় ও উপসর্গ",
          "বাগধারা ও প্রবাদ-প্রবচন",
          "প্রয়োগ-অপপ্রয়োগ ও পারিভাষিক শব্দ"
        ]
      },
      "২. ইংরেজি ভাষা ও সাহিত্য (English - ৩৫)": {
        "Grammar Foundation": [
          "Parts of Speech & Identification",
          "Subject-Verb Agreement",
          "Tense & Sequence of Tenses",
          "Preposition & Group Verbs",
          "Sentence Correction & Dangling Modifier",
          "Narration & Voice Change",
          "Conditionals & Inversion"
        ],
        "Vocabulary & Verbal": [
          "Synonym & Antonym",
          "Analogy",
          "Idioms & Phrases",
          "One Word Substitution",
          "Spellings & Confusing Words",
          "Sentence Completion & Fillers"
        ],
        "English Literature": [
          "Old & Middle English Period",
          "Elizabethan & Jacobean Period (Shakespeare, Marlowe)",
          "Romantic Period (Wordsworth, Keats, Shelley)",
          "Victorian Period (Tennyson, Dickens)",
          "Modern & Post-Modern Literature",
          "Famous Quotes & Literary Terms"
        ]
      },
      "৩. বাংলাদেশ বিষয়াবলী (৩০)": {
        "ইতিহাস ও মুক্তিযুদ্ধ": [
          "প্রাচীন বাংলার জনপদ ও সুলতানি আমল",
          "মুঘল শাসন ও বারোভূঁইয়া",
          "ব্রিটিশ শাসন ও ঔপনিবেশিক আন্দোলন",
          "ভাষা আন্দোলন (১৯৪৭-১৯৫২)",
          "যুক্তফ্রন্ট ও ৬ দফা আন্দোলন",
          "১৯৬৯-এর গণঅভ্যুত্থান ও ৭০-এর নির্বাচন",
          "মহান মুক্তিযুদ্ধ ও বাংলাদেশের স্বাধীনতা (১৯৭১)"
        ],
        "সংবিধান ও সরকার ব্যবস্থা": [
          "সংবিধানের পটভূমি ও মূলনীতি",
          "সংবিধানের গুরুত্বপূর্ণ অনুচ্ছেদ ও সংশোধনী",
          "শাসন বিভাগ, বিচার বিভাগ ও আইনসভা",
          "স্থানীয় সরকার ব্যবস্থা ও সুশাসন",
          "জাতীয় সংসদ ও নির্বাচন ব্যবস্থা"
        ],
        "অর্থনীতি ও ভূগোল": [
          "বাংলাদেশের ভূপ্রকৃতি ও নদ-নদী",
          "অর্থনৈতিক সমীক্ষা ও সাম্প্রতিক বাজেট",
          "কৃষি, শিল্প, বাণিজ্য ও পঞ্চবার্ষিক পরিকল্পনা",
          "মেগা প্রকল্প ও জাতীয় অর্জন"
        ]
      },
      "৪. আন্তর্জাতিক বিষয়াবলী (২০)": {
        "বৈশ্বিক ইতিহাস ও ভূ-রাজনীতি": [
          "প্রথম ও দ্বিতীয় বিশ্বযুদ্ধ এবং ঠান্ডা যুদ্ধ",
          "আন্তর্জাতিক সীমানা ও ভূ-রাজনীতি",
          "আন্তর্জাতিক সামরিক ও রাজনৈতিক জোট (NATO, BRICS, Quad)",
          "আন্তর্জাতিক নিরাপত্তা ও পরাশক্তি রাজনীতি"
        ],
        "সংস্থা ও চুক্তি": [
          "জাতিসংঘ ও এর অঙ্গসংস্থাসমূহ",
          "আন্তর্জাতিক আর্থিক প্রতিষ্ঠান (WB, IMF, ADB)",
          "আন্তর্জাতিক পরিবেশ চুক্তি ও সম্মেলন (COP, প্যারিস চুক্তি)",
          "আঞ্চলিক সংস্থা (SAARC, ASEAN, EU, BIMSTEC)"
        ],
        "সাম্প্রতিক আন্তর্জাতিক ঘটনাবলি": [
          "বৈশ্বিক কূটনীতি ও সংকট",
          "আন্তর্জাতিক পুরস্কার ও সম্মেলন",
          "সাম্প্রতিক ভূ-কৌশলগত বিরোধ ও চুক্তি"
        ]
      },
      "৫. ভূগোল, পরিবেশ ও দুর্যোগ ব্যবস্থাপনা (১০)": {
        "প্রাকৃতিক ভূগোল (বাংলাদেশ ও বিশ্ব)": [
          "বাংলাদেশের ভূ-প্রাকৃতিক বৈশিষ্ট্য ও ভূ-তত্ত্ব",
          "নদ-নদী, পাহাড় ও উপকূলীয় অঞ্চল",
          "বাংলাদেশের আবহাওয়া ও জলবায়ু",
          "বৈশ্বিক জলবায়ু অঞ্চল ও ভূমিরূপ"
        ],
        "পরিবেশ ও বাস্তুতন্ত্র": [
          "বাস্তুতন্ত্র ও পরিবেশ দূষণ (বায়ু, পানি, মাটি)",
          "জীববৈচিত্র্য ও সংরক্ষণ ব্যবস্থাপনা",
          "গ্রিনহাউস প্রতিক্রিয়া ও ওজোনস্তর ক্ষয়",
          "পরিবেশ আইন ও টেকসই উন্নয়ন (SDG)"
        ],
        "প্রাকৃতিক দুর্যোগ ও ব্যবস্থাপনা": [
          "বন্যা, ঘূর্ণিঝড়, সাইক্লোন ও জলোচ্ছ্বাস",
          "ভূমিকম্প, সুনামি ও ভূমিধস",
          "খরা ও নদীভাঙন",
          "দুর্যোগের পূর্বাভাস, প্রশমন ও উদ্ধার কার্যক্রম"
        ],
        "মানচিত্র ও সম্পদ": [
          "মানচিত্র পাঠ, স্কেল ও প্রতীক",
          "অক্ষাংশ, দ্রাঘিমাংশ ও সময় নির্ধারণ",
          "প্রাকৃতিক সম্পদ ব্যবস্থাপনা ও GIS ধারণা"
        ]
      },
      "৬. সাধারণ বিজ্ঞান (১৫)": {
        "ভৌত বিজ্ঞান (Physical Science)": [
          "পদার্থের অবস্থা ও গঠন",
          "বল, গতি ও মহাকর্ষ সূত্র",
          "কাজ, ক্ষমতা ও শক্তি",
          "শব্দ ও তরঙ্গ",
          "আলো, প্রতিসরণ ও লেন্স",
          "চৌম্বকত্ব, তড়িৎ ও ইলেকট্রনিক্স"
        ],
        "জীব বিজ্ঞান (Biological Science)": [
          "উদ্ভিদ ও প্রাণিকোষের অঙ্গাণু",
          "মানবদেহ: রক্ত সংবহন, হৃদপিণ্ড ও রক্তচাপ",
          "শ্বসন, পরিপাক ও স্নায়ুতন্ত্র",
          "পুষ্টি, খাদ্য উপাদান ও ভিটামিন",
          "সংক্রামক ব্যাধি, ভাইরাস ও রোগ প্রতিরোধ",
          "জিনতত্ত্ব, বংশগতি ও ডিএনএ (DNA)"
        ],
        "আধুনিক বিজ্ঞান ও পৃথিবী": [
          "মহাকাশ গবেষণা ও সৌরজগৎ",
          "বায়ুমণ্ডলের স্তর ও আবহাওয়া",
          "নিউক্লিয়ার শক্তি ও তেজস্ক্রিয়তা",
          "বায়োটেকনোলজি ও ন্যানোটেকনোলজি"
        ]
      },
      "৭. কম্পিউটার ও তথ্যপ্রযুক্তি (১৫)": {
        "কম্পিউটার হার্ডওয়্যার": [
          "কম্পিউটার সংগঠন ও বাস আর্কিটেকচার",
          "CPU, ALU, রেজিস্টার ও কন্ট্রোল ইউনিট",
          "মেমোরি: RAM, ROM, ক্যাশ ও সেকেন্ডারি স্টোরেজ",
          "ইনপুট ও আউটপুট ডিভাইসসমূহ"
        ],
        "সফটওয়্যার ও সিস্টেম": [
          "সিস্টেম সফটওয়্যার ও অ্যাপ্লিকেশন সফটওয়্যার",
          "অপারেটিং সিস্টেম (উইন্ডোজ, লিনাক্স, ম্যাক, অ্যান্ড্রয়েড)",
          "প্রোগ্রামিং ভাষা, কম্পাইলার ও ইন্টারপ্রেটার",
          "ডাটাবেস ম্যানেজমেন্ট সিস্টেম (DBMS)"
        ],
        "নেটওয়ার্ক ও ইন্টারনেট": [
          "নেটওয়ার্ক প্রকারভেদ (LAN, WAN, MAN)",
          "নেটওয়ার্ক টপোলজি ও মিডিয়া (অপটিক্যাল ফাইবার)",
          "প্রোটোকল: TCP/IP, HTTP, FTP, DNS",
          "ক্লাউড কম্পিউটিং ও ভার্চুয়ালাইজেশন"
        ],
        "তথ্যপ্রযুক্তি ও সাইবার নিরাপত্তা": [
          "সাইবার অপরাধ ও ম্যালওয়্যার (ভাইরাস, ওয়ার্ম, ট্রোজান)",
          "তথ্য নিরাপত্তা, এনক্রিপশন ও ফায়ারওয়াল",
          "ই-কমার্স, সোশ্যাল মিডিয়া ও ডিজিটাল ফুটপ্রিন্ট",
          "কৃত্রিম বুদ্ধিমত্তা (AI), রোবোটিক্স ও আইওটি (IoT)"
        ]
      },
      "৮. গাণিতিক যুক্তি (১৫)": {
        "পাটিগণিত (Arithmetic)": [
          "বাস্তব সংখ্যা, ভগ্নাংশ ও লসাগু-গসাগু",
          "শতকরা ও লাভ-ক্ষতি",
          "সরল ও চক্রবৃদ্ধি মুনাফা (সুদকষা)",
          "অনুপাত, সমানুপাত ও মিশ্রণ",
          "ঐকিক নিয়ম, কাজ, নল ও চৌবাচ্চা",
          "গতিবেগ, দূরত্ব ও ট্রেন সংক্রান্ত সমস্যা"
        ],
        "বীজগণিত (Algebra)": [
          "বীজগাণিতিক সূত্রাবলি ও উৎপাদক বিশ্লেষণ",
          "সরল সমীকরণ ও দুই চলকবিশিষ্ট সহসমীকরণ",
          "দ্বিঘাত সমীকরণ ও বহুপদী সমীকরণ",
          "একঘাত ও রৈখিক অসমতা",
          "সূচক ও লগারিদমের নিয়মাবলি",
          "সমান্তর ধারা ও গুণোত্তর ধারা"
        ],
        "জ্যামিতি ও পরিমিতি (Geometry)": [
          "রেখা, কোণ, ত্রিভুজ ও চতুর্ভুজ",
          "বৃত্তের পরিধি, ক্ষেত্রফল ও বৃত্তস্থ উপপাদ্য",
          "পিথাগোরাসের উপপাদ্য ও উচ্চতা-দূরত্ব",
          "ক্ষেত্রফল ও ঘনবস্তু (ত্রিভুজ, সিলিন্ডার, গোলক)"
        ],
        "উচ্চতর বীজগণিত": [
          "সেট ও ভেনচিত্রের প্রয়োগ",
          "বিন্যাস (Permutation)",
          "সমাবেশ (Combination)",
          "সম্ভাব্যতা (Probability)"
        ]
      },
      "৯. মানসিক দক্ষতা (১৫)": {
        "ভাষাগত ও বানান দক্ষতা": [
          "শব্দজোড়, বিপরীত ও সমার্থক ধারণা",
          "বানান শুদ্ধি ও শব্দ বিশ্লেষণ",
          "বাক্য ও অর্থগত যৌক্তিক বিচার"
        ],
        "সমস্যা সমাধান ও রক্তের সম্পর্ক": [
          "রক্তের সম্পর্কীয় সমস্যা (Blood Relations)",
          "দিক ও দূরত্ব নির্ণয় (Direction Sense)",
          "স্থানিক অবস্থান ও ক্রমবিন্যাস (Ranking)"
        ],
        "সংখ্যাগত ও বর্ণানুক্রমিক যুক্তি": [
          "সংখ্যাগত ধারা ও মিসিং নাম্বার (Number Series)",
          "বর্ণমালার ক্রম ও এনালজি (Letter Coding)",
          "কোডিং ও ডিকোডিং (Coding-Decoding)"
        ],
        "যান্ত্রিক ও স্থানিক সম্পর্ক": [
          "দর্পণ ছবি ও পানির প্রতিফলন (Mirror & Water Image)",
          "ঘনক, ডাইস ও পেপার কাটিং",
          "জ্যামিতিক চিত্র গণনা (ত্রিভুজ, চতুর্ভুজ গণন)"
        ],
        "দৈনন্দিন সিদ্ধান্ত ও যুক্তি": [
          "ঘড়ি ও কাঁটার কোণ সমস্যা",
          "ক্যালেন্ডার ও বার নির্ণয়",
          "গাণিতিক প্রতীক প্রতিস্থাপন"
        ]
      },
      "১০. নৈতিকতা, মূল্যবোধ ও সুশাসন (১০)": {
        "নৈতিকতার ভিত্তি ও দর্শন": [
          "নৈতিকতার সংজ্ঞা, প্রকৃতি ও উৎস",
          "নৈতিক দর্শনের মূল ধারা (প্লেটো, এরিস্টটল, কান্ট, বেন্থাম, জন রলস)",
          "ব্যক্তি, সমাজ ও রাষ্ট্রের ভিত্তি হিসেবে নৈতিকতা",
          "পেশাগত নৈতিকতা ও প্রশাসনিক সততা"
        ],
        "মূল্যবোধের স্বরূপ ও বিকাশ": [
          "মূল্যবোধের ধারণা, উপাদান ও শ্রেণিবিভাগ",
          "পারিবারিক, সামাজিক ও গণতান্ত্রিক মূল্যবোধ",
          "মূল্যবোধের অবক্ষয়, কারণ ও প্রতিকার",
          "জাতীয় সংহতি ও মূল্যবোধ শিক্ষা"
        ],
        "সুশাসনের ধারণা ও উপাদান": [
          "সুশাসনের সংজ্ঞা ও বিশ্বব্যাংক/জাতিসংঘের রূপরেখা",
          "স্বচ্ছতা (Transparency) ও জবাবদিহিতা (Accountability)",
          "আইনের শাসন (Rule of Law) ও ন্যায়বিচার",
          "জনঅংশগ্রহণ ও দায়িত্বশীল প্রশাসন"
        ],
        "দুর্নীতি প্রতিরোধ ও আইনি রূপরেখা": [
          "দুর্নীতি দমন কমিশন ও দুর্নীতি প্রতিরোধ কৌশল",
          "জাতীয় শুদ্ধাচার কৌশল (NIS) ও সিটিজেন চার্টার",
          "তথ্য অধিকার আইন, ২০০৯ ও স্বচ্ছতা",
          "ই-গভর্ন্যান্স ও ডিজিটাল প্রশাসনিক সেবা"
        ]
      },
      "💼 ব্যাংক নিয়োগ প্রস্তুতি (Job with Manik)": {
        "সেশন ০১-০৪ (Foundation)": [
          "বাংলা ব্যাকরণ ও সাহিত্য ভিত্তি",
          "English Grammar: Subject-Verb Agreement & Tense",
          "Math: Percentage, Profit-Loss & Ratio",
          "Analytical Reasoning & Odd One Out"
        ],
        "সেশন ০৫-০৮ (Advanced Practice)": [
          "বাংলা: সমার্থক ও বিপরীত শব্দ, ধ্বনি ও বর্ণ",
          "English: Synonym, Antonym, Narration & Modifier",
          "Math: Age Problems, Series & Equation",
          "Analytical: Data Sufficiency (বই ২)",
          "ICT: প্রোগ্রামিং ভাষা ও অনুবাদক"
        ],
        "সেশন ০৯-১২ (Banking & Finance)": [
          "ব্যাংকিং জ্ঞান ও টার্মিনোলজি",
          "বাংলাদেশ ব্যাংক, CAMELS ও মুদ্রানীতি",
          "Math: Probability, Permutation & Combination",
          "Financial Markets & Budget Overview"
        ],
        "সেশন ১৩-১৬ (Revision & Speed Test)": [
          "Banking GK & International Finance",
          "English Comprehension & Sentence Fillers",
          "Math Speed Tricks & Data Interpretation",
          "Full Model Test Revision"
        ]
      }
    };
  }

  /// Load cached syllabus tree, or fallback to default
  static Future<Map<String, Map<String, List<String>>>> loadSyllabusTree() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_prefKeyCachedSyllabus);

    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        // Verify that the cached JSON has the new separated subjects (নৈতিকতা, ভূগোল, মানসিক দক্ষতা)
        if (cachedJson.contains('নৈতিকতা') && cachedJson.contains('ভূগোল') && cachedJson.contains('মানসিক দক্ষতা')) {
          final decoded = json.decode(cachedJson) as Map<String, dynamic>;
          final Map<String, Map<String, List<String>>> result = {};
          for (final subKey in decoded.keys) {
            final subMap = decoded[subKey] as Map<String, dynamic>;
            final Map<String, List<String>> secMap = {};
            for (final secKey in subMap.keys) {
              final list = (subMap[secKey] as List<dynamic>).map((e) => e.toString()).toList();
              secMap[secKey] = list;
            }
            result[subKey] = secMap;
          }
          if (result.isNotEmpty) return result;
        }
      } catch (e) {
        debugPrint('[GoogleSheetSyllabus] Error parsing cached syllabus: $e');
      }
    }

    return getDefaultSyllabusTree();
  }

  /// Fetch dynamic syllabus from Google Sheet and update local tree
  static Future<Map<String, Map<String, List<String>>>> fetchAndCacheSyllabus(String rawUrl) async {
    // 1. Start with default tree containing all 10 BCS subjects
    final tree = getDefaultSyllabusTree();

    try {
      final csv = await GoogleSheetRoutineService.fetchCsvContent(rawUrl);
      final rawLines = const LineSplitter().convert(csv);

      if (rawLines.isNotEmpty) {
        // Parse CSV and look for syllabus blocks or hierarchical columns
        final allRows = rawLines.map((l) => _parseCsvRow(l)).toList();
        _mergeDynamicSyllabusFromCsv(tree, allRows);

        // Cache the updated tree to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKeyCachedSyllabus, json.encode(tree));
        await saveSyllabusUrl(rawUrl);
      }
    } catch (e) {
      debugPrint('[GoogleSheetSyllabus] Error fetching syllabus sheet: $e');
      rethrow;
    }

    return tree;
  }

  /// Helper to map any raw subject name to canonical key
  static String _getCanonicalSubjectKey(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.contains('নৈতিকতা') || lower.contains('সুশাসন') || lower.contains('মূল্যবোধ')) {
      return "১০. নৈতিকতা, মূল্যবোধ ও সুশাসন (১০)";
    }
    if (lower.contains('ভূগোল') || lower.contains('দুর্যোগ') || lower.contains('পরিবেশ')) {
      return "৫. ভূগোল, পরিবেশ ও দুর্যোগ ব্যবস্থাপনা (১০)";
    }
    if (lower.contains('মানসিক')) {
      return "৯. মানসিক দক্ষতা (১৫)";
    }
    if (lower.contains('গণিত') || lower.contains('গাণিতিক')) {
      return "৮. গাণিতিক যুক্তি (১৫)";
    }
    if (lower.contains('কম্পিউটার') || lower.contains('তথ্যপ্রযুক্তি') || lower.contains('আইসিটি') || lower.contains('ict')) {
      return "৭. কম্পিউটার ও তথ্যপ্রযুক্তি (১৫)";
    }
    if (lower.contains('সাধারণ বিজ্ঞান') || lower.contains('বিজ্ঞান') || lower.contains('science')) {
      return "৬. সাধারণ বিজ্ঞান (১৫)";
    }
    if (lower.contains('আন্তর্জাতিক')) {
      return "৪. আন্তর্জাতিক বিষয়াবলী (২০)";
    }
    if (lower.contains('বাংলাদেশ')) {
      return "৩. বাংলাদেশ বিষয়াবলী (৩০)";
    }
    if (lower.contains('ইংরেজি') || lower.contains('english')) {
      return "২. ইংরেজি ভাষা ও সাহিত্য (English - ৩৫)";
    }
    if (lower.contains('বাংলা')) {
      return "১. বাংলা ভাষা ও সাহিত্য (৩৫)";
    }
    if (lower.contains('ব্যাংক') || lower.contains('মানিক') || lower.contains('bank')) {
      return "💼 ব্যাংক নিয়োগ প্রস্তুতি (Job with Manik)";
    }
    return raw.trim();
  }

  /// Merge dynamic sections and topics found in CSV into syllabus tree
  static void _mergeDynamicSyllabusFromCsv(
    Map<String, Map<String, List<String>>> tree,
    List<List<String>> allRows,
  ) {
    for (int r = 0; r < allRows.length; r++) {
      final row = allRows[r];
      if (row.isEmpty) continue;

      // Check for 3-column / 4-column structured syllabus: Subject | Section/Era | Topics
      if (row.length >= 3) {
        final col0 = row[0].trim();
        final col1 = row[1].trim();
        final col2 = row[2].trim();

        // Check if row is a header
        if (col0.toLowerCase().contains('subject') || col0.contains('বিষয়')) continue;

        if (col0.isNotEmpty && col1.isNotEmpty && col2.isNotEmpty) {
          final canonicalSub = _getCanonicalSubjectKey(col0);
          final topics = col2
              .split(RegExp(r'[,;\n•|]'))
              .map((t) => t.trim())
              .where((t) => t.length > 1)
              .toList();

          if (topics.isNotEmpty) {
            tree.putIfAbsent(canonicalSub, () => {});
            tree[canonicalSub]!.putIfAbsent(col1, () => []);
            for (final top in topics) {
              if (!tree[canonicalSub]![col1]!.contains(top)) {
                tree[canonicalSub]![col1]!.add(top);
              }
            }
          }
        }
      }

      // Check for specific subject cells in routine tables
      for (final cell in row) {
        if (cell.contains('বাংলা সাহিত্য') && cell.contains('পর্ব-')) {
          _extractSyllabusParagraph(tree, "১. বাংলা ভাষা ও সাহিত্য (৩৫)", cell);
        } else if (cell.contains('গাণিতিক যুক্তি') && cell.contains('পর্ব-')) {
          _extractSyllabusParagraph(tree, "৮. গাণিতিক যুক্তি (১৫)", cell);
        } else if (cell.contains('সুশাসন') || cell.contains('নৈতিকতা')) {
          _extractSyllabusParagraph(tree, "১০. নৈতিকতা, মূল্যবোধ ও সুশাসন (১০)", cell);
        } else if (cell.contains('ভূগোল')) {
          _extractSyllabusParagraph(tree, "৫. ভূগোল, পরিবেশ ও দুর্যোগ ব্যবস্থাপনা (১০)", cell);
        } else if (cell.contains('Bank Topic') || cell.contains('নির্ধারিত বিষয়')) {
          // Bank session topics in subsequent rows
          if (r + 1 < allRows.length) {
            for (int k = r + 1; k < r + 5 && k < allRows.length; k++) {
              final subRow = allRows[k];
              if (subRow.length >= 4) {
                final sessionName = subRow[2].trim();
                final bankTopics = subRow[3].trim();
                if (sessionName.isNotEmpty && bankTopics.isNotEmpty) {
                  tree.putIfAbsent("💼 ব্যাংক নিয়োগ প্রস্তুতি (Job with Manik)", () => {});
                  final topicList = bankTopics
                      .split(RegExp(r'[,+\n|]'))
                      .map((s) => s.trim())
                      .where((s) => s.length > 2)
                      .toList();
                  tree["💼 ব্যাংক নিয়োগ প্রস্তুতি (Job with Manik)"]![sessionName] = topicList;
                }
              }
            }
          }
        }
      }
    }
  }

  /// Helper to extract "পর্ব-১: ... পর্ব-২: ..." syllabus format
  static void _extractSyllabusParagraph(
    Map<String, Map<String, List<String>>> tree,
    String subject,
    String paragraph,
  ) {
    tree.putIfAbsent(subject, () => {});
    final parts = paragraph.split(RegExp(r'পর্ব-[০-৯0-9]:'));
    for (final p in parts) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) continue;
      final subParts = trimmed.split(':');
      if (subParts.length >= 2) {
        final era = subParts[0].trim();
        final rawTopics = subParts.sublist(1).join(':').trim();
        final topicList = rawTopics
            .split(RegExp(r'[,;\n]'))
            .map((s) => s.replaceAll(RegExp(r'\([0-9.]+\)'), '').trim())
            .where((s) => s.length > 1)
            .toList();

        if (era.isNotEmpty && topicList.isNotEmpty) {
          tree[subject]!.putIfAbsent(era, () => []);
          for (final t in topicList) {
            if (!tree[subject]![era]!.contains(t)) {
              tree[subject]![era]!.add(t);
            }
          }
        }
      }
    }
  }

  /// Parse CSV row helper
  static List<String> _parseCsvRow(String line) {
    final List<String> result = [];
    final StringBuffer current = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if ((char == ',' || char == '\t') && !inQuotes) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString().trim());
    return result;
  }
}
