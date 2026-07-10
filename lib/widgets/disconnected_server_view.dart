import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../screens/main_navigation_screen.dart';

class DisconnectedServerView extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;

  const DisconnectedServerView({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.dns_outlined,
    this.iconColor = AppTheme.neonCyan,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: 0.1),
                border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Icon(icon, size: 52, color: iconColor),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 10),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 15),
              ),
            ],
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => MainNavigationScreen.navigateToServers(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: AppTheme.obsidian,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.storage_outlined, size: 20),
              label: Text(
                'Go to Servers',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
