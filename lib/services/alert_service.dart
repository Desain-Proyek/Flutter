import 'package:geolocator/geolocator.dart';
import '../models/water_sample.dart';

/// Time window during which danger samples are considered active alerts (24 hours).
const Duration kAlertWindow = Duration(hours: 24);

/// Maximum radius in meters from the user's position for alert eligibility (5 km).
const double kAlertRadiusMeters = 5000.0;

/// Selects and filters water samples that qualify as danger alerts.
///
/// An alert qualifies when:
/// 1. Its ID is not in [dismissedIds].
/// 2. [WaterSample.safetyStatus] is [WaterSafetyStatus.danger].
/// 3. [WaterSample.timestamp] is within the last 24 hours ([kAlertWindow]) of [now].
/// 4. If [origin] is provided:
///    - Sample must have valid coordinates (latitude and longitude not null).
///    - Distance between [origin] and sample coordinates must be <= [kAlertRadiusMeters].
/// 5. If [origin] is null (GPS unavailable / disabled):
///    - Distance filtering is bypassed.
///    - Samples with or without coordinates are included.
///
/// Returns alerts sorted by distance ascending (nearest first) when [origin] is known,
/// or by newest first when [origin] is null.
List<WaterSample> selectAlerts(
  List<WaterSample> samples, {
  required DateTime now,
  ({double lat, double lng})? origin,
  Set<String> dismissedIds = const {},
}) {
  final List<WaterSample> alerts = [];

  for (final sample in samples) {
    // Exclude previously dismissed samples
    if (dismissedIds.contains(sample.id)) {
      continue;
    }

    // Must be in danger status
    if (sample.safetyStatus != WaterSafetyStatus.danger) {
      continue;
    }

    // Must be within the last 24 hours
    final age = now.difference(sample.timestamp);
    if (age < Duration.zero || age > kAlertWindow) {
      continue;
    }

    if (origin != null) {
      // Exclude samples missing coordinates when device location is available
      if (sample.latitude == null || sample.longitude == null) {
        continue;
      }

      final distance = Geolocator.distanceBetween(
        origin.lat,
        origin.lng,
        sample.latitude!,
        sample.longitude!,
      );

      if (distance > kAlertRadiusMeters) {
        continue;
      }
    }

    alerts.add(sample);
  }

  // Sort by distance (when origin is known) or by newest first
  if (origin != null) {
    alerts.sort((a, b) {
      final distA = Geolocator.distanceBetween(
        origin.lat,
        origin.lng,
        a.latitude!,
        a.longitude!,
      );
      final distB = Geolocator.distanceBetween(
        origin.lat,
        origin.lng,
        b.latitude!,
        b.longitude!,
      );
      final cmp = distA.compareTo(distB);
      if (cmp != 0) return cmp;
      return b.timestamp.compareTo(a.timestamp);
    });
  } else {
    alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  return alerts;
}

/// Formats how long ago an alert occurred in Indonesian ("12 menit lalu", "2 jam lalu").
String formatTimeAgo(DateTime timestamp, {required DateTime now}) {
  final diff = now.difference(timestamp);
  if (diff.isNegative || diff.inMinutes < 1) {
    return 'Baru saja';
  } else if (diff.inHours < 1) {
    return '${diff.inMinutes} menit lalu';
  } else if (diff.inDays < 1) {
    return '${diff.inHours} jam lalu';
  } else {
    return '${diff.inDays} hari lalu';
  }
}

/// Formats the distance between the origin and a sample in Indonesian ("2,3 km dari lokasi Anda").
String? formatAlertDistance(({double lat, double lng})? origin, WaterSample sample) {
  if (origin == null || sample.latitude == null || sample.longitude == null) {
    return null;
  }
  final meters = Geolocator.distanceBetween(
    origin.lat,
    origin.lng,
    sample.latitude!,
    sample.longitude!,
  );
  final km = meters / 1000.0;
  return '${km.toStringAsFixed(1).replaceAll('.', ',')} km dari lokasi Anda';
}
