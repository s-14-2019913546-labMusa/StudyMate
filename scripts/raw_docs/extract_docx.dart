import 'dart:io';

void main() async {
  final file = File('temp_deeds/word/document.xml');
  final xmlStr = await file.readAsString();

  // Match paragraphs
  final pRegex = RegExp(r'<w:p[ >].*?</w:p>');
  final tRegex = RegExp(r'<w:t(?:.*?)>(.*?)</w:t>');
  
  final pMatches = pRegex.allMatches(xmlStr);
  final buffer = StringBuffer();
  
  for (final pMatch in pMatches) {
    final pStr = pMatch.group(0)!;
    final tMatches = tRegex.allMatches(pStr);
    
    if (tMatches.isNotEmpty) {
      for (final tMatch in tMatches) {
        buffer.write(tMatch.group(1));
      }
      buffer.writeln();
    }
  }
  
  await File('extracted_deeds.txt').writeAsString(buffer.toString());
  print('Done extracting ${pMatches.length} paragraphs');
}
