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
import '../../curriculum_and_questions/screens/pdf_importer_screen.dart';
import '../../curriculum_and_questions/screens/question_editor_screen.dart';
import '../../teacher_tools/screens/school_class_manager_screen.dart';

class ExamFormScreen extends StatefulWidget {
  final String subjectId;
  final ExamModel? existingExam;
  final List<String>? initialQuestionIds;

  const ExamFormScreen({
    super.key,
    required this.subjectId,
    this.existingExam,
    this.initialQuestionIds,
  });

  @override
  State<ExamFormScreen> createState() => _ExamFormScreenState();
}

class _ExamFormScreenState extends State<ExamFormScreen> {
  final _uuid = const Uuid();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  ExamCategory _category = ExamCategory.quiz;
  int _durationMinutes = 60;
  bool _antiCheatEnabled = true;

  // Selected Subject (allows picking if teacher has multiple or subjectId is empty)
  String? _selectedSubjectId;

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
    _selectedSubjectId = widget.existingExam?.subjectId ?? (widget.subjectId.isNotEmpty ? widget.subjectId : null);

    if (widget.initialQuestionIds != null && widget.initialQuestionIds!.isNotEmpty) {
      _selectedQuestionIds.addAll(widget.initialQuestionIds!);
      _bankSoalTab = 1;
    }

