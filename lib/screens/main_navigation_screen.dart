import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/server_provider.dart';
import '../models/server_profile.dart';
import '../theme/app_theme.dart';
import 'dashboard/resource_monitor_tab.dart';
import 'docker/docker_manager_tab.dart';
import 'power/power_control_tab.dart';
import 'servers/server_list_screen.dart';
// ignore: implementation_imports
import 'package:dartssh2/src/ssh_userauth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'terminal/interactive_shell_sheet.dart';
import '../services/app_lock_service.dart';
import 'settings/settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  static void navigateToServers(BuildContext context) {
    final state = context.findAncestorStateOfType<_MainNavigationScreenState>() ??
        (context is StatefulElement && context.state is _MainNavigationScreenState
            ? context.state as _MainNavigationScreenState
            : null);
    state?.navigateToTab(3);
  }

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final PageController _pageController;
  bool _isUnlocked = false;

  final List<Widget> _tabs = const [
    _KeepAlivePage(child: ResourceMonitorTab()),
    _KeepAlivePage(child: DockerManagerTab()),
    _KeepAlivePage(child: PowerControlTab()),
    _KeepAlivePage(child: ServerListScreen()),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppLock();
      final provider = Provider.of<ServerProvider>(context, listen: false);
      provider.setOnUserInfoRequestCallback((request) async {
        return await _showInteractiveAuthDialog(request);
      });
      provider.onCloudflareAuthCallback = (profile) async {
        return await _showCloudflareAuthDialog(profile);
      };
    });
  }

  Future<void> _checkAppLock() async {
    final unlocked = await AppLockService().authenticate();
    if (mounted) {
      setState(() => _isUnlocked = unlocked);
    }
  }

  void navigateToTab(int idx) {
    if (_currentIndex == idx) return;
    setState(() => _currentIndex = idx);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        idx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      AppLockService().onAppPaused().then((_) {
        if (mounted) setState(() => _isUnlocked = AppLockService().isUnlocked);
      });
    } else if (state == AppLifecycleState.detached) {
      AppLockService().lock().then((_) {
        if (mounted) setState(() => _isUnlocked = AppLockService().isUnlocked);
      });
    } else if (state == AppLifecycleState.resumed) {
      AppLockService().onAppResumed().then((_) {
        if (mounted) setState(() => _isUnlocked = AppLockService().isUnlocked);
        _checkAppLock();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _launchUrlRobust(BuildContext context, Uri url) async {
    try {
      bool launched = false;
      try {
        launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (_) {}
      if (!launched) {
        try {
          launched = await launchUrl(url, mode: LaunchMode.platformDefault);
        } catch (_) {}
      }
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to open $url')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to open $url')));
      }
    }
  }

  Future<String?> _showCloudflareAuthDialog(ServerProfile profile) async {
    final clientIdController = TextEditingController(text: profile.cloudflareClientId);
    final clientSecretController = TextEditingController(text: profile.cloudflareClientSecret);
    
    final res = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.cloud_queue, color: AppTheme.neonCyan),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cloudflare Zero Trust Service Token',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Text(
                  'To connect through Cloudflare Zero Trust without a browser, configure a Service Token for this SSH host.\n\n'
                  '1. Go to Cloudflare Zero Trust -> Access -> Service Auth -> Service Tokens.\n'
                  '2. Create a token and assign it to an Access Policy linked to your SSH application.\n'
                  '3. Enter the Client ID and Client Secret below.',
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: clientIdController,
                style: GoogleFonts.firaCode(fontSize: 12, color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Client ID (CF-Access-Client-Id)',
                  hintText: 'e.g. 123456789.access',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clientSecretController,
                obscureText: true,
                style: GoogleFonts.firaCode(fontSize: 12, color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Client Secret (CF-Access-Client-Secret)',
                  hintText: 'e.g. abcdef123456...',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.neonCyan),
            onPressed: () {
              final clientId = clientIdController.text.trim();
              final clientSecret = clientSecretController.text.trim();
              if (clientId.isEmpty || clientSecret.isEmpty) {
                return;
              }
              Navigator.pop(ctx, 'SERVICE_TOKEN_AUTH');
            },
            child: Text('Save & Connect', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (res != null && res.isNotEmpty && mounted) {
      final provider = Provider.of<ServerProvider>(context, listen: false);
      final updatedProfile = profile.copyWith(
        cloudflareClientId: clientIdController.text.trim(),
        cloudflareClientSecret: clientSecretController.text.trim(),
      );
      await provider.saveProfile(updatedProfile);
      provider.sshService.updateCurrentProfile(updatedProfile);
    }
    return res;
  }

  Future<List<String>?> _showInteractiveAuthDialog(SSHUserInfoRequest request) async {
    final controllers = request.prompts.map((_) => TextEditingController()).toList();
    
    final urlRegExp = RegExp(r'https?://[^\s]+');
    final match = urlRegExp.firstMatch('${request.instruction} ${request.prompts.map((p) => p.promptText).join(" ")}');
    final foundUrl = match?.group(0);

    final result = await showDialog<List<String>?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.security, color: AppTheme.neonCyan),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                request.name.isNotEmpty ? request.name : '2FA / SSH Security Verification',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (request.instruction.isNotEmpty) ...[
                Text(
                  request.instruction,
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
              ],
              if (foundUrl != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.neonCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.neonCyan),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Browser redirect or authentication required (2FA / SSO):',
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.neonCyan,
                          foregroundColor: AppTheme.obsidian,
                        ),
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('Open Browser to Verify'),
                        onPressed: () async {
                          final uri = Uri.tryParse(foundUrl);
                          if (uri != null) {
                            await _launchUrlRobust(ctx, uri);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              for (var i = 0; i < request.prompts.length; i++) ...[
                TextField(
                  controller: controllers[i],
                  obscureText: !request.prompts[i].echo,
                  style: GoogleFonts.outfit(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: request.prompts[i].promptText,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final answers = controllers.map((c) => c.text).toList();
              Navigator.pop(ctx, answers);
            },
            child: const Text('Confirm & Continue'),
          ),
        ],
      ),
    );

    for (var c in controllers) {
      c.dispose();
    }
    return result;
  }

  void _openTerminal() {
    final provider = Provider.of<ServerProvider>(context, listen: false);
    if (provider.status != ConnectionStatus.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connect to an SSH server first to open the interactive Terminal.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: AppTheme.crimson,
          action: SnackBarAction(
            label: 'Go to Servers',
            textColor: Colors.white,
            onPressed: () => navigateToTab(3),
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const InteractiveShellSheet(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return Scaffold(
        backgroundColor: AppTheme.obsidian,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.neonCyan, width: 2),
                  ),
                  child: const Icon(Icons.lock_outline, size: 64, color: AppTheme.neonCyan),
                ),
                const SizedBox(height: 24),
                Text(
                  'Server Commander SSH',
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Application locked for security. Authenticate to manage servers.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonCyan,
                    foregroundColor: AppTheme.obsidian,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                  onPressed: _checkAppLock,
                  icon: const Icon(Icons.fingerprint, size: 24),
                  label: Text('UNLOCK APP', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final provider = Provider.of<ServerProvider>(context);
    final isConnected = provider.status == ConnectionStatus.connected;

    return Scaffold(
      extendBody: false,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.neonCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.dns, color: AppTheme.neonCyan, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentIndex == 0
                        ? 'Dashboard & Resources'
                        : (_currentIndex == 1
                            ? 'Docker Manager'
                            : (_currentIndex == 2 ? 'System Control' : 'Server Profiles')),
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isConnected && provider.activeProfile != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(color: AppTheme.emerald, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            provider.activeProfile!.name,
                            style: GoogleFonts.outfit(color: AppTheme.emerald, fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.neonCyan),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (idx) => setState(() => _currentIndex = idx),
        children: _tabs,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        heroTag: 'main_nav_fab',
        backgroundColor: isConnected ? AppTheme.neonCyan : AppTheme.cardBorder,
        foregroundColor: isConnected ? AppTheme.obsidian : Colors.white38,
        elevation: isConnected ? 8 : 2,
        onPressed: _openTerminal,
        tooltip: 'Open Terminal Shell (xterm)',
        child: const Icon(Icons.terminal, size: 28),
      ),
      bottomNavigationBar: BottomAppBar(
        color: AppTheme.surfaceDark,
        //shape: const CircularNotchedRectangle(),
        shape: AutomaticNotchedShape(
          const ContinuousRectangleBorder(), // Forma della BottomAppBar (rettangolo standard)
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Forma esatta del tuo FAB
        ),
        notchMargin: 8.0,
        elevation: 16,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Resources', idx: 0),
            _buildNavItem(icon: Icons.apps_outlined, activeIcon: Icons.apps, label: 'Docker', idx: 1),
            const SizedBox(width: 48), // Spazio centrale al largo dell'incavo tondo per il FAB
            _buildNavItem(icon: Icons.power_settings_new_outlined, activeIcon: Icons.power_settings_new, label: 'System', idx: 2),
            _buildNavItem(icon: Icons.storage_outlined, activeIcon: Icons.storage, label: 'Servers', idx: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required IconData activeIcon, required String label, required int idx}) {
    final selected = _currentIndex == idx;
    final color = selected ? AppTheme.neonCyan : Colors.white54;

    return InkWell(
      onTap: () => navigateToTab(idx),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

