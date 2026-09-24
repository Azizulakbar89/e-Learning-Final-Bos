import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/exam_model.dart';
import '../../../core/services/excel_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/curved_header_card.dart';
import '../widgets/duplicate_exam_dialog.dart';
import 'essay_grading_screen.dart';
import 'exam_form_screen.dart';
import '../../teacher_tools/widgets/sidikmu_sync_dialog.dart';

class TeacherExamMonitorScreen extends StatefulWidget {
  final ExamModel exam;

  const TeacherExamMonitorScreen({super.key, required this.exam});

  @override
  State<TeacherExamMonitorScreen> createState() => _TeacherExamMonitorScreenState();
}

class _TeacherExamMonitorScreenState extends State<TeacherExamMonitorScreen> {
  String _selectedClassFilter = 'all';

  void _exportExcel(
    BuildContext context,
    ExamModel currentExam,
    List<ExamSessionModel> sessions, {
    String? targetClass,
  }) async {
    final records = sessions.map((s) {
      return {
        'nis': s.studentNis,
        'score': s.finalScore ?? s.nonEssayScore ?? 0,
      };
    }).toList();

    final classesForFileName = targetClass != null ? [targetClass] : currentExam.classIds;
    final fileName = ExcelService.buildExcelFileName(
      title: currentExam.title,
      classes: classesForFileName,
    );

    final bytes = ExcelService.generateNisAndScoreExcel(
      sheetTitle: 'Nilai Ujian',
      records: records,
    );

    await ExcelService.downloadExcel(bytes: bytes, fileName: fileName);

    if (context.mounted) {
      AppSnackBar.success(
        context,
        'Berkas Excel "$fileName" berhasil diunduh (${bytes.length} bytes). Berisi kolom NIS & NILAI saja.',
      );
    }
  }

