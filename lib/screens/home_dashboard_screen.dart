import 'package:flutter/material.dart';
import '../models/electrochemical_test.dart';
import '../models/water_sample.dart';
import '../models/device_status.dart';
import '../services/potentiostat_service.dart';
import '../services/storage_service.dart';
import '../widgets/water_quality_gauge.dart';
import '../widgets/connection_badge.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<List<WaterSample>>(
      stream: _storageService.samplesStream,
      initialData: _storageService.allSamples,
      builder: (context, snapshot) {
        final samples = snapshot.data ?? [];

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
              await _storageService.loadSamplesFromFirestore();
              if (mounted) setState(() {});
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emergency disaster banner
                  _buildDisasterStatusBanner(isDark),
                  const SizedBox(height: 18),

                  // Overall Water Quality Card
                  _buildOverallGaugeCard(avgWqi, overallStatus, samples.length, isDark),
                  const SizedBox(height: 22),

                  // Rapid Field Test Shortcuts (1-Tap Test)
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
            title: Text(
              sample.locationName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
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
