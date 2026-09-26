import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/water_sample.dart';
import '../models/electrochemical_test.dart';

/// Service managing water sample history and Firestore persistence.
class StorageService {
  // ============================================================
  // SINGLETON
  // ============================================================

  static final StorageService _instance = StorageService._internal();

  factory StorageService() => _instance;

  StorageService._internal() {
    _initDefaultMockData();
  }

  // ============================================================
  // FIRESTORE
  // ============================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collectionName = 'water_samples';

  // ============================================================
  // LOCAL CACHE
  // ============================================================

  final List<WaterSample> _samples = [];

  /// Get all samples currently loaded in local memory.
  List<WaterSample> get allSamples => List.unmodifiable(_samples);

  // ============================================================
  // MOCK DATA
  // ============================================================

  /// Initialize default mock data for development.
  ///
  /// These samples are only stored locally.
  /// They are not automatically uploaded to Firestore.
  void _initDefaultMockData() {
    _samples.addAll([
      WaterSample(
        id: 'PS-20260830-01',
        locationName: 'Posko Pengungsian 03 - Desa Sukamaju',
        latitude: -6.9175,
        longitude: 107.6191,
        sourceType: WaterSourceType.well,
        timestamp: DateTime.now().subtract(
          const Duration(hours: 3, minutes: 15),
        ),
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
        scanParameters: ScanParameters.presetFor(
          TargetAnalyte.lead,
        ),
        fieldNotes:
            'Air sumur keruh setelah banjir bandang, bau lumpur tercium.',
      ),

      WaterSample(
        id: 'PS-20260830-02',
        locationName: 'Truk Tangki Air Bersih PMI #07',
        latitude: -6.9200,
        longitude: 107.6250,
        sourceType: WaterSourceType.reliefTank,
        timestamp: DateTime.now().subtract(
          const Duration(hours: 6),
        ),
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
        scanParameters: ScanParameters.presetFor(
          TargetAnalyte.arsenic,
        ),
        fieldNotes:
            'Pasokan bantuan resmi PMI, kondisi jernih dan netral.',
      ),

      WaterSample(
        id: 'PS-20260829-03',
        locationName: 'Mata Air Bukit Cisarua',
        latitude: -6.8500,
        longitude: 107.6500,
        sourceType: WaterSourceType.spring,
        timestamp: DateTime.now().subtract(
          const Duration(days: 1, hours: 2),
        ),
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
        scanParameters: ScanParameters.presetFor(
          TargetAnalyte.lead,
        ),
        fieldNotes:
            'Sumber air gravitasi warga lereng, layak konsumsi.',
      ),

      WaterSample(
        id: 'PS-20260829-04',
        locationName: 'Genangan Aliran Sungai Citarik',
        latitude: -6.9500,
        longitude: 107.7000,
        sourceType: WaterSourceType.river,
        timestamp: DateTime.now().subtract(
          const Duration(days: 1, hours: 8),
        ),
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
        scanParameters: ScanParameters.presetFor(
          TargetAnalyte.mercury,
        ),
        fieldNotes:
            'Dicurigai tercemar limbah penambangan/industri hulu.',
      ),
    ]);
  }

  // ============================================================
  // FIRESTORE - SAVE
  // ============================================================

  /// Save a water sample to Firestore.
  ///
  /// The document ID is the WaterSample ID.
  Future<void> saveSample(WaterSample sample) async {
    await _firestore
        .collection(_collectionName)
        .doc(sample.id)
        .set(sample.toMap());

    // Update local cache after Firestore succeeds.
    _samples.removeWhere(
      (existing) => existing.id == sample.id,
    );

    _samples.insert(0, sample);
  }

  // ============================================================
  // FIRESTORE - STREAM (REAL-TIME)
  // ============================================================

