import 'dart:convert';
import 'dart:io';

Future<String> translateText(String text) async {
  if (text.trim().isEmpty) return text;
  
  // Split long texts into chunks if necessary (Google translate free API has limits, usually 5000 chars)
  // But our descriptions are short enough.
  
  try {
    final url = Uri.parse('https://translate.googleapis.com/translate_a/single?client=gtx&sl=bn&tl=en&dt=t&q=${Uri.encodeComponent(text)}');
    final request = await HttpClient().getUrl(url);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    final jsonResponse = jsonDecode(responseBody);
    
    // The translated text is split into sentences in the response
    StringBuffer sb = StringBuffer();
    for (var chunk in jsonResponse[0]) {
      sb.write(chunk[0]);
    }
    return sb.toString();
  } catch (e) {
    print('Translation error for "$text": $e');
    return text; // Return original if fails
  }
}

void main() async {
  print('Starting translation...');
  final file = File('e:/development/StudyMate App/studymate/assets/data/islamic_history.json');
  final jsonStr = await file.readAsString();
  final List<dynamic> events = jsonDecode(jsonStr);

  int total = events.length;
  int count = 0;

  for (var event in events) {
    // Only translate if they are equal (meaning they haven't been translated yet)
    if (event['title_en'] == event['title_bn']) {
       String titleBn = event['title_bn'] ?? '';
       String descBn = event['description_bn'] ?? '';
       
       if (titleBn.isNotEmpty) {
         event['title_en'] = await translateText(titleBn);
         await Future.delayed(Duration(milliseconds: 300));
       }
       if (descBn.isNotEmpty) {
         event['description_en'] = await translateText(descBn);
         await Future.delayed(Duration(milliseconds: 300));
       }
       
       count++;
       if (count % 10 == 0) {
         print('Translated $count/$total events...');
         // Save partial progress
         await file.writeAsString(jsonEncode(events));
       }
    }
  }

  // Final save
  await file.writeAsString(jsonEncode(events));
  print('Translation completed!');
}
