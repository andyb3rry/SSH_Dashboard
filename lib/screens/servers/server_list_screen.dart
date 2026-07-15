import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/server_profile.dart';
import '../../providers/server_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import 'server_form_sheet.dart';

class ServerListScreen extends StatefulWidget {
  final bool isModalSelection;

  const ServerListScreen({super.key, this.isModalSelection = false});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ServerProvider>(context, listen: false);
      provider.onCloudflareAuthCallback = (profile) async {
        return await _showCloudflareAuthDialog(profile);
      };
    });
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

  void _openForm(BuildContext context, [ServerProfile? profile]) async {
    final provider = Provider.of<ServerProvider>(context, listen: false);
    final result = await showModalBottomSheet<ServerProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ServerFormSheet(existingProfile: profile),
    );
    if (result != null) {
      await provider.saveProfile(result);
    }
  }

  void _confirmDelete(BuildContext context, ServerProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Server?'),
        content: Text('Are you sure you want to delete the configuration for "${profile.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<ServerProvider>(context, listen: false).deleteProfile(profile.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ServerProvider>(context);

    return Scaffold(
      backgroundColor: widget.isModalSelection ? AppTheme.obsidian : Colors.transparent,
      appBar: widget.isModalSelection
          ? AppBar(
              title: const Text('Select Server Profile'),
            )
          : null,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton.extended(
          heroTag: 'server_list_fab',
          backgroundColor: AppTheme.neonCyan,
          foregroundColor: AppTheme.obsidian,
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.add),
          label: Text('Add Server', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        ),
      ),
      body: Column(
        children: [
          if (!widget.isModalSelection)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'CONFIGURED SERVERS (${provider.profiles.length})',
                  style: GoogleFonts.outfit(color: AppTheme.neonCyan, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
              ),
            ),
          Expanded(
            child: provider.profiles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.cardBorder, width: 2),
                      ),
                      child: const Icon(Icons.terminal, size: 64, color: AppTheme.neonCyan),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Server Configured',
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Add your remote Linux/Android server to start monitoring resources, Docker, and control the shell via SSH.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: Colors.white60, fontSize: 15),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: () => _openForm(context),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Configure First Server'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: widget.isModalSelection ? 16 : 144),
              itemCount: provider.profiles.length,
              itemBuilder: (ctx, idx) {
                final profile = provider.profiles[idx];
                final isActive = provider.activeProfile?.id == profile.id;
                final isConnected = isActive && provider.status == ConnectionStatus.connected;
                final isConnecting = isActive && provider.status == ConnectionStatus.connecting;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: GlassCard(
                    isGlow: isConnected || isConnecting,
                    borderColor: isConnected ? AppTheme.emerald : (isConnecting ? AppTheme.amber : null),
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
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isConnected
                                          ? AppTheme.emerald.withValues(alpha: 0.15)
                                          : AppTheme.obsidian,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isConnected ? AppTheme.emerald : AppTheme.cardBorder,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.storage,
                                      color: isConnected ? AppTheme.emerald : AppTheme.neonCyan,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          '${profile.username}@${profile.host}:${profile.port}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white60,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.white70),
                              color: AppTheme.surfaceDark,
                              onSelected: (val) {
                                if (val == 'edit') _openForm(context, profile);
                                if (val == 'delete') _confirmDelete(context, profile);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.crimson))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (isActive && provider.errorMessage.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.crimson.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppTheme.crimson, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    provider.errorMessage,
                                    style: GoogleFonts.outfit(color: AppTheme.crimson, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            if (isConnected)
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.crimson.withValues(alpha: 0.2),
                                    foregroundColor: AppTheme.crimson,
                                    elevation: 0,
                                    side: const BorderSide(color: AppTheme.crimson),
                                  ),
                                  onPressed: () => provider.disconnect(),
                                  icon: const Icon(Icons.power_settings_new, size: 18),
                                  label: const Text('Disconnect'),
                                ),
                              )
                            else if (isConnecting)
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.amber),
                                  onPressed: null,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                      ),
                                      const SizedBox(width: 10),
                                      Text('Connecting...', style: GoogleFonts.outfit(color: Colors.black)),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    await provider.connect(profile);
                                    if (context.mounted && widget.isModalSelection && provider.status == ConnectionStatus.connected) {
                                      Navigator.pop(context);
                                    }
                                  },
                                  icon: const Icon(Icons.bolt, size: 20),
                                  label: const Text('Connect Server via SSH'),
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