  /// Real-time stream of all water samples from Firestore, ordered newest first.
  ///
  /// Synchronizes the internal [_samples] cache on each emission.
  Stream<List<WaterSample>> get samplesStream {
    return _firestore
        .collection(_collectionName)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      final samples = snapshot.docs.map((doc) {
        return WaterSample.fromMap(
          doc.id,
          doc.data(),
        );
      }).toList();

      // Update local cache
      _samples
        ..clear()
        ..addAll(samples);

      return List.unmodifiable(_samples);
    });
  }

  // ============================================================
  // FIRESTORE - LOAD ALL
  // ============================================================

  /// Load all water samples from Firestore.
  ///
  /// The samples are sorted by timestamp, newest first.
  Future<List<WaterSample>> loadSamplesFromFirestore() async {
    final snapshot = await _firestore
        .collection(_collectionName)
        .orderBy('timestamp', descending: true)
        .get();

    final samples = snapshot.docs.map((doc) {
      return WaterSample.fromMap(
        doc.id,
        doc.data(),
      );
    }).toList();

    // Replace local cache with Firestore data.
    _samples
      ..clear()
      ..addAll(samples);

    return List.unmodifiable(_samples);
  }

  // ============================================================
  // FIRESTORE - LOAD SINGLE SAMPLE
  // ============================================================

  /// Load one water sample from Firestore by ID.
  Future<WaterSample?> getSampleById(String id) async {
    final document = await _firestore
        .collection(_collectionName)
        .doc(id)
        .get();

    if (!document.exists) {
      return null;
    }

    final sample = WaterSample.fromMap(
      document.id,
      document.data()!,
    );

    // Update local cache.
    _samples.removeWhere(
      (existing) => existing.id == sample.id,
    );

    _samples.insert(0, sample);

    return sample;
  }

  // ============================================================
  // FIRESTORE - DELETE
  // ============================================================

  /// Delete a water sample from Firestore and local cache.
  Future<void> deleteSample(String id) async {
    await _firestore
        .collection(_collectionName)
        .doc(id)
        .delete();

    _samples.removeWhere(
      (sample) => sample.id == id,
    );
  }

  // ============================================================
  // SEARCH & FILTER
  // ============================================================

  /// Filter any list of samples by query, safety status, and water source.
  List<WaterSample> filterSamples(
    List<WaterSample> sourceList, {
    String? query,
    WaterSafetyStatus? statusFilter,
    WaterSourceType? sourceFilter,
  }) {
    return sourceList.where((sample) {
      // --------------------------------------------------------
      // TEXT SEARCH
      // --------------------------------------------------------
      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();

        final matchLocation =
            sample.locationName.toLowerCase().contains(q);

        final matchId =
            sample.id.toLowerCase().contains(q);

        final matchNotes =
            (sample.fieldNotes ?? '').toLowerCase().contains(q);

        if (!matchLocation &&
            !matchId &&
            !matchNotes) {
          return false;
        }
      }

      // --------------------------------------------------------
      // SAFETY STATUS FILTER
      // --------------------------------------------------------
      if (statusFilter != null &&
          sample.safetyStatus != statusFilter) {
        return false;
      }

      // --------------------------------------------------------
      // SOURCE FILTER
      // --------------------------------------------------------
      if (sourceFilter != null &&
          sample.sourceType != sourceFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Search samples from the currently loaded local cache.
  List<WaterSample> searchSamples({
    String? query,
    WaterSafetyStatus? statusFilter,
    WaterSourceType? sourceFilter,
  }) {
    return filterSamples(
      _samples,
      query: query,
      statusFilter: statusFilter,
      sourceFilter: sourceFilter,
    );
  }

  // ============================================================
  // CSV EXPORT
  // ============================================================

  /// Generate CSV string for tabular field reports.
  String exportToCSV({List<WaterSample>? customSamples}) {
    final buffer = StringBuffer();
    final targetSamples = customSamples ?? _samples;

    buffer.writeln(
      'Sample_ID,Location,Source_Type,Timestamp,'
      'WQI_Score,Status,Analyte,Measured_mgL,'
      'Threshold_mgL,Exceeded',
    );

    for (final sample in targetSamples) {
      for (final reading in sample.readings) {
        buffer.writeln(
          '${sample.id},'
          '"${sample.locationName}",'
          '${sample.sourceType.name},'
          '${sample.timestamp.toIso8601String()},'
          '${sample.waterQualityIndex.toStringAsFixed(1)},'
          '${sample.safetyStatus.name},'
          '${reading.analyte.name},'
          '${reading.measuredValue.toStringAsFixed(4)},'
          '${reading.thresholdLimit.toStringAsFixed(4)},'
          '${reading.isExceeded}',
        );
      }
    }

    return buffer.toString();
  }

  // ============================================================
  // QR EXPORT
  // ============================================================

  /// Generate concise JSON QR payload for
  /// instant device-to-device field sync.
  String exportSampleToQRPayload(
    WaterSample sample,
  ) {
    final map = {
      'id': sample.id,
      'loc': sample.locationName,
      'src': sample.sourceType.name,
      'ts': sample.timestamp.millisecondsSinceEpoch,
      'wqi': sample.waterQualityIndex.round(),
      'status': sample.safetyStatus.name,
      'analyte': sample.readings.isNotEmpty
          ? sample.readings.first.analyte.symbol
          : 'N/A',
      'conc': sample.readings.isNotEmpty
          ? sample.readings.first.measuredValue
          : 0.0,
      'exceeded': sample.readings.isNotEmpty
          ? sample.readings.first.isExceeded
          : false,
    };

    return jsonEncode(map);
  }
}