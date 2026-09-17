import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/utils/url_helper.dart';
import '../../../core/widgets/app_loading_overlay.dart';

/// Modal dialog untuk melihat dokumen PDF secara interaktif dan penuh
class SubmissionPdfViewerDialog extends StatefulWidget {
  final String pdfUrl;
  final String title;
  final Uint8List? initialBytes;

  const SubmissionPdfViewerDialog({
    super.key,
    required this.pdfUrl,
    required this.title,
    this.initialBytes,
  });

  static Future<void> show(
    BuildContext context, {
    required String pdfUrl,
    required String title,
    Uint8List? initialBytes,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => SubmissionPdfViewerDialog(
        pdfUrl: pdfUrl,
        title: title,
        initialBytes: initialBytes,
      ),
    );
  }

  @override
  State<SubmissionPdfViewerDialog> createState() => _SubmissionPdfViewerDialogState();
}

class _SubmissionPdfViewerDialogState extends State<SubmissionPdfViewerDialog> {
  PdfControllerPinch? _pdfController;
  bool _isLoading = true;
  String? _errorMessage;
  int _pageCount = 0;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Uint8List? bytes = widget.initialBytes;

      if (bytes == null || bytes.isEmpty) {
        final url = widget.pdfUrl.trim();
        bytes = await FirebaseService().resolveFileBytes(url);
      }

      if (bytes.isEmpty) {
        throw Exception('Dokumen PDF kosong atau tidak terbaca.');
      }

      final document = await PdfDocument.openData(bytes);
      _pageCount = document.pagesCount;

      _pdfController = PdfControllerPinch(
        document: Future.value(document),
        initialPage: 1,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHttp = widget.pdfUrl.startsWith('http://') || widget.pdfUrl.startsWith('https://');

    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          children: [
            // ── TOP HEADER BAR ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(bottom: BorderSide(color: Color(0xFF334155))),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    tooltip: 'Kembali',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withAlpha(100),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withAlpha(120)),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 20),
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
                          _pageCount > 0
                              ? 'Halaman $_currentPage dari $_pageCount'
                              : 'Pratinjau Dokumen PDF Tugas Siswa',
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isHttp) ...[
                    IconButton(
                      icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white70, size: 20),
                      tooltip: 'Buka di Browser / Unduh',
                      onPressed: () => openExternalUrl(widget.pdfUrl),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 19),
                      tooltip: 'Salin Tautan PDF',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.pdfUrl));
                        AppSnackBar.showSuccess(context, 'Tautan PDF berhasil disalin!');
                      },
                    ),
                  ],
                ],
              ),
            ),

            // ── PDF VIEWER BODY ──
            Expanded(
              child: Container(
                color: const Color(0xFF0B1120),
                child: _buildBody(),
              ),
            ),

            // ── BOTTOM CONTROLS BAR ──
            if (!_isLoading && _errorMessage == null && _pdfController != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  border: Border(top: BorderSide(color: Color(0xFF334155))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous Page
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF334155),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _currentPage > 1
                          ? () {
                              _pdfController?.previousPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            }
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      label: const Text('Sebelumnya'),
                    ),

                    // Page counter indicator badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF475569)),
                      ),
                      child: Text(
                        'Hal. $_currentPage / $_pageCount',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Next Page
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF334155),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _currentPage < _pageCount
                          ? () {
                              _pdfController?.nextPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            }
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      label: const Text('Berikutnya'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Menyiapkan Pratinjau Dokumen PDF...',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mohon tunggu sebentar selagi berkas dimuat',
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      final isHttp = widget.pdfUrl.startsWith('http://') || widget.pdfUrl.startsWith('https://');
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.redAccent.withAlpha(120)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                'Tidak Dapat Menampilkan PDF Langsung',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Color(0xFF64748B)),
                    ),
                    onPressed: _loadPdf,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Coba Lagi'),
                  ),
                  if (isHttp)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => openExternalUrl(widget.pdfUrl),
                      icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                      label: const Text('Buka di Browser'),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return PdfViewPinch(
      controller: _pdfController!,
      onPageChanged: (page) {
        if (mounted) {
          setState(() {
            _currentPage = page;
          });
        }
      },
    );
  }
}

/// Widget kartu pratinjau PDF ringkas untuk disematkan di detail submisi atau list
class SubmissionPdfPreviewCard extends StatelessWidget {
  final String pdfUrl;
  final String title;
  final VoidCallback? onOpenFullscreen;

  const SubmissionPdfPreviewCard({
    super.key,
    required this.pdfUrl,
    required this.title,
    this.onOpenFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final isHttp = pdfUrl.startsWith('http://') || pdfUrl.startsWith('https://');
    final isFirestore = pdfUrl.startsWith('firestore://');
    final isDataUri = pdfUrl.startsWith('data:');
    final isUnresolved = !isHttp && !isFirestore && !isDataUri;

    String displayFileName;
    if (isFirestore) {
      final uri = Uri.tryParse(pdfUrl);
      displayFileName = uri?.queryParameters['name'] ?? 'Dokumen PDF Tugas.pdf';
    } else if (isDataUri) {
      displayFileName = 'Dokumen PDF (Tersimpan di Database)';
    } else if (pdfUrl.contains('/')) {
      displayFileName = pdfUrl.split('/').last.split('?').first;
    } else {
      displayFileName = pdfUrl;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isUnresolved ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnresolved ? const Color(0xFFFDE68A) : const Color(0xFFFECACA),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isUnresolved ? Colors.amber.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isUnresolved ? Icons.warning_amber_rounded : Icons.picture_as_pdf_rounded,
                  color: isUnresolved ? Colors.amber.shade800 : Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Berkas Tugas PDF Siswa',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isUnresolved ? Colors.amber.shade900 : Colors.red.shade900,
                          ),
                        ),
                        if (isUnresolved) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Perlu Kumpul Ulang',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF78350F)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayFileName,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isUnresolved ? Colors.amber.shade900 : Colors.red.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Main Action: Fullscreen PDF Previewer
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  if (onOpenFullscreen != null) {
                    onOpenFullscreen!();
                  } else {
                    SubmissionPdfViewerDialog.show(
                      context,
                      pdfUrl: pdfUrl,
                      title: title,
                    );
                  }
                },
                icon: const Icon(Icons.fullscreen_rounded, size: 18),
                label: Text(
                  'Lihat Preview PDF 🔍',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),

              if (isHttp) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade800,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => openExternalUrl(pdfUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: Text('Buka / Unduh', style: GoogleFonts.outfit(fontSize: 12)),
                ),
                IconButton(
                  tooltip: 'Salin Tautan PDF',
                  icon: Icon(Icons.copy_rounded, size: 18, color: Colors.red.shade700),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pdfUrl));
                    AppSnackBar.showSuccess(context, 'Tautan berkas PDF disalin ke clipboard!');
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
