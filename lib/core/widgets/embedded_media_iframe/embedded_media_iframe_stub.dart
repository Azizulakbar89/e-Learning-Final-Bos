import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../utils/url_helper.dart';

void focusIframe(String viewKey) {}

Widget buildEmbeddedMediaIframe({
  required String url,
  required String viewKey,
  double? height,
}) {
  final isSupportedMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
  if (!isSupportedMobile) {
    return _buildFallbackStub(url: url, height: height);
  }

  return MobileEmbeddedWebView(
    key: ValueKey('wv_$viewKey'),
    url: url,
    viewKey: viewKey,
    height: height,
  );
}

class MobileEmbeddedWebView extends StatefulWidget {
  final String url;
  final String viewKey;
  final double? height;

  const MobileEmbeddedWebView({
    super.key,
    required this.url,
    required this.viewKey,
    this.height,
  });

  @override
  State<MobileEmbeddedWebView> createState() => _MobileEmbeddedWebViewState();
}

class _MobileEmbeddedWebViewState extends State<MobileEmbeddedWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant MobileEmbeddedWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  void _initController() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame ?? true) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _errorMessage = error.description;
                });
              }
            }
          },
        ),
      );

    if (Platform.isAndroid && controller.platform is AndroidWebViewController) {
      try {
        (controller.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      } catch (_) {}
    }

    try {
      controller.loadRequest(Uri.parse(widget.url));
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
    }

    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    final containerHeight = widget.height ?? 340.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: containerHeight,
        color: const Color(0xFF0F172A),
        child: Stack(
          children: [
            Positioned.fill(
              child: !_hasError
                  ? WebViewWidget(controller: _controller)
                  : _buildErrorView(),
            ),
            if (_isLoading && !_hasError)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF0F172A),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF06B6D4),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Memuat materi interaktif...',
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_rounded, color: Colors.amberAccent, size: 36),
            const SizedBox(height: 8),
            Text(
              'Gagal memuat konten',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _isLoading = true;
                    });
                    _controller.reload();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Coba Lagi', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => openExternalUrl(widget.url),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 14),
                  label: const Text('Buka di Browser', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildFallbackStub({required String url, double? height}) {
  return Container(
    width: double.infinity,
    height: height ?? 320,
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF334155)),
    ),
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.open_in_browser_rounded, color: Colors.cyanAccent, size: 48),
          const SizedBox(height: 12),
          Text(
            'Konten Interaktif Tersedia',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Buka konten materi pembelajaran langsung di peramban:',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => openExternalUrl(url),
            icon: const Icon(Icons.launch_rounded, size: 16),
            label: const Text('Buka Konten'),
          ),
        ],
      ),
    ),
  );
}
