import 'dart:io';

void main() {
  var lines = File('lib/islamic_life_screen.dart').readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    if (RegExp(r'[\u0980-\u09FF]').hasMatch(lines[i])) {
      print('${i+1}: ${lines[i].trim()}');
    }
  }
}
