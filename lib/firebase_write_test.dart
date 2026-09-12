import 'models/water_sample.dart';
import 'models/electrochemical_test.dart';
import 'services/storage_service.dart';

Future<void> testFirestoreWrite() async {
  final storageService = StorageService();

  final testSample = WaterSample.sampleMock(
    id: 'TEST-FIREBASE-001',
    location: 'Firebase Test Location',
    source: WaterSourceType.well,
    status: WaterSafetyStatus.safe,
    wqi: 95.0,
    analyte: TargetAnalyte.lead,
    conc: 0.005,
  );

  try {
    await storageService.saveSample(testSample);

    print('====================================');
    print('FIRESTORE WRITE BERHASIL');
    print('====================================');
    print('ID          : ${testSample.id}');
    print('Location    : ${testSample.locationName}');
    print('WQI         : ${testSample.waterQualityIndex}');
    print('Status      : ${testSample.safetyStatus.name}');
    print('====================================');
  } catch (e) {
    print('====================================');
    print('FIRESTORE WRITE GAGAL');
    print('====================================');
    print('Error: $e');
    print('====================================');
  }
}