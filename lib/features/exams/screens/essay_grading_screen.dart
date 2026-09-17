import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/exam_model.dart';
import '../../../core/models/question_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/responsive_layout.dart';

class EssayGradingScreen extends StatefulWidget {
  final ExamModel exam;
  final ExamSessionModel session;

  const EssayGradingScreen({
    super.key,
    required this.exam,
    required this.session,
  });

  @override
  State<EssayGradingScreen> createState() => _EssayGradingScreenState();
}

class _EssayGradingScreenState extends State<EssayGradingScreen> {
  final Map<String, double> _selectedScores = {};

  @override
  void initState() {
    super.initState();
    _selectedScores.addAll(widget.session.essayScores);
  }

  void _saveGrades() {
    final fb = context.read<FirebaseService>();
    fb.gradeExamEssays(
      sessionId: widget.session.id,
      essayScores: _selectedScores,
    );

    AppSnackBar.success(
      context,
      'Nilai esai berhasil disimpan & nilai akhir total otomatis dihitung!',
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final essayQuestions = fb.questions
        .where((q) => widget.exam.questionIds.contains(q.id) && q.type == QuestionType.essay)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Penilaian Esai: ${widget.session.studentName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.orange),
            onPressed: _saveGrades,
          ),
        ],
      ),
      body: essayQuestions.isEmpty
          ? const Center(child: Text('Ujian ini tidak memiliki butir soal esai.'))
          : ResponsiveFormWrapper(
              maxWidth: 800,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Siswa: ${widget.session.studentName} (NIS: ${widget.session.studentNis})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Skor Non-Esai: ${widget.session.nonEssayScore?.toStringAsFixed(1) ?? "0"} • Berikan nilai esai skala 1 sampai 5 per butir soal.',
                          style: const TextStyle(fontSize: 13, color: Colors.purple),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: essayQuestions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final q = essayQuestions[index];
                      final studentAnswer = widget.session.answers[q.id] as String? ?? '(Tidak dijawab oleh siswa)';
                      final currentScore = _selectedScores[q.id] ?? 3.0;

                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.borderLight),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Soal Esai Nomor ${index + 1}:',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                              const SizedBox(height: 4),
                              Text(q.content, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 12),
                              const Text('Jawaban Siswa:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: SelectableText(
                                  studentAnswer,
                                  style: const TextStyle(fontSize: 13, height: 1.4),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 1 to 5 score picker buttons
                              Row(
                                children: [
                                  const Text('Nilai Esai: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [1.0, 2.0, 3.0, 4.0, 5.0].map((score) {
                                      final isSelected = currentScore == score;
                                      return ChoiceChip(
                                        label: Text('$score'),
                                        selected: isSelected,
                                        selectedColor: AppColors.orange,
                                        labelStyle: TextStyle(
                                          color: isSelected ? Colors.white : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        onSelected: (sel) {
                                          if (sel) setState(() => _selectedScores[q.id] = score);
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _saveGrades,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Simpan & Hitung Nilai Keseluruhan',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
