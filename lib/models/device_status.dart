/// Connection status of PortaStat hardware
enum HardwareConnectionState {
  disconnected('Terputus', 'Perangkat tidak terhubung'),
  scanning('Memindai...', 'Mencari perangkat PortaStat terdekat'),
  connecting('Menghubungkan...', 'Menyinkronkan saluran BLE/Serial'),
  connected('Terhubung (BLE)', 'PortaStat Siap Digunakan'),
  simulator('Mode Simulator', 'Simulasi elektrokimia internal (Standby)');

  final String label;
  final String description;

  const HardwareConnectionState(this.label, this.description);
}

/// Device health and operating telemetry
class DeviceStatus {
  final HardwareConnectionState connectionState;
  final String deviceName;
  final String firmwareVersion;
  final int? batteryPercent;
  final double? boardTemperatureC;
  final double? electrodeWearPercent; // 0 (fresh) to 100 (needs replacement)
  final bool isDummyCellCalibrated;
  final String serialPortOrMac;

  const DeviceStatus({
    this.connectionState = HardwareConnectionState.simulator,
    this.deviceName = '-',
    this.firmwareVersion = '-',
    this.batteryPercent,
    this.boardTemperatureC,
    this.electrodeWearPercent,
    this.isDummyCellCalibrated = false,
    this.serialPortOrMac = '-',
  });

  DeviceStatus copyWith({
    HardwareConnectionState? connectionState,
    String? deviceName,
    String? firmwareVersion,
    int? batteryPercent,
    double? boardTemperatureC,
    double? electrodeWearPercent,
    bool? isDummyCellCalibrated,
    String? serialPortOrMac,
  }) {
    return DeviceStatus(
      connectionState: connectionState ?? this.connectionState,
      deviceName: deviceName ?? this.deviceName,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      boardTemperatureC: boardTemperatureC ?? this.boardTemperatureC,
      electrodeWearPercent: electrodeWearPercent ?? this.electrodeWearPercent,
      isDummyCellCalibrated: isDummyCellCalibrated ?? this.isDummyCellCalibrated,
      serialPortOrMac: serialPortOrMac ?? this.serialPortOrMac,
    );
  }
}
