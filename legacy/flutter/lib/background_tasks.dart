import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'services/daily_reset_service.dart';
import 'services/notification_service.dart';
import 'services/prayer_service.dart';
import 'services/storage_service.dart';

const refreshScheduleTask = 'refreshPrayerSchedule';
const refreshScheduleUniqueName = 'adhkarDailyPrayerRefresh';

@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final storage = await StorageService.create();
    final coordinates = storage.loadCoordinates();
    if (coordinates == null) return true;

    final notifications = NotificationService();
    await notifications.initialize();
    notifications.configureStoredTimeZone(storage.timezoneId);
    await notifications.schedulePrayerReminders(coordinates: coordinates);

    final resetService = DailyResetService(
      storage: storage,
      prayerService: const PrayerService(),
    );
    await resetService.ensureLatestFajrApplied(
      now: DateTime.now(),
      coordinates: coordinates,
    );
    return true;
  });
}
