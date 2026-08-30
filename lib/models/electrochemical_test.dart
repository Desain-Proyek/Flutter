/// Electrochemical measurement techniques supported by PortaStat
enum ElectrochemicalTechnique {
  cyclicVoltammetry('Cyclic Voltammetry (CV)', 'CV', 'Analisis redoks reversibel & karakterisasi elektroda'),
  differentialPulse('Differential Pulse Voltammetry (DPV)', 'DPV', 'Sensitivitas tinggi untuk deteksi logam berat'),
  squareWave('Square Wave Voltammetry (SWV)', 'SWV', 'Kecepatan tinggi & batas deteksi ppb sangat rendah'),
  chronoamperometry('Chronoamperometry (CA)', 'CA', 'Pengukuran arus vs waktu pada potensial konstan');

  final String fullName;
  final String shortName;
  final String description;

  const ElectrochemicalTechnique(this.fullName, this.shortName, this.description);
}

/// Target analyte / water quality parameter
enum TargetAnalyte {
  lead('Timbal (Pb²⁺)', 'Pb', -0.45, 0.010, 'mg/L', 'Racun saraf, bahaya pada anak & ibu hamil', ElectrochemicalTechnique.differentialPulse),
  arsenic('Arsenik (As³⁺)', 'As', 0.15, 0.010, 'mg/L', 'Karsinogenik kuat, sering ditemukan di air tanah', ElectrochemicalTechnique.squareWave),
  cadmium('Kadmium (Cd²⁺)', 'Cd', -0.65, 0.003, 'mg/L', 'Kerusakan ginjal & tulang dari limbah industri/baterai', ElectrochemicalTechnique.differentialPulse),
  mercury('Merkuri (Hg²⁺)', 'Hg', 0.48, 0.001, 'mg/L', 'Bahaya saraf & organ dalam, limbah tambang rakyat', ElectrochemicalTechnique.squareWave),
  iron('Besi (Fe²⁺/Fe³⁺)', 'Fe', 0.25, 0.300, 'mg/L', 'Penyebab air kuning/keruh, rasa karat, kerak pipa', ElectrochemicalTechnique.cyclicVoltammetry),
  copper('Tembaga (Cu²⁺)', 'Cu', 0.02, 1.000, 'mg/L', 'Iritasi pencernaan & toksisitas hati pada dosis tinggi', ElectrochemicalTechnique.differentialPulse),
  phLevel('pH & Klorin', 'pH', 0.0, 6.5, 'pH', 'Derajat keasaman & daya disinfeksi air', ElectrochemicalTechnique.chronoamperometry),
  custom('Analisis Kustom', 'Custom', 0.0, 0.0, 'μA', 'Eksperimen riset & karakterisasi elektroda umum', ElectrochemicalTechnique.cyclicVoltammetry);

  final String title;
  final String symbol;
  final double typicalRedoxPeakV; // Typical potential for peak in Volts
  final double whoThreshold;      // WHO max permissible limit in mg/L
  final String unit;
  final String healthRisk;
  final ElectrochemicalTechnique defaultTechnique;

  const TargetAnalyte(
    this.title,
    this.symbol,
    this.typicalRedoxPeakV,
    this.whoThreshold,
    this.unit,
    this.healthRisk,
    this.defaultTechnique,
  );
}

/// Parameter configuration for a potentiostat scan
class ScanParameters {
  final ElectrochemicalTechnique technique;
  final TargetAnalyte analyte;
  final double startPotentialV;    // E_start in Volts (e.g. -0.8 V)
  final double endPotentialV;      // E_end in Volts (e.g. +0.6 V)
  final double scanRateMvPerSec;   // Scan rate in mV/s (e.g. 50 mV/s)
  final double stepPotentialMv;    // E_step in mV (e.g. 5 mV)
  final double pulseAmplitudeMv;   // Pulse amplitude for DPV/SWV in mV (e.g. 50 mV)
  final double frequencyHz;        // Frequency for SWV in Hz (e.g. 25 Hz)
  final double quietTimeSec;       // Equilibration / quiet time in seconds
  final double depositionTimeSec;  // Stripping voltammetry pre-concentration time
  final double depositionPotentialV; // Deposition potential (e.g. -1.0 V)

  const ScanParameters({
    required this.technique,
    required this.analyte,
    this.startPotentialV = -0.8,
    this.endPotentialV = 0.6,
    this.scanRateMvPerSec = 50.0,
    this.stepPotentialMv = 5.0,
    this.pulseAmplitudeMv = 50.0,
    this.frequencyHz = 25.0,
    this.quietTimeSec = 2.0,
    this.depositionTimeSec = 15.0,
    this.depositionPotentialV = -1.0,
  });

