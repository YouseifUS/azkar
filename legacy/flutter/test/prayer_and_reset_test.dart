import 'package:adhkar_app/models/adhkar.dart';
import 'package:adhkar_app/services/daily_reset_service.dart';
import 'package:adhkar_app/services/prayer_service.dart';
import 'package:adhkar_app/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const cairo = StoredCoordinates(30.0444, 31.2357);
  const prayerService = PrayerService();

  test('calculates Fajr before Asr for Cairo', () {
    final moments = prayerService.forDate(
      date: DateTime(2026, 10, 8),
      latitude: cairo.latitude,
      longitude: cairo.longitude,
    );
    expect(moments.fajr.isBefore(moments.asr), isTrue);
    expect(moments.fajr.hour, inInclusiveRange(3, 6));
    expect(moments.asr.hour, inInclusiveRange(14, 17));
  });

  test('resets both counter groups once after the latest Fajr', () async {
    SharedPreferences.setMockInitialValues({
      'morning_counts': '{"1":1}',
      'evening_counts': '{"1":1}',
    });
    final storage = await StorageService.create();
    final service = DailyResetService(
      storage: storage,
      prayerService: prayerService,
    );

    final firstReset = await service.ensureLatestFajrApplied(
      now: DateTime(2026, 10, 8, 12),
      coordinates: cairo,
    );
    expect(firstReset, isTrue);
    expect(storage.loadCounts(AdhkarPeriod.morning), isEmpty);
    expect(storage.loadCounts(AdhkarPeriod.evening), isEmpty);

    await storage.saveCount(AdhkarPeriod.morning, 1, 1);
    final secondReset = await service.ensureLatestFajrApplied(
      now: DateTime(2026, 10, 8, 13),
      coordinates: cairo,
    );
    expect(secondReset, isFalse);
    expect(storage.loadCounts(AdhkarPeriod.morning)[1], 1);
  });

  test('before Fajr belongs to the previous reset boundary', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    final service = DailyResetService(
      storage: storage,
      prayerService: prayerService,
    );

    await service.ensureLatestFajrApplied(
      now: DateTime(2026, 10, 8, 2),
      coordinates: cairo,
    );
    expect(storage.lastResetBoundary, '2026-10-07');
  });
}
