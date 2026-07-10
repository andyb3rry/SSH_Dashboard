import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/process_info.dart';
import '../../providers/server_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ProcessManagerSheet extends StatefulWidget {
  const ProcessManagerSheet({super.key});

  @override
  State<ProcessManagerSheet> createState() => _ProcessManagerSheetState();
}

class _ProcessManagerSheetState extends State<ProcessManagerSheet> {
  List<ProcessInfo> _processes = [];
  List<ProcessInfo> _filteredProcesses = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'cpu'; // 'cpu', 'mem', 'pid'
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadProcesses();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadProcesses(silent: true));
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProcesses({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }
    final provider = Provider.of<ServerProvider>(context, listen: false);
    final list = await provider.fetchRunningProcesses();
    if (mounted) {
      setState(() {
        _processes = list;
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<ProcessInfo> filtered = _processes.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.command.toLowerCase().contains(q) ||
          p.user.toLowerCase().contains(q) ||
          p.pid.toString().contains(q);
    }).toList();

    if (_sortBy == 'cpu') {
      filtered.sort((a, b) => b.cpuPercentage.compareTo(a.cpuPercentage));
    } else if (_sortBy == 'mem') {
      filtered.sort((a, b) => b.memPercentage.compareTo(a.memPercentage));
    } else if (_sortBy == 'pid') {
      filtered.sort((a, b) => a.pid.compareTo(b.pid));
    }
    _filteredProcesses = filtered;
  }

  void _confirmSendSignal(ProcessInfo process, int signal, String signalName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              signal == 9 ? Icons.dangerous : Icons.warning_amber_rounded,
              color: signal == 9 ? AppTheme.crimson : AppTheme.amber,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('Confirm Signal $signalName')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Do you want to send signal $signalName (-$signal) to the process below?',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.obsidian,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Command: ${process.command}', style: GoogleFonts.firaCode(fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('PID: ${process.pid} | User: ${process.user}', style: GoogleFonts.firaCode(color: AppTheme.neonCyan, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Note: if the process belongs to another user (e.g. root), you will be prompted for the sudo password.',
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: signal == 9 ? AppTheme.crimson : AppTheme.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _executeSignal(process, signal, signalName);
            },
            child: Text('Send $signalName', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeSignal(ProcessInfo process, int signal, String signalName, [String? sudoPassword]) async {
    final provider = Provider.of<ServerProvider>(context, listen: false);
    try {
      await provider.sendSignalToProcess(process.pid, signal, sudoPassword);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.emerald,
            content: Text('Signal $signalName sent to PID ${process.pid} (${process.command}).'),
          ),
        );
        _loadProcesses();
      }
    } catch (e) {
      if (mounted) {
        // Se richiede sudo o permessi negati, chiediamo la password
        final errorStr = e.toString().toLowerCase();
        if (sudoPassword == null && (errorStr.contains('permission denied') || errorStr.contains('operation not permitted') || process.user != provider.activeProfile?.username)) {
          _askSudoPasswordForSignal(process, signal, signalName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.crimson,
              content: Text('Error sending signal: $e'),
            ),
          );
        }
      }
    }
  }

  void _askSudoPasswordForSignal(ProcessInfo process, int signal, String signalName) {
    final pwdController = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.security, color: AppTheme.amber),
              const SizedBox(width: 8),
              const Text('Root Privileges Required'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Process ${process.command} (PID ${process.pid}) requires elevated privileges (sudo kill -$signal) to be terminated. Enter your sudo password:',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pwdController,
                obscureText: obscure,
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Sudo password',
                  prefixIcon: const Icon(Icons.lock, color: AppTheme.neonCyan),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white60),
                    onPressed: () => setStateDialog(() => obscure = !obscure),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                pwdController.clear();
                Navigator.pop(ctx);
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.amber, foregroundColor: Colors.black),
              onPressed: () {
                final pwd = pwdController.text;
                pwdController.clear();
                Navigator.pop(ctx);
                _executeSignal(process, signal, signalName, pwd);
              },
              child: const Text('Execute Sudo Kill', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ).then((_) => pwdController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.neonCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.neonCyan),
                ),
                child: const Icon(Icons.memory, color: AppTheme.neonCyan),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Process Management (Task Manager)',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${_processes.length} active processes monitored',
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.white60),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.neonCyan),
                    onPressed: () => _loadProcesses(),
                    tooltip: 'Refresh list',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by name, user or PID...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.neonCyan, size: 20),
                    filled: true,
                    fillColor: AppTheme.obsidian,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _applyFilters();
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppTheme.obsidian,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: DropdownButton<String>(
                  value: _sortBy,
                  underline: const SizedBox(),
                  dropdownColor: AppTheme.obsidian,
                  icon: const Icon(Icons.sort, color: AppTheme.neonCyan, size: 20),
                  items: [
                    DropdownMenuItem(value: 'cpu', child: Text('Sort: % CPU', style: GoogleFonts.outfit(color: Colors.white, fontSize: 13))),
                    DropdownMenuItem(value: 'mem', child: Text('Sort: % Mem', style: GoogleFonts.outfit(color: Colors.white, fontSize: 13))),
                    DropdownMenuItem(value: 'pid', child: Text('Sort: PID', style: GoogleFonts.outfit(color: Colors.white, fontSize: 13))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _sortBy = val;
                        _applyFilters();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.neonCyan))
                : _filteredProcesses.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty ? 'No processes found.' : 'No match for "$_searchQuery".',
                          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 15),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredProcesses.length,
                        itemBuilder: (ctx, idx) {
                          final process = _filteredProcesses[idx];
                          final isRoot = process.user == 'root';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassCard(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    constraints: const BoxConstraints(minWidth: 52, minHeight: 44),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isRoot ? AppTheme.crimson.withValues(alpha: 0.15) : AppTheme.obsidian,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isRoot ? AppTheme.crimson : AppTheme.cardBorder),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('PID', style: GoogleFonts.outfit(fontSize: 9, color: Colors.white54)),
                                        const SizedBox(height: 1),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '${process.pid}',
                                            style: GoogleFonts.firaCode(fontSize: 12, fontWeight: FontWeight.bold, color: isRoot ? AppTheme.crimson : AppTheme.neonCyan),
                                          ),
                                        ),
                                      ],
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
                                                process.command,
                                                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.obsidian,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.white24),
                                              ),
                                              child: Text(
                                                process.user,
                                                style: GoogleFonts.firaCode(fontSize: 10, color: isRoot ? AppTheme.amber : Colors.white70),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.bolt, size: 13, color: AppTheme.amber.withValues(alpha: 0.8)),
                                                Text(
                                                  'CPU: ${process.cpuPercentage.toStringAsFixed(1)}%',
                                                  style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.amber),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.memory, size: 13, color: AppTheme.neonPurple.withValues(alpha: 0.8)),
                                                Text(
                                                  'MEM: ${process.memPercentage.toStringAsFixed(1)}%',
                                                  style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.neonPurple),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                                    color: AppTheme.surfaceDark,
                                    onSelected: (val) {
                                      if (val == 'term') _confirmSendSignal(process, 15, 'SIGTERM');
                                      if (val == 'kill') _confirmSendSignal(process, 9, 'SIGKILL');
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'term',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.warning_amber_rounded, color: AppTheme.amber, size: 18),
                                            const SizedBox(width: 8),
                                            Text('SIGTERM (-15) Terminate', style: GoogleFonts.outfit(color: Colors.white)),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'kill',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.dangerous, color: AppTheme.crimson, size: 18),
                                            const SizedBox(width: 8),
                                            Text('SIGKILL (-9) Force Kill', style: GoogleFonts.outfit(color: AppTheme.crimson, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
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