  /// Generate field preset optimized for emergency field testing
  factory ScanParameters.presetFor(TargetAnalyte analyte) {
    switch (analyte) {
      case TargetAnalyte.lead:
        return const ScanParameters(
          technique: ElectrochemicalTechnique.differentialPulse,
          analyte: TargetAnalyte.lead,
          startPotentialV: -0.80,
          endPotentialV: -0.10,
          scanRateMvPerSec: 40.0,
          stepPotentialMv: 4.0,
          pulseAmplitudeMv: 50.0,
          depositionTimeSec: 20.0,
          depositionPotentialV: -1.0,
        );
      case TargetAnalyte.arsenic:
        return const ScanParameters(
          technique: ElectrochemicalTechnique.squareWave,
          analyte: TargetAnalyte.arsenic,
          startPotentialV: -0.20,
          endPotentialV: 0.50,
          frequencyHz: 30.0,
          stepPotentialMv: 5.0,
          pulseAmplitudeMv: 60.0,
          depositionTimeSec: 25.0,
          depositionPotentialV: -0.5,
        );
      case TargetAnalyte.cadmium:
        return const ScanParameters(
          technique: ElectrochemicalTechnique.differentialPulse,
          analyte: TargetAnalyte.cadmium,
          startPotentialV: -0.95,
          endPotentialV: -0.35,
          scanRateMvPerSec: 50.0,
          stepPotentialMv: 5.0,
          pulseAmplitudeMv: 50.0,
          depositionTimeSec: 15.0,
          depositionPotentialV: -1.1,
        );
      case TargetAnalyte.mercury:
        return const ScanParameters(
          technique: ElectrochemicalTechnique.squareWave,
          analyte: TargetAnalyte.mercury,
          startPotentialV: 0.10,
          endPotentialV: 0.80,
          frequencyHz: 25.0,
          stepPotentialMv: 5.0,
          pulseAmplitudeMv: 50.0,
          depositionTimeSec: 20.0,
          depositionPotentialV: 0.0,
        );
      case TargetAnalyte.iron:
        return const ScanParameters(
          technique: ElectrochemicalTechnique.cyclicVoltammetry,
          analyte: TargetAnalyte.iron,
          startPotentialV: -0.30,
          endPotentialV: 0.80,
          scanRateMvPerSec: 100.0,
          stepPotentialMv: 5.0,
        );
      case TargetAnalyte.copper:
        return const ScanParameters(
          technique: ElectrochemicalTechnique.differentialPulse,
          analyte: TargetAnalyte.copper,
          startPotentialV: -0.30,
          endPotentialV: 0.40,
          scanRateMvPerSec: 50.0,
          stepPotentialMv: 5.0,
          pulseAmplitudeMv: 40.0,
        );
      case TargetAnalyte.phLevel:
        return const ScanParameters(
          technique: ElectrochemicalTechnique.chronoamperometry,
          analyte: TargetAnalyte.phLevel,
          startPotentialV: 0.0,
          endPotentialV: 0.0,
          scanRateMvPerSec: 0.0,
          quietTimeSec: 5.0,
        );
      case TargetAnalyte.custom:
        return const ScanParameters(
          technique: ElectrochemicalTechnique.cyclicVoltammetry,
          analyte: TargetAnalyte.custom,
          startPotentialV: -0.80,
          endPotentialV: 0.80,
          scanRateMvPerSec: 100.0,
          stepPotentialMv: 10.0,
        );
    }
  }

  ScanParameters copyWith({
    ElectrochemicalTechnique? technique,
    TargetAnalyte? analyte,
    double? startPotentialV,
    double? endPotentialV,
    double? scanRateMvPerSec,
    double? stepPotentialMv,
    double? pulseAmplitudeMv,
    double? frequencyHz,
    double? quietTimeSec,
    double? depositionTimeSec,
    double? depositionPotentialV,
  }) {
    return ScanParameters(
      technique: technique ?? this.technique,
      analyte: analyte ?? this.analyte,
      startPotentialV: startPotentialV ?? this.startPotentialV,
      endPotentialV: endPotentialV ?? this.endPotentialV,
      scanRateMvPerSec: scanRateMvPerSec ?? this.scanRateMvPerSec,
      stepPotentialMv: stepPotentialMv ?? this.stepPotentialMv,
      pulseAmplitudeMv: pulseAmplitudeMv ?? this.pulseAmplitudeMv,
      frequencyHz: frequencyHz ?? this.frequencyHz,
      quietTimeSec: quietTimeSec ?? this.quietTimeSec,
      depositionTimeSec: depositionTimeSec ?? this.depositionTimeSec,
      depositionPotentialV: depositionPotentialV ?? this.depositionPotentialV,
    );
  }
}

/// A single data point recorded during an electrochemical run
class VoltammogramPoint {
  final double potentialV;     // Applied potential (V vs Reference)
  final double currentMicroA;   // Measured current in microamperes (μA)
  final double timestampSec;   // Time elapsed from scan start (s)
  final int cycleIndex;        // Cycle number for multi-cycle CV

  const VoltammogramPoint({
    required this.potentialV,
    required this.currentMicroA,
    required this.timestampSec,
    this.cycleIndex = 1,
  });

  Map<String, dynamic> toMap() => {
    'potential_v': potentialV,
    'current_ua': currentMicroA,
    'timestamp_s': timestampSec,
    'cycle': cycleIndex,
  };
}

/// Detected redox peak from voltammogram analysis
class DetectedPeak {
  final double potentialV;      // Peak potential Ep (V)
  final double peakCurrentMicroA; // Peak current Ip (μA)
  final double baselineMicroA;  // Baseline current at Ep (μA)
  final double netHeightMicroA; // Net peak height (Ip - I_baseline)
  final TargetAnalyte? matchedAnalyte;
  final double estimatedConcentrationMgL; // Estimated concentration in mg/L

  const DetectedPeak({
    required this.potentialV,
    required this.peakCurrentMicroA,
    required this.baselineMicroA,
    required this.netHeightMicroA,
    this.matchedAnalyte,
    required this.estimatedConcentrationMgL,
  });
}
