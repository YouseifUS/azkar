import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'prayer_service.dart';
import 'storage_service.dart';

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final PrayerService _prayerService = const PrayerService();

  static const _channelId = 'adhkar_prayer_reminders';
  static const _channelName = 'تذكير أذكار الصباح والمساء';
  static const _channelDescription = 'تنبيهات بعد صلاة الفجر والعصر بنصف ساعة';

  Future<void> initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );
  }

  Future<String> configureDeviceTimeZone(StorageService storage) async {
    tz_data.initializeTimeZones();
    final info = await FlutterTimezone.getLocalTimezone('ar');
    configureStoredTimeZone(info.identifier);
    await storage.saveTimezoneId(info.identifier);
    return info.identifier;
  }

  void configureStoredTimeZone(String? identifier) {
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(identifier ?? 'UTC'));
    } on Object {
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<bool> requestPermission() async {
    if (await areNotificationsEnabled()) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<bool> areNotificationsEnabled() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? true;
  }

  Future<void> schedulePrayerReminders({
    required StoredCoordinates coordinates,
    int days = 14,
    DateTime? from,
  }) async {
    final now = from ?? DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exactAllowed = await android?.canScheduleExactNotifications() ?? true;
    final scheduleMode = exactAllowed
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    for (var offset = 0; offset < days; offset++) {
      final date = DateTime(start.year, start.month, start.day + offset);
      final prayers = _prayerService.forDate(
        date: date,
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      );
      await _scheduleIfFuture(
        id: _notificationId(date, false),
        moment: prayers.fajr.add(const Duration(minutes: 30)),
        title: 'أذكار الصباح',
        body: 'مرّت نصف ساعة على صلاة الفجر، حان وقت أذكار الصباح.',
        payload: 'morning',
        now: now,
        scheduleMode: scheduleMode,
      );
      await _scheduleIfFuture(
        id: _notificationId(date, true),
        moment: prayers.asr.add(const Duration(minutes: 30)),
        title: 'أذكار المساء',
        body: 'مرّت نصف ساعة على صلاة العصر، حان وقت أذكار المساء.',
        payload: 'evening',
        now: now,
        scheduleMode: scheduleMode,
      );
    }
  }

  Future<void> _scheduleIfFuture({
    required int id,
    required DateTime moment,
    required String title,
    required String body,
    required String payload,
    required DateTime now,
    required AndroidScheduleMode scheduleMode,
  }) async {
    if (!moment.isAfter(now)) return;
    final scheduled = tz.TZDateTime.from(moment, tz.local);
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
      ),
      androidScheduleMode: scheduleMode,
      payload: payload,
    );
  }

  int _notificationId(DateTime date, bool evening) {
    final dayKey = date.year * 10000 + date.month * 100 + date.day;
    return dayKey * 2 + (evening ? 1 : 0);
  }
}
