import 'dart:convert';
import '../models/water_sample.dart';
import '../models/electrochemical_test.dart';

/// Service managing offline-first field test history and data exports
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal() {
    _initDefaultMockData();
  }

  final List<WaterSample> _samples = [];
  List<WaterSample> get allSamples => List.unmodifiable(_samples);

  void _initDefaultMockData() {
    _samples.addAll([
      WaterSample(
        id: 'PS-20260830-01',
        locationName: 'Posko Pengungsian 03 - Desa Sukamaju',
        latitude: -6.9175,
        longitude: 107.6191,
        sourceType: WaterSourceType.well,
        timestamp: DateTime.now().subtract(const Duration(hours: 3, minutes: 15)),
        safetyStatus: WaterSafetyStatus.danger,
        waterQualityIndex: 42.0,
        readings: [
          const ContaminantReading(
            analyte: TargetAnalyte.lead,
            measuredValue: 0.048,
            unit: 'mg/L',
            thresholdLimit: 0.010,
            isExceeded: true,
            peakPotentialV: -0.44,
            peakCurrentMicroA: 5.28,
          ),
        ],
        rawScanData: [],
        scanParameters: ScanParameters.presetFor(TargetAnalyte.lead),
        fieldNotes: 'Air sumur keruh setelah banjir bandang, bau lumpur tercium.',
      ),
      WaterSample(
        id: 'PS-20260830-02',
        locationName: 'Truk Tangki Air Bersih PMI #07',
        latitude: -6.9200,
        longitude: 107.6250,
        sourceType: WaterSourceType.reliefTank,
        timestamp: DateTime.now().subtract(const Duration(hours: 6)),
        safetyStatus: WaterSafetyStatus.safe,
        waterQualityIndex: 94.0,
        readings: [
          const ContaminantReading(
            analyte: TargetAnalyte.arsenic,
            measuredValue: 0.002,
            unit: 'mg/L',
            thresholdLimit: 0.010,
            isExceeded: false,
            peakPotentialV: 0.15,
            peakCurrentMicroA: 0.22,
          ),
        ],
        rawScanData: [],
        scanParameters: ScanParameters.presetFor(TargetAnalyte.arsenic),
        fieldNotes: 'Pasokan bantuan resmi PMI, kondisi jernih dan netral.',
      ),
      WaterSample(
        id: 'PS-20260829-03',
        locationName: 'Mata Air Bukit Cisarua',
        latitude: -6.8500,
        longitude: 107.6500,
        sourceType: WaterSourceType.spring,
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        safetyStatus: WaterSafetyStatus.safe,
        waterQualityIndex: 88.0,
        readings: [
          const ContaminantReading(
            analyte: TargetAnalyte.lead,
            measuredValue: 0.004,
            unit: 'mg/L',
            thresholdLimit: 0.010,
            isExceeded: false,
            peakPotentialV: -0.45,
            peakCurrentMicroA: 0.44,
          ),
        ],
        rawScanData: [],
        scanParameters: ScanParameters.presetFor(TargetAnalyte.lead),
        fieldNotes: 'Sumber air gravitasi warga lereng, layak konsumsi.',
      ),
      WaterSample(
        id: 'PS-20260829-04',
        locationName: 'Genangan Aliran Sungai Citarik',
        latitude: -6.9500,
        longitude: 107.7000,
        sourceType: WaterSourceType.river,
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
        safetyStatus: WaterSafetyStatus.danger,
        waterQualityIndex: 35.0,
        readings: [
          const ContaminantReading(
            analyte: TargetAnalyte.mercury,
            measuredValue: 0.008,
            unit: 'mg/L',
            thresholdLimit: 0.001,
            isExceeded: true,
            peakPotentialV: 0.49,
            peakCurrentMicroA: 6.8,
          ),
        ],
        rawScanData: [],
        scanParameters: ScanParameters.presetFor(TargetAnalyte.mercury),
        fieldNotes: 'Dicurigai tercemar limbah penambangan/industri hulu.',
      ),
    ]);
  }

  void saveSample(WaterSample sample) {
    _samples.insert(0, sample);
  }

  void deleteSample(String id) {
    _samples.removeWhere((s) => s.id == id);
  }

  List<WaterSample> searchSamples({String? query, WaterSafetyStatus? statusFilter, WaterSourceType? sourceFilter}) {
    return _samples.where((sample) {
      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        final matchLocation = sample.locationName.toLowerCase().contains(q);
        final matchId = sample.id.toLowerCase().contains(q);
        final matchNotes = (sample.fieldNotes ?? '').toLowerCase().contains(q);
        if (!matchLocation && !matchId && !matchNotes) return false;
      }

      if (statusFilter != null && sample.safetyStatus != statusFilter) {
        return false;
      }

      if (sourceFilter != null && sample.sourceType != sourceFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Generate CSV string for tabular field reports
  String exportToCSV() {
    final buffer = StringBuffer();
    buffer.writeln('Sample_ID,Location,Source_Type,Timestamp,WQI_Score,Status,Analyte,Measured_mgL,Threshold_mgL,Exceeded');

    for (final s in _samples) {
      for (final r in s.readings) {
        buffer.writeln(
          '${s.id},"${s.locationName}",${s.sourceType.name},${s.timestamp.toIso8601String()},${s.waterQualityIndex.toStringAsFixed(1)},${s.safetyStatus.name},${r.analyte.name},${r.measuredValue.toStringAsFixed(4)},${r.thresholdLimit.toStringAsFixed(4)},${r.isExceeded}',
        );
      }
    }

    return buffer.toString();
  }

  /// Generate concise JSON QR payload for instant device-to-device field sync
  String exportSampleToQRPayload(WaterSample sample) {
    final map = {
      'id': sample.id,
      'loc': sample.locationName,
      'src': sample.sourceType.name,
      'ts': sample.timestamp.millisecondsSinceEpoch,
      'wqi': sample.waterQualityIndex.round(),
      'status': sample.safetyStatus.name,
      'analyte': sample.readings.isNotEmpty ? sample.readings.first.analyte.symbol : 'N/A',
      'conc': sample.readings.isNotEmpty ? sample.readings.first.measuredValue : 0.0,
      'exceeded': sample.readings.isNotEmpty ? sample.readings.first.isExceeded : false,
    };
    return jsonEncode(map);
  }
}
