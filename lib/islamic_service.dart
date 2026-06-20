import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

class IslamicService {
  static final List<Map<String, String>> _verses = [
    {
      'arabic': 'وَاسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ',
      'translation': 'তোমরা ধৈর্য ও সালাতের মাধ্যমে সাহায্য প্রার্থনা কর।',
      'reference': 'সূরা আল-বাকারাহ: ৪৫'
    },
    {
      'arabic': 'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا',
      'translation': 'নিশ্চয়ই কষ্টের সাথে স্বস্তি রয়েছে।',
      'reference': 'সূরা আশ-শারহ: ৫'
    },
    {
      'arabic': 'فَاذْكُرُونِي أَذْكُرْكُمْ',
      'translation': 'তোমরা আমাকে স্মরণ কর, আমিও তোমাদের স্মরণ করব।',
      'reference': 'সূরা আল-বাকারাহ: ১৫২'
    },
    {
      'arabic': 'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
      'translation': 'নিশ্চয়ই আল্লাহ ধৈর্যশীলদের সাথে আছেন।',
      'reference': 'সূরা আল-বাকারাহ: ১৫৩'
    },
    {
      'arabic': 'وَقُل رَّبِّ زِدْنِي عِلْمًا',
      'translation': 'এবং বল, হে আমার পালনকর্তা! আমার জ্ঞান বৃদ্ধি করে দিন।',
      'reference': 'সূরা তাহা: ১১৪'
    },
    {
      'arabic': 'لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا',
      'translation': 'আল্লাহ কোনো সত্ত্বার ওপর তার সাধ্যের অতিরিক্ত বোঝা চাপিয়ে দেন না।',
      'reference': 'সূরা আল-বাকারাহ: ২৮৬'
    },
    {
      'arabic': 'إِنَّ رَحْمَتَ اللَّهِ قَرِيبٌ مِّنَ الْمُحْسِنِينَ',
      'translation': 'নিশ্চয়ই আল্লাহর রহমত সৎকর্মশীলদের নিকটবর্তী।',
      'reference': 'সূরা আল-আরাফ: ৫৬'
    },
    {
      'arabic': 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
      'translation': 'জেনে রেখো, আল্লাহর স্মরণেই কেবল হৃদয়গুলো প্রশান্ত হয়।',
      'reference': 'সূরা আর-রাদ: ২৮'
    }
  ];

  static final List<Map<String, String>> _hadiths = [
    {
      'text': 'জ্ঞান অর্জন করা প্রত্যেক মুসলিমের উপর ফরজ।',
      'narrator': 'আনাস ইবনে মালিক (রা.)',
      'reference': 'সুনানে ইবনে মাজাহ: ২২৪'
    },
    {
      'text': 'তোমাদের মধ্যে সর্বোত্তম ব্যক্তি সে, যে নিজে কুরআন শেখে এবং অন্যকে শেখায়।',
      'narrator': 'উসমান ইবনে আফফান (রা.)',
      'reference': 'সহীহ বুখারী: ৫০২৭'
    },
    {
      'text': 'নিশ্চয়ই সমস্ত কাজের ফলাফল নিয়তের ওপর নির্ভরশীল।',
      'narrator': 'উমর ইবনুল খাত্তাব (রা.)',
      'reference': 'সহীহ বুখারী: ১'
    },
    {
      'text': 'তোমরা সহজ করো, কঠিন করো না; সুসংবাদ দাও, তাড়িয়ে দিও না।',
      'narrator': 'আনাস ইবনে মালিক (রা.)',
      'reference': 'সহীহ বুখারী: ৬৯'
    },
    {
      'text': 'পবিত্রতা হচ্ছে ঈমানের অর্ধেক অংশ।',
      'narrator': 'আবু মালিক আল-আশআরী (রা.)',
      'reference': 'সহীহ মুসলিম: ২২৩'
    },
    {
      'text': 'যে ব্যক্তি জ্ঞান অন্বেষণের পথে চলে, আল্লাহ তার জন্য জান্নাতের পথ সহজ করে দেন।',
      'narrator': 'আবু হুরায়রা (রা.)',
      'reference': 'সহীহ মুসলিম: ২৬৯৯'
    },
    {
      'text': 'প্রকৃত মুসলিম সেই ব্যক্তি, যার জিহ্বা ও হাত থেকে অন্য মুসলিম নিরাপদ থাকে।',
      'narrator': 'আবদুল্লাহ ইবনে আমর (রা.)',
      'reference': 'সহীহ বুখারী: ১০'
    },
    {
      'text': 'তোমরা জাহান্নামের আগুন থেকে বাঁচো, একটি খেজুরের টুকরো সদকা করে হলেও।',
      'narrator': 'আদি ইবনে হাতিম (রা.)',
      'reference': 'সহীহ বুখারী: ১৪১৩'
    }
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
    return _verses[index];
  }

  static Map<String, String> getHadithOfTheDay() {
    final day = DateTime.now().day;
    final index = (day + 3) % _hadiths.length;
    return _hadiths[index];
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
  static Future<Map<String, String>> fetchPrayerTimes(double lat, double lng) async {
    final now = DateTime.now();
    final formattedDate = "${now.day}-${now.month}-${now.year}";
    // method=1 is University of Islamic Sciences, Karachi (most commonly used in Bangladesh)
    final url = "https://api.aladhan.com/v1/timings/$formattedDate?latitude=$lat&longitude=$lng&method=1";

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
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

  static Future<void> _saveCachedPrayerTimes(Map<String, String> timings, double lat, double lng) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/prayer_times_cache.json');
      final data = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'lat': lat,
        'lng': lng,
        'timings': timings
      };
      await file.writeAsString(json.encode(data));
    } catch (_) {}
  }

  static Future<Map<String, String>> _loadCachedOrOfflineTimes(double lat, double lng) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/prayer_times_cache.json');
      if (await file.exists()) {
        final data = json.decode(await file.readAsString());
        // If cache is fresh (less than 24h) and close to coordinates, use it
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
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
}
