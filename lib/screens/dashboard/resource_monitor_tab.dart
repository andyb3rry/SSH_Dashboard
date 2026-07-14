import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/server_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/stat_gauge.dart';
import '../../widgets/disconnected_server_view.dart';
import 'process_manager_sheet.dart';

class ResourceMonitorTab extends StatelessWidget {
  const ResourceMonitorTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ServerProvider>(context);
    final metrics = provider.metrics;
    final isConnected = provider.status == ConnectionStatus.connected;

    if (!isConnected) {
      return const DisconnectedServerView(
        title: 'No Server Connected',
        icon: Icons.cloud_off,
        iconColor: AppTheme.crimson,
        subtitle: 'Connect to an SSH server to view real-time system metrics, monitor CPU, memory, network, and storage.',
      );
    }

    return RefreshIndicator(
      color: AppTheme.neonCyan,
      backgroundColor: AppTheme.surfaceDark,
      onRefresh: () async => await provider.refreshData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header del server connesso
            GlassCard(
              isGlow: true,
              borderColor: AppTheme.neonCyan.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.neonCyan.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.memory, color: AppTheme.neonCyan),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.activeProfile?.name ?? 'SSH Server',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${metrics.osRelease} (${metrics.kernelVersion})',
                              style: GoogleFonts.outfit(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (provider.isRefreshing)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.neonCyan),
                          ),
                        ),
                      IconButton(
                        icon: Icon(
                          provider.isPolling ? Icons.pause_circle_filled : Icons.play_circle_fill,
                          color: provider.isPolling ? AppTheme.emerald : Colors.white60,
                          size: 28,
                        ),
                        tooltip: provider.isPolling ? 'Realtime Monitoring Active' : 'Enable Realtime Polling',
                        onPressed: () => provider.togglePolling(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.cardBorder, height: 1),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, color: AppTheme.neonPurple, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Uptime: ${metrics.uptimeString}',
                              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.speed, color: AppTheme.amber, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Load: ${metrics.loadAvg}',
                              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pulsante rapido Process Manager & Task Manager
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              borderColor: AppTheme.neonCyan.withValues(alpha: 0.4),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const ProcessManagerSheet(),
                );
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.neonCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.list_alt, color: AppTheme.neonCyan),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Task Manager',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Monitor and manage running processes',
                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.white60),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.neonCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const ProcessManagerSheet(),
                      );
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text('Open', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Indice di CPU e Memoria ad anello
            Text(
              'Risorse Utilizzate',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    child: StatGauge(
                      title: 'CPU',
                      percentage: metrics.cpuUsagePercentage,
                      subtitle: metrics.cpuModel,
                      icon: Icons.developer_board,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: GlassCard(
                    child: StatGauge(
                      title: 'Memory (RAM)',
                      percentage: metrics.memoryUsagePercentage,
                      subtitle: '${metrics.memoryUsedMb.toStringAsFixed(0)} / ${metrics.memoryTotalMb.toStringAsFixed(0)} MB',
                      icon: Icons.memory,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card Rete e Card Temperatura
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row(
                          children: [
                            const Icon(Icons.swap_vert, color: AppTheme.neonCyan, size: 20),
                            const SizedBox(width: 8),
                            Text('Network (Rx / Tx)', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('DL: ${metrics.networkDownloadSpeedKbps.toStringAsFixed(1)} KB/s', style: GoogleFonts.firaCode(fontSize: 13, color: AppTheme.emerald, fontWeight: FontWeight.bold)),
                                Text('UL: ${metrics.networkUploadSpeedKbps.toStringAsFixed(1)} KB/s', style: GoogleFonts.firaCode(fontSize: 13, color: AppTheme.neonCyan, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Icon(Icons.network_check, color: Colors.white24, size: 28),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.thermostat, color: metrics.cpuTemperatureCelsius > 75 ? AppTheme.crimson : AppTheme.amber, size: 20),
                            const SizedBox(width: 8),
                            Text('CPU Temp', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              metrics.cpuTemperatureCelsius < 0
                                  ? 'N/A'
                                  : '${metrics.cpuTemperatureCelsius.toStringAsFixed(1)} °C',
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: metrics.cpuTemperatureCelsius > 75 ? AppTheme.crimson : AppTheme.amber,
                              ),
                            ),
                            const Icon(Icons.device_thermostat, color: Colors.white24, size: 28),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Archiviazione Disco (Storage)
            Text(
              'Storage',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            if (metrics.disks.isEmpty)
              _buildSingleDiskCard(metrics.diskUsagePercentage, metrics.diskUsedGb, metrics.diskTotalGb, '/', 'Root Filesystem')
            else
              ...metrics.disks.map((disk) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildSingleDiskCard(disk.usagePercentage, disk.usedGb, disk.totalGb, disk.mountPoint, disk.filesystem),
                  )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleDiskCard(double pct, double usedGb, double totalGb, String mountPoint, String filesystem) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.storage_rounded, color: AppTheme.neonCyan),
                  const SizedBox(width: 10),
                  Text(
                    mountPoint,
                    style: GoogleFonts.firaCode(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '($filesystem)',
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.neonCyan),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (pct / 100.0).clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: AppTheme.obsidian,
              valueColor: AlwaysStoppedAnimation<Color>(
                pct > 85 ? AppTheme.crimson : AppTheme.neonCyan,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Used: ${usedGb.toStringAsFixed(1)} GB',
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
              ),
              Text(
                'Total: ${totalGb.toStringAsFixed(1)} GB',
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
