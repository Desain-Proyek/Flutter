import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/water_sample.dart';
import '../services/storage_service.dart';
import 'analysis_report_screen.dart';

/// Screen displaying an interactive GIS map of all tested water sources in disaster zones.
class DisasterMapScreen extends StatefulWidget {
  const DisasterMapScreen({super.key});

  @override
  State<DisasterMapScreen> createState() => _DisasterMapScreenState();
}

class _DisasterMapScreenState extends State<DisasterMapScreen> {
  final StorageService _storageService = StorageService();
  final MapController _mapController = MapController();

  WaterSafetyStatus? _filterStatus;
  WaterSample? _selectedSample;

  // Default coordinate center (West Java disaster response area)
  static const LatLng _defaultCenter = LatLng(-6.9175, 107.6191);
  double _currentZoom = 11.5;

  void _zoomIn() {
    setState(() {
      _currentZoom = min(_currentZoom + 1.0, 18.0);
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = max(_currentZoom - 1.0, 3.0);
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
  }

  void _recenterToCluster(List<WaterSample> samples) {
    if (samples.isEmpty) {
      _mapController.move(_defaultCenter, 11.5);
      return;
    }

    final valid = samples
        .where((s) => s.latitude != null && s.longitude != null)
        .toList();

    if (valid.isEmpty) {
      _mapController.move(_defaultCenter, 11.5);
      return;
    }

    // Center on the most recent valid sample
    final target = LatLng(valid.first.latitude!, valid.first.longitude!);
    _mapController.move(target, 12.5);
  }

  void _showSampleDetailsSheet(BuildContext context, WaterSample sample, bool isDark) {
    setState(() => _selectedSample = sample);

    final isDanger = sample.safetyStatus == WaterSafetyStatus.danger;
    final isSafe = sample.safetyStatus == WaterSafetyStatus.safe;
    final statusColor = isDanger
        ? const Color(0xFFEF4444)
        : (isSafe ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    final reading = sample.readings.isNotEmpty ? sample.readings.first : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Header: Location name & WQI badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      sample.locationName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'WQI: ${sample.waterQualityIndex.toStringAsFixed(0)}/100',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Safety status description tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDanger
                          ? Icons.warning_rounded
                          : (isSafe ? Icons.check_circle_rounded : Icons.info_outline),
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sample.safetyStatus.label,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Info Row: Source type, timestamp, coordinates
              Row(
                children: [
                  Icon(Icons.water_drop_outlined, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(sample.sourceType.label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 12),
                  Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${sample.timestamp.day}/${sample.timestamp.month} ${sample.timestamp.hour.toString().padLeft(2, '0')}:${sample.timestamp.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Koordinat: ${sample.latitude?.toStringAsFixed(4) ?? "-"}, ${sample.longitude?.toStringAsFixed(4) ?? "-"}',
                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      sample.operatorName,
                      style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Contaminant reading
              if (reading != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Analisis: ${reading.analyte.title}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                      ),
                      Text(
                        '${reading.measuredValue.toStringAsFixed(4)} ${reading.unit} (${reading.isExceeded ? "Tercemar" : "Aman"})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: reading.isExceeded ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Button to open full analysis report
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AnalysisReportScreen(sample: sample),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.analytics_outlined, size: 18),
                label: const Text(
                  'Lihat Laporan Lengkap & Mitigasi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Marker _buildMarker(WaterSample sample, bool isDark) {
    final isDanger = sample.safetyStatus == WaterSafetyStatus.danger;
    final isSafe = sample.safetyStatus == WaterSafetyStatus.safe;
    final statusColor = isDanger
        ? const Color(0xFFEF4444)
        : (isSafe ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    final isSelected = _selectedSample?.id == sample.id;

    return Marker(
      point: LatLng(sample.latitude!, sample.longitude!),
      width: isSelected ? 52 : 46,
      height: isSelected ? 52 : 46,
      child: GestureDetector(
        onTap: () => _showSampleDetailsSheet(context, sample, isDark),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: isSelected ? 3.0 : 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.5),
                blurRadius: isSelected ? 12 : 8,
                spreadRadius: isSelected ? 2 : 1,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              isDanger
                  ? Icons.warning_rounded
                  : (isSafe ? Icons.water_drop_rounded : Icons.filter_alt_rounded),
              color: Colors.white,
              size: isSelected ? 24 : 20,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: StreamBuilder<List<WaterSample>>(
        stream: _storageService.samplesStream,
        initialData: _storageService.allSamples,
        builder: (context, snapshot) {
          final allSamples = snapshot.data ?? [];

          // Filter by status if selected
          final filteredSamples = _filterStatus == null
              ? allSamples
              : allSamples.where((s) => s.safetyStatus == _filterStatus).toList();

          // Only samples with valid coordinates
          final samplesWithCoords = filteredSamples
              .where((s) => s.latitude != null && s.longitude != null)
              .toList();

          // Determine initial map center
          LatLng initialCenter = _defaultCenter;
          if (samplesWithCoords.isNotEmpty) {
            initialCenter = LatLng(
              samplesWithCoords.first.latitude!,
              samplesWithCoords.first.longitude!,
            );
          }

          final markers = samplesWithCoords
              .map((sample) => _buildMarker(sample, isDark))
              .toList();

          return Stack(
            children: [
              // The OpenStreetMap Layer
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: initialCenter,
                  initialZoom: _currentZoom,
                  minZoom: 3.0,
                  maxZoom: 18.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.despro',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),

              // TOP OVERLAY: Filter Chips & Counter Banner
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header card with title & total monitored count
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A).withValues(alpha: 0.92)
                              : Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.explore_rounded, color: Color(0xFF0284C7), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Peta Mutu Air Bencana',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${samplesWithCoords.length} Titik Terpasang',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Filter chips scroll row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterChip(
                              label: const Text('Semua'),
                              selected: _filterStatus == null,
                              onSelected: (_) => setState(() => _filterStatus = null),
                            ),
                            const SizedBox(width: 6),
                            FilterChip(
                              label: const Text('⚠️ Bahaya'),
                              selected: _filterStatus == WaterSafetyStatus.danger,
                              selectedColor: const Color(0xFFEF4444).withValues(alpha: 0.25),
                              onSelected: (sel) => setState(() => _filterStatus = sel ? WaterSafetyStatus.danger : null),
                            ),
                            const SizedBox(width: 6),
                            FilterChip(
                              label: const Text('✓ Layak Minum'),
                              selected: _filterStatus == WaterSafetyStatus.safe,
                              selectedColor: const Color(0xFF10B981).withValues(alpha: 0.25),
                              onSelected: (sel) => setState(() => _filterStatus = sel ? WaterSafetyStatus.safe : null),
                            ),
                            const SizedBox(width: 6),
                            FilterChip(
                              label: const Text('⚡ Perlu Filter'),
                              selected: _filterStatus == WaterSafetyStatus.moderate,
                              selectedColor: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                              onSelected: (sel) => setState(() => _filterStatus = sel ? WaterSafetyStatus.moderate : null),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // BOTTOM RIGHT CONTROLS: Zoom & Recenter
              Positioned(
                bottom: 24,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'map_recenter',
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      foregroundColor: const Color(0xFF0284C7),
                      onPressed: () => _recenterToCluster(samplesWithCoords),
                      tooltip: 'Pusatkan ke Titik Uji',
                      child: const Icon(Icons.my_location_rounded, size: 20),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'map_zoom_in',
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      onPressed: _zoomIn,
                      tooltip: 'Perbesar',
                      child: const Icon(Icons.add, size: 20),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'map_zoom_out',
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      onPressed: _zoomOut,
                      tooltip: 'Perkecil',
                      child: const Icon(Icons.remove, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
