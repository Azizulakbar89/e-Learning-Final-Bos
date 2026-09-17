import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/ai_service.dart';

class BabyLanguageDialog extends StatefulWidget {
  final String materialTitle;
  final String materialContent;
  final String? mediaType;
  final String? cachedExplanation;

  const BabyLanguageDialog({
    super.key,
    required this.materialTitle,
    required this.materialContent,
    this.mediaType,
    this.cachedExplanation,
  });

  @override
  State<BabyLanguageDialog> createState() => _BabyLanguageDialogState();
}

class _BabyLanguageDialogState extends State<BabyLanguageDialog> {
  String? _explanation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExplanation();
  }

  Future<void> _loadExplanation() async {
    if (widget.cachedExplanation != null && widget.cachedExplanation!.isNotEmpty) {
      setState(() {
        _explanation = widget.cachedExplanation;
        _isLoading = false;
      });
      return;
    }

    final result = await AiService.explainInBabyLanguage(
      title: widget.materialTitle,
      content: widget.materialContent,
      mediaType: widget.mediaType,
    );

    if (mounted) {
      setState(() {
        _explanation = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 600),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF7ED), Color(0xFFEFF6FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🧸', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode Bahasa Bayi (ELI5)',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                          const Text(
                            'Penjelasan super mudah seperti cerita anak kecil',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Content Body
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: Colors.amber),
                            const SizedBox(height: 16),
                            Text(
                              'AI sedang menyederhanakan materi...',
                              style: GoogleFonts.outfit(color: Colors.black87),
                            ),
                            const Text(
                              'Menyiapkan analogi mainan & dongeng 🎈',
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(10),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: SelectableText(
                            _explanation ?? 'Gagal memuat penjelasan.',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              height: 1.6,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.thumb_up_alt_rounded),
                    label: const Text('Wah Paham Banget Sekarang! 🎉'),
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
