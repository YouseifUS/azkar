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
