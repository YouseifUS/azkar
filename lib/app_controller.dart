import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';

import 'background_tasks.dart';
import 'models/adhkar.dart';
import 'services/daily_reset_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/prayer_service.dart';
import 'services/storage_service.dart';

class AppController extends ChangeNotifier {
  AppController._({
    required this.document,
    required this._storage,
    required this._prayerService,
    required this._notificationService,
    required this._locationService,
  }) {
    _reloadCounts();
  }

  final AdhkarDocument document;
  final StorageService _storage;
  final PrayerService _prayerService;
  final NotificationService _notificationService;
  final LocationService _locationService;
  DailyResetService get _resetService =>
      DailyResetService(storage: _storage, prayerService: _prayerService);

  Map<int, int> _morningCounts = <int, int>{};
  Map<int, int> _eveningCounts = <int, int>{};
  StoredCoordinates? _coordinates;
  PrayerMoments? _todayPrayers;
  Timer? _fajrTimer;
  bool _activating = false;
  bool _servicesActivated = false;
  String _serviceMessage = 'جاري ضبط مواقيت الصلاة والتنبيهات…';

  PrayerMoments? get todayPrayers => _todayPrayers;
  String get serviceMessage => _serviceMessage;
  bool get servicesActivated => _servicesActivated;
  bool get lightThemeEnabled => _storage.lightThemeEnabled;

  Future<void> toggleTheme() async {
    await _storage.saveLightTheme(!lightThemeEnabled);
    notifyListeners();
  }

  Future<bool> needsPermissionSetup() async {
    var notificationsAllowed = false;
    try {
      notificationsAllowed = await _notificationService
          .areNotificationsEnabled();
    } on Object {
      notificationsAllowed = false;
    }

    var locationAllowed = false;
    try {
      locationAllowed = await _locationService.hasPermission();
    } on Object {
      locationAllowed = false;
    }
    return !notificationsAllowed || !locationAllowed;
  }

  static Future<AppController> create() async {
    final source = await rootBundle.loadString(
      'assets/data/adhkar_morning_evening.json',
    );
    final storage = await StorageService.create();
    const prayerService = PrayerService();
    return AppController._(
      document: AdhkarDocument.fromJsonString(source),
      storage: storage,
      prayerService: prayerService,
      notificationService: NotificationService(),
      locationService: const LocationService(),
    );
  }

  Future<void> activateDeviceServices({bool requestPermissions = true}) async {
    if (_activating) return;
    _activating = true;

    var notificationsAllowed = false;
    try {
      await _notificationService.initialize();
      notificationsAllowed = requestPermissions
          ? await _notificationService.requestPermission()
          : await _notificationService.areNotificationsEnabled();
    } on Object catch (error) {
      debugPrint('Notification initialization failed: $error');
      notificationsAllowed = false;
    }

    LocationResult? location;
    try {
      location = await _locationService.acquire(
        _storage,
        requestPermission: requestPermissions,
      );
      _coordinates = location.coordinates;
      _serviceMessage = location.message;
    } on Object {
      _coordinates = _storage.loadCoordinates();
    }

    try {
      await _notificationService.configureDeviceTimeZone(_storage);
    } on Object {
      _notificationService.configureStoredTimeZone(_storage.timezoneId);
    }

    if (_coordinates != null) {
      try {
        await _applyFajrReset();
        _refreshTodayPrayers();
        _armFajrTimer();
      } on Object {
        // The adhkar experience must remain available if prayer calculation
        // cannot be refreshed on a particular launch.
      }

      if (notificationsAllowed) {
        try {
          await _notificationService.schedulePrayerReminders(
            coordinates: _coordinates!,
          );
          _serviceMessage = 'التذكير مضبوط بعد الفجر والعصر بنصف ساعة.';
        } on Object catch (error) {
          debugPrint('Prayer reminder scheduling failed: $error');
          _serviceMessage = 'تعذر جدولة التنبيهات الآن.';
        }
      } else {
        _serviceMessage = 'فعّل الإشعارات لتصلك تذكيرات الأذكار.';
      }

      try {
        await _registerBackgroundRefresh();
      } on Object {
        // Foreground scheduling above still remains active.
      }
    }

    _servicesActivated = true;
    notifyListeners();
    _activating = false;
  }

  Future<void> refreshAfterResume() async {
    if (_coordinates == null) return;
    await _applyFajrReset();
    _refreshTodayPrayers();
    _armFajrTimer();
    notifyListeners();
  }

  Future<bool> openApplicationSettings() =>
      _locationService.openApplicationSettings();

  int countFor(AdhkarPeriod period, int order) {
    final counts = period == AdhkarPeriod.morning
        ? _morningCounts
        : _eveningCounts;
    return counts[order] ?? 0;
  }

  Future<bool> increment(AdhkarPeriod period, AdhkarItem item) async {
    final counts = period == AdhkarPeriod.morning
        ? _morningCounts
        : _eveningCounts;
    final current = counts[item.order] ?? 0;
    if (current >= item.repetition) return false;
    counts[item.order] = current + 1;
    notifyListeners();
    await _storage.saveCount(period, item.order, current + 1);
    return current + 1 >= item.repetition;
  }

  Future<void> resetAll() async {
    await _storage.resetAllCounters();
    _reloadCounts();
    notifyListeners();
  }

  void _reloadCounts() {
    _morningCounts = _storage.loadCounts(AdhkarPeriod.morning);
    _eveningCounts = _storage.loadCounts(AdhkarPeriod.evening);
  }

  Future<void> _applyFajrReset() async {
    final didReset = await _resetService.ensureLatestFajrApplied(
      now: DateTime.now(),
      coordinates: _coordinates!,
    );
    if (didReset) _reloadCounts();
  }

  void _refreshTodayPrayers() {
    _todayPrayers = _prayerService.forDate(
      date: DateTime.now(),
      latitude: _coordinates!.latitude,
      longitude: _coordinates!.longitude,
    );
  }

  void _armFajrTimer() {
    _fajrTimer?.cancel();
    final now = DateTime.now();
    final nextFajr = _resetService.nextFajr(
      now: now,
      coordinates: _coordinates!,
    );
    _fajrTimer = Timer(nextFajr.difference(now), () async {
      await _applyFajrReset();
      _refreshTodayPrayers();
      _armFajrTimer();
      notifyListeners();
    });
  }

  Future<void> _registerBackgroundRefresh() async {
    await Workmanager().registerPeriodicTask(
      refreshScheduleUniqueName,
      refreshScheduleTask,
      frequency: const Duration(hours: 12),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  @override
  void dispose() {
    _fajrTimer?.cancel();
    super.dispose();
  }
}
