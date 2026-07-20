import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'language_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hijri/hijri_calendar.dart';

class IslamicService {
  static final List<Map<String, String>> _verses = [
    {
      'arabic': 'وَاسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ',
      'translation': 'তোমরা ধৈর্য ও সালাতের মাধ্যমে সাহায্য প্রার্থনা কর।',
      'en_translation': 'Seek help through patience and prayer.',
      'reference': 'সূরা আল-বাকারাহ: ৪৫',
      'en_reference': 'Surah Al-Baqarah: 45',
    },
    {
      'arabic': 'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا',
      'translation': 'নিশ্চয়ই কষ্টের সাথে স্বস্তি রয়েছে।',
      'en_translation': 'Indeed, with hardship comes ease.',
      'reference': 'সূরা আশ-শারহ: ৫',
      'en_reference': 'Surah Ash-Sharh: 5',
    },
    {
      'arabic': 'فَاذْكُرُونِي أَذْكُرْكُمْ',
      'translation': 'তোমরা আমাকে স্মরণ কর, আমিও তোমাদের স্মরণ করব।',
      'en_translation': 'So remember Me; I will remember you.',
      'reference': 'সূরা আল-বাকারাহ: ১৫২',
      'en_reference': 'Surah Al-Baqarah: 152',
    },
    {
      'arabic': 'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
      'translation': 'নিশ্চয়ই আল্লাহ ধৈর্যশীলদের সাথে আছেন।',
      'en_translation': 'Indeed, Allah is with the patient.',
      'reference': 'সূরা আল-বাকারাহ: ১৫৩',
      'en_reference': 'Surah Al-Baqarah: 153',
    },
    {
      'arabic': 'وَقُل رَّبِّ زِدْنِي عِلْمًا',
      'translation': 'এবং বল, হে আমার পালনকর্তা! আমার জ্ঞান বৃদ্ধি করে দিন।',
      'en_translation': 'And say, "My Lord, increase me in knowledge."',
      'reference': 'সূরা তাহা: ১১৪',
      'en_reference': 'Surah Taha: 114',
    },
    {
      'arabic': 'لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا',
      'translation':
          'আল্লাহ কোনো সত্ত্বার ওপর তার সাধ্যের অতিরিক্ত বোঝা চাপিয়ে দেন না।',
      'en_translation': 'Allah does not burden a soul beyond that it can bear.',
      'reference': 'সূরা আল-বাকারাহ: ২৮৬',
      'en_reference': 'Surah Al-Baqarah: 286',
    },
    {
      'arabic': 'إِنَّ رَحْمَتَ اللَّهِ قَرِيبٌ مِّنَ الْمُحْسِنِينَ',
      'translation': 'নিশ্চয়ই আল্লাহর রহমত সৎকর্মশীলদের নিকটবর্তী।',
      'en_translation':
          'Indeed, the mercy of Allah is near to the doers of good.',
      'reference': 'সূরা আল-আরাফ: ৫৬',
      'en_reference': 'Surah Al-Araf: 56',
    },
    {
      'arabic': 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
      'translation': 'জেনে রেখো, আল্লাহর স্মরণেই কেবল হৃদয়গুলো প্রশান্ত হয়।',
      'en_translation':
          'Unquestionably, by the remembrance of Allah hearts are assured.',
      'reference': 'সূরা আর-রাদ: ২৮',
      'en_reference': 'Surah Ar-Ra\'d: 28',
    },
  ];

