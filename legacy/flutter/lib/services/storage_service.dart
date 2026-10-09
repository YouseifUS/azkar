import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/adhkar.dart';

class StoredCoordinates {
  const StoredCoordinates(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class StorageService {
  StorageService(this._preferences);

  final SharedPreferences _preferences;

  static const _latitudeKey = 'location_latitude';
  static const _longitudeKey = 'location_longitude';
  static const _timezoneKey = 'timezone_id';
  static const _lastResetKey = 'last_fajr_reset';
  static const _lightThemeKey = 'light_theme_enabled';

  bool get lightThemeEnabled => _preferences.getBool(_lightThemeKey) ?? false;

  Future<void> saveLightTheme(bool enabled) =>
      _preferences.setBool(_lightThemeKey, enabled);

  static Future<StorageService> create() async {
    return StorageService(await SharedPreferences.getInstance());
  }

  String _countsKey(AdhkarPeriod period) => '${period.storageKey}_counts';

  Map<int, int> loadCounts(AdhkarPeriod period) {
    final raw = _preferences.getString(_countsKey(period));
    if (raw == null) return <int, int>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(int.parse(key), value as int),
      );
    } on Object {
      return <int, int>{};
    }
  }

  Future<void> saveCount(AdhkarPeriod period, int order, int value) async {
    final counts = loadCounts(period)..[order] = value;
    await _preferences.setString(
      _countsKey(period),
      jsonEncode(counts.map((key, value) => MapEntry('$key', value))),
    );
  }

  Future<void> resetAllCounters() async {
    await Future.wait([
      _preferences.remove(_countsKey(AdhkarPeriod.morning)),
      _preferences.remove(_countsKey(AdhkarPeriod.evening)),
    ]);
  }

  StoredCoordinates? loadCoordinates() {
    final latitude = _preferences.getDouble(_latitudeKey);
    final longitude = _preferences.getDouble(_longitudeKey);
    if (latitude == null || longitude == null) return null;
    return StoredCoordinates(latitude, longitude);
  }

  Future<void> saveCoordinates(double latitude, double longitude) async {
    await Future.wait([
      _preferences.setDouble(_latitudeKey, latitude),
      _preferences.setDouble(_longitudeKey, longitude),
    ]);
  }

  String? get timezoneId => _preferences.getString(_timezoneKey);

  Future<void> saveTimezoneId(String value) =>
      _preferences.setString(_timezoneKey, value);

  String? get lastResetBoundary => _preferences.getString(_lastResetKey);

  Future<void> saveLastResetBoundary(String value) =>
      _preferences.setString(_lastResetKey, value);
}