    if (widget.existingExam != null) {
      final exam = widget.existingExam!;
      _titleCtrl.text = exam.title;
      _descCtrl.text = exam.description;
      _category = exam.category;
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
      if (_selectedQuestionIds.isNotEmpty) {
        _bankSoalTab = 1;
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

  void _openManualQuestionEditor(String activeSubjId) async {
    final fb = context.read<FirebaseService>();
    final initialCount = fb.questions.length;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionEditorScreen(
          subjectId: activeSubjId,
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

  void _openPdfOcrImporter(String activeSubjId) async {
    final fb = context.read<FirebaseService>();
    final initialCount = fb.questions.length;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfImporterScreen(
          subjectId: activeSubjId,
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

  Future<void> _saveExam(String activeSubjId) async {
    if (_titleCtrl.text.trim().isEmpty) {
      AppSnackBar.warning(context, 'Judul ujian wajib diisi!');
      return;
    }

    if (activeSubjId.trim().isEmpty) {
      AppSnackBar.warning(context, 'Mata pelajaran wajib dipilih!');
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
      subjectId: activeSubjId,
      teacherId: isEdit ? widget.existingExam!.teacherId : (fb.currentUser?.id ?? 'teacher_budi'),
      classIds: _selectedClasses.toList(),
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _category,
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
    final currentUser = fb.currentUser;
    final isTeacher = currentUser?.isGuru ?? false;
    final isEdit = widget.existingExam != null;

    // Pembatas ketat: Guru yang bisa mengedit HANYA guru yang membuat ujian tersebut
    if (isEdit && isTeacher && !(currentUser?.isAdmin ?? false)) {
      if (widget.existingExam!.teacherId.isNotEmpty && widget.existingExam!.teacherId != currentUser?.id) {
        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            title: const Text('Edit Ujian'),
            backgroundColor: AppColors.surfaceLight,
            foregroundColor: AppColors.textPrimaryLight,
          ),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_rounded, size: 56, color: Color(0xFFDC2626)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Akses Edit Dibatasi',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Hanya guru yang membuat ujian ini yang berhak mengedit jadwal dan soal ujian.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Kembali'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    final teacherSubjects = fb.getTeacherSubjects(currentUser);
    final availableClasses = fb.getTeacherClasses(currentUser);

    // Resolve active subject
    String activeSubjectId = _selectedSubjectId ?? widget.subjectId;
    if (activeSubjectId.isEmpty && teacherSubjects.isNotEmpty) {
      activeSubjectId = teacherSubjects.first.id;
      _selectedSubjectId = activeSubjectId;
    }

    final allSubjectQuestions = fb.questions.where((q) => q.subjectId == activeSubjectId).toList();

    // CP and TP lists for this subject
    final availableCps = fb.cps.where((c) => c.subjectId == activeSubjectId).toList();
    final availableTps = fb.tps.where((t) {
      if (_selectedCpId != null && _selectedCpId != 'all') {
        return t.cpId == _selectedCpId;
      }
      return t.subjectId == activeSubjectId;
    }).toList();

    // Auto-select first class if not set
    if (!_initialized && availableClasses.isNotEmpty) {
      _selectedClasses.add(availableClasses.first);
      _initialized = true;
    }

    // Filter questions:
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
        : allSubjectQuestions;

    final selectedQuestionsList = allSubjectQuestions
        .where((q) => _selectedQuestionIds.contains(q.id))
        .toList();

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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(isEdit ? Icons.check_circle_rounded : Icons.check_rounded, size: 16),
                  label: Text(
                    isEdit ? 'Simpan' : 'Terbitkan',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () => _saveExam(activeSubjectId),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Informasi Dasar
                    _buildSectionHeader('1. Informasi Ujian / Kuis', Icons.info_outline_rounded),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x080F172A),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Mata Pelajaran Selector
                          if (teacherSubjects.isNotEmpty) ...[
                            _labelSmall('Mata Pelajaran:'),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: teacherSubjects.any((s) => s.id == activeSubjectId)
                                      ? activeSubjectId
                                      : teacherSubjects.first.id,
                                  isExpanded: true,
                                  dropdownColor: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                                  items: teacherSubjects.map((s) {
                                    return DropdownMenuItem(
                                      value: s.id,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.menu_book_rounded, size: 18, color: AppColors.primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              s.name,
                                              style: GoogleFonts.outfit(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13.5,
                                                color: const Color(0xFF0F172A),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedSubjectId = val;
                                        _selectedCpId = null;
                                        _selectedTpId = null;
                                        _selectedQuestionIds.clear();
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Jenis Ujian / Kuis (Quiz, Harian, PTS, PAS)
                          _labelSmall('Jenis Penilaian / Ujian:'),
                          const SizedBox(height: 8),
                          Row(
                            children: ExamCategory.values.map((cat) {
                              final isSelected = _category == cat;
                              Color activeColor;
                              IconData catIcon;
                              switch (cat) {
                                case ExamCategory.quiz:
                                  activeColor = const Color(0xFF0EA5E9);
                                  catIcon = Icons.bolt_rounded;
                                  break;
                                case ExamCategory.harian:
                                  activeColor = const Color(0xFF10B981);
                                  catIcon = Icons.assignment_turned_in_rounded;
                                  break;
                                case ExamCategory.pts:
                                  activeColor = const Color(0xFFF59E0B);
                                  catIcon = Icons.school_rounded;
                                  break;
                                case ExamCategory.pas:
                                  activeColor = const Color(0xFFF43F5E);
                                  catIcon = Icons.workspace_premium_rounded;
                                  break;
                              }

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => setState(() => _category = cat),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 160),
                                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: isSelected ? activeColor.withAlpha(25) : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? activeColor : AppColors.borderLight,
                                          width: isSelected ? 1.8 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: activeColor.withAlpha(35),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            catIcon,
                                            size: 18,
                                            color: isSelected ? activeColor : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            cat.label,
                                            style: GoogleFonts.outfit(
                                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                              fontSize: 12,
                                              color: isSelected ? activeColor : const Color(0xFF334155),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),

                          TextField(
                            controller: _titleCtrl,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
                            decoration: InputDecoration(
                              labelText: 'Judul Ujian / Kuis *',
                              hintText: 'Contoh: Penilaian Harian Modul 1 / UTS Pemrograman',
                              prefixIcon: const Icon(Icons.assignment_outlined, color: AppColors.primary),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.borderLight),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.borderLight),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _descCtrl,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Petunjuk & Tata Tertib Pengerjaan',
                              hintText: 'Ujian ini menggunakan sistem pengawasan anti-kecurangan...',
                              prefixIcon: const Icon(Icons.rule_folder_outlined, color: Color(0xFF64748B)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.borderLight),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.borderLight),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 2: Jadwal Pelaksanaan Ujian (Tanggal & Jam)
                    _buildSectionHeader('2. Jadwal Pelaksanaan Ujian', Icons.schedule_rounded),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x080F172A),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // 1. Waktu Mulai Dibuka
                          _buildScheduleCard(
                            context: context,
                            title: 'Waktu Mulai Dibuka',
                            icon: Icons.play_circle_fill_rounded,
                            iconColor: const Color(0xFF10B981),
                            iconBg: const Color(0xFF10B981).withAlpha(20),
                            badgeText: 'Mulai Ujian',
                            badgeColor: const Color(0xFF10B981),
                            date: _startDate,
                            time: _startTime,
                            onPickDate: _pickStartDate,
                            onPickTime: _pickStartTime,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ),
                          // 2. Waktu Selesai / Ditutup
                          _buildScheduleCard(
                            context: context,
                            title: 'Waktu Berakhir / Ditutup',
                            icon: Icons.stop_circle_rounded,
                            iconColor: AppColors.rose,
                            iconBg: AppColors.rose.withAlpha(20),
                            badgeText: 'Batas Tutup',
                            badgeColor: AppColors.rose,
                            date: _endDate,
                            time: _endTime,
                            onPickDate: _pickEndDate,
                            onPickTime: _pickEndTime,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 3: Durasi & Sistem Anti-Cheat
                    _buildSectionHeader('3. Durasi & Pengawasan Ujian', Icons.timer_outlined),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x080F172A),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.hourglass_top_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Durasi Pengerjaan Siswa',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'Hitung mundur dimulai saat siswa menekan tombol mulai',
                                      style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.borderLight),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _durationMinutes,
                                    borderRadius: BorderRadius.circular(12),
                                    dropdownColor: Colors.white,
                                    items: (<int>{15, 30, 45, 60, 90, 120, _durationMinutes}.toList()..sort())
                                        .map((m) => DropdownMenuItem(
                                              value: m,
                                              child: Text(
                                                '$m Menit',
                                                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _durationMinutes = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _antiCheatEnabled ? AppColors.rose.withAlpha(12) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _antiCheatEnabled ? AppColors.rose.withAlpha(60) : AppColors.borderLight,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _antiCheatEnabled ? AppColors.rose.withAlpha(25) : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.security_rounded,
                                    color: _antiCheatEnabled ? AppColors.rose : Colors.grey.shade600,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Anti-Cheat Zero Tolerance',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _antiCheatEnabled ? AppColors.rose : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Kunci fullscreen, deteksi blur tab, auto-submit saat melanggar toleransi.',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: _antiCheatEnabled,
                                  activeThumbColor: AppColors.rose,
                                  onChanged: (val) => setState(() => _antiCheatEnabled = val),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 4: Target Kelas Peserta
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.groups_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  '4. Target Kelas',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E293B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _selectedClasses.isEmpty
                                      ? AppColors.rose.withAlpha(20)
                                      : AppColors.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_selectedClasses.length} Terpilih',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedClasses.isEmpty ? AppColors.rose : AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (availableClasses.isNotEmpty)
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              setState(() {
                                if (_selectedClasses.length == availableClasses.length) {
                                  _selectedClasses.clear();
                                } else {
                                  _selectedClasses.addAll(availableClasses);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _selectedClasses.length == availableClasses.length
                                        ? Icons.deselect_rounded
                                        : Icons.select_all_rounded,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _selectedClasses.length == availableClasses.length
                                        ? 'Batal'
                                        : 'Pilih Semua (${availableClasses.length})',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ujian ini dapat ditugaskan ke beberapa kelas sekaligus. Siswa di semua kelas terpilih dapat langsung mengerjakan.',
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
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _selectedClasses.isEmpty ? AppColors.rose.withAlpha(100) : AppColors.borderLight,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x080F172A),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: availableClasses.map((cls) {
                                final isSelected = _selectedClasses.contains(cls);
                                return InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedClasses.remove(cls);
                                      } else {
                                        _selectedClasses.add(cls);
                                      }
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: AppColors.primary.withAlpha(25),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSelected) ...[
                                          const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary),
                                          const SizedBox(width: 5),
                                        ],
                                        Text(
                                          cls,
                                          style: GoogleFonts.outfit(
                                            fontSize: 12.5,
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            color: isSelected ? AppColors.primaryDark : const Color(0xFF334155),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            if (_selectedClasses.isEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 14, color: AppColors.rose),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Wajib memilih minimal 1 kelas target.',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: AppColors.rose,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Section 5: Pilih Bank Soal Berdasarkan CP & TP
                    _buildSectionHeader(
                      '5. Bank Soal Ujian (${_selectedQuestionIds.length} Terpilih)',
                      Icons.quiz_outlined,
                    ),
                    const SizedBox(height: 10),

                    // Tab Switcher
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setState(() => _bankSoalTab = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _bankSoalTab == 0 ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.filter_alt_rounded,
                                      size: 16,
                                      color: _bankSoalTab == 0 ? Colors.white : AppColors.textSecondaryLight,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Pilih Bank Soal',
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
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setState(() => _bankSoalTab = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _bankSoalTab == 1 ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.checklist_rounded,
                                      size: 16,
                                      color: _bankSoalTab == 1 ? Colors.white : AppColors.textSecondaryLight,
                                    ),
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

                    // TAB 1: SOAL TERPILIH
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
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Silakan buka tab "Pilih Bank Soal" di atas, tentukan CP & TP, lalu centang butir soal yang ingin diujikan.',
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
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: AppColors.primary,
                                          ),
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
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.primaryDark,
                                              fontWeight: FontWeight.bold,
                                            ),
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
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF047857),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      const Spacer(),
                                      IconButton(
                                        tooltip: 'Hapus dari Ujian',
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.redAccent,
                                          size: 20,
                                        ),
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
                      // TAB 0: PILIH DARI BANK SOAL PER CP & TP
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
                                  'Filter CP & TP Soal:',
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
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedCpId != null ? AppColors.primary.withAlpha(80) : AppColors.borderLight,
                                  width: _selectedCpId != null ? 1.5 : 1,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCpId != null && (_selectedCpId == 'all' || availableCps.any((c) => c.id == _selectedCpId))
                                      ? _selectedCpId
                                      : null,
                                  hint: Text(
                                    '-- Pilih Capaian Pembelajaran (CP) --',
                                    style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                                  ),
                                  isExpanded: true,
                                  dropdownColor: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  elevation: 6,
                                  menuMaxHeight: 320,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'all',
                                      child: Text(
                                        'Semua CP pada Mapel Ini',
                                        style: GoogleFonts.outfit(
                                          fontWeight: _selectedCpId == 'all' ? FontWeight.w800 : FontWeight.w600,
                                          fontSize: 13,
                                          color: _selectedCpId == 'all' ? AppColors.primaryDark : const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                    ...availableCps.map((cp) {
                                      final isCurSelected = cp.id == _selectedCpId;
                                      return DropdownMenuItem(
                                        value: cp.id,
                                        child: Text(
                                          '${cp.code} - ${cp.title}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(
                                            fontWeight: isCurSelected ? FontWeight.w800 : FontWeight.w600,
                                            fontSize: 13,
                                            color: isCurSelected ? AppColors.primaryDark : const Color(0xFF1E293B),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedCpId = val;
                                      _selectedTpId = val == 'all' ? 'all' : null;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Dropdown 2: Tujuan Pembelajaran (TP)
                            _labelSmall('2. Tujuan Pembelajaran (TP)'),
                            const SizedBox(height: 5),
                            if (_selectedCpId == null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey.shade400),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Pilih CP di atas terlebih dahulu',
                                      style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 13),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedTpId != null ? const Color(0xFF10B981).withAlpha(120) : AppColors.borderLight,
                                    width: _selectedTpId != null ? 1.5 : 1,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedTpId != null && (_selectedTpId == 'all' || availableTps.any((t) => t.id == _selectedTpId))
                                        ? _selectedTpId
                                        : null,
                                    hint: Text(
                                      '-- Pilih Tujuan Pembelajaran (TP) --',
                                      style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                                    ),
                                    isExpanded: true,
                                    dropdownColor: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    elevation: 6,
                                    menuMaxHeight: 320,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF10B981)),
                                    items: [
                                      DropdownMenuItem(
                                        value: 'all',
                                        child: Text(
                                          'Semua TP pada CP Terpilih',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(
                                            fontWeight: _selectedTpId == 'all' ? FontWeight.w800 : FontWeight.w600,
                                            fontSize: 13,
                                            color: _selectedTpId == 'all' ? const Color(0xFF047857) : const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                      ...availableTps.map((tp) {
                                        final isCurSelected = tp.id == _selectedTpId;
                                        return DropdownMenuItem(
                                          value: tp.id,
                                          child: Text(
                                            '${tp.code} - ${tp.title}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(
                                              fontWeight: isCurSelected ? FontWeight.w800 : FontWeight.w600,
                                              fontSize: 13,
                                              color: isCurSelected ? const Color(0xFF047857) : const Color(0xFF1E293B),
                                            ),
                                          ),
                                        );
                                      }),
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

                      // Action Card: Input Soal Manual & Impor PDF OCR
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withAlpha(50)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(8),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tambah Butir Soal Baru:',
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => _openManualQuestionEditor(activeSubjectId),
                                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                                    label: const Text('Input Manual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDC2626),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => _openPdfOcrImporter(activeSubjectId),
                                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                                    label: const Text('PDF OCR Impor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Questions Count & Select All
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ditemukan ${filteredQuestions.length} Soal',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: const Color(0xFF1E293B),
                            ),
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
                                    ? 'Batal Semua'
                                    : 'Pilih Semua (${filteredQuestions.length})',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Questions List
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
                                'Belum Ada Soal pada Mapel / Filter Ini',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black54,
                                ),
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
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: AppColors.primary,
                                        ),
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
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            color: AppColors.primaryDark,
                                            fontWeight: FontWeight.bold,
                                          ),
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
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            color: Color(0xFF047857),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    if (q.equationLatex != null && q.equationLatex!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'LaTeX',
                                          style: TextStyle(fontSize: 9, color: Colors.purple, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    if (q.missingImageFlag)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          '⚠️ Perlu Gambar',
                                          style: TextStyle(fontSize: 9, color: Colors.amber, fontWeight: FontWeight.bold),
                                        ),
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
                    const SizedBox(height: 40),
                  ],
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
        Flexible(
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String badgeText,
    required Color badgeColor,
    required DateTime date,
    required TimeOfDay time,
    required VoidCallback onPickDate,
    required VoidCallback onPickTime,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Picker Tile Tanggal
              Expanded(
                child: InkWell(
                  onTap: onPickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tanggal',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                AppDateFormatter.formatDate(date),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_calendar_rounded, size: 14, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Picker Tile Jam
              Expanded(
                child: InkWell(
                  onTap: onPickTime,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Waktu',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                '${time.format(context)} WIB',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
