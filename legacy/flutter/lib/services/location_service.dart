import 'package:geolocator/geolocator.dart';

import 'storage_service.dart';

class LocationResult {
  const LocationResult({required this.coordinates, required this.message});

  final StoredCoordinates? coordinates;
  final String message;
}

class LocationService {
  const LocationService();

  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<LocationResult> acquire(
    StorageService storage, {
    bool requestPermission = true,
  }) async {
    final fallback = storage.loadCoordinates();
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return LocationResult(
        coordinates: fallback,
        message: fallback == null
            ? 'يلزم إذن الموقع لحساب الفجر والعصر.'
            : 'إذن الموقع مرفوض؛ يتم استخدام آخر موقع محفوظ.',
      );
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationResult(
        coordinates: fallback,
        message: fallback == null
            ? 'فعّل خدمة الموقع لحساب مواقيت الصلاة.'
            : 'يتم استخدام آخر موقع محفوظ.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      await storage.saveCoordinates(position.latitude, position.longitude);
      return LocationResult(
        coordinates: StoredCoordinates(position.latitude, position.longitude),
        message: 'تم ضبط المواقيت حسب موقعك.',
      );
    } on Object {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        await storage.saveCoordinates(lastKnown.latitude, lastKnown.longitude);
        return LocationResult(
          coordinates: StoredCoordinates(
            lastKnown.latitude,
            lastKnown.longitude,
          ),
          message: 'تم ضبط المواقيت حسب آخر موقع معروف.',
        );
      }
      return LocationResult(
        coordinates: fallback,
        message: fallback == null
            ? 'تعذر تحديد الموقع. حاول مرة أخرى لاحقًا.'
            : 'تعذر تحديث الموقع؛ يتم استخدام آخر موقع محفوظ.',
      );
    }
  }

  Future<bool> openApplicationSettings() => Geolocator.openAppSettings();
}
