import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert';

void main() async {
  final urls = [
    'http://rss.cnn.com/rss/edition.rss',
    'https://rss.nytimes.com/services/xml/rss/nyt/World.xml',
  ];

  for (var url in urls) {
    print('Fetching $url...');
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        }
      ).timeout(const Duration(seconds: 5));
      print('Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final bodyStr = utf8.decode(response.bodyBytes, allowMalformed: true);
        final document = XmlDocument.parse(bodyStr);
        final items = document.findAllElements('item');
        print('Found ${items.length} items');
        if (items.isNotEmpty) {
          final first = items.first;
          print('Title: ${first.findElements('title').firstOrNull?.innerText}');
          print('Date: ${first.findElements('pubDate').firstOrNull?.innerText}');
        }
      } else {
        print('Failed to fetch.');
      }
    } catch (e) {
      print('Exception: $e');
    }
    print('---');
  }
}
