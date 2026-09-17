import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_colors.dart';
import '../models/app_version_model.dart';
import '../services/firebase_service.dart';

class AppUpdateDialog extends StatefulWidget {
  final AppUpdateCheckResult updateResult;

  const AppUpdateDialog({
    super.key,
    required this.updateResult,
  });

  static Future<void> show(
    BuildContext context,
    AppUpdateCheckResult result,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: !result.isForceUpdate,
      builder: (ctx) => PopScope(
        canPop: !result.isForceUpdate,
        child: AppUpdateDialog(updateResult: result),
      ),
    );
  }

  /// Helper untuk memicu pengecekan pembaruan secara manual saat tombol ditekan
  static Future<void> handleManualUpdateCheck(BuildContext context) async {
    final fb = Provider.of<FirebaseService>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 10),
            Text('Memeriksa versi aplikasi terbaru...'),
          ],
        ),
        duration: Duration(seconds: 1),
      ),
    );

    final result = await fb.checkForAppUpdate();
    if (!context.mounted) return;

    if (result.hasUpdate) {
      show(context, result);
    } else {
      // Jika versi sudah sama, tetap sediakan aksi "Uji Pasang Update" agar pengguna bisa mencoba update langsung
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aplikasi Anda versi v${result.currentVersion} (Terkini)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Uji Pasang',
            textColor: Colors.amberAccent,
            onPressed: () {
              show(context, result);
            },
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = '';

  Future<void> _startInAppUpdate() async {
    final server = widget.updateResult.serverVersion;
    final urlString = server?.apkUrl.trim() ?? '';

    if (urlString.isEmpty) {
      _showUrlInputDialog();
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusText = 'Menghubungkan ke server unduhan...';
    });

    try {
      final uri = Uri.parse(urlString);

      // Jika URL mengarah ke web browser atau drive preview, buka browser eksternal
      if (!urlString.toLowerCase().endsWith('.apk') && !urlString.contains('download') && !urlString.contains('export=download')) {
        setState(() => _isDownloading = false);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      final request = http.Request('GET', uri);
      final response = await http.Client().send(request);

      if (response.statusCode >= 400) {
        throw 'Server merespons kode ${response.statusCode}';
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/elearning_update.apk');
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final sink = apkFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (mounted) {
          setState(() {
            if (totalBytes > 0) {
              _progress = receivedBytes / totalBytes;
              final mbRec = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
              final mbTot = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
              final pct = (_progress * 100).toInt();
              _statusText = 'Mengunduh APK: $mbRec MB / $mbTot MB ($pct%)';
            } else {
              final mbRec = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
              _statusText = 'Mengunduh APK: $mbRec MB...';
            }
          });
        }
      }

      await sink.flush();
      await sink.close();

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _statusText = 'Membuka installer paket Android...';
        });
      }

      // Picu installer native Android via MethodChannel
      const installerChannel = MethodChannel('www.azizul.com/app_installer');
      try {
        await installerChannel.invokeMethod('installApk', {'filePath': apkFile.path});
      } catch (e) {
        // Fallback jika installer gagal
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusText = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunduh langsung: $e. Membuka di browser...'),
            backgroundColor: Colors.orange,
          ),
        );
        try {
          await launchUrl(Uri.parse(urlString), mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
    }
  }

  void _showUrlInputDialog() {
    final fb = Provider.of<FirebaseService>(context, listen: false);
    final urlController = TextEditingController(text: fb.appVersionConfig?.apkUrl ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tautan Unduhan APK Belum Disetel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan tautan berkas APK (Google Drive, GitHub, atau web hosting Anda):',
              style: TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                hintText: 'https://...',
                labelText: 'URL Berkas APK',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              final newUrl = urlController.text.trim();
              if (newUrl.isNotEmpty) {
                Navigator.pop(ctx);
                await fb.publishAppUpdate(
                  version: widget.updateResult.serverVersion?.latestVersion ?? '1.0.1',
                  versionCode: (widget.updateResult.serverVersion?.versionCode ?? 1) + 1,
                  apkUrl: newUrl,
                  releaseNotes: 'Pembaruan aplikasi siap dipasang.',
                );
                _startInAppUpdate();
              }
            },
            child: const Text('Simpan & Pasang'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final server = widget.updateResult.serverVersion;
    final newVersion = server?.latestVersion ?? '1.0.1';
    final releaseNotes = server?.releaseNotes.trim() ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Icon Badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(80),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  size: 36,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'Pembaruan Tersedia!',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Version chip transition
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'v${widget.updateResult.currentVersion}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF3B82F6)),
                    ),
                    Text(
                      'v$newVersion',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Description / Release notes
              if (releaseNotes.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Catatan Rilis Baru:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      releaseNotes,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.5,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Text(
                  'Versi terbaru aplikasi telah dirilis dengan perbaikan performa dan fitur baru.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],

              // Downloading indicator & progress bar
              if (_isDownloading) ...[
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: AppColors.primary,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 10),
                Text(
                  _statusText,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isDownloading ? null : _startInAppUpdate,
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download_rounded, size: 20),
                  label: Text(
                    _isDownloading ? 'Mengunduh Pembaruan...' : 'Perbarui Sekarang 🚀',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              if (!widget.updateResult.isForceUpdate && !_isDownloading) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Nanti Saja',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
