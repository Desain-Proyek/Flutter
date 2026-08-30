import 'electrochemical_test.dart';

/// Safety status of water sample according to WHO & Permenkes RI
enum WaterSafetyStatus {
  safe('Aman Dikonsumsi', 'Memenuhi baku mutu air minum (WHO / Permenkes No. 2/2023). Bebas logam berbahaya.'),
  moderate('Perlu Penanganan', 'Melewati ambang batas estetika/ringan. Perlu filtrasi atau aerasi sebelum dikonsumsi.'),
  danger('Bahaya / Tercemar', 'Mengandung kontaminan logam berat berbahaya. JANGAN DIMINUM langsung!');

  final String label;
  final String description;

  const WaterSafetyStatus(this.label, this.description);
}

/// Source type of water sample in field testing
enum WaterSourceType {
  well('Sumur Gali / Bor', 'Air tanah posko pengungsian atau pemukiman'),
  river('Sungai / Aliran Terbuka', 'Air permukaan rentan limpasan & limbah'),
  reliefTank('Truk Tangki Bantuan', 'Pasokan air bersih bantuan tanggap darurat'),
  flood('Genangan Banjir / Rawa', 'Air krisis pasca bencana alam'),
  spring('Mata Air Pegunungan', 'Sumber air alami perbukitan'),
  tap('Perpipaan / PDAM Darurat', 'Jaringan air bersih darurat');

  final String label;
  final String subtitle;

  const WaterSourceType(this.label, this.subtitle);
}

/// Result entry for a single tested contaminant
class ContaminantReading {
  final TargetAnalyte analyte;
  final double measuredValue;       // Measured concentration
  final String unit;
  final double thresholdLimit;      // Standard limit (e.g. 0.01 mg/L)
  final bool isExceeded;
  final double peakPotentialV;
  final double peakCurrentMicroA;

  const ContaminantReading({
    required this.analyte,
    required this.measuredValue,
    required this.unit,
    required this.thresholdLimit,
    required this.isExceeded,
    required this.peakPotentialV,
    required this.peakCurrentMicroA,
  });

  Map<String, dynamic> toMap() => {
    'analyte': analyte.name,
    'measured': measuredValue,
    'unit': unit,
    'threshold': thresholdLimit,
    'exceeded': isExceeded,
    'potential_v': peakPotentialV,
    'current_ua': peakCurrentMicroA,
  };
}

/// Comprehensive water sample record
class WaterSample {
  final String id;
  final String locationName;
  final double? latitude;
  final double? longitude;
  final WaterSourceType sourceType;
  final DateTime timestamp;
  final WaterSafetyStatus safetyStatus;
  final double waterQualityIndex; // 0 to 100
  final List<ContaminantReading> readings;
  final List<VoltammogramPoint> rawScanData;
  final ScanParameters scanParameters;
  final String? fieldNotes;
  final String operatorName;

  const WaterSample({
    required this.id,
    required this.locationName,
    this.latitude,
    this.longitude,
    required this.sourceType,
    required this.timestamp,
    required this.safetyStatus,
    required this.waterQualityIndex,
    required this.readings,
    required this.rawScanData,
    required this.scanParameters,
    this.fieldNotes,
    this.operatorName = 'Relawan Posko',
  });

  /// Factory for sample test generation
  factory WaterSample.sampleMock({
    required String id,
    required String location,
    required WaterSourceType source,
    required WaterSafetyStatus status,
    required double wqi,
    required TargetAnalyte analyte,
    required double conc,
  }) {
    return WaterSample(
      id: id,
      locationName: location,
      sourceType: source,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      safetyStatus: status,
      waterQualityIndex: wqi,
      readings: [
        ContaminantReading(
          analyte: analyte,
          measuredValue: conc,
          unit: analyte.unit,
          thresholdLimit: analyte.whoThreshold,
          isExceeded: conc > analyte.whoThreshold,
          peakPotentialV: analyte.typicalRedoxPeakV,
          peakCurrentMicroA: conc * 85.0,
        ),
      ],
      rawScanData: [],
      scanParameters: ScanParameters.presetFor(analyte),
      fieldNotes: 'Pengambilan sampel di titik pengungsian darurat.',
    );
  }
}
