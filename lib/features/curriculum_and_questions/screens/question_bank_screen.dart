import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/question_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/curved_header_card.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.initialSubjectId;
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

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
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
    if (_selectedTpFilter != null && !tps.any((t) => t.id == _selectedTpFilter)) {
      _selectedTpFilter = null;
    }

    final questions = fb.getQuestionsByFilter(
      subjectId: _selectedSubjectId,
      cpId: _selectedCpFilter,
      tpId: _selectedTpFilter,
    );

    final missingCount = _selectedSubjectId.isEmpty ? 0 : fb.getMissingImageQuestions(_selectedSubjectId).length;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      floatingActionButton: subjects.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuestionEditorScreen(subjectId: _selectedSubjectId),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Buat Soal Baru'),
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
          // Filter Header
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
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('Mapel: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedSubjectId.isNotEmpty ? _selectedSubjectId : null,
                          items: subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
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
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        hint: const Text('Filter CP (Semua)'),
                        value: _selectedCpFilter,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Semua CP')),
                          ...cps.map((c) => DropdownMenuItem(value: c.id, child: Text(c.code))),
                        ],
                        onChanged: (val) => setState(() => _selectedCpFilter = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        hint: const Text('Filter TP (Semua)'),
                        value: _selectedTpFilter,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Semua TP')),
                          ...tps.map((t) => DropdownMenuItem(value: t.id, child: Text(t.code))),
                        ],
                        onChanged: (val) => setState(() => _selectedTpFilter = val),
                      ),
                    ),
                  ],
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

          // Questions List
          Expanded(
            child: questions.isEmpty
                ? const Center(child: Text('Belum ada soal dengan filter ini.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: questions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final q = questions[index];
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
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withAlpha(20),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'No. ${index + 1} • ${q.type.label}',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (q.missingImageFlag)
                                    const Text(
                                      '⚠️ Gambar Kosong',
                                      style: TextStyle(color: AppColors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(q.content, style: const TextStyle(fontSize: 14, height: 1.4)),

                              // Math formula preview
                              if (q.equationLatex != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Math.tex(
                                    q.equationLatex!,
                                    textStyle: const TextStyle(fontSize: 15),
                                  ),
                                ),
                              ],

                              if (q.options.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: q.options.map((opt) {
                                    return Chip(
                                      label: Text('${opt.id}. ${opt.text}'),
                                      backgroundColor: Colors.grey.shade100,
                                      labelStyle: const TextStyle(fontSize: 11),
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
