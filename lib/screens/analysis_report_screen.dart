import 'package:flutter/material.dart';
import '../models/water_sample.dart';
import '../models/mitigation_guide.dart';
import '../services/storage_service.dart';
import '../widgets/water_quality_gauge.dart';
import '../widgets/mitigation_card.dart';
import '../services/pdf_export_service.dart';
import '../services/storage_service.dart';
import 'pdf_preview_screen.dart';

class AnalysisReportScreen extends StatelessWidget {
  final WaterSample sample;

  const AnalysisReportScreen({super.key, required this.sample});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryReading = sample.readings.isNotEmpty ? sample.readings.first : null;
    final mitigation = primaryReading != null
        ? MitigationGuidance.forAnalyte(primaryReading.analyte, primaryReading.isExceeded)
        : MitigationGuidance.forAnalyte(sample.scanParameters.analyte, false);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hasil Analisis & Mitigasi Air',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Lihat & Cetak PDF',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PdfPreviewScreen(sample: sample),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded),
            tooltip: 'Bagikan via QR Code Offline',
            onPressed: () => _showQRCodeModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Bagikan Laporan',
            onPressed: () => _showShareOptions(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sample Header Card
            _buildSampleHeader(isDark),
            const SizedBox(height: 16),

            // Water Quality Gauge & Verdict
            _buildGaugeCard(isDark),
            const SizedBox(height: 16),

            // Contaminants Comparison Table
            _buildContaminantsTable(isDark),
            const SizedBox(height: 16),

            // Emergency Disaster Mitigation Instructions
            MitigationCard(
              guidance: mitigation,
              safetyStatus: sample.safetyStatus,
            ),
            const SizedBox(height: 20),

            // Export & Action Buttons
            _buildActionButtons(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleHeader(bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    sample.id,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0284C7),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.water_rounded, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  sample.sourceType.label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Icon(Icons.access_time_rounded, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  '${sample.timestamp.day}/${sample.timestamp.month}/${sample.timestamp.year} ${sample.timestamp.hour.toString().padLeft(2, '0')}:${sample.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_pin_rounded, size: 16, color: Color(0xFF0284C7)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Petugas Penguji: ${sample.operatorName}${sample.operatorEmail != null ? " (${sample.operatorEmail})" : ""}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
            if (sample.fieldNotes != null && sample.fieldNotes!.isNotEmpty) ...[
              const Divider(height: 16),
              Text(
                'Catatan Lapangan: ${sample.fieldNotes}',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGaugeCard(bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            WaterQualityGauge(
              score: sample.waterQualityIndex,
              status: sample.safetyStatus,
              size: 190,
            ),
            const SizedBox(height: 12),
            Text(
              sample.safetyStatus.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContaminantsTable(bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rincian Konsentrasi Kontaminan Elektrokimia',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...sample.readings.map((reading) {
              final ratio = reading.measuredValue / (reading.thresholdLimit > 0 ? reading.thresholdLimit : 0.01);
              final isExceeded = reading.isExceeded;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isExceeded
                        ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                        : const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isExceeded ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                reading.analyte.symbol,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              reading.analyte.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                          ],
                        ),
                        Text(
                          '${reading.measuredValue.toStringAsFixed(4)} ${reading.unit}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: isExceeded ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress limit bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (ratio / 2.0).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isExceeded ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Batas Baku Mutu (WHO): ${reading.thresholdLimit} ${reading.unit}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          isExceeded ? '⚠️ Melebihi Batas (${ratio.toStringAsFixed(1)}x)' : '✓ Memenuhi Standar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isExceeded ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Resiko: ${reading.analyte.healthRisk}',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
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

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showQRCodeModal(context),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('QR Sinkron'),
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PdfPreviewScreen(sample: sample),
                ),
              );
            },
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Ekspor Laporan Resmi (PDF)'),
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

  void _showQRCodeModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('QR Code Sinkronisasi Lapangan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 200,
                height: 200,
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 140, color: Colors.black),
                      Text(
                        sample.id,
                        style: const TextStyle(color: Colors.black, fontSize: 10, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Scan QR ini dengan smartphone tim relawan lain untuk mentransfer data sampel secara instan tanpa sinyal internet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  void _showShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ekspor Laporan Tanggap Darurat',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.visibility_rounded, color: Color(0xFF0284C7)),
                title: const Text('Pratinjau & Cetak Laporan PDF'),
                subtitle: const Text('Buka pratinjau dokumen resmi A4, cetak ke printer atau simpan.'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfPreviewScreen(sample: sample),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                title: const Text('Bagikan / Simpan File PDF Lapangan'),
                subtitle: const Text('Kirim berkas PDF langsung via WhatsApp, Email, atau Drive.'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Menyiapkan file PDF laporan...')),
                    );
                    await PdfExportService.shareSampleReportPdf(sample);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal mengekspor PDF: $e')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart_rounded, color: Colors.green),
                title: const Text('Ekspor Raw Data CSV'),
                subtitle: const Text('Data tabular hasil uji elektrokimia untuk software lab.'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final cleanId = sample.id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
                    final now = DateTime.now();
                    final timestamp =
                        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
                    final fileName = 'Sampel_${cleanId}_$timestamp.csv';

                    final file = await StorageService().exportAndSaveCSV(
                      customSamples: [sample],
                      fileName: fileName,
                    );

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('CSV tersimpan di: ${file.path}'),
                        duration: const Duration(seconds: 6),
                        action: SnackBarAction(
                          label: 'Buka Folder',
                          onPressed: () => StorageService.openFileLocation(file.path),
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gagal mengekspor CSV: $e'),
                        backgroundColor: Colors.red.shade800,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
