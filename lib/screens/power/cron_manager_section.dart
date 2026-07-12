import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/cron_job.dart';
import '../../providers/server_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../utils/command_validator.dart';

class CronManagerSection extends StatefulWidget {
  const CronManagerSection({super.key});

  @override
  State<CronManagerSection> createState() => _CronManagerSectionState();
}

class _CronManagerSectionState extends State<CronManagerSection> {
  bool _isLoading = false;
  bool _isRootTab = false;
  List<CronJob> _jobs = [];
  String? _errorMessage;
  String? _activeExecutionOutput;
  bool _isExecutingNow = false;
  int _logDaysFilter = 7;
  final ScrollController _execScrollController = ScrollController();

  void _scrollExecToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_execScrollController.hasClients) {
        _execScrollController.jumpTo(_execScrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCronJobs();
    });
  }

  Future<String?> _getSudoPassword(BuildContext context, {bool forceConfirmation = false, String actionName = 'Root Crontab Access', String? exactCommand}) async {
    final provider = Provider.of<ServerProvider>(context, listen: false);
    final storedPwd = provider.activeProfile?.password ?? '';
    if (!forceConfirmation && storedPwd.isNotEmpty) return storedPwd;

    final passwordController = TextEditingController(text: storedPwd);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.obsidian,
        title: Row(
          children: [
            const Icon(Icons.security, color: AppTheme.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Confirm $actionName',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
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
                'You are about to modify or execute root crontab ($actionName). Please confirm your sudo password to proceed:',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              if (exactCommand != null && exactCommand.isNotEmpty) ...[
                Text(
                  'Exact Root Crontab entry / command:',
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.amber),
                  ),
                  child: SelectableText(
                    exactCommand,
                    style: GoogleFonts.firaCode(color: AppTheme.amber, fontSize: 12.5),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Password...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              passwordController.clear();
              Navigator.pop(ctx, null);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.amber, foregroundColor: AppTheme.obsidian),
            onPressed: () {
              final text = passwordController.text;
              passwordController.clear();
              Navigator.pop(ctx, text);
            },
            child: const Text('CONFIRM & EXECUTE'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    return res;
  }

  /// Estimate the minimum interval in days between executions for a given cron schedule.
  /// Returns 0 for sub-daily schedules, 1 for daily, 7 for weekly, 30 for monthly, etc.
  int _estimateScheduleIntervalDays(String schedule) {
    if (schedule.startsWith('@')) {
      switch (schedule) {
        case '@reboot': return 0;
        case '@hourly': return 0;
        case '@daily': case '@midnight': return 1;
        case '@weekly': return 7;
        case '@monthly': return 30;
        case '@yearly': case '@annually': return 365;
        default: return 0;
      }
    }
    final parts = schedule.split(RegExp(r'\s+'));
    if (parts.length != 5) return 0;
    final minPart = parts[0];
    final hrPart = parts[1];
    final dayPart = parts[2];
    final monthPart = parts[3];
    final dowPart = parts[4];

    // Yearly: specific month and day
    if (monthPart != '*' && dayPart != '*') return 365;
    // Monthly: specific day of month
    if (dayPart != '*' && monthPart == '*' && dowPart == '*') return 30;
    // Weekly: specific day of week
    if (dowPart != '*' && dayPart == '*') return 7;
    // Daily: specific hour and minute
    if (hrPart != '*' && !hrPart.startsWith('*/') && minPart != '*') return 1;
    // Sub-daily
    return 0;
  }

  Future<void> _fetchCronJobs() async {
    final provider = Provider.of<ServerProvider>(context, listen: false);
    if (!provider.isConnected) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String crontabText = '';
      String? sudoPwd;

      // Step 1: Fetch crontab only (no bulk log fetch needed)
      if (_isRootTab) {
        sudoPwd = await _getSudoPassword(context, forceConfirmation: false, actionName: 'Read Root Crontab');
        if (sudoPwd == null && (provider.activeProfile?.password ?? '').isEmpty) {
          setState(() => _isLoading = false);
          return;
        }
        crontabText = await provider.executeSudoCommand('crontab -l 2>/dev/null || true', sudoPwd ?? '');
      } else {
        crontabText = await provider.executeCommand('crontab -l 2>/dev/null || true');
      }

      // Step 2: Parse crontab entries (without logs)
      final parsedJobs = _parseCrontab(crontabText, _isRootTab);

      // Step 3: Per-job targeted log search using unique command tokens.
      // Each job gets its own grep against journalctl/syslog, strictly within _logDaysFilter.
      // This avoids the old approach of fetching thousands of bulk log lines.
      final String daysAgo = _logDaysFilter == 1 ? '1 day' : '$_logDaysFilter days';

      for (int idx = 0; idx < parsedJobs.length; idx++) {
        if (!mounted) break;
        final job = parsedJobs[idx];

        // Skip @reboot jobs — they don't produce periodic log entries
        if (job.schedule == '@reboot') continue;

        final uniqueTokens = _extractUniqueTokens(job.command);
        if (uniqueTokens.isEmpty) continue;

        // Use the most distinctive token (longest) for grep
        uniqueTokens.sort((a, b) => b.length.compareTo(a.length));
        final grepPattern = uniqueTokens.first.replaceAll(RegExp(r'[^a-zA-Z0-9_./-]'), '.');

        try {
          String targetedLog = '';
          // Search journalctl first, fall back to syslog/cron.log files
          final searchCmd =
              'line=\$(timeout 4s journalctl -u cron -u crond --since "$daysAgo ago" --no-pager 2>/dev/null '
              '| grep -i "$grepPattern" | tail -n 1); '
              'if [ -z "\$line" ]; then '
              'line=\$(grep -h -i "$grepPattern" /var/log/syslog /var/log/cron /var/log/cron.log 2>/dev/null | tail -n 1); '
              'fi; echo "\$line"';

          if (_isRootTab) {
            targetedLog = await provider.executeSudoCommand(searchCmd, sudoPwd ?? '');
          } else {
            targetedLog = await provider.executeCommand(searchCmd);
          }

          final trimmed = targetedLog.trim();
          if (trimmed.isNotEmpty && _matchLogToCommand(trimmed, job.command)) {
            final match = RegExp(r'\s+(CRON|cron|crond|CMD)\b').firstMatch(trimmed);
            String? foundLog;
            if (match != null && match.start > 0) {
              foundLog = trimmed.substring(0, match.start).trim();
            } else {
              foundLog = trimmed;
            }
            if (foundLog.isNotEmpty) {
              parsedJobs[idx] = CronJob(
                rawLine: job.rawLine,
                schedule: job.schedule,
                command: job.command,
                lastExecutionLog: foundLog,
                isRoot: job.isRoot,
              );
            }
          }
        } catch (_) {
          // Search failed silently — job keeps "not found" status
        }
      }

      if (mounted) {
        setState(() {
          _jobs = parsedJobs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error reading crontab: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<CronJob> _parseCrontab(String crontabOutput, bool isRoot) {
    final List<CronJob> result = [];
    final lines = crontabOutput.split('\n');

    for (var raw in lines) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      String schedule = '';
      String command = '';

      if (line.startsWith('@')) {
        final parts = line.split(RegExp(r'\s+'));
        if (parts.isNotEmpty) {
          schedule = parts[0];
          command = line.substring(schedule.length).trim();
        }
      } else {
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 6) {
          schedule = parts.sublist(0, 5).join(' ');
          command = parts.sublist(5).join(' ');
        } else {
          schedule = '* * * * *';
          command = line;
        }
      }

      if (command.isEmpty) continue;

      result.add(CronJob(
        rawLine: line,
        schedule: schedule,
        command: command,
        lastExecutionLog: null,
        isRoot: isRoot,
      ));
    }

    return result;
  }

  static const Set<String> _genericTokens = {
    'mountpoint', 'rsync', 'docker', 'exec', 'sh', 'bash', 'python', 'python3', 'php', 'node',
    'curl', 'wget', 'tar', 'gzip', 'zip', 'unzip', 'chown', 'chmod', 'cp', 'mv', 'rm', 'cat',
    'echo', 'grep', 'find', 'sed', 'awk', 'xargs', 'tee', 'nice', 'ionice', 'sudo', 'su', 'cd',
    'test', 'sleep', 'date', 'time', 'bin', 'usr', 'local', 'opt', 'var', 'tmp', 'etc', 'mnt',
    'home', 'root', 'and', 'cmd', 'env', 'www-data', 'dev', 'null', 'cron', 'crond', 'systemctl',
    'service', 'journalctl', 'tail', 'head', 'cut', 'sort', 'uniq', 'wc', 'tr', 'mkdir', 'rmdir',
    'ln', 'ls', 'du', 'df', 'free', 'top', 'ps', 'kill', 'killall', 'pkill', 'system',
  };

  List<String> _extractUniqueTokens(String command) {
    // Extract words (3+ chars, alphanumeric + underscores/hyphens/dots)
    final allWords = RegExp(r'[a-zA-Z0-9_.-]+')
        .allMatches(command)
        .map((m) => m.group(0)!)
        .where((t) => t.length >= 3 && !t.startsWith('-') && int.tryParse(t) == null)
        .toSet()
        .toList();

    // Filter out generic Linux/system/command tokens
    final uniqueWords = allWords.where((t) => !_genericTokens.contains(t.toLowerCase())).toList();

    return uniqueWords.isNotEmpty ? uniqueWords : allWords;
  }

  bool _matchLogToCommand(String l, String command) {
    if (!l.contains('CRON') && !l.contains('CMD') && !l.contains('cron')) return false;

    // Extract what CMD (...) logged if available
    String loggedCmd = l;
    final cmdIdx = l.indexOf('CMD (');
    if (cmdIdx != -1) {
      final endIdx = l.lastIndexOf(')');
      if (endIdx > cmdIdx + 5) {
        loggedCmd = l.substring(cmdIdx + 5, endIdx);
      } else {
        loggedCmd = l.substring(cmdIdx + 5);
      }
    } else if (l.contains('CMD ')) {
      loggedCmd = l.substring(l.indexOf('CMD ') + 4);
    }

    final uniqueTokens = _extractUniqueTokens(command);
    if (uniqueTokens.isEmpty) {
      return l.contains(command.trim());
    }

    // Every unique token that appears in the command prior to the logged length must be present in `l`
    int matchedTokens = 0;
    for (final token in uniqueTokens) {
      if (l.contains(token)) {
        matchedTokens++;
      } else {
        // If this token was at the start/prefix of the command (within the region covered by loggedCmd),
        // and it's missing from `l`, then `l` definitely belongs to another job!
        final tokenIndexInCmd = command.indexOf(token);
        if (tokenIndexInCmd != -1 && tokenIndexInCmd < loggedCmd.length - 5) {
          return false;
        }
      }
    }

    return matchedTokens > 0;
  }

  Future<void> _runJobNow(CronJob job) async {
    final provider = Provider.of<ServerProvider>(context, listen: false);
    setState(() {
      _isExecutingNow = true;
      _activeExecutionOutput = '⚡ Running job immediately via SSH...\nCommand: ${job.command}\n\n';
    });
    _scrollExecToBottom();

    try {
      String output = '';
      if (job.isRoot) {
        final sudoPwd = await _getSudoPassword(context, forceConfirmation: true, actionName: 'Instant Execution (${job.humanReadableSchedule})', exactCommand: job.command);
        if (sudoPwd == null && (provider.activeProfile?.password ?? '').isEmpty) {
          setState(() {
            _isExecutingNow = false;
            _activeExecutionOutput = null;
          });
          return;
        }
        output = await provider.executeSudoCommand(job.command, sudoPwd ?? '');
      } else {
        output = await provider.executeCommand(job.command, timeout: const Duration(seconds: 120));
      }

      if (mounted) {
        setState(() {
          _activeExecutionOutput =
              '${_activeExecutionOutput!}$output\n\n✅ Completed successfully at ${TimeOfDay.now().format(context)}!';
          _isExecutingNow = false;
        });
        _scrollExecToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _activeExecutionOutput = '${_activeExecutionOutput!}\n❌ Error during execution:\n$e';
          _isExecutingNow = false;
        });
        _scrollExecToBottom();
      }
    }
  }

  void _showAddOrEditJobDialog({CronJob? jobToEdit}) {
    final scheduleController = TextEditingController(text: jobToEdit?.schedule ?? '0 4 * * *');
    final commandController = TextEditingController(text: jobToEdit?.command ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.obsidian,
          title: Row(
            children: [
              Icon(jobToEdit != null ? Icons.edit : Icons.add_alarm, color: AppTheme.neonPurple),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  jobToEdit != null ? 'Edit Cron Job (${_isRootTab ? "Root" : "User"})' : 'Add Cron Job (${_isRootTab ? "Root" : "User"})',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schedule (Cron Syntax or Presets)',
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: scheduleController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: (_) => setDialogState(() {}),
                    style: GoogleFonts.jetBrainsMono(color: AppTheme.neonCyan),
                    decoration: InputDecoration(
                      hintText: 'e.g., 0 4 * * * or @daily',
                      hintStyle: GoogleFonts.jetBrainsMono(color: Colors.white30),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter a valid schedule';
                      final val = CommandValidator.validateCronJob(scheduleController.text, commandController.text, isRoot: _isRootTab);
                      if (val.isBlocked) return val.message;
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _presetChip('Midnight (@daily)', '@daily', scheduleController, () => setDialogState(() {})),
                      _presetChip('Hourly (@hourly)', '@hourly', scheduleController, () => setDialogState(() {})),
                      _presetChip('Weekly (@weekly)', '@weekly', scheduleController, () => setDialogState(() {})),
                      _presetChip('Every 15 min', '*/15 * * * *', scheduleController, () => setDialogState(() {})),
                      _presetChip('Every day at 04:00', '0 4 * * *', scheduleController, () => setDialogState(() {})),
                      _presetChip('Every Monday at 01:30', '30 1 * * 1', scheduleController, () => setDialogState(() {})),
                      _presetChip('On boot (@reboot)', '@reboot', scheduleController, () => setDialogState(() {})),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Command to Execute',
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: commandController,
                    maxLines: 2,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: (_) => setDialogState(() {}),
                    style: GoogleFonts.jetBrainsMono(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g., /home/user/backup.sh > /tmp/backup.log 2>&1',
                      hintStyle: GoogleFonts.jetBrainsMono(color: Colors.white30),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter the command to execute';
                      final val = CommandValidator.validateCronJob(scheduleController.text, commandController.text, isRoot: _isRootTab);
                      if (val.isBlocked) return val.message;
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Builder(
                    builder: (_) {
                      final val = CommandValidator.validateCronJob(scheduleController.text, commandController.text, isRoot: _isRootTab);
                      if (val.isBlocked && val.message != null) {
                        return Container(
                          padding: const EdgeInsets.all(10),
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
                                child: Text(val.message!, style: GoogleFonts.outfit(color: Colors.white, fontSize: 12.5)),
                              ),
                            ],
                          ),
                        );
                      } else if (val.isWarning && val.message != null) {
                        return Container(
                          padding: const EdgeInsets.all(10),
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
                                child: Text(val.message!, style: GoogleFonts.outfit(color: Colors.white, fontSize: 12.5)),
                              ),
                            ],
                          ),
                        );
                      } else if (_isRootTab) {
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.amber.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.admin_panel_settings, color: AppTheme.amber, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Running with Root privileges in system crontab.', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            Builder(
              builder: (_) {
                final val = CommandValidator.validateCronJob(scheduleController.text, commandController.text, isRoot: _isRootTab);
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: val.isWarning ? AppTheme.amber : AppTheme.neonPurple,
                    foregroundColor: val.isWarning ? AppTheme.obsidian : Colors.white,
                  ),
                  onPressed: val.isBlocked
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          Navigator.pop(ctx);
                          await _saveJobToCrontab(
                            oldJob: jobToEdit,
                            newSchedule: scheduleController.text.trim(),
                            newCommand: commandController.text.trim(),
                          );
                        },
                  child: Text(
                    jobToEdit != null ? 'SAVE CHANGES' : 'ADD TO CRONTAB',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(String label, String value, TextEditingController controller, [VoidCallback? onSelect]) {
    return ActionChip(
      backgroundColor: AppTheme.obsidian,
      side: BorderSide(color: AppTheme.neonPurple.withValues(alpha: 0.5)),
      label: Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
      onPressed: () {
        controller.text = value;
        onSelect?.call();
      },
    );
  }

  Widget _logFilterChip(String label, int days) {
    final isSelected = _logDaysFilter == days;
    return GestureDetector(
      onTap: () {
        if (_isLoading || isSelected) return;
        setState(() => _logDaysFilter = days);
        _fetchCronJobs();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.neonCyan.withValues(alpha: 0.2) : AppTheme.obsidian,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.neonCyan : AppTheme.cardBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? AppTheme.neonCyan : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _saveJobToCrontab({CronJob? oldJob, required String newSchedule, required String newCommand}) async {
    final provider = Provider.of<ServerProvider>(context, listen: false);
    setState(() => _isLoading = true);

    try {
      String currentCrontab = '';
      String? sudoPwd = '';
      final newLine = '$newSchedule $newCommand';

      if (_isRootTab) {
        if (!mounted) return;
        sudoPwd = await _getSudoPassword(context, forceConfirmation: true, actionName: oldJob != null ? 'Edit Root Cron Job' : 'Add Root Cron Job', exactCommand: newLine);
        if (sudoPwd == null && (provider.activeProfile?.password ?? '').isEmpty) {
          setState(() => _isLoading = false);
          return;
        }
        currentCrontab = await provider.executeSudoCommand('crontab -l 2>/dev/null || true', sudoPwd ?? '');
      } else {
        currentCrontab = await provider.executeCommand('crontab -l 2>/dev/null || true');
      }

      List<String> lines = currentCrontab.split('\n').where((l) => l.trim().isNotEmpty).toList();

      if (oldJob != null) {
        final idx = lines.indexWhere((l) => l.trim() == oldJob.rawLine.trim());
        if (idx != -1) {
          lines[idx] = newLine;
        } else {
          lines.add(newLine);
        }
      } else {
        lines.add(newLine);
      }

      final updatedContent = '${lines.join('\n')}\n';
      final base64Content = base64Encode(utf8.encode(updatedContent));

      if (_isRootTab) {
        await provider.executeSudoCommand('echo "$base64Content" | base64 -d | crontab -', sudoPwd ?? '');
      } else {
        await provider.executeCommand('echo "$base64Content" | base64 -d | crontab -');
      }

      await _fetchCronJobs();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error saving to crontab: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteJobFromCrontab(CronJob job) async {
    final provider = Provider.of<ServerProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.obsidian,
        title: const Text('Confirm Deletion', style: TextStyle(color: AppTheme.crimson)),
        content: Text(
          'Are you sure you want to delete this cron job from crontab?\n\n${job.schedule} ${job.command}',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      String currentCrontab = '';
      String? sudoPwd = '';

      if (_isRootTab) {
        if (!mounted) return;
        sudoPwd = await _getSudoPassword(context, forceConfirmation: true, actionName: 'Delete Root Cron Job', exactCommand: 'DELETE: ${job.rawLine}');
        if (sudoPwd == null && (provider.activeProfile?.password ?? '').isEmpty) {
          setState(() => _isLoading = false);
          return;
        }
        currentCrontab = await provider.executeSudoCommand('crontab -l 2>/dev/null || true', sudoPwd ?? '');
      } else {
        currentCrontab = await provider.executeCommand('crontab -l 2>/dev/null || true');
      }

      List<String> lines = currentCrontab.split('\n').where((l) => l.trim() != job.rawLine.trim() && l.trim().isNotEmpty).toList();
      final updatedContent = lines.isEmpty ? '' : '${lines.join('\n')}\n';
      final base64Content = base64Encode(utf8.encode(updatedContent));

      if (_isRootTab) {
        if (lines.isEmpty) {
          await provider.executeSudoCommand('crontab -r 2>/dev/null || true', sudoPwd ?? '');
        } else {
          await provider.executeSudoCommand('echo "$base64Content" | base64 -d | crontab -', sudoPwd ?? '');
        }
      } else {
        if (lines.isEmpty) {
          await provider.executeCommand('crontab -r 2>/dev/null || true');
        } else {
          await provider.executeCommand('echo "$base64Content" | base64 -d | crontab -');
        }
      }

      await _fetchCronJobs();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error deleting from crontab: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.schedule, color: AppTheme.neonPurple, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cron Manager & Job Monitoring',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            IconButton(
              onPressed: _isLoading ? null : _fetchCronJobs,
              icon: const Icon(Icons.refresh, color: AppTheme.neonCyan),
              tooltip: 'Refresh Jobs',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Monitor past executions, edit schedules, or trigger instant executions directly from crontab.',
          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
        ),
        const SizedBox(height: 14),

        // Tab Selector (User vs Root)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.obsidian,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_isRootTab) {
                      setState(() => _isRootTab = false);
                      _fetchCronJobs();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: !_isRootTab ? AppTheme.neonPurple.withValues(alpha: 0.25) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: !_isRootTab ? Border.all(color: AppTheme.neonPurple) : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'User Crontab',
                      style: GoogleFonts.outfit(
                        color: !_isRootTab ? Colors.white : Colors.white60,
                        fontWeight: !_isRootTab ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!_isRootTab) {
                      setState(() => _isRootTab = true);
                      _fetchCronJobs();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _isRootTab ? AppTheme.crimson.withValues(alpha: 0.25) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: _isRootTab ? Border.all(color: AppTheme.crimson) : null,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.security, color: AppTheme.crimson, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Root Crontab',
                          style: GoogleFonts.outfit(
                            color: _isRootTab ? Colors.white : Colors.white60,
                            fontWeight: _isRootTab ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.filter_alt_outlined, color: Colors.white54, size: 16),
            const SizedBox(width: 6),
            Text(
              'Log Window:',
              style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _logFilterChip('Today', 1),
                    const SizedBox(width: 6),
                    _logFilterChip('This Week', 7),
                    const SizedBox(width: 6),
                    _logFilterChip('Last 2 Weeks', 14),
                    const SizedBox(width: 6),
                    _logFilterChip('This Month', 30),
                    const SizedBox(width: 6),
                    _logFilterChip('3 Months', 90),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_isRootTab) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppTheme.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Root crontab is read-only for security reasons. You can edit or delete them in the terminal.',
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Error Box
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppTheme.crimson.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.crimson),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppTheme.crimson),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_errorMessage!, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                ),
              ],
            ),
          ),

        // Instant Execution Output Box
        if (_activeExecutionOutput != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isExecutingNow ? AppTheme.amber : AppTheme.emerald),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isExecutingNow ? Icons.pending : Icons.task_alt,
                          color: _isExecutingNow ? AppTheme.amber : AppTheme.emerald,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isExecutingNow ? 'Running Job Now...' : 'Execution Result',
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                      onPressed: () => setState(() => _activeExecutionOutput = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    controller: _execScrollController,
                    child: SelectableText(
                      _activeExecutionOutput!,
                      style: GoogleFonts.jetBrainsMono(
                        color: _isExecutingNow ? AppTheme.amber : AppTheme.emerald,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Jobs List
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(28.0),
              child: CircularProgressIndicator(color: AppTheme.neonPurple),
            ),
          )
        else if (_jobs.isEmpty)
          SizedBox(
            width: double.infinity,
            child: GlassCard(
              borderColor: AppTheme.cardBorder,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.alarm_off, size: 48, color: Colors.white30),
                    const SizedBox(height: 12),
                    Text(
                      'No Cron Jobs configured in ${_isRootTab ? "Root" : "User"} crontab.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap the button below to schedule your first automated task or script!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _jobs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final job = _jobs[index];
              return GlassCard(
                borderColor: AppTheme.neonPurple.withValues(alpha: 0.35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Schedule Badge & Description
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.neonPurple.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.neonPurple),
                          ),
                          child: Text(
                            job.schedule,
                            style: GoogleFonts.jetBrainsMono(color: AppTheme.neonPurple, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            job.humanReadableSchedule,
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Command Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.obsidian,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.terminal, color: AppTheme.neonCyan, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              job.command,
                              style: GoogleFonts.jetBrainsMono(color: AppTheme.neonCyan, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Last Execution Log Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: job.lastExecutionLog != null
                            ? AppTheme.emerald.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: job.lastExecutionLog != null ? AppTheme.emerald.withValues(alpha: 0.4) : Colors.white12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            job.lastExecutionLog != null ? Icons.history_toggle_off : Icons.info_outline,
                            size: 16,
                            color: job.lastExecutionLog != null ? AppTheme.emerald : Colors.white54,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              job.lastExecutionLog != null
                                  ? 'Last run: ${job.lastExecutionLog}'
                                  : 'No recent execution found in system logs for this command in the last ${_logDaysFilter == 1 ? "1 day" : "$_logDaysFilter days"}.${_estimateScheduleIntervalDays(job.schedule) > _logDaysFilter ? " (This job runs ${job.humanReadableSchedule.toLowerCase()} — try a wider log window)" : ""}',
                              style: GoogleFonts.outfit(
                                color: job.lastExecutionLog != null ? AppTheme.emerald : Colors.white54,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Actions Bar (Run Now, Edit, Delete — Edit/Delete only for User crontab)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald.withValues(alpha: 0.2),
                            foregroundColor: AppTheme.emerald,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            side: const BorderSide(color: AppTheme.emerald),
                          ),
                          onPressed: _isExecutingNow ? null : () => _runJobNow(job),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: Text('Run Now', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        if (!_isRootTab) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit, color: AppTheme.neonPurple, size: 20),
                            tooltip: 'Edit Job',
                            onPressed: () => _showAddOrEditJobDialog(jobToEdit: job),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 20),
                            tooltip: 'Delete Job',
                            onPressed: () => _deleteJobFromCrontab(job),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 16),

        // Add Job Button (only for User crontab — root editing disabled for security)
        if (!_isRootTab)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showAddOrEditJobDialog(),
              icon: const Icon(Icons.add_circle_outline),
              label: Text('Add Job to Crontab (User)', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
