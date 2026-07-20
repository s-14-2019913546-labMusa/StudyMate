import 'dart:io';

void main() {
  final file = File('lib/islamic_life_screen.dart');
  var content = file.readAsStringSync();

  // Add import if not present
  if (!content.contains("import 'language_manager.dart';")) {
    content = content.replaceFirst(
        "import 'prayer_history_screen.dart';", 
        "import 'prayer_history_screen.dart';\nimport 'language_manager.dart';");
  }

  // Define regexes to capture the Bengali text (which we don't know exactly due to encoding)
  // and wrap it with LanguageManager().isBengali ? '...bengali...' : '...english...'

  // 1. "Prayer Times" - find the text near '03:52' maybe? No, let's find the section headers.
  // // 4. Prayer Times List
  content = content.replaceFirstMapped(
    RegExp(r"// 4\. Prayer Times List.*?const Padding\(\s*padding: (const )?EdgeInsets\.only\(left: 4\.0, bottom: 12\.0\),\s*child: Text\(\s*'([^']+)',", dotAll: true),
    (match) => "// 4. Prayer Times List\n                  Padding(\n                    padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),\n                    child: Text(\n                      LanguageManager().isBengali ? '${match.group(2)}' : 'Prayer Times',"
  );

  // // 5. Prayer History Section
  content = content.replaceFirstMapped(
    RegExp(r"// 5\. Prayer History Section.*?const Padding\(\s*padding: (const )?EdgeInsets\.only\(left: 4\.0, bottom: 12\.0\),\s*child: Text\(\s*'([^']+)',", dotAll: true),
    (match) => "// 5. Prayer History Section\n                  Padding(\n                    padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),\n                    child: Text(\n                      LanguageManager().isBengali ? '${match.group(2)}' : 'Prayer History',"
  );

  // // 6. Study Duas Section
  content = content.replaceFirstMapped(
    RegExp(r"// 6\. Study Duas.*?const Padding\(\s*padding: (const )?EdgeInsets\.only\(left: 4\.0, bottom: 12\.0\),\s*child: Text\(\s*'([^']+)',", dotAll: true),
    (match) => "// 6. Study Duas & Deeds\n                  Padding(\n                    padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),\n                    child: Text(\n                      LanguageManager().isBengali ? '${match.group(2)}' : 'Study Duas & Deeds',"
  );

  // 2. Wrap Ayat and Hadith Titles
  // Find "আজকের আয়াত" inside a Text widget
  content = content.replaceAllMapped(
    RegExp(r"const Text\(\s*'([^']+)',\s*style:\s*TextStyle\(color:\s*goldAccent,\s*fontSize:\s*12,\s*fontWeight:\s*FontWeight\.bold\),\s*\)"),
    (match) => "Text(LanguageManager().isBengali ? '${match.group(1)}' : 'Verse of the Day', style: const TextStyle(color: goldAccent, fontSize: 12, fontWeight: FontWeight.bold),)"
  );
  
  // Find Hadith title
  content = content.replaceAllMapped(
    RegExp(r"const Text\(\s*'([^']+)',\s*style:\s*TextStyle\(color:\s*Colors\.white54,\s*fontSize:\s*12\),\s*\)"),
    (match) => "Text(LanguageManager().isBengali ? '${match.group(1)}' : 'Hadith of the Day', style: const TextStyle(color: Colors.white54, fontSize: 12),)"
  );

  // 3. For the Hadith text itself, we want it to be English if language is English!
  // The daily Hadith is fetched from _dailyHadith map.
  // It contains 'text' and 'narrator' and 'reference'.
  // If we want English translation, we need to know if _dailyHadith contains English?
  // Let's modify the daily hadith list or the display code to use English text.

  file.writeAsStringSync(content);
  print('Done applying safe loc');
}
