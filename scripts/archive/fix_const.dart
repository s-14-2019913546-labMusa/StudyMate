import 'dart:io';

void main() {
  final file = File('lib/islamic_life_screen.dart');
  var lines = file.readAsLinesSync();

  var linesToFix = [1054, 1414, 1573, 1929, 2031];
  for (var i in linesToFix) {
    if (i - 1 < lines.length) {
      lines[i - 1] = lines[i - 1].replaceFirst('const ', '');
    }
  }

  file.writeAsStringSync(lines.join('\n'));
  print('Fixed consts');
}
