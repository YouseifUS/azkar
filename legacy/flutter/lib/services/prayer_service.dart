import 'package:adhan/adhan.dart';

class PrayerMoments {
  const PrayerMoments({required this.fajr, required this.asr});

  final DateTime fajr;
  final DateTime asr;
}

class PrayerService {
  const PrayerService();

  PrayerMoments forDate({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) {
    final parameters = CalculationMethod.egyptian.getParameters()
      ..madhab = Madhab.shafi;
    final times = PrayerTimes(
      Coordinates(latitude, longitude),
      DateComponents.from(date),
      parameters,
    );
    return PrayerMoments(fajr: times.fajr, asr: times.asr);
  }
}
