import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/server_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/disconnected_server_view.dart';
import '../../utils/command_validator.dart';
import '../../models/custom_command.dart';
import '../../widgets/custom_command_dialog.dart';
import 'cron_manager_section.dart';

class PowerControlTab extends StatefulWidget {
  const PowerControlTab({super.key});

  @override
  State<PowerControlTab> createState() => _PowerControlTabState();
}

class _PowerControlTabState extends State<PowerControlTab> {
  bool _isUpdating = false;
  String _updateLogs = '';
  final ScrollController _updateLogsScrollController = ScrollController();

  void _scrollUpdateLogsToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_updateLogsScrollController.hasClients) {
        _updateLogsScrollController.jumpTo(_updateLogsScrollController.position.maxScrollExtent);
      }
    });
  }

  /// Filters noisy output lines from streamed system update chunks.
  /// Supports: Debian/Ubuntu (apt/debconf), Fedora/RHEL (dnf/yum),
  /// Arch (pacman), openSUSE (zypper), and general noise patterns.
  String _filterUpdateOutput(String chunk) {
    final lines = chunk.split('\n');
    final filtered = <String>[];
    bool lastLineWasEmpty = false;

    for (final line in lines) {
      final trimmed = line.trim();

      // --- General noise ---
      // Collapse consecutive empty lines
      if (trimmed.isEmpty) {
        if (lastLineWasEmpty) continue;
        lastLineWasEmpty = true;
        filtered.add(line);
        continue;
      }
      lastLineWasEmpty = false;

      // --- Debian / Ubuntu (apt / dpkg / debconf) ---
      if (trimmed.startsWith('WARNING: apt does not have a stable CLI interface')) continue;
      if (trimmed.startsWith('debconf: unable to initialize frontend:')) continue;
      if (trimmed.startsWith('debconf: (') && trimmed.endsWith(')')) continue;
      if (trimmed.startsWith('debconf: falling back to frontend:')) continue;
      // Intermediate dpkg "Reading database" progress (keep 100% and final count line)
      if (RegExp(r'^\(Reading database \.\.\. \d+%$').hasMatch(trimmed)) continue;
      if (trimmed == 'Preconfiguring packages ...') continue;

      // --- Fedora / RHEL / CentOS (dnf / yum) ---
      // Metadata expiration check noise
      if (trimmed.startsWith('Last metadata expiration check:')) continue;
      // GPG key import noise lines
      if (trimmed.startsWith('Importing GPG key')) continue;
      if (trimmed.startsWith('Key imported successfully')) continue;
      // Download progress lines (e.g. "Updates    [===   ] ---")
      if (RegExp(r'^\S+\s+\[=*\s*\]\s').hasMatch(trimmed)) continue;
      // dnf/yum progress bar lines with percentages and speed
      if (RegExp(r'^\(\d+/\d+\):\s+\S+.*\s+\d+(\.\d+)?\s*(kB|MB|B)/s').hasMatch(trimmed)) continue;

      // --- Arch Linux (pacman) ---
      // Progress percentage lines for keyring, integrity, package loading
      if (RegExp(r'^\(\s*\d+/\d+\)\s+(checking keys in keyring|checking package integrity|loading package files|checking for file conflicts|checking available disk space)').hasMatch(trimmed)) continue;
      // pacman download/install progress bars (e.g. " downloading linux   [####----] 45%")
      if (RegExp(r'^\s*(downloading|installing|upgrading|removing)\s+\S+.*\[#+\-*\]\s*\d+%').hasMatch(trimmed)) continue;
      // pacman ":: Retrieving packages..." percentage lines
      if (RegExp(r'^::\s+Retrieving packages\s*\.\.\.').hasMatch(trimmed)) continue;

      // --- openSUSE (zypper) ---
      // Zypper progress lines "Loading repository data..."
      if (trimmed.startsWith('Loading repository data...')) continue;
      if (trimmed.startsWith('Reading installed packages...')) continue;

      filtered.add(line);
    }
    return filtered.join('\n');
  }

  @override
  void dispose() {
    _updateLogsScrollController.dispose();
    super.dispose();
  }

  void _confirmPowerAction(BuildContext context, {required bool isReboot}) {
    final provider = Provider.of<ServerProvider>(context, listen: false);
    // [H1] Don't pre-populate sudo password — user must type it manually
    final passwordController = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isReboot ? Icons.restart_alt : Icons.power_settings_new,
                color: AppTheme.crimson,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(isReboot ? 'Confirm Reboot (sudo)' : 'Confirm Shutdown (sudo)'),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isReboot
                    ? 'You are about to send a reboot command to the Linux server. Root/sudo password is required for confirmation (`sudo -S`):'
                    : 'You are about to shut down the Linux server. Root/sudo password is required for confirmation:',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Sudo (Root) Password',
                  prefixIcon: const Icon(Icons.security, color: AppTheme.crimson),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white60),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                passwordController.clear();
                Navigator.pop(ctx);
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
              onPressed: () {
                final pwd = passwordController.text;
                passwordController.clear();
                Navigator.pop(ctx);
                if (isReboot) {
                  provider.rebootServer(pwd);
                } else {
                  provider.shutdownServer(pwd);
                }
              },
              child: Text(isReboot ? 'CONFIRM & REBOOT' : 'CONFIRM & SHUTDOWN'),
            ),
          ],
        ),
      ),
    ).then((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        passwordController.dispose();
      });
    });
  }

  void _runSystemUpdate(BuildContext context) {
    final provider = Provider.of<ServerProvider>(context, listen: false);
    final command = provider.activeProfile?.customUpdateCommand ?? 'sudo apt update && sudo apt upgrade -y';
    final validation = CommandValidator.validateUpdateCommand(command);
    // [H1] Don't pre-populate sudo password — user must type it manually
    final passwordController = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                validation.isBlocked
                    ? Icons.gpp_bad
                    : validation.isWarning
                        ? Icons.warning_amber_rounded
                        : Icons.system_update_alt,
                color: validation.isBlocked
                    ? AppTheme.crimson
                    : validation.isWarning
                        ? AppTheme.amber
                        : AppTheme.emerald,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  validation.isBlocked ? 'Security Block: Update' : 'Confirm System Update',
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exact command to execute on Linux (`sudo -S`):',
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.obsidian,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: validation.isBlocked
                          ? AppTheme.crimson
                          : validation.isWarning
                              ? AppTheme.amber
                              : AppTheme.cardBorder,
                    ),
                  ),
                  child: SelectableText(
                    command,
                    style: GoogleFonts.firaCode(
                      color: validation.isBlocked
                          ? AppTheme.crimson
                          : validation.isWarning
                              ? AppTheme.amber
                              : AppTheme.neonCyan,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (validation.isBlocked)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.crimson.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.crimson),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.crimson, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            validation.message ?? 'Command blocked due to security risks.',
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (validation.isWarning)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.amber),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.amber, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            validation.message ?? 'Non-standard update command.',
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!validation.isBlocked) ...[
                  Text(
                    'To execute this command with root privileges, confirm or enter your sudo password:',
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13.5),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    style: GoogleFonts.outfit(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Sudo (Root) Password',
                      prefixIcon: const Icon(Icons.security, color: AppTheme.emerald),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white60),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                passwordController.clear();
                Navigator.pop(ctx);
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            if (!validation.isBlocked)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: validation.isWarning ? AppTheme.amber : AppTheme.emerald,
                  foregroundColor: AppTheme.obsidian,
                ),
                onPressed: () async {
                  final pwd = passwordController.text;
                  passwordController.clear();
                  Navigator.pop(ctx);
                  setState(() {
                    _isUpdating = true;
                    _updateLogs = '🚀 Starting Linux system update via sudo -S...\nRunning command: $command\n\n';
                  });
                  _scrollUpdateLogsToBottom();

                  try {
                    await provider.executeSudoCommandStreamed(
                      command,
                      pwd,
                      onStdout: (chunk) {
                        if (mounted) {
                          final filtered = _filterUpdateOutput(chunk);
                          if (filtered.trim().isNotEmpty) {
                            setState(() {
                              _updateLogs += filtered;
                            });
                            _scrollUpdateLogsToBottom();
                          }
                        }
                      },
                      onStderr: (chunk) {
                        if (mounted) {
                          final filtered = _filterUpdateOutput(chunk);
                          if (filtered.trim().isNotEmpty) {
                            setState(() {
                              _updateLogs += filtered;
                            });
                            _scrollUpdateLogsToBottom();
                          }
                        }
                      },
                    );
                    if (mounted) {
                      setState(() {
                        _updateLogs += '\n\n✅ Update completed successfully!';
                        _isUpdating = false;
                      });
                      _scrollUpdateLogsToBottom();
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        _updateLogs += '\n❌ Error during update:\n$e';
                        _isUpdating = false;
                      });
                      _scrollUpdateLogsToBottom();
                    }
                  }
                },
                child: Text(
                  validation.isWarning ? 'CONFIRM WARNING & UPDATE' : 'CONFIRM & UPDATE',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    ).then((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        passwordController.dispose();
      });
    });
  }

  void _openCustomCommandDialog({CustomCommand? command}) async {
    final result = await showDialog<CustomCommand>(
      context: context,
      builder: (_) => CustomCommandDialog(existingCommand: command),
    );

    if (result != null) {
      final provider = Provider.of<ServerProvider>(context, listen: false);
      if (provider.activeProfile != null) {
        final profile = provider.getFullProfile(provider.activeProfile!.id);
        if (profile == null) return;
        List<CustomCommand> updatedCommands = List.from(profile.customCommands);
        
        final existingIndex = updatedCommands.indexWhere((c) => c.id == result.id);
        if (existingIndex >= 0) {
          updatedCommands[existingIndex] = result;
        } else {
          updatedCommands.add(result);
        }
        
        final updatedProfile = profile.copyWith(customCommands: updatedCommands);
        await provider.saveProfile(updatedProfile);
        setState(() {}); // Re-build UI to show new commands
      }
    }
  }

  void _deleteCustomCommand(CustomCommand command) async {
    final provider = Provider.of<ServerProvider>(context, listen: false);
    if (provider.activeProfile != null) {
      final profile = provider.getFullProfile(provider.activeProfile!.id);
      if (profile == null) return;
      List<CustomCommand> updatedCommands = List.from(profile.customCommands);
      updatedCommands.removeWhere((c) => c.id == command.id);
      
      final updatedProfile = profile.copyWith(customCommands: updatedCommands);
      await provider.saveProfile(updatedProfile);
      setState(() {});
    }
  }

  void _executeCustomCommand(CustomCommand command) async {
    final provider = Provider.of<ServerProvider>(context, listen: false);
    setState(() {
      _updateLogs += '\n[${DateTime.now().toIso8601String().substring(11, 19)}] Executing: ${command.title}\n> ${command.command}\n';
    });
    _scrollUpdateLogsToBottom();
    try {
      final result = await provider.executeCommand(command.command);
      setState(() {
        _updateLogs += result.trim();
        _updateLogs += '\n';
      });
      _scrollUpdateLogsToBottom();
    } catch (e) {
      setState(() {
        _updateLogs += 'Error: $e\n';
      });
      _scrollUpdateLogsToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ServerProvider>(context);
    final isConnected = provider.status == ConnectionStatus.connected;

    if (!isConnected) {
      return const DisconnectedServerView(
        title: 'System Control',
        icon: Icons.bolt_outlined,
        iconColor: AppTheme.amber,
        subtitle: 'Connect to an SSH server to perform remote reboots, emergency shutdowns, system updates, and manage cronjobs.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700 && MediaQuery.of(context).orientation == Orientation.landscape;

        // --- Power buttons ---
        Widget powerSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Power Control',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    onTap: () => _confirmPowerAction(context, isReboot: true),
                    borderColor: AppTheme.amber.withValues(alpha: 0.6),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.amber.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.restart_alt, color: AppTheme.amber, size: 32),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Reboot Server',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'sudo reboot',
                          style: GoogleFonts.jetBrainsMono(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: GlassCard(
                    onTap: () => _confirmPowerAction(context, isReboot: false),
                    borderColor: AppTheme.crimson.withValues(alpha: 0.6),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.crimson.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.power_settings_new, color: AppTheme.crimson, size: 32),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Shutdown Server',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'sudo poweroff',
                          style: GoogleFonts.jetBrainsMono(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

        // --- Custom Commands ---
        final customCommands = provider.activeProfile?.customCommands ?? [];
        Widget customCommandsSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Custom Commands',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                TextButton.icon(
                  onPressed: () => _openCustomCommandDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GlassCard(
              borderColor: AppTheme.emerald.withValues(alpha: 0.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.system_update, color: AppTheme.emerald),
                      const SizedBox(width: 10),
                      Text(
                        'Update',
                        style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configured command for this profile:',
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.obsidian,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Text(
                      provider.activeProfile?.customUpdateCommand ?? 'sudo apt update && sudo apt upgrade -y',
                      style: GoogleFonts.jetBrainsMono(color: AppTheme.neonCyan, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        foregroundColor: AppTheme.obsidian,
                      ),
                      onPressed: _isUpdating ? null : () => _runSystemUpdate(context),
                      icon: _isUpdating
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.rocket_launch),
                      label: Text(_isUpdating ? 'Updating...' : 'Start Update'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (customCommands.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Center(
                  child: Text(
                    'No custom commands configured.',
                    style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                itemCount: customCommands.length,
                itemBuilder: (ctx, i) {
                  final cmd = customCommands[i];
                  IconData iconData = Icons.terminal;
                  switch (cmd.iconName) {
                    case 'storage': iconData = Icons.storage; break;
                    case 'save': iconData = Icons.save; break;
                    case 'wifi': iconData = Icons.wifi; break;
                    case 'network_check': iconData = Icons.network_check; break;
                    case 'memory': iconData = Icons.memory; break;
                    case 'build': iconData = Icons.build; break;
                    case 'play_arrow': iconData = Icons.play_arrow; break;
                    case 'bolt': iconData = Icons.bolt; break;
                    case 'web': iconData = Icons.language; break;
                  }
                  
                  return GlassCard(
                    onTap: () => _executeCustomCommand(cmd),
                    borderColor: AppTheme.neonCyan.withValues(alpha: 0.3),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(iconData, color: AppTheme.neonCyan, size: 28),
                              const SizedBox(height: 8),
                              Text(
                                cmd.title,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 16, color: Colors.white54),
                            color: AppTheme.surfaceDark,
                            onSelected: (val) {
                              if (val == 'edit') {
                                _openCustomCommandDialog(command: cmd);
                              } else if (val == 'delete') {
                                _deleteCustomCommand(cmd);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
                              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.crimson))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 144),
          child: isWide
              // ====== WIDE (tablet): two-column layout ======
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column: Power + Update + terminal output
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          powerSection,
                          const SizedBox(height: 24),
                          customCommandsSection,
                          const SizedBox(height: 18),
                          Text(
                            'Terminal Output',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 220,
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: SingleChildScrollView(
                              controller: _updateLogsScrollController,
                              child: SelectableText(
                                _updateLogs.isEmpty ? 'Awaiting command execution...' : _updateLogs,
                                style: GoogleFonts.jetBrainsMono(
                                  color: _updateLogs.isEmpty ? Colors.white30 : AppTheme.emerald, 
                                  fontSize: 12, 
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    // Right column: Cron Manager
                    const Expanded(
                      child: CronManagerSection(),
                    ),
                  ],
                )
              // ====== NARROW (phone): stacked ======
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    powerSection,
                    const SizedBox(height: 24),
                    customCommandsSection,
                    const SizedBox(height: 18),
                    const SizedBox(height: 18),
                    Text(
                      'Terminal Output',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 220,
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: SingleChildScrollView(
                        controller: _updateLogsScrollController,
                        child: SelectableText(
                          _updateLogs.isEmpty ? 'Awaiting command execution...' : _updateLogs,
                          style: GoogleFonts.jetBrainsMono(
                            color: _updateLogs.isEmpty ? Colors.white30 : AppTheme.emerald, 
                            fontSize: 12, 
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const CronManagerSection(),
                  ],
                ),
        );
      },
    );
  }
}
