import 'package:flutter/material.dart';
import '../models/device_status.dart';
import '../services/potentiostat_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool isHighContrast;
  final ValueChanged<bool> onHighContrastChanged;

  const SettingsScreen({
    super.key,
    required this.isHighContrast,
    required this.onHighContrastChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedStandard = 'WHO_2022';
  String _selectedLanguage = 'ID';
  final PotentiostatService _potentiostatService = PotentiostatService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan & Kalibrasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Standard Baku Mutu Section
          _sectionTitle('STANDAR BAKU MUTU AIR'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('WHO Drinking-water Quality Guidelines (4th ed)'),
                  subtitle: const Text('Pb: 0.01 mg/L, As: 0.01 mg/L, Cd: 0.003 mg/L, Hg: 0.001 mg/L'),
                  value: 'WHO_2022',
                  groupValue: _selectedStandard,
                  activeColor: const Color(0xFF0284C7),
                  onChanged: (val) => setState(() => _selectedStandard = val!),
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  title: const Text('Permenkes RI No. 2 Tahun 2023'),
                  subtitle: const Text('Standar baku mutu air minum & higiene sanitasi Indonesia'),
                  value: 'PERMENKES_2023',
                  groupValue: _selectedStandard,
                  activeColor: const Color(0xFF0284C7),
                  onChanged: (val) => setState(() => _selectedStandard = val!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Tampilan & Lapangan Section
          _sectionTitle('PENGATURAN TAMPILAN LAPANGAN'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Mode Terik Matahari (Kontras Tinggi)'),
                  subtitle: const Text('Mempertegas garis grafik dan teks saat pengujian di luar ruangan terbuka'),
                  value: widget.isHighContrast,
                  activeColor: const Color(0xFF0284C7),
                  onChanged: widget.onHighContrastChanged,
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Bahasa Antarmuka'),
                  subtitle: Text(_selectedLanguage == 'ID' ? 'Bahasa Indonesia' : 'English'),
                  trailing: DropdownButton<String>(
                    value: _selectedLanguage,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ID', child: Text('ID (Indonesia)')),
                      DropdownMenuItem(value: 'EN', child: Text('EN (English)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedLanguage = val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Konektivitas Hardware Section
          _sectionTitle('HARDWARE & TELEMETRI'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cable, color: Color(0xFF0284C7)),
                  title: const Text('Status Koneksi'),
                  subtitle: Text(_potentiostatService.deviceStatus.connectionState.label),
                  trailing: OutlinedButton(
                    onPressed: () {
                      _potentiostatService.setDeviceConnection(HardwareConnectionState.simulator);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mode beralih ke Simulator.')),
                      );
                    },
                    child: const Text('Ubah'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.memory, color: Color(0xFF10B981)),
                  title: const Text('Firmware & Board'),
                  subtitle: Text('${_potentiostatService.deviceStatus.deviceName} (${_potentiostatService.deviceStatus.firmwareVersion})'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Database & Memori Section
          _sectionTitle('PENYIMPANAN DATA OFFLINE'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              title: const Text('Reset Riwayat Pengujian'),
              subtitle: const Text('Hapus seluruh cache data pengujian air di perangkat ini.'),
              onTap: () => _confirmResetDialog(context),
            ),
          ),
          const SizedBox(height: 24),

          // About Section
          Center(
            child: Column(
              children: [
                const Text(
                  'PortaStat v1.0.0',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Open Source Portable Potentiostat for Disaster Relief',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {},
                  child: const Text('Lisensi Open Hardware CERN OHL-P & MIT', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _confirmResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Semua Riwayat?'),
        content: const Text('Tindakan ini akan menghapus semua riwayat catatan lapangan yang tersimpan di perangkat ini.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Riwayat pengujian berhasil direset.')),
              );
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
