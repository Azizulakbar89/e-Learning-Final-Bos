import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/assignment_model.dart';
import '../../../core/models/curriculum_model.dart';
import '../../../core/models/exam_model.dart';
import '../../../core/models/question_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_nav_rail.dart';
import '../../../core/widgets/exam_category_badge.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/universal_app_header.dart';
import '../../code_compiler/screens/code_playground_screen.dart';
import '../../exams/screens/exam_taking_screen.dart';
import '../../exams/screens/student_exams_screen.dart';
import '../../materials/screens/material_detail_screen.dart';
import '../../materials/screens/student_materials_screen.dart';
import '../../social_and_gamification/screens/point_redemption_screen.dart';
import '../../social_and_gamification/screens/student_leaderboard_screen.dart';
import 'student_profile_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _currentNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final currentUser = fb.currentUser;
    final totalPoints = currentUser?.totalPoints ?? 0;
    final materials =
        currentUser != null ? fb.getMaterialsForUser(currentUser) : fb.materials;
    final exams = currentUser != null ? fb.getExamsForStudent(currentUser) : fb.exams;
    final highestStreak = fb.getEffectiveStreakCount(currentUser?.id);
    final uncompletedQuizCount = currentUser != null
        ? fb.getUncompletedExamsCount(currentUser)
        : 0;

    final List<Widget> pages = [
      _DashboardPage(
        fb: fb,
        currentUser: currentUser,
        totalPoints: totalPoints,
        highestStreak: highestStreak,
        materials: materials,
        exams: exams,
        uncompletedQuizCount: uncompletedQuizCount,
        onNavTap: (i) => setState(() => _currentNavIndex = i),
      ),
      const StudentMaterialsScreen(),
      const StudentExamsScreen(),
      const StudentLeaderboardScreen(),
      StudentProfileScreen(
        onOpenLeaderboard: () => setState(() => _currentNavIndex = 3),
      ),
    ];

    final desktopNavItems = [
      const AppNavRailItem(
        label: 'Beranda',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
      const AppNavRailItem(
        label: 'Materi Belajar',
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book_rounded,
      ),
      AppNavRailItem(
        label: 'Quiz & Ujian',
        icon: Icons.quiz_outlined,
        selectedIcon: Icons.quiz_rounded,
        badge: uncompletedQuizCount > 0 ? '$uncompletedQuizCount' : null,
      ),
      const AppNavRailItem(
        label: 'Peringkat Kelas',
        icon: Icons.emoji_events_outlined,
        selectedIcon: Icons.emoji_events_rounded,
      ),
      const AppNavRailItem(
        label: 'Profil & Lencana',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
      ),
    ];

    return ResponsiveLayout(
      mobile: _buildMobileLayout(pages, uncompletedQuizCount),
      desktop: _buildDesktopLayout(
        pages,
        currentUser,
        totalPoints,
        highestStreak,
        fb,
        desktopNavItems,
        uncompletedQuizCount,
      ),
    );
  }

  // ─── MOBILE ────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(List<Widget> pages, int uncompletedQuizCount) {
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
          child: _OvalBottomNav(
            selectedIndex: _currentNavIndex,
            uncompletedQuizCount: uncompletedQuizCount,
            onTap: (idx) => setState(() => _currentNavIndex = idx),
          ),
        ),
      ),
    );
  }

  // ─── DESKTOP ────────────────────────────────────────────────────────────────
  Widget _buildDesktopLayout(
    List<Widget> pages,
    dynamic currentUser,
    int totalPoints,
    int highestStreak,
    FirebaseService fb,
    List<AppNavRailItem> navItems,
    int uncompletedQuizCount,
  ) {
    return Scaffold(
      extendBody: true,
      body: Row(
        children: [
          // Sidebar
          AppNavRail(
            selectedIndex: _currentNavIndex,
            onDestinationSelected: (i) => setState(() => _currentNavIndex = i),
            items: navItems,
            header: _buildSidebarHeader(currentUser, totalPoints, highestStreak),
            footer: _buildSidebarFooter(fb),
          ),
          // Main Content
          Expanded(
            child: IndexedStack(
              index: _currentNavIndex,
              children: pages,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(dynamic currentUser, int totalPoints, int highestStreak) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderDark.withAlpha(80))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App brand
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
          const SizedBox(height: 20),
          // User avatar + info
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    currentUser?.fullName.isNotEmpty == true
                        ? currentUser!.fullName[0].toUpperCase()
                        : 'S',
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
                      currentUser?.fullName ?? 'Siswa',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Kelas ${currentUser?.classId ?? "-"}',
                      style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Stats row
          Row(
            children: [
              _sidebarStatChip('🔥', '$highestStreak', AppColors.streakFire),
              const SizedBox(width: 8),
              _sidebarStatChip('🌟', '$totalPoints', Colors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sidebarStatChip(String emoji, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
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

// ─── DASHBOARD PAGE ──────────────────────────────────────────────────────────
class _DashboardPage extends StatefulWidget {
  final FirebaseService fb;
  final dynamic currentUser;
  final int totalPoints;
  final int highestStreak;
  final List<dynamic> materials;
  final List<dynamic> exams;
  final int uncompletedQuizCount;
  final ValueChanged<int> onNavTap;

  const _DashboardPage({
    required this.fb,
    required this.currentUser,
    required this.totalPoints,
    required this.highestStreak,
    required this.materials,
    required this.exams,
    required this.uncompletedQuizCount,
    required this.onNavTap,
  });

  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  @override
  Widget build(BuildContext context) {
    final isWide = isDesktop(context);

    return Container(
      color: isWide ? const Color(0xFF040D1F) : AppColors.backgroundLight,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── Sticky Modern Curved Header (Matching Screenshot) ───
            if (!isWide)
              const UniversalAppHeader(),

            // Scrollable Page Content
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  isWide ? 32 : 16,
                  isWide ? 32 : 16,
                  isWide ? 32 : 16,
                  130, // Avoid overlap with bottom nav
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Desktop greeting
                    if (isWide) ...[
                      Text(
                        'Selamat Datang, ${widget.currentUser?.fullName?.split(' ').first ?? "Siswa"} 👋',
                        style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'NIS: ${widget.currentUser?.nis ?? "-"}  •  Kelas: ${widget.currentUser?.classId ?? "-"}',
                        style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                    ],


                    // ─── Nilai Mata Pelajaran Section (Akumulasi Nilai per Mapel Langsung di Bawahnya Tanpa Jarak Jauh) ───
                    _buildSubjectGradesSection(context, isWide),
                    const SizedBox(height: 20),

                    // Content Sections: Exams and Materials
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _buildSectionHeader(
                                  'Ujian & Kuis Aktif',
                                  isWide,
                                  badge: 'Anti-Cheat',
                                  badgeColor: AppColors.rose,
                                  onSeeAll: () => widget.onNavTap(2),
                                ),
                                const SizedBox(height: 12),
                                _buildExamList(context, isWide),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _buildSectionHeader(
                                  'Materi Pembelajaran',
                                  isWide,
                                  onSeeAll: () => widget.onNavTap(1),
                                ),
                                const SizedBox(height: 12),
                                _buildMaterialList(context, isWide),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildSectionHeader(
                        'Ujian & Kuis Aktif',
                        isWide,
                        badge: 'Anti-Cheat',
                        badgeColor: AppColors.rose,
                        onSeeAll: () => widget.onNavTap(2),
                      ),
                      const SizedBox(height: 12),
                      _buildExamList(context, isWide),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        'Materi Pembelajaran',
                        isWide,
                        onSeeAll: () => widget.onNavTap(1),
                      ),
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
    );
  }

  // ignore: unused_element
  Widget _buildGamificationAndCompilerRow(BuildContext context, bool isWide) {
    return Row(
      children: [
        // Kartu 1: Poin Gamifikasi
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PointRedemptionScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('🌟', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${widget.totalPoints}',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Poin Gamifikasi',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Kartu 2: Compiler Koding IDE
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CodePlaygroundScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('💻', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Compiler',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Koding IDE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }


  // ═══════════════════════════════════════════════════════════════════════════════
  //  NILAI MATA PELAJARAN (Subject Grades Section)
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildSubjectGradesSection(BuildContext context, bool isWide) {
    if (widget.currentUser == null) return const SizedBox.shrink();

    final grades = widget.fb.getStudentSubjectGrades(widget.currentUser!);
    final validGrades = grades.where((g) => g.finalGrade != null).toList();
    final double? gpa = validGrades.isNotEmpty
        ? (validGrades.map((g) => g.finalGrade!).reduce((a, b) => a + b) / validGrades.length)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.analytics_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nilai Mata Pelajaran',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isWide ? Colors.white : const Color(0xFF071540),
                    ),
                  ),
                  Text(
                    gpa != null
                        ? 'Rata-rata: ${gpa.toStringAsFixed(1)} • ${gpa >= 88 ? "Sangat Baik" : gpa >= 75 ? "Baik" : "Cukup"}'
                        : 'Akumulasi nilai kuis, ujian, tugas & bonus gamifikasi',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (gpa != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981).withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, size: 13, color: Color(0xFF10B981)),
                    const SizedBox(width: 3),
                    Text(
                      'Rata-rata: ${gpa.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // List of Subject Cards (Dynamic height, zero overflow)
        if (grades.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Center(
              child: Text(
                'Belum ada data mata pelajaran',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          )
        else
          Column(
            children: List.generate(grades.length, (idx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSubjectGradeCard(context, grades[idx], idx, isWide, widget.fb),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildSubjectGradeCard(
    BuildContext context,
    StudentSubjectGrade grade,
    int index,
    bool isWide,
    FirebaseService fb,
  ) {
    IconData getSubjectIcon(String code) {
      final c = code.toLowerCase();
      if (c.contains('inf') || c.contains('web')) return Icons.code_rounded;
      if (c.contains('bd') || c.contains('sql') || c.contains('data')) return Icons.storage_rounded;
      if (c.contains('pbo') || c.contains('oop')) return Icons.terminal_rounded;
      if (c.contains('jaringan') || c.contains('net')) return Icons.lan_rounded;
      return Icons.school_rounded;
    }

    final double progress = ((grade.finalGrade ?? 0) / 100).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: isWide ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isWide ? AppColors.borderDark.withAlpha(80) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showSubjectGradeDetailModal(context, grade, fb),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Icon + Subject Info + Grade Score Pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: grade.statusColor.withAlpha(16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: grade.statusColor.withAlpha(45)),
                    ),
                    child: Center(
                      child: Icon(
                        getSubjectIcon(grade.subject.code),
                        size: 20,
                        color: grade.statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          grade.subject.name,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: -0.2,
                            color: isWide ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                grade.subject.code,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                grade.predicate,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: grade.statusColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Score Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: grade.statusColor.withAlpha(12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: grade.statusColor.withAlpha(40)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          grade.finalGrade != null ? '${grade.finalGrade}' : '-',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: grade.statusColor,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          grade.finalGrade != null
                              ? (grade.finalGrade! >= 88 ? 'A' : grade.finalGrade! >= 75 ? 'B' : grade.finalGrade! >= 65 ? 'C' : 'D')
                              : 'Siap Belajar',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: grade.statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Middle: Progress Bar
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(grade.statusColor),
                  ),
                ),
              ),

              // Bottom Row: Metrics (Exams, Assignments, Gamification Bonus)
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _gradePill('📝', '${grade.completedExams}/${grade.totalExams} Ujian'),
                        _gradePill('📋', '${grade.completedAssignments} Tugas'),
                        if (grade.bonusGrade > 0)
                          _gradePill('💎', '+${grade.bonusGrade} Poin Bonus', color: AppColors.purple),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gradePill(String emoji, String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color ?? const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  void _showSubjectGradeDetailModal(
    BuildContext context,
    StudentSubjectGrade grade,
    FirebaseService fb,
  ) {
    final studentId = widget.currentUser?.id ?? '';
    final subjectExams = fb.exams.where((e) => e.subjectId == grade.subject.id).toList();
    final subjectSessions = fb.examSessions.where((s) =>
        s.studentId == studentId &&
        s.isCompleted &&
        subjectExams.any((e) => e.id == s.examId)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
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

              // Title Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: grade.statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.analytics_rounded, color: grade.statusColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          grade.subject.name,
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Kode: ${grade.subject.code} • Transkrip Nilai Siswa',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Big Score Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: grade.statusColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: grade.statusColor.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nilai Akhir Mapel',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          grade.predicate,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: grade.statusColor,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: grade.statusColor.withAlpha(80)),
                      ),
                      child: Text(
                        grade.finalGrade != null ? '${grade.finalGrade}' : '-',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: grade.statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Rincian Nilai
              Text(
                'Rincian Komponen Nilai:',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // Exam Average row
              _detailMetricTile(
                '📝 Rata-rata Kuis & Ujian (60%)',
                grade.examAverage != null ? grade.examAverage!.toStringAsFixed(1) : 'Belum Ada Ujian',
                '${grade.completedExams} dari ${grade.totalExams} ujian selesai',
                Colors.blue,
              ),
              const SizedBox(height: 8),

              // Assignment Average row
              _detailMetricTile(
                '📋 Rata-rata Tugas & Proyek (40%)',
                grade.assignmentAverage != null ? grade.assignmentAverage!.toStringAsFixed(1) : 'Belum Ada Tugas Dinilai',
                '${grade.completedAssignments} tugas dikumpulkan',
                AppColors.emerald,
              ),
              const SizedBox(height: 8),

              // Gamification bonus row
              _detailMetricTile(
                '💎 Bonus Poin Gamifikasi',
                '+${grade.bonusGrade} Poin',
                'Ditukarkan melalui fitur Redeem Poin',
                Colors.purple,
              ),
              const SizedBox(height: 16),

              // List of completed exams in this subject
              if (subjectSessions.isNotEmpty) ...[
                Text(
                  'Riwayat Ujian Mapel Ini:',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...subjectSessions.map((session) {
                  final examTitle = subjectExams.firstWhere((e) => e.id == session.examId, orElse: () => ExamModel(id: '', subjectId: '', teacherId: '', classIds: [], title: 'Ujian', description: '', questionIds: [], createdAt: DateTime.now())).title;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.emerald),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            examTitle,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Nilai: ${session.finalScore?.toStringAsFixed(1) ?? "-"}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 14),
              ],

              // Formula Note
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rumus: (Ujian × 60%) + (Tugas × 40%) + Bonus Gamifikasi (Maks. 100).',
                        style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Button to redeem points
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.stars_rounded, size: 18),
                  label: const Text('Tukar Poin untuk Tambah Nilai'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PointRedemptionScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailMetricTile(String title, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    bool isWide, {
    String? badge,
    Color? badgeColor,
    VoidCallback? onSeeAll,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isWide ? Colors.white : const Color(0xFF071540),
            ),
          ),
        ),
        if (badge != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (badgeColor ?? AppColors.primary).withAlpha(20),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: (badgeColor ?? AppColors.primary).withAlpha(70)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 11, color: badgeColor ?? AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    color: badgeColor ?? AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (onSeeAll != null)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onSeeAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lihat Semua',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.primary),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExamList(BuildContext context, bool isWide) {
    if (widget.exams.isEmpty) {
      return _buildEmptyState('Tidak ada ujian aktif saat ini', Icons.quiz_outlined, isWide);
    }
    return Column(
      children: widget.exams.map<Widget>((exam) => _buildExamCard(context, exam, isWide)).toList(),
    );
  }

  Widget _buildExamCard(BuildContext context, dynamic exam, bool isWide) {
    final fb = context.watch<FirebaseService>();
    final currentUser = fb.currentUser;
    final subject = fb.subjects.where((s) => s.id == exam.subjectId).firstOrNull;
    final subjectName = subject?.name ?? 'Mata Pelajaran';
    final isDone = currentUser != null &&
        fb.isExamFinishedForStudent(examId: exam.id, studentId: currentUser.id);
    final session = fb.examSessions
        .where((s) => s.examId == exam.id && s.studentId == currentUser?.id)
        .firstOrNull;
    final score = session?.finalScore ?? session?.nonEssayScore;
    final examQuestions = fb.questions.where((q) => exam.questionIds.contains(q.id)).toList();
    final essayQuestions = examQuestions.where((q) => q.type == QuestionType.essay).toList();
    final hasEssay = essayQuestions.isNotEmpty;
    final isGraded = !hasEssay || (session != null && session.essayScores.length >= essayQuestions.length);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isWide ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isWide ? AppColors.borderDark.withAlpha(80) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDone
                    ? const Color(0xFF10B981).withAlpha(16)
                    : AppColors.orange.withAlpha(16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDone
                      ? const Color(0xFF10B981).withAlpha(45)
                      : AppColors.orange.withAlpha(45),
                ),
              ),
              child: Icon(
                isDone ? Icons.check_circle_rounded : Icons.timer_rounded,
                color: isDone ? const Color(0xFF059669) : AppColors.orange,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book_rounded, size: 11, color: Color(0xFF475569)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                subjectName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: ExamCategoryBadge(category: exam.category),
                      ),
                    ],
                  ),
                  Text(
                    exam.title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isWide ? Colors.white : const Color(0xFF071540),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    exam.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _examChip('${exam.durationMinutes} Menit', Icons.timer_outlined, isWide),
                      const SizedBox(width: 8),
                      _examChip('${exam.questionIds.length} Soal', Icons.list_alt_rounded, isWide),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isDone)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Row(
                        children: [
                          const Icon(Icons.military_tech_rounded, color: AppColors.orange, size: 26),
                          const SizedBox(width: 8),
                          Text('Hasil Ujian', style: GoogleFonts.outfit(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
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
                            ),
                            child: Text(
                              subjectName,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Ujian: ${exam.title}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.navy.withAlpha(10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.navy.withAlpha(35)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Nilai Diperoleh:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                                Text(
                                  '${score?.round() ?? 0} / 100',
                                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.orange),
                                ),
                              ],
                            ),
                          ),
                          if (hasEssay && !isGraded) ...[
                            const SizedBox(height: 8),
                            const Text(
                              '⏳ Menunggu koreksi jawaban esai oleh guru.',
                              style: TextStyle(fontSize: 12, color: AppColors.orangeDark, fontWeight: FontWeight.w600),
                            ),
                          ],
                          const SizedBox(height: 12),
                          const Text(
                            'Ujian yang sudah dikerjakan tidak dapat diulang kembali.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      actions: [
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Tutup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withAlpha(12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.orange.withAlpha(50)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isGraded ? 'Nilai: ${score?.round() ?? 0}' : 'Terkumpul',
                        style: const TextStyle(
                          color: AppColors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isGraded ? 'Selesai' : 'Koreksi Esai',
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Builder(
                builder: (ctx) {
                  final now = DateTime.now();
                  final isUpcoming = exam.startTime != null && now.isBefore(exam.startTime!);
                  final isExpired = exam.endTime != null && now.isAfter(exam.endTime!);

                  if (isUpcoming) {
                    return OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.navy,
                        side: BorderSide(color: AppColors.navy.withAlpha(80)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        AppSnackBar.info(
                          context,
                          'Ujian belum dibuka. Mulai dapat dikerjakan pada: ${AppDateFormatter.formatFullDateTime(exam.startTime!)} WIB.',
                        );
                      },
                      child: const Text('Belum Mulai', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    );
                  }

                  if (isExpired) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Ditutup',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    );
                  }

                  return FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ExamTakingScreen(exam: exam)),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: Text(
                      'Mulai',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _examChip(String label, IconData icon, bool isWide) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isWide ? AppColors.navy.withAlpha(30) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isWide ? AppColors.navy.withAlpha(25) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: isWide ? Colors.white70 : const Color(0xFF475569)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isWide ? Colors.white : const Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialList(BuildContext context, bool isWide) {
    if (widget.materials.isEmpty) {
      return _buildEmptyState('Belum ada materi tersedia', Icons.book_outlined, isWide);
    }
    final sortedMaterials = List<dynamic>.from(widget.materials)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Column(
      children: List.generate(sortedMaterials.length, (index) {
        return _buildMaterialCard(context, sortedMaterials[index], isWide, index);
      }),
    );
  }

  Widget _buildMaterialCard(BuildContext context, dynamic mat, bool isWide, int index) {
    final fb = context.watch<FirebaseService>();
    final user = fb.currentUser;
    final assignments = fb.getAssignmentsForMaterial(mat.id);
    final studentClass =
        (user?.className ?? user?.classId ?? '').trim().toLowerCase();
    final applicableAssignments = assignments.where((a) {
      if (a.classIds.isEmpty) return true;
      if (studentClass.isEmpty) return true;
      return a.classIds.any((c) => c.trim().toLowerCase() == studentClass);
    }).toList();

    AssignmentSubmissionModel? mySub;
    for (final a in applicableAssignments) {
      final subs = fb.getSubmissionsForAssignment(a.id);
      final found = subs
          .where((s) =>
              s.submitterId == user?.id ||
              s.memberStudentIds.contains(user?.id))
          .firstOrNull;
      if (found != null) {
        mySub = found;
        break;
      }
    }

    final hasAssignment = applicableAssignments.isNotEmpty;
    final progress =
        user != null ? fb.getMaterialProgress(user.id, mat.id) : 0.0;
    final typeConfig = _getContentTypeConfig(mat.contentType);
    final subject = fb.subjects.where((s) => s.id == mat.subjectId).firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isWide ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isWide
              ? AppColors.borderDark.withAlpha(80)
              : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withAlpha(10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MaterialDetailScreen(material: mat),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Subject Badge + Type Badge + Rating
              Row(
                children: [
                  if (subject != null) ...[
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.primary.withAlpha(45)),
                        ),
                        child: Text(
                          subject.name,
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeConfig.color.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: typeConfig.color.withAlpha(40)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(typeConfig.icon, size: 12, color: typeConfig.color),
                        const SizedBox(width: 4),
                        Text(
                          typeConfig.label,
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: typeConfig.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.star_rounded,
                            size: 13, color: Color(0xFFF59E0B)),
                        SizedBox(width: 2),
                        Text(
                          '4.9',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                mat.title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                  letterSpacing: -0.2,
                  color: isWide ? Colors.white : const Color(0xFF0F172A),
                  height: 1.25,
                ),
              ),
              if (mat.description.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  mat.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],

              // Progress Belajar Siswa
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: isWide
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isWide
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              progress >= 100
                                  ? Icons.check_circle_rounded
                                  : (progress > 0
                                      ? Icons.pie_chart_rounded
                                      : Icons.radio_button_unchecked_rounded),
                              size: 14,
                              color: progress >= 100
                                  ? const Color(0xFF10B981)
                                  : (progress > 0
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF94A3B8)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Progress Belajar',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isWide
                                    ? Colors.white70
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          progress >= 100
                              ? 'Selesai 100%'
                              : '${progress.toInt()}%',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: progress >= 100
                                ? const Color(0xFF10B981)
                                : (progress > 0
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (progress / 100.0).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 100
                              ? const Color(0xFF10B981)
                              : (progress > 0
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Row: Status Tugas & Tombol Masuk (→)
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: !hasAssignment
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.remove_circle_outline_rounded,
                                    size: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Tidak Ada Tugas',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : (mySub != null && mySub.score != null)
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.stars_rounded,
                                          size: 15,
                                          color: Color(0xFF059669)),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Nilai Tugas: ${mySub.score!.toInt()} / 100',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF047857),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : (mySub != null)
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFBEB),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                            color: const Color(0xFFFDE68A)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.hourglass_top_rounded,
                                              size: 13,
                                              color: Color(0xFFD97706)),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              'Tugas Terkumpul (Menunggu Koreksi)',
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFFB45309),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                            color: const Color(0xFFFED7AA)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.assignment_outlined,
                                              size: 13,
                                              color: Color(0xFFEA580C)),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              'Ada Tugas: ${applicableAssignments.first.title}',
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFFC2410C),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Circular arrow button (→)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(6),
                          blurRadius: 5,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: Color(0xFF0F172A),
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
  }

  Widget _buildEmptyState(String msg, IconData icon, bool isWide) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isWide ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isWide
              ? AppColors.borderDark.withAlpha(80)
              : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Text(
            msg,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  _ContentTypeConfig _getContentTypeConfig(String type) {
    switch (type) {
      case 'youtube':
        return const _ContentTypeConfig(
          icon: Icons.play_circle_rounded,
          color: Colors.red,
          label: 'YouTube Video',
        );
      case 'canva':
        return const _ContentTypeConfig(
          icon: Icons.palette_rounded,
          color: Colors.cyan,
          label: 'Canva Interactive',
        );
      default:
        return const _ContentTypeConfig(
          icon: Icons.slideshow_rounded,
          color: Colors.orange,
          label: 'Presentasi',
        );
    }
  }
}


class _ContentTypeConfig {
  final IconData icon;
  final Color color;
  final String label;
  const _ContentTypeConfig(
      {required this.icon, required this.color, required this.label});
}

// ═══════════════════════════════════════════════════════════════════════════════
//  OVAL / PILL FLOATING BOTTOM NAVIGATION BAR (Mobile)
// ═══════════════════════════════════════════════════════════════════════════════

class _OvalBottomNav extends StatefulWidget {
  final int selectedIndex;
  final int uncompletedQuizCount;
  final ValueChanged<int> onTap;

  const _OvalBottomNav({
    required this.selectedIndex,
    required this.uncompletedQuizCount,
    required this.onTap,
  });

  @override
  State<_OvalBottomNav> createState() => _OvalBottomNavState();
}

class _OvalBottomNavState extends State<_OvalBottomNav> {
  @override
  Widget build(BuildContext context) {
    final items = [
      const _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Beranda',
        color: AppColors.primary,
      ),
      const _NavItem(
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book_rounded,
        label: 'Materi',
        color: AppColors.primary,
      ),
      _NavItem(
        icon: Icons.quiz_outlined,
        activeIcon: Icons.quiz_rounded,
        label: 'Quiz',
        color: AppColors.primary,
        badgeCount: widget.uncompletedQuizCount,
      ),
      const _NavItem(
        icon: Icons.emoji_events_outlined,
        activeIcon: Icons.emoji_events_rounded,
        label: 'Peringkat',
        color: AppColors.primary,
      ),
      const _NavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profil',
        color: AppColors.primary,
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 20,
                offset: Offset(0, 6),
                spreadRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = widget.selectedIndex == index;
              return Expanded(
                child: _NavTabButton(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => widget.onTap(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavTabButton extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTabButton({
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
            _buildIconWithBadge(
              isSelected ? item.activeIcon : item.icon,
              isSelected ? item.color : const Color(0xFF64748B),
              item.badgeCount,
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

  Widget _buildIconWithBadge(IconData icon, Color color, int? badgeCount) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 22, color: color),
        if (badgeCount != null && badgeCount > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.rose,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.rose.withAlpha(120),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
  final int? badgeCount;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
    this.badgeCount,
  });
}

