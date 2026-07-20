import 'dart:io';

void main() {
  var file = File('lib/islamic_life_screen.dart');
  var content = file.readAsStringSync();

  // Fix literal $isBn and literal ${match.group(1)} that was written
  content = content.replaceAll(r'$isBn', 'LanguageManager().isBengali');
  content = content.replaceAll(r'${match.group(1)}', 'LanguageManager().isBengali');

  // Fix literal match.group
  content = content.replaceAllMapped(RegExp(r"Text\(\$\{match\.group\(1\)\}\)"), (match) => "Text(LanguageManager().isBengali)");
  
  // Actually, wait, let's just revert the file and do it right!
}
