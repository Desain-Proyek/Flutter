import 'dart:async';
import 'dart:math';
import '../models/electrochemical_test.dart';
import '../models/device_status.dart';

/// Status of an active potentiostat run
enum ScanExecutionState {
  idle,
  deposition, // Pre-concentration / stripping phase
  equilibration, // Quiet time
  scanning,   // Potential sweep in progress
  completed,
  aborted,
}

/// Potentiostat hardware controller and electrochemical simulation engine
class PotentiostatService {
  static final PotentiostatService _instance = PotentiostatService._internal();
  factory PotentiostatService() => _instance;
  PotentiostatService._internal();

  DeviceStatus _deviceStatus = const DeviceStatus();
  DeviceStatus get deviceStatus => _deviceStatus;

  ScanExecutionState _executionState = ScanExecutionState.idle;
  ScanExecutionState get executionState => _executionState;

  final StreamController<DeviceStatus> _deviceStatusController = StreamController<DeviceStatus>.broadcast();
  Stream<DeviceStatus> get deviceStatusStream => _deviceStatusController.stream;

  final StreamController<VoltammogramPoint> _liveDataController = StreamController<VoltammogramPoint>.broadcast();
  Stream<VoltammogramPoint> get liveDataStream => _liveDataController.stream;

  final StreamController<ScanExecutionState> _stateController = StreamController<ScanExecutionState>.broadcast();
  Stream<ScanExecutionState> get stateStream => _stateController.stream;

  final StreamController<double> _progressController = StreamController<double>.broadcast();
  Stream<double> get progressStream => _progressController.stream;

  Timer? _scanTimer;
  final List<VoltammogramPoint> _currentScanPoints = [];
  List<VoltammogramPoint> get currentScanPoints => List.unmodifiable(_currentScanPoints);

  ScanParameters _activeParams = ScanParameters.presetFor(TargetAnalyte.lead);
  ScanParameters get activeParams => _activeParams;

  // Simulator noise and baseline randomizer
  final Random _rng = Random(42);

  void setDeviceConnection(HardwareConnectionState state) {
    _deviceStatus = _deviceStatus.copyWith(connectionState: state);
    _deviceStatusController.add(_deviceStatus);
  }

