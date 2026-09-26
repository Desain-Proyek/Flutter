import 'dart:async';
import 'package:flutter/material.dart';
import '../models/electrochemical_test.dart';
import '../models/water_sample.dart';
import '../models/device_status.dart';
import '../services/potentiostat_service.dart';
import '../services/water_analyzer_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../widgets/live_voltammogram_chart.dart';
import '../widgets/connection_badge.dart';
import '../widgets/field_parameter_card.dart';
import 'analysis_report_screen.dart';

class LiveMeasurementScreen extends StatefulWidget {
  final ScanParameters? initialParameters;
  final bool autoStart;

  const LiveMeasurementScreen({
    super.key,
    this.initialParameters,
    this.autoStart = false,
  });

  @override
  State<LiveMeasurementScreen> createState() => _LiveMeasurementScreenState();
}

class _LiveMeasurementScreenState extends State<LiveMeasurementScreen> {
  final PotentiostatService _potentiostatService = PotentiostatService();
  final WaterAnalyzerService _analyzerService = WaterAnalyzerService();
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();

  late ScanParameters _parameters;
  final TextEditingController _locationController = TextEditingController(text: 'Posko Pengungsian 01');
  WaterSourceType _selectedSource = WaterSourceType.well;

  bool _showBaseline = true;
  final double _simulatedContaminantLevel = 0.042; // default simulated concentration in mg/L

  StreamSubscription? _stateSub;
  StreamSubscription? _liveDataSub;
  final List<VoltammogramPoint> _livePoints = [];
  List<DetectedPeak> _detectedPeaks = [];

  ScanExecutionState _currentState = ScanExecutionState.idle;
  double _scanProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _parameters = widget.initialParameters ?? ScanParameters.presetFor(TargetAnalyte.lead);

    _currentState = _potentiostatService.executionState;
    _livePoints.addAll(_potentiostatService.currentScanPoints);

