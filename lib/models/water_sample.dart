import 'package:cloud_firestore/cloud_firestore.dart';
import 'electrochemical_test.dart';

/// Safety status of water sample according to WHO & Permenkes RI
enum WaterSafetyStatus {
  safe(
    'Aman Dikonsumsi',
    'Memenuhi baku mutu air minum (WHO / Permenkes No. 2/2023). Bebas logam berbahaya.',
  ),
  moderate(
    'Perlu Penanganan',
    'Melewati ambang batas estetika/ringan. Perlu filtrasi atau aerasi sebelum dikonsumsi.',
  ),
  danger(
    'Bahaya / Tercemar',
    'Mengandung kontaminan logam berat berbahaya. JANGAN DIMINUM langsung!',
  );

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
  final double measuredValue;
  final String unit;
  final double thresholdLimit;
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

  Map<String, dynamic> toMap() {
    return {
      'analyte': analyte.name,
      'measured': measuredValue,
      'unit': unit,
      'threshold': thresholdLimit,
      'exceeded': isExceeded,
      'potential_v': peakPotentialV,
      'current_ua': peakCurrentMicroA,
    };
  }

  factory ContaminantReading.fromMap(Map<String, dynamic> map) {
    final analyteName = map['analyte'] as String;

    final analyte = TargetAnalyte.values.firstWhere(
      (value) => value.name == analyteName,
    );

    return ContaminantReading(
      analyte: analyte,
      measuredValue: (map['measured'] as num).toDouble(),
      unit: map['unit'] as String,
      thresholdLimit: (map['threshold'] as num).toDouble(),
      isExceeded: map['exceeded'] as bool,
      peakPotentialV: (map['potential_v'] as num).toDouble(),
      peakCurrentMicroA: (map['current_ua'] as num).toDouble(),
    );
  }
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
  final double waterQualityIndex;
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

  /// Convert WaterSample into Firestore-compatible data.
  Map<String, dynamic> toMap() {
    return {
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'sourceType': sourceType.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'safetyStatus': safetyStatus.name,
      'waterQualityIndex': waterQualityIndex,
      'readings': readings.map((reading) => reading.toMap()).toList(),
      'fieldNotes': fieldNotes,
      'operatorName': operatorName,
    };
  }

  /// Reconstruct WaterSample from Firestore data.
  factory WaterSample.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    final timestampData = map['timestamp'];

    DateTime timestamp;

    if (timestampData is Timestamp) {
      timestamp = timestampData.toDate();
    } else if (timestampData is DateTime) {
      timestamp = timestampData;
    } else if (timestampData is String) {
      timestamp = DateTime.parse(timestampData);
    } else {
      timestamp = DateTime.now();
    }

    final sourceType = WaterSourceType.values.firstWhere(
      (value) => value.name == map['sourceType'],
      orElse: () => WaterSourceType.well,
    );

    final safetyStatus = WaterSafetyStatus.values.firstWhere(
      (value) => value.name == map['safetyStatus'],
      orElse: () => WaterSafetyStatus.moderate,
    );

    final readingsData = map['readings'] as List<dynamic>? ?? [];

    final readings = readingsData
        .map(
          (reading) => ContaminantReading.fromMap(
            Map<String, dynamic>.from(reading as Map),
          ),
        )
        .toList();

    final TargetAnalyte analyte = readings.isNotEmpty
        ? readings.first.analyte
        : TargetAnalyte.lead;

    return WaterSample(
      id: id,
      locationName: map['locationName'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      sourceType: sourceType,
      timestamp: timestamp,
      safetyStatus: safetyStatus,
      waterQualityIndex:
          (map['waterQualityIndex'] as num?)?.toDouble() ?? 0.0,
      readings: readings,
      rawScanData: const [],
      scanParameters: ScanParameters.presetFor(analyte),
      fieldNotes: map['fieldNotes'] as String?,
      operatorName:
          map['operatorName'] as String? ?? 'Relawan Posko',
    );
  }

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