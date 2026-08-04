import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class StatGauge extends StatefulWidget {
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

  @override
  State<StatGauge> createState() => _StatGaugeState();
}

class _StatGaugeState extends State<StatGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppTheme.animGauge,
      vsync: this,
    );
    _previousPercentage = widget.percentage.clamp(0.0, 100.0);
    _animation = Tween<double>(
      begin: 0.0,
      end: _previousPercentage,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppTheme.animCurve,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant StatGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newPercentage = widget.percentage.clamp(0.0, 100.0);
    if ((newPercentage - _previousPercentage).abs() > 0.1) {
      _animation = Tween<double>(
        begin: _previousPercentage,
        end: newPercentage,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: AppTheme.animCurve,
      ));
      _previousPercentage = newPercentage;
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getGaugeColor(double pct) {
    if (widget.customColor != null) return widget.customColor!;
    if (pct < 60) return AppTheme.neonCyan;
    if (pct < 80) return AppTheme.amber;
    return AppTheme.crimson;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final animatedValue = _animation.value;
        final activeColor = _getGaugeColor(animatedValue);

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
                          value: animatedValue,
                          radius: 14,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          color: AppTheme.cardBorder.withValues(alpha: 0.4),
                          value: 100.0 - animatedValue,
                          radius: 12,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, color: activeColor, size: 22),
                      const SizedBox(height: 4),
                      Text(
                        '${animatedValue.toStringAsFixed(1)}%',
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
                widget.title,
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
                widget.subtitle,
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
      },
    );
  }
}
