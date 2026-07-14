import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class StatGauge extends StatelessWidget {
  final String title;
  final double percentage;
  final String subtitle;
  final IconData icon;
  final Color? customColor;

  const StatGauge({
    super.key,
    required this.title,
    required this.percentage,
    required this.subtitle,
    required this.icon,
    this.customColor,
  });

  Color _getGaugeColor() {
    if (customColor != null) return customColor!;
    if (percentage < 60) return AppTheme.neonCyan;
    if (percentage < 80) return AppTheme.amber;
    return AppTheme.crimson;
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _getGaugeColor();
    final clampedPercentage = percentage.clamp(0.0, 100.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 140,
          width: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: 270,
                  sectionsSpace: 0,
                  centerSpaceRadius: 52,
                  sections: [
                    PieChartSectionData(
                      color: activeColor,
                      value: clampedPercentage,
                      radius: 14,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      color: AppTheme.cardBorder.withValues(alpha: 0.4),
                      value: 100.0 - clampedPercentage,
                      radius: 12,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: activeColor, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    '${clampedPercentage.toStringAsFixed(1)}%',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: Colors.white60,
              fontSize: 11.5,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }
}
