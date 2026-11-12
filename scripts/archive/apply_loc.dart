import 'dart:io';

void main() {
  final file = File('lib/islamic_life_screen.dart');
  var content = file.readAsStringSync();

  if (!content.contains("import 'language_manager.dart';")) {
    content = content.replaceFirst(
        "import 'prayer_history_screen.dart';", 
        "import 'prayer_history_screen.dart';\nimport 'language_manager.dart';");
  }

  var isBn = "LanguageManager().isBengali";

  var replacements = {
    "'এশা (Isha)'": "$isBn ? 'এশা (Isha)' : 'Isha'",
    '"\${prayer[\'name\']} ওয়াক্ত শেষ হতে বাকি"': "$isBn ? '\${prayer[\'name\']} ওয়াক্ত শেষ হতে বাকি' : 'Time left for \${prayer[\'name\']}'",
    "'ফজর (Fajr)'": "$isBn ? 'ফজর (Fajr)' : 'Fajr'",
    "'জুমা (Jumma)'": "$isBn ? 'জুমা (Jumma)' : 'Jumma'",
    "'যোহর (Dhuhr)'": "$isBn ? 'যোহর (Dhuhr)' : 'Dhuhr'",
    "'আসর (Asr)'": "$isBn ? 'আসর (Asr)' : 'Asr'",
    "'মাগরিব (Maghrib)'": "$isBn ? 'মাগরিব (Maghrib)' : 'Maghrib'",
    "'ফজর (Fajr - Tomorrow)'": "$isBn ? 'ফজর (Fajr - Tomorrow)' : 'Fajr (Tomorrow)'",
    "Text('\$label কপি করা হয়েছে!')": "Text($isBn ? '\$label কপি করা হয়েছে!' : '\$label copied!')",
    "'নোটিফিকেশন সেটিংস'": "$isBn ? 'নোটিফিকেশন সেটিংস' : 'Notification Settings'",
    "'জিপিএস লোকেশন আপডেট'": "$isBn ? 'জিপিএস লোকেশন আপডেট' : 'Update GPS Location'",
    "'বিভাগ নির্বাচন করুন'": "$isBn ? 'বিভাগ নির্বাচন করুন' : 'Select Division'",
    "'আজকের হিজরি তারিখ:'": "$isBn ? 'আজকের হিজরি তারিখ:' : 'Today\\'s Hijri Date:'",
    "'জরুরী ওয়াক্ত শেষ হওয়ার কাউন্টডাউন'": "$isBn ? 'জরুরী ওয়াক্ত শেষ হওয়ার কাউন্টডাউন' : 'Countdown to end of urgent prayer time'",
    "'জুম্মাবার মোবারক'": "$isBn ? 'জুম্মাবার মোবারক' : 'Jumma Mubarak'",
    "'নামাজের কাউন্টডাউন'": "$isBn ? 'নামাজের কাউন্টডাউন' : 'Prayer Countdown'",
    "'ওয়াক্ত শেষ হতে বাকি সময়'": "$isBn ? 'ওয়াক্ত শেষ হতে বাকি সময়' : 'Time remaining to end'",
    "'শুরু হতে বাকি সময়'": "$isBn ? 'শুরু হতে বাকি সময়' : 'Time remaining to start'",
    "'জুম্মাবারের বিশেষ আমলসমূহ'": "$isBn ? 'জুম্মাবারের বিশেষ আমলসমূহ' : 'Special Jumma Deeds'",
    "'আজকের দিনের সুন্নত আমলগুলো সম্পন্ন করুন'": "$isBn ? 'আজকের দিনের সুন্নত আমলগুলো সম্পন্ন করুন' : 'Complete today\\'s sunnah deeds'",
    "'আজকের আয়াত'": "$isBn ? 'আজকের আয়াত' : 'Verse of the Day'",
    "'আজকের হাদিস'": "$isBn ? 'আজকের হাদিস' : 'Hadith of the Day'",
    '"হাদিস: \${_dailyHadith?[\'text\']} (বর্ণনায়: \${_dailyHadith?[\'narrator\']}) - \${_dailyHadith?[\'reference\']}"': "$isBn ? 'হাদিস: \${_dailyHadith?[\'text\']} (বর্ণনায়: \${_dailyHadith?[\'narrator\']}) - \${_dailyHadith?[\'reference\']}' : 'Hadith: \${_dailyHadith?[\'text\']} (Narrated by: \${_dailyHadith?[\'narrator\']}) - \${_dailyHadith?[\'reference\']}'",
    '"বর্ণনায়: \${_dailyHadith?[\'narrator\'] ?? \'\'}"': "$isBn ? 'বর্ণনায়: \${_dailyHadith?[\'narrator\'] ?? \'\'}' : 'Narrated by: \${_dailyHadith?[\'narrator\'] ?? \'\'}'",
    "'পবিত্র কুরআন শরীফ'": "$isBn ? 'পবিত্র কুরআন শরীফ' : 'Holy Quran'",
    "'সুরা-ভিত্তিক পাঠ • হাফেজি কুরআন (৬০৪ পৃষ্ঠা) • অফলাইন সাপোর্ট'": "$isBn ? 'সুরা-ভিত্তিক পাঠ • হাফেজি কুরআন (৬০৪ পৃষ্ঠা) • অফলাইন সাপোর্ট' : 'Surah-based • Hafezi Quran (604 pages) • Offline Support'",
    "'কিবলা কম্পাস'": "$isBn ? 'কিবলা কম্পাস' : 'Qibla Compass'",
    "'তাসবীহ কাউন্টার'": "$isBn ? 'তাসবীহ কাউন্টার' : 'Tasbeeh Counter'",
    "'পড়াশোনার দোয়া ও আমল'": "$isBn ? 'পড়াশোনার দোয়া ও আমল' : 'Study Duas & Deeds'",
    "'স্মৃতিশক্তি বৃদ্ধি • কঠিন বিষয় সহজ হওয়া • পড়াশোনা শুরুর দোয়া'": "$isBn ? 'স্মৃতিশক্তি বৃদ্ধি • কঠিন বিষয় সহজ হওয়া • পড়াশোনা শুরুর দোয়া' : 'Memory Boost • Ease Difficulties • Starting Study Dua'",
    "'নামাজের সময়সূচী'": "$isBn ? 'নামাজের সময়সূচী' : 'Prayer Times'",
    "'সূর্যোদয় (Sunrise)'": "$isBn ? 'সূর্যোদয় (Sunrise)' : 'Sunrise'",
    "'সূর্যাস্ত (Sunset)'": "$isBn ? 'সূর্যাস্ত (Sunset)' : 'Sunset'",
    "'নামাজের ইতিহাস'": "$isBn ? 'নামাজের ইতিহাস' : 'Prayer History'",
    "'বিস্তারিত রিপোর্ট'": "$isBn ? 'বিস্তারিত রিপোর্ট' : 'Detailed Report'",
    "'আলহামদুলিল্লাহ, আজ কোনো ওয়াক্ত নামাজ মিস নাই।'": "$isBn ? 'আলহামদুলিল্লাহ, আজ কোনো ওয়াক্ত নামাজ মিস নাই।' : 'Alhamdulillah, no prayers were missed today.'",
    "'আজ আপনার \$todayMissed ওয়াক্ত নামাজ মিস গেছে।'": "$isBn ? 'আজ আপনার \$todayMissed ওয়াক্ত নামাজ মিস গেছে।' : '\$todayMissed prayers missed today.'",
    "'এখনো নামাজের কোনো রেকর্ড নেই। ওয়াক্ত আদায় করে টিক দিন!'": "$isBn ? 'এখনো নামাজের কোনো রেকর্ড নেই। ওয়াক্ত আদায় করে টিক দিন!' : 'No prayer records yet. Pray and check them off!'",
    "'ফ'": "$isBn ? 'ফ' : 'F'",
    "'য'": "$isBn ? 'য' : 'D'",
    "'আ'": "$isBn ? 'আ' : 'A'",
    "'মা'": "$isBn ? 'মা' : 'M'",
    "'এ'": "$isBn ? 'এ' : 'I'",
    '"শুরু: \${_formatTo12Hour(start24h)}  •  শেষ: \${_formatTo12Hour(endLabel24h)}"': "$isBn ? 'শুরু: \${_formatTo12Hour(start24h)}  •  শেষ: \${_formatTo12Hour(endLabel24h)}' : 'Start: \${_formatTo12Hour(start24h)}  •  End: \${_formatTo12Hour(endLabel24h)}'",
    "'চলমান'": "$isBn ? 'চলমান' : 'Ongoing'",
    "'আজকের বিশেষ দিনের গুরুত্ব ও তাৎপর্য'": "$isBn ? 'আজকের বিশেষ দিনের গুরুত্ব ও তাৎপর্য' : 'Importance & Significance of Today'",
    
    // Jumma Sunnahs list
    "'গোসল করা'": "$isBn ? 'গোসল করা' : 'Perform Ghusl (Bath)'",
    "'পরিষ্কার পোশাক পরা ও সুগন্ধি লাগানো'": "$isBn ? 'পরিষ্কার পোশাক পরা ও সুগন্ধি লাগানো' : 'Wear Clean Clothes & Apply Attar'",
    "'সূরা আল-কাহাফ তেলাওয়াত করা'": "$isBn ? 'সূরা আল-কাহাফ তেলাওয়াত করা' : 'Recite Surah Al-Kahf'",
    "'রাসূলুল্লাহ (সা.) এর ওপর দরুদ পাঠ করা'": "$isBn ? 'রাসূলুল্লাহ (সা.) এর ওপর দরুদ পাঠ করা' : 'Send Salawat / Durood upon Prophet (pbuh)'",
    "'জুমার সালাতে আগে যাওয়া'": "$isBn ? 'জুমার সালাতে আগে যাওয়া' : 'Go Early to Mosque for Jummah'",

    "'১. জ্ঞান বৃদ্ধির দোয়া (পড়াশোনা শুরুর আগে)'": "$isBn ? '১. জ্ঞান বৃদ্ধির দোয়া (পড়াশোনা শুরুর আগে)' : '1. Dua for Increasing Knowledge (Before Studying)'",
    "'উচ্চারণ: রাব্বি যিদনি ইলমা।'": "$isBn ? 'উচ্চারণ: রাব্বি যিদনি ইলমা।' : 'Pronunciation: Rabbi zidni ilma.'",
    "'অর্থ: \"হে আমার পালনকর্তা! আমার জ্ঞান বৃদ্ধি করে দিন।\" (সূরা তাহা: ১১৪)'": "$isBn ? 'অর্থ: \"হে আমার পালনকর্তা! আমার জ্ঞান বৃদ্ধি করে দিন।\" (সূরা তাহা: ১১৪)' : 'Meaning: \"O my Lord! Increase me in knowledge.\" (Surah Taha: 114)'",
    "'পড়াশোনা শুরু করার আগে এই দোয়াটি বেশি বেশি পড়া উচিত।'": "$isBn ? 'পড়াশোনা শুরু করার আগে এই দোয়াটি বেশি বেশি পড়া উচিত।' : 'This dua should be recited frequently before starting to study.'",

    "'২. কঠিন বিষয় সহজ হওয়া ও জড়তা কাটার দোয়া'": "$isBn ? '২. কঠিন বিষয় সহজ হওয়া ও জড়তা কাটার দোয়া' : '2. Dua for Easing Difficulties and Removing Stutter'",
    "'উচ্চারণ: রাব্বিশ রাহলি সাদরি, ওয়া ইয়াসসিরলি আমরি, ওয়াহলুল উকদাতাম মিল লিসানি, ইয়াফকাহু কাওলি।'": "$isBn ? 'উচ্চারণ: রাব্বিশ রাহলি সাদরি, ওয়া ইয়াসসিরলি আমরি, ওয়াহলুল উকদাতাম মিল লিসানি, ইয়াফকাহু কাওলি।' : 'Pronunciation: Rabbish rahli sadri, wa yassirli amri, wahlul uqdatam mil lisani, yafqahu qawli.'",
    "'অর্থ: \"হে আমার পালনকর্তা! আমার বক্ষ প্রশস্ত করে দিন, আমার কাজ সহজ করে দিন এবং আমার জিহ্বার জড়তা দূর করে দিন যাতে তারা আমার কথা বুঝতে পারে।\" (সূরা তাহা: ২৫-২৮)'": "$isBn ? 'অর্থ: \"হে আমার পালনকর্তা! আমার বক্ষ প্রশস্ত করে দিন, আমার কাজ সহজ করে দিন এবং আমার জিহ্বার জড়তা দূর করে দিন যাতে তারা আমার কথা বুঝতে পারে।\" (সূরা তাহা: ২৫-২৮)' : 'Meaning: \"O my Lord! Expand for me my breast, ease for me my task, and untie the knot from my tongue that they may understand my speech.\" (Surah Taha: 25-28)'",
    "'পড়াশোনায় মন বসাতে বা কঠিন কোনো অধ্যায় বুঝতে এটি অত্যন্ত কার্যকর।'": "$isBn ? 'পড়াশোনায় মন বসাতে বা কঠিন কোনো অধ্যায় বুঝতে এটি অত্যন্ত কার্যকর।' : 'Very effective for focus and understanding difficult topics.'",

    "'৩. যেকোনো কঠিন কাজ সহজ করার দোয়া'": "$isBn ? '৩. যেকোনো কঠিন কাজ সহজ করার দোয়া' : '3. Dua for Making Difficult Tasks Easy'",
    "'উচ্চারণ: আল্লাহুম্মা লা সাহলা ইল্লা মা জা‘আলতাহু সাহলা, ওয়া আনতা তাজ‘আলুল হাযনা ইযা শি’তা সাহলা।'": "$isBn ? 'উচ্চারণ: আল্লাহুম্মা লা সাহলা ইল্লা মা জা‘আলতাহু সাহলা, ওয়া আনতা তাজ‘আলুল হাযনা ইযা শি’তা সাহলা।' : 'Pronunciation: Allahumma la sahla illa ma ja’altahu sahla, wa anta taj’alul hazna iza shi’ta sahla.'",
    "'অর্থ: \"হে আল্লাহ! আপনি যা সহজ করেছেন তা ছাড়া কোনো কিছুই সহজ নয়। আর আপনি চাইলে কঠিন কাজকেও সহজ করে দিতে পারেন।\" (সহীহ ইবনে হিব্বান)'": "$isBn ? 'অর্থ: \"হে আল্লাহ! আপনি যা সহজ করেছেন তা ছাড়া কোনো কিছুই সহজ নয়। আর আপনি চাইলে কঠিন কাজকেও সহজ করে দিতে পারেন।\" (সহীহ ইবনে হিব্বান)' : 'Meaning: \"O Allah, nothing is easy except what You have made easy, and You can make difficulty easy if You wish.\" (Sahih Ibn Hibban)'",
    "'পরীক্ষার হলে বা কঠিন প্রশ্ন দেখলে মনে মনে এই দোয়াটি পড়তে পারেন।'": "$isBn ? 'পরীক্ষার হলে বা কঠিন প্রশ্ন দেখলে মনে মনে এই দোয়াটি পড়তে পারেন।' : 'Recite this silently during exams or when facing difficult questions.'",

    "'৪. মেধা ও স্মৃতিশক্তি বৃদ্ধির দোয়া'": "$isBn ? '৪. মেধা ও স্মৃতিশক্তি বৃদ্ধির দোয়া' : '4. Dua for Memory Retention & Intelligence'",
    "'উচ্চারণ: আল্লাহুম্মান ফানি বিমা আল্লামতানি, ওয়া আল্লিমনি মা ইয়ানফাউনি, ওয়া যিদনি ইলমা।'": "$isBn ? 'উচ্চারণ: আল্লাহুম্মান ফানি বিমা আল্লামতানি, ওয়া আল্লিমনি মা ইয়ানফাউনি, ওয়া যিদনি ইলমা।' : 'Pronunciation: Allahumman fa’ni bima ‘allamtani, wa ‘allimni ma yanfa’uni, wa zidni ‘ilma.'",
    "'অর্থ: \"হে আল্লাহ! আপনি আমাকে যা শিখিয়েছেন তা দিয়ে আমাকে উপকৃত করুন, আমার জন্য যা উপকারী তা আমাকে শেখান এবং আমার জ্ঞান বৃদ্ধি করে দিন।\" (সুনানে ইবনে মাজাহ)'": "$isBn ? 'অর্থ: \"হে আল্লাহ! আপনি আমাকে যা শিখিয়েছেন তা দিয়ে আমাকে উপকৃত করুন, আমার জন্য যা উপকারী তা আমাকে শেখান এবং আমার জ্ঞান বৃদ্ধি করে দিন।\" (সুনানে ইবনে মাজাহ)' : 'Meaning: \"O Allah! Benefit me with what You have taught me, teach me what will benefit me, and increase my knowledge.\" (Sunan Ibn Majah)'",
    "'পড়া মনে রাখার এবং ব্রেইনের কার্যক্ষমতা বৃদ্ধির জন্য এই দোয়াটি পঠিত হয়।'": "$isBn ? 'পড়া মনে রাখার এবং ব্রেইনের কার্যক্ষমতা বৃদ্ধির জন্য এই দোয়াটি পঠিত হয়।' : 'Recite this to boost brain power and memory retention.'",
  };

  replacements.forEach((key, value) {
    content = content.replaceAll(key, value);
  });
  
  // Replace SnackBar format dynamically
  content = content.replaceAllMapped(
    RegExp(r"Text\('\$\{dua\['title'\]\} কপি হয়েছে'\)"),
    (match) => "Text($isBn ? '\${dua[\"title\"]} কপি হয়েছে' : '\${dua[\"title\"]} copied')"
  );
  
  // Custom replacements
  content = content.replaceAll('return "আজ (Today)";', "return $isBn ? 'আজ (Today)' : 'Today';");
  content = content.replaceAll('return "গতকাল (Yesterday)";', "return $isBn ? 'গতকাল (Yesterday)' : 'Yesterday';");
  
  var banglaMonthBlock = "final monthBangla = {";
  if (content.contains(banglaMonthBlock)) {
    var modifiedHistory = '''
    if (!LanguageManager().isBengali) {
      import 'package:intl/intl.dart';
      return DateFormat('d MMM').format(date);
    }
    final monthBangla = {''';
    content = content.replaceAll(banglaMonthBlock, modifiedHistory);
  }

  // Remove const from dynamic LanguageManager checks (handle ALL known consts here safely)
  content = content.replaceAll('const Padding(\n                        padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),\n                        child: Text(\n                          LanguageManager().isBengali',
                               'Padding(\n                        padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),\n                        child: Text(\n                          LanguageManager().isBengali');
  content = content.replaceAll('const Padding(\n                        padding: EdgeInsets.only(left: 4.0, bottom: 12.0),\n                        child: Text(\n                          LanguageManager().isBengali',
                               'Padding(\n                        padding: EdgeInsets.only(left: 4.0, bottom: 12.0),\n                        child: Text(\n                          LanguageManager().isBengali');

  content = content.replaceAll('const Text(LanguageManager().isBengali', 'Text(LanguageManager().isBengali');
  content = content.replaceAll("const {'title': LanguageManager().isBengali", "{'title': LanguageManager().isBengali");
  content = content.replaceAll("const [{\n        'title': LanguageManager().isBengali", "[{\n        'title': LanguageManager().isBengali");
  content = content.replaceAll("const [{'title': LanguageManager().isBengali", "[{'title': LanguageManager().isBengali");

  content = content.replaceAll('const Padding(', 'Padding(');
  content = content.replaceAll('const Row(', 'Row(');
  content = content.replaceAll('const Column(', 'Column(');
  content = content.replaceAll('const Center(', 'Center(');
  content = content.replaceAll('const Expanded(', 'Expanded(');

  // Added translations for english verse and hadith content inside the app itself if needed:
  // But wait! Quran Verses and Hadith might be in Arabic, and only translation is in Bengali.
  // We can't translate arbitrary hadith/ayat automatically if the API returns them in Bengali.
  // The user says "আর ইংলিশ ভার্সনে কুরানের আয়াতের অর্থটা ইংরেজিতে, হাদিসটাও ইংরেজিতে দিবে।"
  // That means we need to translate the *content* of _dailyHadith and _dailyAyat.
  // Wait, _dailyHadith has 'text', 'narrator', 'reference'. 
  // Are they Bengali text fetched from somewhere? Yes, `IslamicService.getHadithOfTheDay()`

  file.writeAsStringSync(content);
  print('Done applying localization');
}
