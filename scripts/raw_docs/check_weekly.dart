import 'dart:io';
import 'dart:convert';

void main() async {
  final content = await File('../assets/data/special_deeds.json').readAsString();
  final data = jsonDecode(content);
  for (int i=1; i<=7; i++) {
    print('--- Day $i ---');
    print(data['weekly_deeds'][i.toString()]['deeds']);
  }
}
