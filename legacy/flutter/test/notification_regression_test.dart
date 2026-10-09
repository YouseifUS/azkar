import 'package:adhkar_app/app_controller.dart';
import 'package:adhkar_app/services/notification_service.dart';
import 'package:adhkar_app/services/prayer_service.dart';
import 'package:adhkar_app/services/storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const locationChannel = MethodChannel('flutter.baseflow.com/geolocator');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  var notificationsAllowed = true;
  var exactAllowed = true;
  var initializationFails = false;
  var locationPermission = 2;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({
      'location_latitude': 30.0444,
      'location_longitude': 31.2357,
      'timezone_id': 'Africa/Cairo',
    });
    calls = [];
    notificationsAllowed = true;
    exactAllowed = true;
    initializationFails = false;
    locationPermission = 2;
    messenger.setMockMethodCallHandler(notificationsChannel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
          if (initializationFails) {
            throw PlatformException(code: 'invalid_icon');
          }
          return true;
        case 'areNotificationsEnabled':
          return notificationsAllowed;
        case 'canScheduleExactNotifications':
          return exactAllowed;
        case 'requestNotificationsPermission':
          notificationsAllowed = true;
          return true;
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(locationChannel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'checkPermission':
          return locationPermission;
        case 'isLocationServiceEnabled':
          return false;
        case 'requestPermission':
          return locationPermission;
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (_) async => 'Africa/Cairo',
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(notificationsChannel, null);
    messenger.setMockMethodCallHandler(locationChannel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      null,
    );
  });

  test(
    'granted permissions remain granted if notification initialization fails',
    () async {
      initializationFails = true;
      final controller = await AppController.create();
      addTearDown(controller.dispose);
      expect(await controller.needsPermissionSetup(), isFalse);
      expect(calls.where((call) => call.method == 'initialize'), isEmpty);
    },
  );

  test(
    'activation does not request notification permission when already granted',
    () async {
      final controller = await AppController.create();
      addTearDown(controller.dispose);
      await controller.activateDeviceServices();
      expect(
        calls.where((call) => call.method == 'requestNotificationsPermission'),
        isEmpty,
      );
      expect(calls.where((call) => call.method == 'zonedSchedule'), isNotEmpty);
    },
  );

  test('permission setup detects each missing permission', () async {
    final controller = await AppController.create();
    addTearDown(controller.dispose);
    notificationsAllowed = false;
    expect(await controller.needsPermissionSetup(), isTrue);
    notificationsAllowed = true;
    locationPermission = 0;
    expect(await controller.needsPermissionSetup(), isTrue);
  });

  test(
    'resume never requests denied permissions and settings changes reschedule',
    () async {
      notificationsAllowed = false;
      locationPermission = 0;
      final controller = await AppController.create();
      addTearDown(controller.dispose);
      await controller.activateDeviceServices(requestPermissions: false);
      expect(
        calls.where((call) => call.method == 'requestPermission'),
        isEmpty,
      );
      expect(
        calls.where((call) => call.method == 'requestNotificationsPermission'),
        isEmpty,
      );
      expect(calls.where((call) => call.method == 'zonedSchedule'), isEmpty);

      notificationsAllowed = true;
      locationPermission = 2;
      await controller.activateDeviceServices(requestPermissions: false);
      expect(calls.where((call) => call.method == 'zonedSchedule'), isNotEmpty);
      expect(
        calls.where((call) => call.method == 'requestNotificationsPermission'),
        isEmpty,
      );
    },
  );

  test(
    'elapsed reminders are skipped while following days remain scheduled',
    () async {
      final service = NotificationService();
      service.configureStoredTimeZone('Africa/Cairo');
      await service.initialize();
      final prayers = const PrayerService().forDate(
        date: DateTime(2030, 10, 30),
        latitude: 30.0444,
        longitude: 31.2357,
      );
      await service.schedulePrayerReminders(
        coordinates: const StoredCoordinates(30.0444, 31.2357),
        from: prayers.asr.add(const Duration(minutes: 31)),
        days: 2,
      );
      final schedules = calls
          .where((call) => call.method == 'zonedSchedule')
          .toList();
      expect(schedules, hasLength(2));
      expect(schedules.map((call) => (call.arguments as Map)['id']), [
        40602062,
        40602063,
      ]);
    },
  );

  test('notification request grants missing permission', () async {
    notificationsAllowed = false;
    expect(await NotificationService().requestPermission(), isTrue);
    expect(
      calls.where((call) => call.method == 'requestNotificationsPermission'),
      hasLength(1),
    );
  });

  for (final exact in [true, false]) {
    test(
      'schedules both reminders 30 minutes after prayer with exact=$exact',
      () async {
        exactAllowed = exact;
        final service = NotificationService();
        service.configureStoredTimeZone('Africa/Cairo');
        await service.initialize();
        // Cross Cairo's daylight-saving boundary in a future year.
        final start = tz.TZDateTime(tz.local, 2030, 10, 30);
        await service.schedulePrayerReminders(
          coordinates: const StoredCoordinates(30.0444, 31.2357),
          from: start,
          days: 4,
        );
        final schedules = calls
            .where((call) => call.method == 'zonedSchedule')
            .toList();
        expect(schedules, hasLength(8));
        expect(
          schedules.map((call) => (call.arguments as Map)['id']).toSet(),
          hasLength(8),
        );
        for (var day = 0; day < 4; day++) {
          final prayers = const PrayerService().forDate(
            date: DateTime(2030, 10, 30 + day),
            latitude: 30.0444,
            longitude: 31.2357,
          );
          for (var period = 0; period < 2; period++) {
            final args = schedules[day * 2 + period].arguments as Map;
            final encoded = DateTime.parse(args['scheduledDateTime'] as String);
            final scheduled = tz.TZDateTime(
              tz.local,
              encoded.year,
              encoded.month,
              encoded.day,
              encoded.hour,
              encoded.minute,
              encoded.second,
            );
            final prayer = period == 0 ? prayers.fajr : prayers.asr;
            expect(scheduled.difference(prayer), const Duration(minutes: 30));
            expect(args['payload'], period == 0 ? 'morning' : 'evening');
            expect(args['timeZoneName'], 'Africa/Cairo');
            expect(
              (args['platformSpecifics'] as Map)['scheduleMode'],
              exact ? 'exactAllowWhileIdle' : 'inexactAllowWhileIdle',
            );
          }
        }
      },
    );
  }
}
