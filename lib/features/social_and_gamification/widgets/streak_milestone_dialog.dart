import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/social_share_service.dart';


/// Dialog perayaan ala TikTok — muncul setiap kelipatan 10 streak
class StreakMilestoneDialog extends StatefulWidget {
  final int streakCount;
  final String userName;
  final String userClass;

  const StreakMilestoneDialog({
    super.key,
    required this.streakCount,
    required this.userName,
    required this.userClass,
  });

  /// Tampilkan dialog jika [streakCount] adalah kelipatan 10
  static void showIfMilestone({
    required BuildContext context,
    required int streakCount,
    required String userName,
    required String userClass,
  }) {
    if (streakCount > 0 && streakCount % 10 == 0) {
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withAlpha(180),
        builder: (_) => StreakMilestoneDialog(
          streakCount: streakCount,
          userName: userName,
          userClass: userClass,
        ),
      );
    }
  }

  @override
  State<StreakMilestoneDialog> createState() => _StreakMilestoneDialogState();
}

class _StreakMilestoneDialogState extends State<StreakMilestoneDialog>
    with TickerProviderStateMixin {
  final GlobalKey _cardKey = GlobalKey();
  bool _isSharing = false;

  late AnimationController _scaleCtrl;
  late AnimationController _fireCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fireAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fireCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
        reverseDuration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);

    _scaleAnim =
        CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _fireAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _fireCtrl, curve: Curves.easeInOut),
    );
    _scaleCtrl.forward();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _fireCtrl.dispose();
    super.dispose();
  }

  String _getMilestoneQuote(int count) {
    if (count >= 100) return 'Luar biasa! Kamu adalah legenda belajar! 🏆';
    if (count >= 50) return 'Setengah ratus hari tanpa henti! Lanjutkan! 💎';
    if (count >= 30) return 'Sebulan penuh semangat belajar! Keren banget! 🌟';
    if (count >= 20) return 'Dua puluh hari! Konsistensi adalah kuncinya! ✨';
    return 'Sepuluh hari berturut-turut! Mantap jiwa! 🎯';
  }

  Future<Uint8List?> _captureCard() async {
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[StreakShare] Error capturing card: \$e');
      return null;
    }
  }

  Future<void> _shareCard() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final bytes = await _captureCard();
      if (bytes == null || !mounted) {
        setState(() => _isSharing = false);
        return;
      }
      await SocialShareService.showShareChooser(
        context: context,
        imageBytes: bytes,
        fileName: 'streak_${widget.streakCount}_hari.png',
        text:
            '🔥 ${widget.streakCount} Hari Streak Belajar!\n${_getMilestoneQuote(widget.streakCount)}\n\n#eLearning #BelajarTerus #StreakBelajar',
        title: 'Bagikan Streak Belajar 🔥',
      );
    } catch (e) {
      debugPrint('[StreakShare] Error sharing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membagikan. Coba lagi.')),
        );
      }
    }
    if (mounted) setState(() => _isSharing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Share Card ───
              RepaintBoundary(
                key: _cardKey,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF5722), Color(0xFFFF9800), Color(0xFFFFD600)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5722).withAlpha(120),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(40),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'e-Learning • Streak Achievement',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedBuilder(
                        animation: _fireAnim,
                        builder: (_, child) =>
                            Transform.scale(scale: _fireAnim.value, child: child),
                        child: const Text('🔥', style: TextStyle(fontSize: 64)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.streakCount}',
                        style: GoogleFonts.outfit(
                          fontSize: 80,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                          shadows: const [
                            Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                          ],
                        ),
                      ),
                      Text(
                        'HARI STREAK BELAJAR',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withAlpha(220),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getMilestoneQuote(widget.streakCount),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: Colors.white.withAlpha(50),
                            child: Text(
                              widget.userName.isNotEmpty
                                  ? widget.userName[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.userName,
                                style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              if (widget.userClass.isNotEmpty)
                                Text(
                                  widget.userClass,
                                  style: GoogleFonts.outfit(
                                      fontSize: 10.5, color: Colors.white70),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '#BelajarTerus  #eLearning  #StreakBelajar',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          color: Colors.white60,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ─── Action Buttons ───
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Bagikan pencapaianmu! 🎉',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Screenshot kartu di atas lalu posting ke Instagram / WhatsApp',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _isSharing ? null : _shareCard,
                            icon: _isSharing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.share_rounded),
                            label: Text(_isSharing ? 'Memproses...' : 'Bagikan 🚀'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: const Text('Lewati'),
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
