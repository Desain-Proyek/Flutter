import 'package:flutter/material.dart';
import '../models/device_status.dart';
import '../services/potentiostat_service.dart';

/// Connection badge with quick bottom sheet for BLE/USB and simulator switching
class ConnectionBadge extends StatelessWidget {
  final DeviceStatus status;

  const ConnectionBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    IconData iconData;

    switch (status.connectionState) {
      case HardwareConnectionState.connected:
        badgeColor = const Color(0xFF10B981);
        iconData = Icons.bluetooth_connected_rounded;
        break;
      case HardwareConnectionState.simulator:
        badgeColor = const Color(0xFF0284C7);
        iconData = Icons.science_outlined;
        break;
      case HardwareConnectionState.connecting:
      case HardwareConnectionState.scanning:
        badgeColor = const Color(0xFFF59E0B);
        iconData = Icons.bluetooth_searching_rounded;
        break;
      case HardwareConnectionState.disconnected:
        badgeColor = const Color(0xFFEF4444);
        iconData = Icons.bluetooth_disabled_rounded;
        break;
    }

    return InkWell(
      onTap: () => _showConnectionModal(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, color: badgeColor, size: 16),
            const SizedBox(width: 6),
            Text(
              status.connectionState.label,
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(width: 1, height: 12, color: badgeColor.withValues(alpha: 0.3)),
            const SizedBox(width: 6),
            Icon(
              status.batteryPercent != null
                  ? Icons.battery_5_bar_rounded
                  : Icons.battery_unknown_rounded,
              color: badgeColor,
              size: 14,
            ),
            Text(
              status.batteryPercent != null ? '${status.batteryPercent}%' : '-',
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConnectionModal(BuildContext context) {
    final service = PotentiostatService();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Koneksi Perangkat PortaStat',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
              const SizedBox(height: 6),
              Text(
                status.deviceName == '-' && status.serialPortOrMac == '-'
                    ? 'Perangkat terdeteksi: Tidak tersedia'
                    : 'Perangkat terdeteksi: ${status.deviceName} (${status.serialPortOrMac})',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF0284C7),
                  child: Icon(Icons.science_outlined, color: Colors.white),
                ),
                title: const Text('Mode Simulator Elektrokimia'),
                subtitle: const Text('Simulasi respons redoks realistis tanpa hardware fisik.'),
                trailing: status.connectionState == HardwareConnectionState.simulator
                    ? const Icon(Icons.check_circle, color: Color(0xFF10B981))
                    : null,
                onTap: () {
                  service.setDeviceConnection(HardwareConnectionState.simulator);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF10B981),
                  child: Icon(Icons.bluetooth_connected, color: Colors.white),
                ),
                title: const Text('Hubungkan Hardware BLE (ESP32)'),
                subtitle: const Text('Terhubung via Bluetooth Low Energy ke modul PortaStat.'),
                trailing: status.connectionState == HardwareConnectionState.connected
                    ? const Icon(Icons.check_circle, color: Color(0xFF10B981))
                    : null,
                onTap: () {
                  service.setDeviceConnection(HardwareConnectionState.connected);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[700],
                  child: const Icon(Icons.cable, color: Colors.white),
                ),
                title: const Text('Hubungkan USB Serial / OTG'),
                subtitle: const Text('Kabel OTG langsung ke smartphone lapangan.'),
                onTap: () {
                  service.setDeviceConnection(HardwareConnectionState.connected);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Uji mandiri otomatis tersedia setelah perangkat terhubung.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
