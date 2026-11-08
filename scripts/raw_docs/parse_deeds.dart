import 'dart:io';
import 'dart:convert';

void main() async {
  final content = await File('extracted_deeds.txt').readAsString();
  final lines = content.split('\n').map((e) => e.trim()).toList();
  
  Map<String, dynamic> output = {
    'weekly_deeds': {},
    'monthly_focus': {},
    'hijri_deeds': []
  };

  int i = 0;
  
  // Weekly Deeds Map (Mapping numbers 1-7 starting from Sunday or Monday)
  // Let's assume standard Dart DateTime.weekday mapping: 1=Monday, 7=Sunday
  Map<String, int> weekDays = {
    "সোমবার": 1,
    "মঙ্গলবার": 2,
    "বুধবার": 3,
    "বৃহস্পতিবার": 4,
    "শুক্রবার": 5,
    "শনিবার": 6,
    "রবিবার": 7
  };

  int currentMonth = 0;
  int currentDay = 0;

  String? title;
  String regularDeeds = "";
  String specialDeeds = "";
  String warning = "";

  while (i < lines.length) {
    String line = lines[i];
    if (line.isEmpty) { i++; continue; }

    // Check Weekly Deeds parsing (1. রবিবার ... 7. শনিবার)
    bool matchedWeekDay = false;
    for (var key in weekDays.keys) {
      if (line.contains(key) && (line.startsWith('১.') || line.startsWith('২.') || line.startsWith('৩.') || line.startsWith('৪.') || line.startsWith('৫.') || line.startsWith('৬.') || line.startsWith('৭.'))) {
        int wDay = weekDays[key]!;
        String deedText = "";
        String warnText = "";
        i++;
        while (i < lines.length && !lines[i].startsWith('🗓️')) {
          // Check if this line is a new day header
          bool isNextDay = false;
          if (lines[i].startsWith(RegExp(r'[১-৭]\.'))) {
             for (var k in weekDays.keys) {
               if (lines[i].contains(k)) {
                 isNextDay = true;
                 break;
               }
             }
          }
          if (isNextDay) break;

          if (lines[i].startsWith('সতর্কতা:')) {
            warnText += lines[i].replaceFirst('সতর্কতা:', '').trim() + "\n";
          } else if (lines[i].isNotEmpty) {
            deedText += lines[i] + "\n";
          }
          i++;
        }
        output['weekly_deeds'][wDay.toString()] = {
          "day": key,
          "deeds": deedText.trim(),
          "warning": warnText
        };
        matchedWeekDay = true;
        i--;
        break;
      }
    }
    
    if (matchedWeekDay) {
       i++; continue;
    }

    // Check Monthly Focus
    if (line.startsWith('🌙')) {
      final match = RegExp(r'🌙\s*(\d+)\.\s*(.*)').firstMatch(line);
      if (match != null) {
        currentMonth = int.parse(match.group(1)!);
        output['monthly_focus'][currentMonth.toString()] = match.group(2)!.trim();
      } else {
        currentMonth++;
      }
      i++;
      continue;
    }

    // Check Hijri Day
    // e.g. "১ মুহাররম", "১০ জিলহজ (ঈদুল আযহা)", "**৩০ জিলকদ**"
    final dayMatch = RegExp(r'^\*?\*?\s*([০-৯]+)\s+([^\s\*]+)(.*)').firstMatch(line);
    if (dayMatch != null && !line.startsWith('🗓️')) {
      // Possible day match
      String bnDay = dayMatch.group(1)!;
      String enDay = bnDay.replaceAll('০', '0').replaceAll('১', '1').replaceAll('২', '2').replaceAll('৩', '3').replaceAll('৪', '4').replaceAll('৫', '5').replaceAll('৬', '6').replaceAll('৭', '7').replaceAll('৮', '8').replaceAll('৯', '9');
      int day = int.parse(enDay);
      String monthName = dayMatch.group(2)!;
      String rest = dayMatch.group(3)!;
      
      if (day >= 1 && day <= 30) {
        // Save previous day if exists
        if (currentDay > 0 && currentMonth > 0) {
          output['hijri_deeds'].add({
            "month": currentMonth,
            "day": currentDay,
            "title": title ?? "",
            "regular": regularDeeds.trim(),
            "special": specialDeeds.trim(),
            "warning": warning.trim()
          });
        }
        
        currentDay = day;
        title = rest.trim();
        regularDeeds = "";
        specialDeeds = "";
        warning = "";
        i++;
        continue;
      }
    }
    
    // Check fields for current Hijri day
    if (currentDay > 0) {
      if (line.startsWith('নিয়মিত আমল:')) {
        regularDeeds += line.replaceFirst('নিয়মিত আমল:', '').trim() + "\n";
      } else if (line.startsWith('✨ স্পেশাল আমল:') || line.startsWith('✨ আজকের স্পেশাল আমল:')) {
        specialDeeds += line.replaceFirst(RegExp(r'✨.*?আমল:'), '').trim() + "\n";
      } else if (line.startsWith('⚠️ সতর্কতা') || line.startsWith('✨ সতর্কতা')) {
        warning += line.replaceFirst(RegExp(r'[⚠️✨]\s*সতর্কতা.*?:\s*'), '').trim() + "\n";
      } else if (line.startsWith('✨ আজকের বিশেষত্ব:')) {
        specialDeeds += line.replaceFirst('✨ আজকের বিশেষত্ব:', '').trim() + "\n";
      } else {
        // Append to whichever was the last one, or regular if none
        if (warning.isNotEmpty) {
           warning += line + "\n";
        } else if (specialDeeds.isNotEmpty) {
           specialDeeds += line + "\n";
        } else if (regularDeeds.isNotEmpty) {
           regularDeeds += line + "\n";
        } else if (!line.startsWith('📅') && !line.startsWith('সাপ্তাহিক ফোকাস:')) {
           regularDeeds += line + "\n"; // fallback
        }
      }
    }

    i++;
  }

  // Save the last day
  if (currentDay > 0 && currentMonth > 0) {
    output['hijri_deeds'].add({
      "month": currentMonth,
      "day": currentDay,
      "title": title ?? "",
      "regular": regularDeeds.trim(),
      "special": specialDeeds.trim(),
      "warning": warning.trim()
    });
  }

  final outStr = jsonEncode(output);
  await File('../assets/data/special_deeds.json').writeAsString(outStr);
  print('Saved ${output['hijri_deeds'].length} hijri deeds and ${output['weekly_deeds'].length} weekly deeds to assets/data/special_deeds.json');
}
