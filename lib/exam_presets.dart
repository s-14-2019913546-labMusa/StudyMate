import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'daily_routine.dart';

/// নতুন ব্যবহারকারীর পরীক্ষা অনুযায়ী আগে থেকে বসানো সিলেবাস (Study Map) ও সাপ্তাহিক রুটিন
class ExamPreset {
  final String id;
  final String nameEn;
  final String nameBn;
  final IconData icon;
  final Color color;

  /// বিষয় → অধ্যায়/টপিক
  final Map<String, List<String>> syllabus;

  const ExamPreset({
    required this.id,
    required this.nameEn,
    required this.nameBn,
    required this.icon,
    required this.color,
    required this.syllabus,
  });
}

class ExamPresets {
  static const List<ExamPreset> all = [
    ExamPreset(
      id: 'bcs',
      nameEn: 'BCS Preliminary',
      nameBn: 'বিসিএস প্রিলিমিনারি',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF16A34A),
      syllabus: {
        'বাংলা ভাষা ও সাহিত্য': ['ব্যাকরণ', 'প্রাচীন ও মধ্যযুগ', 'আধুনিক যুগ', 'বাংলা সাহিত্যিক ও গ্রন্থ'],
        'English Language & Literature': ['Grammar', 'Vocabulary', 'Literature'],
        'বাংলাদেশ বিষয়াবলি': ['ইতিহাস ও মুক্তিযুদ্ধ', 'সংবিধান', 'অর্থনীতি', 'ভূগোল ও সংস্কৃতি'],
        'আন্তর্জাতিক বিষয়াবলি': ['আন্তর্জাতিক সংস্থা', 'চলতি ঘটনা', 'বিশ্ব রাজনীতি'],
        'ভূগোল, পরিবেশ ও দুর্যোগ': ['বাংলাদেশের ভূগোল', 'পরিবেশ', 'দুর্যোগ ব্যবস্থাপনা'],
        'সাধারণ বিজ্ঞান': ['ভৌত বিজ্ঞান', 'জীববিজ্ঞান', 'আধুনিক বিজ্ঞান'],
        'কম্পিউটার ও তথ্যপ্রযুক্তি': ['কম্পিউটার মৌলিক', 'ইন্টারনেট ও নেটওয়ার্ক', 'সফটওয়্যার'],
        'গাণিতিক যুক্তি': ['পাটিগণিত', 'বীজগণিত', 'জ্যামিতি'],
        'মানসিক দক্ষতা': ['ভাষাগত যৌক্তিকতা', 'সংখ্যাগত ক্ষমতা', 'বানান ও সমস্যা সমাধান'],
        'নৈতিকতা, মূল্যবোধ ও সুশাসন': ['নৈতিকতা', 'সুশাসন'],
      },
    ),
    ExamPreset(
      id: 'bank',
      nameEn: 'Bank Job',
      nameBn: 'ব্যাংক জব',
      icon: Icons.savings_rounded,
      color: Color(0xFF2563EB),
      syllabus: {
        'বাংলা': ['ব্যাকরণ', 'সাহিত্য'],
        'English': ['Grammar', 'Vocabulary', 'Reading comprehension', 'Written (Essay/Letter)'],
        'গণিত': ['পাটিগণিত', 'বীজগণিত', 'জ্যামিতি', 'পরিসংখ্যান'],
        'সাধারণ জ্ঞান': ['বাংলাদেশ', 'আন্তর্জাতিক', 'ব্যাংকিং ও অর্থনীতি'],
        'কম্পিউটার': ['মৌলিক ধারণা', 'MS Office', 'ইন্টারনেট'],
      },
    ),
    ExamPreset(
      id: 'primary',
      nameEn: 'Primary Teacher',
      nameBn: 'প্রাইমারি শিক্ষক',
      icon: Icons.school_rounded,
      color: Color(0xFFF59E0B),
      syllabus: {
        'বাংলা': ['ব্যাকরণ', 'সাহিত্য'],
        'English': ['Grammar', 'Vocabulary'],
        'গণিত': ['পাটিগণিত', 'বীজগণিত', 'জ্যামিতি'],
        'সাধারণ জ্ঞান': ['বাংলাদেশ', 'আন্তর্জাতিক', 'বিজ্ঞান'],
      },
    ),
  ];

  static ExamPreset? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  static const List<String> _weekDays = ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday'];

  static DateTime _nextWeekday(String day) {
    const order = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final target = order.indexOf(day) + 1; // DateTime.monday == 1
    final now = DateTime.now();
    var diff = target - now.weekday;
    if (diff < 0) diff += 7;
    return DateTime(now.year, now.month, now.day).add(Duration(days: diff));
  }

  /// Study Map ফোল্ডার + (চাইলে) শনি–বৃহস্পতি সাপ্তাহিক রুটিন তৈরি করে
  static Future<void> apply(ExamPreset preset, {required bool withRoutine}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    // ১. Study Map (একই নামের ফোল্ডার থাকলে আবার বানানো হবে না)
    final folders = userRef.collection('studyFolders');
    final exists = await folders.where('name', isEqualTo: preset.nameBn).limit(1).get();
    if (exists.docs.isEmpty) {
      final doc = folders.doc();
      final hex = '#${preset.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      await doc.set({
        'id': doc.id,
        'name': preset.nameBn,
        'color': hex,
        'createdAt': FieldValue.serverTimestamp(),
        'subjects': [
          for (final e in preset.syllabus.entries)
            {
              'name': e.key,
              'targetNote': '',
              'topics': [
                for (final t in e.value) {'name': t, 'isCompleted': false, 'comments': []},
              ],
              'comments': [],
            },
        ],
      });
    }

    // ২. সাপ্তাহিক রুটিন: প্রতিদিন সকালে ও সন্ধ্যায় দুটি সেশন, বিষয়গুলো পালাক্রমে
    if (withRoutine) {
      final subjects = preset.syllabus.keys.toList();
      final weekly = userRef.collection('weeklyRoutines');
      final batch = FirebaseFirestore.instance.batch();
      var k = 0;
      for (final day in _weekDays) {
        final date = _nextWeekday(day);
        for (final slot in const [(7, 0, 8, 30), (20, 0, 21, 30)]) {
          final subject = subjects[k % subjects.length];
          k++;
          final start = DateTime(date.year, date.month, date.day, slot.$1, slot.$2);
          final end = DateTime(date.year, date.month, date.day, slot.$3, slot.$4);
          final id = 'preset_${preset.id}_${day}_${slot.$1}';
          final task = Task(
            id: id,
            title: subject,
            subject: subject,
            topic: '',
            notes: '',
            challenges: '',
            startTime: start,
            endTime: end,
            totalDurationMinutes: end.difference(start).inMinutes,
            category: 'Study',
          );
          batch.set(weekly.doc(day).collection('tasks').doc(id), task.toMap());
        }
      }
      await batch.commit();
    }

    await userRef.set({'examGoal': preset.id}, SetOptions(merge: true));
  }
}
