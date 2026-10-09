import 'dart:convert';
import 'dart:io';

import 'package:adhkar_app/models/adhkar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  late AdhkarDocument document;

  setUpAll(() {
    source = File('assets/data/adhkar_morning_evening.json').readAsStringSync();
    document = AdhkarDocument.fromJsonString(source);
  });

  test('contains 23 ordered morning and evening items', () {
    expect(document.morning, hasLength(23));
    expect(document.evening, hasLength(23));
    expect(
      document.morning.map((item) => item.order),
      orderedEquals(range(1, 24)),
    );
    expect(
      document.evening.map((item) => item.order),
      orderedEquals(range(1, 24)),
    );
  });

  test('every item has text and a positive repetition', () {
    for (final item in [...document.morning, ...document.evening]) {
      expect(item.text.trim(), isNotEmpty);
      expect(item.repetition, greaterThan(0));
    }
  });

  test('both lists end with the requested istighfar', () {
    for (final item in [document.morning.last, document.evening.last]) {
      expect(item.text, 'أستغفر الله العظيم وأتوب إليه.');
      expect(item.repetition, 100);
    }
  });

  test('Quran text is expanded rather than stored as a title only', () {
    expect(
      document.morning[1].text,
      startsWith('اللَّهُ لَا إِلَهَ إِلَّا هُوَ'),
    );
    expect(document.morning[1].text, endsWith('وَهُوَ الْعَلِيُّ الْعَظِيمُ.'));
    expect(document.morning[2].text, contains('اللَّهُ الصَّمَدُ'));
    expect(document.morning[3].text, contains('وَمِنْ شَرِّ النَّفَّاثَاتِ'));
    expect(document.morning[4].text, contains('الْوَسْوَاسِ الْخَنَّاسِ'));
  });

  test('Quran wording is preserved with ordinary punctuation', () {
    // Quran.com: 2:255, 112:1-4, 113:1-5, and 114:1-6.
    const passages = [
      'الله لا إله إلا هو الحي القيوم لا تأخذه سنة ولا نوم له ما في السماوات وما في الأرض من ذا الذي يشفع عنده إلا بإذنه يعلم ما بين أيديهم وما خلفهم ولا يحيطون بشيء من علمه إلا بما شاء وسع كرسيه السماوات والأرض ولا يئوده حفظهما وهو العلي العظيم',
      'قل هو الله أحد الله الصمد لم يلد ولم يولد ولم يكن له كفوا أحد',
      'قل أعوذ برب الفلق من شر ما خلق ومن شر غاسق إذا وقب ومن شر النفاثات في العقد ومن شر حاسد إذا حسد',
      'قل أعوذ برب الناس ملك الناس إله الناس من شر الوسواس الخناس الذي يوسوس في صدور الناس من الجنة والناس',
    ];
    const commaCounts = [8, 3, 4, 5];
    final marks = RegExp(r'[\u064B-\u0652،.]');
    for (final items in [document.morning, document.evening]) {
      for (var index = 0; index < passages.length; index++) {
        final text = items[index + 1].text;
        final words = text
            .replaceAll(marks, '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        expect(words, passages[index]);
        expect('،'.allMatches(text).length, commaCounts[index]);
        expect(text, endsWith('.'));
        expect(RegExp(r'[\u06D6-\u06ED]').hasMatch(text), isFalse);
        expect(text, isNot(contains(' ،')));
        expect(text, isNot(contains('  ')));
      }
      final ayat = items[1].text;
      expect(ayat, contains('الْقَيُّومُ، لَا'));
      expect(ayat, contains('الْأَرْضِ، مَنْ'));
      expect(ayat, contains('خَلْفَهُمْ، وَلَا'));
      expect(ayat, contains('وَالْأَرْضَ، وَلَا'));
    }
  });

  test('reviewed formulas and pronunciation are preserved in both periods', () {
    for (final items in [document.morning, document.evening]) {
      expect(items[7].text, contains('أُشهدك، وأُشهد حملة'));
      expect(items[10].text, contains('ربِّ أسألك'));
      expect(items[10].text, contains('سوء الكِبَر'));
      expect(items[11].text, contains('بنعمتك عليَّ'));
      expect(items[12].text, contains('والآخرة. اللهم إني أسألك'));
      expect(items[12].text, contains('يديَّ'));
      expect(items[12].text, contains('أُغتال'));
      // Abu Dawud 5090: three times morning and evening.
      expect(items[13].repetition, 3);
      expect(items[14].text, contains('أَجُرَّه'));
      expect(items[15].text, endsWith('نبيًا.'));
      expect(items[19].text, contains('صلِّ وسلِّم'));
      // Hisn al-Muslim 92: the tenfold tahlil starts without "أشهد أن".
      expect(items[21].text, startsWith('لا إله إلا الله وحده'));
      expect(items[21].repetition, 10);
    }
  });

  test('removed metadata fields are not present in any item', () {
    final json = jsonDecode(source) as Map<String, dynamic>;
    for (final period in ['morning', 'evening']) {
      for (final item in json[period] as List<dynamic>) {
        final map = item as Map<String, dynamic>;
        expect(map.containsKey('category'), isFalse);
        expect(map.containsKey('name'), isFalse);
        expect(map.containsKey('quran_reference'), isFalse);
      }
    }
  });
}

Iterable<int> range(int start, int end) sync* {
  for (var value = start; value < end; value++) {
    yield value;
  }
}
