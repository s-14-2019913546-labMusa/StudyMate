import 'dart:io';

void main() async {
  final content = await File('extracted_deeds.txt').readAsString();
  final lines = content.split('\n');
  for (int i = 0; i < 70; i++) {
    if (i < lines.length) print('$i: ${lines[i]}');
  }
}