    _stateSub = _potentiostatService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
          if (state == ScanExecutionState.completed) {
            _analyzeFinishedScan();
          }
        });
      }
    });

    _liveDataSub = _potentiostatService.liveDataStream.listen((point) {
      if (mounted) {
        setState(() {
          _livePoints.add(point);
          // Live peak detection updates periodically
          if (_livePoints.length % 8 == 0) {
            _detectedPeaks = _analyzerService.detectPeaks(
              points: _livePoints,
              params: _parameters,
            );
          }
        });
      }
    });

    _potentiostatService.progressStream.listen((progress) {
      if (mounted) {
        setState(() => _scanProgress = progress);
      }
    });

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleStartScan();
      });
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _liveDataSub?.cancel();
    _locationController.dispose();
    super.dispose();
  }

  void _handleStartScan() {
    setState(() {
      _livePoints.clear();
      _detectedPeaks.clear();
      _scanProgress = 0.0;
    });

    _potentiostatService.startScan(
      _parameters,
      simulatedContaminantConcentration: _simulatedContaminantLevel,
    );
  }

  void _handleStopScan() {
    _potentiostatService.stopScan();
  }

  void _analyzeFinishedScan() {
    _detectedPeaks = _analyzerService.detectPeaks(
      points: _livePoints,
      params: _parameters,
    );

    final sample = _analyzerService.buildSampleResult(
      locationName: _locationController.text.trim().isEmpty
          ? 'Titik Lapangan #${DateTime.now().millisecond}'
          : _locationController.text.trim(),
      sourceType: _selectedSource,
      params: _parameters,
      points: List.of(_livePoints),
      simulatedOverrideConc: _simulatedContaminantLevel,
      operatorName: _authService.operatorDisplayName,
      operatorId: _authService.operatorId,
      operatorEmail: _authService.operatorEmail,
    );

    _storageService.saveSample(sample);

    // Show completion snackbar with action
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pengujian ${_parameters.analyte.title} Selesai!'),
        action: SnackBarAction(
          label: 'Buka Laporan',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AnalysisReportScreen(sample: sample)),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isScanning = _currentState == ScanExecutionState.scanning ||
        _currentState == ScanExecutionState.deposition;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uji Elektrokimia PortaStat',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_parameters.technique.shortName} • ${_parameters.analyte.title}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          StreamBuilder<DeviceStatus>(
            stream: _potentiostatService.deviceStatusStream,
            initialData: _potentiostatService.deviceStatus,
            builder: (context, snapshot) {
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: ConnectionBadge(status: snapshot.data ?? const DeviceStatus()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sample Info bar (Location & Source)
            _buildSampleMetadataCard(isDark, isScanning),
            const SizedBox(height: 12),

            // Live Voltammogram Chart Screen
            _buildChartSection(isDark, isScanning),
            const SizedBox(height: 12),

            // Live Scan Progress & State Indicator
            if (isScanning || _currentState == ScanExecutionState.completed)
              _buildProgressCard(isDark),
            if (isScanning || _currentState == ScanExecutionState.completed)
              const SizedBox(height: 12),

            // Live Peak Results Summary
            if (_detectedPeaks.isNotEmpty)
              _buildLivePeaksCard(isDark),
            if (_detectedPeaks.isNotEmpty)
              const SizedBox(height: 12),

            // Preset & Parameter controls
            FieldParameterCard(
              parameters: _parameters,
              onParametersChanged: (newParams) {
                setState(() => _parameters = newParams);
              },
              isScanning: isScanning,
            ),
            const SizedBox(height: 14),

            // Analyte Preset Selector Row
            _buildAnalyteSelector(isDark, isScanning),
            const SizedBox(height: 20),

            // Action Buttons Bar
            _buildActionControlButtons(isScanning),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleMetadataCard(bool isDark, bool isScanning) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    enabled: !isScanning,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Nama Lokasi / Titik Sampel Air...',
                      hintStyle: TextStyle(fontSize: 13),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tipe Sumber Air:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                DropdownButton<WaterSourceType>(
                  value: _selectedSource,
                  isDense: true,
                  underline: const SizedBox(),
                  onChanged: isScanning
                      ? null
                      : (val) {
                          if (val != null) setState(() => _selectedSource = val);
                        },
                  items: WaterSourceType.values.map((src) {
                    return DropdownMenuItem(
                      value: src,
                      child: Text(src.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(bool isDark, bool isScanning) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isScanning ? const Color(0xFF10B981) : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Voltammogram I-V Real-Time',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Baseline',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                    Switch(
                      value: _showBaseline,
                      onChanged: (v) => setState(() => _showBaseline = v),
                      activeThumbColor: const Color(0xFF0284C7),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Custom Canvas Chart
            SizedBox(
              height: 260,
              width: double.infinity,
              child: LiveVoltammogramChart(
                points: _livePoints,
                detectedPeaks: _detectedPeaks,
                technique: _parameters.technique,
                showBaseline: _showBaseline,
                isScanning: isScanning,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '💡 Tips: Sentuh dan geser jari pada grafik untuk inspeksi nilai potensial (V) & arus (μA).',
              style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white54 : Colors.black45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(bool isDark) {
    String stateLabel = 'Menyiapkan...';
    Color stateColor = const Color(0xFF0284C7);

    switch (_currentState) {
      case ScanExecutionState.deposition:
        stateLabel = 'Tahap Deposisi / Stripping (${_parameters.depositionTimeSec.toStringAsFixed(0)}s)...';
        stateColor = const Color(0xFFD97706);
        break;
      case ScanExecutionState.scanning:
        stateLabel = 'Menyapu Potensial (${_parameters.startPotentialV}V ➔ ${_parameters.endPotentialV}V)...';
        stateColor = const Color(0xFF10B981);
        break;
      case ScanExecutionState.completed:
        stateLabel = 'Pengujian Selesai - Analisis Puncak Siap';
        stateColor = const Color(0xFF059669);
        break;
      case ScanExecutionState.aborted:
        stateLabel = 'Pengujian Dibatalkan';
        stateColor = const Color(0xFFEF4444);
        break;
      default:
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: stateColor.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: stateColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                stateLabel,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: stateColor),
              ),
              Text(
                '${(_scanProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: stateColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: _scanProgress,
            backgroundColor: stateColor.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(stateColor),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePeaksCard(bool isDark) {
    return Card(
      elevation: 0,
      color: const Color(0xFFE11D48).withValues(alpha: isDark ? 0.12 : 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: const Color(0xFFE11D48).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics_rounded, color: Color(0xFFE11D48), size: 18),
                SizedBox(width: 8),
                Text(
                  'Deteksi Puncak Redoks Elektrokimia:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFE11D48)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._detectedPeaks.map((peak) {
              final analyte = peak.matchedAnalyte ?? _parameters.analyte;
              final isExceeded = peak.estimatedConcentrationMgL > analyte.whoThreshold;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${analyte.title} (Ep: ${peak.potentialV.toStringAsFixed(2)} V)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        Text(
                          'Tinggi Arus Net: ${peak.netHeightMicroA.toStringAsFixed(2)} μA',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isExceeded ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${peak.estimatedConcentrationMgL.toStringAsFixed(4)} mg/L',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyteSelector(bool isDark, bool isScanning) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Target Analit / Kontaminan:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: TargetAnalyte.values.map((analyte) {
            final isSelected = _parameters.analyte == analyte;
            return ChoiceChip(
              label: Text(analyte.title),
              selected: isSelected,
              onSelected: isScanning
                  ? null
                  : (selected) {
                      if (selected) {
                        setState(() {
                          _parameters = ScanParameters.presetFor(analyte);
                        });
                      }
                    },
              selectedColor: const Color(0xFF0284C7),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionControlButtons(bool isScanning) {
    if (isScanning) {
      return FilledButton.icon(
        onPressed: _handleStopScan,
        icon: const Icon(Icons.stop_circle_outlined, size: 22),
        label: const Text('Hentikan Pengujian', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFEF4444),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }

    if (_currentState == ScanExecutionState.completed && _livePoints.isNotEmpty) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _handleStartScan,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Uji Ulang'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () {
                final latestSample = _storageService.allSamples.first;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AnalysisReportScreen(sample: latestSample)),
                );
              },
              icon: const Icon(Icons.assignment_turned_in_rounded),
              label: const Text('Lihat Laporan & Mitigasi'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    }

    return FilledButton.icon(
      onPressed: _handleStartScan,
      icon: const Icon(Icons.play_arrow_rounded, size: 24),
      label: Text(
        'Mulai Uji Elektrokimia (${_parameters.analyte.symbol})',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF0284C7),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
