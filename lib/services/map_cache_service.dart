import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:path_provider/path_provider.dart';

/// Statistics about locally cached map tiles.
class MapCacheStats {
  final int tileCount;
  final int totalBytes;

  const MapCacheStats({required this.tileCount, required this.totalBytes});

  String get formattedSize {
    if (totalBytes <= 0) return '0 B';
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Service managing offline OpenStreetMap tile caching, pre-downloading,
/// and cache cleanup across Windows, Android, and Web.
class MapCacheService {
  static final MapCacheService _instance = MapCacheService._internal();
  factory MapCacheService() => _instance;
  MapCacheService._internal();

  static const int maxCacheBytes = 200 * 1024 * 1024; // 200 MB
  static const Duration tileTtl = Duration(days: 30);
  static const int maxTilesPerDownload = 600;
  static const String osmUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String userAgentHeader = 'PortaStat/1.0 (com.example.despro)';

  CacheStore? _cacheStore;
  CachedTileProvider? _cachedTileProvider;
  Directory? _cacheDir;
  Future<void>? _initFuture;

  bool get isSupported => !kIsWeb && _cachedTileProvider != null;

  /// Initialize the local file-based tile cache (idempotent).
  Future<void> init() {
    return _initFuture ??= _initInternal();
  }

  Future<void> _initInternal() async {
    if (kIsWeb) return;

    try {
      final baseDir = await getApplicationCacheDirectory();
      final dir = Directory('${baseDir.path}${Platform.pathSeparator}map_tiles');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cacheDir = dir;
      _cacheStore = FileCacheStore(dir.path);
      _cachedTileProvider = CachedTileProvider(
        store: _cacheStore!,
        cachePolicy: CachePolicy.forceCache,
        maxStale: tileTtl,
        dio: Dio(
          BaseOptions(
            headers: {'User-Agent': userAgentHeader},
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        ),
      );
      await _enforceMaxCacheSize();
    } catch (e) {
      debugPrint('[MapCacheService] Fallback to network-only tiles: $e');
      _cacheStore = null;
      _cachedTileProvider = null;
    }
  }

  /// Returns a cached [TileProvider] when available, or [NetworkTileProvider] on Web/fallback.
  TileProvider get tileProvider =>
      _cachedTileProvider ?? NetworkTileProvider();

  /// Compute Slippy Map tile coordinates within [bounds] for zoom levels [minZoom]..[maxZoom].
  static List<({int z, int x, int y})> computeTilesForBounds(
    LatLngBounds bounds, {
    int minZoom = 11,
    int maxZoom = 16,
    int maxTiles = maxTilesPerDownload,
  }) {
    final tiles = <({int z, int x, int y})>[];
    final clampedMinZ = minZoom.clamp(1, 18);
    final clampedMaxZ = maxZoom.clamp(clampedMinZ, 18);

    for (int z = clampedMinZ; z <= clampedMaxZ; z++) {
      final n = pow(2, z).toInt();
      final xMin = _lonToTileX(bounds.west, n);
      final xMax = _lonToTileX(bounds.east, n);
      final yMin = _latToTileY(bounds.north, n);
      final yMax = _latToTileY(bounds.south, n);

      for (int x = min(xMin, xMax); x <= max(xMin, xMax); x++) {
        for (int y = min(yMin, yMax); y <= max(yMin, yMax); y++) {
          tiles.add((z: z, x: x, y: y));
          if (tiles.length >= maxTiles) {
            return tiles;
          }
        }
      }
    }
    return tiles;
  }

  static int _lonToTileX(double lon, int n) {
    return (((lon + 180.0) / 360.0) * n).floor().clamp(0, n - 1);
  }

  static int _latToTileY(double lat, int n) {
    final clampedLat = lat.clamp(-85.05112878, 85.05112878);
    final latRad = clampedLat * pi / 180.0;
    final y = ((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0) * n;
    return y.floor().clamp(0, n - 1);
  }

  /// Pre-download map tiles for [bounds] across [minZoom]..[maxZoom].
  Future<({int downloaded, int total, bool cancelled})> downloadRegionTiles({
    required LatLngBounds bounds,
    int minZoom = 11,
    int maxZoom = 16,
    required void Function(int completed, int total) onProgress,
    required bool Function() isCancelled,
  }) async {
    await init();
    if (_cachedTileProvider == null) {
      return (downloaded: 0, total: 0, cancelled: false);
    }

    final tiles = computeTilesForBounds(
      bounds,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
    final total = tiles.length;
    if (total == 0) {
      return (downloaded: 0, total: 0, cancelled: false);
    }

    int completed = 0;
    int downloaded = 0;
    const int batchSize = 4;
    final dio = _cachedTileProvider!.dio;

    for (int i = 0; i < total; i += batchSize) {
      if (isCancelled()) {
        return (downloaded: downloaded, total: total, cancelled: true);
      }

      final end = min(i + batchSize, total);
      final batch = tiles.sublist(i, end);

      await Future.wait(
        batch.map((tile) async {
          if (isCancelled()) return;
          final url =
              'https://tile.openstreetmap.org/${tile.z}/${tile.x}/${tile.y}.png';
          try {
            await dio.get<List<int>>(
              url,
              options: Options(responseType: ResponseType.bytes),
            );
            downloaded++;
          } catch (_) {
            // Skip failed tiles without aborting the entire region download.
          } finally {
            completed++;
          }
        }),
      );

      onProgress(completed, total);
    }

    await _enforceMaxCacheSize();
    return (downloaded: downloaded, total: total, cancelled: isCancelled());
  }

  /// Measure current cached tile count and disk usage.
  Future<MapCacheStats> getCacheStats() async {
    await init();
    if (kIsWeb || _cacheDir == null || !await _cacheDir!.exists()) {
      return const MapCacheStats(tileCount: 0, totalBytes: 0);
    }

    int count = 0;
    int bytes = 0;
    try {
      await for (final entity in _cacheDir!.list(recursive: true)) {
        if (entity is File) {
          count++;
          bytes += await entity.length();
        }
      }
    } catch (e) {
      debugPrint('[MapCacheService] Failed to read cache stats: $e');
    }
    return MapCacheStats(tileCount: count, totalBytes: bytes);
  }

  /// Clear all locally cached map tiles without affecting Firestore data.
  Future<void> clearCache() async {
    await init();
    if (kIsWeb) return;

    try {
      await _cacheStore?.clean();
      if (_cacheDir != null && await _cacheDir!.exists()) {
        await for (final entity in _cacheDir!.list(recursive: false)) {
          await entity.delete(recursive: true);
        }
      }
    } catch (e) {
      debugPrint('[MapCacheService] Failed to clear cache: $e');
    }
  }

  Future<void> _enforceMaxCacheSize() async {
    if (kIsWeb || _cacheDir == null || !await _cacheDir!.exists()) return;
    try {
      final files = <({File file, int size, DateTime modified})>[];
      int totalBytes = 0;
      await for (final entity in _cacheDir!.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          totalBytes += stat.size;
          files.add((file: entity, size: stat.size, modified: stat.modified));
        }
      }
      if (totalBytes <= maxCacheBytes) return;

      files.sort((a, b) => a.modified.compareTo(b.modified));
      for (final item in files) {
        if (totalBytes <= maxCacheBytes) break;
        await item.file.delete();
        totalBytes -= item.size;
      }
    } catch (e) {
      debugPrint('[MapCacheService] Cache trim error: $e');
    }
  }
}
