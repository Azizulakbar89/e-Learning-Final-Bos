import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A modern floating card header with slightly curved corners and deep Navy-Orange
/// gradient theme matching the e-Learning design system.
class CurvedHeaderCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final bool showBackButton;
  final List<Widget>? actions;
  final Widget? leading;
  final EdgeInsetsGeometry margin;

  const CurvedHeaderCard({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.showBackButton = true,
    this.actions,
    this.leading,
    this.margin = const EdgeInsets.fromLTRB(14, 8, 14, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF040D1F), // Deepest Navy
            Color(0xFF071540), // Deep Navy
            Color(0xFF0D2B6E), // Primary Navy
            Color(0xFF1A4DB5), // Medium Navy
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D2B6E).withAlpha(80),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFFF97316).withAlpha(35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withAlpha(25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (showBackButton) ...[
            leading ??
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onBack ?? () => Navigator.maybePop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withAlpha(40)),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha(200),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(width: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: actions!,
            ),
          ],
        ],
      ),
    );
  }
}
