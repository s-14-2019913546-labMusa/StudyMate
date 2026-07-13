import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'bengali_date_helper.dart';
import 'islamic_service.dart';
import 'language_manager.dart';
import 'theme_manager.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDay;
  String _activeCalendarSystem = 'gregorian'; // 'gregorian', 'bengali', 'hijri'

  // Focused months for each system
  late int _focusedGregorianYear;
  late int _focusedGregorianMonth; // 1-12

  late int _focusedBengaliYear;
  late int _focusedBengaliMonth; // 1-12

  late int _focusedHijriYear;
  late int _focusedHijriMonth; // 1-12

  // Dynamic history states
  bool _isLoadingHistory = false;
  List<Map<String, String>> _dynamicHistoryEvents = [];
  final Map<String, List<Map<String, String>>> _historyCache = {};
  final Map<String, String> _translations = {};
  final Set<String> _translatingKeys = {};

  static const List<String> _weekDaysBn = ['রবি', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহ', 'শুক্র', 'শনি'];
  static const List<String> _weekDaysEn = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  static const List<String> _hijriMonthsBn = [
    'মুহররম', 'সফর', 'রবিউল আউয়াল', 'রবিউস সানি', 
    'জমাদিউল আউয়াল', 'জমাদিউস সানি', 'রজব', 'শাবান', 
    'রমজান', 'শাওয়াল', 'জিলকদ', 'জিলহজ'
  ];
  static const List<String> _hijriMonthsEn = [
    'Muharram', 'Safar', 'Rabi\' al-Awwal', 'Rabi\' al-Thani', 
    'Jumada al-Awwal', 'Jumada al-Thani', 'Rajab', 'Sha\'ban', 
    'Ramadan', 'Shawwal', 'Dhu al-Qadah', 'Dhu al-Hijjah'
  ];

  static final Map<String, Map<String, String>> _gregorianSpecialDays = {
    '02-21': {
      'title_bn': 'শহীদ দিবস ও আন্তর্জাতিক মাতৃভাষা দিবস',
      'title_en': 'Shaheed Day & International Mother Language Day',
      'desc_bn': '১৯৫২ সালের এই দিনে বাংলা ভাষাকে রাষ্ট্রভাষা করার দাবিতে ছাত্ররা বুকের таজা রক্ত দিয়ে শহীদ হন। এটি এখন বিশ্বজুড়ে আন্তর্জাতিক মাতৃভাষা দিবস হিসেবে পালিত হয়।',
      'desc_en': 'On this day in 1952, students sacrificed their lives to establish Bengali as a state language. It is now celebrated worldwide as International Mother Language Day.'
    },
    '03-17': {
      'title_bn': 'জাতির পিতা শেখ মুজিবুর রহমানের জন্মবার্ষিকী',
      'title_en': 'Birth Anniversary of Father of the Nation Sheikh Mujibur Rahman',
      'desc_bn': '১৯২০ সালের ১৭ই মার্চ গোপালগঞ্জের টুঙ্গিপাড়ায় স্বাধীন বাংলাদেশের স্থপতি বঙ্গবন্ধু শেখ মুজিবুর রহমান জন্মগ্রহণ করেন। এই দিনটি জাতীয় শিশু দিবস হিসেবেও পালিত হয়।',
      'desc_en': 'On March 17, 1920, the architect of independent Bangladesh, Bangabandhu Sheikh Mujibur Rahman, was born in Tungipara, Gopalganj. This day is also celebrated as National Children\'s Day.'
    },
    '03-26': {
      'title_bn': 'স্বাধীনতা ও জাতীয় দিবস',
      'title_en': 'Independence & National Day',
      'desc_bn': '১৯৭১ সালের ২৬শে মার্চ প্রথম প্রহরে বঙ্গবন্ধু শেখ মুজিবুর রহমান বাংলাদেশের স্বাধীনতা ঘোষণা করেন। এরপর দীর্ঘ ৯ মাসের রক্তক্ষয়ী যুদ্ধের মাধ্যমে দেশ স্বাধীন হয়।',
      'desc_en': 'In the early hours of March 26, 1971, Bangabandhu Sheikh Mujibur Rahman declared the independence of Bangladesh, leading to a 9-month liberation war.'
    },
    '04-14': {
      'title_bn': 'পহেলা বৈশাখ (বাংলা নববর্ষ)',
      'title_en': 'Pohela Boishakh (Bengali New Year)',
      'desc_bn': 'বাংলা সনের প্রথম দিন। এটি বাঙালি জাতির অত্যন্ত আনন্দময় একটি সাংস্কৃতিক উৎসব, যা সর্বজনীনভাবে উদযাপিত হয়।',
      'desc_en': 'The first day of the Bengali calendar. It is a highly joyous cultural festival of the Bengali nation, celebrated universally.'
    },
    '05-01': {
      'title_bn': 'মে দিবস (আন্তর্জাতিক শ্রমিক দিবস)',
      'title_en': 'May Day (International Workers\' Day)',
      'desc_bn': '১৮৮৬ সালে আমেরিকার শিকাগো শহরের হে মার্কেটে ৮ ঘণ্টা কর্মদিবসের দাবিতে আন্দোলনরত শ্রমিকদের আত্মত্যাগের স্মরণে এই দিনটি পালিত হয়।',
      'desc_en': 'This day is observed in memory of the historic struggles and sacrifices of workers in Chicago in 1886 demanding an 8-hour workday.'
    },
    '08-15': {
      'title_bn': 'জাতীয় শোক দিবস',
      'title_en': 'National Mourning Day',
      'desc_bn': '১৯৭৫ সালের ১৫ই আগস্ট ভোরে একদল বিপথগামী সেনা কর্মকর্তার হাতে সপরিবারে নিহত হন বাংলাদেশের স্থপতি বঙ্গবন্ধু শেখ মুজিবুর রহমান।',
      'desc_en': 'On the morning of August 15, 1975, the architect of independent Bangladesh, Bangabandhu Sheikh Mujibur Rahman, was assassinated along with most of his family members.'
    },
    '12-16': {
      'title_bn': 'বিজয় দিবস',
      'title_en': 'Victory Day',
      'desc_bn': '১৯৭১ সালের এই দিনে দীর্ঘ ৯ মাস যুদ্ধের পর পাকিস্তানি বাহিনী ঢাকার রেসকোর্স ময়দানে আত্মসমর্পণ করে এবং বাংলাদেশ বিজয় লাভ করে।',
      'desc_en': 'On this day in 1971, after a 9-month war, Pakistani forces surrendered at the Racecourse Ground in Dhaka, and Bangladesh achieved victory.'
    },
    '12-25': {
      'title_bn': 'যীশু খ্রীষ্টের জন্মদিন (বড় দিন)',
      'title_en': 'Christmas Day',
      'desc_bn': 'খ্রিষ্টধর্মের প্রবর্তক যীশু খ্রীষ্টের জন্মদিন উপলক্ষে খ্রিষ্টান সম্প্রদায়ের সবচেয়ে বড় ধর্মীয় উৎসব।',
      'desc_en': 'The biggest religious festival of the Christian community, celebrating the birth anniversary of Jesus Christ.'
    },
  };

  static final Map<String, List<Map<String, String>>> _historicalEvents = {
    '02-21': [
      {'bn': '১৯৫২: রাষ্ট্রভাষা বাংলার দাবিতে ছাত্রদের মিছিলে পুলিশের গুলিবর্ষণ, শহীদ হন সালাম, বরকত, রফিক, জব্বারসহ অনেকে।', 'en': '1952: Police fired on student protesters demanding Bengali as a state language, martyrdom of Salam, Barkat, Rafiq, Jabbar.'},
      {'bn': '১৯৯৯: ইউনেস্কো ২১শে ফেব্রুয়ারিকে আন্তর্জাতিক মাতৃভাষা দিবস হিসেবে ঘোষণা করে।', 'en': '1999: UNESCO declared 21st February as International Mother Language Day.'}
    ],
    '03-07': [
      {'bn': '১৯৭১: ঢাকার রেসকোর্স ময়দানে বঙ্গবন্ধু শেখ মুজিবুর রহমান তাঁর ঐতিহাসিক ভাষণ প্রদান করেন।', 'en': '1971: Bangabandhu Sheikh Mujibur Rahman delivered his historic speech at the Racecourse Ground in Dhaka.'}
    ],
    '03-17': [
      {'bn': '১৯২০: গোপালগঞ্জের টুঙ্গিপাড়ায় স্বাধীন বাংলাদেশের স্থপতি বঙ্গবন্ধু শেখ মুজিবুর রহমান জন্মগ্রহণ করেন।', 'en': '1920: Bangabandhu Sheikh Mujibur Rahman, the father of the nation, was born in Tungipara.'}
    ],
    '03-26': [
      {'bn': '১৯৭১: বঙ্গবন্ধু কর্তৃক স্বাধীনতার ঘোষণা এবং মুক্তিযুদ্ধ শুরু।', 'en': '1971: Declaration of independence of Bangladesh by Bangabandhu and start of the liberation war.'}
    ],
    '04-10': [
      {'bn': '১৯৭১: বাংলাদেশের প্রথম অস্থায়ী সরকার (মুজিবনগর সরকার) গঠিত হয়।', 'en': '1971: Formation of the first provisional government of Bangladesh (Mujibnagar Government).'}
    ],
    '04-17': [
      {'bn': '১৯৭১: মেহেরপুরের বৈদ্যনাথতলার আম্রকাননে মুজিবনগর সরকারের শপথ গ্রহণ অনুষ্ঠান সম্পন্ন হয়।', 'en': '1971: Oath-taking ceremony of the Mujibnagar Government at Baidyanathtala, Meherpur.'}
    ],
    '05-01': [
      {'bn': '১৮৮৬: শিকাগোর হে মার্কেটে ৮ ঘণ্টা কর্মদিবসের দাবিতে শ্রমিকদের আন্দোলন ও আত্মত্যাগ।', 'en': '1886: Workers\' protest and sacrifices in Chicago for an 8-hour workday.'}
    ],
    '06-07': [
      {'bn': '১৯৬৬: পূর্ব পাকিস্তানের স্বায়ত্তশাসনের দাবিতে ছয় দফা দিবস পালিত হয়।', 'en': '1966: Six-Point Day observed demanding autonomy for East Pakistan.'}
    ],
    '06-23': [
      {'bn': '১৭৫৭: পলাশীর যুদ্ধে নবাব সিরাজউদ্দৌলার পরাজয়ের মাধ্যমে বাংলায় ব্রিটিশ শাসনের সূচনা হয়।', 'en': '1757: Battle of Plassey, defeat of Nawab Siraj-ud-Daulah, beginning of British rule in Bengal.'}
    ],
    '08-15': [
      {'bn': '১৯৭৫: ধানমন্ডির ৩২ নম্বরের বাসভবনে সপরিবারে বঙ্গবন্ধু শেখ মুজিবুর রহমান সপরিবারে নিহত হন।', 'en': '1975: Assassination of Bangabandhu Sheikh Mujibur Rahman and most of his family members.'}
    ],
    '11-03': [
      {'bn': '১৯৭৫: ঢাকা কেন্দ্রীয় কারাগারে জাতীয় চার নেতাকে নির্মমভাবে হত্যা করা হয় (জেল হত্যা দিবস)।', 'en': '1975: Brutal killing of the four national leaders in Dhaka Central Jail (Jail Killing Day).'}
    ],
    '12-14': [
      {'bn': '১৯৭১: পাকিস্তান সেনাবাহিনী ও তাদের দোসররা বাংলাদেশের প্রখ্যাত বুদ্ধিজীবীদের নির্মমভাবে হত্যা করে (শহীদ বুদ্ধিজীবী দিবস)।', 'en': '1971: Systematic execution of Bangladeshi intellectuals by Pakistani occupation forces (Martyred Intellectuals Day).'}
    ],
    '12-16': [
      {'bn': '১৯৭১: রেসকোর্স ময়দানে পাকিস্তানি সেনাবাহিনীর আত্মসমর্পণের মাধ্যমে বাংলাদেশের চূড়ান্ত বিজয় অর্জিত হয়।', 'en': '1971: Victory Day, formal surrender of Pakistani army at the Racecourse Ground.'}
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _syncFocusedMonthsWithSelectedDay();
    _fetchWikiHistory(_selectedDay);
  }

  void _syncFocusedMonthsWithSelectedDay() {
    _focusedGregorianYear = _selectedDay.year;
    _focusedGregorianMonth = _selectedDay.month;

    final bDateStr = BengaliDateHelper.getBengaliDate(_selectedDay);
    final bParts = bDateStr.split(' ');
    if (bParts.length >= 3) {
      final monthName = bParts[1].replaceAll(',', '');
      final bMonthIndex = BengaliDateHelper.getBengaliMonthIndex(monthName);
      _focusedBengaliMonth = bMonthIndex + 1;
      _focusedBengaliYear = BengaliDateHelper.fromBengaliDigits(bParts[2]);
    } else {
      _focusedBengaliMonth = 1;
      _focusedBengaliYear = 1433;
    }

    try {
      final hDate = HijriCalendar.fromDate(_selectedDay);
      _focusedHijriMonth = hDate.hMonth;
      _focusedHijriYear = hDate.hYear;
    } catch (_) {
      _focusedHijriMonth = 1;
      _focusedHijriYear = 1448;
    }
  }

  Future<String> _translateText(String text) async {
    if (_translations.containsKey(text)) {
      return _translations[text]!;
    }
    try {
      final url = 'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=en|bn';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final translated = data['responseData']['translatedText'] as String?;
        if (translated != null && translated.isNotEmpty) {
          _translations[text] = translated;
          return translated;
        }
      }
    } catch (_) {}
    return text;
  }

  Future<void> _fetchWikiHistory(DateTime date) async {
    final key = DateFormat('MM-dd').format(date);
    final bool isBn = LanguageManager().currentLanguage == 'bn';

    if (_historyCache.containsKey(key)) {
      setState(() {
        _dynamicHistoryEvents = _historyCache[key]!;
        _isLoadingHistory = false;
      });
      // Pre-translate top 2 events if they are not translated yet
      if (isBn) {
        bool updated = false;
        for (int i = 0; i < (_dynamicHistoryEvents.length > 2 ? 2 : _dynamicHistoryEvents.length); i++) {
          if (_dynamicHistoryEvents[i]['bn'] == null || _dynamicHistoryEvents[i]['bn'] == _dynamicHistoryEvents[i]['text']) {
            final trans = await _translateText(_dynamicHistoryEvents[i]['text']!);
            _dynamicHistoryEvents[i]['bn'] = trans;
            updated = true;
          }
        }
        if (updated && mounted) {
          setState(() {});
        }
      }
      return;
    }

    setState(() {
      _isLoadingHistory = true;
    });

    final monthStr = date.month.toString().padLeft(2, '0');
    final dayStr = date.day.toString().padLeft(2, '0');
    final url = 'https://en.wikipedia.org/api/rest_v1/feed/onthisday/all/$monthStr/$dayStr';

    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'StudyMateApp/1.0 (contact@studymate.com)'
      });
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final events = data['selected'] as List?;
        if (events != null) {
          final parsed = events.take(15).map<Map<String, String>>((e) {
            final text = e['text'] as String? ?? '';
            final year = e['year']?.toString() ?? '';
            return {
              'year': year,
              'text': text,
            };
          }).toList();
          
          _historyCache[key] = parsed;

          if (mounted && _selectedDay == date) {
            setState(() {
              _dynamicHistoryEvents = parsed;
              _isLoadingHistory = false;
            });

            // Pre-translate top 2 events if Bengali
            if (isBn) {
              for (int i = 0; i < (parsed.length > 2 ? 2 : parsed.length); i++) {
                final originalText = parsed[i]['text']!;
                final translated = await _translateText(originalText);
                parsed[i]['bn'] = translated;
              }
              if (mounted && _selectedDay == date) {
                setState(() {});
              }
            }
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted && _selectedDay == date) {
      setState(() {
        _dynamicHistoryEvents = _getStaticHistoryEvents(date);
        _isLoadingHistory = false;
      });
    }
  }

  List<Map<String, String>> _getStaticHistoryEvents(DateTime date) {
    final key = DateFormat('MM-dd').format(date);
    if (_historicalEvents.containsKey(key)) {
      return _historicalEvents[key]!;
    }
    return [
      {
        'bn': 'ইতিহাসের এই দিনে বিজ্ঞান, সাহিত্য ও আবিষ্কারের অঙ্গনে বিশ্বজুড়ে নানা মাইলফলক অর্জিত হয়েছিল।',
        'en': 'On this day in history, various academic, scientific and historical milestones were achieved worldwide.'
      }
    ];
  }

  Future<void> _launchGoogleSearch(String query) async {
    final url = Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(query)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Map<String, String>? _getSpecialDay(DateTime date, bool isBn) {
    final key = DateFormat('MM-dd').format(date);
    if (_gregorianSpecialDays.containsKey(key)) {
      final holiday = _gregorianSpecialDays[key]!;
      return {
        'title': isBn ? holiday['title_bn']! : holiday['title_en']!,
        'desc': isBn ? holiday['desc_bn']! : holiday['desc_en']!,
        'type': 'holiday'
      };
    }

    final islamicDay = IslamicService.getSpecialIslamicDay(date);
    if (islamicDay != null) {
      String title = islamicDay['title'] ?? '';
      String desc = islamicDay['desc'] ?? '';
      if (!isBn) {
        if (title == 'হিজরি নববর্ষ') {
          title = 'Hijri New Year';
          desc = 'Today is the 1st of Muharram, the Islamic New Year. Happy Hijri New Year!';
        } else if (title == 'আশুরা') {
          title = 'Ashura';
          desc = 'Today is the 10th of Muharram (Ashura). Fasting and prayers have special virtues.';
        } else if (title == 'ঈদে মিলাদুন্নবী (সা.)') {
          title = 'Eid Milad-un-Nabi';
          desc = 'Today is the 12th of Rabi\' al-awwal, marking the birth and passing of Prophet Muhammad (PBUH).';
        } else if (title == 'শবে মেরাজ') {
          title = 'Shab-e-Meraj';
          desc = 'Today is the 27th of Rajab, the night of Shab-e-Meraj. Observing prayers on this night has immense blessings.';
        } else if (title == 'শবে বরাত') {
          title = 'Shab-e-Barat';
          desc = 'Today is the 15th of Sha\'ban, the night of salvation and forgiveness.';
        } else if (title == 'রমজান শুরু') {
          title = 'Ramadan Starts';
          desc = 'Today is the first day of the holy month of Ramadan. Ramadan Mubarak!';
        } else if (title == 'শবে কদর') {
          title = 'Shab-e-Qadr';
          desc = 'Today is the 27th of Ramadan, Shab-e-Qadr. A night better than a thousand months.';
        } else if (title == 'ঈদুল ফিতর') {
          title = 'Eid-ul-Fitr';
          desc = 'Eid Mubarak! Today is the 1st of Shawwal, marking the celebration of Eid-ul-Fitr.';
        } else if (title == 'আরাফাহ দিবস') {
          title = 'Day of Arafah';
          desc = 'Today is the 9th of Dhu al-Hijjah, the day of Arafah. Fasting on this day expiates sins of the past and coming year.';
        } else if (title == 'ঈদুল আজহা') {
          title = 'Eid-ul-Adha';
          desc = 'Eid Mubarak! Today is the 10th of Dhu al-Hijjah, celebrating the festival of sacrifice.';
        }
      }
      return {
        'title': title,
        'desc': desc,
        'type': 'islamic'
      };
    }

    return null;
  }

  DateTime _getBengaliMonthStart(int bYear, int bMonth) {
    int gYear = (bMonth >= 1 && bMonth <= 9) ? (bYear + 593) : (bYear + 594);
    switch (bMonth) {
      case 1: return DateTime(gYear, 4, 14); // Boishakh
      case 2: return DateTime(gYear, 5, 15); // Joistho
      case 3: return DateTime(gYear, 6, 15); // Ashar
      case 4: return DateTime(gYear, 7, 16); // Shrabon
      case 5: return DateTime(gYear, 8, 16); // Bhadra
      case 6: return DateTime(gYear, 9, 17); // Ashwin
      case 7: return DateTime(gYear, 10, 17); // Kartik
      case 8: return DateTime(gYear, 11, 16); // Agrohayon
      case 9: return DateTime(gYear, 12, 16); // Poush
      case 10: return DateTime(gYear, 1, 15); // Magh
      case 11: return DateTime(gYear, 2, 14); // Falgun
      case 12: return DateTime(gYear, 3, 16); // Chaitra
      default: return DateTime(gYear, 4, 14);
    }
  }

  DateTime _getHijriMonthStart(int hYear, int hMonth) {
    try {
      HijriCalendar hStart = HijriCalendar();
      hStart.hYear = hYear;
      hStart.hMonth = hMonth;
      hStart.hDay = 1;
      return hStart.hijriToGregorian(hYear, hMonth, 1);
    } catch (_) {
      return DateTime.now();
    }
  }

  List<DateTime> _daysInActiveMonth() {
    DateTime firstDayOfActiveMonth;
    if (_activeCalendarSystem == 'bengali') {
      firstDayOfActiveMonth = _getBengaliMonthStart(_focusedBengaliYear, _focusedBengaliMonth);
    } else if (_activeCalendarSystem == 'hijri') {
      firstDayOfActiveMonth = _getHijriMonthStart(_focusedHijriYear, _focusedHijriMonth);
    } else {
      firstDayOfActiveMonth = DateTime(_focusedGregorianYear, _focusedGregorianMonth, 1);
    }

    final daysBefore = firstDayOfActiveMonth.weekday % 7;
    final firstToDisplay = firstDayOfActiveMonth.subtract(Duration(days: daysBefore));
    
    return List.generate(42, (index) => firstToDisplay.add(Duration(days: index)));
  }

  void _showHolidayDetail(BuildContext context, String title, String desc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.event_note_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Close'.tr()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAllHistoryPage(BuildContext context, DateTime date, bool isBn) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = isBn 
        ? DateFormat('d MMMM', 'bn').format(date)
        : DateFormat('d MMMM').format(date);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              appBar: AppBar(
                title: Text(isBn ? 'ইতিহাসের এই দিনে ($dateStr)' : 'Today in History ($dateStr)'),
                centerTitle: true,
              ),
              body: SafeArea(
                child: _isLoadingHistory
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _dynamicHistoryEvents.length,
                        itemBuilder: (context, index) {
                          final ev = _dynamicHistoryEvents[index];
                          final text = ev['text'] ?? '';
                          final year = ev['year'] ?? '';
                          final isTranslated = ev['bn'] != null && ev['bn'] != text;
                          final displayText = isBn 
                              ? (isTranslated ? ev['bn']! : text) 
                              : text;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.history_edu_rounded,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (year.isNotEmpty) ...[
                                          Text(
                                            isBn ? '$year সাল' : 'Year $year',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                        ],
                                        Text(
                                          displayText,
                                          style: TextStyle(
                                            fontSize: 15,
                                            height: 1.5,
                                            color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            if (isBn && !isTranslated)
                                              TextButton.icon(
                                                onPressed: () async {
                                                  setState(() {
                                                    _translatingKeys.add(text);
                                                  });
                                                  final trans = await _translateText(text);
                                                  setState(() {
                                                    ev['bn'] = trans;
                                                    _translatingKeys.remove(text);
                                                  });
                                                },
                                                icon: _translatingKeys.contains(text)
                                                    ? const SizedBox(
                                                        width: 12,
                                                        height: 12,
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      )
                                                    : const Icon(Icons.translate_rounded, size: 14),
                                                label: Text(
                                                  _translatingKeys.contains(text) ? 'অনুবাদ হচ্ছে...' : 'বাংলায় অনুবাদ',
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Theme.of(context).colorScheme.secondary,
                                                  padding: EdgeInsets.zero,
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                              )
                                            else
                                              const SizedBox(),
                                            InkWell(
                                              onTap: () => _launchGoogleSearch('$year $text'),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.search_rounded, 
                                                    size: 14, 
                                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isBn ? 'গুগলে খুঁজুন' : 'Search details',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Theme.of(context).colorScheme.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            );
          }
        ),
      ),
    );
  }

  String _getActiveMonthHeader(bool isBn) {
    if (_activeCalendarSystem == 'bengali') {
      final monthName = BengaliDateHelper.getBengaliMonthName(_focusedBengaliMonth - 1);
      final yearDigits = BengaliDateHelper.toBengaliDigits(_focusedBengaliYear.toString());
      return '$monthName $yearDigits';
    } else if (_activeCalendarSystem == 'hijri') {
      final monthName = isBn 
          ? _hijriMonthsBn[_focusedHijriMonth - 1]
          : _hijriMonthsEn[_focusedHijriMonth - 1];
      final yearDigits = isBn 
          ? BengaliDateHelper.toBengaliDigits(_focusedHijriYear.toString()) 
          : _focusedHijriYear.toString();
      return isBn ? '$monthName $yearDigits হিজরি' : '$monthName $yearDigits AH';
    } else {
      final gregorianDate = DateTime(_focusedGregorianYear, _focusedGregorianMonth, 1);
      return isBn 
          ? DateFormat('MMMM yyyy', 'bn').format(gregorianDate) 
          : DateFormat('MMMM yyyy').format(gregorianDate);
    }
  }

  Widget _buildSystemTab(String type, String label, Color color, bool isDark) {
    final isActive = _activeCalendarSystem == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeCalendarSystem = type;
            _syncFocusedMonthsWithSelectedDay();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive 
                ? color.withValues(alpha: 0.15) 
                : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? color : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08)),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: isActive ? [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ] : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 2,
                offset: const Offset(0, 1),
              )
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? color : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isBn = LanguageManager().currentLanguage == 'bn';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final Color gregorianColor = primaryColor;
    final Color bengaliColor = isDark ? Colors.orange.shade300 : Colors.deepOrange.shade800;
    final Color hijriColor = isDark ? Colors.teal.shade300 : Colors.teal.shade800;

    Color activeColor = gregorianColor;
    if (_activeCalendarSystem == 'bengali') {
      activeColor = bengaliColor;
    } else if (_activeCalendarSystem == 'hijri') {
      activeColor = hijriColor;
    }

    final days = _daysInActiveMonth();
    final String monthHeader = _getActiveMonthHeader(isBn);

    final String selectedGregorianStr = isBn
        ? DateFormat('EEEE, d MMMM, yyyy', 'bn').format(_selectedDay)
        : DateFormat('EEEE, d MMMM, yyyy').format(_selectedDay);

    final String selectedBengaliStr = BengaliDateHelper.getBengaliDate(_selectedDay);
    final String selectedHijriStr = IslamicService.getHijriDateBn(_selectedDay);
    final Map<String, String>? selectedSpecialDay = _getSpecialDay(_selectedDay, isBn);

    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        _buildSystemTab('gregorian', isBn ? 'গ্রেগরিয়ান' : 'Gregorian', gregorianColor, isDark),
                        const SizedBox(width: 4),
                        _buildSystemTab('bengali', isBn ? 'বঙ্গাব্দ' : 'Bangabda', bengaliColor, isDark),
                        const SizedBox(width: 4),
                        _buildSystemTab('hijri', isBn ? 'হিজরি' : 'Hijri', hijriColor, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded),
                        onPressed: () {
                          setState(() {
                            if (_activeCalendarSystem == 'bengali') {
                              if (_focusedBengaliMonth == 1) {
                                _focusedBengaliMonth = 12;
                                _focusedBengaliYear--;
                              } else {
                                _focusedBengaliMonth--;
                              }
                            } else if (_activeCalendarSystem == 'hijri') {
                              if (_focusedHijriMonth == 1) {
                                _focusedHijriMonth = 12;
                                _focusedHijriYear--;
                              } else {
                                _focusedHijriMonth--;
                              }
                            } else {
                              if (_focusedGregorianMonth == 1) {
                                _focusedGregorianMonth = 12;
                                _focusedGregorianYear--;
                              } else {
                                _focusedGregorianMonth--;
                              }
                            }
                          });
                          _fetchWikiHistory(DateTime(
                            _activeCalendarSystem == 'bengali' ? _focusedBengaliYear + 593 : (_activeCalendarSystem == 'hijri' ? _selectedDay.year : _focusedGregorianYear),
                            _activeCalendarSystem == 'bengali' ? _getBengaliMonthStart(_focusedBengaliYear, _focusedBengaliMonth).month : (_activeCalendarSystem == 'hijri' ? _selectedDay.month : _focusedGregorianMonth),
                            15
                          ));
                        },
                      ),
                      Text(
                        monthHeader,
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: activeColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios_rounded),
                        onPressed: () {
                          setState(() {
                            if (_activeCalendarSystem == 'bengali') {
                              if (_focusedBengaliMonth == 12) {
                                _focusedBengaliMonth = 1;
                                _focusedBengaliYear++;
                              } else {
                                _focusedBengaliMonth++;
                              }
                            } else if (_activeCalendarSystem == 'hijri') {
                              if (_focusedHijriMonth == 12) {
                                _focusedHijriMonth = 1;
                                _focusedHijriYear++;
                              } else {
                                _focusedHijriMonth++;
                              }
                            } else {
                              if (_focusedGregorianMonth == 12) {
                                _focusedGregorianMonth = 1;
                                _focusedGregorianYear++;
                              } else {
                                _focusedGregorianMonth++;
                              }
                            }
                          });
                          _fetchWikiHistory(DateTime(
                            _activeCalendarSystem == 'bengali' ? _focusedBengaliYear + 593 : (_activeCalendarSystem == 'hijri' ? _selectedDay.year : _focusedGregorianYear),
                            _activeCalendarSystem == 'bengali' ? _getBengaliMonthStart(_focusedBengaliYear, _focusedBengaliMonth).month : (_activeCalendarSystem == 'hijri' ? _selectedDay.month : _focusedGregorianMonth),
                            15
                          ));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: List.generate(7, (index) {
                      return Expanded(
                        child: Center(
                          child: Text(
                            isBn ? _weekDaysBn[index] : _weekDaysEn[index],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: 42,
                    itemBuilder: (context, index) {
                      final date = days[index];
                      final isToday = date.year == DateTime.now().year &&
                          date.month == DateTime.now().month &&
                          date.day == DateTime.now().day;
                      final isSelected = date.year == _selectedDay.year &&
                          date.month == _selectedDay.month &&
                          date.day == _selectedDay.day;

                      final bDateStr = BengaliDateHelper.getBengaliDate(date);
                      final bParts = bDateStr.split(' ');
                      final bDay = bParts[0];
                      int bMonth = 1;
                      int bYear = 1433;
                      if (bParts.length >= 3) {
                        bMonth = BengaliDateHelper.getBengaliMonthIndex(bParts[1].replaceAll(',', '')) + 1;
                        bYear = BengaliDateHelper.fromBengaliDigits(bParts[2]);
                      }

                      String hDay = '';
                      int hMonth = 1;
                      int hYear = 1448;
                      try {
                        final hDate = HijriCalendar.fromDate(date);
                        hDay = BengaliDateHelper.toBengaliDigits(hDate.hDay.toString());
                        hMonth = hDate.hMonth;
                        hYear = hDate.hYear;
                      } catch (_) {}

                      final gDay = date.day.toString();

                      bool isCurrentMonth = false;
                      if (_activeCalendarSystem == 'bengali') {
                        isCurrentMonth = bMonth == _focusedBengaliMonth && bYear == _focusedBengaliYear;
                      } else if (_activeCalendarSystem == 'hijri') {
                        isCurrentMonth = hMonth == _focusedHijriMonth && hYear == _focusedHijriYear;
                      } else {
                        isCurrentMonth = date.month == _focusedGregorianMonth && date.year == _focusedGregorianYear;
                      }

                      final special = _getSpecialDay(date, isBn);
                      final hasSpecial = special != null;

                      String centerDay = gDay;
                      String leftTopDay = bDay;
                      String rightTopDay = hDay;
                      Color leftColor = bengaliColor;
                      Color rightColor = hijriColor;

                      if (_activeCalendarSystem == 'bengali') {
                        centerDay = bDay;
                        leftTopDay = gDay;
                        rightTopDay = hDay;
                        leftColor = isDark ? Colors.white70 : Colors.black54;
                        rightColor = hijriColor;
                      } else if (_activeCalendarSystem == 'hijri') {
                        centerDay = hDay;
                        leftTopDay = gDay;
                        rightTopDay = bDay;
                        leftColor = isDark ? Colors.white70 : Colors.black54;
                        rightColor = bengaliColor;
                      }

                      Color cellBgColor = Colors.transparent;
                      Border? cellBorder;

                      if (isSelected) {
                        cellBgColor = activeColor.withValues(alpha: 0.15);
                        cellBorder = Border.all(color: activeColor, width: 2);
                      } else if (isToday) {
                        cellBorder = Border.all(color: isDark ? Colors.white30 : Colors.black26, width: 1.5);
                      } else if (hasSpecial) {
                        cellBgColor = special['type'] == 'holiday'
                            ? Colors.redAccent.withValues(alpha: 0.08)
                            : Colors.teal.withValues(alpha: 0.08);
                        cellBorder = Border.all(
                          color: special['type'] == 'holiday'
                              ? Colors.redAccent.withValues(alpha: 0.3)
                              : Colors.teal.withValues(alpha: 0.3),
                          width: 1,
                        );
                      }

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDay = date;
                          });
                          _fetchWikiHistory(date);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: cellBgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: cellBorder,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                centerDay,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrentMonth
                                      ? (isSelected ? activeColor : (isDark ? Colors.white : Colors.black))
                                      : (isDark ? Colors.white24 : Colors.black26),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                left: 4,
                                child: Text(
                                  leftTopDay,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrentMonth 
                                        ? leftColor.withValues(alpha: 0.8)
                                        : leftColor.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Text(
                                  rightTopDay,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrentMonth
                                        ? rightColor.withValues(alpha: 0.8)
                                        : rightColor.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                              if (hasSpecial)
                                Positioned(
                                  bottom: 6,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: special['type'] == 'holiday' 
                                          ? Colors.redAccent 
                                          : Colors.teal,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Selected Day Detail Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: ThemeManager.getCardDecoration(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, color: activeColor, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Selected Date'.tr(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20, color: Colors.white10),
                        _buildDateRow('English'.tr(), selectedGregorianStr, isDark),
                        _buildDateRow('Bengali'.tr(), selectedBengaliStr, isDark),
                        _buildDateRow('Islamic'.tr(), selectedHijriStr, isDark),
                        
                        if (selectedSpecialDay != null) ...[
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => _showHolidayDetail(
                              context, 
                              selectedSpecialDay['title']!, 
                              selectedSpecialDay['desc']!
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedSpecialDay['type'] == 'holiday' 
                                    ? Colors.redAccent.withValues(alpha: 0.15)
                                    : Colors.teal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selectedSpecialDay['type'] == 'holiday' 
                                      ? Colors.redAccent.withValues(alpha: 0.3)
                                      : Colors.teal.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.celebration_rounded, 
                                    color: selectedSpecialDay['type'] == 'holiday' 
                                        ? Colors.redAccent 
                                        : Colors.teal,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selectedSpecialDay['title']!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: selectedSpecialDay['type'] == 'holiday' 
                                                ? Colors.redAccent.shade200 
                                                : Colors.teal.shade300,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Tap to view description'.tr(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.white54 : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded, 
                                    size: 14, 
                                    color: isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Today in History Card (fetches from Wikipedia API dynamically)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: ThemeManager.getCardDecoration(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.history_edu_rounded, color: primaryColor, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  isBn ? 'ইতিহাসের এই দিনে' : 'Today in History',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            if (!_isLoadingHistory)
                              TextButton(
                                onPressed: () => _showAllHistoryPage(context, _selectedDay, isBn),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  isBn ? 'বিস্তারিত' : 'View All',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Divider(height: 20, color: Colors.white10),
                        if (_isLoadingHistory)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...List.generate(
                                _dynamicHistoryEvents.length > 2 ? 2 : _dynamicHistoryEvents.length,
                                (index) {
                                  final event = _dynamicHistoryEvents[index];
                                  final text = event['text'] ?? '';
                                  final year = event['year'] ?? '';
                                  final isTranslated = event['bn'] != null && event['bn'] != text;
                                  final displayContent = isBn 
                                      ? (isTranslated ? event['bn']! : text) 
                                      : text;
                                  final displayText = year.isNotEmpty ? '($year) $displayContent' : displayContent;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                                    child: InkWell(
                                      onTap: () => _launchGoogleSearch('$year $text'),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(top: 5.0),
                                              child: Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: primaryColor,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    displayText,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      height: 1.4,
                                                      color: isDark ? Colors.white70 : Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.search_rounded, 
                                                        size: 11, 
                                                        color: primaryColor.withValues(alpha: 0.6),
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        isBn ? 'বিস্তারিত খুঁজুন' : 'Search details',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: primaryColor.withValues(alpha: 0.8),
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    final dateStr = isBn 
                                        ? DateFormat('d MMMM', 'bn').format(_selectedDay)
                                        : DateFormat('d MMMM').format(_selectedDay);
                                    _launchGoogleSearch(isBn ? '$dateStr ইতিহাসের ঘটনা' : 'historical events on $dateStr');
                                  },
                                  icon: const Icon(Icons.search_rounded, size: 16),
                                  label: Text(
                                    isBn ? 'গুগলে আজকের দিনের ইতিহাস খুঁজুন' : 'Google Search Today\'s History',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primaryColor,
                                    side: BorderSide(color: primaryColor.withValues(alpha: 0.4)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