  static final List<Map<String, String>> _hadiths = [
    {
      'text': 'জ্ঞান অর্জন করা প্রত্যেক মুসলিমের উপর ফরজ।',
      'en_text': 'Seeking knowledge is an obligation upon every Muslim.',
      'narrator': 'আনাস ইবনে মালিক (রা.)',
      'en_narrator': 'Anas ibn Malik (RA)',
      'reference': 'সুনানে ইবনে মাজাহ: ২২৪',
      'en_reference': 'Sunan Ibn Majah: 224',
    },
    {
      'text':
          'তোমাদের মধ্যে সর্বোত্তম ব্যক্তি সে, যে নিজে কুরআন শেখে এবং অন্যকে শেখায়।',
      'en_text':
          'The best among you are those who learn the Quran and teach it.',
      'narrator': 'উসমান ইবনে আফফান (রা.)',
      'en_narrator': 'Uthman ibn Affan (RA)',
      'reference': 'সহীহ বুখারী: ৫০২৭',
      'en_reference': 'Sahih Bukhari: 5027',
    },
    {
      'text': 'নিশ্চয়ই সমস্ত কাজের ফলাফল নিয়তের ওপর নির্ভরশীল।',
      'en_text': 'Indeed, the reward of deeds depends upon the intentions.',
      'narrator': 'উমর ইবনুল খাত্তাব (রা.)',
      'en_narrator': 'Umar ibn al-Khattab (RA)',
      'reference': 'সহীহ বুখারী: ১',
      'en_reference': 'Sahih Bukhari: 1',
    },
    {
      'text': 'তোমরা সহজ করো, কঠিন করো না; সুসংবাদ দাও, তাড়িয়ে দিও না।',
      'en_text':
          'Make things easy for people and do not make them difficult, give good tidings and do not repel them.',
      'narrator': 'আনাস ইবনে মালিক (রা.)',
      'en_narrator': 'Anas ibn Malik (RA)',
      'reference': 'সহীহ বুখারী: ৬৯',
      'en_reference': 'Sahih Bukhari: 69',
    },
    {
      'text': 'পবিত্রতা হচ্ছে ঈমানের অর্ধেক অংশ।',
      'en_text': 'Purity is half of faith.',
      'narrator': 'আবু মালিক আল-আশআরী (রা.)',
      'en_narrator': 'Abu Malik Al-Ashari (RA)',
      'reference': 'সহীহ মুসলিম: ২২৩',
      'en_reference': 'Sahih Muslim: 223',
    },
    {
      'text':
          'যে ব্যক্তি জ্ঞান অন্বেষণের পথে চলে, আল্লাহ তার জন্য জান্নাতের পথ সহজ করে দেন।',
      'en_text':
          'Whoever travels a path in search of knowledge, Allah makes the path to Paradise easy for him.',
      'narrator': 'আবু হুরায়রা (রা.)',
      'en_narrator': 'Abu Huraira (RA)',
      'reference': 'সহীহ মুসলিম: ২৬৯৯',
      'en_reference': 'Sahih Muslim: 2699',
    },
    {
      'text':
          'প্রকৃত মুসলিম সেই ব্যক্তি, যার জিহ্বা ও হাত থেকে অন্য মুসলিম নিরাপদ থাকে।',
      'en_text':
          'A true Muslim is the one from whose tongue and hands the Muslims are safe.',
      'narrator': 'আবদুল্লাহ ইবনে আমর (রা.)',
      'en_narrator': 'Abdullah ibn Amr (RA)',
      'reference': 'সহীহ বুখারী: ১০',
      'en_reference': 'Sahih Bukhari: 10',
    },
    {
      'text':
          'তোমরা জাহান্নামের আগুন থেকে বাঁচো, একটি খেজুরের টুকরো সদকা করে হলেও।',
      'en_text':
          'Save yourselves from Hellfire, even by giving half a date in charity.',
      'narrator': 'আদি ইবনে হাতিম (রা.)',
      'en_narrator': 'Adi bin Hatim (RA)',
      'reference': 'সহীহ বুখারী: ১৪১৩',
      'en_reference': 'Sahih Bukhari: 1413',
    },
  ];

