import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/gamification_model.dart';
import '../../../core/models/user_model.dart';

/// Dialog perayaan badge baru siswa.
/// Muncul otomatis saat profil dibuka untuk setiap badge yang baru diraih.
/// Jika user klik "Nanti" -> badge tersebut tidak ditampilkan lagi.
class BadgeShareDialog extends StatefulWidget {
  final BadgeModel badge;
  final UserModel student;

  const BadgeShareDialog({
    super.key,
    required this.badge,
    required this.student,
  });

  static String _prefKey(String badgeId, String studentId) =>
      'badge_share_dismissed_${studentId}_$badgeId';

  /// Cek semua badge earned dan tampilkan satu per satu yang belum pernah di-dismiss
  static Future<void> checkAndShowNewBadges({
    required BuildContext context,
    required List<BadgeModel> badges,
    required UserModel student,
  }) async {
    final earned = badges.where((b) => b.isEarned).toList();
    for (final badge in earned) {
      if (!context.mounted) break;
      final prefs = await SharedPreferences.getInstance();
      if (!context.mounted) break;
      final dismissed = prefs.getBool(_prefKey(badge.id, student.id)) ?? false;
      if (!dismissed) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withAlpha(180),
          builder: (_) => BadgeShareDialog(badge: badge, student: student),
        );
        await Future.delayed(const Duration(milliseconds: 350));
      }
    }
  }

  @override
  State<BadgeShareDialog> createState() => _BadgeShareDialogState();
}

class _BadgeShareDialogState extends State<BadgeShareDialog>
    with TickerProviderStateMixin {
  final GlobalKey _cardKey = GlobalKey();
  bool _isSharing = false;

  late AnimationController _scaleCtrl;
  late AnimationController _shineCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _shineAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _shineCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
        reverseDuration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _scaleAnim =
        CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _shineAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _shineCtrl, curve: Curves.easeInOut),
    );
    _scaleCtrl.forward();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _shineCtrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss({bool share = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      BadgeShareDialog._prefKey(widget.badge.id, widget.student.id),
      true,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    if (share) {
      await Future.delayed(const Duration(milliseconds: 200));
      await _doShare();
    }
  }

  Future<Uint8List?> _captureCard() async {
    try {
      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[BadgeShare] Capture error: \$e');
      return null;
    }
  }

  Future<void> _doShare() async {
    if (_isSharing) return;
    if (mounted) setState(() => _isSharing = true);
    try {
      final bytes = await _captureCard();
      if (bytes == null) {
        if (mounted) setState(() => _isSharing = false);
        return;
      }
      final xFile = XFile.fromData(bytes,
          mimeType: 'image/png', name: 'badge_${widget.badge.id}.png');
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: '${widget.badge.icon} Aku baru saja mendapatkan lencana '
              '"${widget.badge.title}"!\n'
              '${widget.badge.description}\n\n'
              '#eLearning #Spemdalas #Lencana #BelajarTerus',
        ),
      );
    } catch (e) {
      debugPrint('[BadgeShare] Share error: \$e');
    }
    if (mounted) setState(() => _isSharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final student = widget.student;
    final bc = badge.color;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Card screenshot-able ──
              RepaintBoundary(
                key: _cardKey,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        bc,
                        Color.lerp(bc, Colors.white, 0.2) ?? bc,
                        bc.withAlpha(190),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                          color: bc.withAlpha(130),
                          blurRadius: 32,
                          offset: const Offset(0, 12)),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header label
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'e-Learning Spemdalas  •  Lencana Baru',
                          style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 22),
                      // Icon badge animasi
                      AnimatedBuilder(
                        animation: _shineAnim,
                        builder: (_, child) => Transform.scale(
                            scale: _shineAnim.value, child: child),
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withAlpha(30),
                            border: Border.all(
                                color: Colors.white.withAlpha(100),
                                width: 3),
                          ),
                          child: Center(
                            child: Text(badge.icon,
                                style: const TextStyle(fontSize: 50)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Lencana Baru Diraih! ✨',
                          style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        badge.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                          shadows: const [
                            Shadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 4)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badge.description,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Info siswa
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white.withAlpha(50),
                            child: Text(
                              student.fullName.isNotEmpty
                                  ? student.fullName[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(student.fullName,
                                  style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              if ((student.className ??
                                      student.classId ??
                                      '')
                                  .isNotEmpty)
                                Text(
                                    student.className ??
                                        student.classId ??
                                        '',
                                    style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: Colors.white70)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '#eLearning  #Spemdalas  #BelajarTerus',
                        style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: Colors.white60,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Tombol Aksi ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Selamat! Kamu mendapat lencana baru! 🎉',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800, fontSize: 14.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bagikan pencapaian ini ke Instagram atau WhatsApp!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _isSharing
                                ? null
                                : () => _dismiss(share: true),
                            icon: _isSharing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Icon(Icons.share_rounded,
                                    size: 18),
                            label: Text(
                              _isSharing ? 'Memproses...' : 'Bagikan 🚀',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSharing
                                ? null
                                : () => _dismiss(share: false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              side:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            child: const Text('Nanti',
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
