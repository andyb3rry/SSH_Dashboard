import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_dashboard/models/process_info.dart';

void main() {
  group('ProcessInfo.fromPsLine', () {
    test('parses normal ps line correctly', () {
      final line = ' 1234 root     12.5  3.2 node /app/server.js';
      final proc = ProcessInfo.fromPsLine(line);
      expect(proc.pid, 1234);
      expect(proc.user, 'root');
      expect(proc.cpuPercentage, 12.5);
      expect(proc.memPercentage, 3.2);
      expect(proc.command, 'node /app/server.js');
    });

    test('normalizes cpu when cores parameter is passed', () {
      final line = ' 5678 user     200.0  5.0 python3 worker.py';
      final proc = ProcessInfo.fromPsLine(line, cores: 4);
      expect(proc.pid, 5678);
      expect(proc.user, 'user');
      expect(proc.cpuPercentage, 50.0);
      expect(proc.memPercentage, 5.0);
      expect(proc.command, 'python3 worker.py');
    });

    test('clamps cpu and mem percentages to 100.0 maximum', () {
      final line = ' 9999 daemon   450.0 120.5 stress --cpu 8';
      final proc = ProcessInfo.fromPsLine(line, cores: 2);
      // 450.0 / 2 = 225.0 -> clamped to 100.0
      expect(proc.cpuPercentage, 100.0);
      expect(proc.memPercentage, 100.0);
    });

    test('handles malformed lines gracefully', () {
      final line = 'invalid line';
      final proc = ProcessInfo.fromPsLine(line);
      expect(proc.pid, 0);
      expect(proc.user, '?');
      expect(proc.cpuPercentage, 0.0);
      expect(proc.memPercentage, 0.0);
      expect(proc.command, 'invalid line');
    });
  });
}
