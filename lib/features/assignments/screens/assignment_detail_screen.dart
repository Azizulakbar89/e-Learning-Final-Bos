import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/assignment_model.dart';
import '../../../core/models/curriculum_model.dart';
import '../../../core/models/question_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/excel_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../code_compiler/screens/code_playground_screen.dart';
import '../widgets/student_submission_detail_dialog.dart';
import '../widgets/submission_image_viewer.dart';
import '../widgets/submission_pdf_viewer.dart';
import '../../teacher_tools/widgets/sidikmu_sync_dialog.dart';

class AssignmentDetailScreen extends StatefulWidget {
  final AssignmentModel assignment;

  const AssignmentDetailScreen({super.key, required this.assignment});

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  final _uuid = const Uuid();
  late SubmissionType _selectedType;
  final _linkController = TextEditingController();
  final _textController = TextEditingController();

  // Attachment state (PDF & Image)
  String? _attachedPdfName;
  Uint8List? _attachedPdfBytes;
  int? _attachedPdfSize;

  String? _attachedImageName;
  Uint8List? _attachedImageBytes;
  int? _attachedImageSize;
  bool _isSubmitting = false;

  // Multiple Choice Quiz state (if assignmentType == 'pilihan_ganda')
  final Map<String, dynamic> _quizAnswers = {};

  // Code submission state
  String? _submittedCode;
  String? _codeLanguage;
  String? _compileLog;
  bool _compileSuccess = false;
  bool _isEditingSubmission = false;

  // Group state
  String? _groupName;
  final List<String> _selectedMemberIds = [];

  // Teacher class filter state
  String _submissionClassFilter = 'all';

  @override
  void initState() {
    super.initState();
    _selectedType = widget.assignment.allowedSubmissionTypes.isNotEmpty
        ? widget.assignment.allowedSubmissionTypes.first
        : SubmissionType.text;
  }

