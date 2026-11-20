import 'package:flutter_test/flutter_test.dart';
import 'package:despro/models/device_status.dart';
import 'package:despro/models/electrochemical_test.dart';
import 'package:despro/models/water_sample.dart';
import 'package:despro/services/potentiostat_service.dart';
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

    test('buildSampleResult returns 0.0 and no-peak note when no peak is detected', () {
      PotentiostatService().setDeviceConnection(HardwareConnectionState.simulator);
      final flatPoints = [
        const VoltammogramPoint(potentialV: -0.60, currentMicroA: 0.5, timestampSec: 0.1),
        const VoltammogramPoint(potentialV: -0.55, currentMicroA: 0.5, timestampSec: 0.2),
        const VoltammogramPoint(potentialV: -0.50, currentMicroA: 0.5, timestampSec: 0.3),
        const VoltammogramPoint(potentialV: -0.45, currentMicroA: 0.5, timestampSec: 0.4),
        const VoltammogramPoint(potentialV: -0.40, currentMicroA: 0.5, timestampSec: 0.5),
      ];

      final sample = analyzer.buildSampleResult(
        locationName: 'Posko Uji Kosong',
        sourceType: WaterSourceType.well,
        params: ScanParameters.presetFor(TargetAnalyte.lead),
        points: flatPoints,
      );

      expect(sample.readings.length, equals(1));
      expect(sample.readings.first.measuredValue, equals(0.0));
      expect(sample.readings.first.peakCurrentMicroA, equals(0.0));
      expect(sample.readings.first.isExceeded, isFalse);
      expect(sample.fieldNotes, contains('Tidak ada puncak terdeteksi'));
      expect(sample.isSimulated, isTrue);
    });

    test('DeviceStatus defaults to unknown/neutral telemetry values', () {
      const status = DeviceStatus();
      expect(status.deviceName, equals('-'));
      expect(status.firmwareVersion, equals('-'));
      expect(status.serialPortOrMac, equals('-'));
      expect(status.batteryPercent, isNull);
      expect(status.boardTemperatureC, isNull);
      expect(status.electrodeWearPercent, isNull);
      expect(status.isDummyCellCalibrated, isFalse);
    });

    test('WaterSample toMap and fromMap preserve isSimulated with false default', () {
      final simSample = WaterSample(
        id: 'sim-1',
        locationName: 'Posko Sim',
        sourceType: WaterSourceType.well,
        timestamp: DateTime(2026, 11, 20, 12, 0),
        safetyStatus: WaterSafetyStatus.safe,
        waterQualityIndex: 100.0,
        readings: const [],
        rawScanData: const [],
        scanParameters: ScanParameters.presetFor(TargetAnalyte.lead),
        isSimulated: true,
      );

      final simMap = simSample.toMap();
      expect(simMap['isSimulated'], isTrue);

      final restoredSim = WaterSample.fromMap('sim-1', simMap);
      expect(restoredSim.isSimulated, isTrue);

      final legacyMap = Map<String, dynamic>.from(simMap)..remove('isSimulated');
      final restoredLegacy = WaterSample.fromMap('legacy-1', legacyMap);
      expect(restoredLegacy.isSimulated, isFalse);
    });
  });
}
