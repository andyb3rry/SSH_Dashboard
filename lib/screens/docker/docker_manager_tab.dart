import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/docker_container.dart';
import '../../providers/server_provider.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/disconnected_server_view.dart';

class DockerManagerTab extends StatefulWidget {
  const DockerManagerTab({super.key});

  @override
  State<DockerManagerTab> createState() => _DockerManagerTabState();
}

class _DockerManagerTabState extends State<DockerManagerTab> {
  String _searchQuery = '';

  void _showLogsSheet(BuildContext context, DockerContainer container) async {
    final provider = Provider.of<ServerProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _DockerLogsSheet(container: container, provider: provider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ServerProvider>(context);
    final isConnected = provider.status == ConnectionStatus.connected;

    if (!isConnected) {
      return const DisconnectedServerView(
        title: 'Docker Manager',
        icon: Icons.view_in_ar_outlined,
        iconColor: AppTheme.neonCyan,
        subtitle: 'Connect to an SSH server to view the full list of Docker containers and execute operational commands.',
      );
    }

    final allContainers = provider.containers;
    final filteredContainers = allContainers.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) || c.image.toLowerCase().contains(q) || c.id.toLowerCase().contains(q);
    }).toList();

    final runningCount = allContainers.where((c) => c.isRunning).length;

    return RefreshIndicator(
      color: AppTheme.neonCyan,
      backgroundColor: AppTheme.surfaceDark,
      onRefresh: () async => await provider.refreshData(),
      child: Column(
        children: [
          // Header e barra di ricerca
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.apps, color: AppTheme.neonCyan),
                        const SizedBox(width: 8),
                        Text(
                          'Docker Containers',
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Chip(
                      backgroundColor: AppTheme.surfaceDark,
                      side: const BorderSide(color: AppTheme.cardBorder),
                      label: Text(
                        'Running: $runningCount / ${allContainers.length}',
                        style: GoogleFonts.outfit(color: AppTheme.neonCyan, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search by name, image or ID...',
                    prefixIcon: const Icon(Icons.search, color: Colors.white60),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white60),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),

          if (provider.isLoadingAction)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(color: AppTheme.neonCyan, backgroundColor: AppTheme.obsidian),
            ),

          Expanded(
            child: filteredContainers.isEmpty
                ? Center(
                    child: Text(
                      allContainers.isEmpty ? 'No Docker Containers Found' : 'No container matches the search',
                      style: GoogleFonts.outfit(color: Colors.white60, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 120),
                    itemCount: filteredContainers.length,
                    itemBuilder: (ctx, idx) {
                      final container = filteredContainers[idx];
                      final isRunning = container.isRunning;
                      final isPaused = container.isPaused;

                      final statusColor = isRunning
                          ? AppTheme.emerald
                          : (isPaused ? AppTheme.amber : AppTheme.crimson);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: GlassCard(
                          borderColor: isRunning ? AppTheme.emerald.withValues(alpha: 0.5) : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(color: statusColor.withValues(alpha: 0.6), blurRadius: 8),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            container.name,
                                            style: GoogleFonts.outfit(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                                    ),
                                    child: Text(
                                      container.state.toUpperCase(),
                                      style: GoogleFonts.outfit(
                                        color: statusColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.layers_outlined, size: 16, color: Colors.white60),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      container.image,
                                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              if (container.ports.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.lan_outlined, size: 16, color: AppTheme.neonCyan),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        container.ports,
                                        style: GoogleFonts.outfit(color: AppTheme.neonCyan, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 14),
                              const Divider(color: AppTheme.cardBorder, height: 1),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _showLogsSheet(context, container),
                                    icon: const Icon(Icons.text_snippet_outlined, size: 18, color: AppTheme.neonCyan),
                                    label: Text('Logs', style: GoogleFonts.outfit(color: AppTheme.neonCyan, fontWeight: FontWeight.bold)),
                                  ),
                                  Row(
                                    children: [
                                      if (isRunning) ...[
                                        IconButton(
                                          icon: const Icon(Icons.refresh, color: AppTheme.amber),
                                          tooltip: 'Restart Container',
                                          onPressed: () => provider.restartContainer(container.id),
                                        ),
                                        const SizedBox(width: 6),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.crimson.withValues(alpha: 0.2),
                                            foregroundColor: AppTheme.crimson,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            side: const BorderSide(color: AppTheme.crimson),
                                          ),
                                          onPressed: () => provider.stopContainer(container.id),
                                          icon: const Icon(Icons.stop, size: 16),
                                          label: const Text('Stop'),
                                        ),
                                      ] else ...[
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.emerald.withValues(alpha: 0.2),
                                            foregroundColor: AppTheme.emerald,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            side: const BorderSide(color: AppTheme.emerald),
                                          ),
                                          onPressed: () => provider.startContainer(container.id),
                                          icon: const Icon(Icons.play_arrow, size: 16),
                                          label: const Text('Start'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DockerLogsSheet extends StatefulWidget {
  final DockerContainer container;
  final ServerProvider provider;

  const _DockerLogsSheet({required this.container, required this.provider});

  @override
  State<_DockerLogsSheet> createState() => _DockerLogsSheetState();
}

class _DockerLogsSheetState extends State<_DockerLogsSheet> {
  String _logs = 'Loading logs...';
  bool _loading = true;
  double _fontSize = 12.0;
  final ScrollController _logsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    StorageService().getTerminalFontSize().then((val) {
      if (mounted) setState(() => _fontSize = val);
    });
    _fetchLogs();
  }

  void _fetchLogs() async {
    setState(() => _loading = true);
    final text = await widget.provider.getContainerLogs(widget.container.id);
    if (mounted) {
      setState(() {
        _logs = text.isEmpty ? 'No logs available for this container.' : text;
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logsScrollController.hasClients) {
        _logsScrollController.jumpTo(_logsScrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _logsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.obsidian,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.terminal, color: AppTheme.neonCyan),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Logs: ${widget.container.name}',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white60),
                    tooltip: 'Copy logs to clipboard',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _logs));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Logs copied to clipboard')),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.neonCyan),
                    tooltip: 'Reload logs',
                    onPressed: _fetchLogs,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.cardBorder),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.neonCyan))
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: SingleChildScrollView(
                      controller: _logsScrollController,
                      child: SelectableText(
                        _logs,
                        style: GoogleFonts.jetBrainsMono(
                          color: AppTheme.emerald,
                          fontSize: _fontSize,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