  void startScan(ScanParameters params, {double simulatedContaminantConcentration = 0.045}) {
    if (_executionState == ScanExecutionState.scanning || _executionState == ScanExecutionState.deposition) {
      return;
    }

    _activeParams = params;
    _currentScanPoints.clear();
    _scanTimer?.cancel();

    // Step 1: Deposition phase if applicable (DPV/SWV Stripping Voltammetry)
    if (params.depositionTimeSec > 0 && 
        (params.technique == ElectrochemicalTechnique.differentialPulse || 
         params.technique == ElectrochemicalTechnique.squareWave)) {
      _setExecutionState(ScanExecutionState.deposition);
      double depositionElapsed = 0;
      const stepMs = 100;
      
      _scanTimer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) {
        depositionElapsed += stepMs / 1000.0;
        final progress = (depositionElapsed / params.depositionTimeSec).clamp(0.0, 1.0);
        _progressController.add(progress * 0.25); // First 25% of overall progress

        if (depositionElapsed >= params.depositionTimeSec) {
          timer.cancel();
          _startPotentialSweep(params, simulatedContaminantConcentration);
        }
      });
    } else {
      _startPotentialSweep(params, simulatedContaminantConcentration);
    }
  }

  void _startPotentialSweep(ScanParameters params, double concentration) {
    _setExecutionState(ScanExecutionState.scanning);

    final double eStart = params.startPotentialV;
    final double eEnd = params.endPotentialV;
    final double stepV = (params.stepPotentialMv / 1000.0).abs() * (eEnd > eStart ? 1.0 : -1.0);
    final double scanRateVPerSec = (params.scanRateMvPerSec <= 0 ? 50.0 : params.scanRateMvPerSec) / 1000.0;
    
    // Interval between data points in milliseconds
    final int intervalMs = ((stepV.abs() / scanRateVPerSec) * 1000).round().clamp(15, 100);

    double currentPotential = eStart;
    bool isForwardSweep = true;
    int cycle = 1;
    double elapsedTime = 0.0;

    _scanTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      elapsedTime += intervalMs / 1000.0;

      // Calculate realistic electrochemical response current (μA)
      final currentMicroA = _calculateSimulatedCurrent(
        technique: params.technique,
        analyte: params.analyte,
        potential: currentPotential,
        time: elapsedTime,
        concentration: concentration,
        isForward: isForwardSweep,
      );

      final point = VoltammogramPoint(
        potentialV: currentPotential,
        currentMicroA: currentMicroA,
        timestampSec: elapsedTime,
        cycleIndex: cycle,
      );

      _currentScanPoints.add(point);
      _liveDataController.add(point);

      // Sweep progress & bounds
      if (params.technique == ElectrochemicalTechnique.cyclicVoltammetry) {
        // Multi-directional sweep for CV
        if (isForwardSweep) {
          currentPotential += stepV;
          if ((stepV > 0 && currentPotential >= eEnd) || (stepV < 0 && currentPotential <= eEnd)) {
            isForwardSweep = false;
          }
        } else {
          currentPotential -= stepV;
          if ((stepV > 0 && currentPotential <= eStart) || (stepV < 0 && currentPotential >= eStart)) {
            // Completed 1 full cycle
            timer.cancel();
            _completeScan();
            return;
          }
        }
      } else if (params.technique == ElectrochemicalTechnique.chronoamperometry) {
        // Constant potential vs time
        if (elapsedTime >= 15.0) {
          timer.cancel();
          _completeScan();
          return;
        }
      } else {
        // Linear / Stripping sweep (DPV / SWV)
        currentPotential += stepV;
        if ((stepV > 0 && currentPotential >= eEnd) || (stepV < 0 && currentPotential <= eEnd)) {
          timer.cancel();
          _completeScan();
          return;
        }
      }

      // Compute total progress
      final double sweepProgress = ((currentPotential - eStart) / (eEnd - eStart)).abs().clamp(0.0, 1.0);
      _progressController.add(0.25 + (sweepProgress * 0.75));
    });
  }

  /// Accurate electrochemical physics simulator (Gaussian peak + capacitive baseline + Cottrell decay)
  double _calculateSimulatedCurrent({
    required ElectrochemicalTechnique technique,
    required TargetAnalyte analyte,
    required double potential,
    required double time,
    required double concentration, // in mg/L
    required bool isForward,
  }) {
    // 1. Base capacitive charging current / background linear slope
    final double baseline = 0.5 + (0.2 * potential) + ((_rng.nextDouble() - 0.5) * 0.05);

    switch (technique) {
      case ElectrochemicalTechnique.differentialPulse:
      case ElectrochemicalTechnique.squareWave:
        // Stripping voltammetry: Sharp Gaussian Peak at target redox potential
        final double peakPotential = analyte.typicalRedoxPeakV;
        final double peakWidth = (technique == ElectrochemicalTechnique.squareWave) ? 0.06 : 0.08;
        
        // Calibration slope: 1.0 mg/L -> ~80 μA peak
        final double peakHeight = (concentration * 120.0).clamp(0.1, 150.0);
        
        final double deltaE = potential - peakPotential;
        final double gaussian = peakHeight * exp(-(deltaE * deltaE) / (2 * peakWidth * peakWidth));

        final double secondaryPeak = 1.2 * exp(-pow(potential - 0.25, 2) / 0.02);

        return baseline + gaussian + secondaryPeak;

      case ElectrochemicalTechnique.cyclicVoltammetry:
        // Classic Duck-shaped CV curve (Randles-Sevcik anodic & cathodic diffusion couple)
        final double eAnodic = analyte.typicalRedoxPeakV + 0.03;
        final double eCathodic = analyte.typicalRedoxPeakV - 0.03;
        final double ip = (concentration * 60.0).clamp(2.0, 80.0);

        double redoxCurrent = 0.0;
        if (isForward) {
          // Anodic oxidation wave with diffusion tail
          if (potential < eAnodic) {
            redoxCurrent = ip / (1.0 + exp(-(potential - eAnodic) / 0.035));
          } else {
            redoxCurrent = ip / sqrt(1.0 + ((potential - eAnodic) / 0.04));
          }
        } else {
          // Cathodic reduction wave (negative current)
          if (potential > eCathodic) {
            redoxCurrent = -ip / (1.0 + exp((potential - eCathodic) / 0.035));
          } else {
            redoxCurrent = -ip / sqrt(1.0 + ((eCathodic - potential) / 0.04));
          }
        }
        return baseline + redoxCurrent;

      case ElectrochemicalTechnique.chronoamperometry:
        // Cottrell equation decay
        final double cottrell = (concentration * 40.0) / sqrt(max(0.2, time));
        return cottrell + (0.3 * exp(-time / 2.0)) + ((_rng.nextDouble() - 0.5) * 0.03);
    }
  }

  void stopScan() {
    _scanTimer?.cancel();
    _setExecutionState(ScanExecutionState.aborted);
  }

  void _completeScan() {
    _progressController.add(1.0);
    _setExecutionState(ScanExecutionState.completed);
  }

  void _setExecutionState(ScanExecutionState state) {
    _executionState = state;
    _stateController.add(_executionState);
  }

  void calibrateDummyCell() {
    _deviceStatus = _deviceStatus.copyWith(
      isDummyCellCalibrated: true,
      electrodeWearPercent: 5.0,
      boardTemperatureC: 28.5,
    );
    _deviceStatusController.add(_deviceStatus);
  }

  void dispose() {
    _scanTimer?.cancel();
    _deviceStatusController.close();
    _liveDataController.close();
    _stateController.close();
    _progressController.close();
  }
}
