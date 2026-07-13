import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/server_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/disconnected_server_view.dart';
import '../../utils/command_validator.dart';
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

  @override
  void dispose() {
    _updateLogsScrollController.dispose();
    super.dispose();
  }

  void _confirmPowerAction(BuildContext context, {required bool isReboot}) {
    final provider = Provider.of<ServerProvider>(context, listen: false);
    final passwordController = TextEditingController(text: provider.activeProfile?.password ?? '');
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
    ).then((_) => passwordController.dispose());
  }

  void _runSystemUpdate(BuildContext context) {
    final provider = Provider.of<ServerProvider>(context, listen: false);
    final command = provider.activeProfile?.customUpdateCommand ?? 'sudo apt update && sudo apt upgrade -y';
    final validation = CommandValidator.validateUpdateCommand(command);
    final passwordController = TextEditingController(text: provider.activeProfile?.password ?? '');
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
                          setState(() {
                            _updateLogs += chunk;
                          });
                          _scrollUpdateLogsToBottom();
                        }
                      },
                      onStderr: (chunk) {
                        if (mounted) {
                          setState(() {
                            _updateLogs += chunk;
                          });
                          _scrollUpdateLogsToBottom();
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
    ).then((_) => passwordController.dispose());
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Power Actions Section
          Text(
            'Power Control (Power & Reboot)',
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
          const SizedBox(height: 24),

          // Package Maintenance and System Update
          Text(
            'Package Maintenance & System Update',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
          const SizedBox(height: 18),

          // Console Output
          if (_updateLogs.isNotEmpty) ...[
            Text(
              'Update Terminal Output',
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
                  _updateLogs,
                  style: GoogleFonts.jetBrainsMono(color: AppTheme.emerald, fontSize: 12, height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          const CronManagerSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
