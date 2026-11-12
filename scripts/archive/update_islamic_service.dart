import 'dart:io';

void main() {
  final file = File('lib/islamic_service.dart');
  var content = file.readAsStringSync();

  // Add import for LanguageManager
  if (!content.contains("import 'language_manager.dart';")) {
    content = content.replaceFirst("import 'package:http/http.dart' as http;", "import 'package:http/http.dart' as http;\nimport 'language_manager.dart';");
  }

  // We need to inject 'en_translation' and 'en_reference' to _verses
  // We can just replace the whole _verses and _hadiths blocks.
  // It's much easier to just do a string replacement.
  
  var newVerses = '''
  static final List<Map<String, String>> _verses = [
    {
      'arabic': 'وَاسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ',
      'translation': 'তোমরা ধৈর্য ও সালাতের মাধ্যমে সাহায্য প্রার্থনা কর।',
      'en_translation': 'Seek help through patience and prayer.',
      'reference': 'সূরা আল-বাকারাহ: ৪৫',
      'en_reference': 'Surah Al-Baqarah: 45'
    },
    {
      'arabic': 'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا',
      'translation': 'নিশ্চয়ই কষ্টের সাথে স্বস্তি রয়েছে।',
      'en_translation': 'Indeed, with hardship comes ease.',
      'reference': 'সূরা আশ-শারহ: ৫',
      'en_reference': 'Surah Ash-Sharh: 5'
    },
    {
      'arabic': 'فَاذْكُرُونِي أَذْكُرْكُمْ',
      'translation': 'তোমরা আমাকে স্মরণ কর, আমিও তোমাদের স্মরণ করব।',
      'en_translation': 'So remember Me; I will remember you.',
      'reference': 'সূরা আল-বাকারাহ: ১৫২',
      'en_reference': 'Surah Al-Baqarah: 152'
    },
    {
      'arabic': 'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
      'translation': 'নিশ্চয়ই আল্লাহ ধৈর্যশীলদের সাথে আছেন।',
      'en_translation': 'Indeed, Allah is with the patient.',
      'reference': 'সূরা আল-বাকারাহ: ১৫৩',
      'en_reference': 'Surah Al-Baqarah: 153'
    },
    {
      'arabic': 'وَقُل رَّبِّ زِدْنِي عِلْمًا',
      'translation': 'এবং বল, হে আমার পালনকর্তা! আমার জ্ঞান বৃদ্ধি করে দিন।',
      'en_translation': 'And say, "My Lord, increase me in knowledge."',
      'reference': 'সূরা তাহা: ১১৪',
      'en_reference': 'Surah Taha: 114'
    },
    {
      'arabic': 'لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا',
      'translation': 'আল্লাহ কোনো সত্ত্বার ওপর তার সাধ্যের অতিরিক্ত বোঝা চাপিয়ে দেন না।',
      'en_translation': 'Allah does not burden a soul beyond that it can bear.',
      'reference': 'সূরা আল-বাকারাহ: ২৮৬',
      'en_reference': 'Surah Al-Baqarah: 286'
    },
    {
      'arabic': 'إِنَّ رَحْمَتَ اللَّهِ قَرِيبٌ مِّنَ الْمُحْسِنِينَ',
      'translation': 'নিশ্চয়ই আল্লাহর রহমত সৎকর্মশীলদের নিকটবর্তী।',
      'en_translation': 'Indeed, the mercy of Allah is near to the doers of good.',
      'reference': 'সূরা আল-আরাফ: ৫৬',
      'en_reference': 'Surah Al-Araf: 56'
    },
    {
      'arabic': 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
      'translation': 'জেনে রেখো, আল্লাহর স্মরণেই কেবল হৃদয়গুলো প্রশান্ত হয়।',
      'en_translation': 'Unquestionably, by the remembrance of Allah hearts are assured.',
      'reference': 'সূরা আর-রাদ: ২৮',
      'en_reference': 'Surah Ar-Ra\\'d: 28'
    }
  ];
''';

  var newHadiths = '''
  static final List<Map<String, String>> _hadiths = [
    {
      'text': 'জ্ঞান অর্জন করা প্রত্যেক মুসলিমের উপর ফরজ।',
      'en_text': 'Seeking knowledge is an obligation upon every Muslim.',
      'narrator': 'আনাস ইবনে মালিক (রা.)',
      'en_narrator': 'Anas ibn Malik (RA)',
      'reference': 'সুনানে ইবনে মাজাহ: ২২৪',
      'en_reference': 'Sunan Ibn Majah: 224'
    },
    {
      'text': 'তোমাদের মধ্যে সর্বোত্তম ব্যক্তি সে, যে নিজে কুরআন শেখে এবং অন্যকে শেখায়।',
      'en_text': 'The best among you are those who learn the Quran and teach it.',
      'narrator': 'উসমান ইবনে আফফান (রা.)',
      'en_narrator': 'Uthman ibn Affan (RA)',
      'reference': 'সহীহ বুখারী: ৫০২৭',
      'en_reference': 'Sahih Bukhari: 5027'
    },
    {
      'text': 'নিশ্চয়ই সমস্ত কাজের ফলাফল নিয়তের ওপর নির্ভরশীল।',
      'en_text': 'Indeed, the reward of deeds depends upon the intentions.',
      'narrator': 'উমর ইবনুল খাত্তাব (রা.)',
      'en_narrator': 'Umar ibn al-Khattab (RA)',
      'reference': 'সহীহ বুখারী: ১',
      'en_reference': 'Sahih Bukhari: 1'
    },
    {
      'text': 'তোমরা সহজ করো, কঠিন করো না; সুসংবাদ দাও, তাড়িয়ে দিও না।',
      'en_text': 'Make things easy for people and do not make them difficult, give good tidings and do not repel them.',
      'narrator': 'আনাস ইবনে মালিক (রা.)',
      'en_narrator': 'Anas ibn Malik (RA)',
      'reference': 'সহীহ বুখারী: ৬৯',
      'en_reference': 'Sahih Bukhari: 69'
    },
    {
      'text': 'পবিত্রতা হচ্ছে ঈমানের অর্ধেক অংশ।',
      'en_text': 'Purity is half of faith.',
      'narrator': 'আবু মালিক আল-আশআরী (রা.)',
      'en_narrator': 'Abu Malik Al-Ashari (RA)',
      'reference': 'সহীহ মুসলিম: ২২৩',
      'en_reference': 'Sahih Muslim: 223'
    },
    {
      'text': 'যে ব্যক্তি জ্ঞান অন্বেষণের পথে চলে, আল্লাহ তার জন্য জান্নাতের পথ সহজ করে দেন।',
      'en_text': 'Whoever travels a path in search of knowledge, Allah makes the path to Paradise easy for him.',
      'narrator': 'আবু হুরায়রা (রা.)',
      'en_narrator': 'Abu Huraira (RA)',
      'reference': 'সহীহ মুসলিম: ২৬৯৯',
      'en_reference': 'Sahih Muslim: 2699'
    },
    {
      'text': 'প্রকৃত মুসলিম সেই ব্যক্তি, যার জিহ্বা ও হাত থেকে অন্য মুসলিম নিরাপদ থাকে।',
      'en_text': 'A true Muslim is the one from whose tongue and hands the Muslims are safe.',
      'narrator': 'আবদুল্লাহ ইবনে আমর (রা.)',
      'en_narrator': 'Abdullah ibn Amr (RA)',
      'reference': 'সহীহ বুখারী: ১০',
      'en_reference': 'Sahih Bukhari: 10'
    },
    {
      'text': 'তোমরা জাহান্নামের আগুন থেকে বাঁচো, একটি খেজুরের টুকরো সদকা করে হলেও।',
      'en_text': 'Save yourselves from Hellfire, even by giving half a date in charity.',
      'narrator': 'আদি ইবনে হাতিম (রা.)',
      'en_narrator': 'Adi bin Hatim (RA)',
      'reference': 'সহীহ বুখারী: ১৪১৩',
      'en_reference': 'Sahih Bukhari: 1413'
    }
  ];
''';

  // Replace _verses block
  content = content.replaceFirst(RegExp(r'static final List<Map<String, String>> _verses = \[.*?\];', dotAll: true), newVerses.trim());
  // Replace _hadiths block
  content = content.replaceFirst(RegExp(r'static final List<Map<String, String>> _hadiths = \[.*?\];', dotAll: true), newHadiths.trim());

  // Update getters
  var newGetVerse = '''
  static Map<String, String> getVerseOfTheDay() {
    final day = DateTime.now().day;
    final index = day % _verses.length;
    final verse = _verses[index];
    if (LanguageManager().isBengali) {
      return {
        'arabic': verse['arabic']!,
        'translation': verse['translation']!,
        'reference': verse['reference']!
      };
    } else {
      return {
        'arabic': verse['arabic']!,
        'translation': verse['en_translation']!,
        'reference': verse['en_reference']!
      };
    }
  }
''';

  var newGetHadith = '''
  static Map<String, String> getHadithOfTheDay() {
    final day = DateTime.now().day;
    final index = (day + 3) % _hadiths.length;
    final hadith = _hadiths[index];
    if (LanguageManager().isBengali) {
      return {
        'text': hadith['text']!,
        'narrator': hadith['narrator']!,
        'reference': hadith['reference']!
      };
    } else {
      return {
        'text': hadith['en_text']!,
        'narrator': hadith['en_narrator']!,
        'reference': hadith['en_reference']!
      };
    }
  }
''';

  content = content.replaceFirst(RegExp(r'static Map<String, String> getVerseOfTheDay\(\) \{.*?\}', dotAll: true), newGetVerse.trim());
  content = content.replaceFirst(RegExp(r'static Map<String, String> getHadithOfTheDay\(\) \{.*?\}', dotAll: true), newGetHadith.trim());

  file.writeAsStringSync(content);
  print('Updated islamic_service.dart');
}
