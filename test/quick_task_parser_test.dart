import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/quick_add_task.dart';

void main() {
  // সকাল ৭টা ধরে পরীক্ষা
  final morning = DateTime(2026, 11, 12, 7, 0);

  String hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  test('Bengali range with টা', () {
    final p = QuickTaskParser.parse('বাংলা ব্যাকরণ ৮টা–১০টা', now: morning);
    expect(p.subject, 'বাংলা ব্যাকরণ');
    expect(hm(p.start), '08:00');
    expect(hm(p.end), '10:00');
    expect(p.timeFound, true);
  });

  test('Bengali with period word', () {
    final p = QuickTaskParser.parse('গণিত বিকাল ৪টা থেকে ৬টা', now: morning);
    expect(p.subject, 'গণিত');
    expect(hm(p.start), '16:00');
    expect(hm(p.end), '18:00');
  });

  test('English am/pm range', () {
    final p = QuickTaskParser.parse('English 7:30pm-9pm', now: morning);
    expect(p.subject, 'English');
    expect(hm(p.start), '19:30');
    expect(hm(p.end), '21:00');
  });

  test('Range crossing noon', () {
    final p = QuickTaskParser.parse('Physics 11-1', now: morning);
    expect(hm(p.start), '11:00');
    expect(hm(p.end), '13:00');
  });

  test('Past morning time becomes evening', () {
    final p = QuickTaskParser.parse('রসায়ন ৮টা-৯টা', now: DateTime(2026, 11, 12, 15, 0));
    expect(hm(p.start), '20:00');
    expect(hm(p.end), '21:00');
  });

  test('Single time plus duration', () {
    final p = QuickTaskParser.parse('ইতিহাস রাত ৯টা ২ ঘণ্টা', now: morning);
    expect(p.subject, 'ইতিহাস');
    expect(hm(p.start), '21:00');
    expect(hm(p.end), '23:00');
  });

  test('Duration only', () {
    final p = QuickTaskParser.parse('Vocabulary 45 min', now: morning);
    expect(p.subject, 'Vocabulary');
    expect(p.minutes, 45);
    expect(p.timeFound, false);
  });

  test('Spoken Bengali with tomorrow and number words', () {
    final p = QuickTaskParser.parse('কাল সকাল আটটায় গণিত দুই ঘণ্টা', now: DateTime(2026, 11, 12, 15, 0));
    expect(p.dayOffset, 1);
    expect(p.subject, 'গণিত');
    expect(p.start, DateTime(2026, 11, 13, 8, 0));
    expect(p.end, DateTime(2026, 11, 13, 10, 0));
  });

  test('সাড়ে and আধা ঘণ্টা', () {
    final p = QuickTaskParser.parse('আগামীকাল রাত সাড়ে নয়টায় ইংরেজি আধা ঘণ্টা', now: morning);
    expect(p.dayOffset, 1);
    expect(p.subject, 'ইংরেজি');
    expect(p.start, DateTime(2026, 11, 13, 21, 30));
    expect(p.minutes, 30);
  });

  test('English speech: tomorrow seven pm physics one hour', () {
    final p = QuickTaskParser.parse('tomorrow seven pm physics one hour', now: morning);
    expect(p.dayOffset, 1);
    expect(p.subject.toLowerCase(), 'physics');
    expect(p.start, DateTime(2026, 11, 13, 19, 0));
    expect(p.minutes, 60);
  });

  test('Subject words ending in টা are kept', () {
    final p = QuickTaskParser.parse('কোটা আন্দোলন ৮টা-৯টা', now: morning);
    expect(p.subject, 'কোটা আন্দোলন');
  });

  test('No time at all', () {
    final p = QuickTaskParser.parse('সাধারণ জ্ঞান', now: morning);
    expect(p.subject, 'সাধারণ জ্ঞান');
    expect(p.minutes, 60);
    expect(p.timeFound, false);
  });
}
