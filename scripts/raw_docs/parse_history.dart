import 'dart:io';
import 'dart:convert';

void main() async {
  final file = File('e:/development/StudyMate App/studymate/raw_docs/extracted_history_clean.txt');
  final lines = await file.readAsLines();

  final List<Map<String, dynamic>> events = [];
  Map<String, dynamic>? currentEvent;
  String currentDescription = "";

  final monthNames = {
    'মুহাররম': 1, 'মহররম': 1,
    'সফর': 2,
    'রবিউল আউয়াল': 3, 'রবিউল আউয়াল': 3,
    'রবিউস সানি': 4, 'রবিউস সানী': 4,
    'জুমাদাল উলা': 5,
    'জুমাদাস সানি': 6, 'জুমাদাস সানী': 6,
    'রজব': 7,
    'শাবান': 8,
    'রমজান': 9, 'রমযান': 9,
    'শাওয়াল': 10, 'শাওয়াল': 10,
    'জিলকদ': 11,
    'জিলহজ্জ': 12, 'জিলহজ': 12,
  };

  int parseMonth(String text) {
    for (final entry in monthNames.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }
    return -1;
  }

  int parseDay(String text) {
    // Looks for numbers (bangla or english) before a month name
    final RegExp regExp = RegExp(r'([০-৯0-9]+)\s*(?:মুহাররম|মহররম|সফর|রবিউল|রবিউস|জুমাদাল|জুমাদাস|রজব|শাবান|রমজান|রমযান|শাওয়াল|শাওয়াল|জিলকদ|জিলহজ্জ|জিলহজ)');
    final match = regExp.firstMatch(text);
    if (match != null) {
      String numStr = match.group(1)!;
      // Convert Bangla digits to English
      const banglaDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
      for (int i = 0; i < 10; i++) {
        numStr = numStr.replaceAll(banglaDigits[i], i.toString());
      }
      return int.tryParse(numStr) ?? 1;
    }
    return 1;
  }

  for (int i = 0; i < lines.length; i++) {
    String line = lines[i].trim();
    if (line.isEmpty) continue;

    if (line.contains("পর্ব") && line.contains("নোট:")) continue;

    // A new event begins with "ঘটনা-" or "ঘটনা -"
    if (line.startsWith('ঘটনা-') || line.startsWith('ঘটনা -') || line.startsWith('ঘটনা ')) {
      // Save previous event
      if (currentEvent != null) {
        currentEvent['description_bn'] = currentDescription.trim();
        events.add(currentEvent);
      }
      
      currentEvent = {
        'hijri_month': 1,
        'hijri_day': 1,
        'date_text_bn': '',
        'title_bn': '',
      };
      currentDescription = "";
      
      // The next line is usually the date
      if (i + 1 < lines.length) {
        String dateLine = lines[i + 1].trim();
        if (parseMonth(dateLine) != -1) {
          currentEvent['hijri_month'] = parseMonth(dateLine);
          currentEvent['hijri_day'] = parseDay(dateLine);
          currentEvent['date_text_bn'] = dateLine.replaceAll(RegExp(r'^(📅|তারিখ:\s*)'), '').trim();
          i++; // Skip date line
        }
      }
    } else if (currentEvent != null) {
      if (line.startsWith('🕌')) {
        currentEvent['title_bn'] = line.replaceAll('🕌', '').trim();
      } else if (line.startsWith('🌟')) {
        currentDescription += '\n\n' + line;
      } else if (line.startsWith('📚')) {
        currentDescription += '\n\n' + line;
      } else {
        if (currentEvent['title_bn'] == '' && parseMonth(line) != -1 && currentEvent['date_text_bn'] == '') {
           currentEvent['hijri_month'] = parseMonth(line);
           currentEvent['hijri_day'] = parseDay(line);
           currentEvent['date_text_bn'] = line.replaceAll(RegExp(r'^(📅|তারিখ:\s*)'), '').trim();
        } else if (currentEvent['title_bn'] == '' && !line.startsWith('🌟') && !line.startsWith('📚')) {
           // Maybe this is the title and it didn't start with 🕌
           currentEvent['title_bn'] = line.trim();
        } else {
           if (currentDescription.isNotEmpty) {
             currentDescription += '\n';
           }
           currentDescription += line;
        }
      }
    }
  }

  if (currentEvent != null) {
    currentEvent['description_bn'] = currentDescription.trim();
    events.add(currentEvent);
  }

  // Populate English fields for compatibility
  for (var event in events) {
    event['title_en'] = event['title_bn'];
    event['description_en'] = event['description_bn'];
  }

  print('Total events parsed: ${events.length}');

  final jsonFile = File('e:/development/StudyMate App/studymate/assets/data/islamic_history.json');
  await jsonFile.writeAsString(jsonEncode(events));
  print('Wrote to ${jsonFile.path}');
}
