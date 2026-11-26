import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:despro/models/electrochemical_test.dart';
import 'package:despro/services/map_cache_service.dart';
import 'package:despro/widgets/high_contrast_scope.dart';
import 'package:despro/widgets/live_voltammogram_chart.dart';

void main() {
  group('Mode Terik Matahari (High Contrast)', () {
    testWidgets('LiveVoltammogramChart renders cleanly in high-contrast mode',
        (WidgetTester tester) async {
      final points = [
        const VoltammogramPoint(
            potentialV: -0.60, currentMicroA: 0.5, timestampSec: 0.1),
        const VoltammogramPoint(
            potentialV: -0.45, currentMicroA: 6.4, timestampSec: 0.4),
        const VoltammogramPoint(
            potentialV: -0.30, currentMicroA: 0.6, timestampSec: 0.7),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: HighContrastScope(
            isHighContrast: true,
            child: Scaffold(
              body: SizedBox(
                width: 360,
                height: 260,
                child: LiveVoltammogramChart(
                  points: points,
                  isHighContrast: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(LiveVoltammogramChart), findsOneWidget);
      final chart = tester.widget<LiveVoltammogramChart>(
        find.byType(LiveVoltammogramChart),
      );
      expect(chart.isHighContrast, isTrue);
    });

    test('SharedPreferences persists and loads is_high_contrast', () async {
      SharedPreferences.setMockInitialValues({'is_high_contrast': true});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_high_contrast'), isTrue);

      await prefs.setBool('is_high_contrast', false);
      expect(prefs.getBool('is_high_contrast'), isFalse);
    });
  });

  group('MapCacheService', () {
    test('computeTilesForBounds generates valid tile coordinates and respects maxTiles',
        () {
      final bounds = LatLngBounds(
        const LatLng(-6.95, 107.55),
        const LatLng(-6.88, 107.68),
      );
      final tiles = MapCacheService.computeTilesForBounds(
        bounds,
        minZoom: 11,
        maxZoom: 13,
        maxTiles: 50,
      );

      expect(tiles, isNotEmpty);
      expect(tiles.length, lessThanOrEqualTo(50));
      for (final t in tiles) {
        expect(t.z, inInclusiveRange(11, 13));
        expect(t.x, greaterThanOrEqualTo(0));
        expect(t.y, greaterThanOrEqualTo(0));
      }
    });

    test('MapCacheStats formats byte sizes accurately', () {
      expect(
        const MapCacheStats(tileCount: 0, totalBytes: 0).formattedSize,
        equals('0 B'),
      );
      expect(
        const MapCacheStats(tileCount: 5, totalBytes: 2048).formattedSize,
        equals('2.0 KB'),
      );
      expect(
        const MapCacheStats(tileCount: 100, totalBytes: 5 * 1024 * 1024)
            .formattedSize,
        equals('5.0 MB'),
      );
    });
  });
}
