import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/exam_model.dart';
import '../../../core/models/material_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/excel_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/sidikmu_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/app_nav_rail.dart';
import '../../../core/widgets/app_update_dialog.dart';
import '../../../core/widgets/exam_category_badge.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/universal_app_header.dart';
import '../../curriculum_and_questions/screens/cp_tp_manager_screen.dart';
import '../../curriculum_and_questions/screens/missing_images_validator_screen.dart';
import '../../curriculum_and_questions/screens/question_bank_screen.dart';
import '../../exams/screens/teacher_exam_monitor_screen.dart';
import '../../materials/screens/material_detail_screen.dart';
import '../../materials/screens/material_form_screen.dart';
import '../../materials/screens/teacher_materials_screen.dart';
import '../../exams/screens/exam_form_screen.dart';
import '../../exams/widgets/duplicate_exam_dialog.dart';
import '../../social_and_gamification/screens/chat_list_screen.dart';
import '../../teacher_tools/screens/student_roster_screen.dart';
import '../../teacher_tools/screens/school_class_manager_screen.dart';
import '../../teacher_tools/widgets/class_student_scores_dialog.dart';
import '../../teacher_tools/widgets/class_material_progress_dialog.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  String _activeSubjectId = 'subj_web';
  int _currentNavIndex = 0;
  final Set<String> _notifiedLockedSessionIds = {};

  static const _navItems = [
    AppNavRailItem(
      label: 'Beranda',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    AppNavRailItem(
      label: 'Quiz & Ujian',
      icon: Icons.quiz_outlined,
      selectedIcon: Icons.quiz_rounded,
    ),
    AppNavRailItem(
      label: 'Materi Belajar',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book_rounded,
    ),
    AppNavRailItem(
      label: 'Pesan & Diskusi',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
    ),
    AppNavRailItem(
      label: 'Profil Guru',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final currentUser = fb.currentUser;
    final taughtSubjects = fb.getTeacherSubjects(currentUser);

    // Ensure active subject is valid
    if (taughtSubjects.isNotEmpty) {
      if (_activeSubjectId.isEmpty || !taughtSubjects.any((s) => s.id == _activeSubjectId)) {
        _activeSubjectId = taughtSubjects.first.id;
      }
    } else {
      _activeSubjectId = '';
    }

    final missingCount = _activeSubjectId.isEmpty ? 0 : fb.getMissingImageQuestions(_activeSubjectId).length;
    final allTeacherExams = fb.getTeacherExams(currentUser);
    final allTeacherMaterials = fb.getTeacherMaterials(currentUser);
    final exams = _activeSubjectId.isEmpty
        ? allTeacherExams
        : allTeacherExams.where((e) => e.subjectId == _activeSubjectId).toList();
    final materials = _activeSubjectId.isEmpty
        ? allTeacherMaterials
        : allTeacherMaterials.where((m) => m.subjectId == _activeSubjectId).toList();

    // ─── Real-Time Alert for newly locked students ───
    final teacherExamIds = allTeacherExams.map((e) => e.id).toSet();
    final teacherStudents = fb.getTeacherStudents(currentUser);
    final teacherStudentIds = teacherStudents.map((s) => s.id).toSet();

    final lockedSessions = fb.examSessions.where((s) {
      return s.isLocked && (teacherExamIds.contains(s.examId) || teacherStudentIds.contains(s.studentId));
    }).toList();

    for (final s in lockedSessions) {
      if (!_notifiedLockedSessionIds.contains(s.id)) {
        _notifiedLockedSessionIds.add(s.id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final exam = fb.exams.where((e) => e.id == s.examId).firstOrNull;
          final examTitle = exam?.title ?? 'Kuis / Ujian';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
              ),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              duration: const Duration(seconds: 7),
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withAlpha(35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_person_rounded, color: Color(0xFFEF4444), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Siswa Terkunci!',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: const Color(0xFFFCA5A5),
                          ),
                        ),
                        Text(
                          '${s.studentName} (${s.studentClass.isNotEmpty ? s.studentClass : "Kelas"}) terdeteksi keluar aplikasi pada "$examTitle"',
                          style: const TextStyle(fontSize: 11.5, color: Colors.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'BUKA KUNCI',
                textColor: const Color(0xFF38BDF8),
                onPressed: () {
                  _showLockedStudentsModal(context, fb, currentUser);
                },
              ),
            ),
          );
        });
      }
    }

    final currentLockedIds = lockedSessions.map((s) => s.id).toSet();
    _notifiedLockedSessionIds.removeWhere((id) => !currentLockedIds.contains(id));

    final List<Widget> pages = [
      _TeacherDashboardPage(
        fb: fb,
        currentUser: currentUser,
        taughtSubjects: taughtSubjects,
        activeSubjectId: _activeSubjectId,
        onSubjectChanged: (id) => setState(() => _activeSubjectId = id),
        missingCount: missingCount,
        exams: exams,
        materials: materials,
        onNavigateToQuiz: () => setState(() => _currentNavIndex = 1),
        onNavigateToMaterials: () => setState(() => _currentNavIndex = 2),
      ),
      _TeacherExamsPage(
        fb: fb,
        currentUser: currentUser,
        taughtSubjects: taughtSubjects,
        activeSubjectId: _activeSubjectId,
        onSubjectChanged: (id) => setState(() => _activeSubjectId = id),
      ),
      const TeacherMaterialsScreen(showBackButton: false),
      const ChatListScreen(showBackButton: false, isEmbedded: true),
      _TeacherProfilePage(
        currentUser: currentUser,
        fb: fb,
        taughtSubjects: taughtSubjects,
      ),
    ];

    return ResponsiveLayout(
      mobile: _buildMobileLayout(pages, fb),
      desktop: _buildDesktopLayout(pages, currentUser, fb),
    );
  }

  Widget _buildMobileLayout(List<Widget> pages, FirebaseService fb) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentNavIndex,
        children: pages,
      ),
      bottomNavigationBar: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: _TeacherOvalBottomNav(
            selectedIndex: _currentNavIndex,
            onTap: (idx) => setState(() => _currentNavIndex = idx),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    List<Widget> pages,
    dynamic currentUser,
    FirebaseService fb,
  ) {
    return Scaffold(
      body: Row(
        children: [
          AppNavRail(
            selectedIndex: _currentNavIndex,
            onDestinationSelected: (i) => setState(() => _currentNavIndex = i),
            items: _navItems,
            header: _buildSidebarHeader(currentUser, fb),
            footer: _buildSidebarFooter(fb),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey(_currentNavIndex),
                child: pages[_currentNavIndex],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(dynamic currentUser, FirebaseService fb) {
    final totalStudents = fb.getTeacherStudents(currentUser).length;
    final activeExams = fb.getTeacherExams(currentUser).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderDark.withAlpha(80))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'e-learning spemdalas',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '👨‍🏫 Panel Guru',
              style: TextStyle(
                color: AppColors.primaryLight,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF0EA5E9)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    currentUser?.fullName.isNotEmpty == true
                        ? currentUser!.fullName[0].toUpperCase()
                        : 'G',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser?.fullName ?? 'Guru',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Pengajar & Pengawas',
                      style: const TextStyle(
                          color: AppColors.textSecondaryDark, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _sidebarStat('$totalStudents', 'Siswa', AppColors.accent),
              const SizedBox(width: 8),
              _sidebarStat('$activeExams', 'Ujian', AppColors.rose),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sidebarStat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              label,
              style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarFooter(FirebaseService fb) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => fb.logout(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.rose.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.rose.withAlpha(60)),
        ),
        child: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.rose, size: 18),
            const SizedBox(width: 10),
            Text(
              'Keluar',
              style: GoogleFonts.inter(
                color: AppColors.rose,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── LOCKED STUDENTS MODAL ──────────────────────────────────────────────────
void _showLockedStudentsModal(BuildContext context, FirebaseService fb, dynamic currentUser) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Consumer<FirebaseService>(
        builder: (context, fbService, _) {
          final teacherStudents = fbService.getTeacherStudents(currentUser);
          final teacherStudentIds = teacherStudents.map((s) => s.id).toSet();
          final teacherExams = fbService.getTeacherExams(currentUser);
          final teacherExamIds = teacherExams.map((e) => e.id).toSet();

          final lockedSessions = fbService.examSessions.where((s) {
            return s.isLocked &&
                (teacherExamIds.contains(s.examId) || teacherStudentIds.contains(s.studentId));
          }).toList();

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (lockedSessions.isNotEmpty ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        lockedSessions.isNotEmpty ? Icons.lock_person_rounded : Icons.verified_user_rounded,
                        color: lockedSessions.isNotEmpty ? const Color(0xFFDC2626) : const Color(0xFF059669),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daftar Siswa Terkunci',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            lockedSessions.isNotEmpty
                                ? '${lockedSessions.length} siswa perlu dibuka kuncinya'
                                : 'Semua sesi ujian siswa berjalan normal',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (lockedSessions.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFECFDF5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 40),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Tidak Ada Siswa Terkunci',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Seluruh siswa mengerjakan ujian dengan lancar tanpa pelanggaran anti-cheat.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: lockedSessions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final s = lockedSessions[idx];
                        final exam = fbService.exams.where((e) => e.id == s.examId).firstOrNull;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFFEF4444).withAlpha(30),
                                    child: const Icon(Icons.person_rounded, color: Color(0xFFDC2626), size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.studentName,
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.5,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          'Kelas: ${s.studentClass.isNotEmpty ? s.studentClass : "-"} • NIS: ${s.studentNis}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.lock_rounded, size: 12, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${s.violationCount}x Pelanggaran',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.quiz_rounded, size: 14, color: Color(0xFFEA580C)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        exam?.title ?? 'Ujian Siswa',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: const Color(0xFF334155),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (exam != null) ...[
                                      const SizedBox(width: 6),
                                      ExamCategoryBadge(category: exam.category),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: () {
                                        fbService.unblockExamSession(s.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Kunci ujian untuk ${s.studentName} berhasil dibuka!'),
                                            backgroundColor: const Color(0xFF10B981),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.lock_open_rounded, size: 16),
                                      label: const Text('Buka Kunci Sekarang'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  if (exam != null) ...[
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TeacherExamMonitorScreen(exam: exam),
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        side: const BorderSide(color: Color(0xFF94A3B8)),
                                      ),
                                      child: const Text('Monitor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

// ─── DASHBOARD PAGE ──────────────────────────────────────────────────────────
class _TeacherDashboardPage extends StatelessWidget {
  final FirebaseService fb;
  final dynamic currentUser;
  final List<dynamic> taughtSubjects;
  final String activeSubjectId;
  final ValueChanged<String> onSubjectChanged;
  final int missingCount;
  final List<dynamic> exams;
  final List<dynamic> materials;

  final VoidCallback? onNavigateToQuiz;
  final VoidCallback? onNavigateToMaterials;

  const _TeacherDashboardPage({
    required this.fb,
    required this.currentUser,
    required this.taughtSubjects,
    required this.activeSubjectId,
    required this.onSubjectChanged,
    required this.missingCount,
    required this.exams,
    required this.materials,
    this.onNavigateToQuiz,
    this.onNavigateToMaterials,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Container(
      color: isWide ? const Color(0xFF040D1F) : AppColors.backgroundLight,
      child: SafeArea(
        bottom: false,
        child: ClipRect(
          child: Column(
            children: [
              // ─── Sticky Modern Curved Header (Matching Beranda / Siswa) ───
              if (!isWide) const UniversalAppHeader(),

              // Scrollable Page Content
              Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  isWide ? 32 : 16,
                  isWide ? 20 : 10,
                  isWide ? 32 : 16,
                  130, // Avoid overlap with floating bottom nav
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

              // Desktop greeting
              if (isWide) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dashboard Guru 📋',
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            currentUser?.fullName ?? 'Pengajar',
                            style: const TextStyle(
                                color: AppColors.textSecondaryDark, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ChatListScreen())),
                      icon: const Text('🔥', style: TextStyle(fontSize: 16)),
                      label: const Text('Streaks Siswa'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Unplotted Warning Banner
              if (taughtSubjects.isEmpty || fb.getTeacherClasses(currentUser).isEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Akun Guru Belum Diplot Oleh Admin Sekolah',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: const Color(0xFF991B1B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Data siswa, kelas, mapel, materi, dan ujian hanya akan muncul jika Admin telah menugaskan akun Anda pada kelas & mapel tertentu. Hubungi Admin Sekolah untuk melakukan plotting.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF7F1D1D), height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Stats Overview
              _buildStatsRow(context, isWide),
              const SizedBox(height: 20),

              // Missing images alert
              if (missingCount > 0) ...[
                _buildMissingAlert(context, isWide),
                const SizedBox(height: 16),
              ],

              // Alat Pengajar (Always above progress quiz and progress materi)
              _sectionTitle('Alat Pengajar', isWide, icon: Icons.construction_rounded),
              const SizedBox(height: 12),
              _buildActionGrid(context, isWide),
              const SizedBox(height: 24),

              // Subject Switcher & Progress Kelas (Rata-rata Nilai & Progress Materi)
              _buildSubjectChipTabs(isWide),
              const SizedBox(height: 14),
              _buildClassScoresSection(context, isWide),
              const SizedBox(height: 14),
              _buildClassMaterialProgressSection(context, isWide),
              const SizedBox(height: 28),

              // Exams & Materials
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildExamHeader(context, isWide),
                          const SizedBox(height: 12),
                          _buildExamList(context, isWide),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMaterialHeader(context, isWide),
                          const SizedBox(height: 12),
                          _buildMaterialList(context, isWide),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                _buildExamHeader(context, isWide),
                const SizedBox(height: 12),
                _buildExamList(context, isWide),
                const SizedBox(height: 24),
                _buildMaterialHeader(context, isWide),
                const SizedBox(height: 12),
                _buildMaterialList(context, isWide),
              ],
            ],
          ),
        ),
      ),
    ],
  ),
),
),
);
  }


  Widget _buildStatsRow(BuildContext context, bool isWide) {
    final teacherStudents = fb.getTeacherStudents(currentUser);
    final teacherStudentIds = teacherStudents.map((s) => s.id).toSet();
    final teacherClasses = fb.getTeacherClasses(currentUser);
    final teacherExams = fb.getTeacherExams(currentUser);
    final teacherExamIds = teacherExams.map((e) => e.id).toSet();

    final liveStudents = fb.examSessions
        .where((s) => s.status == 'in_progress' && (teacherExamIds.contains(s.examId) || teacherStudentIds.contains(s.studentId)))
        .length;
    final lockedStudents = fb.examSessions
        .where((s) => s.status == 'locked' && (teacherExamIds.contains(s.examId) || teacherStudentIds.contains(s.studentId)))
        .length;

    final stats = [
      _StatItem(
        icon: Icons.people_alt_rounded,
        value: teacherStudents.length.toString(),
        label: 'Siswa Binaan',
        primaryColor: const Color(0xFF2563EB),
        lightColor: const Color(0xFFEFF6FF),
        borderColor: const Color(0xFFBFDBFE),
        badgeText: '${teacherClasses.length} Rombel',
        badgeColor: const Color(0xFF2563EB),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StudentRosterScreen()),
        ),
      ),
      _StatItem(
        icon: Icons.quiz_rounded,
        value: exams.length.toString(),
        label: 'Ujian Aktif',
        primaryColor: const Color(0xFF7C3AED),
        lightColor: const Color(0xFFF5F3FF),
        borderColor: const Color(0xFFDDD6FE),
        badgeText: 'Tersedia',
        badgeColor: const Color(0xFF7C3AED),
        onTap: onNavigateToQuiz,
      ),
      _StatItem(
        icon: Icons.visibility_rounded,
        value: liveStudents.toString(),
        label: 'Sedang Ujian',
        primaryColor: const Color(0xFF059669),
        lightColor: const Color(0xFFECFDF5),
        borderColor: const Color(0xFFA7F3D0),
        badgeText: liveStudents > 0 ? 'Live' : 'Kosong',
        badgeColor: const Color(0xFF059669),
        onTap: onNavigateToQuiz,
      ),
      _StatItem(
        icon: lockedStudents > 0 ? Icons.lock_person_rounded : Icons.lock_rounded,
        value: lockedStudents.toString(),
        label: 'Terkunci',
        primaryColor: lockedStudents > 0 ? const Color(0xFFDC2626) : const Color(0xFF475569),
        lightColor: lockedStudents > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
        borderColor: lockedStudents > 0 ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
        badgeText: lockedStudents > 0 ? 'Perlu Buka' : 'Aman',
        badgeColor: lockedStudents > 0 ? const Color(0xFFDC2626) : const Color(0xFF10B981),
        onTap: () => _showLockedStudentsModal(context, fb, currentUser),
      ),
    ];

    if (isWide) {
      return Row(
        children: [
          for (int i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: _buildStatCard(stats[i], isWide)),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard(stats[0], isWide)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard(stats[1], isWide)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildStatCard(stats[2], isWide)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard(stats[3], isWide)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(_StatItem stat, bool isWide) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: stat.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: stat.borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: stat.primaryColor.withAlpha(14),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: stat.lightColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: stat.borderColor),
                ),
                child: Icon(stat.icon, color: stat.primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          stat.value,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.5,
                            height: 1.0,
                          ),
                        ),
                        if (stat.badgeText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: stat.lightColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: stat.borderColor),
                            ),
                            child: Text(
                              stat.badgeText!,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: stat.badgeColor ?? stat.primaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stat.label,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectChipTabs(bool isWide) {
    final displaySubjects = taughtSubjects;
    if (displaySubjects.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Icon(Icons.layers_rounded, color: Color(0xFF1E40AF), size: 14),
            ),
            const SizedBox(width: 8),
            Text(
              'Mata Pelajaran Diampu:',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isWide ? Colors.white70 : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: displaySubjects.map((s) {
              final isActive = s.id == activeSubjectId;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onSubjectChanged(s.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? const LinearGradient(
                              colors: [Color(0xFF0A1931), Color(0xFF1E3A8A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isActive ? null : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0),
                        width: isActive ? 1.5 : 1,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: const Color(0xFF1E3A8A).withAlpha(45),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withAlpha(6),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFFF97316) : Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s.name,
                          style: GoogleFonts.outfit(
                            color: isActive ? Colors.white : const Color(0xFF334155),
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12.5,
                          ),
                        ),
                        if (s.code.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.white.withAlpha(25) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.code,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isActive ? Colors.white70 : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildClassScoresSection(BuildContext context, bool isWide) {
    final classes = fb.getTeacherClasses(currentUser);
    final activeSubject = fb.subjects.where((s) => s.id == activeSubjectId).firstOrNull;

    if (classes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.analytics_rounded, size: 15, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 8),
                Text(
                  'Rata-Rata Nilai Per Kelas',
                  style: GoogleFonts.outfit(
                    fontSize: isWide ? 16 : 14.5,
                    fontWeight: FontWeight.w700,
                    color: isWide ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${classes.length} Rombel',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: classes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final cls = classes[idx];
              final summary = fb.getClassScoreSummary(cls, subjectId: activeSubjectId);
              final double avg = summary['averageScore'] as double;
              final int studentCount = summary['totalStudents'] as int;

              final Color scoreColor = avg >= 80
                  ? const Color(0xFF059669)
                  : (avg >= 70
                      ? const Color(0xFF2563EB)
                      : (avg >= 60 ? const Color(0xFFD97706) : const Color(0xFFDC2626)));
              final Color scoreBg = avg >= 80
                  ? const Color(0xFFECFDF5)
                  : (avg >= 70
                      ? const Color(0xFFEFF6FF)
                      : (avg >= 60 ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2)));

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => ClassStudentScoresDialog.show(
                    context,
                    classId: cls,
                    subjectId: activeSubjectId,
                    subjectName: activeSubject?.name,
                  ),
                  child: Container(
                    width: 210,
                    decoration: BoxDecoration(
                      gradient: isWide
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFFF8FAFC), Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: isWide ? AppColors.surfaceDark : null,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isWide ? scoreColor.withAlpha(60) : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x0A0F172A),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A).withAlpha(8),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  cls,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: scoreBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: scoreColor.withAlpha(50)),
                                ),
                                child: Text(
                                  avg > 0 ? avg.toStringAsFixed(1) : '-',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: scoreColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.people_alt_rounded, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 5),
                              Text(
                                '$studentCount Siswa Terdaftar',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                'Lihat Rincian Nilai',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: scoreColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 13, color: scoreColor),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClassMaterialProgressSection(BuildContext context, bool isWide) {
    final classes = fb.getTeacherClasses(currentUser);
    final activeSubject = fb.subjects.where((s) => s.id == activeSubjectId).firstOrNull;

    if (classes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Icon(Icons.menu_book_rounded, size: 15, color: Color(0xFF059669)),
                ),
                const SizedBox(width: 8),
                Text(
                  'Progress Materi Belajar',
                  style: GoogleFonts.outfit(
                    fontSize: isWide ? 16 : 14.5,
                    fontWeight: FontWeight.w700,
                    color: isWide ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Per Kelas',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 125,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: classes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final cls = classes[idx];
              final summary = fb.getClassMaterialProgressSummary(cls, activeSubjectId);
              final double avgProgress = summary['averageProgress'] as double;
              final int studentCount = summary['totalStudents'] as int;
              final int totalClassMaterials = (summary['totalMaterials'] as int?) ?? 0;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => ClassMaterialProgressDialog.show(
                    context,
                    classId: cls,
                    subjectId: activeSubjectId,
                    subjectName: activeSubject?.name,
                  ),
                  child: Container(
                    width: 210,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: isWide
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFFFFFBEB), Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: isWide ? AppColors.surfaceDark : null,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFFDE68A),
                        width: 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A0F172A),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A).withAlpha(8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                cls,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${avgProgress.toInt()}% Selesai',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (avgProgress / 100).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$studentCount Siswa • $totalClassMaterials Materi',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF059669)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMissingAlert(BuildContext context, bool isWide) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MissingImagesValidatorScreen(subjectId: activeSubjectId),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.amber.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.amber.withAlpha(150)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$missingCount soal belum memiliki gambar dari PDF. Klik untuk melengkapi.',
                style: TextStyle(
                  color: Colors.amber.shade900,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.amber),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, bool isWide, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Icon(icon, size: 15, color: const Color(0xFFEA580C)),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: isWide ? Colors.white : const Color(0xFF071540),
          ),
        ),
      ],
    );
  }

  Widget _buildActionGrid(BuildContext context, bool isWide) {
    final actions = [
      _ActionCard(
        title: 'Bank Soal',
        subtitle: '5 Tipe & LaTeX',
        icon: Icons.quiz_outlined,
        primaryColor: const Color(0xFF2563EB),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuestionBankScreen(initialSubjectId: activeSubjectId),
          ),
        ),
      ),
      _ActionCard(
        title: 'Kelola CP & TP',
        subtitle: 'Capaian & Tujuan',
        icon: Icons.account_tree_outlined,
        primaryColor: const Color(0xFFEA580C),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CpTpManagerScreen()),
        ),
      ),
      _ActionCard(
        title: 'Kelola Kelas',
        subtitle: 'Daftar Kelas Sekolah',
        icon: Icons.meeting_room_outlined,
        primaryColor: const Color(0xFFEA580C),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SchoolClassManagerScreen()),
        ),
      ),
      _ActionCard(
        title: 'Data Siswa',
        subtitle: 'NIS, Akun & Nilai',
        icon: Icons.people_alt_outlined,
        primaryColor: const Color(0xFF2563EB),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StudentRosterScreen()),
        ),
      ),
    ];

    if (isWide) {
      return Row(
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: _buildActionCardWidget(actions[i], isWide)),
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (int i = 0; i < actions.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 10));
      final hasSecond = i + 1 < actions.length;
      rows.add(
        Row(
          children: [
            Expanded(child: _buildActionCardWidget(actions[i], isWide)),
            const SizedBox(width: 10),
            Expanded(
              child: hasSecond
                  ? _buildActionCardWidget(actions[i + 1], isWide)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }

  Widget _buildActionCardWidget(_ActionCard card, bool isWide) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: card.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: card.primaryColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(card.icon, color: card.primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      card.title,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamHeader(BuildContext context, bool isWide) {
    return Row(
      children: [
        Expanded(
          child: _sectionTitle('Pantau Ujian Real-Time', isWide),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEA580C), Color(0xFFF97316)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF97316).withAlpha(60),
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
                MaterialPageRoute(builder: (_) => ExamFormScreen(subjectId: activeSubjectId)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      'Buat Ujian',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExamList(BuildContext context, bool isWide) {
    if (exams.isEmpty) {
      return _buildEmptyState('Belum ada ujian untuk mapel ini',
          Icons.quiz_outlined, isWide);
    }
    return Column(
      children: exams
          .map<Widget>((exam) => _buildExamCard(context, exam, isWide))
          .toList(),
    );
  }

  Widget _buildExamCard(BuildContext context, dynamic exam, bool isWide) {
    final liveSessions = fb.examSessions.where((s) => s.examId == exam.id).toList();
    final lockedCount = liveSessions.where((s) => s.isLocked).length;
    final hasIssue = lockedCount > 0;
    final isLive = liveSessions.isNotEmpty;
    final examModel = exam is ExamModel ? exam : null;
    final classList = (exam.classIds is List) ? (exam.classIds as List).cast<String>() : <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isWide ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasIssue
              ? const Color(0xFFFDA4AF)
              : (isWide ? AppColors.borderDark.withAlpha(80) : const Color(0xFFE2E8F0)),
          width: hasIssue ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: hasIssue
                ? const Color(0xFFF43F5E).withAlpha(20)
                : const Color(0xFF0F172A).withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TeacherExamMonitorScreen(exam: exam)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Device Icon + Title + Status Badges
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: hasIssue
                              ? [const Color(0xFFFFE4E6), const Color(0xFFFECDD3)]
                              : (isLive
                                  ? [const Color(0xFFDCFCE7), const Color(0xFFBBF7D0)]
                                  : [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)]),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasIssue
                              ? const Color(0xFFFDA4AF)
                              : (isLive ? const Color(0xFF86EFAC) : const Color(0xFFFED7AA)),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        hasIssue
                            ? Icons.lock_person_rounded
                            : (isLive ? Icons.sensors_rounded : Icons.computer_rounded),
                        color: hasIssue
                            ? const Color(0xFFE11D48)
                            : (isLive ? const Color(0xFF16A34A) : const Color(0xFFEA580C)),
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
                              ExamCategoryBadge(category: exam.category),
                              const SizedBox(width: 6),
                              if (isLive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF16A34A),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'LIVE',
                                        style: GoogleFonts.outfit(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF15803D),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            exam.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: isWide ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.groups_rounded, size: 13, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${classList.isEmpty ? "Semua Kelas" : classList.join(", ")}  •  ${liveSessions.length} Peserta',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Bottom Action Bar
                Row(
                  children: [
                    if (hasIssue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDA4AF)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_rounded, size: 11, color: Color(0xFFE11D48)),
                            const SizedBox(width: 4),
                            Text(
                              '$lockedCount Terkunci',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFE11D48),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    // Monitor button
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: hasIssue
                              ? [const Color(0xFFE11D48), const Color(0xFFF43F5E)]
                              : [const Color(0xFFEA580C), const Color(0xFFF97316)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: (hasIssue ? const Color(0xFFE11D48) : const Color(0xFFEA580C)).withAlpha(50),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TeacherExamMonitorScreen(exam: exam),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.remove_red_eye_rounded, size: 13, color: Colors.white),
                                const SizedBox(width: 5),
                                Text(
                                  'Monitor',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (examModel != null)
                      _buildMiniActionButton(
                        icon: Icons.copy_rounded,
                        color: const Color(0xFFEA580C),
                        tooltip: 'Duplikat Ujian',
                        onTap: () => DuplicateExamDialog.show(context, examModel),
                      ),
                    _buildMiniActionButton(
                      icon: Icons.edit_outlined,
                      color: const Color(0xFF2563EB),
                      tooltip: 'Edit Ujian',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExamFormScreen(
                            subjectId: exam.subjectId,
                            existingExam: exam,
                          ),
                        ),
                      ),
                    ),
                    _buildMiniActionButton(
                      icon: Icons.delete_outline_rounded,
                      color: const Color(0xFFE11D48),
                      tooltip: 'Hapus Ujian',
                      onTap: () => _confirmDeleteExam(context, exam),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: const EdgeInsets.all(6),
        tooltip: tooltip,
        icon: Icon(icon, size: 16, color: color),
        onPressed: onTap,
      ),
    );
  }

  void _confirmDeleteExam(BuildContext context, dynamic exam) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Hapus Ujian?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Ujian "${exam.title}" beserta seluruh sesi ujian siswa yang terkait akan dihapus secara permanen.',
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
              Navigator.pop(context);
              await showLoadingDialog(
                context,
                message: 'Menghapus jadwal ujian...',
                action: () async {
                  await fb.deleteExam(exam.id);
                },
                successMessage: 'Ujian berhasil dihapus.',
                errorMessage: 'Gagal menghapus ujian. Silakan coba lagi.',
              );
            },
            child: Text('Hapus', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialHeader(BuildContext context, bool isWide) {
    return Row(
      children: [
        Expanded(child: _sectionTitle('Materi Pelajaran', isWide)),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withAlpha(40),
                blurRadius: 8,
                offset: const Offset(0, 2),
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
                  builder: (_) => MaterialFormScreen(subjectId: activeSubjectId),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      'Tambah',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildMaterialList(BuildContext context, bool isWide) {
    if (materials.isEmpty) {
      return _buildEmptyState(
          'Belum ada materi pada mapel ini', Icons.book_outlined, isWide);
    }
    return Column(
      children: materials
          .map<Widget>((mat) => _buildMaterialCard(context, mat, isWide))
          .toList(),
    );
  }

  Widget _buildMaterialCard(BuildContext context, dynamic mat, bool isWide) {
    final material = mat as MaterialModel;
    final (icon, color, label) = _typeConfig(material.contentType);
    final fb = context.read<FirebaseService>();
    final assignments = fb.getAssignmentsForMaterial(material.id);
    final assignment = assignments.isNotEmpty ? assignments.first : null;

    // Assignment type badge config
    String? assignBadgeLabel;
    Color? assignBadgeColor;
    if (assignment != null) {
      switch (assignment.assignmentType) {
        case 'individu':
          assignBadgeLabel = '👤 Individu';
          assignBadgeColor = AppColors.primary;
          break;
        case 'kelompok':
          assignBadgeLabel = '👥 Kelompok';
          assignBadgeColor = const Color(0xFF1E40AF);
          break;
        case 'pilihan_ganda':
          assignBadgeLabel = '📝 Kuis PG';
          assignBadgeColor = Colors.orange.shade700;
          break;
      }
    }

    final schedDt = material.scheduledOpenAt;
    final schedStr = schedDt != null
        ? 'Buka: ${schedDt.day.toString().padLeft(2, '0')}/${schedDt.month.toString().padLeft(2, '0')}/${schedDt.year}'
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isWide ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWide ? AppColors.borderDark.withAlpha(80) : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MaterialDetailScreen(material: material)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withAlpha(60)),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            material.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isWide ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  label,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              Text(
                                '•',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                              ),
                              Text(
                                material.classIds.map((cid) => fb.schoolClasses.where((c) => c.id == cid).firstOrNull?.name ?? cid).join(", "),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              if (schedStr != null) ...[
                                Text(
                                  '•',
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFFEA580C)),
                                    const SizedBox(width: 2),
                                    Text(
                                      schedStr,
                                      style: GoogleFonts.outfit(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFEA580C),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildMiniActionButton(
                      icon: Icons.edit_outlined,
                      color: const Color(0xFF2563EB),
                      tooltip: 'Edit Materi',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MaterialFormScreen(
                            subjectId: material.subjectId,
                            existingMaterial: material,
                          ),
                        ),
                      ),
                    ),
                    _buildMiniActionButton(
                      icon: Icons.delete_outline_rounded,
                      color: const Color(0xFFE11D48),
                      tooltip: 'Hapus Materi',
                      onTap: () => _confirmDeleteMaterial(context, material),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),

                // Assignment badge + download row
                if (assignBadgeLabel != null || assignment != null) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (assignBadgeLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: assignBadgeColor!.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: assignBadgeColor.withAlpha(80)),
                          ),
                          child: Text(
                            assignBadgeLabel,
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: assignBadgeColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (assignment != null && material.classIds.isNotEmpty)
                        PopupMenuButton<String>(
                          tooltip: 'Download Nilai per Kelas',
                          onSelected: (classId) async {
                            final rows = fb.getGradeRowsByClass(
                              assignmentId: assignment.id,
                              classId: classId,
                            );
                            // Build Excel
                            final excel = _buildGradeExcel(
                              title: material.title,
                              classId: classId,
                              rows: rows,
                            );
                            final displayClassName = fb.schoolClasses.where((c) => c.id == classId).firstOrNull?.name ?? classId;
                            await ExcelService.downloadExcel(
                              bytes: excel,
                              fileName: 'Nilai_${material.title.replaceAll(' ', '_')}_$displayClassName.xlsx',
                            );
                          },
                          itemBuilder: (_) => material.classIds.map((cid) {
                            final className = fb.schoolClasses.where((c) => c.id == cid).firstOrNull?.name ?? cid;
                            return PopupMenuItem<String>(
                              value: cid,
                              child: Row(children: [
                                const Icon(Icons.download_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text('Download Nilai Kelas $className', style: GoogleFonts.outfit(fontSize: 13)),
                              ]),
                            );
                          }).toList(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.download_rounded, size: 13, color: Color(0xFF059669)),
                              const SizedBox(width: 4),
                              Text('Unduh Nilai',
                                  style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: const Color(0xFF059669),
                                      fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteMaterial(BuildContext context, MaterialModel material) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Hapus Materi?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Materi "${material.title}" beserta tugas dan penyerahan siswa terkait akan dihapus secara permanen.',
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
              Navigator.pop(context);
              await showLoadingDialog(
                context,
                message: 'Menghapus materi...',
                action: () => fb.deleteMaterial(material.id),
                successMessage: 'Materi berhasil dihapus.',
                errorMessage: 'Gagal menghapus materi.',
              );
            },
            child: Text('Hapus', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Uint8List _buildGradeExcel({
    required String title,
    required String classId,
    required List<List<dynamic>> rows,
  }) {
    // Use ExcelService's raw excel to build a full table
    // For now, build a simple records list compatible with generateNisAndScoreExcel
    // by extracting Nama & Nilai columns
    final records = rows.skip(1).map((row) => {
      'nis': row[0]?.toString() ?? '',
      'score': row[3]?.toString() ?? '-',
    }).toList();
    return ExcelService.generateNisAndScoreExcel(
      sheetTitle: '$title - Kelas $classId',
      records: records,
    );
  }

  Widget _buildEmptyState(String msg, IconData icon, bool isWide) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon,
              size: 36,
              color: isWide ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          const SizedBox(height: 8),
          Text(
            msg,
            style: TextStyle(
              color: isWide ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, String) _typeConfig(String type) {
    switch (type) {
      case 'youtube':
        return (Icons.play_circle_rounded, Colors.red, 'YouTube');
      case 'canva':
        return (Icons.palette_rounded, Colors.cyan, 'Canva');
      default:
        return (Icons.slideshow_rounded, Colors.orange, 'Presentasi');
    }
  }
}

class _StatItem {
  final IconData icon;
  final String value;
  final String label;
  final Color primaryColor;
  final Color lightColor;
  final Color borderColor;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback? onTap;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.primaryColor,
    required this.lightColor,
    required this.borderColor,
    this.badgeText,
    this.badgeColor,
    this.onTap,
  });
}

class _ActionCard {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color primaryColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryColor,
    required this.onTap,
  });
}

// ─── TEACHER EXAMS PAGE ──────────────────────────────────────────────────────
class _TeacherExamsPage extends StatefulWidget {
  final FirebaseService fb;
  final dynamic currentUser;
  final List<dynamic> taughtSubjects;
  final String activeSubjectId;
  final ValueChanged<String> onSubjectChanged;

  const _TeacherExamsPage({
    required this.fb,
    required this.currentUser,
    required this.taughtSubjects,
    required this.activeSubjectId,
    required this.onSubjectChanged,
  });

  @override
  State<_TeacherExamsPage> createState() => _TeacherExamsPageState();
}

class _TeacherExamsPageState extends State<_TeacherExamsPage> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _filterSubjectId;
  String _filterClass = 'all';
  String _filterCategory = 'all';

  @override
  void initState() {
    super.initState();
    _filterSubjectId = 'all';
    _filterClass = 'all';
    _filterCategory = 'all';
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _promptExportExcel(BuildContext context, ExamModel currentExam, List<ExamSessionModel> allSessions) {
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
                        color: AppColors.emerald.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.file_download_outlined, color: AppColors.emerald, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pilih Unduh Nilai Excel',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
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
                      color: AppColors.emerald.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.table_view_rounded, color: AppColors.emerald),
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
        'Berkas Excel "$fileName" berhasil diunduh. Berisi kolom NIS & NILAI saja.',
      );
    }
  }

  void _confirmDeleteExam(BuildContext context, dynamic exam) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Hapus Ujian?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Ujian "${exam.title}" beserta seluruh sesi ujian siswa yang terkait akan dihapus secara permanen.',
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
              Navigator.pop(context);
              await showLoadingDialog(
                context,
                message: 'Menghapus jadwal ujian...',
                action: () async {
                  await widget.fb.deleteExam(exam.id);
                },
                successMessage: 'Ujian berhasil dihapus.',
                errorMessage: 'Gagal menghapus ujian. Silakan coba lagi.',
              );
            },
            child: Text('Hapus', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fb = widget.fb;
    final allExams = fb.getTeacherExams(widget.currentUser);
    final displaySubjects = widget.taughtSubjects;
    final teacherClasses = fb.getTeacherClasses(widget.currentUser);

    final exams = allExams.where((e) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTitle = e.title.toLowerCase().contains(query);
        final matchDesc = e.description.toLowerCase().contains(query);
        if (!matchTitle && !matchDesc) return false;
      }
      if (_filterSubjectId != null && _filterSubjectId != 'all') {
        if (e.subjectId != _filterSubjectId) return false;
      }
      if (_filterClass != 'all') {
        if (e.classIds.isNotEmpty && !e.classIds.contains(_filterClass)) {
          return false;
        }
      }
      if (_filterCategory != 'all') {
        if (e.category.name != _filterCategory) return false;
      }
      return true;
    }).toList();

    final String resolvedSubjectId = (_filterSubjectId != null && _filterSubjectId != 'all')
        ? _filterSubjectId!
        : (displaySubjects.isNotEmpty ? displaySubjects.first.id : '');

    final missingCount = resolvedSubjectId.isEmpty ? 0 : widget.fb.getMissingImageQuestions(resolvedSubjectId).length;

    return Container(
      color: AppColors.backgroundLight,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Universal Header
            UniversalAppHeader(
              bottomContent: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.quiz_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Quiz & Ujian Guru',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'Pantau Real-Time, Buat Ujian & Ekspor Nilai',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExamFormScreen(subjectId: resolvedSubjectId),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 14),
                    label: const Text('Buat Ujian'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rose,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            // Body List
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Action Row
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QuestionBankScreen(initialSubjectId: resolvedSubjectId),
                              ),
                            ),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(8),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withAlpha(20),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Bank Soal (${fb.questions.length})',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MissingImagesValidatorScreen(subjectId: resolvedSubjectId),
                              ),
                            ),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(8),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: (missingCount > 0 ? AppColors.rose : AppColors.emerald).withAlpha(20),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      missingCount > 0 ? Icons.image_not_supported_outlined : Icons.check_circle_outline_rounded,
                                      color: missingCount > 0 ? AppColors.rose : AppColors.emerald,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      missingCount > 0 ? 'Cek Gambar ($missingCount)' : 'Gambar Valid',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: missingCount > 0 ? AppColors.rose : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Filter Panel: Search + 3 Dropdowns (Matching Design Model)
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(6),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search Input
                          TextField(
                            controller: _searchCtrl,
                            style: GoogleFonts.outfit(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Cari judul materi atau deskripsi...',
                              hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13),
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () => _searchCtrl.clear(),
                                    )
                                  : null,
                              filled: true,
                              fillColor: const Color(0xFFF1F5F9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Dropdown 1: Mapel (Full Width)
                          _buildFilterDropdown(
                            icon: Icons.menu_book_rounded,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: (displaySubjects.any((s) => s.id == _filterSubjectId) || _filterSubjectId == 'all')
                                    ? _filterSubjectId
                                    : 'all',
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                                style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                                items: [
                                  const DropdownMenuItem(
                                    value: 'all',
                                    child: Text('Semua Materi / Mapel'),
                                  ),
                                  ...displaySubjects.map((s) => DropdownMenuItem(
                                        value: s.id,
                                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                                      )),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _filterSubjectId = val);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Row: Dropdown 2 (Target Kelas) & Dropdown 3 (Jenis Tugas / Ujian)
                          Row(
                            children: [
                              Expanded(
                                child: _buildFilterDropdown(
                                  icon: Icons.school_rounded,
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: (teacherClasses.contains(_filterClass) || _filterClass == 'all')
                                          ? _filterClass
                                          : 'all',
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                                      style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                                      items: [
                                        const DropdownMenuItem(
                                          value: 'all',
                                          child: Text('Semua Kelas'),
                                        ),
                                        ...teacherClasses.map((cls) => DropdownMenuItem(
                                              value: cls,
                                              child: Text('Kelas $cls', overflow: TextOverflow.ellipsis),
                                            )),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _filterClass = val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildFilterDropdown(
                                  icon: Icons.assignment_outlined,
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _filterCategory,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                                      style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                                      items: [
                                        const DropdownMenuItem(
                                          value: 'all',
                                          child: Text('Semua Jenis Ujian'),
                                        ),
                                        ...ExamCategory.values.map((cat) => DropdownMenuItem(
                                              value: cat.name,
                                              child: Text(cat.label, overflow: TextOverflow.ellipsis),
                                            )),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _filterCategory = val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Reset button if filters applied
                          if ((_filterSubjectId != null && _filterSubjectId != 'all') ||
                              _filterClass != 'all' ||
                              _filterCategory != 'all' ||
                              _searchQuery.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _searchCtrl.clear();
                                    _filterSubjectId = 'all';
                                    _filterClass = 'all';
                                    _filterCategory = 'all';
                                  });
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.refresh_rounded, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Reset Filter',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daftar Ujian (${exams.length})',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Text(
                          'Real-Time Live',
                          style: TextStyle(fontSize: 12, color: AppColors.emerald, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (exams.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            const Icon(Icons.quiz_outlined, size: 48, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 10),
                            Text(
                              'Belum ada kuis atau ujian untuk mapel ini',
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ExamFormScreen(subjectId: resolvedSubjectId),
                                ),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Buat Ujian Sekarang'),
                              style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
                            ),
                          ],
                        ),
                      )
                    else
                      ...exams.map((exam) {
                        final liveSessions = fb.examSessions.where((s) => s.examId == exam.id).toList();
                        final lockedCount = liveSessions.where((s) => s.isLocked).length;
                        final hasIssue = lockedCount > 0;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TeacherExamMonitorScreen(exam: exam),
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: hasIssue
                                      ? AppColors.rose.withAlpha(120)
                                      : const Color(0xFFE2E8F0),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: hasIssue ? AppColors.rose.withAlpha(20) : Colors.black.withAlpha(10),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: (hasIssue ? AppColors.rose : AppColors.primary).withAlpha(20),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          hasIssue ? Icons.lock_person_rounded : Icons.desktop_windows_rounded,
                                          color: hasIssue ? AppColors.rose : AppColors.primary,
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
                                                ExamCategoryBadge(category: exam.category),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    exam.title,
                                                    style: GoogleFonts.outfit(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withAlpha(15),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '${liveSessions.length} Peserta',
                                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF8B5CF6).withAlpha(15),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.groups_rounded, size: 12, color: Color(0xFF8B5CF6)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        exam.classIds.isEmpty ? 'Semua Kelas' : exam.classIds.join(', '),
                                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (hasIssue)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.rose.withAlpha(20),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      '$lockedCount Terkunci',
                                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.rose),
                                                    ),
                                                  ),
                                                Text(
                                                  '• ${exam.durationMinutes} Menit • ${exam.questionIds.length} Soal',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => TeacherExamMonitorScreen(exam: exam),
                                            ),
                                          ),
                                          icon: const Icon(Icons.visibility_rounded, size: 14),
                                          label: const Text('Monitor Real-Time'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: hasIssue ? AppColors.rose : AppColors.primary,
                                            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        tooltip: 'Duplikat Ujian ke Kelas Lain',
                                        icon: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
                                        onPressed: () => DuplicateExamDialog.show(context, exam),
                                      ),
                                      IconButton(
                                        tooltip: 'Unduh Excel Nilai (Pilihan Per Kelas)',
                                        icon: const Icon(Icons.file_download_outlined, color: AppColors.emerald, size: 20),
                                        onPressed: () => _promptExportExcel(context, exam, liveSessions),
                                      ),
                                      IconButton(
                                        tooltip: 'Edit Ujian',
                                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF3B82F6), size: 20),
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ExamFormScreen(
                                              subjectId: exam.subjectId,
                                              existingExam: exam,
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Hapus Ujian',
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                        onPressed: () => _confirmDeleteExam(context, exam),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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
    );
  }

  Widget _buildFilterDropdown({
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ─── TEACHER PROFILE PAGE ────────────────────────────────────────────────────
class _TeacherProfilePage extends StatelessWidget {
  final UserModel? currentUser;
  final FirebaseService fb;
  final List<dynamic> taughtSubjects;

  const _TeacherProfilePage({
    required this.currentUser,
    required this.fb,
    required this.taughtSubjects,
  });

  void _showEditProfileDialog(BuildContext context) {
    if (currentUser == null) return;
    final nameCtrl = TextEditingController(text: currentUser!.fullName);
    final passCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final selectedClasses = List<String>.from(fb.getTeacherClasses(currentUser));
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Edit Profil Guru',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Perbarui nama lengkap, kelas yang diajar, dan kata sandi akun guru Anda.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nama Lengkap Beserta Gelar',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Kelas yang Diajar (Ditetapkan oleh Admin):',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Daftar kelas dan mata pelajaran ditentukan sepenuhnya oleh Admin melalui Master Data Guru. Hubungi Admin jika terdapat perubahan tugas mengajar:',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    if (selectedClasses.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Belum ada kelas yang diplot untuk akun Anda oleh Admin.',
                                style: TextStyle(fontSize: 11.5, color: Colors.brown),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: selectedClasses.map((cName) {
                          return Chip(
                            avatar: const Icon(Icons.school_rounded, size: 14, color: AppColors.primary),
                            label: Text(cName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            backgroundColor: AppColors.primary.withAlpha(20),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Password Baru (Opsional)',
                        hintText: 'Biarkan kosong jika tidak ingin mengubah',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setModalState(() => obscure = !obscure),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: confirmPassCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Konfirmasi Password Baru',
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        if (passCtrl.text.isNotEmpty && v != passCtrl.text) {
                          return 'Konfirmasi password tidak cocok';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            final newName = nameCtrl.text.trim();
                            final newPass = passCtrl.text.isNotEmpty ? passCtrl.text : null;
                            if (ctx.mounted) Navigator.pop(ctx);
                            await showLoadingDialog(
                              context,
                              message: 'Memperbarui profil guru...',
                              action: () => fb.updateTeacherProfile(
                                teacherId: currentUser!.id,
                                fullName: newName,
                                newPassword: newPass,
                              ),
                              successMessage: 'Profil guru berhasil diperbarui!',
                              errorMessage: 'Gagal memperbarui profil.',
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('Simpan Perubahan', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSidikmuAccountDialog(BuildContext context) {
    if (currentUser == null) return;
    final urlCtrl = TextEditingController(text: currentUser!.sidikmuUrl ?? SidikmuService.defaultUrl);
    final userCtrl = TextEditingController(text: currentUser!.sidikmuUsername ?? '');
    final passCtrl = TextEditingController(text: currentUser!.sidikmuPassword ?? '');
    final formKey = GlobalKey<FormState>();
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isConnected = currentUser!.hasSidikmuAccount;
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF0284C7), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Integrasi Akun SidikMu',
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                'Tautkan akun SidikMu untuk sinkronisasi nilai otomatis',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: urlCtrl,
                      decoration: InputDecoration(
                        labelText: 'URL Web Portal SidikMu',
                        hintText: 'https://smpm12gkb.sidikmu.com',
                        prefixIcon: const Icon(Icons.language_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'URL tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: userCtrl,
                      decoration: InputDecoration(
                        labelText: 'Username SidikMu',
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Username tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: passCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Password SidikMu',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setModalState(() => obscure = !obscure),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Password tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        if (isConnected) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: ctx,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Putuskan Akun SidikMu?'),
                                    content: const Text('Kredensial SidikMu akan dihapus dari akun guru ini.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('Putuskan', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  await fb.clearTeacherSidikmuCredentials(teacherId: currentUser!.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Akun SidikMu berhasil diputuskan.')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.link_off_rounded, color: Colors.red, size: 18),
                              label: const Text('Putuskan', style: TextStyle(color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: Colors.red.shade200),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (formKey.currentState?.validate() ?? false) {
                                final cleanUrl = urlCtrl.text.trim();
                                final cleanUser = userCtrl.text.trim();
                                final cleanPass = passCtrl.text.trim();
                                Navigator.pop(ctx);
                                await showLoadingDialog(
                                  context,
                                  message: 'Menyimpan kredensial SidikMu...',
                                  action: () => fb.updateTeacherSidikmuCredentials(
                                    teacherId: currentUser!.id,
                                    sidikmuUrl: cleanUrl,
                                    sidikmuUsername: cleanUser,
                                    sidikmuPassword: cleanPass,
                                  ),
                                  successMessage: 'Akun SidikMu berhasil ditautkan!',
                                  errorMessage: 'Gagal menyimpan akun SidikMu.',
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: Text(
                              'Simpan Akun SidikMu',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.rose.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, color: AppColors.rose, size: 20),
            ),
            const SizedBox(width: 10),
            Text('Keluar Akun Guru?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: const Text('Apakah Anda yakin ingin keluar dari akun guru ini? Anda perlu memasukkan username dan kata sandi kembali untuk masuk.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () {
              Navigator.pop(context);
              fb.logout();
            },
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUser;
    final totalStudents = fb.getTeacherStudents(user).length;
    final totalExams = fb.getTeacherExams(user).length;
    final totalMaterials = fb.getTeacherMaterials(user).length;
    final totalQuestions = fb.getTeacherQuestions(user).length;

    final subjectNames = taughtSubjects.map((s) => s.name.toString()).toList();
    final classesTaught = fb.getTeacherClasses(user);

    return Container(
      color: AppColors.backgroundLight,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Universal Header
            UniversalAppHeader(
              bottomContent: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Profil & Manajemen Guru',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'Informasi Akun, Pengaturan & Menu Guru',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _confirmLogout(context),
                    tooltip: 'Keluar / Logout',
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            // Profile Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 130),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Unified Teacher Profile Card (Compact & Cohesive)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top: Avatar + Name + NIP + Edit Button
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF38BDF8), Color(0xFFA855F7), Color(0xFFEC4899)],
                                  ),
                                ),
                                padding: const EdgeInsets.all(2.5),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primaryDark,
                                  ),
                                  child: Center(
                                    child: Text(
                                      user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'G',
                                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.fullName ?? 'Bapak/Ibu Guru',
                                      style: GoogleFonts.outfit(fontSize: 15.5, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'NIP: ${user?.nis ?? user?.username ?? '-'} • Guru Pengajar',
                                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _showEditProfileDialog(context),
                                  borderRadius: BorderRadius.circular(20),
                                  splashColor: AppColors.primary.withAlpha(30),
                                  highlightColor: AppColors.primary.withAlpha(15),
                                  child: Ink(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primary.withAlpha(24),
                                          AppColors.primary.withAlpha(12),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.primary.withAlpha(90),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withAlpha(20),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.edit_note_rounded,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Edit Profil',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),

                          // Teaching Scope (Mapel & Kelas Diajar)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.menu_book_rounded, size: 13, color: AppColors.primary),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'Mapel: ',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                    ),
                                    Expanded(
                                      child: Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: subjectNames.isNotEmpty
                                            ? subjectNames.map((s) => Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEFF6FF),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                                  ),
                                                  child: Text(
                                                    s,
                                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                                                  ),
                                                )).toList()
                                            : [const Text('Semua Mapel', style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic))],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.groups_rounded, size: 13, color: Color(0xFF8B5CF6)),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'Kelas: ',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                    ),
                                    Expanded(
                                      child: Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: classesTaught.isNotEmpty
                                            ? classesTaught.map((c) => Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF3E8FF),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFDDD6FE)),
                                                  ),
                                                  child: Text(
                                                    c,
                                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF6D28D9)),
                                                  ),
                                                )).toList()
                                            : [const Text('Semua Kelas', style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic))],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // 4 Quick Stats in One Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.people_alt_rounded,
                                  value: '$totalStudents',
                                  label: 'Siswa',
                                  color: const Color(0xFF0D2B6E),
                                  bg: const Color(0xFFEFF6FF),
                                  border: const Color(0xFFBFDBFE),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.quiz_rounded,
                                  value: '$totalExams',
                                  label: 'Ujian',
                                  color: const Color(0xFFEA580C),
                                  bg: const Color(0xFFFFF7ED),
                                  border: const Color(0xFFFED7AA),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.auto_stories_rounded,
                                  value: '$totalMaterials',
                                  label: 'Materi',
                                  color: const Color(0xFF0284C7),
                                  bg: const Color(0xFFF0F9FF),
                                  border: const Color(0xFFBAE6FD),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.inventory_2_rounded,
                                  value: '$totalQuestions',
                                  label: 'Bank Soal',
                                  color: const Color(0xFFD97706),
                                  bg: const Color(0xFFFFFBEB),
                                  border: const Color(0xFFFDE68A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // SidikMu Account Integration Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFF0F9FF),
                            Colors.white,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withAlpha(15),
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
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withAlpha(30),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.cloud_sync_rounded,
                                  color: Color(0xFF0284C7),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Portal SidikMu',
                                          style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (user?.hasSidikmuAccount == true)
                                                ? const Color(0xFFDCFCE7)
                                                : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: (user?.hasSidikmuAccount == true)
                                                  ? const Color(0xFF86EFAC)
                                                  : Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            (user?.hasSidikmuAccount == true) ? 'Terhubung' : 'Belum Ditautkan',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: (user?.hasSidikmuAccount == true)
                                                  ? const Color(0xFF15803D)
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      (user?.hasSidikmuAccount == true)
                                          ? 'User: ${user?.sidikmuUsername} • Sinkronisasi Siap'
                                          : 'Tautkan akun untuk sinkronisasi nilai tugas & ujian',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _showSidikmuAccountDialog(context),
                                  borderRadius: BorderRadius.circular(20),
                                  splashColor: Colors.white24,
                                  child: Ink(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF0284C7).withAlpha(80),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          (user?.hasSidikmuAccount == true)
                                              ? Icons.tune_rounded
                                              : Icons.link_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          (user?.hasSidikmuAccount == true) ? 'Kelola' : 'Tautkan',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Teacher Management Tools
                    Row(
                      children: [
                        const Icon(Icons.grid_view_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Pintasan Pengelolaan Guru',
                          style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildToolTile(
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.primary,
                      title: 'Bank Soal & Kisi-Kisi',
                      subtitle: 'Kelola butir soal pilihan ganda & esai',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const QuestionBankScreen(initialSubjectId: 'subj_web')),
                      ),
                    ),
                    _buildToolTile(
                      icon: Icons.checklist_rtl_rounded,
                      color: const Color(0xFF8B5CF6),
                      title: 'Capaian Pembelajaran (CP & TP)',
                      subtitle: 'Atur capaian dan tujuan pembelajaran',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CpTpManagerScreen()),
                      ),
                    ),
                    _buildToolTile(
                      icon: Icons.class_outlined,
                      color: const Color(0xFF0284C7),
                      title: 'Kelola Kelas Sekolah',
                      subtitle: 'Tambah dan kelola rombel kelas siswa',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SchoolClassManagerScreen()),
                      ),
                    ),
                    _buildToolTile(
                      icon: Icons.badge_outlined,
                      color: const Color(0xFF10B981),
                      title: 'Roster & Kredensial Siswa',
                      subtitle: 'Pantau NIS dan password awal siswa',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StudentRosterScreen()),
                      ),
                    ),
                    _buildToolTile(
                      icon: Icons.notifications_active_rounded,
                      color: const Color(0xFF0D9488),
                      title: 'Uji Pop-Up Notifikasi',
                      subtitle: 'Tes pop-up status bar HP & banner melayang seketika',
                      onTap: () => FcmService.triggerTestNotification(context),
                    ),
                    _buildToolTile(
                      icon: Icons.system_update_rounded,
                      color: const Color(0xFF6366F1),
                      title: 'Pembaruan Aplikasi',
                      subtitle: 'Periksa ketersediaan rilis versi aplikasi terbaru',
                      onTap: () => AppUpdateDialog.handleManualUpdateCheck(context),
                    ),
                    const SizedBox(height: 10),

                    // Logout Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.rose.withAlpha(50)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.rose.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.logout_rounded, color: AppColors.rose, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Keluar dari Aplikasi',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.rose),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Sesi akun guru Anda akan diakhiri.',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _confirmLogout(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.rose,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required Color bg,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: color.withAlpha(200),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildToolTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
        trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
      ),
    );
  }
}

// ─── TEACHER OVAL BOTTOM NAV (Exact Student Styling) ─────────────────────────
class _TeacherOvalBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _TeacherOvalBottomNav({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.primary;
    final items = [
      const _TeacherNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
        color: activeColor,
      ),
      const _TeacherNavItem(
        icon: Icons.quiz_outlined,
        activeIcon: Icons.quiz_rounded,
        label: 'Quiz',
        color: activeColor,
      ),
      const _TeacherNavItem(
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book_rounded,
        label: 'Materi',
        color: activeColor,
      ),
      const _TeacherNavItem(
        icon: Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_bubble_rounded,
        label: 'Pesan',
        color: activeColor,
      ),
      const _TeacherNavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile',
        color: activeColor,
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
            boxShadow: AppColors.floatingShadow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = selectedIndex == index;
              return Expanded(
                child: _TeacherNavTabButton(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => onTap(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TeacherNavTabButton extends StatelessWidget {
  final _TeacherNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _TeacherNavTabButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: isSelected
            ? BoxDecoration(
                color: item.color.withAlpha(22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: item.color.withAlpha(70)),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              size: 22,
              color: isSelected ? item.color : const Color(0xFF64748B),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? item.color : const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;

  const _TeacherNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });
}


