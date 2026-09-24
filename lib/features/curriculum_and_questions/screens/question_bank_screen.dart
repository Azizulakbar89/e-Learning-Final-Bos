import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/question_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/curved_header_card.dart';
import '../../../core/widgets/smart_math_text.dart';
import 'missing_images_validator_screen.dart';
import 'pdf_importer_screen.dart';
import 'question_editor_screen.dart';

class QuestionBankScreen extends StatefulWidget {
  final String initialSubjectId;

  const QuestionBankScreen({super.key, this.initialSubjectId = 'subj_web'});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  late String _selectedSubjectId;
  String? _selectedCpFilter;
  String? _selectedTpFilter;
  bool _onlyMyQuestions = true; // Default: Only show questions uploaded by current teacher
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.initialSubjectId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSmartPoolDialog() {
    final fb = context.read<FirebaseService>();
    final allOtherQuestions = fb.questions.where((q) => q.subjectId != _selectedSubjectId).toList();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Smart Pool: Ambil Soal dari CP Lain'),
        content: SizedBox(
          width: 500,
          child: allOtherQuestions.isEmpty
              ? const Text('Belum ada soal dari mata pelajaran lain.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: allOtherQuestions.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final q = allOtherQuestions[index];
                    return ListTile(
                      title: Text(q.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${q.type.label} • Dari Mapel: ${q.subjectId}'),
                      trailing: FilledButton.tonal(
                        child: const Text('Tarik Soal'),
                        onPressed: () {
                          // Copy question to current subject
                          final copied = q.copyWith(
                            id: 'q_pooled_${DateTime.now().millisecondsSinceEpoch}',
                            subjectId: _selectedSubjectId,
                            teacherId: fb.currentUser?.id,
                            creatorName: fb.currentUser?.fullName,
                          );
                          fb.addQuestion(copied);
                          Navigator.pop(context);
                          AppSnackBar.success(
                            context,
                            'Soal berhasil ditarik ke bank soal mata pelajaran aktif!',
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteQuestion(QuestionModel question) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Hapus Soal?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apakah Anda yakin ingin menghapus butir soal ini dari Bank Soal?',
              style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                question.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus Soal'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final fb = context.read<FirebaseService>();
      await fb.deleteQuestion(question.id);
      if (mounted) {
        AppSnackBar.success(context, 'Butir soal berhasil dihapus dari Bank Soal!');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final currentUserId = fb.currentUser?.id;
    final subjects = fb.currentUser?.isGuru == true
        ? fb.getTeacherSubjects(fb.currentUser)
        : fb.subjects;

    // Safety: ensure selected subject exists in subjects list, otherwise fallback to first or default
    final validSubjectIds = subjects.map((s) => s.id).toSet();
    if (!validSubjectIds.contains(_selectedSubjectId)) {
      if (subjects.isNotEmpty) {
        _selectedSubjectId = subjects.first.id;
      } else {
        _selectedSubjectId = '';
      }
    }

    final cps = fb.cps.where((c) => c.subjectId == _selectedSubjectId).toList();
    final tps = fb.tps.where((t) => t.subjectId == _selectedSubjectId).toList();

    // Safety: ensure selected CP and TP filters belong to current subject
    if (_selectedCpFilter != null && !cps.any((c) => c.id == _selectedCpFilter)) {
      _selectedCpFilter = null;
    }

    final availableTps = _selectedCpFilter == null
        ? tps
        : tps.where((t) => t.cpId == _selectedCpFilter).toList();

    if (_selectedTpFilter != null && !availableTps.any((t) => t.id == _selectedTpFilter)) {
      _selectedTpFilter = null;
    }

    // Filter questions by subject, CP, TP
    var rawQuestions = fb.getQuestionsByFilter(
      subjectId: _selectedSubjectId,
      cpId: _selectedCpFilter,
      tpId: _selectedTpFilter,
    );

    // Apply Teacher Filter: "Soal Saya" vs "Semua Guru"
    if (_onlyMyQuestions && currentUserId != null && currentUserId.isNotEmpty) {
      rawQuestions = rawQuestions.where((q) {
        // Match if teacherId equals current user OR if teacherId is unset and creator matches
        return q.teacherId == currentUserId || q.teacherId == null || q.teacherId!.isEmpty;
      }).toList();
    }

    // Apply Search Filter
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      rawQuestions = rawQuestions.where((q) {
        return q.content.toLowerCase().contains(query) ||
            q.options.any((opt) => opt.text.toLowerCase().contains(query));
      }).toList();
    }

    final questions = rawQuestions;
    final missingCount = _selectedSubjectId.isEmpty ? 0 : fb.getMissingImageQuestions(_selectedSubjectId).length;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      floatingActionButton: subjects.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFFF97316),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuestionEditorScreen(subjectId: _selectedSubjectId),
                  ),
                );
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Buat Soal Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CurvedHeaderCard(
              title: 'Bank Soal Terpadu',
              actions: subjects.isEmpty
                  ? []
                  : [
                      IconButton(
                        tooltip: 'Tarik / Pool Soal dari CP Lain',
                        icon: const Icon(Icons.hub_outlined, color: Color(0xFFFB923C), size: 20),
                        onPressed: _showSmartPoolDialog,
                      ),
                      IconButton(
                        tooltip: 'Impor Soal PDF (OCR)',
                        icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white70, size: 20),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PdfImporterScreen(subjectId: _selectedSubjectId),
                            ),
                          );
                        },
                      ),
                    ],
            ),
            // Warning if no subjects
            if (subjects.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Akun guru Anda belum diplot ke mata pelajaran manapun oleh Admin. Bank soal hanya dapat diakses untuk mapel yang ditugaskan.',
                        style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                color: Colors.white,
                child: Column(
                  children: [
                    // Teacher Scope Filter Chips & Mapel Dropdown
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment<bool>(
                                value: true,
                                label: Text('Soal Saya', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                icon: Icon(Icons.person, size: 16),
                              ),
                              ButtonSegment<bool>(
                                value: false,
                                label: Text('Semua Guru', style: TextStyle(fontSize: 12)),
                                icon: Icon(Icons.groups, size: 16),
                              ),
                            ],
                            selected: {_onlyMyQuestions},
                            onSelectionChanged: (Set<bool> newSelection) {
                              setState(() {
                                _onlyMyQuestions = newSelection.first;
                              });
                            },
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Mapel Dropdown
                    Row(
                      children: [
                        const Text('Mapel: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedSubjectId.isNotEmpty ? _selectedSubjectId : null,
                                items: subjects
                                    .map((s) => DropdownMenuItem(
                                          value: s.id,
                                          child: Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedSubjectId = val;
                                      _selectedCpFilter = null;
                                      _selectedTpFilter = null;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // CP & TP Filters
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                isExpanded: true,
                                hint: const Text('Semua CP', style: TextStyle(fontSize: 12)),
                                value: _selectedCpFilter,
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('Semua CP', style: TextStyle(fontSize: 12))),
                                  ...cps.map((c) => DropdownMenuItem(value: c.id, child: Text(c.code, style: const TextStyle(fontSize: 12)))),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedCpFilter = val;
                                    if (_selectedTpFilter != null) {
                                      final validForNewCp = val == null ||
                                          tps.any((t) => t.id == _selectedTpFilter && t.cpId == val);
                                      if (!validForNewCp) {
                                        _selectedTpFilter = null;
                                      }
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                isExpanded: true,
                                hint: const Text('Semua TP', style: TextStyle(fontSize: 12)),
                                value: _selectedTpFilter,
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('Semua TP', style: TextStyle(fontSize: 12))),
                                  ...availableTps.map((t) => DropdownMenuItem(value: t.id, child: Text(t.code, style: const TextStyle(fontSize: 12)))),
                                ],
                                onChanged: (val) => setState(() => _selectedTpFilter = val),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Live Search Bar
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Cari kata kunci butir soal...',
                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Missing Images Warning Banner if any
            if (missingCount > 0)
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MissingImagesValidatorScreen(subjectId: _selectedSubjectId),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppColors.amber.withAlpha(30),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Peringatan: Ditemukan $missingCount butir soal yang referensi gambarnya belum terlampir. Klik untuk memvalidasi.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18, color: AppColors.amber),
                    ],
                  ),
                ),
              ),

            // Questions List with Edit & Delete controls
            Expanded(
              child: questions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.quiz_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _onlyMyQuestions
                                ? 'Belum ada soal yang diunggah oleh Anda pada mapel ini.'
                                : 'Belum ada butir soal dengan filter ini.',
                            style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PdfImporterScreen(subjectId: _selectedSubjectId),
                                ),
                              );
                            },
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text('Impor dari PDF'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: questions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final q = questions[index];
                        final isOwner = q.teacherId == null || q.teacherId == currentUserId;

                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: q.missingImageFlag ? AppColors.amber : AppColors.borderLight,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header: Number Badge, Missing Image Tag, & EDIT / DELETE Actions
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFFEDD5)),
                                      ),
                                      child: Text(
                                        'No. ${index + 1} • ${q.type.label}',
                                        style: const TextStyle(
                                          color: Color(0xFFEA580C),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (q.missingImageFlag) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '⚠️ Gambar Kosong',
                                          style: TextStyle(color: Colors.brown, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                    if (q.creatorName != null && q.creatorName!.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isOwner ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isOwner ? const Color(0xFFBFDBFE) : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Text(
                                          isOwner ? 'Saya' : q.creatorName!,
                                          style: TextStyle(
                                            color: isOwner ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const Spacer(),

                                    // Action Buttons: Edit & Delete
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 19, color: AppColors.primary),
                                      tooltip: 'Edit Soal',
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => QuestionEditorScreen(
                                              subjectId: _selectedSubjectId,
                                              existingQuestion: q,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFEF4444)),
                                      tooltip: 'Hapus Soal',
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      onPressed: () => _confirmDeleteQuestion(q),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Question Content with Smart Math LaTeX Rendering
                                SmartMathText(
                                  text: q.content,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),

                                // Math formula preview (if not already part of content text)
                                if (q.equationLatex != null &&
                                    !q.content.contains(q.equationLatex!.replaceAll(r'$', ''))) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue.shade100),
                                    ),
                                    child: SmartMathText(
                                      text: q.equationLatex!,
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                ],

                                // Options List
                                if (q.options.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: q.options.map((opt) {
                                      final isCorrect = q.correctAnswers == opt.id ||
                                          (q.correctAnswers is List && (q.correctAnswers as List).contains(opt.id));

                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isCorrect ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isCorrect ? AppColors.emerald : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${opt.id}. ',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isCorrect ? const Color(0xFF065F46) : const Color(0xFF334155),
                                              ),
                                            ),
                                            SmartMathText(
                                              text: opt.text,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isCorrect ? const Color(0xFF065F46) : const Color(0xFF334155),
                                              ),
                                            ),
                                            if (isCorrect) ...[
                                              const SizedBox(width: 4),
                                              const Icon(Icons.check_circle, size: 14, color: AppColors.emerald),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
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
}
