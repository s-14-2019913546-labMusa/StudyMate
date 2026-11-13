import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/mcq/bijoy_converter.dart';
import 'package:studymate/mcq/pdf_mcq_parser.dart';

void main() {
  group('Bijoy → Unicode', () {
    test('common words', () {
      expect(BijoyConverter.convert('evsjv‡`k'), 'বাংলাদেশ');
      expect(BijoyConverter.convert('†Kvb'), 'কোন');
      expect(BijoyConverter.convert('wK'), 'কি');
      expect(BijoyConverter.convert('cÖkœ'), 'প্রশ্ন');
      expect(BijoyConverter.convert('Kg©Pvix'), 'কর্মচারী');
      expect(BijoyConverter.convert('Kvh©'), 'কার্য');
      expect(BijoyConverter.convert('evsjv‡`‡ki RvZxq dzj †KvbwU?'), 'বাংলাদেশের জাতীয় ফুল কোনটি?');
    });

    test('detection', () {
      expect(BijoyConverter.looksLikeBijoy('evsjv‡`‡ki RvZxq dzj †KvbwU? K) †Mvjvc L) kvcjv'), isTrue);
      expect(BijoyConverter.looksLikeBijoy('What is the capital of Japan? A) Osaka B) Tokyo'), isFalse);
      expect(BijoyConverter.looksLikeBijoy('বাংলাদেশের জাতীয় ফুল কোনটি?'), isFalse);
    });

    test('visual order fix for Unicode PDF text', () {
      const broken = 'েকান েদেশর িক িদন';
      expect(BijoyConverter.hasVisualOrder(broken), isTrue);
      expect(BijoyConverter.reorder('েকান'), 'কোন');
      expect(BijoyConverter.reorder('িক'), 'কি');
    });
  });

  group('PDF parser', () {
    test('numbered questions with inline options and answer key', () {
      const text = '''
১। বাংলাদেশের জাতীয় ফুল কোনটি?
ক) গোলাপ খ) শাপলা গ) জবা ঘ) বেলি
২। জাপানের রাজধানী কোথায়?
(ক) ওসাকা (খ) কিয়োটো (গ) টোকিও (ঘ) নাগোয়া
৩। কোনটি মৌলিক সংখ্যা?
ক. ৪   খ. ৬
গ. ৭   ঘ. ৯

উত্তরমালা: ১.খ ২.গ ৩.গ
''';
      final r = PdfMcqParser.parseDocument(text);
      expect(r.drafts.length, 3);
      expect(r.keyAnswers, 3);
      expect(r.filledFromKey, 3);
      expect(r.drafts[0].question, 'বাংলাদেশের জাতীয় ফুল কোনটি?');
      expect(r.drafts[0].options, ['গোলাপ', 'শাপলা', 'জবা', 'বেলি']);
      expect(r.drafts[0].answer, 1);
      expect(r.drafts[1].options[2], 'টোকিও');
      expect(r.drafts[1].answer, 2);
      expect(r.drafts[2].options, ['৪', '৬', '৭', '৯']);
      expect(r.drafts.every((d) => d.ready), isTrue);
    });

    test('inline answer, explanation, wrapped question and missing answer', () {
      const text = '''
1. Which planet is known
as the red planet?
A) Venus B) Mars C) Jupiter D) Saturn Ans: B
Explanation: Iron oxide makes it red.
2. Capital of Japan?
a) Osaka
b) Kyoto
c) Tokyo
d) Nagoya
3. Largest ocean?
A. Atlantic B. Indian C. Pacific D. Arctic
Answer: Pacific
''';
      final r = PdfMcqParser.parseDocument(text);
      expect(r.drafts.length, 3);
      expect(r.drafts[0].question, 'Which planet is known as the red planet?');
      expect(r.drafts[0].answer, 1);
      expect(r.drafts[0].explanation, 'Iron oxide makes it red.');
      expect(r.drafts[1].answer, -1); // উত্তর নেই → ব্যবহারকারী বেছে দেবে
      expect(r.drafts[1].ready, isFalse);
      expect(r.drafts[2].answer, 2);
    });

    test('answer key in English letter form', () {
      final (key, rest) = PdfMcqParser.extractAnswerKey('Q text\n1-a, 2-c, 3-d, 4-b\nmore');
      expect(key, {1: 0, 2: 2, 3: 3, 4: 1});
      expect(rest, 'Q text\nmore');
    });

    test('question text with a number is not taken as an answer key', () {
      final (key, rest) = PdfMcqParser.extractAnswerKey('৫. ১৯৭১ সালের কত তারিখে স্বাধীনতা ঘোষণা হয়?');
      expect(key, isEmpty);
      expect(rest, isNotEmpty);
    });

    test('Bijoy document end to end', () {
      const text = '1| evsjv‡`‡ki RvZxq dzj †KvbwU?\nK) †Mvjvc L) kvcjv M) Rev N) ‡ewj\nDËi: L';
      final r = PdfMcqParser.parseDocument(text);
      expect(r.drafts.length, 1);
      expect(r.drafts[0].question, 'বাংলাদেশের জাতীয় ফুল কোনটি?');
      expect(r.drafts[0].options[1], 'শাপলা');
      expect(r.drafts[0].answer, 1);
    });

    test('star marks the correct option', () {
      final r = PdfMcqParser.parseDocument('1. 2+2=?\nক) ৩\nখ) ৪*\nগ) ৫\nঘ) ৬');
      expect(r.drafts.single.answer, 1);
      expect(r.drafts.single.options[1], '৪');
    });
  });
}