  // static lookup table for divisions of Bangladesh
  static final Map<String, Map<String, dynamic>> divisionData = {
    'Dhaka': {'lat': 23.8103, 'lng': 90.4125, 'name': 'ঢাকা'},
    'Chittagong': {'lat': 22.3569, 'lng': 91.7832, 'name': 'চট্টগ্রাম'},
    'Sylhet': {'lat': 24.8949, 'lng': 91.8687, 'name': 'সিলেট'},
    'Rajshahi': {'lat': 24.3636, 'lng': 88.6241, 'name': 'রাজশাহী'},
    'Khulna': {'lat': 22.8456, 'lng': 89.5403, 'name': 'খুলনা'},
    'Barisal': {'lat': 22.7010, 'lng': 90.3535, 'name': 'বরিশাল'},
    'Rangpur': {'lat': 25.7439, 'lng': 89.2753, 'name': 'রংপুর'},
    'Mymensingh': {'lat': 24.7471, 'lng': 90.4203, 'name': 'ময়মনসিংহ'},
  };

  // Select random Quran verse and Hadith based on seed (e.g., day of month) to keep it stable for 24h
  static Map<String, String> getVerseOfTheDay() {
    final day = DateTime.now().day;
    final index = day % _verses.length;
    final verse = _verses[index];
    if (LanguageManager().isBengali) {
      return {
        'arabic': verse['arabic']!,
        'translation': verse['translation']!,
        'reference': verse['reference']!,
      };
    } else {
      return {
        'arabic': verse['arabic']!,
        'translation': verse['en_translation']!,
        'reference': verse['en_reference']!,
      };
    }
  }

  static Map<String, String> getHadithOfTheDay() {
    final day = DateTime.now().day;
    final index = (day + 3) % _hadiths.length;
    final hadith = _hadiths[index];
    if (LanguageManager().isBengali) {
      return {
        'text': hadith['text']!,
        'narrator': hadith['narrator']!,
        'reference': hadith['reference']!,
      };
    } else {
      return {
        'text': hadith['en_text']!,
        'narrator': hadith['en_narrator']!,
        'reference': hadith['en_reference']!,
      };
    }
  }

