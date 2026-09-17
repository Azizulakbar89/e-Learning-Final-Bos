import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/exam_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../screens/exam_form_screen.dart';

class DuplicateExamDialog extends StatefulWidget {
  final ExamModel exam;

  const DuplicateExamDialog({super.key, required this.exam});

  static Future<void> show(BuildContext context, ExamModel exam) {
    return showDialog(
      context: context,
      builder: (_) => DuplicateExamDialog(exam: exam),
    );
  }

  @override
  State<DuplicateExamDialog> createState() => _DuplicateExamDialogState();
}

class _DuplicateExamDialogState extends State<DuplicateExamDialog> {
  late final TextEditingController _titleCtrl;
  final Set<String> _selectedClasses = {};
  bool _openEditorAfterDuplicate = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: '${widget.exam.title} (Salinan)');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _duplicate() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      AppSnackBar.error(
        context,
        'Judul ujian baru wajib diisi!',
      );
      return;
    }

    if (_selectedClasses.isEmpty) {
      AppSnackBar.error(
        context,
        'Pilih setidaknya 1 kelas tujuan duplikasi!',
      );
      return;
    }

    final fb = context.read<FirebaseService>();
    final newExamId = const Uuid().v4();

    final duplicatedExam = widget.exam.copyWith(
      id: newExamId,
      title: title,
      classIds: _selectedClasses.toList(),
      createdAt: DateTime.now(),
    );

    await fb.addExam(duplicatedExam);

    if (mounted) {
      Navigator.pop(context);

      AppSnackBar.success(
        context,
        'Ujian "$title" berhasil diduplikat untuk kelas: ${_selectedClasses.join(", ")}',
      );

      if (_openEditorAfterDuplicate) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExamFormScreen(
              subjectId: duplicatedExam.subjectId,
              existingExam: duplicatedExam,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final availableClasses = fb.getTeacherClasses(fb.currentUser);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Duplikat Kuis / Ujian',
                          style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Salin seluruh soal & pengaturan ke kelas lain',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Current Quiz Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Asal: "${widget.exam.title}" (${widget.exam.questionIds.length} Soal, Kelas: ${widget.exam.classIds.join(", ")})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Title input
              Text(
                'Judul Ujian Hasil Duplikat',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  hintText: 'Contoh: Kuis Informatika Bab 1 - Kelas 8B',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Class Target Selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pilih Kelas Tujuan (${_selectedClasses.length} Dipilih)',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  if (availableClasses.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedClasses.length == availableClasses.length) {
                            _selectedClasses.clear();
                          } else {
                            _selectedClasses.addAll(availableClasses);
                          }
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        _selectedClasses.length == availableClasses.length ? 'Batal Semua' : 'Pilih Semua',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableClasses.map((cls) {
                  final isSelected = _selectedClasses.contains(cls);
                  final isCurrentClass = widget.exam.classIds.contains(cls);

                  return FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cls),
                        if (isCurrentClass) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Asal', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withAlpha(35),
                    checkmarkColor: AppColors.primary,
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : Colors.grey.shade300,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onSelected: (sel) {
                      setState(() {
                        if (sel) {
                          _selectedClasses.add(cls);
                        } else {
                          _selectedClasses.remove(cls);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Open editor checkbox
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _openEditorAfterDuplicate,
                onChanged: (val) => setState(() => _openEditorAfterDuplicate = val ?? false),
                title: const Text(
                  'Buka editor untuk menyesuaikan soal/jadwal setelah duplikat',
                  style: TextStyle(fontSize: 12.5),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
              const SizedBox(height: 18),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _duplicate,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Duplikat Sekarang'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
