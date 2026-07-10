class ProcessInfo {
  final int pid;
  final String user;
  final double cpuPercentage;
  final double memPercentage;
  final String command;

  ProcessInfo({
    required this.pid,
    required this.user,
    required this.cpuPercentage,
    required this.memPercentage,
    required this.command,
  });

  factory ProcessInfo.fromPsLine(String line, {int cores = 1}) {
    // Format da: ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu
    // Esempio riga: " 1234 root     12.5  3.2 node /app/server.js"
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 5) {
      return ProcessInfo(pid: 0, user: '?', cpuPercentage: 0.0, memPercentage: 0.0, command: line);
    }
    final pid = int.tryParse(parts[0]) ?? 0;
    final user = parts[1];
    final rawCpu = double.tryParse(parts[2]) ?? 0.0;
    final effectiveCores = cores > 0 ? cores : 1;
    final cpu = (rawCpu / effectiveCores).clamp(0.0, 100.0);
    final mem = (double.tryParse(parts[3]) ?? 0.0).clamp(0.0, 100.0);
    final comm = parts.sublist(4).join(' ');
    return ProcessInfo(pid: pid, user: user, cpuPercentage: cpu, memPercentage: mem, command: comm);
  }

  Map<String, dynamic> toJson() => {
    'pid': pid,
    'user': user,
    'cpuPercentage': cpuPercentage,
    'memPercentage': memPercentage,
    'command': command,
  };
}
