import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/electrochemical_test.dart';
import '../models/water_sample.dart';
import '../models/device_status.dart';
import '../services/alert_service.dart';
import '../services/location_service.dart';
import '../services/potentiostat_service.dart';
import '../services/storage_service.dart';
import '../widgets/water_quality_gauge.dart';
import '../widgets/connection_badge.dart';
import '../widgets/offline_indicator_badge.dart';
import 'live_measurement_screen.dart';
import 'analysis_report_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const HomeDashboardScreen({super.key, required this.onNavigateTab});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final PotentiostatService _potentiostatService = PotentiostatService();
  final StorageService _storageService = StorageService();

  Position? _currentPosition;

  // In-memory set of dismissed danger alert sample IDs for the current session.
  // Accepted limitation: dismissed alerts do not persist across app restarts.
  final Set<String> _dismissedAlertIds = {};

  @override
  void initState() {
    super.initState();
    _storageService.lastSyncError.addListener(_onSyncError);
    _fetchDevicePosition();
  }

  Future<void> _fetchDevicePosition() async {
    final position = await LocationService().getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = position;
      });
    }
  }

  @override
  void dispose() {
    _storageService.lastSyncError.removeListener(_onSyncError);
    super.dispose();
  }

  void _onSyncError() {
    final err = _storageService.lastSyncError.value;
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.red,
        ),
      );
      _storageService.lastSyncError.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<List<WaterSample>>(
      stream: _storageService.samplesStream,
      initialData: _storageService.allSamples,
      builder: (context, snapshot) {
        final samples = snapshot.data ?? [];

        final origin = _currentPosition != null
            ? (lat: _currentPosition!.latitude, lng: _currentPosition!.longitude)
            : null;

        final alerts = selectAlerts(
          samples,
          now: DateTime.now(),
          origin: origin,
          dismissedIds: _dismissedAlertIds,
        );

        // Calculate average WQI
        final double avgWqi = samples.isNotEmpty
            ? samples.map((s) => s.waterQualityIndex).reduce((a, b) => a + b) / samples.length
            : 85.0;

        final WaterSafetyStatus overallStatus = avgWqi > 75
            ? WaterSafetyStatus.safe
            : (avgWqi > 50 ? WaterSafetyStatus.moderate : WaterSafetyStatus.danger);

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PortaStat',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
                    ),
                    Text(
                      'Deteksi Kualitas Air Bencana',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              const OfflineIndicatorBadge(compact: true),
              const SizedBox(width: 8),
              StreamBuilder<DeviceStatus>(
                stream: _potentiostatService.deviceStatusStream,
                initialData: _potentiostatService.deviceStatus,
                builder: (context, snapshot) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 14.0),
                    child: ConnectionBadge(status: snapshot.data ?? const DeviceStatus()),
                  );
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              final loadFuture = _storageService.loadSamplesFromFirestore();
              final posFuture = LocationService().getCurrentPosition();
              final results = await Future.wait([loadFuture, posFuture]);
              if (mounted) {
                setState(() {
                  _currentPosition = results[1] as Position?;
                });
              }
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Danger alert banner (when alerts exist)
                  if (alerts.isNotEmpty) ...[
                    _buildDangerAlertBanner(alerts, origin, isDark),
                    const SizedBox(height: 18),
                  ],

                  // Emergency disaster banner
                  _buildDisasterStatusBanner(isDark),
                  const SizedBox(height: 18),

                  // Overall Water Quality Card
                  _buildOverallGaugeCard(avgWqi, overallStatus, samples.length, isDark),
                  const SizedBox(height: 22),

                  // Rapid Field Test Shortcuts (1-Tap Test) - Sementara di-comment
                  /*
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Uji Cepat Lapangan (1-Sentuhan)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => widget.onNavigateTab(1), // Go to Measurement tab
                        child: const Text('Mode Ahli (CV/DPV)', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildQuickTestGrid(context),
                  const SizedBox(height: 24),
                  */

                  // Offline Status Banner
                  const OfflineStatusBar(),

                  // Recent Field Test Logs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Riwayat Uji Sumber Air Terkini',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => widget.onNavigateTab(2), // Go to Field Log tab
                        child: const Text('Lihat Semua', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildRecentTestsList(samples, isDark),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDangerAlertBanner(
    List<WaterSample> alerts,
    ({double lat, double lng})? origin,
    bool isDark,
  ) {
    final primaryAlert = alerts.first;
    final now = DateTime.now();

    ContaminantReading? exceededReading;
    for (final reading in primaryAlert.readings) {
      if (reading.isExceeded) {
        exceededReading = reading;
        break;
      }
    }

    final timeAgo = formatTimeAgo(primaryAlert.timestamp, now: now);
    final distanceText = formatAlertDistance(origin, primaryAlert);
    final otherCount = alerts.length - 1;

    final otherAlertsText = otherCount > 0 ? ', dan $otherCount titik lain' : '';
    final semanticLabel = 'Peringatan: air tercemar terdeteksi di '
        '${primaryAlert.locationName.isNotEmpty ? primaryAlert.locationName : "sumber air"}'
        '$otherAlertsText. Ketuk untuk membuka laporan analisis.';

    return Semantics(
      label: semanticLabel,
      button: true,
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.6 : 0.4),
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnalysisReportScreen(sample: primaryAlert),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 14, top: 10, right: 6, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFDC2626),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Peringatan: air tercemar terdeteksi',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (otherCount > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '+$otherCount titik lain',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'Tutup peringatan',
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        padding: const EdgeInsets.all(12),
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        onPressed: () {
                          setState(() {
                            // In-memory dismissal for current session only.
                            // Accepted limitation: dismissed alerts do not persist across app restarts.
                            _dismissedAlertIds.addAll(alerts.map((a) => a.id));
                          });
                        },
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 32, right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primaryAlert.locationName.isNotEmpty
                              ? primaryAlert.locationName
                              : 'Lokasi tanpa nama',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (exceededReading != null)
                          Text(
                            '${exceededReading.analyte.title}: ${exceededReading.measuredValue} ${exceededReading.unit}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            timeAgo,
                            if (distanceText != null) distanceText,
                          ].join(' • '),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                        if (origin == null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Lokasi perangkat tidak tersedia, menampilkan semua peringatan 24 jam terakhir.',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisasterStatusBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tanggap Darurat Air Bersih Posko',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7)),
                ),
                SizedBox(height: 2),
                Text(
                  'Pastikan elektroda bersih sebelum dicelupkan. Uji awal mencegah keracunan massal.',
                  style: TextStyle(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallGaugeCard(double avgWqi, WaterSafetyStatus status, int sampleCount, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Status Mutu Air Wilayah Krisis',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$sampleCount Titik Teruji',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            WaterQualityGauge(score: avgWqi, status: status, size: 190),
            const SizedBox(height: 12),
            Text(
              status.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => widget.onNavigateTab(3), // Navigate to Map tab (index 3)
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: const Color(0xFF0284C7).withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size.fromHeight(40),
              ),
              icon: const Icon(Icons.map_rounded, size: 18, color: Color(0xFF0284C7)),
              label: const Text(
                'Lihat Sebaran Titik Air di Peta Wilayah',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0284C7)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildQuickTestGrid(BuildContext context) {
    final quickAnalytes = [
      TargetAnalyte.lead,
      TargetAnalyte.arsenic,
      TargetAnalyte.mercury,
      TargetAnalyte.cadmium,
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: quickAnalytes.map((analyte) {
        return _buildQuickTestTile(context, analyte);
      }).toList(),
    );
  }

  Widget _buildQuickTestTile(BuildContext context, TargetAnalyte analyte) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color analyteColor;
    switch (analyte) {
      case TargetAnalyte.lead:
        analyteColor = const Color(0xFF6366F1);
        break;
      case TargetAnalyte.arsenic:
        analyteColor = const Color(0xFFE11D48);
        break;
      case TargetAnalyte.mercury:
        analyteColor = const Color(0xFF0D9488);
        break;
      case TargetAnalyte.cadmium:
        analyteColor = const Color(0xFFD97706);
        break;
      default:
        analyteColor = const Color(0xFF0284C7);
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveMeasurementScreen(
              initialParameters: ScanParameters.presetFor(analyte),
              autoStart: true,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: analyteColor.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: analyteColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: analyteColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    analyte.symbol,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
                Icon(Icons.play_circle_fill_rounded, color: analyteColor, size: 22),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  analyte.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'Batas WHO: ${analyte.whoThreshold} mg/L',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTestsList(List<WaterSample> samples, bool isDark) {
    if (samples.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('Belum ada data pengujian air.'),
        ),
      );
    }

    final recent = samples.take(3).toList();

    return Column(
      children: recent.map((sample) {
        final isDanger = sample.safetyStatus == WaterSafetyStatus.danger;
        final isSafe = sample.safetyStatus == WaterSafetyStatus.safe;
        final statusColor = isDanger
            ? const Color(0xFFEF4444)
            : (isSafe ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.15),
              child: Icon(
                isDanger ? Icons.warning_rounded : (isSafe ? Icons.check_circle_rounded : Icons.info_outline),
                color: statusColor,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    sample.locationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
                if (sample.isPendingSync)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 11, color: Color(0xFFD97706)),
                        SizedBox(width: 2),
                        Text(
                          'Belum terkirim',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              '${sample.sourceType.label} • WQI: ${sample.waterQualityIndex.toStringAsFixed(0)}/100',
              style: const TextStyle(fontSize: 11.5),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnalysisReportScreen(sample: sample),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}
