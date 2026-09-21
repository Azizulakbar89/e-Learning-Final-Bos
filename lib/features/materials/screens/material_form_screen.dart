import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/assignment_model.dart';
import '../../../core/models/material_model.dart';
import '../../../core/models/question_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/curved_header_card.dart';

class MaterialFormScreen extends StatefulWidget {
  /// Pass [subjectId] to pre-select a subject (e.g. opened from subject tab).
  /// Leave null to show a subject picker inside the form.
  final String? subjectId;
  final MaterialModel? existingMaterial;

  const MaterialFormScreen({
    super.key,
    this.subjectId,
    this.existingMaterial,
  });

  @override
  State<MaterialFormScreen> createState() => _MaterialFormScreenState();
}

class _MaterialFormScreenState extends State<MaterialFormScreen> {
  final _uuid = const Uuid();

  // Subject selection
  String? _selectedSubjectId;
  String _getSubjectId() => _selectedSubjectId ?? widget.subjectId ?? '';

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.existingMaterial?.subjectId ?? widget.subjectId;
    if (widget.existingMaterial != null) {
      final m = widget.existingMaterial!;
      _titleCtrl.text = m.title;
      _descCtrl.text = m.description;
      _mediaUrlCtrl.text = m.mediaUrl;
      _contentType = m.contentType;
      _selectedClassIds.addAll(m.classIds);
      _scheduledOpenAt = m.scheduledOpenAt;
      _aiSummaryCtrl.text = m.aiContextSummary ?? '';
      _assignmentType = m.assignmentType ?? 'none';
    }
  }

  // Material fields
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _mediaUrlCtrl = TextEditingController();
  final _aiSummaryCtrl = TextEditingController();
  String _contentType = 'youtube';
  final Set<String> _selectedClassIds = {};
  DateTime? _scheduledOpenAt;
  Uint8List? _pptFileBytes;
  String? _pptFileName;
  bool _isUploadingPpt = false;

  // Assignment fields
  String _assignmentType = 'none';
  final _assignTitleCtrl = TextEditingController();
  final _assignDescCtrl = TextEditingController();
  DateTime _deadline = DateTime.now().add(const Duration(days: 7));
  final Set<SubmissionType> _selectedSubmTypes = {SubmissionType.pdf, SubmissionType.link};
  int _maxGroupMembers = 3;
  final Set<String> _selectedLanguages = {'html', 'css', 'js'};
  bool _requireCompile = false;
  final _starterCodeCtrl = TextEditingController();
  final List<_InlinePgQuestion> _pgQuestions = [];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _mediaUrlCtrl.dispose();
    _aiSummaryCtrl.dispose();
    _assignTitleCtrl.dispose();
    _assignDescCtrl.dispose();
    _starterCodeCtrl.dispose();
    for (final q in _pgQuestions) {
      q.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPptFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['ppt', 'pptx', 'pdf'],
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _pptFileBytes = bytes;
        _pptFileName = file.name;
      });
    }
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _fmtDt(DateTime? dt) {
    if (dt == null) return 'Sekarang (langsung tersedia)';
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year} pukul $hh:$min';
  }

  Future<void> _save() async {
    final subjectId = _getSubjectId();
    if (subjectId.isEmpty) {
      AppSnackBar.warning(context, 'Pilih mata pelajaran terlebih dahulu!');
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      AppSnackBar.warning(context, 'Judul materi wajib diisi!');
      return;
    }
    if (_selectedClassIds.isEmpty) {
      AppSnackBar.warning(context, 'Pilih minimal 1 kelas!');
      return;
    }

    final fb = context.read<FirebaseService>();
    final isEdit = widget.existingMaterial != null;
    final materialId = isEdit ? widget.existingMaterial!.id : _uuid.v4();

    // Pre-validate media URL sebelum masuk loading dialog
    String mediaUrl = _mediaUrlCtrl.text.trim();
    if (_contentType != 'ppt' && mediaUrl.isEmpty) {
      AppSnackBar.warning(context, 'URL media wajib diisi!');
      return;
    }

    setState(() => _isUploadingPpt = true);
    final isEdit2 = isEdit; // capture for closure
    try {
      await showLoadingDialog(
        context,
        message: isEdit ? 'Memperbarui materi...' : 'Menerbitkan materi baru...',
        action: () async {
          // Upload PPT jika ada
          if (_contentType == 'ppt' && _pptFileBytes != null) {
            mediaUrl = await fb.uploadPptFile(
              bytes: _pptFileBytes!,
              fileName: _pptFileName ?? 'presentation.pptx',
              materialId: materialId,
            );
          }

        if (mediaUrl.isEmpty) throw Exception('URL media wajib diisi!');

        final material = MaterialModel(
          id: materialId,
          subjectId: subjectId,
          teacherId: isEdit2 ? widget.existingMaterial!.teacherId : (fb.currentUser?.id ?? ''),
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          contentType: _contentType,
          mediaUrl: mediaUrl,
          classIds: _selectedClassIds.toList(),
          scheduledOpenAt: _scheduledOpenAt,
          assignmentType: _assignmentType == 'none' ? null : _assignmentType,
          aiContextSummary: _aiSummaryCtrl.text.trim().isNotEmpty ? _aiSummaryCtrl.text.trim() : null,
          createdAt: isEdit2 ? widget.existingMaterial!.createdAt : DateTime.now(),
        );

        if (isEdit2) {
          await fb.updateMaterial(material);
        } else {
          await fb.addMaterial(material);
        }

        if (_assignmentType != 'none') {
          final aTitle = _assignTitleCtrl.text.trim().isNotEmpty
              ? _assignTitleCtrl.text.trim()
              : _titleCtrl.text.trim();

          List<String> questionIds = [];
          if (_assignmentType == 'pilihan_ganda') {
            questionIds = await _savePgQuestions(fb, subjectId);
          }

          final assignment = AssignmentModel(
            id: _uuid.v4(),
            materialId: materialId,
            subjectId: subjectId,
            teacherId: fb.currentUser?.id ?? '',
            title: aTitle,
            description: _assignDescCtrl.text.trim(),
            assignmentType: _assignmentType,
            classIds: _selectedClassIds.toList(),
            isGroup: _assignmentType == 'kelompok',
            maxGroupMembers: _assignmentType == 'kelompok' ? _maxGroupMembers : 1,
            allowedSubmissionTypes: _assignmentType == 'pilihan_ganda'
                ? [SubmissionType.text]
                : _selectedSubmTypes.toList(),
            codeConfig: _selectedSubmTypes.contains(SubmissionType.code) && _assignmentType != 'pilihan_ganda'
                ? CodeConfig(
                    allowedLanguages: _selectedLanguages.toList(),
                    starterCode: _starterCodeCtrl.text.trim(),
                    requireSuccessfulCompile: _requireCompile,
                  )
                : null,
            questionIds: questionIds,
            deadline: _deadline,
            createdAt: DateTime.now(),
          );
          await fb.addAssignment(assignment);
        }
      },
      successMessage: isEdit ? 'Materi berhasil diperbarui!' : 'Materi berhasil diterbitkan!',
      errorMessage: 'Gagal menyimpan materi. Periksa koneksi internet Anda.',
      popOnSuccess: true,
    );
    } finally {
      if (mounted) setState(() => _isUploadingPpt = false);
    }
  }

  Future<List<String>> _savePgQuestions(FirebaseService fb, String subjectId) async {
    final ids = <String>[];
    for (final q in _pgQuestions) {
      if (q.contentCtrl.text.trim().isEmpty) continue;
      final id = _uuid.v4();
      final options = ['A', 'B', 'C', 'D'].asMap().entries.map((e) {
        return QuestionOption(id: e.value, text: q.optionControllers[e.key].text.trim());
      }).toList();
      final qModel = QuestionModel(
        id: id,
        subjectId: subjectId,
        cpId: '',
        tpId: '',
        type: QuestionType.single,
        content: q.contentCtrl.text.trim(),
        options: options,
        correctAnswers: q.correctOption,
      );
      await fb.addQuestion(qModel);
      ids.add(id);
    }
    return ids;
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final currentUser = fb.currentUser;
    final isTeacher = currentUser?.isGuru ?? false;
    final isEdit = widget.existingMaterial != null;

    // Pembatas ketat: Guru yang bisa mengedit HANYA guru yang membuat materi tersebut
    if (isEdit && isTeacher && !(currentUser?.isAdmin ?? false)) {
      if (widget.existingMaterial!.teacherId.isNotEmpty &&
          widget.existingMaterial!.teacherId != currentUser?.id) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text('Edit Materi'),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E293B),
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
                      'Hanya guru yang membuat materi ini yang berhak mengeditnya.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Kembali'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
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

    final availableClasses = fb.getTeacherClasses(fb.currentUser);
    final availableSubjects = fb.getTeacherSubjects(fb.currentUser);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CurvedHeaderCard(
              title: widget.existingMaterial != null ? 'Edit Materi' : 'Tambah Materi',
              subtitle: 'Penyusunan Konten & Sumber Belajar Siswa',
              actions: [
                _isUploadingPpt
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      )
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _save,
                        icon: Icon(
                          widget.existingMaterial != null
                              ? Icons.check_circle_rounded
                              : Icons.publish_rounded,
                          size: 16,
                        ),
                        label: Text(
                          widget.existingMaterial != null
                              ? 'Simpan'
                              : 'Terbitkan',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // ── SECTION 1: Info Materi ──────────────────────────────────────
            _sectionHeader('1', Icons.book_outlined, 'Informasi Materi', AppColors.primary),
            const SizedBox(height: 12),
            _card(children: [
              _label('Mata Pelajaran *'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: availableSubjects.any((s) => s.id == _selectedSubjectId)
                    ? _selectedSubjectId
                    : null,
                isExpanded: true,
                decoration: _dec('Pilih Mata Pelajaran'),
                hint: Text('Pilih Mata Pelajaran',
                    style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 13)),
                items: availableSubjects.map((subj) {
                  return DropdownMenuItem<String>(
                    value: subj.id,
                    child: Text(
                      '${subj.name} (${subj.code})',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedSubjectId = val);
                },
              ),
              const SizedBox(height: 14),
              _label('Judul Materi *'),
              TextField(controller: _titleCtrl, decoration: _dec('Contoh: Pemrograman Web Interaktif'), style: GoogleFonts.outfit()),
              const SizedBox(height: 14),
              _label('Deskripsi & Tujuan Belajar'),
              TextField(controller: _descCtrl, maxLines: 3, decoration: _dec('Ringkasan materi dan kompetensi...'), style: GoogleFonts.outfit()),
              const SizedBox(height: 14),
              _label('Jadwal Dibuka untuk Siswa'),
              const SizedBox(height: 6),
              _schedulePicker(),
              const SizedBox(height: 14),
              _label('Kelas Yang Menerima Materi *'),
              const SizedBox(height: 8),
              availableClasses.isEmpty
                  ? Text('Belum ada kelas. Buat di menu Kelas terlebih dahulu.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: availableClasses.map((clsName) {
                        final sel = _selectedClassIds.contains(clsName);
                        return FilterChip(
                          label: Text(clsName, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
                          selected: sel,
                          selectedColor: AppColors.primary.withAlpha(25),
                          checkmarkColor: AppColors.primary,
                          side: BorderSide(color: sel ? AppColors.primary : Colors.grey.shade300),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _selectedClassIds.add(clsName);
                            } else {
                              _selectedClassIds.remove(clsName);
                            }
                          }),
                        );
                      }).toList(),
                    ),
            ]),

            const SizedBox(height: 20),

            // ── SECTION 2: Media ────────────────────────────────────────────
            _sectionHeader('2', Icons.play_lesson_outlined, 'Media Pembelajaran', Colors.orange.shade700),
            const SizedBox(height: 12),
            _card(children: [
              _label('Tipe Media'),
              const SizedBox(height: 8),
              Row(children: [
                _mediaChip('youtube', Icons.play_circle_outline, 'YouTube', Colors.red),
                const SizedBox(width: 8),
                _mediaChip('canva', Icons.palette_outlined, 'Canva', Colors.teal),
                const SizedBox(width: 8),
                _mediaChip('ppt', Icons.slideshow_outlined, 'PPT File', Colors.orange.shade700),
              ]),
              const SizedBox(height: 14),
              if (_contentType == 'ppt') ...[
                _label('Upload File Presentasi (.ppt / .pptx / .pdf)'),
                const SizedBox(height: 8),
                _pptUploadBox(),
              ] else ...[
                _label(_contentType == 'youtube' ? 'URL YouTube' : 'URL Canva Embed'),
                const SizedBox(height: 6),
                TextField(
                  controller: _mediaUrlCtrl,
                  decoration: _dec(
                    _contentType == 'youtube'
                        ? 'https://youtube.com/watch?v=...'
                        : 'https://www.canva.com/design/.../view?embed',
                  ).copyWith(prefixIcon: const Icon(Icons.link_rounded)),
                  style: GoogleFonts.outfit(),
                ),
              ],
              const SizedBox(height: 14),
              _label('Catatan AI Grounding (Opsional)'),
              TextField(
                controller: _aiSummaryCtrl,
                maxLines: 2,
                decoration: _dec('Teks membantu AI menjawab pertanyaan siswa dengan akurat'),
                style: GoogleFonts.outfit(fontSize: 13),
              ),
            ]),

            const SizedBox(height: 20),

            // ── SECTION 3: Tugas ────────────────────────────────────────────
            _sectionHeader('3', Icons.assignment_outlined, 'Tugas (Opsional)', Colors.purple.shade700),
            const SizedBox(height: 12),
            _card(children: [
              _label('Jenis Tugas'),
              const SizedBox(height: 10),
              _typeCard('none', Icons.do_not_disturb_alt_outlined, 'Tidak Ada Tugas',
                  'Materi hanya untuk dipelajari', Colors.grey),
              const SizedBox(height: 8),
              _typeCard('individu', Icons.person_outline_rounded, 'Tugas Individu',
                  'Setiap siswa mengumpulkan sendiri', AppColors.primary),
              const SizedBox(height: 8),
              _typeCard('kelompok', Icons.groups_outlined, 'Tugas Kelompok',
                  'Ketua bentuk kelompok, nilai tersebar ke semua anggota', Colors.purple),
              const SizedBox(height: 8),
              _typeCard('pilihan_ganda', Icons.quiz_outlined, 'Kuis Pilihan Ganda',
                  'Siswa jawab soal PG langsung di aplikasi', Colors.orange.shade700),
            ]),

            // Sub-form tugas
            if (_assignmentType != 'none') ...[
              const SizedBox(height: 16),
              _card(children: [
                TextField(
                  controller: _assignTitleCtrl,
                  decoration: _dec('Judul tugas (kosong = pakai judul materi)').copyWith(labelText: 'Judul Tugas'),
                  style: GoogleFonts.outfit(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _assignDescCtrl,
                  maxLines: 3,
                  decoration: _dec('Instruksi dan kriteria penilaian...').copyWith(labelText: 'Instruksi & Deskripsi'),
                  style: GoogleFonts.outfit(),
                ),
                const SizedBox(height: 14),
                _deadlinePicker(),
              ]),
            ],

            // Sub-form individu / kelompok
            if (_assignmentType == 'individu' || _assignmentType == 'kelompok') ...[
              const SizedBox(height: 12),
              _card(children: [
                if (_assignmentType == 'kelompok') ...[
                  _label('Kapasitas Maks. Anggota Per Kelompok'),
                  const SizedBox(height: 8),
                  Row(
                    children: [2, 3, 4, 5, 6].map((n) {
                      final sel = _maxGroupMembers == n;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _maxGroupMembers = n),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: sel ? Colors.purple : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: sel ? Colors.purple : Colors.grey.shade300),
                            ),
                            child: Center(
                              child: Text('$n',
                                  style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: sel ? Colors.white : Colors.grey.shade700)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                _label('Format Pengumpulan yang Diizinkan'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: SubmissionType.values.map((t) {
                    final sel = _selectedSubmTypes.contains(t);
                    return FilterChip(
                      label: Text(t.label, style: GoogleFonts.outfit(fontSize: 13)),
                      selected: sel,
                      selectedColor: AppColors.primary.withAlpha(25),
                      checkmarkColor: AppColors.primary,
                      side: BorderSide(color: sel ? AppColors.primary : Colors.grey.shade300),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selectedSubmTypes.add(t);
                        } else if (_selectedSubmTypes.length > 1) {
                          _selectedSubmTypes.remove(t);
                        }
                      }),
                    );
                  }).toList(),
                ),
                if (_selectedSubmTypes.contains(SubmissionType.code)) ...[
                  const SizedBox(height: 16),
                  _codeConfigBox(),
                ],
              ]),
            ],

            // Sub-form pilihan ganda
            if (_assignmentType == 'pilihan_ganda') ...[
              const SizedBox(height: 12),
              _card(children: [
                Row(children: [
                  Text('Soal Kuis (${_pgQuestions.length} soal)',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _pgQuestions.add(_InlinePgQuestion())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah Soal'),
                  ),
                ]),
                const SizedBox(height: 8),
                if (_pgQuestions.isEmpty)
                  _emptyPgPlaceholder()
                else
                  Column(
                    children: _pgQuestions.asMap().entries.map((e) => _pgCard(e.key, e.value)).toList(),
                  ),
              ]),
            ],

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isUploadingPpt ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
                icon: _isUploadingPpt
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.publish_rounded),
                label: Text(
                  _isUploadingPpt ? 'Mengupload...' : 'Terbitkan Materi',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
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

  // ── Widget helpers ──────────────────────────────────────────────────────────

  Widget _sectionHeader(String num, IconData icon, String title, Color color) => Row(
    children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text(num, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
      ),
      const SizedBox(width: 10),
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 8),
      Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
    ],
  );

  Widget _card({required List<Widget> children}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _label(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade700)),
  );

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
  );

  Widget _schedulePicker() => InkWell(
    onTap: () async {
      final dt = await _pickDateTime(_scheduledOpenAt ?? DateTime.now().add(const Duration(hours: 1)));
      if (dt != null) setState(() => _scheduledOpenAt = dt);
    },
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
      child: Row(children: [
        Icon(Icons.schedule_rounded, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(_fmtDt(_scheduledOpenAt),
              style: GoogleFonts.outfit(
                  color: _scheduledOpenAt != null ? AppColors.primary : Colors.grey.shade500,
                  fontWeight: _scheduledOpenAt != null ? FontWeight.w600 : FontWeight.normal)),
        ),
        if (_scheduledOpenAt != null)
          GestureDetector(
            onTap: () => setState(() => _scheduledOpenAt = null),
            child: Icon(Icons.clear, size: 16, color: Colors.grey.shade500),
          ),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
      ]),
    ),
  );

  Widget _pptUploadBox() => InkWell(
    onTap: _pickPptFile,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _pptFileBytes != null ? AppColors.emerald : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: _pptFileBytes != null ? AppColors.emerald.withAlpha(10) : Colors.grey.shade50,
      ),
      child: Row(children: [
        Icon(
          _pptFileBytes != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
          color: _pptFileBytes != null ? AppColors.emerald : Colors.grey.shade500,
          size: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_pptFileName ?? 'Klik untuk pilih file',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    color: _pptFileBytes != null ? AppColors.emerald : AppColors.textPrimaryLight)),
            if (_pptFileBytes != null)
              Text('${(_pptFileBytes!.length / 1024).toStringAsFixed(1)} KB',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ]),
        ),
        if (_pptFileBytes != null)
          TextButton(
            onPressed: () => setState(() { _pptFileBytes = null; _pptFileName = null; }),
            child: const Text('Ganti'),
          ),
      ]),
    ),
  );

  Widget _mediaChip(String type, IconData icon, String label, Color color) {
    final sel = _contentType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _contentType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: sel ? color.withAlpha(20) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? color : Colors.grey.shade300, width: sel ? 2 : 1),
          ),
          child: Column(children: [
            Icon(icon, color: sel ? color : Colors.grey.shade500, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    color: sel ? color : Colors.grey.shade600),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }

  Widget _typeCard(String type, IconData icon, String title, String subtitle, Color color) {
    final sel = _assignmentType == type;
    return GestureDetector(
      onTap: () => setState(() => _assignmentType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? color.withAlpha(15) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? color : Colors.grey.shade200, width: sel ? 2 : 1),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: sel ? color.withAlpha(30) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: sel ? color : Colors.grey.shade500, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: sel ? color : AppColors.textPrimaryLight)),
              Text(subtitle, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500)),
            ]),
          ),
          if (sel) Icon(Icons.check_circle_rounded, color: color, size: 20),
        ]),
      ),
    );
  }

  Widget _deadlinePicker() => InkWell(
    onTap: () async {
      final dt = await _pickDateTime(_deadline);
      if (dt != null) setState(() => _deadline = dt);
    },
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(10),
        color: Colors.red.shade50,
      ),
      child: Row(children: [
        const Icon(Icons.calendar_month_rounded, color: Colors.red, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Batas Waktu (Deadline)',
                style: TextStyle(fontSize: 11, color: Colors.red.shade400)),
            Text(_fmtDt(_deadline),
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
          ]),
        ),
        Icon(Icons.edit_calendar_rounded, size: 18, color: Colors.red.shade400),
      ]),
    ),
  );

  Widget _codeConfigBox() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.terminal_rounded, color: AppColors.emerald, size: 18),
        const SizedBox(width: 8),
        Text('Konfigurasi Koding', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 10),
      Wrap(
        spacing: 6, runSpacing: 6,
        children: [
          {'id': 'html', 'name': 'HTML'},
          {'id': 'css', 'name': 'CSS'},
          {'id': 'js', 'name': 'JavaScript'},
          {'id': 'php', 'name': 'PHP'},
          {'id': 'arduino', 'name': 'Arduino'},
        ].map((lang) {
          final isSel = _selectedLanguages.contains(lang['id']);
          return FilterChip(
            label: Text(lang['name']!,
                style: GoogleFonts.outfit(fontSize: 12, color: isSel ? Colors.white : Colors.white70)),
            selected: isSel,
            selectedColor: AppColors.emerald,
            backgroundColor: Colors.white10,
            side: BorderSide(color: isSel ? AppColors.emerald : Colors.white24),
            checkmarkColor: Colors.white,
            onSelected: (v) => setState(() {
              if (v) {
                _selectedLanguages.add(lang['id']!);
              } else if (_selectedLanguages.length > 1) {
                _selectedLanguages.remove(lang['id']!);
              }
            }),
          );
        }).toList(),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Checkbox(
          value: _requireCompile,
          activeColor: AppColors.emerald,
          onChanged: (v) => setState(() => _requireCompile = v ?? false),
        ),
        Expanded(
          child: Text('Wajib compile sukses sebelum kumpul',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 12)),
        ),
      ]),
      const SizedBox(height: 8),
      TextField(
        controller: _starterCodeCtrl,
        maxLines: 4,
        style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          filled: true, fillColor: Colors.black38,
          hintText: '// Starter code...',
          hintStyle: const TextStyle(color: Colors.white30),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ]),
  );

  Widget _emptyPgPlaceholder() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.orange.shade200),
    ),
    child: Center(
      child: Column(children: [
        Icon(Icons.quiz_outlined, color: Colors.orange.shade400, size: 36),
        const SizedBox(height: 8),
        Text('Tekan "+ Tambah Soal" untuk mulai input soal PG',
            style: GoogleFonts.outfit(color: Colors.orange.shade700), textAlign: TextAlign.center),
      ]),
    ),
  );

  Widget _pgCard(int index, _InlinePgQuestion q) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orange.shade200),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(6)),
          child: Text('Soal ${index + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
          onPressed: () => setState(() => _pgQuestions.removeAt(index)),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        ),
      ]),
      const SizedBox(height: 10),
      TextField(
        controller: q.contentCtrl,
        maxLines: 2,
        decoration: _dec('Pertanyaan soal nomor ${index + 1}...'),
        style: GoogleFonts.outfit(),
      ),
      const SizedBox(height: 10),
      StatefulBuilder(builder: (ctx, setStt) => Column(
        children: ['A', 'B', 'C', 'D'].asMap().entries.map((e) {
          final isCorrect = q.correctOption == e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              GestureDetector(
                onTap: () {
                  setState(() => q.correctOption = e.value);
                  setStt(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 28, height: 28,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isCorrect ? AppColors.emerald : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: isCorrect ? AppColors.emerald : Colors.grey.shade400),
                  ),
                  child: Center(
                    child: Text(e.value,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                            color: isCorrect ? Colors.white : Colors.grey.shade600)),
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: q.optionControllers[e.key],
                  decoration: InputDecoration(
                    hintText: 'Opsi ${e.value}',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isCorrect ? AppColors.emerald : Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isCorrect ? AppColors.emerald : Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: isCorrect ? AppColors.emerald.withAlpha(10) : Colors.white,
                  ),
                  style: GoogleFonts.outfit(fontSize: 13),
                ),
              ),
            ]),
          );
        }).toList(),
      )),
      if (q.correctOption.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.emerald.withAlpha(20),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('✓ Kunci Jawaban: ${q.correctOption}',
              style: TextStyle(color: AppColors.emerald, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
    ]),
  );
}

class _InlinePgQuestion {
  final TextEditingController contentCtrl = TextEditingController();
  final List<TextEditingController> optionControllers =
      List.generate(4, (_) => TextEditingController());
  String correctOption = 'A';

  void dispose() {
    contentCtrl.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
  }
}
