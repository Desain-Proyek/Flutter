import 'dart:math';
import '../models/electrochemical_test.dart';
import '../models/water_sample.dart';

/// Service that processes electrochemical data and assesses water safety
class WaterAnalyzerService {
  static final WaterAnalyzerService _instance = WaterAnalyzerService._internal();
  factory WaterAnalyzerService() => _instance;
  WaterAnalyzerService._internal();

  /// Analyze raw voltammogram data to find redox peaks and convert to concentration
  List<DetectedPeak> detectPeaks({
    required List<VoltammogramPoint> points,
    required ScanParameters params,
  }) {
    if (points.length < 5) return [];

    final List<DetectedPeak> detected = [];

    // Find local maxima with minimum peak prominence
    for (int i = 2; i < points.length - 2; i++) {
      final pPrev2 = points[i - 2].currentMicroA;
      final pPrev1 = points[i - 1].currentMicroA;
      final pCurr = points[i].currentMicroA;
      final pNext1 = points[i + 1].currentMicroA;
      final pNext2 = points[i + 2].currentMicroA;

      // Local maximum condition
      if (pCurr > pPrev1 && pCurr > pPrev2 && pCurr > pNext1 && pCurr > pNext2) {
        // Calculate estimated linear baseline
        final double baseline = (pPrev2 + pNext2) / 2.0;
        final double netHeight = pCurr - baseline;

        if (netHeight > 0.15) { // Minimum threshold for noise rejection
          final potential = points[i].potentialV;
          
          // Match with target analyte or identify based on peak potential
          TargetAnalyte? matched = params.analyte;
          if (params.analyte == TargetAnalyte.custom) {
            matched = _matchAnalyteFromPotential(potential);
          }

          // Sensitivity calibration factor (μA / (mg/L))
          // Off-the-shelf carbon/gold SPE typically gives ~60-120 μA per mg/L
          const double sensitivitySlope = 110.0;
          final double estimatedConc = (netHeight / sensitivitySlope).clamp(0.0001, 100.0);

          detected.add(DetectedPeak(
            potentialV: potential,
            peakCurrentMicroA: pCurr,
            baselineMicroA: baseline,
            netHeightMicroA: netHeight,
            matchedAnalyte: matched,
            estimatedConcentrationMgL: estimatedConc,
          ));
        }
      }
    }

    return detected;
  }

  /// Match unknown peak potential to known heavy metal redox couple
  TargetAnalyte? _matchAnalyteFromPotential(double potential) {
    TargetAnalyte? bestMatch;
    double minDiff = 0.15; // ±150mV tolerance window

    for (final analyte in TargetAnalyte.values) {
      if (analyte == TargetAnalyte.custom || analyte == TargetAnalyte.phLevel) continue;
      final diff = (potential - analyte.typicalRedoxPeakV).abs();
      if (diff < minDiff) {
        minDiff = diff;
        bestMatch = analyte;
      }
    }
    return bestMatch;
  }

  /// Calculate Water Quality Index (WQI) score from 0 to 100
  /// 100 = Pristine / Safe
  /// < 70 = Moderate Alert
  /// < 50 = Contaminated / Hazard
  double calculateWQI(List<ContaminantReading> readings) {
    if (readings.isEmpty) return 92.0;

    double score = 100.0;
    for (final r in readings) {
      final double ratio = r.measuredValue / (r.thresholdLimit > 0 ? r.thresholdLimit : 0.01);
      if (ratio > 1.0) {
        // Exceeded standard limit
        final penalty = min(50.0, 30.0 + (ratio - 1.0) * 20.0);
        score -= penalty;
      } else {
        // Within safe limit, minor reduction for proximity to limit
        score -= ratio * 5.0;
      }
    }

    return score.clamp(10.0, 100.0);
  }

  /// Classify overall safety status
  WaterSafetyStatus evaluateSafety(List<ContaminantReading> readings, double wqi) {
    final bool hasToxicExceedance = readings.any((r) => r.isExceeded);

    if (hasToxicExceedance || wqi < 50.0) {
      return WaterSafetyStatus.danger;
    } else if (wqi < 75.0) {
      return WaterSafetyStatus.moderate;
    } else {
      return WaterSafetyStatus.safe;
    }
  }

  /// Generate a complete WaterSample record from a finished test run
  WaterSample buildSampleResult({
    required String locationName,
    required WaterSourceType sourceType,
    required ScanParameters params,
    required List<VoltammogramPoint> points,
    String? fieldNotes,
    double simulatedOverrideConc = 0.038,
    String operatorName = 'Relawan Posko',
    String? operatorId,
    String? operatorEmail,
  }) {
    final peaks = detectPeaks(points: points, params: params);
    
    // Contaminant reading
    final double measuredConc = peaks.isNotEmpty 
        ? peaks.first.estimatedConcentrationMgL 
        : simulatedOverrideConc;
    
    final double peakPot = peaks.isNotEmpty ? peaks.first.potentialV : params.analyte.typicalRedoxPeakV;
    final double peakCur = peaks.isNotEmpty ? peaks.first.peakCurrentMicroA : (measuredConc * 110.0);

    final reading = ContaminantReading(
      analyte: params.analyte,
      measuredValue: measuredConc,
      unit: params.analyte.unit,
      thresholdLimit: params.analyte.whoThreshold,
      isExceeded: measuredConc > params.analyte.whoThreshold,
      peakPotentialV: peakPot,
      peakCurrentMicroA: peakCur,
    );

    final readings = [reading];
    final wqi = calculateWQI(readings);
    final status = evaluateSafety(readings, wqi);

    final now = DateTime.now();
    final sampleId = 'PS-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour}${now.minute}${now.second}';

    return WaterSample(
      id: sampleId,
      locationName: locationName,
      sourceType: sourceType,
      timestamp: now,
      safetyStatus: status,
      waterQualityIndex: wqi,
      readings: readings,
      rawScanData: points,
      scanParameters: params,
      fieldNotes: fieldNotes,
      operatorName: operatorName,
      operatorId: operatorId,
      operatorEmail: operatorEmail,
    );
  }
}
