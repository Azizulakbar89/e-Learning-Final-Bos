import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GLOBAL HELPER: showLoadingDialog
// ─────────────────────────────────────────────────────────────────────────────

/// Tampilkan overlay loading animasi, jalankan [action], lalu otomatis
/// tampilkan snackbar sukses atau error setelahnya.
Future<bool> showLoadingDialog(
  BuildContext context, {
  required String message,
  required Future<void> Function() action,
  String successMessage = 'Berhasil!',
  String? errorMessage,
  bool popOnSuccess = false,
}) async {
  bool success = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withAlpha(100),
    builder: (_) => _LoadingOverlay(message: message),
  );

  try {
    await action();
    success = true;
  } catch (e) {
    success = false;
  }

  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  await Future.delayed(const Duration(milliseconds: 120));

  if (context.mounted) {
    if (success) {
      AppSnackBar.success(context, successMessage);
      if (popOnSuccess && context.mounted) Navigator.of(context).maybePop();
    } else {
      AppSnackBar.error(
        context,
        errorMessage ?? 'Terjadi kesalahan. Silakan coba lagi.',
      );
    }
  }

  return success;
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: _LoadingOverlay (internal)
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingOverlay extends StatefulWidget {
  final String message;

  const _LoadingOverlay({required this.message});

  @override
  State<_LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<_LoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.80, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            decoration: BoxDecoration(
              color: const Color(0xFF040D1F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withAlpha(30)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(80),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryLight,
                          ),
                          backgroundColor: AppColors.primaryLight.withAlpha(30),
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF7A00), Color(0xFFFF0055)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF5722).withAlpha(80),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('⚡', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.message,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Mohon tunggu sebentar...',
                  style: TextStyle(
                    color: Colors.white.withAlpha(130),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP SNACK BAR — terpusat menggantikan ScaffoldMessenger tersebar
// ─────────────────────────────────────────────────────────────────────────────

class AppSnackBar {
  AppSnackBar._();

  static void success(BuildContext context, String message) {
    _show(context, message: message, icon: Icons.check_circle_rounded,
        bgColor: const Color(0xFF059669));
  }

  static void showSuccess(BuildContext context, String message) => success(context, message);

  static void error(BuildContext context, String message) {
    _show(context, message: message, icon: Icons.error_rounded,
        bgColor: const Color(0xFFDC2626));
  }

  static void showError(BuildContext context, String message) => error(context, message);

  static void warning(BuildContext context, String message) {
    _show(context, message: message, icon: Icons.warning_amber_rounded,
        bgColor: const Color(0xFFF59E0B));
  }

  static void showWarning(BuildContext context, String message) => warning(context, message);

  static void info(BuildContext context, String message) {
    _show(context, message: message, icon: Icons.info_rounded,
        bgColor: AppColors.primary);
  }

  static void showInfo(BuildContext context, String message) => info(context, message);

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color bgColor,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
