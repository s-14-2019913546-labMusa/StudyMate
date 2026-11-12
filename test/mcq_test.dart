import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/mcq/mcq_service.dart';

void main() {
  test('Bundled question bank is well formed', () {
    final data = jsonDecode(File('assets/data/mcq_bank.json').readAsStringSync()) as Map<String, dynamic>;
    final subjects = (data['subjects'] as Map<String, dynamic>).keys.toSet();
    final qs = data['questions'] as List;
    expect(qs.length, greaterThanOrEqualTo(70));
    final seen = <String>{};
    for (final q in qs) {
      final m = q as Map<String, dynamic>;
      expect(subjects.contains(m['s']), isTrue, reason: 'unknown subject ${m['s']}');
      expect((m['o'] as List).length, 4, reason: m['q']);
      final a = m['a'] as int;
      expect(a >= 0 && a < 4, isTrue, reason: m['q']);
      expect((m['o'] as List).toSet().length, 4, reason: 'duplicate options: ${m['q']}');
      expect(seen.add(m['q'] as String), isTrue, reason: 'duplicate question ${m['q']}');
    }
  });

  test('Parses pasted Bengali questions with উত্তর line', () {
    const text = '''
বাংলাদেশের জাতীয় ফুল কোনটি?
ক) গোলাপ
খ) শাপলা
গ) জবা
ঘ) বেলি
উত্তর: খ
ব্যাখ্যা: শাপলা জাতীয় ফুল।

2. Capital of Japan?
A) Osaka
B) Kyoto
C) Tokyo
D) Nagoya
Ans: C
''';
    final qs = McqService.parsePasted(text, 'সাধারণ জ্ঞান');
    expect(qs.length, 2);
    expect(qs[0].question, 'বাংলাদেশের জাতীয় ফুল কোনটি?');
    expect(qs[0].answer, 1);
    expect(qs[0].explanation, 'শাপলা জাতীয় ফুল।');
    expect(qs[1].question, 'Capital of Japan?');
    expect(qs[1].correctText, 'Tokyo');
  });

  test('Star marks the correct option', () {
    const text = 'Which is a prime number?\na) 4\nb) 6\nc) 7*\nd) 9';
    final qs = McqService.parsePasted(text, 'গণিত');
    expect(qs.single.answer, 2);
    expect(qs.single.correctText, '7');
  });

  test('Incomplete blocks are skipped', () {
    const text = 'Question without options\nAns: A';
    expect(McqService.parsePasted(text, 'x'), isEmpty);
  });
}
