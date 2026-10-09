import 'package:intl/intl.dart';

import 'prayer_service.dart';
import 'storage_service.dart';

class DailyResetService {
  DailyResetService({required this.storage, required this.prayerService});

  final StorageService storage;
  final PrayerService prayerService;

  Future<bool> ensureLatestFajrApplied({
    required DateTime now,
    required StoredCoordinates coordinates,
  }) async {
    final today = DateTime(now.year, now.month, now.day);
    final todayFajr = prayerService
        .forDate(
          date: today,
          latitude: coordinates.latitude,
          longitude: coordinates.longitude,
        )
        .fajr;
    final boundaryDate = now.isBefore(todayFajr)
        ? today.subtract(const Duration(days: 1))
        : today;
    final boundaryKey = DateFormat('yyyy-MM-dd').format(boundaryDate);

    if (storage.lastResetBoundary == boundaryKey) return false;
    await storage.resetAllCounters();
    await storage.saveLastResetBoundary(boundaryKey);
    return true;
  }

  DateTime nextFajr({
    required DateTime now,
    required StoredCoordinates coordinates,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final todayFajr = prayerService
        .forDate(
          date: today,
          latitude: coordinates.latitude,
          longitude: coordinates.longitude,
        )
        .fajr;
    if (todayFajr.isAfter(now)) return todayFajr;

    final tomorrow = today.add(const Duration(days: 1));
    return prayerService
        .forDate(
          date: tomorrow,
          latitude: coordinates.latitude,
          longitude: coordinates.longitude,
        )
        .fajr;
  }
}
