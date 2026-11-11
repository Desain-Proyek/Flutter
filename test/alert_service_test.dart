import 'package:flutter_test/flutter_test.dart';
import 'package:despro/models/electrochemical_test.dart';
import 'package:despro/models/water_sample.dart';
import 'package:despro/services/alert_service.dart';

WaterSample _createTestSample({
  required String id,
  String locationName = 'Test Posko',
  double? latitude,
  double? longitude,
  WaterSafetyStatus safetyStatus = WaterSafetyStatus.danger,
  required DateTime timestamp,
  List<ContaminantReading> readings = const [],
}) {
  return WaterSample(
    id: id,
    locationName: locationName,
    latitude: latitude,
    longitude: longitude,
    sourceType: WaterSourceType.well,
    timestamp: timestamp,
    safetyStatus: safetyStatus,
    waterQualityIndex: safetyStatus == WaterSafetyStatus.danger ? 25.0 : 92.0,
    readings: readings,
    rawScanData: const [],
    scanParameters: ScanParameters.presetFor(TargetAnalyte.lead),
  );
}

void main() {
  group('selectAlerts', () {
    final now = DateTime(2026, 11, 11, 12, 0, 0);
    const origin = (lat: 0.0, lng: 0.0);

    // 0.00899 degrees latitude ~ 999.6 meters (~1 km) from (0,0)
    const lat1km = 0.00899;
    // 0.0899 degrees latitude ~ 9996 meters (~10 km) from (0,0)
    const lat10km = 0.0899;
    // 0.027 degrees latitude ~ 3000 meters (~3 km) from (0,0)
    const lat3km = 0.027;

    test('keeps a danger sample 1 km away, 1 hour old', () {
      final sample = _createTestSample(
        id: 'sample-1km-1h',
        latitude: lat1km,
        longitude: 0.0,
        safetyStatus: WaterSafetyStatus.danger,
        timestamp: now.subtract(const Duration(hours: 1)),
      );

      final alerts = selectAlerts([sample], now: now, origin: origin);

      expect(alerts.length, 1);
      expect(alerts.first.id, 'sample-1km-1h');
    });

    test('drops a safe sample, a danger sample older than 24 h, and a danger sample 10 km away', () {
      final safeSample = _createTestSample(
        id: 'safe-sample',
        latitude: lat1km,
        longitude: 0.0,
        safetyStatus: WaterSafetyStatus.safe,
        timestamp: now.subtract(const Duration(hours: 1)),
      );

      final oldDangerSample = _createTestSample(
        id: 'old-danger-sample',
        latitude: lat1km,
        longitude: 0.0,
        safetyStatus: WaterSafetyStatus.danger,
        timestamp: now.subtract(const Duration(hours: 25)),
      );

      final farDangerSample = _createTestSample(
        id: 'far-danger-sample',
        latitude: lat10km,
        longitude: 0.0,
        safetyStatus: WaterSafetyStatus.danger,
        timestamp: now.subtract(const Duration(hours: 1)),
      );

      final alerts = selectAlerts(
        [safeSample, oldDangerSample, farDangerSample],
        now: now,
        origin: origin,
      );

      expect(alerts, isEmpty);
    });

    test('includes a danger sample without coordinates only when origin is null', () {
      final noCoordDangerSample = _createTestSample(
        id: 'no-coords',
        latitude: null,
        longitude: null,
        safetyStatus: WaterSafetyStatus.danger,
        timestamp: now.subtract(const Duration(hours: 2)),
      );

      // When origin is available, sample without coordinates must be excluded
      final alertsWithOrigin = selectAlerts(
        [noCoordDangerSample],
        now: now,
        origin: origin,
      );
      expect(alertsWithOrigin, isEmpty);

      // When origin is null, sample without coordinates must be included
      final alertsWithoutOrigin = selectAlerts(
        [noCoordDangerSample],
        now: now,
        origin: null,
      );
      expect(alertsWithoutOrigin.length, 1);
      expect(alertsWithoutOrigin.first.id, 'no-coords');
    });

    test('drops ids listed in dismissedIds', () {
      final sample1 = _createTestSample(
        id: 'sample-dismissed',
        latitude: lat1km,
        longitude: 0.0,
        safetyStatus: WaterSafetyStatus.danger,
        timestamp: now.subtract(const Duration(hours: 1)),
      );

      final sample2 = _createTestSample(
        id: 'sample-active',
        latitude: lat1km,
        longitude: 0.0,
        safetyStatus: WaterSafetyStatus.danger,
        timestamp: now.subtract(const Duration(hours: 1)),
      );

      final alerts = selectAlerts(
        [sample1, sample2],
        now: now,
        origin: origin,
        dismissedIds: {'sample-dismissed'},
      );

      expect(alerts.length, 1);
      expect(alerts.first.id, 'sample-active');
    });

    test('sorts by distance when origin is given', () {
      final sample3km = _createTestSample(
        id: 'sample-3km',
        latitude: lat3km,
        longitude: 0.0,
        safetyStatus: WaterSafetyStatus.danger,
        timestamp: now.subtract(const Duration(hours: 1)),
      );

      final sample1km = _createTestSample(
        id: 'sample-1km',
        latitude: lat1km,
        longitude: 0.0,
        safetyStatus: WaterSafetyStatus.danger,
        timestamp: now.subtract(const Duration(hours: 2)),
      );

      // Input list has 3 km first, then 1 km
      final alerts = selectAlerts(
        [sample3km, sample1km],
        now: now,
        origin: origin,
      );

      expect(alerts.length, 2);
      expect(alerts[0].id, 'sample-1km');
      expect(alerts[1].id, 'sample-3km');
    });

    test('sorts by newest first when origin is null', () {
      final sampleOlder = _createTestSample(
        id: 'older',
        safetyStatus: WaterSafetyStatus.danger,
        timestamp: now.subtract(const Duration(hours: 5)),
      );

      final sampleNewer = _createTestSample(
        id: 'newer',
        safetyStatus: WaterSafetyStatus.danger,
        timestamp: now.subtract(const Duration(hours: 1)),
      );

      final alerts = selectAlerts(
        [sampleOlder, sampleNewer],
        now: now,
        origin: null,
      );

      expect(alerts.length, 2);
      expect(alerts[0].id, 'newer');
      expect(alerts[1].id, 'older');
    });
  });

  group('formatTimeAgo & formatAlertDistance', () {
    final now = DateTime(2026, 11, 11, 12, 0, 0);

    test('formatTimeAgo handles minutes, hours, days, and just now', () {
      expect(formatTimeAgo(now.subtract(const Duration(seconds: 30)), now: now), 'Baru saja');
      expect(formatTimeAgo(now.subtract(const Duration(minutes: 12)), now: now), '12 menit lalu');
      expect(formatTimeAgo(now.subtract(const Duration(hours: 3)), now: now), '3 jam lalu');
      expect(formatTimeAgo(now.subtract(const Duration(days: 2)), now: now), '2 hari lalu');
    });

    test('formatAlertDistance formats distance with comma and km', () {
      const origin = (lat: 0.0, lng: 0.0);
      final sample = _createTestSample(
        id: 'dist-test',
        latitude: 0.02068, // ~2.3 km from 0,0
        longitude: 0.0,
        timestamp: now,
      );

      final formatted = formatAlertDistance(origin, sample);
      expect(formatted, contains('km dari lokasi Anda'));
      expect(formatted, contains(','));
    });
  });
}
