import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'surah_viewer_screen.dart';

class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({super.key});

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Directory? _appDir;

  // Caching states
  Map<int, bool> _cachedSurahs = {};
  Map<int, bool> _cachedPages = {};

  // Batch download state
  bool _isDownloadingAllSurahs = false;
  double _surahDownloadProgress = 0.0;
  String _surahDownloadStatus = '';

  bool _isDownloadingAllPages = false;
  double _pageDownloadProgress = 0.0;
  String _pageDownloadStatus = '';

  // Page reader states (Hafezi Quran)
  int _currentPage = 1;
  int _currentJuz = 1;
  bool _showPageTranslation = false;
  double _pageArabicFontSize = 22.0;

  // ── 30 Para (Juz) data ─────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> juzData = [
    {'juz': 1,  'bn': 'পারা ১ – আলিফ লাম মীম',          'start': 1,   'end': 21},
    {'juz': 2,  'bn': 'পারা ২ – সায়াকুল',               'start': 22,  'end': 41},
    {'juz': 3,  'bn': 'পারা ৩ – তিলকার রুসুল',          'start': 42,  'end': 62},
    {'juz': 4,  'bn': 'পারা ৪ – লান তানালু',            'start': 63,  'end': 81},
    {'juz': 5,  'bn': 'পারা ৫ – ওয়াল মুহসানাত',         'start': 82,  'end': 100},
    {'juz': 6,  'bn': 'পারা ৬ – লা ইউহিব্বুল্লাহ',      'start': 101, 'end': 121},
    {'juz': 7,  'bn': 'পারা ৭ – ওয়া ইযা সামিউ',        'start': 122, 'end': 141},
    {'juz': 8,  'bn': 'পারা ৮ – ওয়া লাও আন্নানা',       'start': 142, 'end': 161},
    {'juz': 9,  'bn': 'পারা ৯ – কালাল মালা',            'start': 162, 'end': 181},
    {'juz': 10, 'bn': 'পারা ১০ – ওয়া আলামু',           'start': 182, 'end': 200},
    {'juz': 11, 'bn': 'পারা ১১ – ইয়াতাযিররুনা',        'start': 201, 'end': 220},
    {'juz': 12, 'bn': 'পারা ১২ – ওয়ামা মিন দাব্বাহ',    'start': 221, 'end': 241},
    {'juz': 13, 'bn': 'পারা ১৩ – ওয়ামা উবার্রিউ',       'start': 242, 'end': 261},
    {'juz': 14, 'bn': 'পারা ১৪ – রুব্বামা',             'start': 262, 'end': 281},
    {'juz': 15, 'bn': 'পারা ১৫ – সুবহানাল্লাযী',        'start': 282, 'end': 301},
    {'juz': 16, 'bn': 'পারা ১৬ – কালা আলাম',           'start': 302, 'end': 321},
    {'juz': 17, 'bn': 'পারা ১৭ – ইকতারাবা',            'start': 322, 'end': 341},
    {'juz': 18, 'bn': 'পারা ১৮ – কাদ আফলাহা',          'start': 342, 'end': 361},
    {'juz': 19, 'bn': 'পারা ১৯ – ওয়া কালাল্লাযীনা',     'start': 362, 'end': 381},
    {'juz': 20, 'bn': 'পারা ২০ – আম্মান খালাকা',        'start': 382, 'end': 401},
    {'juz': 21, 'bn': 'পারা ২১ – উতলু মা উহিয়া',        'start': 402, 'end': 421},
    {'juz': 22, 'bn': 'পারা ২২ – ওয়ামাইয়াকনুত',        'start': 422, 'end': 440},
    {'juz': 23, 'bn': 'পারা ২৩ – ওয়ামান ইয়াকনুত',      'start': 441, 'end': 461},
    {'juz': 24, 'bn': 'পারা ২৪ – ফামান আযলামু',         'start': 462, 'end': 481},
    {'juz': 25, 'bn': 'পারা ২৫ – ইলাইহি ইউরাদ্দু',      'start': 482, 'end': 501},
    {'juz': 26, 'bn': 'পারা ২৬ – হা মীম',              'start': 502, 'end': 521},
    {'juz': 27, 'bn': 'পারা ২৭ – কালা ফামা খাতবুকুম',   'start': 522, 'end': 541},
    {'juz': 28, 'bn': 'পারা ২৮ – কাদ সামিআল্লাহ',       'start': 542, 'end': 561},
    {'juz': 29, 'bn': 'পারা ২৯ – তাবারাকাল্লাযী',        'start': 562, 'end': 581},
    {'juz': 30, 'bn': 'পারা ৩০ – আম্মা',               'start': 582, 'end': 604},
  ];

  // ── 114 Surah list ──────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> surahList = [
    {'id': 1,   'name': 'Al-Fatihah',     'bn': 'আল-ফাতিহা',         'ar': 'الفاتحة',    'ayahs': 7,   'type': 'Meccan'},
    {'id': 2,   'name': 'Al-Baqarah',     'bn': 'আল-বাকারাহ',        'ar': 'البقرة',     'ayahs': 286, 'type': 'Medinan'},
    {'id': 3,   'name': "Ali 'Imran",     'bn': 'আলি ইমরান',         'ar': 'آل عمران',   'ayahs': 200, 'type': 'Medinan'},
    {'id': 4,   'name': 'An-Nisa',        'bn': 'আন-নিসা',           'ar': 'النساء',     'ayahs': 176, 'type': 'Medinan'},
    {'id': 5,   'name': "Al-Ma'idah",     'bn': "আল-মা'ইদাহ",       'ar': 'المائدة',    'ayahs': 120, 'type': 'Medinan'},
    {'id': 6,   'name': "Al-An'am",       'bn': "আল-আন'আম",         'ar': 'الأنعام',    'ayahs': 165, 'type': 'Meccan'},
    {'id': 7,   'name': "Al-A'raf",       'bn': "আল-আ'রাফ",         'ar': 'الأعراف',    'ayahs': 206, 'type': 'Meccan'},
    {'id': 8,   'name': 'Al-Anfal',       'bn': 'আল-আনফাল',          'ar': 'الأنفال',    'ayahs': 75,  'type': 'Medinan'},
    {'id': 9,   'name': 'At-Tawbah',      'bn': 'আত-তাওবাহ',         'ar': 'التوبة',     'ayahs': 129, 'type': 'Medinan'},
    {'id': 10,  'name': 'Yunus',          'bn': 'ইউনুস',             'ar': 'يونس',       'ayahs': 109, 'type': 'Meccan'},
    {'id': 11,  'name': 'Hud',            'bn': 'হুদ',               'ar': 'هود',        'ayahs': 123, 'type': 'Meccan'},
    {'id': 12,  'name': 'Yusuf',          'bn': 'ইউসুফ',             'ar': 'يوسف',       'ayahs': 111, 'type': 'Meccan'},
    {'id': 13,  'name': "Ar-Ra'd",        'bn': "আর-রা'দ",           'ar': 'الرعد',      'ayahs': 43,  'type': 'Medinan'},
    {'id': 14,  'name': 'Ibrahim',        'bn': 'ইব্রাহীম',          'ar': 'إبراهيم',    'ayahs': 52,  'type': 'Meccan'},
    {'id': 15,  'name': 'Al-Hijr',        'bn': 'আল-হিজর',           'ar': 'الحجر',      'ayahs': 99,  'type': 'Meccan'},
    {'id': 16,  'name': 'An-Nahl',        'bn': 'আন-নাহল',           'ar': 'النحل',      'ayahs': 128, 'type': 'Meccan'},
    {'id': 17,  'name': 'Al-Isra',        'bn': 'আল-ইসরা',           'ar': 'الإسراء',    'ayahs': 111, 'type': 'Meccan'},
    {'id': 18,  'name': 'Al-Kahf',        'bn': 'আল-কাহফ',           'ar': 'الكهف',      'ayahs': 110, 'type': 'Meccan'},
    {'id': 19,  'name': 'Maryam',         'bn': 'মারিয়াম',           'ar': 'مريم',       'ayahs': 98,  'type': 'Meccan'},
    {'id': 20,  'name': 'Ta-Ha',          'bn': 'ত্বোয়া-হা',         'ar': 'طه',         'ayahs': 135, 'type': 'Meccan'},
    {'id': 21,  'name': 'Al-Anbiya',      'bn': 'আল-আম্বিয়া',        'ar': 'الأنبياء',   'ayahs': 112, 'type': 'Meccan'},
    {'id': 22,  'name': 'Al-Hajj',        'bn': 'আল-হাজ্জ',          'ar': 'الحج',       'ayahs': 78,  'type': 'Medinan'},
    {'id': 23,  'name': "Al-Mu'minun",    'bn': 'আল-মুমিনুন',        'ar': 'المؤمنون',   'ayahs': 118, 'type': 'Meccan'},
    {'id': 24,  'name': 'An-Nur',         'bn': 'আন-নূর',            'ar': 'النور',      'ayahs': 64,  'type': 'Medinan'},
    {'id': 25,  'name': 'Al-Furqan',      'bn': 'আল-ফুরকান',         'ar': 'الفرقان',    'ayahs': 77,  'type': 'Meccan'},
    {'id': 26,  'name': "Ash-Shu'ara",    'bn': 'আশ-শুয়ারা',         'ar': 'الشعراء',    'ayahs': 227, 'type': 'Meccan'},
    {'id': 27,  'name': 'An-Naml',        'bn': 'আন-নামল',           'ar': 'النمل',      'ayahs': 93,  'type': 'Meccan'},
    {'id': 28,  'name': 'Al-Qasas',       'bn': 'আল-কাসাস',          'ar': 'القصص',      'ayahs': 88,  'type': 'Meccan'},
    {'id': 29,  'name': 'Al-Ankabut',     'bn': 'আল-আনকাবুত',        'ar': 'العنكبوت',   'ayahs': 69,  'type': 'Meccan'},
    {'id': 30,  'name': 'Ar-Rum',         'bn': 'আর-রূম',            'ar': 'الروم',      'ayahs': 60,  'type': 'Meccan'},
    {'id': 31,  'name': 'Luqman',         'bn': 'লোকমান',            'ar': 'لقمان',      'ayahs': 34,  'type': 'Meccan'},
    {'id': 32,  'name': 'As-Sajdah',      'bn': 'আস-সাজদাহ',         'ar': 'السجدة',     'ayahs': 30,  'type': 'Meccan'},
    {'id': 33,  'name': 'Al-Ahzab',       'bn': 'আল-আহযাব',          'ar': 'الأحزاب',    'ayahs': 73,  'type': 'Medinan'},
    {'id': 34,  'name': 'Saba',           'bn': 'সাবা',              'ar': 'سبأ',        'ayahs': 54,  'type': 'Meccan'},
    {'id': 35,  'name': 'Fatir',          'bn': 'ফাতির',             'ar': 'فاطر',       'ayahs': 45,  'type': 'Meccan'},
    {'id': 36,  'name': 'Ya-Sin',         'bn': 'ইয়াসীন',            'ar': 'يس',         'ayahs': 83,  'type': 'Meccan'},
    {'id': 37,  'name': 'As-Saffat',      'bn': 'আস-সাফফাত',         'ar': 'الصافات',    'ayahs': 182, 'type': 'Meccan'},
    {'id': 38,  'name': 'Sad',            'bn': 'সোয়াদ',            'ar': 'ص',          'ayahs': 88,  'type': 'Meccan'},
    {'id': 39,  'name': 'Az-Zumar',       'bn': 'আজ-যুমার',          'ar': 'الزمر',      'ayahs': 75,  'type': 'Meccan'},
    {'id': 40,  'name': 'Ghafir',         'bn': 'গাফির',             'ar': 'غافر',       'ayahs': 85,  'type': 'Meccan'},
    {'id': 41,  'name': 'Fussilat',       'bn': 'ফুসসিলাত',          'ar': 'فصلت',       'ayahs': 54,  'type': 'Meccan'},
    {'id': 42,  'name': 'Ash-Shura',      'bn': 'আশ-শূরা',           'ar': 'الشورى',     'ayahs': 53,  'type': 'Meccan'},
    {'id': 43,  'name': 'Az-Zukhruf',     'bn': 'আজ-যুখরুফ',         'ar': 'الزخرف',     'ayahs': 89,  'type': 'Meccan'},
    {'id': 44,  'name': 'Ad-Dukhan',      'bn': 'আদ-দোখান',          'ar': 'الدخان',     'ayahs': 59,  'type': 'Meccan'},
    {'id': 45,  'name': 'Al-Jathiyah',    'bn': 'আল-জাসিয়াহ',       'ar': 'الجاثية',    'ayahs': 37,  'type': 'Meccan'},
    {'id': 46,  'name': 'Al-Ahqaf',       'bn': 'আল-আহকাফ',          'ar': 'الأحقاف',    'ayahs': 35,  'type': 'Meccan'},
    {'id': 47,  'name': 'Muhammad',       'bn': 'মুহাম্মদ',           'ar': 'محمد',       'ayahs': 38,  'type': 'Medinan'},
    {'id': 48,  'name': 'Al-Fath',        'bn': 'আল-ফাতাহ',          'ar': 'الفتح',      'ayahs': 29,  'type': 'Medinan'},
    {'id': 49,  'name': 'Al-Hujurat',     'bn': 'আল-হুজুরাত',        'ar': 'الحجرات',    'ayahs': 18,  'type': 'Medinan'},
    {'id': 50,  'name': 'Qaf',            'bn': 'কাফ',               'ar': 'ق',          'ayahs': 45,  'type': 'Meccan'},
    {'id': 51,  'name': 'Adh-Dhariyat',   'bn': 'আয-যারিয়াত',        'ar': 'الذاريات',   'ayahs': 60,  'type': 'Meccan'},
    {'id': 52,  'name': 'At-Tur',         'bn': 'আত-তূর',            'ar': 'الطور',      'ayahs': 49,  'type': 'Meccan'},
    {'id': 53,  'name': 'An-Najm',        'bn': 'আন-নাজম',           'ar': 'النجم',      'ayahs': 62,  'type': 'Meccan'},
    {'id': 54,  'name': 'Al-Qamar',       'bn': 'আল-কামার',          'ar': 'القمر',      'ayahs': 55,  'type': 'Meccan'},
    {'id': 55,  'name': 'Ar-Rahman',      'bn': 'আর-রাহমান',         'ar': 'الرحمن',     'ayahs': 78,  'type': 'Medinan'},
    {'id': 56,  'name': "Al-Waqi'ah",     'bn': 'আল-ওয়াকিয়াহ',      'ar': 'الواقعة',    'ayahs': 96,  'type': 'Meccan'},
    {'id': 57,  'name': 'Al-Hadid',       'bn': 'আল-হাদীদ',          'ar': 'الحديد',     'ayahs': 29,  'type': 'Medinan'},
    {'id': 58,  'name': 'Al-Mujadilah',   'bn': 'আল-মুজাদালাহ',      'ar': 'المجادلة',   'ayahs': 22,  'type': 'Medinan'},
    {'id': 59,  'name': 'Al-Hashr',       'bn': 'আল-হাশর',           'ar': 'الحشر',      'ayahs': 24,  'type': 'Medinan'},
    {'id': 60,  'name': 'Al-Mumtahanah',  'bn': 'আল-মুমতাহানাহ',     'ar': 'الممتحنة',   'ayahs': 13,  'type': 'Medinan'},
    {'id': 61,  'name': 'As-Saff',        'bn': 'আস-সাফ',            'ar': 'الصف',       'ayahs': 14,  'type': 'Medinan'},
    {'id': 62,  'name': "Al-Jumu'ah",     'bn': "আল-জুমু'আহ",       'ar': 'الجمعة',     'ayahs': 11,  'type': 'Medinan'},
    {'id': 63,  'name': 'Al-Munafiqun',   'bn': 'আল-মুনাফিকুন',      'ar': 'المنافقون',  'ayahs': 11,  'type': 'Medinan'},
    {'id': 64,  'name': 'At-Taghabun',    'bn': 'আত-তাগাবুন',        'ar': 'التغابن',    'ayahs': 18,  'type': 'Medinan'},
    {'id': 65,  'name': 'At-Talaq',       'bn': 'আত-তালাক',          'ar': 'الطلاق',     'ayahs': 12,  'type': 'Medinan'},
    {'id': 66,  'name': 'At-Tahrim',      'bn': 'আত-তাহরীম',         'ar': 'التحريم',    'ayahs': 12,  'type': 'Medinan'},
    {'id': 67,  'name': 'Al-Mulk',        'bn': 'আল-মূলক',           'ar': 'الملك',      'ayahs': 30,  'type': 'Meccan'},
    {'id': 68,  'name': 'Al-Qalam',       'bn': 'আল-কালাম',          'ar': 'القلم',      'ayahs': 52,  'type': 'Meccan'},
    {'id': 69,  'name': 'Al-Haqqah',      'bn': 'আল-হাক্কাহ',        'ar': 'الحاقة',     'ayahs': 52,  'type': 'Meccan'},
    {'id': 70,  'name': "Al-Ma'arij",     'bn': "আল-মা'আরিজ",       'ar': 'المعارج',    'ayahs': 44,  'type': 'Meccan'},
    {'id': 71,  'name': 'Nuh',            'bn': 'নূহ',               'ar': 'نوح',        'ayahs': 28,  'type': 'Meccan'},
    {'id': 72,  'name': 'Al-Jinn',        'bn': 'আল-জীন',            'ar': 'الجن',       'ayahs': 28,  'type': 'Meccan'},
    {'id': 73,  'name': 'Al-Muzzammil',   'bn': 'আল-মুযযাম্মিল',     'ar': 'المزمل',     'ayahs': 20,  'type': 'Meccan'},
    {'id': 74,  'name': 'Al-Muddaththir', 'bn': 'আল-মুদ্দাসসির',     'ar': 'المدثر',     'ayahs': 56,  'type': 'Meccan'},
    {'id': 75,  'name': 'Al-Qiyamah',     'bn': 'আল-কিয়ামাহ',       'ar': 'القيامة',    'ayahs': 40,  'type': 'Meccan'},
    {'id': 76,  'name': 'Al-Insan',       'bn': 'আল-ইনসান',          'ar': 'الإنسان',    'ayahs': 31,  'type': 'Medinan'},
    {'id': 77,  'name': 'Al-Mursalat',    'bn': 'আল-মুরসালাত',       'ar': 'المرسلات',   'ayahs': 50,  'type': 'Meccan'},
    {'id': 78,  'name': "An-Naba",        'bn': 'আন-নাব্যা',          'ar': 'النبأ',      'ayahs': 40,  'type': 'Meccan'},
    {'id': 79,  'name': "An-Nazi'at",     'bn': 'আন-নাযিয়াত',        'ar': 'النازعات',   'ayahs': 46,  'type': 'Meccan'},
    {'id': 80,  'name': 'Abasa',          'bn': 'আবাসা',             'ar': 'عبس',        'ayahs': 42,  'type': 'Meccan'},
    {'id': 81,  'name': 'At-Takwir',      'bn': 'আত-তাকভীর',         'ar': 'التكوير',    'ayahs': 29,  'type': 'Meccan'},
    {'id': 82,  'name': 'Al-Infitar',     'bn': 'আল-ইনফিতার',        'ar': 'الانفطار',   'ayahs': 19,  'type': 'Meccan'},
    {'id': 83,  'name': 'Al-Mutaffifin',  'bn': 'আল-মুতাফফিফীন',     'ar': 'المطففين',   'ayahs': 36,  'type': 'Meccan'},
    {'id': 84,  'name': 'Al-Inshiqaq',    'bn': 'আল-ইনশিকাক',        'ar': 'الانشقاق',   'ayahs': 25,  'type': 'Meccan'},
    {'id': 85,  'name': 'Al-Buruj',       'bn': 'আল-বুরূজ',          'ar': 'البروج',     'ayahs': 22,  'type': 'Meccan'},
    {'id': 86,  'name': 'At-Tariq',       'bn': 'আত-তারিক',          'ar': 'الطارق',     'ayahs': 17,  'type': 'Meccan'},
    {'id': 87,  'name': "Al-A'la",        'bn': "আল-আ'লা",          'ar': 'الأعلى',     'ayahs': 19,  'type': 'Meccan'},
    {'id': 88,  'name': 'Al-Ghashiyah',   'bn': 'আল-গাশিয়াহ',       'ar': 'الغاشية',    'ayahs': 26,  'type': 'Meccan'},
    {'id': 89,  'name': 'Al-Fajr',        'bn': 'আল-ফজর',            'ar': 'الفجر',      'ayahs': 30,  'type': 'Meccan'},
    {'id': 90,  'name': 'Al-Balad',       'bn': 'আল-বালাদ',          'ar': 'البلد',      'ayahs': 20,  'type': 'Meccan'},
    {'id': 91,  'name': 'Ash-Shams',      'bn': 'আশ-শামস',           'ar': 'الشمس',      'ayahs': 15,  'type': 'Meccan'},
    {'id': 92,  'name': 'Al-Layl',        'bn': 'আল-লাইল',           'ar': 'الليل',      'ayahs': 21,  'type': 'Meccan'},
    {'id': 93,  'name': 'Ad-Duha',        'bn': 'আদ-দুহা',           'ar': 'الضحى',      'ayahs': 11,  'type': 'Meccan'},
    {'id': 94,  'name': 'Ash-Sharh',      'bn': 'আশ-শারহ',           'ar': 'الشرح',      'ayahs': 8,   'type': 'Meccan'},
    {'id': 95,  'name': 'At-Tin',         'bn': 'আত-তীন',            'ar': 'التين',      'ayahs': 8,   'type': 'Meccan'},
    {'id': 96,  'name': 'Al-Alaq',        'bn': 'আল-আলাক',           'ar': 'العلق',      'ayahs': 19,  'type': 'Meccan'},
    {'id': 97,  'name': 'Al-Qadr',        'bn': 'আল-কদর',            'ar': 'القدر',      'ayahs': 5,   'type': 'Meccan'},
    {'id': 98,  'name': 'Al-Bayyinah',    'bn': 'আল-বাইয়্যিনাহ',     'ar': 'البينة',     'ayahs': 8,   'type': 'Medinan'},
    {'id': 99,  'name': 'Az-Zalzalah',    'bn': 'আয-যালযালাহ',       'ar': 'الزلزلة',    'ayahs': 8,   'type': 'Medinan'},
    {'id': 100, 'name': 'Al-Adiyat',      'bn': 'আল-আদিয়াত',         'ar': 'العاديات',   'ayahs': 11,  'type': 'Meccan'},
    {'id': 101, 'name': "Al-Qari'ah",     'bn': "আল-কারি'আহ",       'ar': 'القارعة',    'ayahs': 11,  'type': 'Meccan'},
    {'id': 102, 'name': 'At-Takathur',    'bn': 'আত-তাকাসুর',        'ar': 'التكاثر',    'ayahs': 8,   'type': 'Meccan'},
    {'id': 103, 'name': 'Al-Asr',         'bn': 'আল-আসর',            'ar': 'العصر',      'ayahs': 3,   'type': 'Meccan'},
    {'id': 104, 'name': 'Al-Humazah',     'bn': 'আল-হুমাযাহ',        'ar': 'الهمزة',     'ayahs': 9,   'type': 'Meccan'},
    {'id': 105, 'name': 'Al-Fil',         'bn': 'আল-ফীল',            'ar': 'الفيل',      'ayahs': 5,   'type': 'Meccan'},
    {'id': 106, 'name': 'Quraysh',        'bn': 'কোরাইশ',            'ar': 'قريش',       'ayahs': 4,   'type': 'Meccan'},
    {'id': 107, 'name': "Al-Ma'un",       'bn': "আল-মা'ঊন",         'ar': 'الماعون',    'ayahs': 7,   'type': 'Meccan'},
    {'id': 108, 'name': 'Al-Kauthar',     'bn': 'আল-কাওসার',         'ar': 'الكوثر',     'ayahs': 3,   'type': 'Meccan'},
    {'id': 109, 'name': 'Al-Kafirun',     'bn': 'আল-কাফিরুন',        'ar': 'الكافرون',   'ayahs': 6,   'type': 'Meccan'},
    {'id': 110, 'name': 'An-Nasr',        'bn': 'আন-নসর',            'ar': 'النصر',      'ayahs': 3,   'type': 'Medinan'},
    {'id': 111, 'name': 'Al-Masad',       'bn': 'আল-লাহাব',          'ar': 'المسد',      'ayahs': 5,   'type': 'Meccan'},
    {'id': 112, 'name': 'Al-Ikhlas',      'bn': 'আল-ইখলাস',          'ar': 'الإخلاص',    'ayahs': 4,   'type': 'Meccan'},
    {'id': 113, 'name': 'Al-Falaq',       'bn': 'আল-ফালাক',          'ar': 'الفلق',      'ayahs': 5,   'type': 'Meccan'},
    {'id': 114, 'name': 'An-Nas',         'bn': 'আন-নাস',            'ar': 'الناس',      'ayahs': 6,   'type': 'Meccan'},
  ];

  // Scroll controller to track position and load next pages
  final ScrollController _mushafScrollController = ScrollController();
  final Map<int, List<Map<String, dynamic>>> _loadedPagesData = {};
  final Set<int> _failedPages = {};
  final Set<int> _loadingPages = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initAppDirectory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mushafScrollController.dispose();
    super.dispose();
  }

  // ── App directory & cache checks ───────────────────────────────────────────
  Future<void> _initAppDirectory() async {
    _appDir = await getApplicationDocumentsDirectory();
    _checkCachedSurahs();
    _checkCachedPages();
    _loadJuzPages(_currentJuz);
  }

  Future<void> _checkCachedSurahs() async {
    if (_appDir == null) return;
    final Map<int, bool> temp = {};
    for (int i = 1; i <= 114; i++) {
      temp[i] = await File('${_appDir!.path}/quran_surah_$i.json').exists();
    }
    if (mounted) setState(() => _cachedSurahs = temp);
  }

  Future<void> _checkCachedPages() async {
    if (_appDir == null) return;
    final Map<int, bool> temp = {};
    for (int i = 1; i <= 604; i++) {
      temp[i] = await File('${_appDir!.path}/quran_page_$i.json').exists();
    }
    if (mounted) setState(() => _cachedPages = temp);
  }

  // ── Juz helpers ────────────────────────────────────────────────────────────
  void _updateCurrentJuz() {
    for (final juz in juzData) {
      if (_currentPage >= (juz['start'] as int) &&
          _currentPage <= (juz['end'] as int)) {
        if (mounted) setState(() => _currentJuz = juz['juz'] as int);
        break;
      }
    }
  }

  void _jumpToJuz(int juzNumber) {
    final juz = juzData.firstWhere((j) => j['juz'] == juzNumber);
    setState(() {
      _currentPage = juz['start'] as int;
      _currentJuz = juzNumber;
      _loadedPagesData.clear();
      _failedPages.clear();
      _loadingPages.clear();
    });
    _loadJuzPages(juzNumber);
    if (_mushafScrollController.hasClients) {
      _mushafScrollController.jumpTo(0);
    }
  }

  void _showParaSelector() {
    const goldAccent = Color(0xFFE5B842);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1E19),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return SafeArea(
              top: true,
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      children: [
                        Container(
                          width: 40, height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.all(Radius.circular(2)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'পারা নির্বাচন করুন',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '৩০টি পারা • প্রতি পারায় ২০ পৃষ্ঠা',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: juzData.length,
                      itemBuilder: (ctx, index) {
                        final juz = juzData[index];
                        final bool isCurrent = (juz['juz'] as int) == _currentJuz;
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            _jumpToJuz(juz['juz'] as int);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isCurrent ? const Color(0xFF1D3E32) : const Color(0xFF162D24),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isCurrent ? goldAccent.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.05),
                                width: isCurrent ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isCurrent
                                        ? goldAccent.withValues(alpha: 0.2)
                                        : Colors.white.withValues(alpha: 0.05),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${juz['juz']}',
                                      style: TextStyle(
                                        color: isCurrent ? goldAccent : Colors.white60,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        juz['bn'] as String,
                                        style: TextStyle(
                                          color: isCurrent ? Colors.white : Colors.white70,
                                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'পৃষ্ঠা ${juz['start']} – ${juz['end']}',
                                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isCurrent)
                                  const Icon(Icons.bookmark_rounded, color: goldAccent, size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPageJumpDialog() {
    const goldAccent = Color(0xFFE5B842);
    final ctrl = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF162D24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('পৃষ্ঠায় যান',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: '১ – ৬০৪',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: goldAccent.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: goldAccent.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: goldAccent, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final p = int.tryParse(ctrl.text);
              if (p != null && p >= 1 && p <= 604) {
                Navigator.pop(ctx);
                setState(() {
                  _currentPage = p;
                  _loadedPagesData.clear();
                  _failedPages.clear();
                  _loadingPages.clear();
                });
                _updateCurrentJuz();
                _loadJuzPages(_currentJuz);
                if (_mushafScrollController.hasClients) {
                  _mushafScrollController.jumpTo(0);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: goldAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('যাও',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Individual Surah Download ───────────────────────────────────────────────
  Future<void> _downloadSurah(int surahNumber) async {
    if (_appDir == null) return;
    final file = File('${_appDir!.path}/quran_surah_$surahNumber.json');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('সুরা $surahNumber ডাউনলোড শুরু হয়েছে...'),
      backgroundColor: Colors.teal.shade800,
      duration: const Duration(seconds: 1),
    ));
    try {
      final results = await Future.wait([
        http.get(Uri.parse('https://api.alquran.cloud/v1/surah/$surahNumber/quran-simple')),
        http.get(Uri.parse('https://api.alquran.cloud/v1/surah/$surahNumber/bn.bengali')),
        http.get(Uri.parse('https://api.alquran.cloud/v1/surah/$surahNumber/en.sahih')),
      ]).timeout(const Duration(seconds: 15));

      if (results[0].statusCode == 200 && results[1].statusCode == 200 && results[2].statusCode == 200) {
        final arabicData = json.decode(results[0].body)['data']['ayahs'] as List;
        final bnData     = json.decode(results[1].body)['data']['ayahs'] as List;
        final enData     = json.decode(results[2].body)['data']['ayahs'] as List;
        final List<Map<String, dynamic>> ayahs = [];
        for (int i = 0; i < arabicData.length; i++) {
          ayahs.add({
            'numberInSurah': arabicData[i]['numberInSurah'],
            'text': arabicData[i]['text'],
            'bn': bnData[i]['text'],
            'en': enData[i]['text'],
          });
        }
        await file.writeAsString(json.encode(ayahs));
        await _checkCachedSurahs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('সুরা ডাউনলোড সম্পূর্ণ হয়েছে!'),
            backgroundColor: Color(0xFF0F3625),
          ));
        }
      } else {
        throw Exception('API error');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ডাউনলোড ব্যর্থ: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  // ── Batch download all 114 Surahs ─────────────────────────────────────────
  Future<void> _downloadAllSurahs() async {
    if (_appDir == null) return;
    setState(() {
      _isDownloadingAllSurahs = true;
      _surahDownloadProgress = 0.0;
      _surahDownloadStatus = 'ডাউনলোড শুরু হচ্ছে...';
    });
    try {
      for (int i = 1; i <= 114; i++) {
        if (!_isDownloadingAllSurahs) break;
        setState(() {
          _surahDownloadStatus = 'সুরা $i/১১৪ ডাউনলোড হচ্ছে...';
          _surahDownloadProgress = i / 114;
        });
        final file = File('${_appDir!.path}/quran_surah_$i.json');
        if (await file.exists()) continue;
        final results = await Future.wait([
          http.get(Uri.parse('https://api.alquran.cloud/v1/surah/$i/quran-simple')),
          http.get(Uri.parse('https://api.alquran.cloud/v1/surah/$i/bn.bengali')),
          http.get(Uri.parse('https://api.alquran.cloud/v1/surah/$i/en.sahih')),
        ]).timeout(const Duration(seconds: 15));
        if (results[0].statusCode == 200 && results[1].statusCode == 200 && results[2].statusCode == 200) {
          final arabicData = json.decode(results[0].body)['data']['ayahs'] as List;
          final bnData     = json.decode(results[1].body)['data']['ayahs'] as List;
          final enData     = json.decode(results[2].body)['data']['ayahs'] as List;
          final List<Map<String, dynamic>> ayahs = [];
          for (int j = 0; j < arabicData.length; j++) {
            ayahs.add({
              'numberInSurah': arabicData[j]['numberInSurah'],
              'text': arabicData[j]['text'],
              'bn': bnData[j]['text'],
              'en': enData[j]['text'],
            });
          }
          await file.writeAsString(json.encode(ayahs));
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
      await _checkCachedSurahs();
      setState(() {
        _isDownloadingAllSurahs = false;
        _surahDownloadStatus = 'সব সুরা সফলভাবে ডাউনলোড হয়েছে!';
      });
    } catch (e) {
      await _checkCachedSurahs();
      setState(() {
        _isDownloadingAllSurahs = false;
        _surahDownloadStatus = 'ডাউনলোড ব্যাহত হয়েছে: $e';
      });
    }
  }

  // ── Load Hafezi page content ───────────────────────────────────────────────
  void _loadJuzPages(int juzNumber) {
    final juz = juzData.firstWhere((j) => j['juz'] == juzNumber);
    final int start = juz['start'] as int;
    final int end = juz['end'] as int;
    for (int p = start; p <= end; p++) {
      _loadSinglePage(p);
    }
  }

  Future<void> _loadSinglePage(int pageNum) async {
    if (_appDir == null) return;
    if (_loadedPagesData.containsKey(pageNum)) return;
    if (_loadingPages.contains(pageNum)) return;
    _loadingPages.add(pageNum);
    
    final file = File('${_appDir!.path}/quran_page_$pageNum.json');
    try {
      if (await file.exists()) {
        final content = await file.readAsString();
        final List decoded = json.decode(content);
        if (mounted) {
          setState(() {
            _loadedPagesData[pageNum] = decoded.cast<Map<String, dynamic>>();
            _loadingPages.remove(pageNum);
          });
        }
      } else {
        final results = await Future.wait([
          http.get(Uri.parse('https://api.alquran.cloud/v1/page/$pageNum/quran-simple')),
          http.get(Uri.parse('https://api.alquran.cloud/v1/page/$pageNum/bn.bengali')),
          http.get(Uri.parse('https://api.alquran.cloud/v1/page/$pageNum/en.sahih')),
        ]).timeout(const Duration(seconds: 15));
        if (results[0].statusCode == 200 && results[1].statusCode == 200 && results[2].statusCode == 200) {
          final arabicData = json.decode(results[0].body)['data']['ayahs'] as List;
          final bnData     = json.decode(results[1].body)['data']['ayahs'] as List;
          final enData     = json.decode(results[2].body)['data']['ayahs'] as List;
          final List<Map<String, dynamic>> tempPage = [];
          for (int i = 0; i < arabicData.length; i++) {
            tempPage.add({
              'surah': arabicData[i]['surah']['englishName'],
              'numberInSurah': arabicData[i]['numberInSurah'],
              'text': arabicData[i]['text'],
              'bn': bnData[i]['text'],
              'en': enData[i]['text'],
            });
          }
          await file.writeAsString(json.encode(tempPage));
          await _checkCachedPages();
          if (mounted) {
            setState(() {
              _loadedPagesData[pageNum] = tempPage;
              _loadingPages.remove(pageNum);
            });
          }
        } else {
          throw Exception('API error');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _failedPages.add(pageNum);
          _loadingPages.remove(pageNum);
        });
      }
    }
  }

  Future<void> _loadPageContent() async {
    _loadJuzPages(_currentJuz);
  }

  // ── Batch download all 604 pages ──────────────────────────────────────────
  Future<void> _downloadAllPages() async {
    if (_appDir == null) return;
    setState(() {
      _isDownloadingAllPages = true;
      _pageDownloadProgress = 0.0;
      _pageDownloadStatus = 'ডাউনলোড শুরু হচ্ছে...';
    });
    try {
      for (int i = 1; i <= 604; i++) {
        if (!_isDownloadingAllPages) break;
        setState(() {
          _pageDownloadStatus = 'পেইজ $i/৬০৪ ডাউনলোড হচ্ছে...';
          _pageDownloadProgress = i / 604;
        });
        final file = File('${_appDir!.path}/quran_page_$i.json');
        if (await file.exists()) continue;
        final results = await Future.wait([
          http.get(Uri.parse('https://api.alquran.cloud/v1/page/$i/quran-simple')),
          http.get(Uri.parse('https://api.alquran.cloud/v1/page/$i/bn.bengali')),
          http.get(Uri.parse('https://api.alquran.cloud/v1/page/$i/en.sahih')),
        ]).timeout(const Duration(seconds: 15));
        if (results[0].statusCode == 200 && results[1].statusCode == 200 && results[2].statusCode == 200) {
          final arabicData = json.decode(results[0].body)['data']['ayahs'] as List;
          final bnData     = json.decode(results[1].body)['data']['ayahs'] as List;
          final enData     = json.decode(results[2].body)['data']['ayahs'] as List;
          final List<Map<String, dynamic>> tempPage = [];
          for (int j = 0; j < arabicData.length; j++) {
            tempPage.add({
              'surah': arabicData[j]['surah']['englishName'],
              'numberInSurah': arabicData[j]['numberInSurah'],
              'text': arabicData[j]['text'],
              'bn': bnData[j]['text'],
              'en': enData[j]['text'],
            });
          }
          await file.writeAsString(json.encode(tempPage));
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
      await _checkCachedPages();
      setState(() {
        _isDownloadingAllPages = false;
        _pageDownloadStatus = 'সব পেইজ সফলভাবে ডাউনলোড হয়েছে!';
      });
      _loadPageContent();
    } catch (e) {
      await _checkCachedPages();
      setState(() {
        _isDownloadingAllPages = false;
        _pageDownloadStatus = 'ডাউনলোড ব্যাহত হয়েছে: $e';
      });
    }
  }

  // ── Settings bottom sheet ─────────────────────────────────────────────────
  void _showPageSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF162D24),
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          const goldAccent = Color(0xFFE5B842);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('হাফেজি কুরআন সেটিংস',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Row(children: [
                  const Icon(Icons.format_size_rounded, color: goldAccent, size: 20),
                  const SizedBox(width: 12),
                  const Text('আরবি লেখার সাইজ', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const Spacer(),
                  Text('${_pageArabicFontSize.toInt()} px',
                      style: const TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                ]),
                Slider(
                  value: _pageArabicFontSize,
                  min: 18.0, max: 36.0, divisions: 9,
                  activeColor: goldAccent,
                  inactiveColor: Colors.white10,
                  onChanged: (val) {
                    setModalState(() => _pageArabicFontSize = val);
                    setState(() => _pageArabicFontSize = val);
                  },
                ),
                SwitchListTile(
                  title: const Text('অনুবাদ দেখুন', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  value: _showPageTranslation,
                  activeThumbColor: goldAccent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setModalState(() => _showPageTranslation = val);
                    setState(() => _showPageTranslation = val);
                  },
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    const primaryBg  = Color(0xFF0F1E19);
    const cardBg     = Color(0xFF162D24);
    const goldAccent = Color(0xFFE5B842);
    const textLight  = Colors.white;

    return Scaffold(
      backgroundColor: primaryBg,
      appBar: AppBar(
        title: const Text('পবিত্র কুরআন শরীফ',
            style: TextStyle(fontWeight: FontWeight.bold, color: textLight)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: textLight),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: goldAccent,
          labelColor: goldAccent,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'সুরা ভিত্তিক', icon: Icon(Icons.list_alt_rounded, size: 20)),
            Tab(text: 'হাফেজি কুরআন', icon: Icon(Icons.menu_book_rounded, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ════════════════════════════════════════
          // TAB 1: Surah List
          // ════════════════════════════════════════
          Column(
            children: [
              if (_isDownloadingAllSurahs)
                Container(
                  color: const Color(0xFF0F3625),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_surahDownloadStatus,
                              style: const TextStyle(color: textLight, fontSize: 12, fontWeight: FontWeight.w500)),
                          IconButton(
                            icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 20),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            onPressed: () => setState(() {
                              _isDownloadingAllSurahs = false;
                              _surahDownloadStatus = 'ডাউনলোড বাতিল করা হয়েছে।';
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _surahDownloadProgress,
                          backgroundColor: Colors.white10,
                          color: goldAccent,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: _downloadAllSurahs,
                    icon: const Icon(Icons.download_for_offline_rounded, color: Colors.black, size: 18),
                    label: const Text('সব সুরা অফলাইনে ডাউনলোড করুন (১১৪টি)',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: goldAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: surahList.length,
                  itemBuilder: (context, index) {
                    final surah = surahList[index];
                    final int sId = surah['id'] as int;
                    final bool isCached = _cachedSurahs[sId] ?? false;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.07),
                          ),
                          child: Center(
                            child: Text('$sId',
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(surah['bn'] as String,
                                  style: const TextStyle(color: textLight, fontWeight: FontWeight.bold, fontSize: 15),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            Text('(${surah['name']})',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                        subtitle: Text(
                          '${(surah['type'] as String) == "Meccan" ? "মাক্কী" : "মাদানী"} • ${surah['ayahs']} আয়াত',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(surah['ar'] as String,
                                style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 12),
                            if (isCached)
                              const Icon(Icons.check_circle_rounded, color: Colors.tealAccent, size: 22)
                            else
                              IconButton(
                                icon: const Icon(Icons.download_rounded, color: Colors.white38, size: 20),
                                onPressed: () => _downloadSurah(sId),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SurahViewerScreen(
                                surahNumber: sId,
                                surahNameBangla: surah['bn'] as String,
                                surahNameEnglish: surah['name'] as String,
                                surahNameArabic: surah['ar'] as String,
                                revelationType: surah['type'] as String,
                                totalAyahs: surah['ayahs'] as int,
                              ),
                            ),
                          ).then((_) => _checkCachedSurahs());
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // ════════════════════════════════════════
          // TAB 2: Hafezi Quran – Mushaf Style
          // ════════════════════════════════════════
          Column(
            children: [
              // ── Batch download banner ──
              if (_isDownloadingAllPages)
                Container(
                  color: const Color(0xFF0F3625),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(_pageDownloadStatus,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 18),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            onPressed: () => setState(() {
                              _isDownloadingAllPages = false;
                              _pageDownloadStatus = 'ডাউনলোড বাতিল হয়েছে।';
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _pageDownloadProgress,
                          backgroundColor: Colors.white10,
                          color: goldAccent,
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Para / Navigation Header Bar ──
              Container(
                color: const Color(0xFF0F2A20),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _showParaSelector,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: goldAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: goldAccent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book_rounded, color: goldAccent, size: 14),
                            const SizedBox(width: 6),
                            Text('পারা $_currentJuz',
                                style: const TextStyle(color: goldAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            const Icon(Icons.expand_more_rounded, color: goldAccent, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: goldAccent, size: 28),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _currentPage > 1
                          ? () {
                              setState(() => _currentPage--);
                              _updateCurrentJuz();
                              _loadPageContent();
                            }
                          : null,
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _showPageJumpDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Text(
                          'পৃষ্ঠা $_currentPage / ৬০৪',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: goldAccent, size: 28),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _currentPage < 604
                          ? () {
                              setState(() => _currentPage++);
                              _updateCurrentJuz();
                              _loadPageContent();
                            }
                          : null,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.tune_rounded, color: goldAccent, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _showPageSettingsBottomSheet,
                    ),
                  ],
                ),
              ),

              // ── Offline warning bar ──
              if (!_isDownloadingAllPages && !(_cachedPages[_currentPage] ?? false))
                Container(
                  color: const Color(0xFF2A1A1A),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: Colors.orangeAccent, size: 14),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('এই পৃষ্ঠাটি ক্যাশে নেই। ডাউনলোড করুন।',
                            style: TextStyle(color: Colors.white60, fontSize: 11)),
                      ),
                      TextButton(
                        onPressed: _loadPageContent,
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero),
                        child: const Text('পৃষ্ঠা ডাউনলোড',
                            style: TextStyle(color: goldAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      TextButton(
                        onPressed: _downloadAllPages,
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero),
                        child: const Text('সব ডাউনলোড',
                            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

              // ── Mushaf Page Area ──
              Expanded(
                child: Builder(
                  builder: (context) {
                    final juz = juzData.firstWhere((j) => j['juz'] == _currentJuz);
                    final int start = juz['start'] as int;
                    final int end = juz['end'] as int;
                    final int totalPages = end - start + 1;

                    return ListView.builder(
                      controller: _mushafScrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                      itemCount: totalPages,
                      itemBuilder: (context, index) {
                        final int pageNum = start + index;
                        final pageAyahs = _loadedPagesData[pageNum];

                        if (pageAyahs == null) {
                          if (_failedPages.contains(pageNum)) {
                            return Card(
                              color: cardBg,
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 36),
                                    const SizedBox(height: 8),
                                    Text('পৃষ্ঠা $pageNum লোড করা যায়নি', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                    TextButton(
                                      onPressed: () => _loadSinglePage(pageNum),
                                      child: const Text('আবার চেষ্টা করুন', style: TextStyle(color: goldAccent)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return Container(
                            height: 120,
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(color: goldAccent, strokeWidth: 2),
                                ),
                                SizedBox(height: 10),
                                Text('পৃষ্ঠা লোড হচ্ছে...', style: TextStyle(color: Colors.white38, fontSize: 12)),
                              ],
                            ),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildMushafPage(pageNum, pageAyahs),
                        );
                      },
                    );
                  }
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Mushaf Page Widget
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMushafPage(int pageNum, List<Map<String, dynamic>> pageAyahs) {
    const parchmentBg     = Color(0xFFF5EDDC);
    const parchmentBorder = Color(0xFFE0CCB0);
    const inkColor        = Color(0xFF1A1209);
    const headerColor     = Color(0xFF6B1A1A);

    final segments = <Widget>[];
    String? lastSurahName;
    final List<Map<String, dynamic>> currentAyahRun = [];

    void flushRun() {
      if (currentAyahRun.isEmpty) return;
      final buf = StringBuffer();
      for (final a in currentAyahRun) {
        // U+06DD = ARABIC END OF AYAH ۝
        buf.write('${a["_clean"]} \u06dd${a["numberInSurah"]} ');
      }
      segments.add(
        Text(
          buf.toString().trim(),
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: inkColor,
            fontSize: _pageArabicFontSize,
            height: 2.1,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
      if (_showPageTranslation) {
        segments.add(const SizedBox(height: 6));
        for (final a in currentAyahRun) {
          segments.add(Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              '(${a["surah"]}: ${a["numberInSurah"]}) ${a["bn"] ?? ""}',
              style: const TextStyle(color: Color(0xFF4A3B28), fontSize: 11, height: 1.5),
            ),
          ));
        }
        segments.add(const SizedBox(height: 6));
      }
      currentAyahRun.clear();
    }

    for (final ayah in pageAyahs) {
      String text       = ayah['text'] as String? ?? '';
      final int num     = ayah['numberInSurah'] as int? ?? 0;
      final String surah = ayah['surah'] as String? ?? '';

      // Strip Bismillah prefix from surah-start ayahs
      if (num == 1 && surah != 'Al-Fatihah' && surah != 'At-Tawbah') {
        const p1 = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ';
        const p2 = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ ';
        if (text.startsWith(p1)) text = text.substring(p1.length);
        if (text.startsWith(p2)) text = text.substring(p2.length);
      }

      if (surah != lastSurahName && num == 1) {
        flushRun();
        lastSurahName = surah;
        segments.add(const SizedBox(height: 8));
        segments.add(_buildSurahHeader(surah, headerColor));
      } else {
        lastSurahName = surah;
      }

      currentAyahRun.add({...ayah, '_clean': text});
    }
    flushRun();

    final paraInfo = juzData.firstWhere(
      (j) => pageNum >= (j['start'] as int) && pageNum <= (j['end'] as int),
      orElse: () => juzData.first,
    );
    final int paraPage       = pageNum - (paraInfo['start'] as int) + 1;
    final int totalParaPages = (paraInfo['end'] as int) - (paraInfo['start'] as int) + 1;

    return Container(
      decoration: BoxDecoration(
        color: parchmentBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: parchmentBorder, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: parchmentBorder,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(
                bottom: BorderSide(color: headerColor.withValues(alpha: 0.25), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(paraInfo['bn'] as String,
                    style: const TextStyle(color: headerColor, fontSize: 11, fontWeight: FontWeight.bold)),
                Text('$pageNum',
                    style: const TextStyle(color: headerColor, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Arabic content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: segments,
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: parchmentBorder,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              border: Border(
                top: BorderSide(color: headerColor.withValues(alpha: 0.25), width: 1),
              ),
            ),
            child: Center(
              child: Text(
                'পারার ভেতরে পৃষ্ঠা $paraPage / $totalParaPages',
                style: TextStyle(
                  color: headerColor.withValues(alpha: 0.7),
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahHeader(String surahName, Color headerColor) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: headerColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: headerColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          Text(
            surahName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: headerColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          if (surahName != 'Al-Fatihah' && surahName != 'At-Tawbah') ...[
            const SizedBox(height: 6),
            Text(
              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: headerColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.8,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
