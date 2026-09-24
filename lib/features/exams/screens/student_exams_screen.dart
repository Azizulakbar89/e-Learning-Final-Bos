import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/question_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/exam_category_badge.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadClassExamQuestions();
    });
  }

  void _preloadClassExamQuestions() {
    if (!mounted) return;
    final fb = context.read<FirebaseService>();
    final user = fb.currentUser;
    final classExams = user != null ? fb.getExamsForStudent(user) : fb.exams;
    for (final exam in classExams) {
      fb.loadQuestionsForExam(exam);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final user = fb.currentUser;

    final classExams = user != null ? fb.getExamsForStudent(user) : fb.exams;

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
              bottomContent: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.quiz_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Quiz & Ujian Siswa',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          _selectedSubjectId == 'all'
                              ? '${classExams.length} Ujian Tersedia • Evaluasi Belajar'
                              : '${filteredExams.length} Ujian ${selectedSubject?.name ?? "Mapel Ini"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: Colors.white.withAlpha(190),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── TAB SWITCHER (SEDANG BERLANGSUNG VS RIWAYAT) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Container(
                height: 46,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _subMenuItem(
                        title: 'Sedang Berlangsung',
                        icon: Icons.local_fire_department_rounded,
                        count: pending.length,
                        isSelected: _selectedSubMenu == 0,
                        activeColor: const Color(0xFFEA580C),
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
                        activeColor: const Color(0xFF0F2552),
                        onTap: () => setState(() => _selectedSubMenu = 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── SUBJECT FILTER CHIPS (HORIZONTAL SCROLL) ──
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
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
                        padding: const EdgeInsets.only(left: 8),
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
            ),
            Expanded(
              child: _selectedSubMenu == 0
                  // Tab Sedang Berlangsung
                  ? (pending.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: const Icon(
                                    Icons.task_alt_rounded,
                                    size: 40,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  _selectedSubjectId == 'all'
                                      ? 'Semua Ujian Telah Selesai!'
                                      : 'Tidak Ada Ujian Aktif: ${selectedSubject?.name ?? ""}',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _selectedSubjectId == 'all'
                                      ? 'Bagus sekali! Tidak ada kuis atau evaluasi belajar yang tertunda saat ini. Tetap pantau kelasmu.'
                                      : 'Tidak ada kuis aktif pada mata pelajaran ini saat ini.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                if (_selectedSubjectId != 'all') ...[
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed: () => setState(() => _selectedSubjectId = 'all'),
                                    icon: const Icon(Icons.refresh_rounded, size: 16),
                                    label: const Text('Tampilkan Semua Mapel'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0F172A),
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                          itemCount: pending.length,
                          itemBuilder: (ctx, idx) => _ExamCard(
                            exam: pending[idx],
                            isDone: false,
                          ),
                        ))
                  // Tab Riwayat
                  : (done.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Icon(
                                    Icons.history_rounded,
                                    size: 40,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  _selectedSubjectId == 'all'
                                      ? 'Belum Ada Riwayat Ujian'
                                      : 'Belum Ada Riwayat: ${selectedSubject?.name ?? ""}',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Selesaikan kuis di tab "Sedang Berlangsung" untuk melihat catatan nilai dan evaluasi di sini.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                if (_selectedSubjectId != 'all') ...[
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed: () => setState(() => _selectedSubjectId = 'all'),
                                    icon: const Icon(Icons.refresh_rounded, size: 16),
                                    label: const Text('Tampilkan Semua Mapel'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0F172A),
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
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
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF0F172A).withAlpha(40)
                  : const Color(0x060F172A),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? const Color(0xFFFB923C) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withAlpha(35)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
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
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withAlpha(15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? activeColor : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withAlpha(22)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? activeColor : const Color(0xFF64748B),
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

    final now = DateTime.now();
    final isUpcoming = exam.startTime != null && now.isBefore(exam.startTime!);
    final isExpired = exam.endTime != null && now.isAfter(exam.endTime!);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? const Color(0xFFE2E8F0)
              : (isUpcoming
                  ? const Color(0xFFE2E8F0)
                  : const Color(0xFFFED7AA)),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isDone
              ? () => _showResultDialog(context, subjectName, hasEssay, isGraded)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── HEADER ROW: SUBJECT BADGE + STATUS/SCORE ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.menu_book_rounded, size: 12, color: Color(0xFF1E3A8A)),
                          const SizedBox(width: 5),
                          Text(
                            subjectName,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    ExamCategoryBadge(category: exam.category),
                    const Spacer(),
                    if (isDone)
                      if (!isGraded)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.pending_actions_rounded, size: 12, color: Color(0xFFB45309)),
                              const SizedBox(width: 4),
                              Text(
                                'Koreksi Guru',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.emoji_events_rounded, size: 12, color: Color(0xFF047857)),
                              const SizedBox(width: 4),
                              Text(
                                'Nilai: ${score ?? session?.finalScore?.round() ?? 100}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        )
                    else if (exam.antiCheatEnabled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFEDD5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.security_rounded, size: 12, color: Color(0xFFEA580C)),
                            const SizedBox(width: 4),
                            Text(
                              'Anti-Cheat',
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFEA580C),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── TITLE & DESCRIPTION ──
                Text(
                  exam.title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                if (exam.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    exam.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // ── JADWAL / SCHEDULE (JIKA ADA) ──
                if (exam.startTime != null || exam.endTime != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFFEA580C)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Jadwal: ${exam.startTime != null ? AppDateFormatter.formatShortDateTime(exam.startTime!) : "-"} s/d ${exam.endTime != null ? AppDateFormatter.formatShortDateTime(exam.endTime!) : "-"}',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF334155),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // ── STATS CHIPS: MENIT & SOAL ──
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _chip('${exam.durationMinutes} Menit', Icons.timer_outlined, const Color(0xFF0F2552)),
                    _chip('${exam.questionIds.length} Soal', Icons.assignment_outlined, const Color(0xFF0F2552)),
                    if (isDone)
                      _chip('Selesai Dikerjakan', Icons.check_circle_outline_rounded, const Color(0xFF047857))
                    else if (isUpcoming)
                      _chip('Belum Dibuka', Icons.lock_clock_outlined, const Color(0xFF64748B))
                    else if (isExpired)
                      _chip('Waktu Habis', Icons.hourglass_disabled_rounded, const Color(0xFFEF4444)),
                  ],
                ),

                const SizedBox(height: 14),

                // ── ACTION BUTTON / CTA ──
                if (isDone) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.visibility_rounded, size: 15, color: Color(0xFF1E3A8A)),
                        const SizedBox(width: 6),
                        Text(
                          'Lihat Hasil & Rincian Nilai',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E3A8A),
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ] else ...[
                  if (isUpcoming)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          AppSnackBar.info(
                            context,
                            'Ujian belum dibuka. Mulai dapat dikerjakan pada: ${AppDateFormatter.formatFullDateTime(exam.startTime!)} WIB.',
                          );
                        },
                        icon: const Icon(Icons.schedule_rounded, size: 15),
                        label: Text(
                          'Ujian Belum Dimulai',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                      ),
                    )
                  else if (isExpired)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Waktu Pengerjaan Telah Berakhir',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    )
                  else
                    // Prominent Warm Orange CTA Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEA580C).withAlpha(50),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExamTakingScreen(exam: exam),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  'Mulai Kerjakan Ujian',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: Colors.white,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResultDialog(BuildContext context, String subjectName, bool hasEssay, bool isGraded) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFD97706), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hasil Ujian',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    subjectName,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 20),
            Text(
              exam.title,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: const Color(0xFF0F172A),
              ),
            ),
            if (exam.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                exam.description,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A1931), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x200A1931),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'NILAI AKHIR',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${score ?? 0} / 100',
                    style: GoogleFonts.outfit(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFB923C),
                    ),
                  ),
                  if (hasEssay && !isGraded) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '⏳ Menunggu koreksi esai oleh guru',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (session?.nonEssayScore != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Skor Pilihan Ganda:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text(
                      '${session!.nonEssayScore!.round()}',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: const [
                Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ujian ini telah selesai dikerjakan.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Tutup',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

