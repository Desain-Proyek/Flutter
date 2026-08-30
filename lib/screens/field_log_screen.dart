import 'package:flutter/material.dart';
import '../models/water_sample.dart';
import '../services/storage_service.dart';
import 'analysis_report_screen.dart';

class FieldLogScreen extends StatefulWidget {
  const FieldLogScreen({super.key});

  @override
  State<FieldLogScreen> createState() => _FieldLogScreenState();
}

class _FieldLogScreenState extends State<FieldLogScreen> {
  final StorageService _storageService = StorageService();
  String _searchQuery = '';
  WaterSafetyStatus? _filterStatus;
  WaterSourceType? _filterSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredSamples = _storageService.searchSamples(
      query: _searchQuery,
      statusFilter: _filterStatus,
      sourceFilter: _filterSource,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Catatan Lapangan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text('Database Titik Sumber Air Darurat', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Ekspor Semua ke CSV',
            onPressed: () {
              _storageService.exportToCSV();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Berhasil mengekspor ${filteredSamples.length} data ke CSV!')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Cari lokasi, desa, ID sampel...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
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
                        label: const Text('⚠️ Bahaya / Tercemar'),
                        selected: _filterStatus == WaterSafetyStatus.danger,
                        selectedColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        onSelected: (sel) => setState(() => _filterStatus = sel ? WaterSafetyStatus.danger : null),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('✓ Layak Minum'),
                        selected: _filterStatus == WaterSafetyStatus.safe,
                        selectedColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                        onSelected: (sel) => setState(() => _filterStatus = sel ? WaterSafetyStatus.safe : null),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('⚡ Perlu Filter'),
                        selected: _filterStatus == WaterSafetyStatus.moderate,
                        selectedColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        onSelected: (sel) => setState(() => _filterStatus = sel ? WaterSafetyStatus.moderate : null),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // List of Samples
          Expanded(
            child: filteredSamples.isEmpty
                ? const Center(
                    child: Text('Tidak ada catatan pengujian air yang cocok.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filteredSamples.length,
                    itemBuilder: (context, index) {
                      final sample = filteredSamples[index];
                      return _buildSampleCard(context, sample, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleCard(BuildContext context, WaterSample sample, bool isDark) {
    final isDanger = sample.safetyStatus == WaterSafetyStatus.danger;
    final isSafe = sample.safetyStatus == WaterSafetyStatus.safe;
    final statusColor = isDanger
        ? const Color(0xFFEF4444)
        : (isSafe ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    final reading = sample.readings.isNotEmpty ? sample.readings.first : null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withValues(alpha: 0.35), width: 1.2),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnalysisReportScreen(sample: sample),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      sample.locationName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'WQI: ${sample.waterQualityIndex.toStringAsFixed(0)}/100',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.water_drop_outlined, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(sample.sourceType.label, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                  const SizedBox(width: 10),
                  Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${sample.timestamp.day}/${sample.timestamp.month} ${sample.timestamp.hour.toString().padLeft(2, '0')}:${sample.timestamp.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (reading != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Analisis: ${reading.analyte.title}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${reading.measuredValue.toStringAsFixed(4)} ${reading.unit} (${reading.isExceeded ? "Tercemar" : "Aman"})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: reading.isExceeded ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
