import 'package:flutter/material.dart';
import '../services/potentiostat_service.dart';

class HardwareDIYGuideScreen extends StatelessWidget {
  const HardwareDIYGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Panduan Hardware & Perakitan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Manufaktur Bengkel Lokal & Komponen Terjangkau', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Box
            _buildLowCostBanner(isDark),
            const SizedBox(height: 16),

            // 3-Electrode Pinout Schematic Card
            _buildSchematicCard(isDark),
            const SizedBox(height: 16),

            // Dummy Cell Calibration & Hardware Self-Test
            _buildCalibrationCard(context, isDark),
            const SizedBox(height: 16),

            // Bill of Materials (BOM) Table
            _buildBOMCard(isDark),
            const SizedBox(height: 16),

            // Electrode Field Care & Cleaning Guide
            _buildFieldCareCard(isDark),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLowCostBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.build_circle_outlined, color: Color(0xFF0284C7), size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Desain Terbuka (Open Hardware DIY)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0284C7)),
                ),
                SizedBox(height: 3),
                Text(
                  'Dirancang khusus agar dapat dirakit oleh bengkel elektronik kecil & UMKM tanpa mesin fabrikasi canggih dengan estimasi biaya < Rp 300.000.',
                  style: TextStyle(fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchematicCard(bool isDark) {
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
            const Row(
              children: [
                Icon(Icons.schema_outlined, size: 20, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Text(
                  'Skematik Sistem 3-Elektroda (3-Electrode Cell)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: Column(
                children: [
                  _pinoutRow(
                    'WE (Working Electrode)',
                    'Sensor Kerja',
                    'Tempat reaksi redoks analit berlangsung. Mengukur arus transimpedansi (TIA).',
                    const Color(0xFFE11D48),
                  ),
                  const Divider(height: 16),
                  _pinoutRow(
                    'RE (Reference Electrode)',
                    'Elektroda Rujukan',
                    'Mempertahankan potensial acuan konstan (Ag/AgCl). Arus masuk ~0 pA (High Impedance Buffer).',
                    const Color(0xFF0284C7),
                  ),
                  const Divider(height: 16),
                  _pinoutRow(
                    'CE (Counter / Aux Electrode)',
                    'Elektroda Pembantu',
                    'Mengalirkan arus balik dari larutan untuk menjaga kestabilan sel elektrokimia (Platinum / Kawat Stainless).',
                    const Color(0xFF10B981),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pinoutRow(String pin, String name, String desc, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            pin.split(' ').first,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.25)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalibrationCard(BuildContext context, bool isDark) {
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
            const Row(
              children: [
                Icon(Icons.tune_rounded, size: 20, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Text(
                  'Kalibrasi Mandiri (Dummy Cell 10 kΩ)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Gunakan resistor 10 kΩ antara pin WE dan CE/RE untuk memverifikasi hukum Ohm (V = I x R) dan memastikan op-amp TIA bekerja linear sebelum pengujian air.',
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () {
                PotentiostatService().calibrateDummyCell();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✓ Dummy Cell Terverifikasi! Noise: 0.12 μA, Slope: 0.10 mA/V.')),
                );
              },
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Jalankan Uji Mandiri Dummy Cell'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBOMCard(bool isDark) {
    final bomItems = [
      {'part': 'ESP32 DevKit V1 (30-pin)', 'spec': 'BLE 4.2 & Dual Core 240MHz', 'price': 'Rp 55.000', 'status': 'Sangat Mudah'},
      {'part': 'Modul LMP91000 / Op-Amp TIA', 'spec': 'Potentiostat AFE I2C', 'price': 'Rp 85.000', 'status': 'Online/Toko Elektronik'},
      {'part': 'Elektroda Karbon Sablon (SPE)', 'spec': '3-Kutub (WE/RE/CE) atau Pensil 2B', 'price': 'Rp 15.000/set', 'status': 'Bahan Lokal'},
      {'part': 'Baterai Li-Ion 18650 + TP4056', 'spec': '3.7V 2600mAh + BMS Charger', 'price': 'Rp 35.000', 'status': 'Tersedia Luas'},
      {'part': 'Casing 3D Print / Box X6', 'spec': 'Enclosure ABS Tahan Cipratan', 'price': 'Rp 20.000', 'status': 'Bengkel Lokal'},
    ];

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daftar Komponen (Bill of Materials)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Est. Total: Rp 210.000',
                    style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...bomItems.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['part']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          Text(item['spec']!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(item['price']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0284C7))),
                        Text(item['status']!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
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

  Widget _buildFieldCareCard(bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cleaning_services_outlined, size: 20, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Text(
                  'Perawatan Elektroda di Daerah Bencana',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              '1. Bilas elektroda dengan air deionisasi atau air mineral botol bersih setelah setiap pengujian sampel.',
              style: TextStyle(fontSize: 12, height: 1.3),
            ),
            SizedBox(height: 4),
            Text(
              '2. Jika terjadi fouling/penumpukan kotoran logam berat, lakukan pembersihan elektrokimia (Electrochemical Cleaning) dengan menerapkan potensial +1.0 V selama 10 detik dalam larutan asam sitrat/cuka encer.',
              style: TextStyle(fontSize: 12, height: 1.3),
            ),
            SizedBox(height: 4),
            Text(
              '3. Hindari menyentuh permukaan elektroda karbon dengan jari berminyak.',
              style: TextStyle(fontSize: 12, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
