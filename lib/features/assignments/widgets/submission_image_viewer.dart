import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/url_helper.dart';
import '../../../core/widgets/app_loading_overlay.dart';

/// Modal dialog modern untuk melihat gambar/foto tugas siswa dengan zoom dan swipe galeri
class SubmissionImageViewerDialog extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String title;

  const SubmissionImageViewerDialog({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    required this.title,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
    required String title,
  }) {
    if (imageUrls.isEmpty) return Future.value();
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => SubmissionImageViewerDialog(
        imageUrls: imageUrls,
        initialIndex: initialIndex,
        title: title,
      ),
    );
  }

  @override
  State<SubmissionImageViewerDialog> createState() => _SubmissionImageViewerDialogState();
}

class _SubmissionImageViewerDialogState extends State<SubmissionImageViewerDialog> {
  late PageController _pageController;
  late int _currentIndex;
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      _transformationController.value = Matrix4.diagonal3Values(2.5, 2.5, 1.0)
        ..setTranslationRaw(-position.dx * 1.5, -position.dy * 1.5, 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUrl = widget.imageUrls[_currentIndex];
    final isHttp = currentUrl.startsWith('http://') || currentUrl.startsWith('https://');

    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF0A0F1D),
      child: SafeArea(
        child: Column(
          children: [
            // ── TOP HEADER BAR ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF131B2E),
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withAlpha(50),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.emerald.withAlpha(100)),
                    ),
                    child: const Icon(Icons.image_rounded, color: AppColors.emerald, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.imageUrls.length > 1
                              ? 'Foto ${_currentIndex + 1} dari ${widget.imageUrls.length} • Cubit atau ketuk 2x untuk memperbesar'
                              : 'Cubit (pinch) atau ketuk 2x untuk memperbesar',
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.imageUrls.length > 1) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${widget.imageUrls.length}',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (isHttp) ...[
                    IconButton(
                      icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white70, size: 20),
                      tooltip: 'Buka di Browser',
                      onPressed: () => openExternalUrl(currentUrl),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 19),
                      tooltip: 'Salin Tautan Gambar',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: currentUrl));
                        AppSnackBar.showSuccess(context, 'Tautan gambar berhasil disalin!');
                      },
                    ),
                  ],
                ],
              ),
            ),

            // ── IMAGE VIEWER SWIPABLE / ZOOMABLE ──
            Expanded(
              child: GestureDetector(
                onDoubleTapDown: (details) => _doubleTapDetails = details,
                onDoubleTap: _handleDoubleTap,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.imageUrls.length,
                  onPageChanged: (idx) {
                    setState(() {
                      _currentIndex = idx;
                      _transformationController.value = Matrix4.identity();
                    });
                  },
                  itemBuilder: (ctx, index) {
                    final imgUrl = widget.imageUrls[index];
                    return Center(
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 0.5,
                        maxScale: 5.0,
                        clipBehavior: Clip.none,
                        child: _buildImage(imgUrl),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── BOTTOM THUMBNAIL STRIP (If > 1 image) ──
            if (widget.imageUrls.length > 1)
              Container(
                height: 76,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF131B2E),
                  border: Border(top: BorderSide(color: Color(0xFF1E293B))),
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.imageUrls.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(width: 10),
                  itemBuilder: (ctx, idx) {
                    final isSelected = idx == _currentIndex;
                    final thumbUrl = widget.imageUrls[idx];
                    return InkWell(
                      onTap: () {
                        _pageController.animateToPage(
                          idx,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppColors.emerald : Colors.white24,
                            width: isSelected ? 2.5 : 1.0,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildImage(thumbUrl, fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String url, {BoxFit fit = BoxFit.contain}) {
    if (url.startsWith('data:image')) {
      try {
        final commaIdx = url.indexOf(',');
        final base64Str = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (ctx, err, stack) => _buildErrorBox(),
        );
      } catch (_) {
        return _buildErrorBox();
      }
    } else if (url.startsWith('firestore://')) {
      final cached = FirebaseService.getCachedFileBytes(url);
      if (cached != null) {
        return Image.memory(cached, fit: fit, errorBuilder: (ctx, err, stack) => _buildErrorBox());
      }
      return FutureBuilder<Uint8List>(
        future: FirebaseService().resolveFileBytes(url),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.emerald),
              ),
            );
          }
          if (snap.hasError || !snap.hasData) {
            return _buildErrorBox(message: snap.error?.toString().replaceAll('Exception:', '').trim() ?? 'Gagal memuat gambar');
          }
          return Image.memory(snap.data!, fit: fit, errorBuilder: (ctx, err, stack) => _buildErrorBox());
        },
      );
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: fit,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          final total = progress.expectedTotalBytes;
          final loaded = progress.cumulativeBytesLoaded;
          final val = total != null && total > 0 ? loaded / total : null;
          return Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                value: val,
                strokeWidth: 3,
                color: AppColors.emerald,
              ),
            ),
          );
        },
        errorBuilder: (ctx, err, stack) => _buildErrorBox(),
      );
    } else {
      // Local/mock filename
      return _buildErrorBox(message: 'Berkas gambar belum diunggah ke server ("$url")');
    }
  }

  Widget _buildErrorBox({String message = 'Gagal memuat gambar'}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_rounded, color: Colors.redAccent, size: 40),
          const SizedBox(height: 10),
          Text(
            message,
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Widget galeri thumbnail gambar yang bisa disematkan di dialog atau kartu pengumpulan
class SubmissionImageGalleryGrid extends StatelessWidget {
  final List<String> imageUrls;
  final String title;

  const SubmissionImageGalleryGrid({
    super.key,
    required this.imageUrls,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.image_rounded, color: AppColors.emerald, size: 20),
            const SizedBox(width: 8),
            Text(
              'Lampiran Foto Tugas (${imageUrls.length} Foto)',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: const Color(0xFF0F172A),
              ),
            ),
            const Spacer(),
            Text(
              'Ketuk foto untuk perbesar 🔍',
              style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(imageUrls.length, (index) {
            final img = imageUrls[index];
            return InkWell(
              onTap: () {
                SubmissionImageViewerDialog.show(
                  context,
                  imageUrls: imageUrls,
                  initialIndex: index,
                  title: title,
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  color: const Color(0xFFF1F5F9),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildThumbnail(img),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(160),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                    if (imageUrls.length > 1)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(160),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${index + 1}',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildThumbnail(String url) {
    if (url.startsWith('data:image')) {
      try {
        final commaIdx = url.indexOf(',');
        final base64Str = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => _buildErrorThumbnail(),
        );
      } catch (_) {
        return _buildErrorThumbnail();
      }
    } else if (url.startsWith('firestore://')) {
      final cached = FirebaseService.getCachedFileBytes(url);
      if (cached != null) {
        return Image.memory(cached, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => _buildErrorThumbnail());
      }
      return FutureBuilder<Uint8List>(
        future: FirebaseService().resolveFileBytes(url),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald)));
          }
          if (snap.hasError || !snap.hasData) {
            return _buildErrorThumbnail();
          }
          return Image.memory(snap.data!, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => _buildErrorThumbnail());
        },
      );
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald),
            ),
          );
        },
        errorBuilder: (ctx, err, stack) => _buildErrorThumbnail(),
      );
    } else {
      return _buildErrorThumbnail();
    }
  }

  Widget _buildErrorThumbnail() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 28),
      ),
    );
  }
}
