import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/daily_routine.dart';
import 'package:studymate/routine_intent.dart';

void main() {
  RoutineIntentType? t(String s) => RoutineIntentParser.parse(s)?.type;

  group('intent type', () {
    test('what now', () {
      expect(t('এখন কী পড়ব?'), RoutineIntentType.whatNow);
      expect(t('ekhon ki porbo'), RoutineIntentType.whatNow);
      expect(t('What should I do now'), RoutineIntentType.whatNow);
    });

    test('plan tomorrow', () {
      expect(t('কালকের প্ল্যান'), RoutineIntentType.planTomorrow);
      expect(t('plan tomorrow'), RoutineIntentType.planTomorrow);
      expect(t('কাল কী পড়ব'), RoutineIntentType.planTomorrow);
    });

    test('move unfinished', () {
      expect(t('বাকিগুলো কালকে সরাও'), RoutineIntentType.moveUnfinished);
    });

    test('delete', () {
      final i = RoutineIntentParser.parse('আজকের রসায়ন বাদ দাও')!;
      expect(i.type, RoutineIntentType.delete);
      expect(i.query, 'রসায়ন');
    });

    test('move to tomorrow', () {
      final i = RoutineIntentParser.parse('আজকের ফিজিক্স কালকে দাও')!;
      expect(i.type, RoutineIntentType.moveToDay);
      expect(i.amount, 1);
      expect(i.query, 'ফিজিক্স');
      expect(RoutineIntentParser.parse('গণিত পরশু সরাও')!.amount, 2);
    });

    test('move to time', () {
      final i = RoutineIntentParser.parse('ইংরেজিটা ৯টায় সরাও')!;
      expect(i.type, RoutineIntentType.moveToTime);
      expect(i.query, 'ইংরেজি');
    });

    test('postpone', () {
      final i = RoutineIntentParser.parse('গণিত ২০ মিনিট পিছাও')!;
      expect(i.type, RoutineIntentType.postpone);
      expect(i.amount, 20);
      expect(i.query, 'গণিত');
      expect(RoutineIntentParser.parse('পিছাও')!.amount, 15);
    });

    test('add', () {
      final i = RoutineIntentParser.parse('কাল সকাল ৭টায় গণিত ২ ঘণ্টা')!;
      expect(i.type, RoutineIntentType.add);
      expect(i.query, contains('গণিত'));
      expect(t('Physics 7pm-9pm'), RoutineIntentType.add);
      expect(t('যোগ করো: বাংলা ব্যাকরণ'), RoutineIntentType.add);
    });

    test('not routine', () {
      expect(t('কাজী নজরুল'), isNull);
      expect(t('মুক্তিযুদ্ধ ১৯৭১'), isNull);
      expect(t('সকালে পড়া মনে থাকে না'), isNull);
      expect(t('/calc 50*4'), isNull);
    });
  });

  group('task helpers', () {
    final d = DateTime(2026, 11, 13);
    Task task(String id, String title, int h, int mins, {String status = 'pending'}) => Task(
          id: id,
          title: title,
          subject: title,
          startTime: d.add(Duration(hours: h)),
          endTime: d.add(Duration(hours: h, minutes: mins)),
          totalDurationMinutes: mins,
          status: status,
          isCompleted: status == 'completed',
        );

    final tasks = [
      task('1', 'English Grammar', 8, 60, status: 'completed'),
      task('2', 'গণিত', 10, 120),
      task('3', '[WR] Physics', 14, 60),
    ];

    test('find by Bengali/English synonym and suffix', () {
      expect(RoutineIntentParser.findTasks(tasks, 'ফিজিক্স').map((e) => e.id), ['3']);
      expect(RoutineIntentParser.findTasks(tasks, 'গণিতটা').map((e) => e.id), ['2']);
      expect(RoutineIntentParser.findTasks(tasks, 'ইংরেজি').map((e) => e.id), ['1']);
    });

    test('current, next, missed', () {
      final (cur, next) = RoutineIntentParser.currentAndNext(tasks, d.add(const Duration(hours: 11)));
      expect(cur?.id, '2');
      expect(next?.id, '3');
      expect(RoutineIntentParser.missed(tasks, d.add(const Duration(hours: 13))).map((e) => e.id), ['2']);
    });

    test('overlaps', () {
      final o = RoutineIntentParser.overlaps(tasks, d.add(const Duration(hours: 11)), d.add(const Duration(hours: 12)));
      expect(o.map((e) => e.id), ['2']);
    });
  });
}
