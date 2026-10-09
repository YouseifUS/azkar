import 'dart:convert';

enum AdhkarPeriod { morning, evening }

extension AdhkarPeriodX on AdhkarPeriod {
  String get storageKey => this == AdhkarPeriod.morning ? 'morning' : 'evening';

  String get arabicLabel =>
      this == AdhkarPeriod.morning ? 'أذكار الصباح' : 'أذكار المساء';
}

class AdhkarItem {
  const AdhkarItem({
    required this.order,
    required this.text,
    required this.repetition,
  });

  final int order;
  final String text;
  final int repetition;

  factory AdhkarItem.fromJson(Map<String, dynamic> json) {
    return AdhkarItem(
      order: json['order'] as int,
      text: (json['text'] as String).trim(),
      repetition: json['repetition'] as int,
    );
  }
}

class AdhkarDocument {
  AdhkarDocument({required this.morning, required this.evening}) {
    _validate('morning', morning);
    _validate('evening', evening);
  }

  final List<AdhkarItem> morning;
  final List<AdhkarItem> evening;

  List<AdhkarItem> itemsFor(AdhkarPeriod period) =>
      period == AdhkarPeriod.morning ? morning : evening;

  factory AdhkarDocument.fromJsonString(String source) {
    final root = jsonDecode(source) as Map<String, dynamic>;
    return AdhkarDocument(
      morning: _parseList(root['morning']),
      evening: _parseList(root['evening']),
    );
  }

  static List<AdhkarItem> _parseList(Object? value) {
    if (value is! List) {
      throw const FormatException('قائمة الأذكار غير موجودة');
    }
    return List<AdhkarItem>.unmodifiable(
      value.map((item) => AdhkarItem.fromJson(item as Map<String, dynamic>)),
    );
  }

  static void _validate(String label, List<AdhkarItem> items) {
    if (items.isEmpty) {
      throw FormatException('$label must not be empty');
    }
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      if (item.order != index + 1) {
        throw FormatException('$label order is invalid at ${index + 1}');
      }
      if (item.text.isEmpty || item.repetition < 1) {
        throw FormatException('$label item ${item.order} is invalid');
      }
    }
  }
}
