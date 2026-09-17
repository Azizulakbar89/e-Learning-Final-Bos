import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/exam_model.dart';
import '../../../core/models/question_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/curved_header_card.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../curriculum_and_questions/screens/pdf_importer_screen.dart';
import '../../curriculum_and_questions/screens/question_editor_screen.dart';
import '../../teacher_tools/screens/school_class_manager_screen.dart';

class ExamFormScreen extends StatefulWidget {
  final String subjectId;
  final ExamModel? existingExam;

  const ExamFormScreen({
    super.key,
    required this.subjectId,
    this.existingExam,
  });

  @override
  State<ExamFormScreen> createState() => _ExamFormScreenState();
}

class _ExamFormScreenState extends State<ExamFormScreen> {
  final _uuid = const Uuid();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _durationMinutes = 60;
  bool _antiCheatEnabled = true;

  // Jadwal Ujian Mulai & Akhir (Tanggal, Bulan, Tahun, Jam:Menit)
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);

  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 59);

  final Set<String> _selectedClasses = {};
  final Set<String> _selectedQuestionIds = {};
  bool _initialized = false;

  // Filter Bank Soal berdasarkan CP & TP
  String? _selectedCpId;
  String? _selectedTpId;
  int _bankSoalTab = 0; // 0: Pilih Bank Soal per CP & TP, 1: Soal Terpilih

  @override
  void initState() {
    super.initState();
    if (widget.existingExam != null) {
      final exam = widget.existingExam!;
      _titleCtrl.text = exam.title;
      _descCtrl.text = exam.description;
      _durationMinutes = exam.durationMinutes;
      _antiCheatEnabled = exam.antiCheatEnabled;
      _selectedClasses.addAll(exam.classIds);
      _selectedQuestionIds.addAll(exam.questionIds);
      if (exam.startTime != null) {
        _startDate = exam.startTime!;
        _startTime = TimeOfDay.fromDateTime(exam.startTime!);
      }
      if (exam.endTime != null) {
        _endDate = exam.endTime!;
        _endTime = TimeOfDay.fromDateTime(exam.endTime!);
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  DateTime get _computedStartDateTime => DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );

  DateTime get _computedEndDateTime => DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        _endTime.hour,
        _endTime.minute,
      );

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'PILIH TANGGAL MULAI UJIAN',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'PILIH JAM MULAI UJIAN',
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'PILIH TANGGAL SELESAI / AKHIR UJIAN',
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      helpText: 'PILIH JAM SELESAI / BATAS AKHIR',
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  void _openManualQuestionEditor() async {
    final fb = context.read<FirebaseService>();
    final initialCount = fb.questions.length;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionEditorScreen(
          subjectId: widget.subjectId,
          initialCpId: _selectedCpId,
          initialTpId: _selectedTpId != 'all' ? _selectedTpId : null,
        ),
      ),
    );

    if (mounted) {
      final updatedQuestions = context.read<FirebaseService>().questions;
      if (updatedQuestions.length > initialCount) {
        final newlyAdded = updatedQuestions.sublist(0, updatedQuestions.length - initialCount);
        setState(() {
          for (final q in newlyAdded) {
            _selectedQuestionIds.add(q.id);
          }
        });
      }
    }
  }

  void _openPdfOcrImporter() async {
    final fb = context.read<FirebaseService>();
    final initialCount = fb.questions.length;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfImporterScreen(
          subjectId: widget.subjectId,
          initialCpId: _selectedCpId,
          initialTpId: _selectedTpId != 'all' ? _selectedTpId : null,
        ),
      ),
    );

    if (mounted) {
      final updatedQuestions = context.read<FirebaseService>().questions;
      if (updatedQuestions.length > initialCount) {
        final newlyAdded = updatedQuestions.sublist(0, updatedQuestions.length - initialCount);
        setState(() {
          for (final q in newlyAdded) {
            _selectedQuestionIds.add(q.id);
          }
        });
      }
    }
  }

  Future<void> _saveExam() async {
    if (_titleCtrl.text.trim().isEmpty) {
      AppSnackBar.warning(context, 'Judul ujian wajib diisi!');
      return;
    }

    if (_selectedClasses.isEmpty) {
      AppSnackBar.warning(context, 'Pilih setidaknya 1 kelas target peserta ujian!');
      return;
    }

    if (_selectedQuestionIds.isEmpty) {
      AppSnackBar.warning(context, 'Pilih setidaknya 1 butir soal untuk ujian ini!');
      return;
    }

    final startDateTime = _computedStartDateTime;
    final endDateTime = _computedEndDateTime;

    if (endDateTime.isBefore(startDateTime)) {
      AppSnackBar.warning(context, 'Waktu akhir ujian tidak boleh mendahului waktu mulai ujian!');
      return;
    }

    final fb = context.read<FirebaseService>();
    final isEdit = widget.existingExam != null;
    final examId = isEdit ? widget.existingExam!.id : _uuid.v4();

    final exam = ExamModel(
      id: examId,
      subjectId: widget.subjectId,
      teacherId: isEdit ? widget.existingExam!.teacherId : (fb.currentUser?.id ?? 'teacher_budi'),
      classIds: _selectedClasses.toList(),
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      durationMinutes: _durationMinutes,
      antiCheatEnabled: _antiCheatEnabled,
      questionIds: _selectedQuestionIds.toList(),
      createdAt: isEdit ? widget.existingExam!.createdAt : DateTime.now(),
      startTime: startDateTime,
      endTime: endDateTime,
    );

    final success = await showLoadingDialog(
      context,
      message: isEdit ? 'Menyimpan perubahan ujian...' : 'Menerbitkan jadwal ujian baru...',
      action: () async {
        if (isEdit) {
          await fb.updateExam(exam);
        } else {
          await fb.addExam(exam);
        }
      },
      successMessage: isEdit
          ? 'Ujian / Kuis berhasil diperbarui!'
          : 'Ujian / Kuis berhasil dibuat & dijadwalkan secara real-time!',
      errorMessage: 'Gagal menyimpan ujian. Silakan periksa data Anda.',
    );

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final availableClasses = fb.getTeacherClasses(fb.currentUser);
    final allSubjectQuestions = fb.questions.where((q) => q.subjectId == widget.subjectId).toList();

    // CP and TP lists for this subject
    final availableCps = fb.cps.where((c) => c.subjectId == widget.subjectId).toList();
    final availableTps = fb.tps.where((t) {
      if (_selectedCpId != null && _selectedCpId != 'all') {
        return t.cpId == _selectedCpId;
      }
      return t.subjectId == widget.subjectId;
    }).toList();

    // Auto-select first class if not set
    if (!_initialized && availableClasses.isNotEmpty) {
      _selectedClasses.add(availableClasses.first);
      _initialized = true;
    }

    // Filter questions: ONLY loaded when CP and TP are chosen!
    final bool cpTpChosen = _selectedCpId != null && _selectedTpId != null;
    final filteredQuestions = cpTpChosen
        ? allSubjectQuestions.where((q) {
            if (_selectedCpId != null && _selectedCpId != 'all') {
              if (q.cpId != _selectedCpId) return false;
            }
            if (_selectedTpId != null && _selectedTpId != 'all') {
              if (q.tpId != _selectedTpId) return false;
            }
            return true;
          }).toList()
        : <QuestionModel>[];

    final selectedQuestionsList = allSubjectQuestions
        .where((q) => _selectedQuestionIds.contains(q.id))
        .toList();

    final isEdit = widget.existingExam != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CurvedHeaderCard(
              title: isEdit ? 'Edit Jadwal Ujian / Kuis' : 'Buat Jadwal Ujian / Kuis',
              subtitle: 'Pengaturan Waktu, Soal & Integritas Siswa',
              actions: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(isEdit ? Icons.check_circle_rounded : Icons.check, size: 16),
                  label: Text(
                    isEdit ? 'Simpan' : 'Terbitkan',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: _saveExam,
                ),
              ],
            ),
            Expanded(
              child: ResponsiveFormWrapper(
                maxWidth: 960,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // Section 1: Informasi Dasar
            _buildSectionHeader('1. Informasi Ujian / Kuis', Icons.info_outline_rounded),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _titleCtrl,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16),
                    decoration: const InputDecoration(
                      labelText: 'Judul Ujian / Kuis',
                      hintText: 'Contoh: Penilaian Harian Modul 1 / UTS Pemrograman',
                      prefixIcon: Icon(Icons.assignment_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Petunjuk & Tata Tertib Pengerjaan',
                      hintText: 'Ujian ini menggunakan sistem pengawasan anti-kecurangan...',
                      prefixIcon: Icon(Icons.rule_folder_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 2: Jadwal Pelaksanaan Ujian (Tanggal & Jam)
            _buildSectionHeader('2. Jadwal Pelaksanaan Ujian', Icons.schedule_rounded),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  // Waktu Mulai Ujian
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Waktu Mulai Dibuka',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '${AppDateFormatter.formatDate(_startDate)} • Pukul ${_startTime.format(context)} WIB',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickStartDate,
                        icon: const Icon(Icons.calendar_month_rounded, size: 16),
                        label: const Text('Tanggal'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _pickStartTime,
                        icon: const Icon(Icons.access_time_rounded, size: 16),
                        label: const Text('Jam'),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Waktu Akhir / Batas Tutup Ujian
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.rose.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.stop_circle_rounded, color: AppColors.rose, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Waktu Berakhir / Ditutup',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '${AppDateFormatter.formatDate(_endDate)} • Pukul ${_endTime.format(context)} WIB',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickEndDate,
                        icon: const Icon(Icons.calendar_month_rounded, size: 16),
                        label: const Text('Tanggal'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _pickEndTime,
                        icon: const Icon(Icons.access_time_rounded, size: 16),
                        label: const Text('Jam'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 3: Durasi & Sistem Anti-Cheat
            _buildSectionHeader('3. Durasi & Pengawasan Ujian', Icons.timer_outlined),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hourglass_top_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text('Durasi Pengerjaan Siswa:', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      DropdownButton<int>(
                        value: _durationMinutes,
                        borderRadius: BorderRadius.circular(12),
                        items: [15, 30, 45, 60, 90, 120]
                            .map((m) => DropdownMenuItem(value: m, child: Text('$m Menit')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _durationMinutes = val);
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        const Icon(Icons.security_rounded, color: AppColors.rose, size: 20),
                        const SizedBox(width: 10),
                        Text('Anti-Cheat Zero Tolerance', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    subtitle: const Text(
                      'Kunci fullscreen, deteksi blur tab, auto-submit jika melanggar toleransi.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: _antiCheatEnabled,
                    activeThumbColor: AppColors.rose,
                    onChanged: (val) => setState(() => _antiCheatEnabled = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 4: Target Kelas Peserta
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildSectionHeader(
                    '4. Target Kelas (${_selectedClasses.length} Kelas Dipilih)',
                    Icons.groups_rounded,
                  ),
                ),
                if (availableClasses.isNotEmpty) ...[
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (_selectedClasses.length == availableClasses.length) {
                          _selectedClasses.clear();
                        } else {
                          _selectedClasses.addAll(availableClasses);
                        }
                      });
                    },
                    icon: Icon(
                      _selectedClasses.length == availableClasses.length
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _selectedClasses.length == availableClasses.length
                          ? 'Batal Semua'
                          : 'Pilih Semua (${availableClasses.length})',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Ujian / kuis ini dapat ditugaskan ke beberapa kelas sekaligus. Siswa di semua kelas terpilih dapat langsung mengerjakan.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            if (availableClasses.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF59E0B).withAlpha(100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
                        SizedBox(width: 8),
                        Text(
                          'Belum Ada Kelas yang Diinput Admin',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tambahkan kelas resmi sekolah terlebih dahulu agar ujian dapat ditugaskan ke siswa.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SchoolClassManagerScreen()),
                        );
                      },
                      child: const Text('Tambah Kelas Sekarang'),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedClasses.isEmpty ? AppColors.rose.withAlpha(100) : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableClasses.map((cls) {
                        final isSelected = _selectedClasses.contains(cls);
                        return FilterChip(
                          label: Text(
                            cls,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppColors.primary : Colors.black87,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primary.withAlpha(35),
                          checkmarkColor: AppColors.primary,
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : Colors.grey.shade300,
                            width: isSelected ? 1.5 : 1,
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
                    if (_selectedClasses.isEmpty) ...[
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: AppColors.rose),
                          SizedBox(width: 4),
                          Text(
                            'Wajib memilih minimal 1 kelas target.',
                            style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // ─── Section 5: Pilih Bank Soal Berdasarkan CP & TP ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(
                  '5. Bank Soal Ujian (${_selectedQuestionIds.length} Soal Terpilih)',
                  Icons.quiz_outlined,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Tab Switcher: [ 🎯 Pilih dari Bank Soal ] | [ 📋 Soal Terpilih (${_selectedQuestionIds.length}) ]
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _bankSoalTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _bankSoalTab == 0 ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.filter_alt_rounded,
                                size: 16, color: _bankSoalTab == 0 ? Colors.white : AppColors.textSecondaryLight),
                            const SizedBox(width: 6),
                            Text(
                              'Pilih dari Bank Soal',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _bankSoalTab == 0 ? Colors.white : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _bankSoalTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _bankSoalTab == 1 ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.checklist_rounded,
                                size: 16, color: _bankSoalTab == 1 ? Colors.white : AppColors.textSecondaryLight),
                            const SizedBox(width: 6),
                            Text(
                              'Soal Terpilih (${_selectedQuestionIds.length})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _bankSoalTab == 1 ? Colors.white : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ─── TAB 1: SOAL TERPILIH ───
            if (_bankSoalTab == 1) ...[
              if (selectedQuestionsList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.checklist_rtl_rounded, size: 54, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Belum Ada Soal yang Dipilih',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Silakan buka tab "Pilih dari Bank Soal" di atas, tentukan CP & TP, lalu centang butir soal yang ingin diujikan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: selectedQuestionsList.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final q = selectedQuestionsList[index];
                    final qCp = availableCps.where((c) => c.id == q.cpId).firstOrNull;
                    final qTp = availableTps.where((t) => t.id == q.tpId).firstOrNull;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF10B981).withAlpha(80)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Soal #${index + 1} • ${q.type.label}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (qCp != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight.withAlpha(20),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    qCp.code,
                                    style: const TextStyle(fontSize: 10, color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              const SizedBox(width: 6),
                              if (qTp != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withAlpha(20),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    qTp.code,
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF047857), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Hapus dari Ujian',
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _selectedQuestionIds.remove(q.id);
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            q.content,
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ] else ...[
              // ─── TAB 0: PILIH DARI BANK SOAL PER CP & TP ───
              // Card Filter CP & TP
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryLight.withAlpha(60)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryLight.withAlpha(12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.filter_alt_rounded, color: AppColors.primaryLight, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pilih CP & TP Terlebih Dahulu:',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Dropdown 1: Capaian Pembelajaran (CP)
                    _labelSmall('1. Capaian Pembelajaran (CP)'),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCpId != null && availableCps.any((c) => c.id == _selectedCpId)
                              ? _selectedCpId
                              : null,
                          hint: const Text('-- Pilih Capaian Pembelajaran (CP) --'),
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryLight),
                          items: availableCps.map((cp) {
                            return DropdownMenuItem(
                              value: cp.id,
                              child: Text(
                                '${cp.code} - ${cp.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedCpId = val;
                              _selectedTpId = null; // reset TP when CP changes
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Dropdown 2: Tujuan Pembelajaran (TP)
                    _labelSmall('2. Tujuan Pembelajaran (TP)'),
                    const SizedBox(height: 4),
                    if (_selectedCpId == null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          '-- Pilih CP Di Atas Terlebih Dahulu --',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedTpId,
                            hint: const Text('-- Pilih Tujuan Pembelajaran (TP) --'),
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryLight),
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('Semua TP pada CP Terpilih', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              ...availableTps.map((tp) => DropdownMenuItem(
                                    value: tp.id,
                                    child: Text(
                                      '${tp.code} - ${tp.title}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  )),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedTpId = val);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Conditional Display: ONLY show questions when BOTH CP and TP are selected!
              if (_selectedCpId == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.filter_list_rounded, size: 36, color: AppColors.primary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Pilih Capaian Pembelajaran (CP) Terlebih Dahulu',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryDark),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Butir-butir bank soal akan dimuat setelah Anda menentukan Capaian Pembelajaran (CP) dan Tujuan Pembelajaran (TP) di atas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else if (_selectedTpId == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.touch_app_rounded, size: 36, color: Color(0xFF059669)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Pilih Tujuan Pembelajaran (TP)',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF065F46)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Capaian Pembelajaran sudah dipilih. Sekarang pilih Tujuan Pembelajaran (TP) pada dropdown di atas untuk memuat butir soal yang sesuai.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else ...[
                // BARU MUNCUL BUTIR-BUTIR SOAL BERDASARKAN CP & TP!
                // Header & Select All Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ditemukan ${filteredQuestions.length} Soal',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E293B)),
                    ),
                    if (filteredQuestions.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            final allFilteredIds = filteredQuestions.map((q) => q.id).toSet();
                            final hasAll = allFilteredIds.every((id) => _selectedQuestionIds.contains(id));
                            if (hasAll) {
                              _selectedQuestionIds.removeAll(allFilteredIds);
                            } else {
                              _selectedQuestionIds.addAll(allFilteredIds);
                            }
                          });
                        },
                        child: Text(
                          filteredQuestions.every((q) => _selectedQuestionIds.contains(q.id))
                              ? 'Batal Semua di Filter Ini'
                              : 'Pilih Semua di Filter Ini',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Action Card: Input Soal Manual & Impor PDF OCR
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withAlpha(50)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tambah Butir Soal Baru untuk CP & TP Terpilih:',
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _openManualQuestionEditor,
                              icon: const Icon(Icons.edit_note_rounded, size: 20),
                              label: const Text('Input Manual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _openPdfOcrImporter,
                              icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                              label: const Text('PDF OCR Impor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Questions List (Filtered by CP & TP)
                if (filteredQuestions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.quiz_outlined, size: 54, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'Tidak ada soal untuk CP & TP terpilih',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black54),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tambahkan butir soal baru menggunakan tombol "Input Manual" atau "PDF OCR Impor" di atas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredQuestions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final q = filteredQuestions[index];
                      final isChecked = _selectedQuestionIds.contains(q.id);
                      final qCp = availableCps.where((c) => c.id == q.cpId).firstOrNull;
                      final qTp = availableTps.where((t) => t.id == q.tpId).firstOrNull;

                      return Container(
                        decoration: BoxDecoration(
                          color: isChecked ? AppColors.primary.withAlpha(12) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isChecked ? AppColors.primary : AppColors.borderLight,
                            width: isChecked ? 1.5 : 1,
                          ),
                        ),
                        child: CheckboxListTile(
                          value: isChecked,
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedQuestionIds.add(q.id);
                              } else {
                                _selectedQuestionIds.remove(q.id);
                              }
                            });
                          },
                          title: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '#${index + 1} • ${q.type.label}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                                ),
                              ),
                              if (qCp != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight.withAlpha(20),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    qCp.code,
                                    style: const TextStyle(fontSize: 9.5, color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              if (qTp != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withAlpha(20),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    qTp.code,
                                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF047857), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              if (q.equationLatex != null && q.equationLatex!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('LaTeX', style: TextStyle(fontSize: 9, color: Colors.purple, fontWeight: FontWeight.bold)),
                                ),
                              if (q.missingImageFlag)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('⚠️ Perlu Gambar', style: TextStyle(fontSize: 9, color: Colors.amber, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              q.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  ),
],
),
),
);
}

  Widget _labelSmall(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF475569),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
