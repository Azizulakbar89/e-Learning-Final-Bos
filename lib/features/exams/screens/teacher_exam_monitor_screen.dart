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
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CurvedHeaderCard(
              title: 'Ruang Pantau: ${currentExam.title}',
              subtitle: 'Pantau Nilai, Integritas, dan Sesi Live Ujian',
              actions: [
                IconButton(
                  tooltip: 'Download Excel Nilai Ujian (Pilihan Per Kelas)',
                  icon: const Icon(Icons.file_download_outlined, color: Colors.white, size: 20),
                  onPressed: () => _promptDownloadExcel(context, currentExam, allSessions),
                ),
                IconButton(
                  tooltip: 'Duplikat Ujian ke Kelas Lain',
                  icon: const Icon(Icons.copy_rounded, color: AppColors.orange, size: 20),
                  onPressed: () => DuplicateExamDialog.show(context, currentExam),
                ),
                IconButton(
                  tooltip: 'Edit Ujian Ini',
                  icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExamFormScreen(
                        subjectId: currentExam.subjectId,
                        existingExam: currentExam,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus Ujian Ini',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  onPressed: () => _confirmDeleteExam(context, fb, currentExam),
                ),
              ],
            ),
          // Control Bar: Toggle Anti-Cheat
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: currentExam.antiCheatEnabled ? Colors.red.shade50 : Colors.grey.shade100,
            child: Row(
              children: [
                Icon(
                  currentExam.antiCheatEnabled ? Icons.security_rounded : Icons.shield_outlined,
                  color: currentExam.antiCheatEnabled ? Colors.red.shade800 : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sistem Deteksi Kecurangan (Zero-Tolerance Anti-Cheat)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: currentExam.antiCheatEnabled ? Colors.red.shade900 : Colors.black87,
                        ),
                      ),
                      Text(
                        currentExam.antiCheatEnabled
                            ? 'Mode Ketat Aktif: Pindah aplikasi / notifikasi ditarik otomatis mengunci siswa.'
                            : 'Mode Bebas: Deteksi kecurangan dinonaktifkan sementara.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: currentExam.antiCheatEnabled,
                  activeThumbColor: AppColors.rose,
                  onChanged: (val) {
                    fb.toggleExamAntiCheat(currentExam.id, val);
                  },
                ),
              ],
            ),
          ),

          // Class Filter Bar
          if (classes.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_list_rounded, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Kelas:',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text('Semua Kelas (${allSessions.length})'),
                            selected: _selectedClassFilter == 'all',
                            selectedColor: AppColors.primary.withAlpha(35),
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
                                selectedColor: AppColors.primary.withAlpha(35),
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
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatBadge(
                    label: _selectedClassFilter == 'all' ? 'Total Peserta' : 'Peserta ($_selectedClassFilter)',
                    value: '${displayedSessions.length}',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  _buildStatBadge(
                    label: 'KKM Mapel',
                    value: kkm.toStringAsFixed(0),
                    color: AppColors.orange,
                  ),
                  const SizedBox(width: 10),
                  _buildStatBadge(
                    label: 'Tuntas KKM ✅',
                    value: '${displayedSessions.where((s) => (s.finalScore ?? s.nonEssayScore ?? 0) >= kkm && s.isCompleted).length}',
                    color: Colors.green,
                  ),
                  const SizedBox(width: 10),
                  _buildStatBadge(
                    label: 'Terkunci 🚨',
                    value: '${displayedSessions.where((s) => s.isLocked).length}',
                    color: AppColors.rose,
                  ),
                  const SizedBox(width: 10),
                  _buildStatBadge(
                    label: 'Selesai 📝',
                    value: '${displayedSessions.where((s) => s.isCompleted).length}',
                    color: AppColors.navy,
                  ),
                ],
              ),
            ),
          ),

          // Real-time Student Sessions Grid
          Expanded(
            child: displayedSessions.isEmpty
                ? Center(
                    child: Text(
                      _selectedClassFilter == 'all'
                          ? 'Belum ada siswa yang memulai ujian ini.'
                          : 'Belum ada siswa kelas $_selectedClassFilter yang memulai ujian ini.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 56),
                    itemCount: displayedSessions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final s = displayedSessions[index];
                      return Card(
                        elevation: s.isLocked ? 3 : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: s.isLocked ? AppColors.orangeDark : AppColors.borderLight,
                            width: s.isLocked ? 2 : 1,
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
                                        ? AppColors.orangeDark.withAlpha(30)
                                        : AppColors.navy.withAlpha(20),
                                    child: Icon(
                                      s.isLocked ? Icons.lock : Icons.person,
                                      color: s.isLocked ? AppColors.orangeDark : AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.studentName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        Text(
                                          'NIS: ${s.studentNis} • Kelas: ${s.studentClass}',
                                          style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12),
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
                                    color: AppColors.orangeDark.withAlpha(15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: AppColors.orangeDark, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Pelanggaran (${s.violationCount}x): ${s.lastViolationReason ?? "Pindah aplikasi"}',
                                          style: const TextStyle(color: AppColors.orangeDark, fontSize: 12, fontWeight: FontWeight.w600),
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
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  if (s.finalScore != null) ...[
                                    Builder(builder: (_) {
                                      final scoreVal = s.finalScore!;
                                      final isTuntas = scoreVal >= kkm;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isTuntas ? Colors.green.shade50 : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: isTuntas ? Colors.green.shade200 : Colors.red.shade200),
                                        ),
                                        child: Text(
                                          'Nilai: ${scoreVal.toStringAsFixed(1)} (KKM: ${kkm.toStringAsFixed(0)} • ${isTuntas ? "Tuntas" : "Remedial"})',
                                          style: TextStyle(
                                            color: isTuntas ? Colors.green.shade800 : Colors.red.shade800,
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
                                      style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
                                      icon: const Icon(Icons.lock_open, size: 16),
                                      label: const Text('Buka Blokir (Unblock)'),
                                      onPressed: () => fb.unblockExamSession(s.id),
                                    ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: s.antiCheatDisabledForStudent
                                          ? AppColors.navy
                                          : AppColors.orange,
                                      side: BorderSide(
                                        color: s.antiCheatDisabledForStudent
                                            ? AppColors.navy
                                            : AppColors.orange.withAlpha(120),
                                      ),
                                    ),
                                    icon: Icon(
                                      s.antiCheatDisabledForStudent
                                          ? Icons.shield_outlined
                                          : Icons.gpp_bad_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      s.antiCheatDisabledForStudent
                                          ? 'Cheat: Dinonaktifkan'
                                          : 'Nonaktifkan Cheat Siswa',
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
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text('Hapus Cache Akun (Safe)'),
                                    onPressed: () {
                                      fb.clearExamSessionCache(s.id);
                                      AppSnackBar.info(
                                        context,
                                        'Cache sesi siswa disegarkan. Jawaban tetap tersimpan utuh.',
                                      );
                                    },
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.rose),
                                    icon: const Icon(Icons.restart_alt, size: 16),
                                    label: const Text('Reset Jawaban'),
                                    onPressed: () => _confirmReset(context, fb, s),
                                  ),
                                  if (s.isCompleted)
                                    FilledButton.tonalIcon(
                                      icon: const Icon(Icons.rate_review_outlined, size: 16),
                                      label: const Text('Nilai Esai (Skala 1-5)'),
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

  Widget _buildStatBadge({required String label, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
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
