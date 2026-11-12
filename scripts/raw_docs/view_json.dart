import 'dart:io';
import 'dart:convert';

void main() async {
  final content = await File('../assets/data/special_deeds.json').readAsString();
  final data = jsonDecode(content);
  print(data['weekly_deeds']['5']);
  print(data['monthly_focus']['2']);
  
  final hijri = data['hijri_deeds'] as List;
  for (var item in hijri) {
    if (item['month'] == 2 && item['day'] == 10) {
      print(item);
    }
  }
}
