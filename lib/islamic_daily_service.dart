import 'package:hijri/hijri_calendar.dart';

class IslamicHistoryEvent {
  final String title;
  final String summary;
  final String? url;

  const IslamicHistoryEvent({
    required this.title,
    required this.summary,
    this.url,
  });
}

class IslamicDailyService {
  static const List<IslamicHistoryEvent> _historyEvents = [
    IslamicHistoryEvent(
      title: 'Battle of Badr (বদর যুদ্ধ)',
      summary: 'The Battle of Badr was a key battle in the early days of Islam and a turning point in Muhammad\'s (PBUH) struggle with his opponents among the Quraish in Mecca.',
      url: 'https://bn.wikipedia.org/wiki/%E0%A6%AC%E0%A6%A6%E0%A6%B0%E0%A7%87%E0%A6%B0_%E0%A6%AF%E0%A7%81%E0%A6%A6%E0%A7%8D%E0%A6%A7',
    ),
    IslamicHistoryEvent(
      title: 'Conquest of Mecca (মক্কা বিজয়)',
      summary: 'The Conquest of Mecca is the event when Mecca was conquered by Muslims led by Prophet Muhammad (PBUH) in December 629 or January 630 AD.',
      url: 'https://bn.wikipedia.org/wiki/%E0%A6%AE%E0%A6%95%E0%A7%8D%E0%A6%95%E0%A6%BE_%E0%A6%AC%E0%A6%BF%E0%A6%9C%E0%A7%9F',
    ),
    IslamicHistoryEvent(
      title: 'Life of Abu Bakr (R) (আবু বকর (রা) এর জীবনী)',
      summary: 'Abu Bakr (R) was a senior companion (Sahabi) and the father-in-law of the Islamic prophet Muhammad (PBUH). He became the first Muslim Caliph following Muhammad\'s death.',
      url: 'https://bn.wikipedia.org/wiki/%E0%A6%86%E0%A6%AC%E0%A7%81_%E0%A6%AC%E0%A6%95%E0%A6%B0',
    ),
    IslamicHistoryEvent(
      title: 'Treaty of Hudaybiyyah (হুদায়বিয়ার সন্ধি)',
      summary: 'The Treaty of Hudaybiyyah was an event that took place during the time of the Islamic prophet Muhammad (PBUH). It was a pivotal treaty between Muhammad and the Quraish tribe.',
      url: 'https://bn.wikipedia.org/wiki/%E0%A6%B9%E0%A7%81%E0%A6%A6%E0%A6%BE%E0%A7%9F%E0%A6%AC%E0%A6%BF%E0%A7%9F%E0%A6%BE%E0%A6%B0_%E0%A6%B8%E0%A6%A8%E0%A7%8D%E0%A6%A7%E0%A6%BF',
    ),
    IslamicHistoryEvent(
      title: 'Battle of Khandaq (খন্দকের যুদ্ধ)',
      summary: 'The Battle of the Trench (Khandaq) was a 27-day-long defense by Muslims of Yathrib (now Medina) from Arab and Jewish tribes. The Muslims dug a trench to render the enemy cavalry ineffective.',
      url: 'https://bn.wikipedia.org/wiki/%E0%A6%96%E0%A6%A8%E0%A7%8D%E0%A6%A6%E0%A6%95%E0%A7%87%E0%A6%B0_%E0%A6%AF%E0%A7%81%E0%A6%A6%E0%A7%8D%E0%A6%A7',
    ),
    IslamicHistoryEvent(
      title: 'Life of Umar ibn al-Khattab (R) (ওমর ইবনুল খাত্তাব (রা) এর জীবনী)',
      summary: 'Umar (R) was one of the most powerful and influential Muslim caliphs in history. He was a senior companion of the Islamic prophet Muhammad (PBUH).',
      url: 'https://bn.wikipedia.org/wiki/%E0%A6%93%E0%A6%AE%E0%A6%B0_%E0%A6%87%E0%A6%AC%E0%A6%A8%E0%A7%81%E0%A6%B2_%E0%A6%96%E0%A6%BE%E0%A6%A4%E0%A7%8D%E0%A6%A4%E0%A6%BE%E0%A6%AC',
    ),
    IslamicHistoryEvent(
      title: 'Farewell Pilgrimage (বিদায় হজ্জ)',
      summary: 'The Farewell Pilgrimage was the last and only Hajj pilgrimage the Islamic prophet Muhammad (PBUH) participated in.',
      url: 'https://bn.wikipedia.org/wiki/%E0%A6%AC%E0%A6%BF%E0%A6%A6%E0%A6%BE%E0%A7%9F_%E0%A6%B9%E0%A6%9C%E0%A7%8D%E0%A6%9C',
    ),
  ];

  static IslamicHistoryEvent getTodayHistoryEvent() {
    final now = DateTime.now();
    final epoch = DateTime(2024, 1, 1);
    final diffDays = now.difference(epoch).inDays;
    
    final index = diffDays.abs() % _historyEvents.length;
    return _historyEvents[index];
  }

  static List<String> getSpecialDeedsForToday() {
    List<String> deeds = [];
    final now = DateTime.now();
    
    if (now.weekday == DateTime.friday) {
      deeds.add('Friday Sunnah: Read Surah Kahf (সূরা কাহাফ তেলাওয়াত করুন)');
      deeds.add('Friday Sunnah: Send Darood upon the Prophet (PBUH) (বেশি বেশি দরুদ পড়ুন)');
      deeds.add('Friday Sunnah: Cut nails and take a bath (নখ কাটা ও গোসল করা)');
    } else if (now.weekday == DateTime.monday || now.weekday == DateTime.thursday) {
      deeds.add('Weekly Sunnah: Fasting on Monday/Thursday (আজ সোমবার/বৃহস্পতিবার, সুন্নাহ রোজা রাখার দিন)');
    }

    try {
      final hijriNow = HijriCalendar.now();
      
      if (hijriNow.hDay == 13 || hijriNow.hDay == 14 || hijriNow.hDay == 15) {
        deeds.add('Ayyam al-Bid: Fasting is highly recommended (আজ আইয়ামে বিজের দিন, রোজা রাখার চেষ্টা করুন)');
      }

      if (hijriNow.hMonth == 1) {
        if (hijriNow.hDay == 9 || hijriNow.hDay == 10) {
          deeds.add('Ashura: Fasting on 9th/10th Muharram (আশুরার রোজা রাখুন)');
        }
      }

      if (hijriNow.hMonth == 9) {
        deeds.add('Ramadan: Perform Taraweeh and read Quran (তারাবিহ পড়ুন ও বেশি বেশি কুরআন তেলাওয়াত করুন)');
      }

      if (hijriNow.hMonth == 12 && hijriNow.hDay <= 10) {
        deeds.add('Dhul Hijjah: The best 10 days for good deeds (জিলহজ মাসের প্রথম ১০ দিন, বেশি বেশি আমল করুন)');
        if (hijriNow.hDay == 9) {
          deeds.add('Day of Arafah: Fasting expiates two years of sins (আরাফার দিন, রোজা রাখুন)');
        }
      }
    } catch (e) {
      // Fallback
    }

    if (deeds.isEmpty) {
      deeds.add('General Daily Sunnah: Read Ayatul Kursi after Fard prayers (নিয়মিত সুন্নাহ: ফরজ নামাজের পর আয়াতুল কুরসি পড়া)');
      deeds.add('General Daily Sunnah: Make Istighfar at least 100 times (বেশি বেশি ইস্তিগফার করুন)');
    }

    return deeds;
  }
}

