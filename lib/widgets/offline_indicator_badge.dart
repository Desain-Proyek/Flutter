import 'package:flutter/material.dart';
import '../services/storage_service.dart';

/// Reusable offline & cloud sync indicator badge for AppBars and headers.
///
/// Automatically listens to [StorageService.isOfflineNotifier] and displays
/// real-time status:
/// - Green "Online" / "Cloud Online" badge when connected.
/// - Amber "Offline" / "Mode Offline" badge when working from local cache,
///   disconnected, or when pending sync samples exist.
class OfflineIndicatorBadge extends StatelessWidget {
  final bool compact;
  final bool showWhenOnline;

  const OfflineIndicatorBadge({
    super.key,
    this.compact = false,
    this.showWhenOnline = true,
  });

  @override
  Widget build(BuildContext context) {
    final storageService = StorageService();

    return ValueListenableBuilder<bool>(
      valueListenable: storageService.isOfflineNotifier,
      builder: (context, isOffline, child) {
        if (!isOffline && storageService.pendingCount == 0 && !showWhenOnline) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final pending = storageService.pendingCount;

        final Color badgeColor = isOffline
            ? const Color(0xFFD97706) // Amber/Orange
            : const Color(0xFF10B981); // Emerald Green

        final IconData badgeIcon = isOffline
            ? Icons.cloud_off_rounded
            : Icons.cloud_done_rounded;

        final String labelText;
        if (isOffline) {
          if (pending > 0) {
            labelText = compact ? 'Offline ($pending)' : 'Offline ($pending Pending)';
          } else {
            labelText = compact ? 'Offline' : 'Mode Offline';
          }
        } else {
          labelText = compact ? 'Online' : 'Cloud Online';
        }

        final tooltipMessage = isOffline
            ? (pending > 0
                ? '$pending sampel tersimpan lokal, menunggu koneksi.'
                : 'Mode Offline: Memori lokal perangkat aktif.')
            : 'Cloud Online: Terhubung ke Firebase Firestore.';

        return Tooltip(
          message: tooltipMessage,
          child: InkWell(
            onTap: () => _showSyncDetailModal(context, storageService),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 4 : 5,
              ),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    badgeIcon,
                    color: badgeColor,
                    size: 15,
                    semanticLabel: isOffline ? 'Indikator Offline' : 'Indikator Online',
                  ),
                  const SizedBox(width: 5),
                  Text(
                    labelText,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSyncDetailModal(BuildContext context, StorageService storageService) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final isOffline = storageService.isOffline;
            final pending = storageService.pendingCount;
            final isDark = Theme.of(modalContext).brightness == Brightness.dark;

            final statusColor = isOffline ? const Color(0xFFD97706) : const Color(0xFF10B981);

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cloud_sync_rounded, color: statusColor, size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            'Status Sinkronisasi & Cloud',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Status Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: statusColor,
                          radius: 18,
                          child: Icon(
                            isOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOffline ? 'Mode Offline Aktif' : 'Terhubung ke Cloud (Online)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isOffline
                                    ? (pending > 0
                                        ? '$pending data tersimpan di memori perangkat, siap dikirim saat online.'
                                        : 'Aplikasi beroperasi dari database lokal perangkat.')
                                    : 'Data tersinkronisasi otomatis dengan server Firebase Firestore.',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Info items
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.storage_rounded, color: Color(0xFF0284C7)),
                    title: const Text('Total Riwayat Sampel'),
                    trailing: Text(
                      '${storageService.allSamples.length} sampel',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.pending_actions_rounded,
                      color: pending > 0 ? const Color(0xFFD97706) : Colors.grey,
                    ),
                    title: const Text('Sampel Menunggu Sinkronisasi'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: pending > 0
                            ? const Color(0xFFD97706).withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$pending sampel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: pending > 0 ? const Color(0xFFD97706) : Colors.grey,
                        ),
                      ),
                    ),
                  ),

                  const Divider(height: 20),

                  // Force Offline Toggle for Field Simulation
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.signal_cellular_connected_no_internet_4_bar_rounded),
                    title: const Text('Simulasi Mode Offline Lapangan', style: TextStyle(fontSize: 13.5)),
                    subtitle: const Text(
                      'Paksa aplikasi beroperasi tanpa internet untuk uji coba tanggap bencana.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    value: storageService.isForceOffline,
                    onChanged: (val) {
                      storageService.setForceOffline(val);
                      setModalState(() {});
                    },
                  ),

                  const SizedBox(height: 12),

                  // Sync / Refresh button
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Memeriksa koneksi internet & menyinkronkan data...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      final isConnected = await storageService.checkInternetConnection();
                      if (isConnected) {
                        await storageService.loadSamplesFromFirestore();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sinkronisasi selesai! Data cloud terbaru telah dimuat.'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tidak dapat terhubung ke internet. Tetap dalam Mode Offline.'),
                              backgroundColor: Color(0xFFD97706),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Periksa Koneksi & Sinkronkan Sekarang'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Reusable full-width offline status banner.
class OfflineStatusBar extends StatelessWidget {
  const OfflineStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final storageService = StorageService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<bool>(
      valueListenable: storageService.isOfflineNotifier,
      builder: (context, isOffline, child) {
        final pending = storageService.pendingCount;
        final shouldShow = isOffline || pending > 0;

        if (!shouldShow) return const SizedBox.shrink();

        const orangeColor = Color(0xFFD97706);

        final text = pending > 0
            ? '$pending sampel tersimpan lokal, menunggu koneksi untuk dikirim.'
            : 'Mode Offline: Bekerja tanpa internet. Data tersimpan di perangkat.';

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 20,
                color: orangeColor,
                semanticLabel: 'Status Offline',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: orangeColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  storageService.checkInternetConnection().then((hasInternet) {
                    if (hasInternet) {
                      storageService.loadSamplesFromFirestore();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Terhubung kembali! Menyinkronkan data cloud...'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Koneksi internet belum terdeteksi. Tetap offline.'),
                          backgroundColor: Color(0xFFD97706),
                        ),
                      );
                    }
                  });
                },
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: orangeColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Offline',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.refresh_rounded, color: Colors.white, size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
