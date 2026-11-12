import 'dart:convert';
import 'dart:io';

void main() async {
  final url = Uri.parse('https://translate.googleapis.com/translate_a/single?client=gtx&sl=bn&tl=en&dt=t&q=${Uri.encodeComponent("আমার নাম রহিম")}');
  final request = await HttpClient().getUrl(url);
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  print(responseBody);
}
