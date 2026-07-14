import 'disk_info.dart';

class SystemMetrics {
  final double cpuUsagePercentage;
  final double memoryUsedMb;
  final double memoryTotalMb;
  final double diskUsedGb;
  final double diskTotalGb;
  final String uptimeString;
  final String loadAvg;
  final String osRelease;
  final String kernelVersion;
  final DateTime timestamp;
  final double networkDownloadSpeedKbps;
  final double networkUploadSpeedKbps;
  final double cpuTemperatureCelsius;
  final List<DiskInfo> disks;
  final String cpuModel;

  SystemMetrics({
    required this.cpuUsagePercentage,
    required this.memoryUsedMb,
    required this.memoryTotalMb,
    required this.diskUsedGb,
    required this.diskTotalGb,
    required this.uptimeString,
    required this.loadAvg,
    required this.osRelease,
    required this.kernelVersion,
    required this.timestamp,
    this.networkDownloadSpeedKbps = 0.0,
    this.networkUploadSpeedKbps = 0.0,
    this.cpuTemperatureCelsius = -1.0,
    this.disks = const [],
    this.cpuModel = 'Unknown Processor',
  });

  factory SystemMetrics.empty() {
    return SystemMetrics(
      cpuUsagePercentage: 0.0,
      memoryUsedMb: 0.0,
      memoryTotalMb: 1.0, // Per evitare divisione per zero
      diskUsedGb: 0.0,
      diskTotalGb: 1.0, // Per evitare divisione per zero
      uptimeString: 'Unknown',
      loadAvg: '0.00, 0.00, 0.00',
      osRelease: 'Linux Server',
      kernelVersion: 'Unknown',
      timestamp: DateTime.now(),
      networkDownloadSpeedKbps: 0.0,
      networkUploadSpeedKbps: 0.0,
      cpuTemperatureCelsius: -1.0,
      disks: const [],
      cpuModel: 'Unknown Processor',
    );
  }

  double get memoryUsagePercentage {
    if (memoryTotalMb <= 0) return 0.0;
    return (memoryUsedMb / memoryTotalMb) * 100.0;
  }

  double get diskUsagePercentage {
    if (diskTotalGb <= 0) return 0.0;
    return (diskUsedGb / diskTotalGb) * 100.0;
  }

  SystemMetrics copyWith({
    double? cpuUsagePercentage,
    double? memoryUsedMb,
    double? memoryTotalMb,
    double? diskUsedGb,
    double? diskTotalGb,
    String? uptimeString,
    String? loadAvg,
    String? osRelease,
    String? kernelVersion,
    DateTime? timestamp,
    double? networkDownloadSpeedKbps,
    double? networkUploadSpeedKbps,
    double? cpuTemperatureCelsius,
    List<DiskInfo>? disks,
    String? cpuModel,
  }) {
    return SystemMetrics(
      cpuUsagePercentage: cpuUsagePercentage ?? this.cpuUsagePercentage,
      memoryUsedMb: memoryUsedMb ?? this.memoryUsedMb,
      memoryTotalMb: memoryTotalMb ?? this.memoryTotalMb,
      diskUsedGb: diskUsedGb ?? this.diskUsedGb,
      diskTotalGb: diskTotalGb ?? this.diskTotalGb,
      uptimeString: uptimeString ?? this.uptimeString,
      loadAvg: loadAvg ?? this.loadAvg,
      osRelease: osRelease ?? this.osRelease,
      kernelVersion: kernelVersion ?? this.kernelVersion,
      timestamp: timestamp ?? this.timestamp,
      networkDownloadSpeedKbps: networkDownloadSpeedKbps ?? this.networkDownloadSpeedKbps,
      networkUploadSpeedKbps: networkUploadSpeedKbps ?? this.networkUploadSpeedKbps,
      cpuTemperatureCelsius: cpuTemperatureCelsius ?? this.cpuTemperatureCelsius,
      disks: disks ?? this.disks,
      cpuModel: cpuModel ?? this.cpuModel,
    );
  }
}
