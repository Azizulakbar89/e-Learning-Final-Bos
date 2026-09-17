import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? color;
  final Color? borderColor;
  final double blur;
  final List<BoxShadow>? boxShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.color,
    this.borderColor,
    this.blur = 12,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color ??
                (isDark
                    ? Colors.white.withAlpha(18)
                    : Colors.white.withAlpha(180)),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ??
                  (isDark
                      ? Colors.white.withAlpha(30)
                      : Colors.white.withAlpha(120)),
              width: 1.2,
            ),
            boxShadow: boxShadow ??
                [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 60 : 20),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
          ),
          child: child,
        ),
      ),
    );
  }
}
