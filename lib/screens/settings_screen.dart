import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_status.dart';
import '../services/potentiostat_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

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
  final PotentiostatService _potentiostatService = PotentiostatService();
  final AuthService _authService = AuthService();

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
          // Petugas & Autentikasi Section
          _sectionTitle('PETUGAS & AUTENTIKASI'),
          _buildOperatorProfileCard(isDark),
          const SizedBox(height: 18),

          // Standard Baku Mutu Section
          _sectionTitle('STANDAR BAKU MUTU AIR'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.verified_outlined, color: Color(0xFF0284C7), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'WHO Drinking-water Quality Guidelines (4th ed)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Aktif',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Pb: 0.01 mg/L, As: 0.01 mg/L, Cd: 0.003 mg/L, Hg: 0.001 mg/L',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Standar acuan resmi yang digunakan sistem untuk evaluasi ambang batas toksisitas & Water Quality Index (WQI).',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                  subtitle: const Text('Bahasa Indonesia (Bawaan Sistem)'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ID (Indonesia)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0284C7),
                      ),
                    ),
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
              subtitle: const Text('Hapus seluruh riwayat pengujian milik akun ini.'),
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

  Widget _buildOperatorProfileCard(bool isDark) {
    final isAnonymous = _authService.isAnonymous;
    final displayName = _authService.operatorDisplayName;
    final email = _authService.operatorEmail;
    final uid = _authService.operatorId ?? 'N/A';
    final shortUid = uid.length > 8 ? uid.substring(0, 8) : uid;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
                  child: Icon(
                    isAnonymous ? Icons.shield_outlined : Icons.person_rounded,
                    color: const Color(0xFF0284C7),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAnonymous
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                  : const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isAnonymous ? 'Relawan Tamu' : 'Resmi',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isAnonymous ? const Color(0xFFD97706) : const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email ?? 'ID: $shortUid...',
                        style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _confirmSignOutDialog(context),
                icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.red),
                label: const Text(
                  'Keluar / Ganti Petugas',
                  style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari Akun?'),
        content: const Text(
          'Anda akan dialihkan kembali ke layar masuk petugas/relawan lapangan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.signOut();
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmResetDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Semua Riwayat?'),
        content: const Text(
          'Hapus semua riwayat pengujian milik akun ini dari server? Data tidak bisa dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    showDialog(
      context: this.context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Menghapus riwayat pengujian...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final n = await StorageService().deleteAllMySamples();
      if (!mounted) return;
      Navigator.of(this.context, rootNavigator: true).pop();
      final msg = n == 0
          ? 'Tidak ada riwayat milik akun ini.'
          : '$n riwayat berhasil dihapus.';
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      Navigator.of(this.context, rootNavigator: true).pop();
      final message = e.code == 'permission-denied'
          ? 'Anda tidak punya izin menghapus riwayat ini.'
          : 'Gagal menghapus riwayat: ${e.message ?? e.code}';
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(this.context, rootNavigator: true).pop();
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus riwayat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
