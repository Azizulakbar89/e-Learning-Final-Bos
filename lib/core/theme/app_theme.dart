import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// ─── AppTheme ────────────────────────────────────────────────────────────────
/// Tema: ORANGE (aksi) + NAVY DONGKER (struktur) + PUTIH (surface)
///   • AppBar / NavRail / Header  → Navy
///   • CTA Buttons / FAB / Badge  → Orange
///   • Surface / Cards / Forms    → White
/// ─────────────────────────────────────────────────────────────────────────────
class AppTheme {
  static const _navy   = AppColors.navy;       // 0xFF0D2B6E
  static const _orange = AppColors.orange;     // 0xFFF97316
  static const _white  = Color(0xFFFFFFFF);

  // ════════════════════════════════════════════════════════════
  //  LIGHT THEME
  // ════════════════════════════════════════════════════════════
  static ThemeData get lightTheme {
    final base     = ThemeData.light(useMaterial3: true);
    final baseText = GoogleFonts.outfitTextTheme(base.textTheme);

    return base.copyWith(
      brightness: Brightness.light,
      primaryColor: _orange,
      scaffoldBackgroundColor: AppColors.backgroundLight,

      // ── ColorScheme ────────────────────────────────────────
      colorScheme: ColorScheme.light(
        // Orange = primary CTA
        primary:              _orange,
        onPrimary:            _white,
        primaryContainer:     const Color(0xFFFFE8D6),
        onPrimaryContainer:   const Color(0xFF5C2200),
        // Navy = secondary structure
        secondary:            _navy,
        onSecondary:          _white,
        secondaryContainer:   const Color(0xFFD6E4FF),
        onSecondaryContainer: const Color(0xFF071540),
        // Sky accent = tertiary
        tertiary:             AppColors.accent,
        onTertiary:           _white,
        // Surfaces
        surface:              _white,
        onSurface:            AppColors.textPrimaryLight,
        surfaceContainerHighest: AppColors.backgroundLight,
        // Errors
        error:                AppColors.rose,
        onError:              _white,
        // Borders
        outline:              AppColors.borderLight,
        outlineVariant:       const Color(0xFFCDD8F0),
        // Inverse (nav bar indicators, etc.)
        inverseSurface:       _navy,
        onInverseSurface:     _white,
        // Shadow
        shadow:               Colors.black,
      ),

      // ── Typography ─────────────────────────────────────────
      textTheme: baseText.copyWith(
        displayLarge:  GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight, letterSpacing: -0.6),
        displayMedium: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight, letterSpacing: -0.4),
        headlineLarge: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight, letterSpacing: -0.3),
        headlineMedium:GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight, letterSpacing: -0.2),
        titleLarge:    GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight, letterSpacing: -0.1),
        titleMedium:   GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
        titleSmall:    GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
        bodyLarge:     GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimaryLight, height: 1.5),
        bodyMedium:    GoogleFonts.inter(fontSize: 13.5, color: AppColors.textSecondaryLight, height: 1.5),
        bodySmall:     GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondaryLight),
        labelLarge:    GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: _orange),
        labelMedium:   GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: _navy),
      ),

      // ── AppBar → NAVY ──────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: _navy,
        foregroundColor: _white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: const Color(0x1A0A1931),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.navyDark,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w700, color: _white,
          letterSpacing: -0.3,
        ),
        iconTheme:        const IconThemeData(color: _white),
        actionsIconTheme: const IconThemeData(color: _white),
      ),

      // ── Cards → White + subtle border ─────────────────────
      cardTheme: CardThemeData(
        color: _white,
        elevation: 0,
        shadowColor: const Color(0x0A0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),

      // ── Input → White + orange focus ──────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _orange, width: 2),
        ),
        hintStyle: TextStyle(color: AppColors.textSecondaryLight.withAlpha(160)),
        labelStyle: const TextStyle(color: AppColors.textSecondaryLight),
        floatingLabelStyle: const TextStyle(color: _orange, fontWeight: FontWeight.w600),
        prefixIconColor: AppColors.textSecondaryLight,
        suffixIconColor: AppColors.textSecondaryLight,
      ),

      // ── ElevatedButton → Orange ───────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: _white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      // ── FilledButton → Orange ─────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: _white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),

      // ── OutlinedButton → Orange border ────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _orange,
          side: const BorderSide(color: _orange, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),

      // ── TextButton → Orange ───────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _orange,
          textStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),

      // ── FAB → Orange ──────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _orange,
        foregroundColor: _white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        extendedTextStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
      ),

      // ── Chip → Orange when selected ───────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.backgroundLight,
        selectedColor: _orange,
        secondarySelectedColor: _navy,
        labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimaryLight),
        secondaryLabelStyle: const TextStyle(color: _white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        showCheckmark: false,
      ),

      // ── Tab Bar → Orange indicator ────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: _orange,
        unselectedLabelColor: AppColors.textSecondaryLight,
        labelStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: _orange, width: 3),
          insets: EdgeInsets.symmetric(horizontal: 8),
        ),
        indicatorColor: _orange,
        dividerColor: AppColors.borderLight,
      ),

      // ── Bottom Navigation Bar → Navy active ───────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _white,
        indicatorColor: _orange.withAlpha(25),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: _orange);
          }
          return GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondaryLight);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _orange);
          }
          return IconThemeData(color: AppColors.textSecondaryLight);
        }),
      ),

      // ── Progress Indicator → Orange ───────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: _orange,
        linearTrackColor: _orange.withAlpha(30),
        circularTrackColor: _orange.withAlpha(20),
      ),

      // ── Divider ───────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),

      // ── Switch → Orange ───────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? _white : Colors.grey.shade300),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? _orange : Colors.grey.shade200),
      ),

      // ── Checkbox → Orange ─────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? _orange : Colors.transparent),
        checkColor: WidgetStateProperty.all(_white),
        side: const BorderSide(color: AppColors.borderLight, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // ── Radio → Orange ────────────────────────────────────
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? _orange : AppColors.textSecondaryLight),
      ),

      // ── Dialog ────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: _white,
        elevation: 8,
        shadowColor: _navy.withAlpha(40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight),
      ),

      // ── SnackBar → Navy + orange action ───────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _navy,
        contentTextStyle: GoogleFonts.inter(color: _white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        actionTextColor: _orange,
      ),

      // ── Bottom Sheet ──────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // ── List Tile ─────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor: _white,
        iconColor: _navy,
        textColor: AppColors.textPrimaryLight,
        subtitleTextStyle: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ── Slider → Orange ───────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: _orange,
        inactiveTrackColor: _orange.withAlpha(30),
        thumbColor: _orange,
        overlayColor: _orange.withAlpha(20),
        valueIndicatorColor: _navy,
        valueIndicatorTextStyle: const TextStyle(color: _white),
      ),

      // ── Icons ─────────────────────────────────────────────
      iconTheme: const IconThemeData(color: _navy),
      primaryIconTheme: const IconThemeData(color: _white),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  DARK THEME
  // ════════════════════════════════════════════════════════════
  static ThemeData get darkTheme {
    final base     = ThemeData.dark(useMaterial3: true);
    final baseText = GoogleFonts.outfitTextTheme(base.textTheme);

    return base.copyWith(
      brightness: Brightness.dark,
      primaryColor: _orange,
      scaffoldBackgroundColor: AppColors.backgroundDark,

      colorScheme: ColorScheme.dark(
        primary:          _orange,
        onPrimary:        _white,
        secondary:        AppColors.navyMid,
        onSecondary:      _white,
        tertiary:         AppColors.accent,
        onTertiary:       _white,
        surface:          AppColors.surfaceDark,
        onSurface:        AppColors.textPrimaryDark,
        error:            AppColors.rose,
        onError:          _white,
        outline:          AppColors.borderDark,
        inverseSurface:   _white,
        onInverseSurface: _navy,
      ),

      textTheme: baseText.copyWith(
        displayLarge:  GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimaryDark),
        headlineLarge: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark),
        titleLarge:    GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark),
        bodyLarge:     GoogleFonts.inter(fontSize: 16, color: AppColors.textPrimaryDark, height: 1.5),
        bodyMedium:    GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondaryDark, height: 1.5),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navyDark,
        foregroundColor: _white,
        elevation: 0,
        scrolledUnderElevation: 1,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: _white),
        iconTheme: const IconThemeData(color: _white),
      ),

      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.borderDark),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _orange, width: 2),
        ),
        hintStyle: TextStyle(color: AppColors.textSecondaryDark.withAlpha(150)),
        floatingLabelStyle: const TextStyle(color: _orange, fontWeight: FontWeight.w600),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: _white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: _white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _orange,
        foregroundColor: _white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedColor: _orange,
        labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimaryDark),
        secondaryLabelStyle: const TextStyle(color: _white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.borderDark),
        ),
        showCheckmark: false,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: _orange,
        unselectedLabelColor: AppColors.textSecondaryDark,
        labelStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: _orange, width: 3),
          insets: EdgeInsets.symmetric(horizontal: 8),
        ),
        indicatorColor: _orange,
        dividerColor: AppColors.borderDark,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: _orange,
        linearTrackColor: _orange.withAlpha(25),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardDark,
        contentTextStyle: GoogleFonts.inter(color: _white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        actionTextColor: _orange,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? _white : Colors.grey.shade600),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? _orange : Colors.grey.shade700),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? _orange : Colors.transparent),
        checkColor: WidgetStateProperty.all(_white),
        side: const BorderSide(color: AppColors.borderDark, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
        space: 1,
      ),

      iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
    );
  }
}
