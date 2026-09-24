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
  static const Color orangePale  = Color(0xFFFFF7ED); // Orange 50 (light bg tint)

  // ── Navy Palette ─────────────────────────────────────────────────────────────
  static const Color navy        = Color(0xFF0F2552); // Navy 800  – STRUCTURAL
  static const Color navyMid     = Color(0xFF1E3A8A); // Navy 700
  static const Color navyLight   = Color(0xFF2563EB); // Royal Blue
  static const Color navyDark    = Color(0xFF0A1931); // Navy 900
  static const Color navyDeep    = Color(0xFF060F1E); // Navy 950

  // ── Alias for code that uses 'primary' ──────────────────────────────────────
  static const Color primary      = orange;        // main CTA = orange
  static const Color primaryLight = orangeLight;
  static const Color primaryDark  = orangeDark;

  // ── Semantic / Status ────────────────────────────────────────────────────────
  static const Color accent   = Color(0xFF0EA5E9); // Sky blue 500
  static const Color emerald  = Color(0xFF10B981); // Emerald 500 - Success / Points
  static const Color amber    = Color(0xFFF59E0B); // Amber 500 - Warning / Streak
  static const Color rose     = Color(0xFFF43F5E); // Rose 500 - Error / Alert
  static const Color purple   = Color(0xFF8B5CF6); // Violet 500 - AI / Badges

  // ── Light Surface (Tailwind Slate Clean Standard) ───────────────────────────
  static const Color backgroundLight    = Color(0xFFF8FAFC); // Slate 50: Bersih, sejuk & bebas silau
  static const Color surfaceLight       = Colors.white;
  static const Color textPrimaryLight   = Color(0xFF0F172A); // Slate 900: Tajam & elegan
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate 500: Rasio kontras optimal
  static const Color borderLight        = Color(0xFFE2E8F0); // Slate 200: Garis batas halus & presisi

  // ── Dark Surface ─────────────────────────────────────────────────────────────
  static const Color backgroundDark    = Color(0xFF0B132B);
  static const Color surfaceDark       = Color(0xFF111D3D);
  static const Color cardDark          = Color(0xFF16254C);
  static const Color textPrimaryDark   = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color borderDark        = Color(0xFF1E293B);

  // ── Gamification ─────────────────────────────────────────────────────────────
  static const Color streakFire = Color(0xFFFF5722);
  static const Color streakGold = Color(0xFFF59E0B);

  // ── Reusable Diffusion Shadows ───────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        const BoxShadow(
          color: Color(0x0A0F172A),
          blurRadius: 16,
          offset: Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get floatingShadow => [
        const BoxShadow(
          color: Color(0x140F172A),
          blurRadius: 20,
          offset: Offset(0, 8),
          spreadRadius: 0,
        ),
      ];

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
