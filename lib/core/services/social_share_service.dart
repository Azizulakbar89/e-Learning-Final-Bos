import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';

class SocialShareService {
  static const MethodChannel _channel = MethodChannel('www.azizul.com/social_share');

  /// Menyimpan bytes gambar ke temporary file lokal
  static Future<File> _saveImageToTemp(Uint8List imageBytes, String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_\.-]'), '_');
    final file = File('${tempDir.path}/$sanitizedName');
    await file.writeAsBytes(imageBytes);
    return file;
  }

  /// Bagikan langsung ke Instagram (Story / Post)
  static Future<bool> shareToInstagram({
    required Uint8List imageBytes,
    required String fileName,
    String? caption,
  }) async {
    try {
      final file = await _saveImageToTemp(imageBytes, fileName);

      if (!kIsWeb && Platform.isAndroid) {
        final bool? success = await _channel.invokeMethod<bool>('shareToInstagram', {
          'filePath': file.path,
          'caption': caption ?? '',
        });
        if (success == true) return true;
      }

      // iOS or fallback
      final xFile = XFile(file.path, mimeType: 'image/png');
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: caption,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[SocialShareService] Error shareToInstagram: $e');
      // Fallback to generic share
      try {
        final xFile = XFile.fromData(imageBytes, mimeType: 'image/png', name: fileName);
        await SharePlus.instance.share(
          ShareParams(
            files: [xFile],
            text: caption,
          ),
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Bagikan langsung ke WhatsApp (Status / Chat)
  static Future<bool> shareToWhatsApp({
    required Uint8List imageBytes,
    required String fileName,
    required String text,
  }) async {
    try {
      final file = await _saveImageToTemp(imageBytes, fileName);

      if (!kIsWeb && Platform.isAndroid) {
        final bool? success = await _channel.invokeMethod<bool>('shareToWhatsApp', {
          'filePath': file.path,
          'text': text,
        });
        if (success == true) return true;
      }

      // iOS / other platforms: try url_launcher scheme then SharePlus
      final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }

      final xFile = XFile(file.path, mimeType: 'image/png');
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: text,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[SocialShareService] Error shareToWhatsApp: $e');
      try {
        final xFile = XFile.fromData(imageBytes, mimeType: 'image/png', name: fileName);
        await SharePlus.instance.share(
          ShareParams(
            files: [xFile],
            text: text,
          ),
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Bagikan via system share sheet
  static Future<void> shareSystem({
    required Uint8List imageBytes,
    required String fileName,
    required String text,
  }) async {
    final xFile = XFile.fromData(imageBytes, mimeType: 'image/png', name: fileName);
    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        text: text,
      ),
    );
  }

  /// Menampilkan modal bottom sheet pilihan platform (Instagram vs WhatsApp vs Lainnya)
  static Future<void> showShareChooser({
    required BuildContext context,
    required Uint8List imageBytes,
    required String fileName,
    required String text,
    String? title,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.share_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title ?? 'Bagikan Pencapaian 🎉',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Pilih platform tujuan postingan Anda:',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ─── Pilihan 1: Instagram (Post / Story) ───
              InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  await shareToInstagram(
                    imageBytes: imageBytes,
                    fileName: fileName,
                    caption: text,
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF833AB4), // Instagram Purple
                        Color(0xFFFD1D1D), // Instagram Red
                        Color(0xFFFCB045), // Instagram Orange
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFD1D1D).withAlpha(80),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instagram',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Posting ke Cerita (Story) atau Feed Instagram',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: Colors.white.withAlpha(220),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ─── Pilihan 2: WhatsApp (Status / Chat) ───
              InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  await shareToWhatsApp(
                    imageBytes: imageBytes,
                    fileName: fileName,
                    text: text,
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366), // WhatsApp Green
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF25D366).withAlpha(80),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WhatsApp',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Posting ke Status WhatsApp atau kirim ke Obrolan',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: Colors.white.withAlpha(220),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ─── Pilihan 3: Aplikasi Lainnya ───
              InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  await shareSystem(
                    imageBytes: imageBytes,
                    fileName: fileName,
                    text: text,
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.more_horiz_rounded,
                          color: Color(0xFF334155),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aplikasi Lainnya',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Buka pilihan sistem untuk aplikasi lainnya atau salin berkas',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
