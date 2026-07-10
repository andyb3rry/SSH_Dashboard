import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/server_profile.dart';
import '../../theme/app_theme.dart';

class ServerFormSheet extends StatefulWidget {
  final ServerProfile? existingProfile;

  const ServerFormSheet({super.key, this.existingProfile});

  @override
  State<ServerFormSheet> createState() => _ServerFormSheetState();
}

class _ServerFormSheetState extends State<ServerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _privateKeyController;
  late TextEditingController _updateCommandController;
  late TextEditingController _cloudflareClientIdController;
  late TextEditingController _cloudflareClientSecretController;
  
  bool _useAuthKey = false;
  bool _useCloudflareTunnel = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProfile;
    _nameController = TextEditingController(text: p?.name ?? '');
    _hostController = TextEditingController(text: p?.host ?? '');
    _portController = TextEditingController(text: p != null && p.port > 0 ? p.port.toString() : '');
    _usernameController = TextEditingController(text: p?.username ?? '');
    _passwordController = TextEditingController(text: p?.password ?? '');
    _privateKeyController = TextEditingController(text: p?.privateKey ?? '');
    _updateCommandController = TextEditingController(
      text: p?.customUpdateCommand ?? 'sudo apt-get update && sudo apt-get -y upgrade',
    );
    _cloudflareClientIdController = TextEditingController(text: p?.cloudflareClientId ?? '');
    _cloudflareClientSecretController = TextEditingController(text: p?.cloudflareClientSecret ?? '');
    _useAuthKey = p?.useAuthKey ?? false;
    _useCloudflareTunnel = p?.useCloudflareTunnel ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _updateCommandController.dispose();
    _cloudflareClientIdController.dispose();
    _cloudflareClientSecretController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      int portVal = int.tryParse(_portController.text.trim()) ?? 0;
      if (portVal <= 0) {
        portVal = _useCloudflareTunnel ? 443 : 22;
      }
      String cleanHost = _hostController.text.trim();
      cleanHost = cleanHost.replaceAll(RegExp(r'^(https?|wss?):\/\/'), '');
      if (cleanHost.contains('#')) cleanHost = cleanHost.split('#')[0];
      if (cleanHost.contains('/')) cleanHost = cleanHost.split('/')[0];
      if (cleanHost.contains(':')) cleanHost = cleanHost.split(':')[0];

      final id = widget.existingProfile?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      String nameVal = _nameController.text.trim().isEmpty ? 'Server $cleanHost' : _nameController.text.trim();
      if (nameVal.length > 25) nameVal = nameVal.substring(0, 25);
      final profile = ServerProfile(
        id: id,
        name: nameVal,
        host: cleanHost,
        port: portVal,
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        privateKey: _privateKeyController.text.trim(),
        useAuthKey: _useAuthKey,
        customUpdateCommand: _updateCommandController.text.trim(),
        useCloudflareTunnel: _useCloudflareTunnel,
        cloudflareClientId: _cloudflareClientIdController.text.trim(),
        cloudflareClientSecret: _cloudflareClientSecretController.text.trim(),
      );
      _passwordController.clear();
      Navigator.pop(context, profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingProfile == null ? 'New SSH Server' : 'Edit Server',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                maxLength: 25,
                validator: (val) => (val != null && val.trim().length > 25) ? 'Max 25 characters allowed' : null,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Display Name (Max 25 chars)',
                  counterStyle: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 11),
                  labelStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 14),
                  hintStyle: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13.5),
                  prefixIcon: const Icon(Icons.label_outline, color: AppTheme.neonCyan),
                  hintText: 'E.g. Raspberry Pi Home / Production Cloud',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _hostController,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter Host/IP' : null,
                      decoration: InputDecoration(
                        labelText: 'Host / IP *',
                        labelStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 14),
                        hintStyle: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13.5),
                        prefixIcon: const Icon(Icons.computer, color: AppTheme.neonCyan),
                        hintText: '192.168.1.100 or server.com',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _portController,
                      style: GoogleFonts.firaCode(color: Colors.white, fontSize: 14),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Port',
                        labelStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 14),
                        hintStyle: GoogleFonts.firaCode(color: const Color(0xFF64748B), fontSize: 13),
                        hintText: _useCloudflareTunnel ? '443' : '22',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _usernameController,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Username required' : null,
                decoration: InputDecoration(
                  labelText: 'SSH Username *',
                  labelStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 14),
                  hintStyle: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13.5),
                  prefixIcon: const Icon(Icons.person_outline, color: AppTheme.neonCyan),
                  hintText: 'root / ubuntu / admin',
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.obsidian.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Private Key Authentication (SSH Key)',
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Switch(
                      value: _useAuthKey,
                      activeTrackColor: AppTheme.neonCyan,
                      onChanged: (val) => setState(() => _useAuthKey = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (!_useAuthKey)
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'SSH Password',
                    labelStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 14),
                    hintStyle: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13.5),
                    prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.neonCyan),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white60,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                )
              else
                TextFormField(
                  controller: _privateKeyController,
                  maxLines: 4,
                  style: GoogleFonts.firaCode(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'SSH Private Key (.pem / id_rsa / ed25519)',
                    labelStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 14),
                    hintStyle: GoogleFonts.firaCode(color: const Color(0xFF64748B), fontSize: 12),
                    hintText: '-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----',
                    prefixIcon: const Icon(Icons.key, color: AppTheme.neonPurple),
                  ),
                ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.obsidian.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _useCloudflareTunnel ? AppTheme.neonCyan : AppTheme.cardBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Connect via Cloudflare Tunnel Access',
                                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Use WebSockets (wss://) and Zero Trust browser / GitHub OAuth authentication',
                                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _useCloudflareTunnel,
                          activeTrackColor: AppTheme.neonCyan,
                          onChanged: (val) => setState(() => _useCloudflareTunnel = val),
                        ),
                      ],
                    ),
                    if (_useCloudflareTunnel) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cloudflareClientIdController,
                        style: GoogleFonts.firaCode(fontSize: 12, color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'CF-Access-Client-Id (Service Token)',
                          labelStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13),
                          hintStyle: GoogleFonts.firaCode(color: const Color(0xFF64748B), fontSize: 12),
                          hintText: 'E.g. 06e2c...access',
                          prefixIcon: const Icon(Icons.vpn_key_outlined, color: AppTheme.amber),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _cloudflareClientSecretController,
                        obscureText: true,
                        style: GoogleFonts.firaCode(fontSize: 12, color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'CF-Access-Client-Secret (Service Token)',
                          labelStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13),
                          hintStyle: GoogleFonts.firaCode(color: const Color(0xFF64748B), fontSize: 12),
                          hintText: 'E.g. 84d3a...',
                          prefixIcon: const Icon(Icons.security, color: AppTheme.crimson),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _updateCommandController,
                style: GoogleFonts.firaCode(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Quick Update Command',
                  labelStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 14),
                  hintStyle: GoogleFonts.firaCode(color: const Color(0xFF64748B), fontSize: 12.5),
                  prefixIcon: const Icon(Icons.system_update_alt, color: AppTheme.emerald),
                  hintText: 'sudo apt-get update && sudo apt-get -y upgrade',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Server Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