  void _promptDownloadExcel(BuildContext context, ExamModel currentExam, List<ExamSessionModel> allSessions) {
    final classes = currentExam.classIds;
    if (classes.length <= 1) {
      _exportExcel(context, currentExam, allSessions, targetClass: classes.firstOrNull);
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.file_download_outlined, color: AppColors.orange, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pilih Unduh Nilai Excel',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
                          ),
                          Text(
                            'Hanya kolom NIS & NILAI sesuai format resmi',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.table_view_rounded, color: AppColors.navy),
                  ),
                  title: const Text('Unduh Gabungan Semua Kelas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${classes.join(", ")} • Total ${allSessions.length} siswa'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportExcel(context, currentExam, allSessions);
                  },
                ),
                const Divider(),
                ...classes.map((cls) {
                  final classSessions = allSessions
                      .where((s) => s.studentClass.trim().toLowerCase() == cls.trim().toLowerCase())
                      .toList();
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.school_rounded, color: AppColors.primary),
                    ),
                    title: Text('Unduh Khusus Kelas $cls', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('${classSessions.length} siswa telah mengerjakan'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(ctx);
                      _exportExcel(context, currentExam, classSessions, targetClass: cls);
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSidikmuSumatifSync(
    BuildContext context,
    ExamModel currentExam,
    List<ExamSessionModel> sessions,
  ) {
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
    if (_selectedClassFilter != 'all') {
      targetClass = _selectedClassFilter;
    } else if (currentExam.classIds.isNotEmpty) {
      final cid = currentExam.classIds.first;
      targetClass = fb.schoolClasses.where((c) => c.id == cid).firstOrNull?.name ?? cid;
    }

    // Determine subject
    final subject = fb.subjects.where((s) => s.id == currentExam.subjectId).firstOrNull;
    final subjectName = subject?.name ?? 'Informatika';

    // Map student NIS to scores
    final studentGradesByNis = <String, double?>{};
    final studentNamesByNis = <String, String>{};

    // Pre-populate with all students in this class so missing ones are properly tracked
    final classStudents = fb.allStudents.where((s) {
      final sClass = (s.className ?? s.classId ?? '').trim().toLowerCase();
      if (targetClass.isEmpty || targetClass.toLowerCase() == 'semua kelas') return true;
      return sClass == targetClass.toLowerCase() ||
          (s.classId != null && s.classId!.toLowerCase() == targetClass.toLowerCase()) ||
          (s.className != null && targetClass.toLowerCase().contains(s.className!.toLowerCase())) ||
          (s.className != null && s.className!.toLowerCase().contains(targetClass.toLowerCase()));
    }).toList();

    for (final s in classStudents) {
      final nis = (s.nis ?? '').trim();
      if (nis.isNotEmpty) {
        studentGradesByNis[nis] = 0.0;
        studentNamesByNis[nis] = s.fullName;
      }
    }

    // Fill with exam session scores
    for (final session in sessions) {
      if (_selectedClassFilter != 'all' &&
          session.studentClass.trim().toLowerCase() != _selectedClassFilter.trim().toLowerCase()) {
        continue;
      }
      final nis = session.studentNis.trim();
      if (nis.isNotEmpty) {
        final score = session.finalScore ?? session.nonEssayScore ?? 0.0;
        studentGradesByNis[nis] = score;
        studentNamesByNis[nis] = session.studentName;
      }
    }

    SidikmuSyncDialog.show(
      context,
      isFormatif: false,
      targetClassName: targetClass.isNotEmpty ? targetClass : 'Semua Kelas',
      targetSubjectName: subjectName,
      examTitle: currentExam.title,
      examId: currentExam.id,
      studentGradesByNis: studentGradesByNis,
      studentNamesByNis: studentNamesByNis,
    );
  }

  void _confirmDeleteExam(BuildContext context, FirebaseService fb, ExamModel currentExam) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Hapus Ujian?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Ujian "${currentExam.title}" beserta seluruh sesi ujian siswa yang terkait akan dihapus secara permanen.',
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.outfit()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context); // close dialog
              final success = await showLoadingDialog(
                context,
                message: 'Menghapus jadwal ujian...',
                action: () async {
                  await fb.deleteExam(currentExam.id);
                },
                successMessage: 'Ujian berhasil dihapus.',
                errorMessage: 'Gagal menghapus ujian. Silakan coba lagi.',
              );
              if (success && context.mounted) {
                Navigator.pop(context); // leave monitor screen
              }
            },
            child: Text('Hapus', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final currentUser = fb.currentUser;
    final isTeacher = currentUser?.isGuru ?? false;
    final currentExam = fb.exams.firstWhere((e) => e.id == widget.exam.id, orElse: () => widget.exam);

    // Pembatas ketat: Guru yang bisa memonitor HANYA guru yang membuat ujian tersebut
    final isAuthorized = !isTeacher ||
        (currentUser?.isAdmin ?? false) ||
        (currentExam.teacherId.isNotEmpty && currentExam.teacherId == currentUser?.id);

    if (!isAuthorized) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
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
                    'Akses Monitoring Dibatasi',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hanya guru yang membuat ujian ini yang dapat melihat dan memonitor sesi ujian siswa secara langsung.',
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final allSessions = fb.examSessions
        .where((s) => s.examId == widget.exam.id)
        .toList();

    // Filter sessions by selected class
    final displayedSessions = _selectedClassFilter == 'all'
        ? allSessions
        : allSessions
            .where((s) => s.studentClass.trim().toLowerCase() == _selectedClassFilter.trim().toLowerCase())
            .toList();

    final classes = currentExam.classIds;

    final examSubject = fb.subjects.where((s) => s.id == currentExam.subjectId).firstOrNull;
    final kkm = examSubject?.kkm ?? 75.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CurvedHeaderCard(
              title: 'Ruang Pantau: ${currentExam.title}',
              subtitle: '${currentExam.category.fullLabel} • Pantau Nilai, Integritas & Sesi Siswa',
              actions: [
                IconButton(
                  tooltip: 'Sinkronkan Nilai ke SidikMu (Sumatif)',
                  icon: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF38BDF8), size: 22),
                  onPressed: () => _openSidikmuSumatifSync(context, currentExam, allSessions),
                ),
                IconButton(
                  tooltip: 'Download Excel Nilai Ujian',
                  icon: const Icon(Icons.file_download_outlined, color: Colors.white, size: 20),
                  onPressed: () => _promptDownloadExcel(context, currentExam, allSessions),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
                  tooltip: 'Menu Opsi Ujian',
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (value) {
                    if (value == 'duplicate') {
                      DuplicateExamDialog.show(context, currentExam);
                    } else if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExamFormScreen(
                            subjectId: currentExam.subjectId,
                            existingExam: currentExam,
                          ),
                        ),
                      );
                    } else if (value == 'delete') {
                      _confirmDeleteExam(context, fb, currentExam);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy_rounded, color: Color(0xFFF97316), size: 18),
                          SizedBox(width: 10),
                          Text('Duplikat ke Kelas Lain', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, color: Color(0xFF0284C7), size: 18),
                          SizedBox(width: 10),
                          Text('Edit Pengaturan Ujian', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                          SizedBox(width: 10),
                          Text('Hapus Jadwal Ujian', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Control Bar: Toggle Anti-Cheat
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: currentExam.antiCheatEnabled ? const Color(0xFFFFF1F2) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: currentExam.antiCheatEnabled ? const Color(0xFFFECDD3) : AppColors.borderLight,
                  width: currentExam.antiCheatEnabled ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (currentExam.antiCheatEnabled ? Colors.red : Colors.black).withAlpha(8),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: currentExam.antiCheatEnabled ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      currentExam.antiCheatEnabled ? Icons.shield_rounded : Icons.shield_outlined,
                      color: currentExam.antiCheatEnabled ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                      size: 20,
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
                                'Zero-Tolerance Anti-Cheat',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: currentExam.antiCheatEnabled ? const Color(0xFF9F1239) : const Color(0xFF1E293B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: currentExam.antiCheatEnabled ? const Color(0xFFE11D48) : const Color(0xFF94A3B8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                currentExam.antiCheatEnabled ? 'AKTIF' : 'NONAKTIF',
                                style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentExam.antiCheatEnabled
                              ? 'Kunci layar otomatis saat siswa berpindah tab/aplikasi.'
                              : 'Deteksi kecurangan dinonaktifkan sementara.',
                          style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: currentExam.antiCheatEnabled,
                      activeTrackColor: const Color(0xFFE11D48),
                      activeThumbColor: Colors.white,
                      onChanged: (val) {
                        fb.toggleExamAntiCheat(currentExam.id, val);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Class Filter Bar
            if (classes.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 2, 14, 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      'Filter Kelas:',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: Text('Semua (${allSessions.length})'),
                              selected: _selectedClassFilter == 'all',
                              selectedColor: AppColors.primary.withAlpha(30),
                              labelStyle: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: _selectedClassFilter == 'all' ? FontWeight.bold : FontWeight.w500,
                                color: _selectedClassFilter == 'all' ? AppColors.primary : const Color(0xFF475569),
                              ),
                              onSelected: (selected) {
                                if (selected) setState(() => _selectedClassFilter = 'all');
                              },
                            ),
                            const SizedBox(width: 6),
                            ...classes.map((cls) {
                              final count = allSessions
                                  .where((s) => s.studentClass.trim().toLowerCase() == cls.trim().toLowerCase())
                                  .length;
                              final isSel = _selectedClassFilter.toLowerCase() == cls.toLowerCase();
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text('$cls ($count)'),
                                  selected: isSel,
                                  selectedColor: AppColors.primary.withAlpha(30),
                                  labelStyle: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                    color: isSel ? AppColors.primary : const Color(0xFF475569),
                                  ),
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedClassFilter = selected ? cls : 'all';
                                    });
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Statistics Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatBadge(
                      label: _selectedClassFilter == 'all' ? 'Total Peserta' : 'Peserta ($_selectedClassFilter)',
                      value: '${displayedSessions.length}',
                      color: AppColors.primary,
                      icon: Icons.people_alt_rounded,
                    ),
                    const SizedBox(width: 8),
                    _buildStatBadge(
                      label: 'KKM Mapel',
                      value: kkm.toStringAsFixed(0),
                      color: const Color(0xFFF97316),
                      icon: Icons.flag_rounded,
                    ),
                    const SizedBox(width: 8),
                    _buildStatBadge(
                      label: 'Tuntas KKM',
                      value: '${displayedSessions.where((s) => (s.finalScore ?? s.nonEssayScore ?? 0) >= kkm && s.isCompleted).length}',
                      color: const Color(0xFF10B981),
                      icon: Icons.check_circle_rounded,
                    ),
                    const SizedBox(width: 8),
                    _buildStatBadge(
                      label: 'Terkunci 🚨',
                      value: '${displayedSessions.where((s) => s.isLocked).length}',
                      color: const Color(0xFFEF4444),
                      icon: Icons.lock_rounded,
                    ),
                    const SizedBox(width: 8),
                    _buildStatBadge(
                      label: 'Selesai 📝',
                      value: '${displayedSessions.where((s) => s.isCompleted).length}',
                      color: const Color(0xFF6366F1),
                      icon: Icons.assignment_turned_in_rounded,
                    ),
                  ],
                ),
              ),
            ),

            // Real-time Student Sessions Grid
            Expanded(
              child: displayedSessions.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          constraints: const BoxConstraints(maxWidth: 420),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.borderLight),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(8),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(20),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.sensors_rounded,
                                  size: 40,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Ruang Pantau Siaga',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedClassFilter == 'all'
                                    ? 'Belum ada siswa yang mulai mengerjakan "${currentExam.title}". Progres jawaban, skor, dan status integritas anti-cheat akan muncul otomatis secara real-time di sini.'
                                    : 'Belum ada siswa dari kelas $_selectedClassFilter yang memulai ujian ini.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.school_rounded, size: 14, color: Color(0xFF475569)),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Target Kelas: ${classes.join(", ")}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF475569),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 56),
                      itemCount: displayedSessions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final s = displayedSessions[index];
                        return Card(
                          elevation: s.isLocked ? 3 : 1,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: s.isLocked ? const Color(0xFFEF4444) : AppColors.borderLight,
                              width: s.isLocked ? 1.8 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: s.isLocked
                                          ? const Color(0xFFFEE2E2)
                                          : AppColors.primary.withAlpha(20),
                                      child: Icon(
                                        s.isLocked ? Icons.lock_rounded : Icons.person_rounded,
                                        color: s.isLocked ? const Color(0xFFDC2626) : AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.studentName,
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          Text(
                                            'NIS: ${s.studentNis} • Kelas: ${s.studentClass}',
                                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _buildStatusChip(s),
                                  ],
                                ),

                                if (s.isLocked) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF1F2),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFFECDD3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Pelanggaran (${s.violationCount}x): ${s.lastViolationReason ?? "Pindah aplikasi / layar"}',
                                            style: const TextStyle(color: Color(0xFF9F1239), fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 12),
                                // Live Answer Progress Bar
                                Row(
                                  children: [
                                    Text(
                                      'Jawaban Terisi: ${s.answers.length}/${currentExam.questionIds.length}',
                                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                                    ),
                                    const Spacer(),
                                    if (s.finalScore != null) ...[
                                      Builder(builder: (_) {
                                        final scoreVal = s.finalScore!;
                                        final isTuntas = scoreVal >= kkm;
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isTuntas ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: isTuntas ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
                                          ),
                                          child: Text(
                                            'Nilai: ${scoreVal.toStringAsFixed(1)} (${isTuntas ? "Tuntas" : "Remedial"})',
                                            style: TextStyle(
                                              color: isTuntas ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ],
                                ),
                                const Divider(height: 20),

                                // Teacher Quick Control Buttons
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (s.isLocked)
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFFF97316),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.lock_open_rounded, size: 16),
                                        label: const Text('Buka Blokir (Unblock)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        onPressed: () => fb.unblockExamSession(s.id),
                                      ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        foregroundColor: s.antiCheatDisabledForStudent
                                            ? AppColors.navy
                                            : const Color(0xFFEA580C),
                                        side: BorderSide(
                                          color: s.antiCheatDisabledForStudent
                                              ? AppColors.navy
                                              : const Color(0xFFEA580C).withAlpha(120),
                                        ),
                                      ),
                                      icon: Icon(
                                        s.antiCheatDisabledForStudent
                                            ? Icons.shield_outlined
                                            : Icons.gpp_bad_outlined,
                                        size: 15,
                                      ),
                                      label: Text(
                                        s.antiCheatDisabledForStudent
                                            ? 'Cheat: Nonaktif'
                                            : 'Bebaskan Cheat Siswa',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                      ),
                                      onPressed: () {
                                        final newStatus = !s.antiCheatDisabledForStudent;
                                        fb.toggleStudentAntiCheat(s.id, newStatus);
                                        if (newStatus) {
                                          AppSnackBar.warning(
                                            context,
                                            'Anti-Cheat DINONAKTIFKAN khusus untuk ${s.studentName}. Siswa bebas bernavigasi tanpa penguncian.',
                                          );
                                        } else {
                                          AppSnackBar.info(
                                            context,
                                            'Anti-Cheat DIAKTIFKAN kembali untuk ${s.studentName}.',
                                          );
                                        }
                                      },
                                    ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.refresh_rounded, size: 15),
                                      label: const Text('Refresh Cache', style: TextStyle(fontSize: 11.5)),
                                      onPressed: () {
                                        fb.clearExamSessionCache(s.id);
                                        AppSnackBar.info(
                                          context,
                                          'Cache sesi siswa disegarkan. Jawaban tetap tersimpan utuh.',
                                        );
                                      },
                                    ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFEF4444),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.restart_alt_rounded, size: 15),
                                      label: const Text('Reset Jawaban', style: TextStyle(fontSize: 11.5)),
                                      onPressed: () => _confirmReset(context, fb, s),
                                    ),
                                    if (s.isCompleted)
                                      FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.rate_review_outlined, size: 15),
                                        label: const Text('Nilai Esai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => EssayGradingScreen(exam: currentExam, session: s),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
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

  Widget _buildStatBadge({
    required String label,
    required String value,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 105),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(50)),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
              ],
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ExamSessionModel s) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (s.antiCheatDisabledForStudent) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 12, color: Color(0xFFB45309)),
                SizedBox(width: 4),
                Text(
                  'Bebas Cheat',
                  style: TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (s.isLocked)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.orangeDark, borderRadius: BorderRadius.circular(20)),
            child: const Text('TERKUNCI 🚨', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          )
        else if (s.isCompleted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(20)),
            child: const Text('SELESAI', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.orange.withAlpha(25), borderRadius: BorderRadius.circular(20)),
            child: const Text('Mengerjakan', style: TextStyle(color: AppColors.orangeDark, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  void _confirmReset(BuildContext context, FirebaseService fb, ExamSessionModel s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Konfirmasi Reset Jawaban'),
        content: Text('Apakah Anda yakin ingin mereset seluruh jawaban siswa ${s.studentName}? Siswa akan mengulang ujian dari awal.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () {
              fb.resetExamSession(s.id);
              Navigator.pop(context);
              AppSnackBar.error(
                context,
                'Lembar jawaban berhasil di-reset.',
              );
            },
            child: const Text('Ya, Reset Jawaban'),
          ),
        ],
      ),
    );
  }
}
