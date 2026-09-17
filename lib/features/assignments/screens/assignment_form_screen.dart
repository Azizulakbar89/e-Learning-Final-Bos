import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/assignment_model.dart';
import '../../../core/models/question_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/responsive_layout.dart';

class AssignmentFormScreen extends StatefulWidget {
  final String materialId;
  final String subjectId;

  const AssignmentFormScreen({
    super.key,
    required this.materialId,
    required this.subjectId,
  });

  @override
  State<AssignmentFormScreen> createState() => _AssignmentFormScreenState();
}

class _AssignmentFormScreenState extends State<AssignmentFormScreen> {
  final _uuid = const Uuid();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _starterCodeCtrl = TextEditingController();

  String _assignmentType = 'individu'; // 'individu' | 'kelompok' | 'pilihan_ganda'
  int _maxGroupMembers = 3;
  DateTime _deadline = DateTime.now().add(const Duration(days: 7));

  // For pilihan_ganda mode
  final Set<String> _selectedQuestionIds = {};

  // Allowed submission types
  final Set<SubmissionType> _selectedTypes = {SubmissionType.code, SubmissionType.link};

  // Code configuration
  final Set<String> _selectedLanguages = {'html', 'css', 'js', 'php', 'arduino'};
  bool _requireSuccessfulCompile = true;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _starterCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAssignment() async {
    if (_titleCtrl.text.trim().isEmpty) {
      AppSnackBar.warning(context, 'Judul tugas wajib diisi!');
      return;
    }
    if (_assignmentType == 'pilihan_ganda' && _selectedQuestionIds.isEmpty) {
      AppSnackBar.warning(context, 'Pilih setidaknya 1 butir soal untuk kuis pilihan ganda!');
      return;
    }
    if (_assignmentType != 'pilihan_ganda' && _selectedTypes.isEmpty) {
      AppSnackBar.warning(context, 'Pilih setidaknya 1 format pengumpulan tugas!');
      return;
    }

    final fb = context.read<FirebaseService>();
    await showLoadingDialog(
      context,
      message: 'Membuat tugas pembelajaran...',
      action: () async {
        final newAssignment = AssignmentModel(
          id: _uuid.v4(),
          materialId: widget.materialId,
          subjectId: widget.subjectId,
          teacherId: fb.currentUser?.id ?? 'teacher_budi',
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          assignmentType: _assignmentType,
          isGroup: _assignmentType == 'kelompok',
          maxGroupMembers: _assignmentType == 'kelompok' ? _maxGroupMembers : 1,
          allowedSubmissionTypes: _assignmentType == 'pilihan_ganda'
              ? [SubmissionType.text]
              : _selectedTypes.toList(),
          codeConfig: _assignmentType != 'pilihan_ganda' && _selectedTypes.contains(SubmissionType.code)
              ? CodeConfig(
                  allowedLanguages: _selectedLanguages.toList(),
                  starterCode: _starterCodeCtrl.text.trim().isNotEmpty
                      ? _starterCodeCtrl.text.trim()
                      : '// Tulis kode program Anda disini',
                  requireSuccessfulCompile: _requireSuccessfulCompile,
                )
              : null,
          questionIds: _selectedQuestionIds.toList(),
          deadline: _deadline,
          createdAt: DateTime.now(),
        );
        await fb.addAssignment(newAssignment);
      },
      successMessage: 'Tugas berhasil dibuat!',
      errorMessage: 'Gagal membuat tugas. Coba lagi.',
      popOnSuccess: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final objectiveQuestions = fb.questions.where((q) => q.type != QuestionType.essay).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Tugas / Kuis Pembelajaran'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.emerald),
            onPressed: _saveAssignment,
          ),
        ],
      ),
      body: ResponsiveFormWrapper(
        maxWidth: 800,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Judul Tugas / Kuis',
                hintText: 'Contoh: Kuis Pemahaman Dasar & Logika',
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Instruksi & Deskripsi',
                hintText: 'Jelaskan instruksi pengerjaan dan kriteria penilaian...',
              ),
            ),
            const SizedBox(height: 20),

            // Tipe Tugas / Kuis
            const Text('Tipe Pembelajaran:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tugas Individu'),
                  selected: _assignmentType == 'individu',
                  selectedColor: AppColors.primary.withAlpha(30),
                  onSelected: (sel) {
                    if (sel) setState(() => _assignmentType = 'individu');
                  },
                ),
                ChoiceChip(
                  label: const Text('Tugas Kelompok'),
                  selected: _assignmentType == 'kelompok',
                  selectedColor: Colors.purple.withAlpha(30),
                  onSelected: (sel) {
                    if (sel) setState(() => _assignmentType = 'kelompok');
                  },
                ),
                ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.quiz_rounded, size: 16, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text('Kuis Pilihan Ganda (Bank Soal)'),
                    ],
                  ),
                  selected: _assignmentType == 'pilihan_ganda',
                  selectedColor: AppColors.primaryLight.withAlpha(40),
                  onSelected: (sel) {
                    if (sel) setState(() => _assignmentType = 'pilihan_ganda');
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // If Mode Kelompok
            if (_assignmentType == 'kelompok') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.groups_rounded, color: Colors.purple),
                    const SizedBox(width: 10),
                    const Text('Kapasitas Maks. per Kelompok: ',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const Spacer(),
                    DropdownButton<int>(
                      value: _maxGroupMembers,
                      items: [2, 3, 4, 5, 6].map((n) {
                        return DropdownMenuItem(value: n, child: Text('$n Orang'));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _maxGroupMembers = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // If Mode Kuis Pilihan Ganda: Pick from Question Bank
            if (_assignmentType == 'pilihan_ganda') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pilih Butir Soal dari Bank Soal (${_selectedQuestionIds.length} Dipilih):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  if (objectiveQuestions.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedQuestionIds.length == objectiveQuestions.length) {
                            _selectedQuestionIds.clear();
                          } else {
                            _selectedQuestionIds.addAll(objectiveQuestions.map((q) => q.id));
                          }
                        });
                      },
                      child: Text(
                        _selectedQuestionIds.length == objectiveQuestions.length ? 'Batal Semua' : 'Pilih Semua',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (objectiveQuestions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('Belum ada soal objektif di bank soal. Buat soal di menu Ujian terlebih dahulu.'),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: objectiveQuestions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final q = objectiveQuestions[index];
                    final isChecked = _selectedQuestionIds.contains(q.id);

                    return Container(
                      decoration: BoxDecoration(
                        color: isChecked ? AppColors.primary.withAlpha(12) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isChecked ? AppColors.primary : AppColors.borderLight,
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isChecked,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedQuestionIds.add(q.id);
                            } else {
                              _selectedQuestionIds.remove(q.id);
                            }
                          });
                        },
                        title: Text(
                          q.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '#${index + 1} • ${q.type.label} • ${q.options.length} Pilihan',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20),
            ] else ...[

            // Allowed Submission Types (Multi-select)
            const Text('Format Pengumpulan yang Diizinkan:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SubmissionType.values.map((type) {
                final isSelected = _selectedTypes.contains(type);
                return FilterChip(
                  label: Text(type.label),
                  selected: isSelected,
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        _selectedTypes.add(type);
                      } else {
                        if (_selectedTypes.length > 1) {
                          _selectedTypes.remove(type);
                        }
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // If "Koding" is selected: Coding configuration section
            if (_selectedTypes.contains(SubmissionType.code)) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.terminal_rounded, color: AppColors.emerald),
                        SizedBox(width: 8),
                        Text(
                          'Konfigurasi Compiler Koding In-App',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Pilih Bahasa Pemrograman yang Diizinkan:',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        {'id': 'html', 'name': 'HTML'},
                        {'id': 'css', 'name': 'CSS'},
                        {'id': 'js', 'name': 'JavaScript'},
                        {'id': 'php', 'name': 'PHP'},
                        {'id': 'arduino', 'name': 'Arduino IDE (C/C++)'},
                      ].map((lang) {
                        final isSel = _selectedLanguages.contains(lang['id']);
                        return FilterChip(
                          label: Text(lang['name']!),
                          selected: isSel,
                          selectedColor: AppColors.emerald,
                          onSelected: (sel) {
                            setState(() {
                              if (sel) {
                                _selectedLanguages.add(lang['id']!);
                              } else {
                                if (_selectedLanguages.length > 1) {
                                  _selectedLanguages.remove(lang['id']!);
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _requireSuccessfulCompile,
                          activeColor: AppColors.emerald,
                          onChanged: (val) => setState(() => _requireSuccessfulCompile = val ?? true),
                        ),
                        const Expanded(
                          child: Text(
                            'Wajib Lolos Uji Coba / Compile sebelum siswa dapat mengumpulkan kode',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Template / Starter Code Awal:',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _starterCodeCtrl,
                      maxLines: 5,
                      style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black38,
                        hintText: '// Starter code yang akan langsung muncul di editor siswa...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],

            // Deadline selector
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.borderLight),
              ),
              leading: const Icon(Icons.calendar_month, color: AppColors.primary),
              title: const Text('Batas Waktu Pengumpulan (Deadline)'),
              subtitle: Text(
                '${_deadline.day}/${_deadline.month}/${_deadline.year} pukul ${_deadline.hour}:${_deadline.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              trailing: ElevatedButton(
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _deadline,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (pickedDate != null) {
                    if (!context.mounted) return;
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_deadline),
                    );
                    if (pickedTime != null && mounted) {
                      setState(() {
                        _deadline = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
                child: const Text('Ubah'),
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _saveAssignment,
                icon: const Icon(Icons.assignment_turned_in_rounded),
                label: const Text('Buat & Bagikan Tugas ke Kelas', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
