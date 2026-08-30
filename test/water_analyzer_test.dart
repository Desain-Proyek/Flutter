import 'package:flutter_test/flutter_test.dart';
import 'package:despro/models/electrochemical_test.dart';
import 'package:despro/models/water_sample.dart';
import 'package:despro/services/water_analyzer_service.dart';

void main() {
  group('WaterAnalyzerService Tests', () {
    late WaterAnalyzerService analyzer;

    setUp(() {
      analyzer = WaterAnalyzerService();
    });

    test('calculates WQI score accurately for safe vs contaminated readings', () {
      final safeReadings = [
        const ContaminantReading(
          analyte: TargetAnalyte.lead,
          measuredValue: 0.002,
          unit: 'mg/L',
          thresholdLimit: 0.010,
          isExceeded: false,
          peakPotentialV: -0.45,
          peakCurrentMicroA: 0.22,
        ),
      ];
      final safeScore = analyzer.calculateWQI(safeReadings);
      expect(safeScore, greaterThanOrEqualTo(80.0));
      expect(analyzer.evaluateSafety(safeReadings, safeScore), equals(WaterSafetyStatus.safe));

      final toxicReadings = [
        const ContaminantReading(
          analyte: TargetAnalyte.lead,
          measuredValue: 0.050, // 5x higher than WHO limit
          unit: 'mg/L',
          thresholdLimit: 0.010,
          isExceeded: true,
          peakPotentialV: -0.45,
          peakCurrentMicroA: 5.5,
        ),
      ];
      final toxicScore = analyzer.calculateWQI(toxicReadings);
      expect(toxicScore, lessThanOrEqualTo(50.0));
      expect(analyzer.evaluateSafety(toxicReadings, toxicScore), equals(WaterSafetyStatus.danger));
    });

    test('detects electrochemical peak from synthetic voltammogram data', () {
      final points = [
        const VoltammogramPoint(potentialV: -0.60, currentMicroA: 0.5, timestampSec: 0.1),
        const VoltammogramPoint(potentialV: -0.55, currentMicroA: 0.8, timestampSec: 0.2),
        const VoltammogramPoint(potentialV: -0.50, currentMicroA: 2.2, timestampSec: 0.3),
        const VoltammogramPoint(potentialV: -0.45, currentMicroA: 6.4, timestampSec: 0.4), // Peak
        const VoltammogramPoint(potentialV: -0.40, currentMicroA: 2.5, timestampSec: 0.5),
        const VoltammogramPoint(potentialV: -0.35, currentMicroA: 0.9, timestampSec: 0.6),
        const VoltammogramPoint(potentialV: -0.30, currentMicroA: 0.6, timestampSec: 0.7),
      ];

      final peaks = analyzer.detectPeaks(
        points: points,
        params: ScanParameters.presetFor(TargetAnalyte.lead),
      );

      expect(peaks.isNotEmpty, isTrue);
      expect(peaks.first.potentialV, equals(-0.45));
      expect(peaks.first.peakCurrentMicroA, equals(6.4));
      expect(peaks.first.netHeightMicroA, greaterThan(3.0));
    });
  });
}