  @override
  void dispose() {
    _linkController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _openCodeEditor() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => CodePlaygroundScreen(
          initialLanguage: widget.assignment.codeConfig?.allowedLanguages.first ?? 'html',
          initialCode: widget.assignment.codeConfig?.starterCode,
          isAssignmentMode: true,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedType = SubmissionType.code;
        _codeLanguage = result['language'];
        _submittedCode = result['code'];
        _compileLog = result['compile_log'];
        _compileSuccess = result['compile_success'] ?? false;
      });

      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        'Kode berhasil diverifikasi & siap dikumpulkan!',
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pickPdfFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (bytes.length > 10 * 1024 * 1024) {
          if (mounted) {
            AppSnackBar.showError(
              context,
              'Ukuran berkas PDF melebihi batas maksimal 10MB!',
            );
          }
          return;
        }
        setState(() {
          _attachedPdfName = file.name;
          _attachedPdfBytes = bytes;
          _attachedPdfSize = bytes.length;
        });
      }
    } catch (e) {
      debugPrint('Error picking pdf: $e');
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Gagal memilih berkas PDF: $e',
        );
      }
    }
  }

  Future<void> _pickImageDirect(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _attachedImageName = pickedFile.name;
          _attachedImageBytes = bytes;
          _attachedImageSize = bytes.length;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      try {
        final f = await FilePicker.pickFile(
          type: FileType.image,
        );
        if (f != null) {
          final bytes = await f.readAsBytes();
          setState(() {
            _attachedImageName = f.name;
            _attachedImageBytes = bytes;
            _attachedImageSize = bytes.length;
          });
        }
      } catch (e2) {
        if (mounted) {
          AppSnackBar.showError(
            context,
            'Gagal memilih gambar: $e2',
          );
        }
      }
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Pilih Sumber Foto Tugas',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.photo_library_rounded, color: AppColors.primary),
                ),
                title: const Text('Galeri HP / Perangkat', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Pilih file foto tugas dari galeri HP'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFECFDF5),
                  child: Icon(Icons.camera_alt_rounded, color: AppColors.emerald),
                ),
                title: const Text('Kamera HP', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Ambil foto lembar jawaban secara langsung'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source != null) {
      await _pickImageDirect(source);
    }
  }

  void _previewImageDialog(Uint8List bytes, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.55,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const CircleAvatar(
                radius: 14,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final fbService = context.read<FirebaseService>();
    final currentUser = fbService.currentUser;
    if (currentUser == null) return;

    final existingSub = fbService.submissions.where(
      (s) => s.assignmentId == widget.assignment.id &&
          (s.submitterId == currentUser.id || s.memberStudentIds.contains(currentUser.id)),
    ).firstOrNull;
    if (existingSub != null) {
      AppSnackBar.warning(context, 'Tugas ini sudah selesai dikerjakan dan tidak dapat dikumpulkan ulang.');
      return;
    }

    // Validasi pemilihan berkas / konten sesuai metode pengumpulan
    if (_selectedType == SubmissionType.pdf) {
      if (_attachedPdfBytes == null && (_attachedPdfName == null || _attachedPdfName!.isEmpty)) {
        AppSnackBar.warning(context, 'Harap pilih berkas PDF dari memori HP/perangkat Anda terlebih dahulu!');
        return;
      }
    } else if (_selectedType == SubmissionType.image) {
      if (_attachedImageBytes == null && (_attachedImageName == null || _attachedImageName!.isEmpty)) {
        AppSnackBar.warning(context, 'Harap pilih foto tugas dari galeri atau kamera HP Anda terlebih dahulu!');
        return;
      }
    } else if (_selectedType == SubmissionType.link) {
      if (_linkController.text.trim().isEmpty) {
        AppSnackBar.warning(context, 'Harap masukkan URL / link tugas terlebih dahulu!');
        return;
      }
    } else if (_selectedType == SubmissionType.text) {
      if (_textController.text.trim().isEmpty) {
        AppSnackBar.warning(context, 'Harap tuliskan jawaban tugas Anda terlebih dahulu!');
        return;
      }
    } else if (_selectedType == SubmissionType.code) {
      if (_submittedCode == null || _submittedCode!.isEmpty) {
        AppSnackBar.warning(context, 'Harap buka compiler dan verifikasi kode program Anda terlebih dahulu!');
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      await showLoadingDialog(
        context,
        message: 'Mengunggah & mengumpulkan tugas...',
        action: () async {
          String? finalPdfUrl = _attachedPdfName;
          if (_attachedPdfBytes != null) {
            finalPdfUrl = await fbService.uploadAssignmentFile(
              bytes: _attachedPdfBytes!,
              fileName: _attachedPdfName ?? 'tugas.pdf',
              assignmentId: widget.assignment.id,
              studentId: currentUser.id,
            );
          }

          String? finalImageUrl = _attachedImageName;
          if (_attachedImageBytes != null) {
            finalImageUrl = await fbService.uploadAssignmentFile(
              bytes: _attachedImageBytes!,
              fileName: _attachedImageName ?? 'foto_tugas.jpg',
              assignmentId: widget.assignment.id,
              studentId: currentUser.id,
            );
          }

          // Build member IDs
          final memberIds = [currentUser.id];
          if (widget.assignment.isGroup) {
            for (final id in _selectedMemberIds) {
              if (!memberIds.contains(id)) memberIds.add(id);
            }
          }

          final submission = AssignmentSubmissionModel(
            id: _uuid.v4(),
            assignmentId: widget.assignment.id,
            groupId: widget.assignment.isGroup ? 'grp_${DateTime.now().millisecondsSinceEpoch}' : null,
            groupName: widget.assignment.isGroup ? (_groupName ?? 'Kelompok Siswa') : null,
            submitterId: currentUser.id,
            submitterName: currentUser.fullName,
            memberStudentIds: memberIds,
            type: _selectedType,
            pdfUrl: finalPdfUrl,
            linkUrl: _linkController.text.trim().isNotEmpty ? _linkController.text.trim() : null,
            imageUrls: finalImageUrl != null ? [finalImageUrl] : [],
            textContent: _textController.text.trim().isNotEmpty ? _textController.text.trim() : null,
            codeLanguage: _codeLanguage,
            sourceCode: _submittedCode,
            compileLog: _compileLog,
            compileSuccess: _compileSuccess,
            submittedAt: DateTime.now(),
          );

          await fbService.submitAssignment(submission);
        },
        successMessage: 'Tugas berhasil dikumpulkan! Anda mendapatkan +50 Poin Gamifikasi 🌟',
        errorMessage: 'Gagal mengumpulkan tugas. Periksa jaringan Anda dan coba lagi.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isEditingSubmission = false;
        });
      }
    }
  }

  void _handleQuizSubmit(List<QuestionModel> questions) {
    final fbService = context.read<FirebaseService>();
    final currentUser = fbService.currentUser;
    if (currentUser == null) return;

    final existingSub = fbService.submissions.where(
      (s) => s.assignmentId == widget.assignment.id &&
          (s.submitterId == currentUser.id || s.memberStudentIds.contains(currentUser.id)),
    ).firstOrNull;
    if (existingSub != null) {
      AppSnackBar.showError(
        context,
        'Kuis ini sudah selesai dikerjakan dan nilai Anda sudah tercatat.',
      );
      return;
    }

    if (_quizAnswers.isEmpty) {
      AppSnackBar.showError(
        context,
        'Silakan pilih jawaban kuis terlebih dahulu!',
      );
      return;
    }

    int correctCount = 0;
    for (final q in questions) {
      final selectedAns = _quizAnswers[q.id];
      if (selectedAns != null) {
        if (q.type == QuestionType.single && selectedAns.toString() == q.correctAnswers.toString()) {
          correctCount++;
        } else if (q.type == QuestionType.trueFalse && selectedAns == q.correctAnswers) {
          correctCount++;
        } else if (q.type == QuestionType.multi) {
          final correctList = List<String>.from(q.correctAnswers is List ? q.correctAnswers : [q.correctAnswers.toString()]);
          final studentList = List<String>.from(selectedAns is List ? selectedAns : [selectedAns.toString()]);
          if (correctList.length == studentList.length && correctList.every((e) => studentList.contains(e))) {
            correctCount++;
          }
        }
      }
    }

    final double calculatedScore = questions.isNotEmpty
        ? (correctCount / questions.length) * 100.0
        : 100.0;

    final submission = AssignmentSubmissionModel(
      id: _uuid.v4(),
      assignmentId: widget.assignment.id,
      submitterId: currentUser.id,
      submitterName: currentUser.fullName,
      memberStudentIds: [currentUser.id],
      type: SubmissionType.text,
      textContent: 'Kuis Pilihan Ganda: $correctCount dari ${questions.length} soal benar.',
      score: calculatedScore,
      submittedAt: DateTime.now(),
      gradedAt: DateTime.now(),
    );

    fbService.submitAssignment(submission);

    fbService.addPoints(
      studentId: currentUser.id,
      points: (calculatedScore * 0.5).round().clamp(10, 50),
      reason: 'Pengerjaan Kuis: ${widget.assignment.title}',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 38),
              ),
              const SizedBox(height: 16),
              Text(
                'Nilai Kuis Langsung Dinilai! 🎉',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.assignment.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'SKOR YANG DIPEROLEH',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: Color(0xFF047857),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${calculatedScore.round()}',
                          style: GoogleFonts.outfit(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF047857),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '/ 100',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$correctCount dari ${questions.length} butir soal dijawab dengan benar',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF59E0B).withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '+${(calculatedScore * 0.5).round().clamp(10, 50)} Poin Gamifikasi 🌟',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    setState(() {});
                  },
                  child: const Text('Lihat Hasil & Selesai', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportExcel() async {
    final fbService = context.read<FirebaseService>();
    final currentUser = fbService.currentUser;
    final isTeacher = currentUser?.isGuru ?? false;
    final teacherClasses = isTeacher
        ? fbService.getTeacherClasses(currentUser)
        : fbService.getAvailableClasses();
    final teacherClassesLower = teacherClasses.map((c) => c.toLowerCase()).toSet();

    final allSubmissions = fbService.getSubmissionsForAssignment(widget.assignment.id).where((s) {
      if (!isTeacher) return true;
      final student = fbService.allStudents.firstWhere(
        (std) => std.id == s.submitterId,
        orElse: () => currentUserMock,
      );
      final sClass = (student.className ?? student.classId ?? '').trim().toLowerCase();
      return teacherClassesLower.contains(sClass);
    }).toList();

    final submissions = _submissionClassFilter == 'all'
        ? allSubmissions
        : allSubmissions.where((s) {
            final student = fbService.allStudents.firstWhere(
              (std) => std.id == s.submitterId,
              orElse: () => currentUserMock,
            );
            final sClass = (student.className ?? student.classId ?? '').trim();
            return sClass.toLowerCase() == _submissionClassFilter.toLowerCase();
          }).toList();

    final records = <Map<String, dynamic>>[];
    for (final sub in submissions) {
      // Find submitter student NIS
      final student = fbService.allStudents.firstWhere(
        (s) => s.id == sub.submitterId,
        orElse: () => currentUserMock,
      );

      records.add({
        'nis': student.nis ?? 'NIS-000',
        'score': sub.score ?? 0,
      });

      // Also add members if group
      for (final memberId in sub.memberStudentIds) {
        if (memberId != sub.submitterId) {
          final mStudent = fbService.allStudents.firstWhere(
            (s) => s.id == memberId,
            orElse: () => currentUserMock,
          );
          records.add({
            'nis': mStudent.nis ?? 'NIS-000',
            'score': sub.score ?? 0,
          });
        }
      }
    }

    final classesForFile = _submissionClassFilter != 'all'
        ? [_submissionClassFilter]
        : (widget.assignment.classIds.isNotEmpty
            ? widget.assignment.classIds
            : (widget.assignment.subjectId.isNotEmpty ? [widget.assignment.subjectId] : <String>[]));

    final fileName = ExcelService.buildExcelFileName(
      title: widget.assignment.title,
      classes: classesForFile,
    );

    final bytes = ExcelService.generateNisAndScoreExcel(
      sheetTitle: _submissionClassFilter != 'all' ? 'Nilai $_submissionClassFilter' : 'Nilai Tugas',
      records: records,
    );

    await ExcelService.downloadExcel(bytes: bytes, fileName: fileName);

    if (mounted) {
      AppSnackBar.showSuccess(
        context,
        'Berkas Excel "$fileName" berhasil diunduh (${bytes.length} bytes). Berisi kolom NIS & NILAI saja.',
      );
    }
  }

  void _openSidikmuSync(BuildContext context, List<AssignmentSubmissionModel> submissions) {
    final fb = context.read<FirebaseService>();
    final teacher = fb.currentUser;
    if (teacher == null || !teacher.hasSidikmuAccount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun SidikMu belum ditautkan. Buka menu Profil untuk menghubungkan.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Determine target class
    String targetClass = '';
    if (_submissionClassFilter != 'all') {
      targetClass = _submissionClassFilter;
    } else if (widget.assignment.classIds.isNotEmpty) {
      targetClass = widget.assignment.classIds.first;
    }

    // Determine subject name
    final subject = fb.subjects.firstWhere(
      (s) => s.id == widget.assignment.subjectId,
      orElse: () => SubjectModel(id: '', name: 'Informatika', code: ''),
    );

    // Map student NIS to scores
    final studentGradesByNis = <String, double?>{};
    final studentNamesByNis = <String, String>{};

    // Include all students in this class from fb.allStudents
    final classStudents = fb.allStudents.where((s) {
      final sClass = (s.className ?? s.classId ?? '').trim().toLowerCase();
      if (targetClass.isEmpty) return true;
      return sClass == targetClass.toLowerCase();
    }).toList();

    for (final s in classStudents) {
      final nis = (s.nis ?? '').trim();
      if (nis.isNotEmpty) {
        studentGradesByNis[nis] = null; // Default null (empty / not submitted)
        studentNamesByNis[nis] = s.fullName;
      }
    }

    // Fill with submission scores
    for (final sub in submissions) {
      final student = fb.allStudents.firstWhere(
        (std) => std.id == sub.submitterId,
        orElse: () => currentUserMock,
      );
      final nis = (student.nis ?? '').trim();
      if (nis.isNotEmpty) {
        studentGradesByNis[nis] = sub.score;
        studentNamesByNis[nis] = student.fullName.isNotEmpty ? student.fullName : sub.submitterName;
      }
      // Group members sync
      for (final memId in sub.memberStudentIds) {
        final mem = fb.allStudents.firstWhere(
          (m) => m.id == memId,
          orElse: () => currentUserMock,
        );
        final memNis = (mem.nis ?? '').trim();
        if (memNis.isNotEmpty) {
          studentGradesByNis[memNis] = sub.score;
          studentNamesByNis[memNis] = mem.fullName;
        }
      }
    }

    SidikmuSyncDialog.show(
      context,
      isFormatif: true,
      targetClassName: targetClass.isNotEmpty ? targetClass : 'Semua Kelas',
      targetSubjectName: subject.name,
      studentGradesByNis: studentGradesByNis,
      studentNamesByNis: studentNamesByNis,
    );
  }

  static final currentUserMock = UserModel(id: '', username: '', fullName: '', role: '');

  @override
  Widget build(BuildContext context) {
    final fbService = context.watch<FirebaseService>();
    final currentUser = fbService.currentUser;
    final isTeacher = currentUser?.isGuru ?? false;
    final submissions = fbService.getSubmissionsForAssignment(widget.assignment.id);
    final teacherClasses = isTeacher
        ? fbService.getTeacherClasses(currentUser)
        : fbService.getAvailableClasses();
    final teacherClassesLower = teacherClasses.map((c) => c.toLowerCase()).toSet();

    final scopedSubmissions = isTeacher
        ? submissions.where((s) {
            final student = fbService.allStudents.firstWhere(
              (std) => std.id == s.submitterId,
              orElse: () => currentUserMock,
            );
            final sClass = (student.className ?? student.classId ?? '').trim().toLowerCase();
            return teacherClassesLower.contains(sClass);
          }).toList()
        : submissions;

    final filteredSubmissions = isTeacher && _submissionClassFilter != 'all'
        ? scopedSubmissions.where((s) {
            final student = fbService.allStudents.firstWhere(
              (std) => std.id == s.submitterId,
              orElse: () => currentUserMock,
            );
            final sClass = (student.className ?? student.classId ?? '').trim().toLowerCase();
            return sClass == _submissionClassFilter.toLowerCase();
          }).toList()
        : scopedSubmissions;
    final rawQuizQuestions = fbService.questions
        .where((q) => widget.assignment.questionIds.contains(q.id))
        .toList();
    final quizQuestions = currentUser != null
        ? (List<QuestionModel>.from(rawQuizQuestions)
            ..shuffle(Random('${widget.assignment.id}_${currentUser.id}'.hashCode)))
        : rawQuizQuestions;
    final mySub = submissions
        .where((s) => s.submitterId == currentUser?.id || s.memberStudentIds.contains(currentUser?.id))
        .firstOrNull;

    final subject = fbService.subjects.cast<SubjectModel?>().firstWhere(
      (s) => s?.id == widget.assignment.subjectId,
      orElse: () => null,
    );
    final isOverdue = DateTime.now().isAfter(widget.assignment.deadline);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF040D1F), // Deepest Navy
                Color(0xFF071540), // Deep Navy
                Color(0xFF0D2B6E), // Structural Navy
                Color(0xFF1E3A8A), // Medium Navy
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        leading: Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.maybePop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(40)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.assignment.title,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.assignment.isGroup
                        ? const Color(0xFF8B5CF6).withAlpha(55)
                        : const Color(0xFF38BDF8).withAlpha(45),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: widget.assignment.isGroup
                          ? const Color(0xFFA78BFA).withAlpha(90)
                          : const Color(0xFF7DD3FC).withAlpha(80),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.assignment.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.assignment.isGroup ? 'Tugas Kelompok' : 'Tugas Individu',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (subject != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      subject.name,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(200),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: const [], // Logo download di header dihapus sesuai permintaan
      ),
      body: ResponsiveFormWrapper(
        maxWidth: 960,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── AESTHETIC ASSIGNMENT / GROUP CARD ──
              Container(
                decoration: BoxDecoration(
                  gradient: widget.assignment.isGroup
                      ? const LinearGradient(
                          colors: [
                            Color(0xFFFFFFFF),
                            Color(0xFFFAF5FF), // Soft lavender tint
                            Color(0xFFF5EEFD),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0xFFFFFFFF),
                            Color(0xFFF8FAFC),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: widget.assignment.isGroup
                        ? const Color(0xFFDDD6FE)
                        : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.assignment.isGroup
                          ? const Color(0xFF7C3AED).withAlpha(18)
                          : Colors.black.withAlpha(10),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Accent Glow Strip
                      Container(
                        height: 5,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: widget.assignment.isGroup
                              ? const LinearGradient(
                                  colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9), Color(0xFFEC4899)],
                                )
                              : AppColors.orangeGradient,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Tag & Deadline Row
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        gradient: widget.assignment.isGroup
                                            ? const LinearGradient(
                                                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : const LinearGradient(
                                                colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                                              ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (widget.assignment.isGroup
                                                    ? const Color(0xFF8B5CF6)
                                                    : const Color(0xFF0284C7))
                                                .withAlpha(65),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            widget.assignment.isGroup
                                                ? Icons.groups_rounded
                                                : Icons.person_rounded,
                                            color: Colors.white,
                                            size: 15,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            widget.assignment.isGroup ? 'Tugas Kelompok' : 'Tugas Individu',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (widget.assignment.isGroup) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEDE9FE),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0xFFDDD6FE)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.people_outline_rounded,
                                                size: 13, color: Color(0xFF6D28D9)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Maks. ${widget.assignment.maxGroupMembers} Siswa/Tim',
                                              style: GoogleFonts.outfit(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF6D28D9),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                // Deadline Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
                                  decoration: BoxDecoration(
                                    color: isOverdue ? const Color(0xFFFFF1F2) : const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isOverdue ? const Color(0xFFFECDD3) : const Color(0xFFFDE68A),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.alarm_rounded,
                                        size: 14,
                                        color: isOverdue ? const Color(0xFFE11D48) : const Color(0xFFD97706),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Deadline: ${AppDateFormatter.formatDate(widget.assignment.deadline)}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isOverdue ? const Color(0xFFBE123C) : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // 2. Assignment Title
                            Text(
                              widget.assignment.title,
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.4,
                              ),
                            ),

                            // 3. Description
                            if (widget.assignment.description.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                widget.assignment.description,
                                style: GoogleFonts.outfit(
                                  fontSize: 13.5,
                                  color: const Color(0xFF475569),
                                  height: 1.55,
                                ),
                              ),
                            ],

                            // 4. Group System Highlight Info (if group)
                            if (widget.assignment.isGroup) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F3FF),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFDDD6FE)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6).withAlpha(35),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.info_outline_rounded,
                                        color: Color(0xFF6D28D9),
                                        size: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Kolaborasi Kelompok: Cukup 1 siswa yang mengumpulkan tugas mewakili tim. Seluruh anggota kelompok otomatis terdata dan mendapatkan nilai yang sama dari guru.',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF5B21B6),
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // 5. Allowed Formats Chips
                            if (widget.assignment.allowedSubmissionTypes.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Format Jawaban:',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  ...widget.assignment.allowedSubmissionTypes.map((t) {
                                    IconData iconData = Icons.file_present_rounded;
                                    Color chipColor = const Color(0xFF64748B);
                                    Color chipBg = const Color(0xFFF1F5F9);
                                    if (t == SubmissionType.pdf) {
                                      iconData = Icons.picture_as_pdf_rounded;
                                      chipColor = const Color(0xFFE11D48);
                                      chipBg = const Color(0xFFFFE4E6);
                                    } else if (t == SubmissionType.image) {
                                      iconData = Icons.image_rounded;
                                      chipColor = const Color(0xFF0284C7);
                                      chipBg = const Color(0xFFE0F2FE);
                                    } else if (t == SubmissionType.code) {
                                      iconData = Icons.code_rounded;
                                      chipColor = const Color(0xFF059669);
                                      chipBg = const Color(0xFFD1FAE5);
                                    } else if (t == SubmissionType.link) {
                                      iconData = Icons.link_rounded;
                                      chipColor = const Color(0xFF7C3AED);
                                      chipBg = const Color(0xFFEDE9FE);
                                    } else if (t == SubmissionType.text) {
                                      iconData = Icons.article_rounded;
                                      chipColor = const Color(0xFFD97706);
                                      chipBg = const Color(0xFFFEF3C7);
                                    }
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: chipBg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: chipColor.withAlpha(50)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(iconData, size: 12, color: chipColor),
                                          const SizedBox(width: 4),
                                          Text(
                                            t.label,
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: chipColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // IF TEACHER: Show list of submissions to review & grade
            if (isTeacher) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Daftar Pengumpulan (${filteredSubmissions.length} Siswa/Kelompok)',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _openSidikmuSync(context, filteredSubmissions),
                        icon: const Icon(Icons.cloud_sync_rounded, size: 16),
                        label: const Text('Sinkron SidikMu'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        onPressed: _exportExcel,
                        icon: const Icon(Icons.download, size: 18),
                        label: Text(
                          _submissionClassFilter == 'all' ? 'Unduh Excel' : 'Unduh Excel ($_submissionClassFilter)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Class Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          'Semua Kelas (${submissions.length})',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: _submissionClassFilter == 'all' ? FontWeight.bold : FontWeight.w500,
                            color: _submissionClassFilter == 'all' ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                        selected: _submissionClassFilter == 'all',
                        selectedColor: AppColors.primary,
                        backgroundColor: const Color(0xFFF1F5F9),
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _submissionClassFilter == 'all' ? AppColors.primary : Colors.transparent,
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _submissionClassFilter = 'all');
                          }
                        },
                      ),
                    ),
                    ...teacherClasses.map((cls) {
                      final isSelected = _submissionClassFilter == cls;
                      final count = submissions.where((s) {
                        final std = fbService.allStudents.firstWhere(
                          (u) => u.id == s.submitterId,
                          orElse: () => currentUserMock,
                        );
                        final c = std.className ?? std.classId ?? 'X-RPL-1';
                        return c == cls;
                      }).length;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            '$cls ($count)',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: const Color(0xFFF1F5F9),
                          showCheckmark: false,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : Colors.transparent,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _submissionClassFilter = cls);
                            }
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (filteredSubmissions.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 44, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        Text(
                          _submissionClassFilter == 'all'
                              ? 'Belum ada siswa yang mengumpulkan tugas ini.'
                              : 'Belum ada siswa kelas $_submissionClassFilter yang mengumpulkan.',
                          style: GoogleFonts.outfit(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredSubmissions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final sub = filteredSubmissions[index];
                    final student = fbService.allStudents.firstWhere(
                      (s) => s.id == sub.submitterId,
                      orElse: () => currentUserMock,
                    );
                    final studentClass = student.className ?? student.classId ?? 'X-RPL-1';
                    final studentNis = student.nis ?? 'NIS-000';

                    final isGroupSub = widget.assignment.isGroup ||
                        sub.groupName != null ||
                        sub.memberStudentIds.length > 1;

                    return Card(
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: isGroupSub
                              ? const Color(0xFFDDD6FE)
                              : AppColors.borderLight,
                          width: isGroupSub ? 1.2 : 1.0,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: isGroupSub
                              ? const LinearGradient(
                                  colors: [Colors.white, Color(0xFFFAF8FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: isGroupSub
                                        ? const LinearGradient(
                                            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : const LinearGradient(
                                            colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isGroupSub
                                                ? const Color(0xFF8B5CF6)
                                                : AppColors.orange)
                                            .withAlpha(50),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isGroupSub ? Icons.groups_rounded : Icons.person_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              sub.groupName ?? sub.submitterName,
                                              style: GoogleFonts.outfit(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15.5,
                                                color: const Color(0xFF0F172A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isGroupSub) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEDE9FE),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFDDD6FE)),
                                              ),
                                              child: Text(
                                                'TIM',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFF6D28D9),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withAlpha(15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.primary.withAlpha(40)),
                                            ),
                                            child: Text(
                                              'Kelas: $studentClass',
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: Text(
                                              'NIS: $studentNis',
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                          if (isGroupSub)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF3E8FF),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFE9D5FF)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.people_outline_rounded,
                                                      size: 11, color: Color(0xFF7C3AED)),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    '${sub.memberStudentIds.length} Siswa',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF7C3AED),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tipe: ${sub.type.label}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (sub.score != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD1FAE5),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFA7F3D0)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.check_circle_rounded,
                                                color: Color(0xFF059669), size: 13),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Nilai: ${sub.score!.toInt()}',
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFF065F46),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.orange,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => StudentSubmissionDetailDialog.show(
                                        context,
                                        submission: sub,
                                        assignment: widget.assignment,
                                        onGraded: () => setState(() {}),
                                      ),
                                      icon: const Icon(Icons.remove_red_eye_rounded, size: 15),
                                      label: Text(
                                        sub.score != null ? 'Buka Jawaban' : 'Buka & Nilai',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (sub.sourceCode != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.code, color: AppColors.emerald, size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Kompilasi Sukses (${sub.codeLanguage ?? "Code"})',
                                          style: const TextStyle(
                                            color: AppColors.emerald,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    SelectableText(
                                      sub.sourceCode!,
                                      maxLines: 4,
                                      style: GoogleFonts.firaCode(
                                        fontSize: 11,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (sub.pdfUrl != null && sub.pdfUrl!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Berkas PDF Siswa',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red.shade900,
                                            ),
                                          ),
                                          Text(
                                            sub.pdfUrl!.contains('/') ? sub.pdfUrl!.split('/').last.split('?').first : sub.pdfUrl!,
                                            style: GoogleFonts.outfit(fontSize: 11, color: Colors.red.shade800),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        visualDensity: VisualDensity.compact,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => SubmissionPdfViewerDialog.show(
                                        context,
                                        pdfUrl: sub.pdfUrl!,
                                        title: 'Berkas PDF - ${sub.submitterName}',
                                      ),
                                      icon: const Icon(Icons.fullscreen_rounded, size: 16),
                                      label: Text(
                                        'Preview PDF',
                                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (sub.imageUrls.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.image_rounded, color: AppColors.emerald, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Foto Tugas Siswa (${sub.imageUrls.length} Foto)',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF166534),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Ketuk untuk perbesar 🔍',
                                          style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF15803D)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: List.generate(sub.imageUrls.length, (imgIdx) {
                                        final img = sub.imageUrls[imgIdx];
                                        return InkWell(
                                          onTap: () => SubmissionImageViewerDialog.show(
                                            context,
                                            imageUrls: sub.imageUrls,
                                            initialIndex: imgIdx,
                                            title: 'Foto Tugas - ${sub.submitterName}',
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            width: 72,
                                            height: 72,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0xFF86EFAC)),
                                              color: Colors.white,
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                _buildThumbNetworkOrBase64(img),
                                                Positioned(
                                                  right: 4,
                                                  bottom: 4,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(3),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withAlpha(160),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 13),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (sub.linkUrl != null && sub.linkUrl!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.link_rounded, color: Colors.blue, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Tautan: ${sub.linkUrl!}',
                                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade900),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (sub.textContent != null && sub.textContent!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.article_rounded, color: Color(0xFF6366F1), size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Teks/Esai: ${sub.textContent!}',
                                        style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF334155)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ] else ...[
              // IF STUDENT: Check if student has already submitted
              if (mySub != null && !_isEditingSubmission) ...[
                Text(
                  'Status Pengumpulan Tugas Anda',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildMySubmissionCard(mySub),
              ] else if (widget.assignment.assignmentType == 'pilihan_ganda' || widget.assignment.questionIds.isNotEmpty) ...[
                Text(
                  'Kuis Pilihan Ganda',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildQuizSection(quizQuestions),
              ] else ...[
                // IF STUDENT: Regular Submission Form
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditingSubmission ? 'Kumpulkan Ulang / Perbarui Berkas' : 'Kumpulkan Tugas',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (_isEditingSubmission)
                      TextButton.icon(
                        onPressed: () => setState(() => _isEditingSubmission = false),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Batal'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // If group task: group formation
                if (widget.assignment.isGroup) ...[
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
                        const Row(
                          children: [
                            Icon(Icons.group, color: Colors.purple),
                            SizedBox(width: 8),
                            Text(
                              'Pengumpulan Kelompok',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Nama Kelompok',
                            hintText: 'Contoh: Kelompok Cyber Tech 1',
                          ),
                          onChanged: (val) => _groupName = val,
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final myClass = (currentUser?.className ?? currentUser?.classId ?? '').trim().toLowerCase();
                            final assignmentClasses = widget.assignment.classIds.map((c) => c.trim().toLowerCase()).toList();

                            // Filter classmates or assignment class students (excluding currentUser)
                            var candidateStudents = fbService.allStudents.where((s) {
                              if (s.id == currentUser?.id) return false;
                              final sClass = (s.className ?? s.classId ?? '').trim().toLowerCase();
                              if (assignmentClasses.isNotEmpty) {
                                return assignmentClasses.contains(sClass);
                              }
                              if (myClass.isNotEmpty) {
                                return sClass == myClass;
                              }
                              return true;
                            }).toList();

                            // Fallback if class matching has no members: show all other registered students
                            if (candidateStudents.isEmpty) {
                              candidateStudents = fbService.allStudents
                                  .where((s) => s.id != currentUser?.id)
                                  .toList();
                            }

                            // Siswa yang kelompoknya sudah mengumpulkan tidak dapat dipilih lagi
                            final alreadySubmittedStudentIds = submissions
                                .where((sub) => sub.assignmentId == widget.assignment.id)
                                .expand((sub) => [sub.submitterId, ...sub.memberStudentIds])
                                .toSet();

                            candidateStudents = candidateStudents
                                .where((s) => !alreadySubmittedStudentIds.contains(s.id))
                                .toList();

                            candidateStudents.sort(
                              (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
                            );

                            final maxSelectable = (widget.assignment.maxGroupMembers > 1)
                                ? widget.assignment.maxGroupMembers - 1
                                : 1;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Pilih anggota (Maks. ${widget.assignment.maxGroupMembers} anak):',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Terpilih: ${_selectedMemberIds.length}/$maxSelectable teman',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (candidateStudents.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.purple.shade100),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, size: 16, color: Colors.purple.shade400),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Belum ada data siswa lain yang terdaftar di Firebase.',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: candidateStudents.map((student) {
                                      final isSelected = _selectedMemberIds.contains(student.id);
                                      final displayName = student.fullName.isNotEmpty ? student.fullName : student.username;
                                      final nisText = (student.nis != null && student.nis!.isNotEmpty)
                                          ? ' (NIS ${student.nis})'
                                          : '';

                                      return FilterChip(
                                        avatar: CircleAvatar(
                                          radius: 12,
                                          backgroundColor: isSelected ? Colors.purple : Colors.purple.shade100,
                                          child: Text(
                                            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? Colors.white : Colors.purple.shade800,
                                            ),
                                          ),
                                        ),
                                        label: Text(
                                          '$displayName$nisText',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isSelected ? Colors.purple.shade900 : Colors.black87,
                                          ),
                                        ),
                                        selected: isSelected,
                                        selectedColor: Colors.purple.shade100,
                                        backgroundColor: Colors.white,
                                        checkmarkColor: Colors.purple,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: BorderSide(
                                            color: isSelected ? Colors.purple : Colors.grey.shade300,
                                          ),
                                        ),
                                        onSelected: (selected) {
                                          setState(() {
                                            if (selected) {
                                              if (_selectedMemberIds.length < maxSelectable) {
                                                _selectedMemberIds.add(student.id);
                                              } else {
                                                AppSnackBar.showError(
                                                  context,
                                                  'Maksimal anggota kelompok adalah ${widget.assignment.maxGroupMembers} orang (termasuk kamu).',
                                                );
                                              }
                                            } else {
                                              _selectedMemberIds.remove(student.id);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Submission format selector
                const Text('Pilih Metode Pengumpulan:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: widget.assignment.allowedSubmissionTypes.map((type) {
                    final isChosen = _selectedType == type;
                    return ChoiceChip(
                      label: Text(type.label),
                      selected: isChosen,
                      onSelected: (sel) {
                        if (sel) setState(() => _selectedType = type);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Submission Type Dynamic Inputs
                if (_selectedType == SubmissionType.code) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.terminal_rounded, color: AppColors.emerald),
                            SizedBox(width: 8),
                            Text(
                              'Tugas Koding Terintegrasi',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tulis kode Anda di Compiler Editor in-app, uji coba eksekusi sebelum mengumpulkan.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        if (_submittedCode != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.emerald),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: AppColors.emerald, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Kode Siap Dikumpulkan (${_codeLanguage ?? "Code"})',
                                      style: const TextStyle(
                                        color: AppColors.emerald,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SelectableText(
                                  _submittedCode!,
                                  maxLines: 4,
                                  style: GoogleFonts.firaCode(fontSize: 11, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _openCodeEditor,
                          icon: const Icon(Icons.edit_note_rounded),
                          label: Text(
                            _submittedCode != null
                                ? 'Buka & Edit Kembali di Compiler'
                                : 'Buka Compiler & Tulis Kode',
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_selectedType == SubmissionType.link) ...[
                  TextField(
                    controller: _linkController,
                    decoration: const InputDecoration(
                      labelText: 'URL / Tautan Tugas',
                      hintText: 'https://github.com/username/project...',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                ] else if (_selectedType == SubmissionType.text) ...[
                  TextField(
                    controller: _textController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Jawaban Tertulis',
                      hintText: 'Ketikkan analisis atau jawaban Anda disini...',
                    ),
                  ),
                ] else if (_selectedType == SubmissionType.pdf) ...[
                  if (_attachedPdfBytes != null || (_attachedPdfName != null && _attachedPdfName!.isNotEmpty)) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 28),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _attachedPdfName ?? 'Dokumen PDF',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: AppColors.emerald, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_formatFileSize(_attachedPdfSize ?? _attachedPdfBytes?.length ?? 0)} • Berkas PDF Siap Dikumpulkan',
                                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Hapus berkas ini',
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _attachedPdfName = null;
                                    _attachedPdfBytes = null;
                                    _attachedPdfSize = null;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _pickPdfFile,
                              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                              label: const Text('Ganti Berkas PDF Lain dari HP'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    InkWell(
                      onTap: _pickPdfFile,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.upload_file_rounded, color: Colors.red, size: 32),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Pilih Berkas PDF dari HP / Perangkat',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sentuh di sini untuk membuka dokumen PDF di HP Anda (Maksimal 10MB)',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _pickPdfFile,
                              icon: const Icon(Icons.folder_open_rounded, size: 18),
                              label: const Text('Buka Dokumen HP'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ] else if (_selectedType == SubmissionType.image) ...[
                  if (_attachedImageBytes != null || (_attachedImageName != null && _attachedImageName!.isNotEmpty)) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _attachedImageBytes != null
                                    ? Image.memory(
                                        _attachedImageBytes!,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 56,
                                        height: 56,
                                        color: Colors.green.shade50,
                                        child: const Icon(Icons.image, color: Colors.green),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _attachedImageName ?? 'Foto Tugas',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: AppColors.emerald, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_formatFileSize(_attachedImageSize ?? _attachedImageBytes?.length ?? 0)} • Foto Siap Dikumpulkan',
                                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Hapus foto ini',
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _attachedImageName = null;
                                    _attachedImageBytes = null;
                                    _attachedImageSize = null;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (_attachedImageBytes != null) ...[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => _previewImageDialog(
                                      _attachedImageBytes!,
                                      _attachedImageName ?? 'Foto Lembar Tugas',
                                    ),
                                    icon: const Icon(Icons.visibility_outlined, size: 18),
                                    label: const Text('Lihat Foto'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                                  label: const Text('Ganti Foto'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_a_photo_rounded, color: Colors.green, size: 32),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Pilih Foto Tugas dari HP',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ambil foto lembar jawaban langsung lewat kamera atau pilih dari galeri foto HP',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _pickImageDirect(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                                  label: const Text('Kamera HP'),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _pickImageDirect(ImageSource.gallery),
                                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                                  label: const Text('Galeri HP'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      disabledBackgroundColor: Colors.grey.shade400,
                    ),
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    child: _isSubmitting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Mengunggah & Mengumpulkan...',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          )
                        : const Text(
                            'Kumpulkan Tugas Sekarang (Dapatkan +50 Poin)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    ),
  );
  }


  Widget _buildMySubmissionCard(AssignmentSubmissionModel sub) {
    final fbService = context.watch<FirebaseService>();
    final currentUser = fbService.currentUser;
    final hasScore = sub.score != null;
    final isGroup = sub.groupId != null || sub.memberStudentIds.length > 1;
    final isSubmitter = currentUser?.id == sub.submitterId;

    // Resolve group members
    final List<UserModel> groupMembers = [];
    if (isGroup && sub.memberStudentIds.isNotEmpty) {
      for (final mid in sub.memberStudentIds) {
        final st = fbService.allStudents.where((u) => u.id == mid).firstOrNull;
        if (st != null && !groupMembers.any((m) => m.id == st.id)) {
          groupMembers.add(st);
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasScore ? const Color(0xFF10B981).withAlpha(80) : const Color(0xFFF59E0B).withAlpha(80),
        ),
        boxShadow: [
          BoxShadow(
            color: (hasScore ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withAlpha(15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner khusus jika tugas kelompok telah dikumpulkan oleh teman
          if (isGroup && !isSubmitter) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.people_alt_rounded, color: Color(0xFF16A34A), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tugas Kelompok Sudah Dikumpulkan Rekan Anda',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Tugas kelompok "${sub.groupName ?? 'Kelompok'}" ini telah dikumpulkan oleh teman kelompokmu (${sub.submitterName}). '
                          'Anda dan anggota kelompok lainnya tidak perlu mengumpulkan lagi. '
                          'Nilai yang diberikan guru akan otomatis berlaku sama untuk seluruh anggota kelompok.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFF166534),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasScore ? const Color(0xFF10B981).withAlpha(20) : const Color(0xFFF59E0B).withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasScore ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                  color: hasScore ? const Color(0xFF10B981) : const Color(0xFFD97706),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasScore ? 'Tugas Selesai & Dinilai! 🎉' : 'Tugas Sudah Dikumpulkan! ⏳',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: hasScore ? const Color(0xFF047857) : const Color(0xFFB45309),
                      ),
                    ),
                    Text(
                      'Dikumpulkan: ${AppDateFormatter.formatFullDateTime(sub.submittedAt)} • Oleh: ${sub.submitterName}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasScore) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGroup ? 'NILAI KELOMPOK (BERLAKU SAMA SATU KELOMPOK)' : 'NILAI DIPEROLEH',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${sub.score!.round()}',
                            style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w900, color: const Color(0xFF047857)),
                          ),
                          const SizedBox(width: 4),
                          Text('/ 100', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      sub.score! >= 75 ? 'TUNTAS (LULUS)' : 'PERLU PERBAIKAN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: sub.score! >= 75 ? const Color(0xFF047857) : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (sub.teacherFeedback != null && sub.teacherFeedback!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Umpan Balik Guru:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Text(sub.teacherFeedback!, style: const TextStyle(fontSize: 12.5, color: Colors.black87)),
                  ],
                ),
              ),
            ],
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tugas Anda telah diterima dan saat ini sedang menunggu evaluasi serta penilaian oleh guru.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isGroup && groupMembers.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.group_rounded, size: 16, color: Colors.purple),
                      const SizedBox(width: 6),
                      Text(
                        'Anggota Kelompok: ${sub.groupName ?? "Kelompok"} (${groupMembers.length} Siswa)',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: Colors.purple.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: groupMembers.map((m) {
                      final isLeader = m.id == sub.submitterId;
                      final isMe = m.id == currentUser?.id;
                      return Chip(
                        avatar: Icon(
                          isLeader ? Icons.star_rounded : (isMe ? Icons.check_circle_rounded : Icons.person_outline_rounded),
                          size: 14,
                          color: isLeader ? Colors.amber.shade800 : (isMe ? Colors.green.shade700 : Colors.purple.shade700),
                        ),
                        label: Text(
                          '${m.fullName}${isLeader ? " (Pengunggah)" : ""}${isMe && !isLeader ? " (Anda)" : ""}',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        backgroundColor: isMe ? Colors.green.shade50 : (isLeader ? Colors.amber.shade50 : Colors.white),
                        side: BorderSide(
                          color: isMe ? Colors.green.shade300 : (isLeader ? Colors.amber.shade300 : Colors.purple.shade200),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ] else if (sub.groupName != null) ...[
            const SizedBox(height: 12),
            Text('Kelompok: ${sub.groupName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
          if (sub.pdfUrl != null && sub.pdfUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            SubmissionPdfPreviewCard(
              pdfUrl: sub.pdfUrl!,
              title: 'Berkas PDF Tugas Saya',
            ),
          ],
          if (sub.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            SubmissionImageGalleryGrid(
              imageUrls: sub.imageUrls,
              title: 'Foto Tugas Saya',
            ),
          ],
          if (sub.textContent != null) ...[
            const SizedBox(height: 12),
            const Text('Keterangan Pengumpulan:', style: TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(sub.textContent!, style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: const [
                Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF475569)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tugas / Kuis ini sudah selesai dikerjakan dan tidak dapat dikerjakan ulang.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (!hasScore) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  setState(() {
                    _selectedType = sub.type;
                    _linkController.text = sub.linkUrl ?? '';
                    _textController.text = sub.textContent ?? '';
                    _submittedCode = sub.sourceCode;
                    _codeLanguage = sub.codeLanguage ?? 'python';
                    _attachedPdfName = null;
                    _attachedPdfBytes = null;
                    _attachedImageName = null;
                    _attachedImageBytes = null;
                    _isEditingSubmission = true;
                  });
                },
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                label: const Text(
                  'Kumpulkan Ulang / Perbarui Berkas Tugas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuizSection(List<QuestionModel> questions) {
    if (questions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: const Center(
          child: Text('Belum ada butir soal pada kuis pilihan ganda ini.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'KUIS PILIHAN GANDA (${questions.length} SOAL)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            const Spacer(),
            const Text(
              '⚡ Nilai Langsung Otomatis',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF047857), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: questions.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (ctx, index) {
            final q = questions[index];
            final selectedAns = _quizAnswers[q.id];

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
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
                          'Soal #${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        q.type.label,
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    q.content,
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 14),

                  // Render options
                  if (q.type == QuestionType.trueFalse) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: selectedAns == true ? const Color(0xFF10B981).withAlpha(25) : Colors.transparent,
                              side: BorderSide(
                                color: selectedAns == true ? const Color(0xFF10B981) : AppColors.borderLight,
                                width: selectedAns == true ? 2 : 1,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              setState(() => _quizAnswers[q.id] = true);
                            },
                            child: const Text('BENAR', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: selectedAns == false ? const Color(0xFFEF4444).withAlpha(25) : Colors.transparent,
                              side: BorderSide(
                                color: selectedAns == false ? const Color(0xFFEF4444) : AppColors.borderLight,
                                width: selectedAns == false ? 2 : 1,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              setState(() => _quizAnswers[q.id] = false);
                            },
                            child: const Text('SALAH', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Multiple / Single choice options
                    ...q.options.map((opt) {
                      final optKey = opt.id;
                      final optText = opt.text;
                      final isChosen = selectedAns?.toString() == optKey.toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isChosen ? AppColors.primaryLight.withAlpha(12) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isChosen ? AppColors.primaryLight : AppColors.borderLight,
                            width: isChosen ? 1.5 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() => _quizAnswers[q.id] = optKey);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isChosen ? AppColors.primaryLight : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isChosen ? AppColors.primaryLight : Colors.grey.shade400,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      optKey.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isChosen ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    optText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isChosen ? FontWeight.w700 : FontWeight.normal,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _handleQuizSubmit(questions),
            icon: const Icon(Icons.rocket_launch_rounded),
            label: const Text(
              'Kumpulkan Kuis & Nilai Langsung 🚀',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbNetworkOrBase64(String url) {
    if (url.startsWith('data:image')) {
      try {
        final commaIdx = url.indexOf(',');
        final base64Str = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 20, color: Colors.grey),
        );
      } catch (_) {
        return const Icon(Icons.broken_image, size: 20, color: Colors.grey);
      }
    } else if (url.startsWith('firestore://')) {
      final cached = FirebaseService.getCachedFileBytes(url);
      if (cached != null) {
        return Image.memory(cached, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 20, color: Colors.grey));
      }
      return FutureBuilder<Uint8List>(
        future: FirebaseService().resolveFileBytes(url),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)));
          }
          if (snap.hasError || !snap.hasData) {
            return const Icon(Icons.broken_image, size: 20, color: Colors.grey);
          }
          return Image.memory(snap.data!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 20, color: Colors.grey));
        },
      );
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 20, color: Colors.grey),
      );
    }
    return const Icon(Icons.image, size: 20, color: Colors.grey);
  }
}
