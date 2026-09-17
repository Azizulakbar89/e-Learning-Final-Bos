import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/question_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/universal_app_header.dart';
import 'exam_taking_screen.dart';

class StudentExamsScreen extends StatefulWidget {
  const StudentExamsScreen({super.key});

  @override
  State<StudentExamsScreen> createState() => _StudentExamsScreenState();
}

class _StudentExamsScreenState extends State<StudentExamsScreen> {
  // 0: Sedang Berlangsung / Aktif, 1: Riwayat
  int _selectedSubMenu = 0;
  String _selectedSubjectId = 'all';

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final user = fb.currentUser;

    // All exams assigned to student's class
    final classExams = fb.exams.where((e) {
      if (user?.classId != null && user!.classId!.isNotEmpty) {
        return e.classIds.contains(user.classId);
      }
      return true;
    }).toList();

    // Filter by selected subject
    final filteredExams = classExams.where((e) {
      if (_selectedSubjectId != 'all' && e.subjectId != _selectedSubjectId) {
        return false;
      }
      return true;
    }).toList();

    // Ujian yang sudah selesai, di-submit, atau waktu pengerjaannya telah habis
    final done = filteredExams.where((e) {
      if (user == null) return false;
      return fb.isExamFinishedForStudent(examId: e.id, studentId: user.id);
    }).toList();
    final pending = filteredExams.where((e) => !done.contains(e)).toList();

