import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/storage_service.dart';
import '../../services/app_lock_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService();

  bool _appLockEnabled = false;
  int _appLockTimeoutSeconds = 60;
  double _terminalFontSize = 14.0;
  int _sshTimeoutSeconds = 25;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final lock = await _storage.isAppLockEnabled();
    final appLockTimeout = await _storage.getAppLockTimeoutSeconds();
    final font = await _storage.getTerminalFontSize();
    final timeout = await _storage.getSshTimeoutSeconds();

    if (mounted) {
      setState(() {
        _appLockEnabled = lock;
        _appLockTimeoutSeconds = appLockTimeout;
        _terminalFontSize = font;
        _sshTimeoutSeconds = timeout;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value) {
      final success = await AppLockService().authenticate(
        reason: 'Authenticate to enable biometric / PIN App Lock',
        force: true,
      );
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed. Biometric lock was not enabled.'),
              backgroundColor: AppTheme.crimson,
            ),
          );
        }
        return;
      }
    } else {
      final success = await AppLockService().authenticate(
        reason: 'Authenticate to disable biometric / PIN App Lock',
        force: true,
      );
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed. Biometric lock remains enabled.'),
              backgroundColor: AppTheme.crimson,
            ),
          );
        }
        return;
      }
    }

    await _storage.setAppLockEnabled(value);
    if (mounted) {
      setState(() => _appLockEnabled = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? '🔒 App Lock enabled successfully!' : '🔓 App Lock disabled.'),
          backgroundColor: value ? AppTheme.emerald : Colors.white24,
        ),
      );
    }
  }

  Future<void> _changeFontSize(double size) async {
    await _storage.setTerminalFontSize(size);
    if (mounted) {
      setState(() => _terminalFontSize = size);
    }
  }

  Future<void> _changeTimeout(int seconds) async {
    await _storage.setSshTimeoutSeconds(seconds);
    if (mounted) {
      setState(() => _sshTimeoutSeconds = seconds);
    }
  }

  Future<void> _changeAppLockTimeout(int seconds) async {
    await _storage.setAppLockTimeoutSeconds(seconds);
    if (mounted) {
      setState(() => _appLockTimeoutSeconds = seconds);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ App Lock timeout updated!'),
          backgroundColor: AppTheme.emerald,
        ),
      );
    }
  }

  String _getTimeoutExplanation(int seconds) {
    if (seconds == -1) {
      return 'Authentication is only required when launching the app from cold start / full close.';
    }
    if (seconds == 0) {
      return 'Authentication is required immediately whenever you leave or background the app.';
    }
    String timeStr = seconds < 60 ? '${seconds}s' : '${seconds ~/ 60}m';
    return 'Authentication is required when left in background for over $timeStr (and on cold start).';
  }

  Future<void> _clearHostKeys() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.obsidian,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.amber),
            const SizedBox(width: 10),
            Text('Reset Host Fingerprints?', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          'This will clear all saved SHA-256 SSH host fingerprints (TOFU cache).\n\n'
          'Next time you connect to your servers, you will establish new Trust-On-First-Use keys.',
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.amber, foregroundColor: AppTheme.obsidian),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CLEAR KEYS'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final count = await _storage.clearAllHostFingerprints();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleared $count saved SSH host fingerprints.'),
            backgroundColor: AppTheme.neonCyan,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.obsidian,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.settings, color: AppTheme.neonCyan),
            const SizedBox(width: 10),
            Text('Application Settings', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonCyan))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle('SECURITY & ACCESS'),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          activeThumbColor: AppTheme.neonCyan,
                          activeTrackColor: AppTheme.neonCyan.withValues(alpha: 0.3),
                          title: Text('Biometric / PIN App Lock', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text(
                            'Require fingerprint, face unlock, or device PIN every time SSH Dashboard starts or resumes from background.',
                            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
                          ),
                          value: _appLockEnabled,
                          onChanged: _toggleAppLock,
                          secondary: Icon(
                            _appLockEnabled ? Icons.lock : Icons.lock_open,
                            color: _appLockEnabled ? AppTheme.neonCyan : Colors.white38,
                            size: 28,
                          ),
                        ),
                      ),
                      if (_appLockEnabled) ...[
                        Divider(color: AppTheme.cardBorder.withValues(alpha: 0.5), height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.timer_outlined, color: AppTheme.neonCyan),
                                        const SizedBox(width: 12),
                                        Flexible(
                                          child: Text(
                                            'Lock Timeout',
                                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.obsidian,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.cardBorder),
                                    ),
                                    child: DropdownButton<int>(
                                      value: _appLockTimeoutSeconds,
                                      dropdownColor: AppTheme.obsidian,
                                      style: GoogleFonts.outfit(color: AppTheme.neonCyan, fontWeight: FontWeight.bold, fontSize: 14),
                                      underline: const SizedBox(),
                                      items: const [
                                        DropdownMenuItem(value: -1, child: Text('On Close Only')),
                                        DropdownMenuItem(value: 0, child: Text('Immediately')),
                                        DropdownMenuItem(value: 30, child: Text('After 30s')),
                                        DropdownMenuItem(value: 60, child: Text('After 1m')),
                                        DropdownMenuItem(value: 300, child: Text('After 5m')),
                                        DropdownMenuItem(value: 900, child: Text('After 15m')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) _changeAppLockTimeout(val);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 36),
                                child: Text(
                                  _getTimeoutExplanation(_appLockTimeoutSeconds),
                                  style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('TERMINAL SHELL'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.text_fields, color: AppTheme.neonCyan),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Terminal Font Size', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          Text('${_terminalFontSize.toInt()} pt', style: GoogleFonts.firaCode(color: AppTheme.neonCyan, fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: _terminalFontSize,
                        min: 12,
                        max: 20,
                        divisions: 4,
                        activeColor: AppTheme.neonCyan,
                        inactiveColor: Colors.white24,
                        onChanged: (val) => _changeFontSize(val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('SSH NETWORK TIMEOUT'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder),
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
                                const Icon(Icons.timer_outlined, color: AppTheme.neonCyan),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    'Command Execution Timeout',
                                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.obsidian,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: DropdownButton<int>(
                              value: _sshTimeoutSeconds,
                              dropdownColor: AppTheme.obsidian,
                              style: GoogleFonts.outfit(color: AppTheme.neonCyan, fontWeight: FontWeight.bold, fontSize: 15),
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: 15, child: Text('15s')),
                                DropdownMenuItem(value: 25, child: Text('25s')),
                                DropdownMenuItem(value: 45, child: Text('45s')),
                                DropdownMenuItem(value: 60, child: Text('60s')),
                              ],
                              onChanged: (val) {
                                if (val != null) _changeTimeout(val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 36),
                        child: Text(
                          'Max duration before aborting unresponsive commands.',
                          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('SECURITY MANAGEMENT'),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const Icon(Icons.key_off, color: AppTheme.amber, size: 28),
                    title: Text('Clear Known SSH Host Keys', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text('Reset SHA-256 fingerprint verification (TOFU cache). Use if your remote server OS was reinstalled.', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.amber.withValues(alpha: 0.2),
                        foregroundColor: AppTheme.amber,
                        elevation: 0,
                      ),
                      onPressed: _clearHostKeys,
                      child: const Text('Reset Keys'),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    'Server Commander SSH • v1.2.0 (Security Hardened)',
                    style: GoogleFonts.outfit(color: Colors.white30, fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(color: AppTheme.neonCyan, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }
}
