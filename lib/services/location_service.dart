import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Service managing GPS & device geolocation resolution.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Retrieve current real-world device coordinates.
  ///
  /// Returns null if location service is disabled, permission denied,
  /// or if an error / timeout occurs.
  Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Layanan lokasi (GPS) tidak aktif.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Izin lokasi ditolak oleh pengguna.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Izin lokasi ditolak permanen.');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );

      debugPrint(
        '[LocationService] Lokasi terdeteksi: Lat=${position.latitude}, Lng=${position.longitude}, Akurasi=${position.accuracy}m',
      );
      return position;
    } catch (e) {
      debugPrint('[LocationService] Exception saat mengambil lokasi: $e');
      return null;
    }
  }
}
