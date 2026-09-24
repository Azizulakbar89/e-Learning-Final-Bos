import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/exam_model.dart';

class ExamCategoryBadge extends StatelessWidget {
  final ExamCategory category;
  final double fontSize;
  final double iconSize;
  final EdgeInsetsGeometry? padding;

  const ExamCategoryBadge({
    super.key,
    required this.category,
    this.fontSize = 10,
    this.iconSize = 11,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (category) {
      case ExamCategory.quiz:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
        icon = Icons.bolt_rounded;
        break;
      case ExamCategory.harian:
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        icon = Icons.assignment_turned_in_rounded;
        break;
      case ExamCategory.pts:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        icon = Icons.school_rounded;
        break;
      case ExamCategory.pas:
        bg = const Color(0xFFFFE4E6);
        fg = const Color(0xFFE11D48);
        icon = Icons.workspace_premium_rounded;
        break;
    }

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: fg),
          const SizedBox(width: 3.5),
          Text(
            category.label,
            style: GoogleFonts.outfit(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
