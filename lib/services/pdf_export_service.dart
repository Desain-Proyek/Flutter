import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/water_sample.dart';
import '../models/mitigation_guide.dart';
import 'storage_service.dart';

/// Service for generating, sharing, and printing official PDF test reports.
class PdfExportService {
  /// Generate a clean file name for the PDF report.
  static String getPdfFileName(WaterSample sample) {
    final cleanId = sample.id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final dateStr =
        '${sample.timestamp.year}${sample.timestamp.month.toString().padLeft(2, '0')}${sample.timestamp.day.toString().padLeft(2, '0')}';
    return 'Laporan_Kualitas_Air_${cleanId}_$dateStr.pdf';
  }

  /// Generate the complete PDF document as [Uint8List] bytes.
  static Future<Uint8List> generateSampleReportPdf(WaterSample sample) async {
    final doc = pw.Document(
      title: 'Laporan Kualitas Air PortaStat - ${sample.id}',
      author: sample.operatorName,
    );

    // Primary reading & mitigation guidance
    final primaryReading =
        sample.readings.isNotEmpty ? sample.readings.first : null;
    final mitigation = primaryReading != null
        ? MitigationGuidance.forAnalyte(
            primaryReading.analyte, primaryReading.isExceeded)
        : MitigationGuidance.forAnalyte(sample.scanParameters.analyte, false);

    // QR Code data payload
    final qrPayload = StorageService().exportSampleToQRPayload(sample);

    // Brand & Status Colors
    final primaryColor = PdfColor.fromHex('#0284C7');
    final darkHeader = PdfColor.fromHex('#0F172A');
    final borderColor = PdfColor.fromHex('#CBD5E1');

    PdfColor statusColor;
    PdfColor statusBgColor;
    String statusTitle;

    switch (sample.safetyStatus) {
      case WaterSafetyStatus.safe:
        statusColor = PdfColor.fromHex('#059669');
        statusBgColor = PdfColor.fromHex('#ECFDF5');
        statusTitle = 'AMAN DIKONSUMSI';
        break;
      case WaterSafetyStatus.moderate:
        statusColor = PdfColor.fromHex('#D97706');
        statusBgColor = PdfColor.fromHex('#FFFBEB');
        statusTitle = 'PERLU PENANGANAN / FILTRASI';
        break;
      case WaterSafetyStatus.danger:
        statusColor = PdfColor.fromHex('#DC2626');
        statusBgColor = PdfColor.fromHex('#FEF2F2');
        statusTitle = 'BAHAYA / TERCEMAR LOGAM BERAT';
        break;
    }

    // Build PDF MultiPage
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (pw.Context context) {
          return [
            // ==========================================
            // HEADER & LETTERHEAD
            // ==========================================
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PORTASTAT EMERGENCY WATER MONITORING',
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9,
                          letterSpacing: 1.1,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'LAPORAN HASIL PENGUJIAN KUALITAS AIR',
                        style: pw.TextStyle(
                          color: darkHeader,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Pemeriksaan Elektrokimia Kualitas Air Posko Bencana & Krisis Lingkungan',
                        style: const pw.TextStyle(
                          color: PdfColors.grey700,
                          fontSize: 8.5,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F0F9FF'),
                    border: pw.Border.all(color: primaryColor, width: 1),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'ID: ${sample.id}',
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      pw.Text(
                        '${sample.timestamp.day.toString().padLeft(2, '0')}/${sample.timestamp.month.toString().padLeft(2, '0')}/${sample.timestamp.year} ${sample.timestamp.hour.toString().padLeft(2, '0')}:${sample.timestamp.minute.toString().padLeft(2, '0')} WIB',
                        style: const pw.TextStyle(
                          color: PdfColors.grey600,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: borderColor, thickness: 1),
            pw.SizedBox(height: 10),

            // ==========================================
            // STATUS & WATER QUALITY INDEX (WQI) BANNER
            // ==========================================
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: statusBgColor,
                border: pw.Border.all(color: statusColor, width: 1.2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'STATUS KELAYAKAN AIR: $statusTitle',
                          style: pw.TextStyle(
                            color: statusColor,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11.5,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          sample.safetyStatus.description,
                          style: const pw.TextStyle(
                            color: PdfColors.grey800,
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: statusColor,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'SKOR WQI',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          '${sample.waterQualityIndex.toStringAsFixed(0)}/100',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // ==========================================
            // SAMPLE & FIELD METADATA TABLE
            // ==========================================
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                border: pw.Border.all(color: borderColor),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'INFORMASI TITIK PENGUJIAN LAPANGAN',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9.5,
                      color: darkHeader,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: _buildInfoItem(
                          'Lokasi Titik Sampel',
                          sample.locationName,
                        ),
                      ),
                      pw.Expanded(
                        child: _buildInfoItem(
                          'Tipe Sumber Air',
                          sample.sourceType.label,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: _buildInfoItem(
                          'Koordinat GPS',
                          (sample.latitude != null && sample.longitude != null)
                              ? '${sample.latitude!.toStringAsFixed(5)}, ${sample.longitude!.toStringAsFixed(5)}'
                              : 'Tidak terdata (Manual GPS)',
                        ),
                      ),
                      pw.Expanded(
                        child: _buildInfoItem(
                          'Petugas Penguji',
                          sample.operatorName +
                              (sample.operatorEmail != null
                                  ? ' (${sample.operatorEmail})'
                                  : ''),
                        ),
                      ),
                    ],
                  ),
                  if (sample.fieldNotes != null &&
                      sample.fieldNotes!.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 5),
                    _buildInfoItem(
                      'Catatan Observasi Fisik Lapangan',
                      sample.fieldNotes!.trim(),
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // ==========================================
            // CONTAMINANT READINGS TABLE
            // ==========================================
            pw.Text(
              'HASIL PENGUKURAN KONTAMINAN ELEKTROKIMIA',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: darkHeader,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 0.6),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.6), // Parameter
                1: pw.FlexColumnWidth(1.8), // Hasil Terukur
                2: pw.FlexColumnWidth(2.0), // Baku Mutu (WHO)
                3: pw.FlexColumnWidth(2.0), // Status
                4: pw.FlexColumnWidth(1.6), // Potensial Puncak
                5: pw.FlexColumnWidth(1.6), // Arus Puncak
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F1F5F9'),
                  ),
                  children: [
                    _buildTableHeaderCell('Parameter / Analit'),
                    _buildTableHeaderCell('Hasil Terukur'),
                    _buildTableHeaderCell('Baku Mutu (WHO)'),
                    _buildTableHeaderCell('Evaluasi Status'),
                    _buildTableHeaderCell('Potensial (Ep)'),
                    _buildTableHeaderCell('Arus Net (Ip)'),
                  ],
                ),
                // Table Data Rows
                ...sample.readings.map((reading) {
                  final exceeded = reading.isExceeded;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: exceeded
                          ? PdfColor.fromHex('#FEF2F2')
                          : PdfColors.white,
                    ),
                    children: [
                      _buildTableCell(
                        '${reading.analyte.title} (${reading.analyte.symbol})',
                        isBold: true,
                      ),
                      _buildTableCell(
                        '${reading.measuredValue.toStringAsFixed(4)} ${reading.unit}',
                        textColor: exceeded
                            ? PdfColor.fromHex('#DC2626')
                            : PdfColor.fromHex('#059669'),
                        isBold: true,
                      ),
                      _buildTableCell(
                        '${reading.thresholdLimit.toStringAsFixed(4)} ${reading.unit}',
                      ),
                      _buildTableCell(
                        exceeded
                            ? 'MELEBIHI BATAS'
                            : 'Memenuhi Baku Mutu',
                        textColor: exceeded
                            ? PdfColor.fromHex('#DC2626')
                            : PdfColor.fromHex('#059669'),
                        isBold: true,
                      ),
                      _buildTableCell(
                        '${reading.peakPotentialV.toStringAsFixed(2)} V',
                      ),
                      _buildTableCell(
                        '${reading.peakCurrentMicroA.toStringAsFixed(2)} uA',
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 12),

            // ==========================================
            // INSTRUMENT PARAMETERS SUMMARY
            // ==========================================
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderColor, width: 0.7),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                color: PdfColor.fromHex('#FAFAFA'),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildInlineParam(
                    'Metode Elektrokimia',
                    sample.scanParameters.technique.fullName,
                  ),
                  _buildInlineParam(
                    'Rentang Sapuan',
                    '${sample.scanParameters.startPotentialV}V s/d ${sample.scanParameters.endPotentialV}V',
                  ),
                  _buildInlineParam(
                    'Scan Rate',
                    '${sample.scanParameters.scanRateMvPerSec} mV/s',
                  ),
                  _buildInlineParam(
                    'Deposisi',
                    '${sample.scanParameters.depositionTimeSec.toStringAsFixed(0)}s',
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // ==========================================
            // EMERGENCY MITIGATION RECOMMENDATIONS
            // ==========================================
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: statusBgColor,
                border: pw.Border.all(color: statusColor, width: 0.8),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PANDUAN & REKOMENDASI MITIGASI DARURAT BENCANA',
                    style: pw.TextStyle(
                      color: statusColor,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9.5,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    mitigation.criticalWarning,
                    style: pw.TextStyle(
                      color: PdfColors.black,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8.5,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Tindakan Langsung di Lapangan:',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8.5,
                      color: darkHeader,
                    ),
                  ),
                  ...mitigation.immediateActions.map(
                    (action) => pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2, left: 6),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('• ',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 8)),
                          pw.Expanded(
                            child: pw.Text(
                              action,
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Metode Penjernihan / Pengolahan Darurat:',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8.5,
                      color: darkHeader,
                    ),
                  ),
                  ...mitigation.lowCostTreatmentSteps.map(
                    (step) => pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2, left: 6),
                      child: pw.Text(
                        step,
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey900,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Rujukan Standar: ${mitigation.whoStandardRef}',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // ==========================================
            // FOOTER & VERIFICATION
            // ==========================================
            pw.Divider(color: borderColor, thickness: 0.8),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                // QR Code Verification
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 52,
                      height: 52,
                      padding: const pw.EdgeInsets.all(3),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(4)),
                        color: PdfColors.white,
                      ),
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrPayload,
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Validasi Digital Lapangan',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 7.5,
                            color: darkHeader,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Pindai QR ini untuk verifikasi keaslian\ndata pembacaan sensor PortaStat.',
                          style: const pw.TextStyle(
                            fontSize: 6.5,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Signature / Operator Column
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Petugas / Penguji Posko,',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey800,
                      ),
                    ),
                    pw.SizedBox(height: 32),
                    pw.Container(
                      width: 140,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColors.black,
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      sample.operatorName,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  /// Share or save the generated PDF file using system dialog.
  static Future<void> shareSampleReportPdf(WaterSample sample) async {
    final pdfBytes = await generateSampleReportPdf(sample);
    final filename = getPdfFileName(sample);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
    );
  }

  /// Print the generated PDF report directly to a connected printer.
  static Future<void> printSampleReportPdf(WaterSample sample) async {
    final pdfBytes = await generateSampleReportPdf(sample);
    final filename = getPdfFileName(sample);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: filename,
    );
  }

  // ==========================================
  // HELPER WIDGETS FOR PDF
  // ==========================================

  static pw.Widget _buildInfoItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 7.5,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 1.5),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 8.5,
            color: PdfColors.grey900,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildInlineParam(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 7,
            color: PdfColors.grey600,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 7.5,
            color: PdfColors.grey900,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 7.5,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isBold = false,
    PdfColor textColor = PdfColors.black,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor,
        ),
      ),
    );
  }
}
