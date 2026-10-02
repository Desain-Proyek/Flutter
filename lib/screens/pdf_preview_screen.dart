import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/water_sample.dart';
import '../services/pdf_export_service.dart';

/// Screen displaying interactive PDF preview for a water sample test report.
class PdfPreviewScreen extends StatelessWidget {
  final WaterSample sample;

  const PdfPreviewScreen({super.key, required this.sample});

  @override
  Widget build(BuildContext context) {
    final fileName = PdfExportService.getPdfFileName(sample);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pratinjau Dokumen PDF',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'ID: ${sample.id} • ${sample.locationName}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: PdfPreview(
        build: (format) => PdfExportService.generateSampleReportPdf(sample),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: fileName,
        loadingWidget: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                'Menyusun Dokumen Laporan PDF...',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
