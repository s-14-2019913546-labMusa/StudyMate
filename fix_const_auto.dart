import 'dart:io';

void main() {
  final file = File('lib/islamic_life_screen.dart');
  var lines = file.readAsLinesSync();

  var linesToFix = [1281, 1768, 1966, 2453, 2576];
  for (var i in linesToFix) {
    if (i - 1 < lines.length) {
      // Find the const keyword on this line or previous lines if not found.
      // Since the error points to LanguageManager, the const might be on an earlier line.
      // Let's search upwards up to 5 lines for a 'const' keyword and remove it.
      bool found = false;
      for (var j = i - 1; j >= 0 && j >= i - 5; j--) {
        if (lines[j].contains('const ')) {
          lines[j] = lines[j].replaceFirst('const ', '');
          found = true;
          break;
        }
      }
      if (!found) {
        print('Could not find const near line \$i');
      }
    }
  }

  file.writeAsStringSync(lines.join('\n'));
  print('Fixed consts');
}
