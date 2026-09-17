import 'package:flutter/material.dart';

/// ─── AppColors ───────────────────────────────────────────────────────────────
/// Tema: ORANGE + BIRU DONGKER + PUTIH
///   Orange  (#F97316) → warna aksi utama: tombol, FAB, highlight, badge
///   Navy    (#0D2B6E) → warna struktural: AppBar, header, nav rail, dark card
///   White   (#FFFFFF) → surface: kartu, form, background
/// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  // ── Orange Palette ──────────────────────────────────────────────────────────
  static const Color orange      = Color(0xFFF97316); // Orange 500 – PRIMARY ACTION
  static const Color orangeLight = Color(0xFFFB923C); // Orange 400
  static const Color orangeDark  = Color(0xFFEA580C); // Orange 600
  static const Color orangePale  = Color(0xFFFFF4ED); // Orange 50 (light bg tint)

  // ── Navy Palette ─────────────────────────────────────────────────────────────
  static const Color navy        = Color(0xFF0D2B6E); // Navy 700  – STRUCTURAL
  static const Color navyMid     = Color(0xFF1A4DB5); // Navy 500
  static const Color navyLight   = Color(0xFF1A4DB5); // Navy light alias
  static const Color navyDark    = Color(0xFF071540); // Navy 900
  static const Color navyDeep    = Color(0xFF040D1F); // Navy 950

  // ── Alias for code that uses 'primary' ──────────────────────────────────────
  static const Color primary      = orange;        // main CTA = orange
  static const Color primaryLight = orangeLight;
  static const Color primaryDark  = orangeDark;

  // ── Semantic / Status ────────────────────────────────────────────────────────
  static const Color accent   = Color(0xFF38BDF8); // Sky blue accent
  static const Color emerald  = Color(0xFF10B981); // Success / Points
  static const Color amber    = Color(0xFFF59E0B); // Streak / Warning
  static const Color rose     = Color(0xFFF43F5E); // Error / Alert
  static const Color purple   = Color(0xFF8B5CF6); // AI / Badges

  // ── Light Surface ─────────────────────────────────────────────────────────────
  static const Color backgroundLight    = Color(0xFFF8F9FF); // Very faint cool white
  static const Color surfaceLight       = Colors.white;
  static const Color textPrimaryLight   = Color(0xFF071540); // Navy deep
  static const Color textSecondaryLight = Color(0xFF4A6080);
  static const Color borderLight        = Color(0xFFE2E8F0);

  // ── Dark Surface ─────────────────────────────────────────────────────────────
  static const Color backgroundDark    = Color(0xFF060E1F);
  static const Color surfaceDark       = Color(0xFF0D1B38);
  static const Color cardDark          = Color(0xFF132040);
  static const Color textPrimaryDark   = Color(0xFFF0F6FF);
  static const Color textSecondaryDark = Color(0xFF7A9CC5);
  static const Color borderDark        = Color(0xFF1E3560);

  // ── Gamification ─────────────────────────────────────────────────────────────
  static const Color streakFire = Color(0xFFFF5722);
  static const Color streakGold = Color(0xFFFFD700);

  // ── Gradient Library ─────────────────────────────────────────────────────────

  /// Orange → Amber  (primary CTA / hero sections)
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [Color(0xFFEA580C), Color(0xFFF97316), Color(0xFFFB923C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Navy dark → Navy mid  (AppBar / structural headers)
  static const LinearGradient navyGradient = LinearGradient(
    colors: [Color(0xFF040D1F), Color(0xFF0D2B6E), Color(0xFF1A4DB5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Orange → Navy  (hero banners / mixed accent)
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFFEA580C), Color(0xFFF97316), Color(0xFF0D2B6E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Teal / Sky (informational stat card)
  static const LinearGradient tealGradient = LinearGradient(
    colors: [Color(0xFF0369A1), Color(0xFF38BDF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Emerald (success stat card)
  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF047857), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Rose/Red (error/lock stat card)
  static const LinearGradient roseGradient = LinearGradient(
    colors: [Color(0xFFBE123C), Color(0xFFF43F5E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Purple/Violet (AI/badges)
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF5B21B6), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Legacy alias
  static const LinearGradient primaryGradient = orangeGradient;
  static const LinearGradient aiGradient      = purpleGradient;
  static const LinearGradient examLockGradient = roseGradient;

  static const LinearGradient flameGradient = LinearGradient(
    colors: [Color(0xFFFF7A00), Color(0xFFFF0055)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