    // Selected subject object
    final selectedSubject = fb.subjects.where((s) => s.id == _selectedSubjectId).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            UniversalAppHeader(
              bottomContent: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Row Info Ujian
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.quiz_rounded,
                            color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Quiz & Ujian',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _selectedSubjectId == 'all'
                                  ? '${classExams.length} Ujian Tersedia • Evaluasi Belajar'
                                  : '${filteredExams.length} Ujian ${selectedSubject?.name ?? "Mapel Ini"}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (pending.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 11)),
                              const SizedBox(width: 4),
                              Text(
                                '${pending.length} Aktif',
                                style: const TextStyle(
                                  color: Color(0xFFEA580C),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Sub Menu 2 Tabs: Sedang Berlangsung vs Riwayat Selesai
                  Container(
                    height: 42,
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(50),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withAlpha(35)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _subMenuItem(
                            title: 'Sedang Berlangsung',
                            icon: Icons.local_fire_department_rounded,
                            count: pending.length,
                            isSelected: _selectedSubMenu == 0,
                            activeColor: AppColors.orange,
                            onTap: () => setState(() => _selectedSubMenu = 0),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _subMenuItem(
                            title: 'Riwayat Selesai',
                            icon: Icons.history_rounded,
                            count: done.length,
                            isSelected: _selectedSubMenu == 1,
                            activeColor: const Color(0xFF2563EB),
                            onTap: () => setState(() => _selectedSubMenu = 1),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Subject Filter Chips (Horizontal Scroll)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _subjectChip(
                          label: 'Semua Mapel',
                          icon: Icons.auto_stories_rounded,
                          isSelected: _selectedSubjectId == 'all',
                          count: classExams.length,
                          onTap: () => setState(() => _selectedSubjectId = 'all'),
                        ),
                        ...fb.subjects.map((s) {
                          final count = classExams.where((e) => e.subjectId == s.id).length;
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _subjectChip(
                              label: s.name,
                              icon: Icons.menu_book_rounded,
                              isSelected: _selectedSubjectId == s.id,
                              count: count,
                              onTap: () => setState(() => _selectedSubjectId = s.id),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _selectedSubMenu == 0
                  // Tab Sedang Berlangsung
                  ? (pending.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppColors.orange.withAlpha(20),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_circle_rounded,
                                    size: 40, color: AppColors.orange),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedSubjectId == 'all'
                                    ? 'Tidak Ada Ujian Sedang Berlangsung'
                                    : 'Tidak Ada Ujian Aktif: ${selectedSubject?.name ?? ""}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _selectedSubjectId == 'all'
                                    ? 'Semua kuis dan ujian kelasmu telah diselesaikan! 🎉'
                                    : 'Tidak ada kuis aktif pada mapel ini saat ini.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12.5,
                                ),
                              ),
                              if (_selectedSubjectId != 'all') ...[
                                const SizedBox(height: 14),
                                OutlinedButton.icon(
                                  onPressed: () => setState(() => _selectedSubjectId = 'all'),
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Tampilkan Semua Mapel'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.navy,
                                    side: BorderSide(color: AppColors.navy.withAlpha(60)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: pending.length,
                          itemBuilder: (ctx, idx) => _ExamCard(
                            exam: pending[idx],
                            isDone: false,
                          ),
                        ))
                  // Tab Riwayat
                  : (done.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_rounded,
                                  size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                _selectedSubjectId == 'all'
                                    ? 'Belum Ada Riwayat Ujian'
                                    : 'Belum Ada Riwayat: ${selectedSubject?.name ?? ""}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Selesaikan kuis di tab "Sedang Berlangsung" untuk melihat riwayat nilai di sini.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12.5,
                                ),
                              ),
                              if (_selectedSubjectId != 'all') ...[
                                const SizedBox(height: 14),
                                OutlinedButton.icon(
                                  onPressed: () => setState(() => _selectedSubjectId = 'all'),
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Tampilkan Semua Mapel'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.navy,
                                    side: BorderSide(color: AppColors.navy.withAlpha(60)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: done.length,
                          itemBuilder: (ctx, idx) {
                            final exam = done[idx];
                            final session = fb.examSessions
                                .where((s) => s.examId == exam.id && s.studentId == user?.id)
                                .firstOrNull;
                            final score = session?.finalScore?.round() ?? session?.nonEssayScore?.round();
                            return _ExamCard(
                              exam: exam,
                              isDone: true,
                              session: session,
                              score: score,
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subjectChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required int count,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.orange : Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.orangeLight : Colors.white.withAlpha(45),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.orange.withAlpha(80),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black.withAlpha(35) : Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _subMenuItem({
    required String title,
    required IconData icon,
    required int count,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? activeColor : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF0F172A) : Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withAlpha(20)
                    : Colors.white.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? activeColor : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Exam Card ───────────────────────────────────────────────────────────────
class _ExamCard extends StatelessWidget {
  final dynamic exam;
  final bool isDone;
  final int? score;
  final dynamic session;

  const _ExamCard({
    required this.exam,
    required this.isDone,
    this.score,
    this.session,
  });

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final subject = fb.subjects.where((s) => s.id == exam.subjectId).firstOrNull;
    final subjectName = subject?.name ?? 'Mata Pelajaran';
    final examQuestions = fb.questions.where((q) => exam.questionIds.contains(q.id)).toList();
    final essayQuestions = examQuestions.where((q) => q.type == QuestionType.essay).toList();
    final hasEssay = essayQuestions.isNotEmpty;
    final isGraded = !hasEssay || (session != null && session.essayScores.length >= essayQuestions.length);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: isDone
          ? () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: [
                      const Icon(Icons.military_tech_rounded, color: AppColors.orange, size: 26),
                      const SizedBox(width: 8),
                      Text(
                        'Hasil Ujian',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.navy.withAlpha(15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.navy.withAlpha(30)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book_rounded, size: 12, color: AppColors.navy),
                            const SizedBox(width: 4),
                            Text(
                              subjectName,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(exam.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      Text(exam.description, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.navy.withAlpha(10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.navy.withAlpha(35)),
                        ),
                        child: Column(
                          children: [
                            const Text('NILAI AKHIR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy, letterSpacing: 0.8)),
                            const SizedBox(height: 4),
                            Text(
                              '${score ?? 0} / 100',
                              style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.orange),
                            ),
                            if (hasEssay && !isGraded) ...[
                              const SizedBox(height: 6),
                              const Text('⏳ Menunggu koreksi esai guru', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.orangeDark)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '🔒 Ujian ini sudah selesai dikerjakan dan tidak dapat diulang kembali.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  actions: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tutup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDone
                ? AppColors.navy.withAlpha(35)
                : AppColors.orange.withAlpha(55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDone ? AppColors.navy : AppColors.orange).withAlpha(12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: isDone
                      ? const LinearGradient(
                          colors: [AppColors.navy, AppColors.navyLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [AppColors.orange, AppColors.orangeDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (isDone ? AppColors.navy : AppColors.orange).withAlpha(40),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isDone ? Icons.check_circle_rounded : Icons.timer_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withAlpha(15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.navy.withAlpha(35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.menu_book_rounded, size: 11, color: AppColors.navy),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              subjectName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      exam.title,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exam.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (exam.startTime != null || exam.endTime != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 11, color: AppColors.orange),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Jadwal: ${exam.startTime != null ? AppDateFormatter.formatShortDateTime(exam.startTime!) : "-"} s/d ${exam.endTime != null ? AppDateFormatter.formatShortDateTime(exam.endTime!) : "-"}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navy,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _chip('${exam.durationMinutes} Menit',
                            Icons.timer_outlined, isDone),
                        _chip('${exam.questionIds.length} Soal',
                            Icons.list_alt_rounded, isDone),
                        if (exam.antiCheatEnabled)
                          _chip('Anti-Cheat', Icons.security_rounded, isDone,
                              isAccent: true),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isDone)
                if (!isGraded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withAlpha(15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.orange.withAlpha(60)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Terkumpul',
                          style: TextStyle(
                            color: AppColors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 10.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Koreksi Esai',
                          style: GoogleFonts.outfit(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                          ),
                        ),
                        if (session?.nonEssayScore != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'PG: ${session!.nonEssayScore!.round()}',
                            style: GoogleFonts.outfit(
                              color: AppColors.navy,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withAlpha(12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.orange.withAlpha(50)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Selesai Dinilai',
                          style: TextStyle(
                            color: AppColors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Nilai: ${score ?? session?.finalScore?.round() ?? 100} / 100',
                          style: GoogleFonts.outfit(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
              else ...[
                Builder(
                  builder: (ctx) {
                    final now = DateTime.now();
                    final isUpcoming =
                        exam.startTime != null && now.isBefore(exam.startTime!);
                    final isExpired =
                        exam.endTime != null && now.isAfter(exam.endTime!);

                    if (isUpcoming) {
                      return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.navy,
                          side: BorderSide(color: AppColors.navy.withAlpha(80)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          AppSnackBar.info(
                            context,
                            'Ujian belum dibuka. Mulai dapat dikerjakan pada: ${AppDateFormatter.formatFullDateTime(exam.startTime!)} WIB.',
                          );
                        },
                        child: Text(
                          'Belum Mulai',
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      );
                    }

                    if (isExpired) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Ditutup',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey),
                        ),
                      );
                    }

                    return FilledButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ExamTakingScreen(exam: exam)),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: Text(
                        'Mulai',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon, bool isDone, {bool isAccent = false}) {
    final color = isAccent ? AppColors.orange : AppColors.navy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(isAccent ? 18 : 12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(isAccent ? 40 : 25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
