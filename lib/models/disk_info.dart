class DiskInfo {
  final String filesystem;
  final String mountPoint;
  final double totalGb;
  final double usedGb;
  final double freeGb;
  final double usagePercentage;

  DiskInfo({
    required this.filesystem,
    required this.mountPoint,
    required this.totalGb,
    required this.usedGb,
    required this.freeGb,
    required this.usagePercentage,
  });

  factory DiskInfo.fromJson(Map<String, dynamic> json) {
    return DiskInfo(
      filesystem: json['filesystem']?.toString() ?? '',
      mountPoint: json['mountPoint']?.toString() ?? '',
      totalGb: (json['totalGb'] is num) ? (json['totalGb'] as num).toDouble() : 0.0,
      usedGb: (json['usedGb'] is num) ? (json['usedGb'] as num).toDouble() : 0.0,
      freeGb: (json['freeGb'] is num) ? (json['freeGb'] as num).toDouble() : 0.0,
      usagePercentage: (json['usagePercentage'] is num) ? (json['usagePercentage'] as num).toDouble() : 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'filesystem': filesystem,
    'mountPoint': mountPoint,
    'totalGb': totalGb,
    'usedGb': usedGb,
    'freeGb': freeGb,
    'usagePercentage': usagePercentage,
  };
}
