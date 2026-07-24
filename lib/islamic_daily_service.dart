import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';

class IslamicHistoryEvent {
  final int hijriMonth;
  final int hijriDay;
  final String dateTextBn;
  final String titleBn;
  final String descriptionBn;
  final String titleEn;
  final String descriptionEn;

  const IslamicHistoryEvent({
    required this.hijriMonth,
    required this.hijriDay,
    required this.dateTextBn,
    required this.titleBn,
    required this.descriptionBn,
    required this.titleEn,
    required this.descriptionEn,
  });

  factory IslamicHistoryEvent.fromJson(Map<String, dynamic> json) {
    return IslamicHistoryEvent(
      hijriMonth: json['hijri_month'],
      hijriDay: json['hijri_day'],
      dateTextBn: json['date_text_bn'] ?? '',
      titleBn: json['title_bn'] ?? '',
      descriptionBn: json['description_bn'] ?? '',
      titleEn: json['title_en'] ?? '',
      descriptionEn: json['description_en'] ?? '',
    );
  }
}

class TodayDeeds {
  final Map<String, dynamic>? weeklyDeeds;
  final Map<String, dynamic>? hijriDeeds;
  final String? monthlyFocus;

  TodayDeeds({this.weeklyDeeds, this.hijriDeeds, this.monthlyFocus});
}
class IslamicDailyService {
  static List<IslamicHistoryEvent>? _cachedEvents;
  static Map<String, dynamic>? _cachedSpecialDeedsJson;

  static Future<void> loadEvents() async {
    if (_cachedEvents == null) {
      final String response = await rootBundle.loadString('assets/data/islamic_history.json');
      final data = json.decode(response) as List;
      _cachedEvents = data.map((json) => IslamicHistoryEvent.fromJson(json)).toList();
    }
    
    if (_cachedSpecialDeedsJson == null) {
      try {
        final String response = await rootBundle.loadString('assets/data/special_deeds.json');
        _cachedSpecialDeedsJson = json.decode(response);
      } catch (e) {
        print('Error loading special deeds from rootBundle: $e');
      }
    }
  }

  static Future<void> init() async {
    try {
      await loadEvents();
    } catch (e) {
      _cachedEvents = [];
    }
  }

  static Future<List<IslamicHistoryEvent>> getTodayHistoryEvents() async {
    if (_cachedEvents == null) {
      await init();
    }
    if (_cachedEvents!.isEmpty) return [];

    final hijriNow = HijriCalendar.now();
    int currentMonth = hijriNow.hMonth;
    int currentDay = hijriNow.hDay;

    // First try exact match
    List<IslamicHistoryEvent> exactMatches = _cachedEvents!.where((e) => e.hijriMonth == currentMonth && e.hijriDay == currentDay).toList();
    if (exactMatches.isNotEmpty) {
      return exactMatches;
    }

    // If no exact match, find the minimum distance
    int minDistance = 99999;
    for (var event in _cachedEvents!) {
      int eventAbsDay = event.hijriMonth * 30 + event.hijriDay;
      int currentAbsDay = currentMonth * 30 + currentDay;
      
      int dist = (eventAbsDay - currentAbsDay).abs();
      if (dist > 180) {
        dist = 360 - dist;
      }
      
      if (dist < minDistance) {
        minDistance = dist;
      }
    }

    // Now find all events that have this minimum distance
    List<IslamicHistoryEvent> closestEvents = [];
    for (var event in _cachedEvents!) {
      int eventAbsDay = event.hijriMonth * 30 + event.hijriDay;
      int currentAbsDay = currentMonth * 30 + currentDay;
      
      int dist = (eventAbsDay - currentAbsDay).abs();
      if (dist > 180) {
        dist = 360 - dist;
      }
      
      if (dist == minDistance) {
        closestEvents.add(event);
      }
    }

    if (closestEvents.isEmpty) {
      closestEvents.add(_cachedEvents!.first);
    }
    
    return closestEvents;
  }

  static Future<TodayDeeds> getSpecialDeedsForTodayAsync() async {
    await loadEvents(); // Ensure loaded
    
    Map<String, dynamic>? weekly;
    Map<String, dynamic>? hijri;
    String? focus;
    
    if (_cachedSpecialDeedsJson != null) {
      final now = DateTime.now();
      final hijriNow = HijriCalendar.now();
      
      // Weekly deeds
      final Map<String, dynamic>? allWeekly = _cachedSpecialDeedsJson!['weekly_deeds'];
      if (allWeekly != null) {
        weekly = allWeekly[now.weekday.toString()];
      }
      
      // Hijri deeds
      final List<dynamic>? allHijri = _cachedSpecialDeedsJson!['hijri_deeds'];
      if (allHijri != null) {
        for (var item in allHijri) {
          if (item['month'] == hijriNow.hMonth && item['day'] == hijriNow.hDay) {
            hijri = item;
            break;
          }
        }
      }
      
      // Monthly focus
      final Map<String, dynamic>? allFocus = _cachedSpecialDeedsJson!['monthly_focus'];
      if (allFocus != null) {
        focus = allFocus[hijriNow.hMonth.toString()];
      }
    }
    
    return TodayDeeds(
      weeklyDeeds: weekly,
      hijriDeeds: hijri,
      monthlyFocus: focus,
    );
  }
}