  // Get user location coordinates, fall back to Dhaka if denied/unavailable
  static Future<Position?> determinePosition() async {
    try {
      return await _determinePositionRaw().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint("IslamicService: Location determination timed out.");
          return null;
        },
      );
    } catch (e) {
      debugPrint("IslamicService: Location determination failed: $e");
      return null;
    }
  }

  static Future<Position?> _determinePositionRaw() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return null;
    }
  }

  // Fetch prayer times using the public Aladhan API
  static Future<Map<String, String>> fetchPrayerTimes(
    double lat,
    double lng,
  ) async {
    final now = DateTime.now();
    final formattedDate = "${now.day}-${now.month}-${now.year}";
    // method=1 is University of Islamic Sciences, Karachi (most commonly used in Bangladesh)
    final url =
        "https://api.aladhan.com/v1/timings/$formattedDate?latitude=$lat&longitude=$lng&method=1";

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['data'] != null) {
          final timings = data['data']['timings'] as Map<String, dynamic>;
          final parsedTimings = {
            'Fajr': timings['Fajr'] as String,
            'Sunrise': timings['Sunrise'] as String,
            'Dhuhr': timings['Dhuhr'] as String,
            'Asr': timings['Asr'] as String,
            'Maghrib': timings['Maghrib'] as String,
            'Isha': timings['Isha'] as String,
          };
          await _saveCachedPrayerTimes(parsedTimings, lat, lng);
          return parsedTimings;
        }
      }
      throw Exception("Invalid API response");
    } catch (e) {
      // Fallback to cache or offline default
      return await _loadCachedOrOfflineTimes(lat, lng);
    }
  }

  static Future<void> _saveCachedPrayerTimes(
    Map<String, String> timings,
    double lat,
    double lng,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/prayer_times_cache.json');
      final data = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'lat': lat,
        'lng': lng,
        'timings': timings,
      };
      await file.writeAsString(json.encode(data));
    } catch (_) {}
  }

  static Future<Map<String, String>> _loadCachedOrOfflineTimes(
    double lat,
    double lng,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/prayer_times_cache.json');
      if (await file.exists()) {
        final data = json.decode(await file.readAsString());
        // If cache is fresh (less than 24h) and close to coordinates, use it
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(
          data['timestamp'],
        );
        if (DateTime.now().difference(cacheTime).inHours < 24) {
          return Map<String, String>.from(data['timings']);
        }
      }
    } catch (_) {}

    // Offline Division-level Fallback
    // Determine closest division based on coordinate distances
    String closestDivision = 'Dhaka';
    double minDistance = double.maxFinite;

    divisionData.forEach((key, val) {
      final double dLat = val['lat'] - lat;
      final double dLng = val['lng'] - lng;
      final double dist = dLat * dLat + dLng * dLng;
      if (dist < minDistance) {
        minDistance = dist;
        closestDivision = key;
      }
    });

    return _getOfflineTimesForDivision(closestDivision);
  }

  // Pre-baked estimations for divisions in Bangladesh (approximate averages for June/Summer solstice)
  static Map<String, String> _getOfflineTimesForDivision(String division) {
    // Basic Summer offset adjustments relative to Dhaka
    switch (division) {
      case 'Chittagong':
        return {
          'Fajr': '03:48',
          'Sunrise': '05:10',
          'Dhuhr': '11:58',
          'Asr': '04:30',
          'Maghrib': '06:40',
          'Isha': '08:08',
        };
      case 'Sylhet':
        return {
          'Fajr': '03:41',
          'Sunrise': '05:05',
          'Dhuhr': '11:57',
          'Asr': '04:33',
          'Maghrib': '06:44',
          'Isha': '08:14',
        };
      case 'Rajshahi':
        return {
          'Fajr': '03:57',
          'Sunrise': '05:22',
          'Dhuhr': '12:12',
          'Asr': '04:41',
          'Maghrib': '06:57',
          'Isha': '08:24',
        };
      case 'Khulna':
        return {
          'Fajr': '03:59',
          'Sunrise': '05:21',
          'Dhuhr': '12:08',
          'Asr': '04:36',
          'Maghrib': '06:51',
          'Isha': '08:17',
        };
      case 'Barisal':
        return {
          'Fajr': '03:55',
          'Sunrise': '05:17',
          'Dhuhr': '12:04',
          'Asr': '04:33',
          'Maghrib': '06:46',
          'Isha': '08:12',
        };
      case 'Rangpur':
        return {
          'Fajr': '03:50',
          'Sunrise': '05:17',
          'Dhuhr': '12:09',
          'Asr': '04:42',
          'Maghrib': '06:58',
          'Isha': '08:27',
        };
      case 'Mymensingh':
        return {
          'Fajr': '03:46',
          'Sunrise': '05:11',
          'Dhuhr': '12:03',
          'Asr': '04:36',
          'Maghrib': '06:51',
          'Isha': '08:18',
        };
      case 'Dhaka':
      default:
        return {
          'Fajr': '03:52',
          'Sunrise': '05:15',
          'Dhuhr': '12:03',
          'Asr': '04:34',
          'Maghrib': '06:48',
          'Isha': '08:15',
        };
    }
  }

  static final List<String> hijriMonthsBn = [
    'মুহররম',
    'সফর',
    'রবিউল আউয়াল',
    'রবিউস সানি',
    'জুমাদাল উলা',
    'জুমাদাস সানি',
    'রজব',
    'শাবান',
    'রমজান',
    'শাওয়াল',
    'জিলকদ',
    'জিলহজ',
  ];

  static String toBengaliNumbers(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bengali = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], bengali[i]);
    }
    return input;
  }

  static String getHijriDateBn(DateTime date) {
    try {
      final hDate = HijriCalendar.fromDate(date);
      return _convertToBengaliHijriString(hDate);
    } catch (e) {
      return "হিজরি তারিখ লোড হচ্ছে...";
    }
  }

  static String _convertToBengaliHijriString(HijriCalendar hDate) {
    try {
      final day = toBengaliNumbers(hDate.hDay.toString());
      final month = hijriMonthsBn[hDate.hMonth - 1];
      final year = toBengaliNumbers(hDate.hYear.toString());
      return "$day $month, $year হিজরি";
    } catch (_) {
      return '';
    }
  }

  static Map<String, String>? getSpecialIslamicDay(DateTime date) {
    try {
      final hDate = HijriCalendar.fromDate(date);
      final month = hDate.hMonth;
      final day = hDate.hDay;

      if (month == 1 && day == 1) {
        return {
          'title': 'হিজরি নববর্ষ',
          'desc': 'আজ হিজরি নববর্ষ (১ মুহররম)। নতুন হিজরি বছরের শুভেচ্ছা!',
        };
      }
      if (month == 1 && day == 10) {
        return {
          'title': 'আশুরা',
          'desc':
              'আজ পবিত্র আশুরা (১০ মুহররম)। রোজা রাখা ও ইবাদতের বিশেষ ফজিলত রয়েছে।',
        };
      }
      if (month == 3 && day == 12) {
        return {
          'title': 'ঈদে মিলাদুন্নবী (সা.)',
          'desc':
              'আজ ১২ রবিউল আউয়াল, প্রিয়নবী হযরত মুহাম্মদ (সা.)-এর জন্ম ও ওফাত দিবস।',
        };
      }
      if (month == 7 && day == 27) {
        return {
          'title': 'শবে মেরাজ',
          'desc':
              'আজ পবিত্র শবে মেরাজ (২৭ রজব)। শবে মেরাজের রজনীতে ইবাদত-বندهগী করা অত্যন্ত পুণ্যময়।',
        };
      }
      if (month == 8 && day == 15) {
        return {
          'title': 'শবে বরাত',
          'desc':
              'আজ পবিত্র শবে বরাত (১৫ শাবান)। ক্ষমার রজনীতে নফল ইবাদত ও দিনের বেলা রোজা রাখার ফজিলত রয়েছে।',
        };
      }
      if (month == 9 && day == 1) {
        return {
          'title': 'রমজান শুরু',
          'desc': 'আজ রমজান মাসের প্রথম দিন। বরকতময় সিয়াম সাধনার মাস শুরু হলো।',
        };
      }
      if (month == 9 && day == 27) {
        return {
          'title': 'শবে কদর',
          'desc':
              'আজ পবিত্র শবে কদর (২৭ রমজান)। হাজার মাসের চেয়েও শ্রেষ্ঠ রজনীতে ইবাদতে আত্মনিয়োগ করুন।',
        };
      }
      if (month == 10 && day == 1) {
        return {
          'title': 'ঈদুল ফিতর',
          'desc':
              'ঈদ মোবারক! আজ পবিত্র ঈদুল ফিতর (১ শাওয়াল)। আনন্দ ও উৎসবের দিন।',
        };
      }
      if (month == 12 && day == 9) {
        return {
          'title': 'আরাফাহ দিবস',
          'desc':
              'আজ পবিত্র আরাফাহ দিবস (৯ জিলহজ)। হজের মূল দিন এবং এই দিনে নফল রোজার অশেষ ফজিলত।',
        };
      }
      if (month == 12 && day == 10) {
        return {
          'title': 'ঈদুল আজহা',
          'desc':
              'ঈদ মোবারক! আজ পবিত্র ঈদুল আজহা (১০ জিলহজ)। ত্যাগের মহিমায় উদ্ভাসিত হোক কুরবানির দিন।',
        };
      }
    } catch (_) {}
    return null;
  }
}
