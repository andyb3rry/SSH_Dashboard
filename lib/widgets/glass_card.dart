import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;
  final double borderRadius;
  final bool isGlow;
  final bool useBlur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.borderColor,
    this.backgroundColor,
    this.borderRadius = 18,
    this.isGlow = false,
    this.useBlur = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: (backgroundColor ?? AppTheme.surfaceDark).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? (isGlow ? AppTheme.neonCyan.withValues(alpha: 0.6) : AppTheme.cardBorder),
          width: isGlow ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isGlow)
            BoxShadow(
              color: (borderColor ?? AppTheme.neonCyan).withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: 1,
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        ),
      );
    }

    if (!useBlur) {
      return content;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: content,
      ),
    );
  }
}
