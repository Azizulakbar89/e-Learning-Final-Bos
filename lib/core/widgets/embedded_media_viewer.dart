import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/url_helper.dart';
import 'app_loading_overlay.dart';
import 'embedded_media_iframe/embedded_media_iframe.dart';

class EmbeddedMediaViewer extends StatefulWidget {
  final String contentType; // 'youtube' | 'canva' | 'ppt'
  final String mediaUrl;
  final String title;
  final VoidCallback? onProgressTriggered;

  const EmbeddedMediaViewer({
    super.key,
    required this.contentType,
    required this.mediaUrl,
    required this.title,
    this.onProgressTriggered,
  });

  @override
  State<EmbeddedMediaViewer> createState() => _EmbeddedMediaViewerState();
}

class _EmbeddedMediaViewerState extends State<EmbeddedMediaViewer> {
  // Viewer mode for PPT: 'google' or 'office'
  String _pptViewerMode = 'google';

  /// Extracts YouTube video ID from various YouTube URL formats
  static String? extractYoutubeVideoId(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return null;
    final regExp = RegExp(
      r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/))([\w-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(clean);
    if (match != null) return match.group(1);
    if (RegExp(r'^[\w-]{11}$').hasMatch(clean)) return clean;
    return null;
  }

  /// Extracts Canva embed URL from share link or raw iframe code
  static String extractCanvaEmbedUrl(String raw) {
    var clean = raw.trim();
    if (clean.isEmpty) return clean;
    final iframeSrc =
        RegExp(r'src=["\x27]([^"\x27]+)["\x27]').firstMatch(clean);
    if (iframeSrc != null) {
      clean = iframeSrc.group(1)!;
    }
    if (clean.contains('canva.com/design/') && clean.contains('/edit')) {
      clean = clean.replaceAll('/edit', '/view');
    }
    if (clean.contains('canva.com/design/') && !clean.contains('embed')) {
      clean = clean.contains('?') ? '$clean&embed' : '$clean?embed';
    }
    return clean;
  }

  /// Checks if URL is a Google Slides presentation
  static bool isGoogleSlides(String url) =>
      url.contains('docs.google.com/presentation');

  static String getGoogleSlidesEmbedUrl(String url) {
    final clean = url.trim();
    final idMatch =
        RegExp(r'presentation\/d\/([a-zA-Z0-9_-]+)').firstMatch(clean);
    if (idMatch != null) {
      final id = idMatch.group(1);
      return 'https://docs.google.com/presentation/d/$id/embed?start=false&loop=false&delayms=3000';
    }
    return clean;
  }

  void _copyUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    AppSnackBar.showSuccess(
      context,
      'Tautan berhasil disalin ke clipboard! 📋',
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawUrl = widget.mediaUrl.trim();
    final type = widget.contentType.toLowerCase();

    if (rawUrl.isEmpty) {
      return _buildEmptyState('Media belum dilampirkan untuk materi ini.');
    }

    if (type == 'youtube') {
      return _buildYoutubeViewer(rawUrl);
    } else if (type == 'canva') {
      return _buildCanvaViewer(rawUrl);
    } else {
      return _buildPptViewer(rawUrl);
    }
  }

  // ────────────────────────── YOUTUBE VIEWER ──────────────────────────
  Widget _buildYoutubeViewer(String rawUrl) {
    final videoId = extractYoutubeVideoId(rawUrl);
    if (videoId == null) {
      return _buildFallbackUrlCard(
        title: 'Tonton Video YouTube',
        subtitle: rawUrl,
        icon: Icons.play_circle_fill_rounded,
        iconColor: Colors.redAccent,
        url: rawUrl,
      );
    }

    final embedUrl =
        'https://www.youtube-nocookie.com/embed/$videoId?autoplay=0&rel=0&modestbranding=1&playsinline=1';
    final viewKey = 'yt_$videoId';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000).withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFF0000).withAlpha(100)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, color: Color(0xFFFF0000), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'YouTube Video',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Salin Tautan Video',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 16),
                  onPressed: () => _copyUrl(rawUrl),
                ),
                IconButton(
                  tooltip: 'Buka di YouTube (Tab Baru)',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 17),
                  onPressed: () {
                    widget.onProgressTriggered?.call();
                    openExternalUrl('https://www.youtube.com/watch?v=$videoId');
                  },
                ),
              ],
            ),
          ),

          // Embedded IFrame Player
          AspectRatio(
            aspectRatio: 16 / 9,
            child: buildEmbeddedMediaIframe(
              url: embedUrl,
              viewKey: viewKey,
            ),
          ),

          // Bottom Quick Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(17)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ID: $videoId',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                InkWell(
                  onTap: () {
                    widget.onProgressTriggered?.call();
                    openExternalUrl('https://www.youtube.com/watch?v=$videoId');
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withAlpha(80),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withAlpha(120)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.smart_display_rounded, color: Colors.redAccent, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Buka di YouTube',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── CANVA VIEWER ──────────────────────────
  Widget _buildCanvaViewer(String rawUrl) {
    final embedUrl = extractCanvaEmbedUrl(rawUrl);
    final viewKey = 'canva_${embedUrl.hashCode.abs()}';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E131F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.cyan.withAlpha(120), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withAlpha(25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0E131F),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              border: Border(bottom: BorderSide(color: Colors.cyan.withAlpha(60))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.cyan.withAlpha(120)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.slideshow_rounded, color: Colors.cyan, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Canva Interactive Embed',
                        style: TextStyle(
                            color: Colors.cyan,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Salin Tautan Canva',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 16),
                  onPressed: () => _copyUrl(rawUrl),
                ),
                IconButton(
                  tooltip: 'Buka Presentasi di Canva (Tab Baru)',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 17),
                  onPressed: () {
                    widget.onProgressTriggered?.call();
                    openExternalUrl(rawUrl);
                  },
                ),
              ],
            ),
          ),

          // Embedded Canva Iframe (Responsive Aspect Ratio with comfortable height for Canva's controls)
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = (w * 9 / 16 + 65).clamp(280.0, 560.0);
              return GestureDetector(
                onTap: () {
                  focusIframe(viewKey);
                  widget.onProgressTriggered?.call();
                },
                child: SizedBox(
                  height: h,
                  child: buildEmbeddedMediaIframe(
                    url: embedUrl,
                    viewKey: viewKey,
                    height: h,
                  ),
                ),
              );
            },
          ),

          // Bottom Action Bar & Navigation Guidance
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0E131F),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(17)),
              border: Border(top: BorderSide(color: Colors.cyan.withAlpha(60))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Highlighted Navigation Hint
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.cyanAccent.withAlpha(60)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.touch_app_rounded, color: Colors.cyanAccent, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Klik panah ◀ dan ▶ di pojok kiri bawah slide Canva untuk berpindah halaman.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Controls & Fullscreen Buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Keyboard Focus Quick Button
                    InkWell(
                      onTap: () {
                        widget.onProgressTriggered?.call();
                        focusIframe(viewKey);
                        AppSnackBar.showInfo(
                          context,
                          '⌨️ Kontrol aktif! Gunakan tombol panah ← dan → pada keyboard untuk ganti slide.',
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.keyboard_rounded, color: Colors.white70, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Gunakan Keyboard (← / →)',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // In-App Fullscreen Button
                        InkWell(
                          onTap: () {
                            widget.onProgressTriggered?.call();
                            _openFullscreenInteractiveViewer(
                              context: context,
                              embedUrl: embedUrl,
                              rawUrl: rawUrl,
                              title: widget.title,
                              viewKey: viewKey,
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.cyan.shade900.withAlpha(140),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.cyanAccent.withAlpha(120)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fullscreen_rounded, color: Colors.cyanAccent, size: 15),
                                SizedBox(width: 4),
                                Text(
                                  'Layar Penuh',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFullscreenInteractiveViewer({
    required BuildContext context,
    required String embedUrl,
    required String rawUrl,
    required String title,
    required String viewKey,
  }) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (dialogCtx) => Dialog.fullscreen(
        backgroundColor: const Color(0xFF0A0F1D),
        child: SafeArea(
          child: Column(
            children: [
              // Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF131B2E),
                  border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      tooltip: 'Tutup Layar Penuh',
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Mode Presentasi Interaktif',
                            style: TextStyle(color: Colors.cyanAccent, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 18),
                      tooltip: 'Buka di Canva',
                      onPressed: () {
                        widget.onProgressTriggered?.call();
                        openExternalUrl(rawUrl);
                      },
                    ),
                  ],
                ),
              ),

              // Expanded Fullscreen Iframe
              Expanded(
                child: Container(
                  color: Colors.black,
                  child: buildEmbeddedMediaIframe(
                    url: embedUrl,
                    viewKey: '${viewKey}_fullscreen',
                  ),
                ),
              ),

              // Bottom Navigation Helper Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF131B2E),
                  border: Border(top: BorderSide(color: Color(0xFF1E293B))),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.touch_app_rounded, color: Colors.cyanAccent, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Gunakan tombol panah ◀ dan ▶ pada toolbar Canva di kiri bawah, atau tombol panah keyboard ← →.',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5),
                      ),
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

  // ────────────────────────── PPT / DOCUMENT VIEWER ──────────────────────────
  Widget _buildPptViewer(String rawUrl) {
    String embedUrl;
    final isGSlides = isGoogleSlides(rawUrl);

    if (isGSlides) {
      embedUrl = getGoogleSlidesEmbedUrl(rawUrl);
    } else {
      if (_pptViewerMode == 'office') {
        embedUrl =
            'https://view.officeapps.live.com/op/embed.aspx?src=${Uri.encodeComponent(rawUrl)}';
      } else {
        embedUrl =
            'https://docs.google.com/viewer?url=${Uri.encodeComponent(rawUrl)}&embedded=true';
      }
    }

    final viewKey = 'ppt_${embedUrl.hashCode.abs()}_$_pptViewerMode';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withAlpha(25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEA580C), Color(0xFFC2410C)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                const Icon(Icons.co_present_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  isGSlides ? 'Google Slides Presentation' : 'Presentasi PPT / Dokumen',
                  style: GoogleFonts.outfit(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                // Viewer Selector if not Google Slides
                if (!isGSlides) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() => _pptViewerMode = 'google');
                            widget.onProgressTriggered?.call();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _pptViewerMode == 'google'
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Google',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _pptViewerMode == 'google'
                                    ? const Color(0xFFC2410C)
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() => _pptViewerMode = 'office');
                            widget.onProgressTriggered?.call();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _pptViewerMode == 'office'
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Office',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _pptViewerMode == 'office'
                                    ? const Color(0xFFC2410C)
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                IconButton(
                  tooltip: 'Buka di Tab Baru',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 17),
                  onPressed: () => openExternalUrl(rawUrl),
                ),
              ],
            ),
          ),

          // Embedded IFrame Viewer (Responsive Height)
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = (w * 9 / 16 + 50).clamp(260.0, 520.0);
              return SizedBox(
                height: h,
                child: buildEmbeddedMediaIframe(
                  url: embedUrl,
                  viewKey: viewKey,
                  height: h,
                ),
              );
            },
          ),

          // Bottom Action Bar with Direct Download and Fullscreen
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(17)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                // Unduh File Presentasi
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text(
                    'Unduh File Materi',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    widget.onProgressTriggered?.call();
                    openExternalUrl(rawUrl);
                  },
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Salin Tautan File',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.copy_rounded, color: Color(0xFF78350F), size: 16),
                      onPressed: () => _copyUrl(rawUrl),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        widget.onProgressTriggered?.call();
                        openExternalUrl(rawUrl);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fullscreen_rounded, color: Color(0xFFB45309), size: 15),
                            SizedBox(width: 4),
                            Text(
                              'Layar Penuh',
                              style: TextStyle(
                                  color: Color(0xFF92400E),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── FALLBACKS & EMPTY STATES ──────────────────────────
  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.hourglass_empty_rounded, size: 40, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackUrlCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String url,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 52, color: iconColor),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.outfit(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => openExternalUrl(url),
            icon: const Icon(Icons.launch_rounded, size: 16),
            label: const Text('Buka Konten'),
          ),
        ],
      ),
    );
  }
}
