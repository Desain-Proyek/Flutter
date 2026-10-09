import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  Stream<List<WaterSample>> get samplesStream async* {
    var user = FirebaseAuth.instance.currentUser;
    debugPrint(
      'FirebaseAuth.instance.currentUser when stream starts: '
      '${user != null ? "uid=${user.uid}" : "null (NOT signed in)"}',
    );

    if (user == null) {
      debugPrint('[StorageService] User is not signed in when stream starts. Signing in anonymously...');
      try {
        final cred = await FirebaseAuth.instance.signInAnonymously();
        user = cred.user;
        debugPrint('[StorageService] Successfully signed in anonymously: uid=${user?.uid}');
      } catch (e) {
        debugPrint('[StorageService] Anonymous sign-in attempt failed: $e');
      }
    }

    yield* _firestore
        .collection(_collectionName)
        .orderBy('timestamp', descending: true)
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) {
          debugPrint(
            'snapshot.docs.length: ${snapshot.docs.length}, '
            'snapshot.metadata.isFromCache: ${snapshot.metadata.isFromCache}, '
            'snapshot.metadata.hasPendingWrites: ${snapshot.metadata.hasPendingWrites}',
          );

          if (snapshot.metadata.isFromCache && snapshot.docs.isEmpty) {
            debugPrint(
              'Ignoring snapshot where isFromCache && docs.isEmpty '
              'so local cache is not wiped.',
            );
            return false;
          }
          return true;
        })
        .map<List<WaterSample>>((snapshot) {
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

          return List<WaterSample>.unmodifiable(_samples);
        })
        .handleError((e) {
          debugPrint('Firestore stream error: $e');
          throw e;
        });
  }

  // ============================================================
  // FIRESTORE - LOAD ALL
  // ============================================================

  /// Load all water samples from Firestore.
  ///
  /// The samples are sorted by timestamp, newest first.
  Future<List<WaterSample>> loadSamplesFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint(
      'FirebaseAuth.instance.currentUser before loadSamplesFromFirestore: '
      '${user != null ? "uid=${user.uid}" : "null (NOT signed in)"}',
    );

    if (user == null) {
      debugPrint('[StorageService] User is not signed in before loadSamplesFromFirestore. Signing in anonymously...');
      try {
        final cred = await FirebaseAuth.instance.signInAnonymously();
        debugPrint('[StorageService] Successfully signed in anonymously: uid=${cred.user?.uid}');
      } catch (e) {
        debugPrint('[StorageService] Anonymous sign-in attempt failed: $e');
      }
    }

    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .orderBy('timestamp', descending: true)
          .get();

      debugPrint(
        'snapshot.docs.length: ${snapshot.docs.length}, '
        'snapshot.metadata.isFromCache: ${snapshot.metadata.isFromCache}, '
        'snapshot.metadata.hasPendingWrites: ${snapshot.metadata.hasPendingWrites}',
      );

      if (snapshot.metadata.isFromCache && snapshot.docs.isEmpty) {
        debugPrint(
          'Ignoring get snapshot where isFromCache && docs.isEmpty '
          'so local cache is not wiped.',
        );
        return List.unmodifiable(_samples);
      }

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
    } catch (e) {
      debugPrint('Firestore get error: $e');
      return List.unmodifiable(_samples);
    }
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
      if (sample.readings.isEmpty) {
        buffer.writeln(
          '${sample.id},'
          '"${sample.locationName}",'
          '${sample.sourceType.name},'
          '${sample.timestamp.toIso8601String()},'
          '${sample.waterQualityIndex.toStringAsFixed(1)},'
          '${sample.safetyStatus.name},'
          '${sample.scanParameters.analyte.name},'
          '0.0000,'
          '0.0000,'
          'false',
        );
      } else {
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
    }

    return buffer.toString();
  }

  /// Get user's Downloads directory across platforms with fallback.
  Future<Directory> getDownloadsDirectory() async {
    String dirPath;
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        dirPath = '$userProfile\\Downloads';
      } else {
        dirPath = Directory.current.path;
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        dirPath = '$home/Downloads';
      } else {
        dirPath = Directory.current.path;
      }
    } else {
      dirPath = Directory.current.path;
    }

    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Export samples to a CSV file and save it directly to the Downloads folder.
  Future<File> exportAndSaveCSV({
    List<WaterSample>? customSamples,
    String? fileName,
  }) async {
    final content = exportToCSV(customSamples: customSamples);
    final dir = await getDownloadsDirectory();

    String finalFileName;
    if (fileName != null && fileName.trim().isNotEmpty) {
      var sanitized = fileName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      if (!sanitized.toLowerCase().endsWith('.csv')) {
        sanitized = '$sanitized.csv';
      }
      finalFileName = sanitized;
    } else {
      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      finalFileName = 'Catatan_Lapangan_$dateStr.csv';
    }

    final filePath = '${dir.path}${Platform.pathSeparator}$finalFileName';
    final file = File(filePath);
    await file.writeAsString(content, flush: true);
    return file;
  }

  /// Open file location in File Explorer / Finder and highlight the file.
  static Future<void> openFileLocation(String filePath) async {
    try {
      final file = File(filePath);
      final exists = await file.exists();
      final cleanPath = filePath.replaceAll('/', '\\');

      if (Platform.isWindows) {
        if (exists) {
          await Process.run('explorer.exe', ['/select,', cleanPath]);
        } else {
          final parentDir = file.parent.path.replaceAll('/', '\\');
          await Process.run('explorer.exe', [parentDir]);
        }
      } else if (Platform.isMacOS) {
        if (exists) {
          await Process.run('open', ['-R', filePath]);
        } else {
          await Process.run('open', [file.parent.path]);
        }
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [file.parent.path]);
      }
    } catch (e) {
      debugPrint('Gagal membuka lokasi file: $e');
    }
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