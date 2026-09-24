import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/curriculum_model.dart';
import '../../../core/models/question_model.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/pdf_ocr_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/smart_math_text.dart';
import '../../exams/screens/exam_form_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class PdfImporterScreen extends StatefulWidget {
  final String subjectId;
  final String? initialCpId;
  final String? initialTpId;

  const PdfImporterScreen({
    super.key,
    required this.subjectId,
    this.initialCpId,
    this.initialTpId,
  });

  @override
  State<PdfImporterScreen> createState() => _PdfImporterScreenState();
}

class _PdfImporterScreenState extends State<PdfImporterScreen> with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  String? _selectedSubjectId;
  String? _selectedCpId;
  String? _selectedTpId;

  // Selected file info
  String _fileName = 'Bank_Soal_Terpadu_Multibahasa.pdf';
  int _fileSizeBytes = 345000;
  Uint8List? _pdfBytes;
  bool _hasCustomFile = false;

  // Extracted questions & selection
  List<QuestionModel> _parsedQuestions = [];
  final Set<String> _selectedQuestionIds = {};
  String _activeFilter = 'all'; // 'all', 'id', 'en', 'ar', 'math'
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.subjectId.isNotEmpty ? widget.subjectId : null;
    _selectedCpId = widget.initialCpId;
    _selectedTpId = widget.initialTpId;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _fileName = file.name;
          _fileSizeBytes = bytes.length;
          _pdfBytes = bytes;
          _hasCustomFile = true;
        });

        if (mounted) {
          AppSnackBar.info(context, 'Berkas PDF "${file.name}" berhasil dipilih. Klik "Pindai & Ekstrak" untuk memulai OCR.');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Gagal memilih berkas PDF: $e');
      }
    }
  }

  // Scanning progress state
  String _progressStatus = 'Menganalisis berkas PDF...';
  double _progressValue = 0.1;

  Future<void> _processPdf() async {
    setState(() {
      _isProcessing = true;
      _progressStatus = 'Membuka dan membaca berkas PDF...';
      _progressValue = 0.05;
    });

    final targetSubjectId = _selectedSubjectId ?? widget.subjectId;

    try {
      final questions = await PdfOcrService.parsePdfQuestions(
        subjectId: targetSubjectId,
        cpId: _selectedCpId,
        tpId: _selectedTpId,
        fileName: _fileName,
        pdfBytes: _pdfBytes,
        onProgress: (status, progress) {
          if (mounted) {
            setState(() {
              _progressStatus = status;
              _progressValue = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _parsedQuestions = questions;
          _selectedQuestionIds.clear();
          _selectedQuestionIds.addAll(questions.map((q) => q.id));
          _isProcessing = false;
        });

        if (questions.isNotEmpty) {
          AppSnackBar.success(
            context,
            '✨ Berhasil mengekstrak ${questions.length} butir soal dari berkas PDF!',
          );
        } else {
          AppSnackBar.error(
            context,
            'Tidak ada butir soal yang terdeteksi dari berkas ini. Pastikan berkas memiliki teks/soal yang jelas.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        AppSnackBar.error(context, 'Terjadi kesalahan saat memproses OCR: $e');
      }
    }
  }

  List<QuestionModel> get _filteredQuestions {
    List<QuestionModel> list = _parsedQuestions;

    if (_activeFilter == 'ar') {
      list = list.where((q) => PdfOcrService.containsArabic(q.content)).toList();
    } else if (_activeFilter == 'math') {
      list = list.where((q) => q.equationLatex != null && q.equationLatex!.isNotEmpty).toList();
    } else if (_activeFilter == 'en') {
      list = list.where((q) {
        final lower = q.content.toLowerCase();
        return (lower.contains('the') || lower.contains('what') || lower.contains('read') || lower.contains('passage')) &&
            !PdfOcrService.containsArabic(q.content);
      }).toList();
    } else if (_activeFilter == 'id') {
      list = list.where((q) {
        final isAr = PdfOcrService.containsArabic(q.content);
        final isMath = q.equationLatex != null && q.equationLatex!.isNotEmpty;
        final lower = q.content.toLowerCase();
        final isEn = lower.contains('the') && lower.contains('passage');
        return !isAr && !isMath && !isEn;
      }).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final qry = _searchQuery.trim().toLowerCase();
      list = list.where((q) {
        final matchContent = q.content.toLowerCase().contains(qry);
        final matchOptions = q.options.any((o) => o.text.toLowerCase().contains(qry));
        return matchContent || matchOptions;
      }).toList();
    }

    return list;
  }

  void _toggleSelectAll() {
    setState(() {
      final currentFilteredIds = _filteredQuestions.map((q) => q.id).toSet();
      final hasAll = currentFilteredIds.every((id) => _selectedQuestionIds.contains(id));
      if (hasAll) {
        _selectedQuestionIds.removeAll(currentFilteredIds);
      } else {
        _selectedQuestionIds.addAll(currentFilteredIds);
      }
    });
  }

  void _saveToQuestionBank() {
    final selectedQuestions = _parsedQuestions.where((q) => _selectedQuestionIds.contains(q.id)).toList();
    if (selectedQuestions.isEmpty) {
      AppSnackBar.info(context, 'Pilih minimal 1 butir soal untuk disimpan ke Bank Soal.');
      return;
    }

    final fb = context.read<FirebaseService>();
    fb.addQuestionsBulk(selectedQuestions);

    AppSnackBar.success(
      context,
      '🎉 ${selectedQuestions.length} butir soal berhasil disimpan ke Bank Soal!',
    );

    Navigator.pop(context);
  }

  void _createExamDirectly() {
    final selectedQuestions = _parsedQuestions.where((q) => _selectedQuestionIds.contains(q.id)).toList();
    if (selectedQuestions.isEmpty) {
      AppSnackBar.info(context, 'Pilih minimal 1 butir soal untuk membuat Ujian / Quiz.');
      return;
    }

    final fb = context.read<FirebaseService>();
    // Bulk save selected questions into Firebase
    fb.addQuestionsBulk(selectedQuestions);

    final targetSubjectId = _selectedSubjectId ?? widget.subjectId;
    final selectedIds = selectedQuestions.map((q) => q.id).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamFormScreen(
          subjectId: targetSubjectId,
          initialQuestionIds: selectedIds,
        ),
      ),
    );
  }

  void _editQuestionModal(QuestionModel question, int index) {
    final contentCtrl = TextEditingController(text: question.content);
    final eqCtrl = TextEditingController(text: question.equationLatex ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primary.withAlpha(25),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Edit Butir Soal #${index + 1}',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentCtrl,
                  maxLines: 4,
                  textDirection: PdfOcrService.containsArabic(question.content) ? TextDirection.rtl : TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'Konten / Teks Soal',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: eqCtrl,
                  decoration: InputDecoration(
                    labelText: 'Formula LaTeX (Opsional)',
                    hintText: r'f(x) = \frac{a}{b}',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Batal'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          final updated = question.copyWith(
                            content: contentCtrl.text.trim(),
                            equationLatex: eqCtrl.text.trim().isEmpty ? null : eqCtrl.text.trim(),
                          );
                          _parsedQuestions[index] = updated;
                        });
                        Navigator.pop(ctx);
                        AppSnackBar.success(context, 'Soal berhasil diperbarui!');
                      },
                      child: const Text('Simpan Perubahan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showApiKeyDialog() async {
    final currentKey = await AiService.getEffectiveApiKey();
    final isCustomKey = currentKey.startsWith('AIzaSy');
    final keyCtrl = TextEditingController(text: isCustomKey ? currentKey : '');
    bool isTesting = false;
    bool? testResult;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.key_rounded, color: Colors.amber, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pengaturan Google Gemini API Key',
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                isCustomKey ? 'API Key Kustom Aktif' : 'Belum Dikonfigurasi (Kunci Bawaan)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isCustomKey ? AppColors.emerald : Colors.amber.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: keyCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Gemini API Key (AIzaSy...)',
                        hintText: 'Masukkan API Key dari Google AI Studio',
                        prefixIcon: const Icon(Icons.vpn_key_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => launchUrl(
                        Uri.parse('https://aistudio.google.com/app/apikey'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Text(
                        '👉 Klik di sini untuk mendapatkan API Key Gemini Gratis (Google AI Studio)',
                        style: TextStyle(color: Colors.blue, fontSize: 12, decoration: TextDecoration.underline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (testResult != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: testResult! ? const Color(0xFFECFDF5) : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: testResult! ? AppColors.emerald : Colors.red),
                        ),
                        child: Row(
                          children: [
                            Icon(testResult! ? Icons.check_circle : Icons.error_rounded,
                                size: 18, color: testResult! ? AppColors.emerald : Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                testResult!
                                    ? '✅ API Key Valid & Terhubung ke Gemini AI!'
                                    : '❌ API Key tidak valid atau kuota habis. Periksa kembali.',
                                style: TextStyle(
                                  color: testResult! ? const Color(0xFF065F46) : Colors.red.shade900,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: isTesting
                              ? null
                              : () async {
                                  setModalState(() => isTesting = true);
                                  final ok = await AiService.testApiKey(keyCtrl.text.trim());
                                  setModalState(() {
                                    isTesting = false;
                                    testResult = ok;
                                  });
                                },
                          icon: isTesting
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.network_check_rounded, size: 16),
                          label: const Text('Uji Koneksi'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () async {
                            final k = keyCtrl.text.trim();
                            if (k.isNotEmpty) {
                              await AiService.saveApiKey(k);
                              if (mounted) {
                                Navigator.pop(ctx);
                                AppSnackBar.success(context, 'API Key Gemini berhasil disimpan!');
                              }
                            }
                          },
                          child: const Text('Simpan'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final subjects = fb.subjects;
    final currentSubject = subjects.firstWhere(
      (s) => s.id == (_selectedSubjectId ?? widget.subjectId),
      orElse: () => subjects.isNotEmpty ? subjects.first : subjects.first,
    );

    final cps = fb.cps.where((c) => c.subjectId == currentSubject.id).toList();
    final tps = fb.tps.where((t) => t.cpId == _selectedCpId).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Impor Soal Berkas PDF',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Smart AI OCR & Math LaTeX Support',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined, size: 20),
            tooltip: 'Konfigurasi Gemini API Key',
            onPressed: _showApiKeyDialog,
          ),
          if (_parsedQuestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.emerald.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.emerald),
                      const SizedBox(width: 4),
                      Text(
                        '${_selectedQuestionIds.length}/${_parsedQuestions.length} Terpilih',
                        style: const TextStyle(color: AppColors.emerald, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _parsedQuestions.isNotEmpty ? _buildStickyBottomBar() : null,
      body: ResponsiveFormWrapper(
        maxWidth: 900,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero & Multilingual Feature Cards
              _buildHeroHeader(),

              const SizedBox(height: 16),

              // 2. Interactive File Uploader & OCR Setup
              _buildUploadAndConfigSection(cps, tps, subjects),

              const SizedBox(height: 20),

              // 3. OCR Progress Indicator (When active)
              if (_isProcessing) _buildScanningProgressCard(),

              // 4. Extracted Results Section
              if (_parsedQuestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildResultsHeader(),
                const SizedBox(height: 12),
                _buildFilterChips(),
                const SizedBox(height: 12),
                _buildSearchBar(),
                const SizedBox(height: 16),
                _buildQuestionsList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Hero Section highlighting AI capabilities (Bahasa Indonesia, English, Arabic, Math LaTeX)
  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withAlpha(40),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Universal PDF Question OCR',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pindai berkas PDF soal ujian sekali klik, siap digunakan untuk Ujian & Quiz!',
                      style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),

          // Capability Badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeaturePill('🇮🇩 B. Indonesia', 'Literasi & Pilihan Ganda', const Color(0xFF38BDF8)),
              _buildFeaturePill('🇬🇧 English', 'Reading & Grammar', const Color(0xFFA78BFA)),
              _buildFeaturePill('🇸🇦 B. Arab', 'RTL & Harakat UTF-8', const Color(0xFF34D399)),
              _buildFeaturePill('📐 Matematika', 'LaTeX Formula & Sains', const Color(0xFFFBBF24)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill(String title, String desc, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Upload Box and Subject / CP / TP selection
  Widget _buildUploadAndConfigSection(
    List<CurriculumCpModel> cps,
    List<CurriculumTpModel> tps,
    List<SubjectModel> subjects,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. Unggah Berkas PDF',
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),

          // File Dropzone Card
          InkWell(
            onTap: _isProcessing ? null : _pickPdfFile,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _hasCustomFile ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _hasCustomFile ? AppColors.emerald : Colors.blue.shade200,
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _hasCustomFile ? AppColors.emerald.withAlpha(25) : Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _hasCustomFile ? Icons.check_rounded : Icons.picture_as_pdf_rounded,
                      size: 32,
                      color: _hasCustomFile ? AppColors.emerald : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _hasCustomFile ? _fileName : 'Klik untuk Pilih Dokumen PDF',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _hasCustomFile
                        ? '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB • Siap dipindai'
                        : 'Mendukung format PDF soal teks, tabel, bahasa Arab, dan rumus matematika',
                    style: TextStyle(
                      fontSize: 12,
                      color: _hasCustomFile ? AppColors.emerald : Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_hasCustomFile) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _pickPdfFile,
                      icon: const Icon(Icons.change_circle_outlined, size: 16),
                      label: const Text('Ganti Berkas PDF', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            '2. Tautkan ke Kurikulum & Mata Pelajaran',
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),

          // Subject selector (if available)
          if (subjects.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Mata Pelajaran',
                prefixIcon: const Icon(Icons.menu_book_rounded, size: 20, color: AppColors.primary),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
              initialValue: _selectedSubjectId ?? widget.subjectId,
              items: subjects.map<DropdownMenuItem<String>>((s) {
                return DropdownMenuItem(
                  value: s.id,
                  child: Text(s.name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedSubjectId = val;
                  _selectedCpId = null;
                  _selectedTpId = null;
                });
              },
            ),
            const SizedBox(height: 12),
          ],

          // CP & TP selectors
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Capaian (CP)',
                    prefixIcon: const Icon(Icons.flag_rounded, size: 18, color: Colors.blue),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                  initialValue: _selectedCpId,
                  items: cps.map<DropdownMenuItem<String>>((c) {
                    return DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.code} - ${c.title}', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() {
                    _selectedCpId = val;
                    _selectedTpId = null;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Tujuan (TP)',
                    prefixIcon: const Icon(Icons.track_changes_rounded, size: 18, color: Colors.indigo),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                  initialValue: _selectedTpId,
                  items: tps.map<DropdownMenuItem<String>>((t) {
                    final label = t.title.isNotEmpty ? t.title : t.description;
                    return DropdownMenuItem(
                      value: t.id,
                      child: Text('${t.code} - $label', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedTpId = val),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Primary Scan Trigger Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isProcessing ? null : _processPdf,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.document_scanner_rounded, size: 22),
              label: Text(
                _isProcessing ? 'Sedang Memindai & Menganalisis...' : 'Pindai & Ekstrak Soal PDF Sekarang',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Scanning feedback card with live step & page indicators
  Widget _buildScanningProgressCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'AI OCR & Vision Extractor Sedang Berjalan',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progressValue.clamp(0.05, 1.0),
              backgroundColor: Colors.blue.shade100,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _progressStatus,
            style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// Results Header with Accuracy & Select All
  Widget _buildResultsHeader() {
    final currentFiltered = _filteredQuestions;
    final allSelected = currentFiltered.isNotEmpty && currentFiltered.every((q) => _selectedQuestionIds.contains(q.id));

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hasil Ekstraksi Soal',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
              Text(
                '${_parsedQuestions.length} butir soal siap diambil untuk Ujian & Quiz',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: _toggleSelectAll,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: allSelected ? AppColors.primary.withAlpha(20) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: allSelected ? AppColors.primary : Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  allSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  size: 16,
                  color: allSelected ? AppColors.primary : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  allSelected ? 'Batal Semua' : 'Pilih Semua',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: allSelected ? AppColors.primary : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Filter chips (All, Indonesian, English, Arabic, Math)
  Widget _buildFilterChips() {
    final filters = [
      {'id': 'all', 'label': 'Semua (${_parsedQuestions.length})', 'icon': Icons.layers_rounded},
      {'id': 'id', 'label': '🇮🇩 B. Indonesia', 'icon': Icons.translate_rounded},
      {'id': 'en', 'label': '🇬🇧 English', 'icon': Icons.language_rounded},
      {'id': 'ar', 'label': '🇸🇦 العربية (Arab)', 'icon': Icons.menu_book_rounded},
      {'id': 'math', 'label': '📐 Matematika / LaTeX', 'icon': Icons.functions_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _activeFilter == f['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              showCheckmark: false,
              label: Text(f['label'] as String),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
              selectedColor: const Color(0xFF1E293B),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF1E293B) : Colors.grey.shade300,
                ),
              ),
              onSelected: (_) => setState(() => _activeFilter = f['id'] as String),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Live Search Bar for Question Text & Options
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Cari kata kunci teks soal, Arab, atau opsi jawaban...',
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );
  }

  /// List of Extracted Question Cards
  Widget _buildQuestionsList() {
    final questions = _filteredQuestions;

    if (questions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.filter_list_off_rounded, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'Tidak ada soal untuk kategori ini.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: questions.length,
      separatorBuilder: (_, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final q = questions[index];
        final isSelected = _selectedQuestionIds.contains(q.id);
        final isArabic = PdfOcrService.containsArabic(q.content);
        final hasMath = q.equationLatex != null && q.equationLatex!.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade200,
              width: isSelected ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected ? AppColors.primary.withAlpha(12) : Colors.black.withAlpha(5),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Checkbox, Index, Flexible Badges, Actions (No Overflow)
              Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedQuestionIds.add(q.id);
                        } else {
                          _selectedQuestionIds.remove(q.id);
                        }
                      });
                    },
                  ),
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: isSelected ? AppColors.primary : Colors.grey.shade200,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isSelected ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            q.type.label,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)),
                          ),
                        ),
                        if (isArabic)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.emerald.withAlpha(80)),
                            ),
                            child: const Text('🇸🇦 Arab (RTL)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal)),
                          ),
                        if (hasMath)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: const Text('📐 LaTeX Math', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                    tooltip: 'Edit Soal',
                    onPressed: () => _editQuestionModal(q, index),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Question Content (Auto Arabic RTL or standard LTR + Smart Math Symbols)
              Container(
                 width: double.infinity,
                 padding: const EdgeInsets.symmetric(horizontal: 4),
                 child: SmartMathText(
                   text: q.content,
                   textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                   style: GoogleFonts.outfit(
                     fontSize: isArabic ? 16 : 14,
                     height: isArabic ? 1.6 : 1.4,
                     fontWeight: FontWeight.w500,
                     color: const Color(0xFF1E293B),
                   ),
                 ),
               ),

              // Standalone LaTeX Formula Preview Box (only if not already part of the content string)
              if (hasMath &&
                  !(q.content.contains(r'\sqrt') ||
                      q.content.contains(r'\frac') ||
                      q.content.contains(r'\times') ||
                      q.content.contains(q.equationLatex!.replaceAll(r'$', '')))) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SmartMathText(
                        text: q.equationLatex!,
                        style: const TextStyle(fontSize: 16, color: Color(0xFF1E293B)),
                      ),
                    ),
                  ),
                ),
              ],

              // Options with highlighted correct answers (Full Width & No Overflow)
              if (q.options.isNotEmpty) ...[
                const SizedBox(height: 12),
                Column(
                  children: q.options.map((opt) {
                    final isCorrect = _isOptionCorrect(q, opt);
                    final isOptArabic = PdfOcrService.containsArabic(opt.text);

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isCorrect ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCorrect ? AppColors.emerald : Colors.grey.shade300,
                          width: isCorrect ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: isCorrect ? AppColors.emerald : Colors.grey.shade300,
                            ),
                            child: Text(
                              opt.id,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isCorrect ? Colors.white : Colors.grey.shade800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SmartMathText(
                              text: opt.text + (opt.matchingKey != null ? ' ➔ ${opt.matchingKey}' : ''),
                              textDirection: isOptArabic ? TextDirection.rtl : TextDirection.ltr,
                              style: TextStyle(
                                fontSize: isOptArabic ? 15 : 13,
                                height: isOptArabic ? 1.5 : 1.3,
                                fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                                color: isCorrect ? const Color(0xFF065F46) : const Color(0xFF334155),
                              ),
                            ),
                          ),
                          if (isCorrect) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check_circle, size: 18, color: AppColors.emerald),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Missing media alert if any
              if (q.missingImageFlag) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.amber.withAlpha(80)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.amber),
                      SizedBox(width: 6),
                      Text(
                        'Referensi gambar dalam soal belum terlampir',
                        style: TextStyle(color: AppColors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  bool _isOptionCorrect(QuestionModel q, QuestionOption opt) {
    if (q.correctAnswers == null) return false;
    if (q.correctAnswers is String) {
      return q.correctAnswers == opt.id || q.correctAnswers == opt.text;
    }
    if (q.correctAnswers is List) {
      final list = q.correctAnswers as List;
      return list.contains(opt.id) || list.contains(opt.text);
    }
    if (q.correctAnswers is Map) {
      final map = q.correctAnswers as Map;
      return map.containsKey(opt.text);
    }
    return false;
  }

  /// Sticky Bottom Action Bar with 2 Direct Action Paths
  Widget _buildStickyBottomBar() {
    final selectedCount = _selectedQuestionIds.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Save to Bank Soal Button
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.download_done_rounded, size: 20, color: AppColors.primary),
                label: Text(
                  'Simpan ke Bank Soal ($selectedCount)',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: selectedCount == 0 ? null : _saveToQuestionBank,
              ),
            ),
            const SizedBox(width: 12),

            // Direct Create Exam / Quiz Button
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.bolt_rounded, size: 20, color: Colors.white),
                label: Text(
                  'Langsung Buat Ujian ($selectedCount)',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: selectedCount == 0 ? null : _createExamDirectly,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
