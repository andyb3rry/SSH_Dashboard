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
            // Animated icon entrance: scale from 0.7 → 1.0 with spring
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.7, end: 1.0),
              duration: AppTheme.animSlow,
              curve: AppTheme.animCurveEnter,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: Opacity(opacity: scale.clamp(0.0, 1.0), child: child),
              ),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.1),
                  border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Icon(icon, size: 52, color: iconColor),
              ),
            ),
            const SizedBox(height: 24),
            // Animated text entrance: slide up + fade in
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: AppTheme.animSlow,
              curve: AppTheme.animCurveEnter,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - value)),
                  child: child,
                ),
              ),
              child: Column(
                children: [
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
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Animated button entrance: slightly delayed fade + slide
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 650),
              curve: AppTheme.animCurveEnter,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - value)),
                  child: child,
                ),
              ),
              child: ElevatedButton.icon(
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
            ),
          ],
        ),
      ),
    );
  }
}
