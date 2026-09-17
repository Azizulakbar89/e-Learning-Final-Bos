import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/curriculum_model.dart';
import '../../../core/models/material_model.dart';
import '../../../core/models/school_class_model.dart';
import '../../../core/models/streak_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/app_nav_rail.dart';
import '../../../core/widgets/app_update_dialog.dart';
import '../../../core/widgets/curved_header_card.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../social_and_gamification/screens/chat_conversation_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentNavIndex = 0;

  static const _navItems = [
    AppNavRailItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
    ),
    AppNavRailItem(
      label: 'Data Master',
      icon: Icons.manage_accounts_outlined,
      selectedIcon: Icons.manage_accounts_rounded,
    ),
    AppNavRailItem(
      label: 'Monitoring Chat',
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum_rounded,
    ),
    AppNavRailItem(
      label: 'Monitoring Nilai',
      icon: Icons.assessment_outlined,
      selectedIcon: Icons.assessment_rounded,
    ),
    AppNavRailItem(
      label: 'Profil',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final currentUser = fb.currentUser;

    final List<Widget> pages = [
      _AdminDashboardOverview(
        fb: fb,
        onNavigate: (index) => setState(() => _currentNavIndex = index),
      ),
      _AdminMasterDataPage(fb: fb),
      _AdminChatMonitoringPage(fb: fb),
      _AdminAcademicMonitoringPage(fb: fb),
      _AdminProfilePage(currentUser: currentUser, fb: fb),
    ];

    return ResponsiveLayout(
      mobile: _buildMobileLayout(pages),
      desktop: _buildDesktopLayout(pages, currentUser, fb),
    );
  }

  Widget _buildMobileLayout(List<Widget> pages) {
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
          child: _AdminOvalBottomNav(
            selectedIndex: _currentNavIndex,
            onTap: (idx) => setState(() => _currentNavIndex = idx),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    List<Widget> pages,
    UserModel? currentUser,
    FirebaseService fb,
  ) {
    return Scaffold(
      body: Row(
        children: [
          AppNavRail(
            selectedIndex: _currentNavIndex,
            onDestinationSelected: (i) => setState(() => _currentNavIndex = i),
            items: _navItems,
            header: _buildSidebarHeader(currentUser),
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

  Widget _buildSidebarHeader(UserModel? currentUser) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withAlpha(50),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.school_rounded, color: Colors.amberAccent, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portal E-Learning',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Sistem E-Learning',
                      style: GoogleFonts.outfit(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withAlpha(25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Colors.orangeAccent, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    currentUser?.fullName ?? 'Administrator',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarFooter(FirebaseService fb) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: InkWell(
        onTap: () => fb.logout(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withAlpha(50)),
          ),
          child: Row(
            children: const [
              Icon(Icons.logout_rounded, color: Colors.redAccent, size: 16),
              SizedBox(width: 8),
              Text(
                'Keluar Akun',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAVIGATION FOR MOBILE (Exact Student & Teacher Floating Model)
// ─────────────────────────────────────────────────────────────────────────────
class _AdminOvalBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _AdminOvalBottomNav({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      const _AdminNavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Dashboard',
        color: AppColors.primary,
      ),
      const _AdminNavItem(
        icon: Icons.manage_accounts_outlined,
        activeIcon: Icons.manage_accounts_rounded,
        label: 'Master',
        color: AppColors.emerald,
      ),
      const _AdminNavItem(
        icon: Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_bubble_rounded,
        label: 'Pesan',
        color: Color(0xFF0284C7),
      ),
      const _AdminNavItem(
        icon: Icons.assessment_outlined,
        activeIcon: Icons.assessment_rounded,
        label: 'Monitoring',
        color: Color(0xFFD97706),
      ),
      const _AdminNavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profil',
        color: AppColors.purple,
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
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppColors.primary.withAlpha(12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = selectedIndex == index;
              return Expanded(
                child: _AdminNavTabButton(
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

class _AdminNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;

  const _AdminNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });
}

class _AdminNavTabButton extends StatelessWidget {
  final _AdminNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _AdminNavTabButton({
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

// ─────────────────────────────────────────────────────────────────────────────
// 1. DASHBOARD OVERVIEW TAB
// ─────────────────────────────────────────────────────────────────────────────
class _AdminDashboardOverview extends StatelessWidget {
  final FirebaseService fb;
  final ValueChanged<int> onNavigate;

  const _AdminDashboardOverview({required this.fb, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final totalStudents = fb.allStudents.length;
    final totalTeachers = fb.allTeachers.length;
    final totalClasses = fb.schoolClasses.length;
    final totalSubjects = fb.subjects.length;
    final totalExams = fb.exams.length;
    final totalMaterials = fb.materials.length;
    final totalChatMessages = fb.chatMessages.length;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const CurvedHeaderCard(
              title: 'Dashboard E-Learning',
              subtitle: 'Pusat Manajemen Data & Monitoring Pembelajaran',
              showBackButton: false,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 90),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ringkasan Ekosistem Sekolah',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // KPI Grid
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isWide = constraints.maxWidth > 600;
                        final crossAxisCount = isWide ? 4 : 2;
                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: isWide ? 1.9 : 1.55,
                          children: [
                            _kpiCard(
                              title: 'Total Siswa',
                              value: '$totalStudents',
                              subtitle: 'Akun Terdaftar',
                              icon: Icons.groups_rounded,
                              color: const Color(0xFF2563EB),
                              onTap: () => onNavigate(1),
                            ),
                            _kpiCard(
                              title: 'Total Guru',
                              value: '$totalTeachers',
                              subtitle: 'Pendidik Aktif',
                              icon: Icons.person_rounded,
                              color: const Color(0xFF059669),
                              onTap: () => onNavigate(1),
                            ),
                            _kpiCard(
                              title: 'Rombel Kelas',
                              value: '$totalClasses',
                              subtitle: 'Kelas Terdaftar',
                              icon: Icons.meeting_room_rounded,
                              color: const Color(0xFFD97706),
                              onTap: () => onNavigate(1),
                            ),
                            _kpiCard(
                              title: 'Mata Pelajaran',
                              value: '$totalSubjects',
                              subtitle: 'Kurikulum Aktif',
                              icon: Icons.menu_book_rounded,
                              color: const Color(0xFF7C3AED),
                              onTap: () => onNavigate(1),
                            ),
                            _kpiCard(
                              title: 'Ujian & Quiz',
                              value: '$totalExams',
                              subtitle: 'Evaluasi Pembelajaran',
                              icon: Icons.quiz_rounded,
                              color: const Color(0xFFDC2626),
                              onTap: () => onNavigate(3),
                            ),
                            _kpiCard(
                              title: 'Modul Materi',
                              value: '$totalMaterials',
                              subtitle: 'Materi Siap Belajar',
                              icon: Icons.library_books_rounded,
                              color: const Color(0xFF0D9488),
                              onTap: () => onNavigate(3),
                            ),
                            _kpiCard(
                              title: 'Pesan Chat & Diskusi',
                              value: '$totalChatMessages',
                              subtitle: 'Interaksi Terpantau',
                              icon: Icons.forum_rounded,
                              color: const Color(0xFFEA580C),
                              onTap: () => onNavigate(2),
                            ),
                            _kpiCard(
                              title: 'Tukar Nilai Siswa',
                              value: '${fb.pointTransactions.length}',
                              subtitle: 'Aktivitas Gamifikasi',
                              icon: Icons.stars_rounded,
                              color: const Color(0xFFCA8A04),
                              onTap: () => onNavigate(3),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Quick Management Actions
                    Text(
                      'Pintasan Pengelolaan Sistem',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: _actionTile(
                            icon: Icons.add_circle_outline_rounded,
                            title: 'Data Master',
                            subtitle: 'Kelas, Siswa, Guru & Mapel',
                            color: const Color(0xFF1E3A8A),
                            onTap: () => onNavigate(1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _actionTile(
                            icon: Icons.visibility_outlined,
                            title: 'Pantau Chat',
                            subtitle: 'Diskusi & Obrolan Siswa',
                            color: const Color(0xFFD97706),
                            onTap: () => onNavigate(2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _actionTile(
                            icon: Icons.insights_rounded,
                            title: 'Pantau Nilai',
                            subtitle: 'Ujian, Quiz & Progress',
                            color: const Color(0xFF059669),
                            onTap: () => onNavigate(3),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _actionTile(
                            icon: Icons.security_rounded,
                            title: 'Akun & Akses',
                            subtitle: 'Pengaturan & Logout',
                            color: const Color(0xFF475569),
                            onTap: () => onNavigate(4),
                          ),
                        ),
                      ],
                    ),
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

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(35)),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9.5,
                color: Colors.grey.shade500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. MASTER DATA MANAGEMENT (KELAS, SISWA, GURU & MAPEL)
// ─────────────────────────────────────────────────────────────────────────────
class _AdminMasterDataPage extends StatefulWidget {
  final FirebaseService fb;

  const _AdminMasterDataPage({required this.fb});

  @override
  State<_AdminMasterDataPage> createState() => _AdminMasterDataPageState();
}

class _AdminMasterDataPageState extends State<_AdminMasterDataPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedClassFilter = 'Semua Kelas';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CurvedHeaderCard(
              title: 'Manajemen Data Master',
              subtitle: 'Kelola Kelas, Siswa, Guru, & Mata Pelajaran',
              showBackButton: false,
              actions: [
                IconButton(
                  tooltip: 'Tambah Data',
                  icon: const Icon(Icons.add_circle_rounded, color: Colors.amberAccent, size: 22),
                  onPressed: _openAddDialogForCurrentTab,
                ),
              ],
            ),

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: const Color(0xFF1E3A8A),
                unselectedLabelColor: Colors.grey.shade500,
                indicatorColor: Colors.orange.shade700,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'Kelas'),
                  Tab(text: 'Siswa'),
                  Tab(text: 'Guru & Penugasan'),
                  Tab(text: 'Mata Pelajaran'),
                ],
              ),
            ),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildClassesTab(),
                  _buildStudentsTab(),
                  _buildTeachersTab(),
                  _buildSubjectsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddDialogForCurrentTab() {
    switch (_tabController.index) {
      case 0:
        _showAddClassDialog();
        break;
      case 1:
        _showAddStudentDialog();
        break;
      case 2:
        _showAddTeacherDialog();
        break;
      case 3:
        _showAddSubjectDialog();
        break;
    }
  }

  // ─── TAB 1: DATA KELAS ───
  Widget _buildClassesTab() {
    final classes = widget.fb.schoolClasses;
    final allStudents = widget.fb.allStudents;
    final allTeachers = widget.fb.allTeachers;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daftar Rombel Kelas (${classes.length})',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _showAddClassDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Tambah Kelas', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: classes.isEmpty
                ? const Center(child: Text('Belum ada kelas terdaftar.'))
                : ListView.builder(
                    itemCount: classes.length,
                    itemBuilder: (ctx, idx) {
                      final c = classes[idx];
                      final studentCount = allStudents
                          .where((s) => (s.className ?? s.classId ?? '').trim().toLowerCase() == c.name.trim().toLowerCase())
                          .length;
                      final teacherCount = allTeachers
                          .where((t) => t.classIds.any((cid) => cid.trim().toLowerCase() == c.name.trim().toLowerCase() || cid.trim().toLowerCase() == c.id.trim().toLowerCase()))
                          .length;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.orange.withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(Icons.meeting_room_rounded, color: Colors.orange, size: 20),
                            ),
                          ),
                          title: Text(
                            c.name,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            '$studentCount Siswa  •  $teacherCount Guru Pengampu',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                                tooltip: 'Edit Kelas',
                                onPressed: () => _showEditClassDialog(c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                tooltip: 'Hapus Kelas',
                                onPressed: () => _confirmDeleteClass(c),
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
    );
  }

  void _showAddClassDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Tambah Kelas Baru', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Nama Kelas',
            hintText: 'Contoh: X-PPLG-1, XI-RPL, dsb.',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                final nav = Navigator.of(ctx);
                await widget.fb.addSchoolClass(val);
                nav.pop();
              }
            },
            child: const Text('Simpan Kelas'),
          ),
        ],
      ),
    );
  }

  void _showEditClassDialog(SchoolClassModel c) {
    final controller = TextEditingController(text: c.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Nama Kelas', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Nama Rombel Kelas',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                final nav = Navigator.of(ctx);
                await widget.fb.updateSchoolClass(c.id, val);
                nav.pop();
              }
            },
            child: const Text('Simpan Perubahan'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteClass(SchoolClassModel c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Kelas ${c.name}?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('Tindakan ini akan menghapus entitas kelas dari sistem master data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await showLoadingDialog(
                context,
                message: 'Menghapus kelas ${c.name}...',
                action: () async {
                  await widget.fb.deleteSchoolClass(c.id);
                },
                successMessage: 'Kelas ${c.name} berhasil dihapus.',
                errorMessage: 'Gagal menghapus kelas.',
              );
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: DATA SISWA ───
  Widget _buildStudentsTab() {
    final allStudents = widget.fb.allStudents;
    final availableClasses = widget.fb.getAvailableClasses();
    final filterClasses = ['Semua Kelas', ...availableClasses];

    final filtered = allStudents.where((s) {
      final sClass = (s.className ?? s.classId ?? '').trim();
      if (_selectedClassFilter != 'Semua Kelas' &&
          sClass.toLowerCase() != _selectedClassFilter.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return s.fullName.toLowerCase().contains(q) || (s.nis?.contains(q) ?? false);
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
      child: Column(
        children: [
          // Filter & Search bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari siswa atau NIS...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: filterClasses.contains(_selectedClassFilter)
                        ? _selectedClassFilter
                        : 'Semua Kelas',
                    items: filterClasses
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedClassFilter = v);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Siswa: ${filtered.length}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _showAddStudentDialog,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Tambah Siswa', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Tidak ada data siswa yang cocok.'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final s = filtered[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.withAlpha(30),
                            child: Text(
                              s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : 'S',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ),
                          title: Text(
                            s.fullName,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          subtitle: Text(
                            'NIS: ${s.nis ?? "-"}  •  Kelas: ${s.className ?? s.classId ?? "-"}  •  Pass: ${s.initialPassword ?? "******"}',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                tooltip: 'Edit Data Siswa',
                                onPressed: () => _showEditStudentDialog(s),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                tooltip: 'Hapus Siswa',
                                onPressed: () => _confirmDeleteStudent(s),
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
    );
  }

  void _showAddStudentDialog() {
    final nameCtrl = TextEditingController();
    final nisCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'siswa123');
    String selectedClass = widget.fb.getAvailableClasses().firstOrNull ?? 'X-PPLG-1';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Tambah Siswa Baru', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap Siswa'),
                ),
                TextField(
                  controller: nisCtrl,
                  decoration: const InputDecoration(labelText: 'Nomor Induk Siswa (NIS)'),
                ),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: 'Password Akun Awal'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedClass,
                  decoration: const InputDecoration(labelText: 'Pilih Kelas'),
                  items: widget.fb.getAvailableClasses()
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDState(() => selectedClass = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final nis = nisCtrl.text.trim();
                final pass = passCtrl.text.trim();
                if (name.isNotEmpty && nis.isNotEmpty) {
                  if (widget.fb.allStudents.any((s) => s.nis == nis)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('NIS "$nis" sudah terdaftar pada siswa lain!'),
                        backgroundColor: AppColors.rose,
                      ),
                    );
                    return;
                  }
                  final nav = Navigator.of(ctx);
                  final newStudent = UserModel(
                    id: 'std_${DateTime.now().millisecondsSinceEpoch}',
                    username: nis,
                    fullName: name,
                    role: 'siswa',
                    nis: nis,
                    classId: selectedClass,
                    className: selectedClass,
                    initialPassword: pass.isNotEmpty ? pass : 'siswa123',
                  );
                  await widget.fb.addStudentUser(newStudent);
                  nav.pop();
                }
              },
              child: const Text('Simpan Siswa', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStudentDialog(UserModel student) {
    final nameCtrl = TextEditingController(text: student.fullName);
    final passCtrl = TextEditingController(text: student.initialPassword ?? '');
    String selectedClass = student.className ?? student.classId ?? 'X-PPLG-1';
    final classes = widget.fb.getAvailableClasses();
    if (!classes.contains(selectedClass) && classes.isNotEmpty) {
      selectedClass = classes.first;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Siswa: ${student.fullName}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                ),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: 'Reset Password'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedClass,
                  decoration: const InputDecoration(labelText: 'Kelas Siswa'),
                  items: classes
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDState(() => selectedClass = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
              onPressed: () async {
                final nav = Navigator.of(ctx);
                final updated = student.copyWith(
                  fullName: nameCtrl.text.trim(),
                  initialPassword: passCtrl.text.trim(),
                  classId: selectedClass,
                  className: selectedClass,
                );
                await widget.fb.addStudentUser(updated);
                nav.pop();
              },
              child: const Text('Simpan Perubahan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteStudent(UserModel student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Siswa: ${student.fullName}?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('Akun siswa ini akan dihapus dari sistem e-learning.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await showLoadingDialog(
                context,
                message: 'Menghapus akun siswa...',
                action: () async {
                  await widget.fb.deleteStudentUser(student.id);
                },
                successMessage: 'Siswa ${student.fullName} berhasil dihapus.',
                errorMessage: 'Gagal menghapus akun siswa.',
              );
            },
            child: const Text('Hapus Siswa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── TAB 3: DATA GURU & PENUGASAN MAPEL/KELAS ───
  Widget _buildTeachersTab() {
    final teachers = widget.fb.allTeachers;
    final subjects = widget.fb.subjects;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daftar Guru & Penugasan (${teachers.length})',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _showAddTeacherDialog,
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Tambah Guru', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Expanded(
            child: teachers.isEmpty
                ? const Center(child: Text('Belum ada guru terdaftar.'))
                : ListView.builder(
                    itemCount: teachers.length,
                    itemBuilder: (ctx, idx) {
                      final t = teachers[idx];
                      final taughtSubjNames = subjects
                          .where((s) => t.subjectIds.contains(s.id))
                          .map((s) => s.name)
                          .toList();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderLight),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(6),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.withAlpha(30),
                            child: const Icon(Icons.school_rounded, color: Colors.teal),
                          ),
                          title: Text(
                            t.fullName,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Username: ${t.username}  •  ${t.subjectIds.length} Mapel  •  ${t.classIds.length} Kelas',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(),
                                  const Text(
                                    'Mata Pelajaran yang Diajar:',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                                  ),
                                  const SizedBox(height: 4),
                                  taughtSubjNames.isEmpty
                                      ? const Text('Belum ada mapel ditugaskan.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic))
                                      : Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: taughtSubjNames
                                              .map((sn) => Chip(
                                                    label: Text(sn, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                                    backgroundColor: Colors.blue.shade50,
                                                    visualDensity: VisualDensity.compact,
                                                    padding: EdgeInsets.zero,
                                                  ))
                                              .toList(),
                                        ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Kelas yang Diampu:',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                  ),
                                  const SizedBox(height: 4),
                                  t.classIds.isEmpty
                                      ? const Text('Belum ada kelas ditugaskan.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic))
                                      : Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: t.classIds
                                              .map((cn) => Chip(
                                                    label: Text(cn, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                                    backgroundColor: Colors.orange.shade50,
                                                    visualDensity: VisualDensity.compact,
                                                    padding: EdgeInsets.zero,
                                                  ))
                                              .toList(),
                                        ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Wrap(
                                      alignment: WrapAlignment.end,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.blueAccent,
                                            side: const BorderSide(color: Colors.blueAccent),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                          icon: const Icon(Icons.edit_outlined, size: 15),
                                          label: const Text('Edit Guru', style: TextStyle(fontSize: 12)),
                                          onPressed: () => _showEditTeacherDialog(t),
                                        ),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.redAccent,
                                            side: const BorderSide(color: Colors.redAccent),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                          icon: const Icon(Icons.delete_outline, size: 15),
                                          label: const Text('Hapus Guru', style: TextStyle(fontSize: 12)),
                                          onPressed: () => _confirmDeleteTeacher(t),
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                          icon: const Icon(Icons.tune_rounded, size: 15),
                                          label: const Text('Atur Mapel & Kelas', style: TextStyle(fontSize: 12)),
                                          onPressed: () => _showAssignTeacherDialog(t),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddTeacherDialog() {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'guru123');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Tambah Guru Baru', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Lengkap & Gelar')),
            TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Username Login')),
            TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password Akun')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final username = userCtrl.text.trim();
              final pass = passCtrl.text.trim();
              if (name.isNotEmpty && username.isNotEmpty) {
                final nav = Navigator.of(ctx);
                final newTeacher = UserModel(
                  id: 'tch_${DateTime.now().millisecondsSinceEpoch}',
                  username: username,
                  fullName: name,
                  role: 'guru',
                  initialPassword: pass.isNotEmpty ? pass : 'guru123',
                );
                await widget.fb.addTeacherUser(newTeacher);
                nav.pop();
              }
            },
            child: const Text('Simpan Guru', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAssignTeacherDialog(UserModel teacher) {
    final allSubjects = widget.fb.subjects;
    final allClasses = widget.fb.getAvailableClasses();

    final selectedSubjectIds = List<String>.from(teacher.subjectIds);
    final selectedClassIds = List<String>.from(teacher.classIds);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Penugasan Guru', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(teacher.fullName, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('1. Pilih Mata Pelajaran yang Diajar (Bisa > 1):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allSubjects.map((s) {
                      final isSelected = selectedSubjectIds.contains(s.id);
                      return FilterChip(
                        label: Text(s.name, style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        selectedColor: Colors.blue.shade100,
                        onSelected: (sel) {
                          setDState(() {
                            if (sel) {
                              selectedSubjectIds.add(s.id);
                            } else {
                              selectedSubjectIds.remove(s.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  const Text('2. Pilih Kelas yang Diampu (Bisa > 1):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allClasses.map((c) {
                      final isSelected = selectedClassIds.contains(c);
                      return FilterChip(
                        label: Text(c, style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        selectedColor: Colors.orange.shade100,
                        onSelected: (sel) {
                          setDState(() {
                            if (sel) {
                              selectedClassIds.add(c);
                            } else {
                              selectedClassIds.remove(c);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
              onPressed: () async {
                final nav = Navigator.of(ctx);
                await widget.fb.assignTeacherToSubjectsAndClasses(
                  teacherId: teacher.id,
                  subjectIds: selectedSubjectIds,
                  classIds: selectedClassIds,
                );
                nav.pop();
              },
              child: const Text('Terapkan Penugasan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTeacherDialog(UserModel teacher) {
    final nameCtrl = TextEditingController(text: teacher.fullName);
    final userCtrl = TextEditingController(text: teacher.username);
    final passCtrl = TextEditingController(text: teacher.initialPassword ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Profil Guru', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Lengkap & Gelar'),
              ),
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(labelText: 'Username Login'),
              ),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'Password Akun Baru'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final username = userCtrl.text.trim();
              final pass = passCtrl.text.trim();
              if (name.isNotEmpty && username.isNotEmpty) {
                final nav = Navigator.of(ctx);
                final updated = teacher.copyWith(
                  fullName: name,
                  username: username,
                  initialPassword: pass.isNotEmpty ? pass : teacher.initialPassword,
                );
                await widget.fb.updateTeacherUser(updated);
                nav.pop();
              }
            },
            child: const Text('Simpan Perubahan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTeacher(UserModel teacher) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Guru: ${teacher.fullName}?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('Akun guru ini akan dihapus dari sistem e-learning.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await showLoadingDialog(
                context,
                message: 'Menghapus akun guru...',
                action: () async {
                  await widget.fb.deleteTeacherUser(teacher.id);
                },
                successMessage: 'Guru ${teacher.fullName} berhasil dihapus.',
                errorMessage: 'Gagal menghapus akun guru.',
              );
            },
            child: const Text('Hapus Guru', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── TAB 4: DATA MATA PELAJARAN ───
  Widget _buildSubjectsTab() {
    final subjects = widget.fb.subjects;
    final teachers = widget.fb.allTeachers;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daftar Mata Pelajaran (${subjects.length})',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _showAddSubjectDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Tambah Mapel', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Expanded(
            child: subjects.isEmpty
                ? const Center(child: Text('Belum ada mata pelajaran terdaftar.'))
                : ListView.builder(
                    itemCount: subjects.length,
                    itemBuilder: (ctx, idx) {
                      final s = subjects[idx];
                      final teacherList = teachers.where((t) => t.subjectIds.contains(s.id)).toList();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue.withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(Icons.menu_book_rounded, color: Colors.blue, size: 20),
                            ),
                          ),
                          title: Text(
                            s.name,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          subtitle: Text(
                            'Kode: ${s.code}  •  KKM: ${s.kkm.toStringAsFixed(0)}  •  ${teacherList.length} Guru Pengampu (${teacherList.map((t) => t.fullName).join(", ").isEmpty ? "Belum Ditugaskan" : teacherList.map((t) => t.fullName).join(", ")})',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                tooltip: 'Edit Mapel',
                                onPressed: () => _showEditSubjectDialog(s),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                tooltip: 'Hapus Mapel',
                                onPressed: () => _confirmDeleteSubject(s),
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
    );
  }

  void _showAddSubjectDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final kkmCtrl = TextEditingController(text: '75.0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Tambah Mata Pelajaran', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Mata Pelajaran')),
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Kode Mapel (e.g. INF-10)')),
            TextField(
              controller: kkmCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Standar KKM / Batas Nilai Minimal (e.g. 75.0)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final code = codeCtrl.text.trim();
              final kkm = double.tryParse(kkmCtrl.text.trim()) ?? 75.0;
              if (name.isNotEmpty && code.isNotEmpty) {
                final nav = Navigator.of(ctx);
                final newSubject = SubjectModel(
                  id: 'subj_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  code: code,
                  icon: 'code',
                  kkm: kkm,
                );
                await widget.fb.addSubject(newSubject);
                nav.pop();
              }
            },
            child: const Text('Simpan Mapel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditSubjectDialog(SubjectModel subject) {
    final nameCtrl = TextEditingController(text: subject.name);
    final codeCtrl = TextEditingController(text: subject.code);
    final kkmCtrl = TextEditingController(text: subject.kkm.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Mata Pelajaran', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Mata Pelajaran')),
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Kode Mapel')),
            TextField(
              controller: kkmCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Standar KKM / Batas Nilai Minimal'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final kkm = double.tryParse(kkmCtrl.text.trim()) ?? subject.kkm;
              final updated = SubjectModel(
                id: subject.id,
                name: nameCtrl.text.trim(),
                code: codeCtrl.text.trim(),
                icon: subject.icon,
                kkm: kkm,
              );
              await widget.fb.updateSubject(updated);
              nav.pop();
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSubject(SubjectModel subject) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Mapel: ${subject.name}?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('Mata pelajaran ini akan dihapus dari sistem e-learning.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await showLoadingDialog(
                context,
                message: 'Menghapus mata pelajaran...',
                action: () async {
                  await widget.fb.deleteSubject(subject.id);
                },
                successMessage: 'Mata pelajaran ${subject.name} berhasil dihapus.',
                errorMessage: 'Gagal menghapus mata pelajaran.',
              );
            },
            child: const Text('Hapus Mapel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. MONITORING CHAT & DISKUSI (MATERI, GURU, PEER SISWA, GRUP)
// ─────────────────────────────────────────────────────────────────────────────
class _AdminChatMonitoringPage extends StatefulWidget {
  final FirebaseService fb;

  const _AdminChatMonitoringPage({required this.fb});

  @override
  State<_AdminChatMonitoringPage> createState() => _AdminChatMonitoringPageState();
}

class _AdminChatMonitoringPageState extends State<_AdminChatMonitoringPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedClass = 'Semua Kelas';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableClasses = ['Semua Kelas', ...widget.fb.getAvailableClasses()];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CurvedHeaderCard(
              title: 'Monitoring Chat & Diskusi',
              subtitle: 'Pengawasan Komunikasi & Forum Pembelajaran Siswa',
              showBackButton: false,
              actions: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: const Color(0xFF0F172A),
                      value: availableClasses.contains(_selectedClass) ? _selectedClass : 'Semua Kelas',
                      items: availableClasses
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedClass = v);
                      },
                    ),
                  ),
                ),
              ],
            ),

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF1E3A8A),
                unselectedLabelColor: Colors.grey.shade500,
                indicatorColor: Colors.orange.shade700,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11),
                tabs: const [
                  Tab(text: 'Diskusi Materi'),
                  Tab(text: 'Chat Siswa - Guru'),
                  Tab(text: 'Chat Antar Siswa'),
                  Tab(text: 'Grup Kelas'),
                ],
              ),
            ),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMaterialDiscussions(),
                  _buildTeacherStudentChats(),
                  _buildPeerChats(),
                  _buildGroupChats(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Diskusi Materi (Forum Messages)
  Widget _buildMaterialDiscussions() {
    final materials = widget.fb.materials;
    final allForumMessages = <Map<String, dynamic>>[];

    for (final m in materials) {
      for (final cid in m.classIds) {
        if (_selectedClass != 'Semua Kelas' && cid.trim().toLowerCase() != _selectedClass.trim().toLowerCase()) {
          continue;
        }
        final msgs = widget.fb.getForumMessages(materialId: m.id, classId: cid);
        for (final msg in msgs) {
          allForumMessages.add({
            'material': m,
            'classId': cid,
            'message': msg,
          });
        }
      }
    }

    allForumMessages.sort((a, b) => (b['message'] as ForumMessageModel).createdAt.compareTo((a['message'] as ForumMessageModel).createdAt));

    if (allForumMessages.isEmpty) {
      return Center(
        child: Text(
          'Belum ada pesan diskusi materi untuk filter ini.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
      itemCount: allForumMessages.length,
      itemBuilder: (ctx, idx) {
        final item = allForumMessages[idx];
        final mat = item['material'] as MaterialModel;
        final cid = item['classId'] as String;
        final msg = item['message'] as ForumMessageModel;
        final isGuru = msg.senderRole == 'guru';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${mat.title} • Kelas $cid',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                    ),
                  ),
                  Text(
                    DateFormat('dd MMM, HH:mm').format(msg.createdAt),
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: isGuru ? Colors.teal.shade100 : Colors.orange.shade100,
                    child: Text(
                      msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : 'U',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isGuru ? Colors.teal : Colors.orange.shade800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    msg.senderName,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isGuru ? Colors.teal.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isGuru ? 'GURU' : 'SISWA',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isGuru ? Colors.teal : Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                msg.message,
                style: const TextStyle(fontSize: 12.5, height: 1.3),
              ),
            ],
          ),
        );
      },
    );
  }

  // 2. Chat Siswa - Guru
  Widget _buildTeacherStudentChats() {
    return _buildStreakList(StreakType.teacher);
  }

  // 3. Chat Antar Siswa (Peer)
  Widget _buildPeerChats() {
    return _buildStreakList(StreakType.peer);
  }

  // 4. Grup Kelas
  Widget _buildGroupChats() {
    return _buildStreakList(StreakType.group);
  }

  Widget _buildStreakList(StreakType type) {
    final streaks = widget.fb.streaks.where((s) => s.type == type).toList();

    if (streaks.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada riwayat percakapan pada kategori ini.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
      itemCount: streaks.length,
      itemBuilder: (ctx, idx) {
        final st = streaks[idx];
        final messages = widget.fb.chatMessages.where((m) => m.streakId == st.id).toList()
          ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
        final lastMsg = messages.firstOrNull;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: type == StreakType.teacher
                  ? Colors.teal.shade100
                  : (type == StreakType.peer ? Colors.indigo.shade100 : Colors.amber.shade100),
              child: Icon(
                type == StreakType.teacher
                    ? Icons.school_rounded
                    : (type == StreakType.peer ? Icons.people_rounded : Icons.groups_rounded),
                size: 20,
                color: type == StreakType.teacher
                    ? Colors.teal
                    : (type == StreakType.peer ? Colors.indigo : Colors.amber.shade800),
              ),
            ),
            title: Text(
              st.title,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            subtitle: Text(
              lastMsg != null
                  ? '${lastMsg.senderName}: ${lastMsg.message}'
                  : 'Belum ada pesan terkirim.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${messages.length} pesan',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 2),
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatConversationScreen(streak: st),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. MONITORING PROGRESS & REKAP NILAI (UJIAN, QUIZ, MATERI, TUGAS)
// ─────────────────────────────────────────────────────────────────────────────
class _AdminAcademicMonitoringPage extends StatefulWidget {
  final FirebaseService fb;

  const _AdminAcademicMonitoringPage({required this.fb});

  @override
  State<_AdminAcademicMonitoringPage> createState() => _AdminAcademicMonitoringPageState();
}

class _AdminAcademicMonitoringPageState extends State<_AdminAcademicMonitoringPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedClass = 'Semua Kelas';
  String? _selectedSubjectId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classes = ['Semua Kelas', ...widget.fb.getAvailableClasses()];
    final subjects = widget.fb.subjects;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const CurvedHeaderCard(
              title: 'Monitoring Nilai & Progress',
              subtitle: 'Grafik Performa & Evaluasi Akademik Masing-masing Siswa',
              showBackButton: false,
            ),

            // Search Bar for individual student
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau NISN siswa...',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),
            ),

            // Class and Subject Filters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: classes.contains(_selectedClass) ? _selectedClass : 'Semua Kelas',
                          items: classes
                              .map((c) => DropdownMenuItem(value: c, child: Text('Kelas: $c', style: const TextStyle(fontSize: 12))))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedClass = v);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedSubjectId,
                          hint: const Text('Semua Mapel', style: TextStyle(fontSize: 12)),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Semua Mapel', style: TextStyle(fontSize: 12))),
                            ...subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (v) => setState(() => _selectedSubjectId = v),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tab bar with "Grafik & Rekap Siswa" as the primary view
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF1E3A8A),
                unselectedLabelColor: Colors.grey.shade500,
                indicatorColor: Colors.orange.shade700,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11),
                tabs: const [
                  Tab(text: 'Grafik & Rekap Siswa'),
                  Tab(text: 'Ujian & Quiz'),
                  Tab(text: 'Tugas'),
                  Tab(text: 'Progres Materi'),
                ],
              ),
            ),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStudentPerformanceAndChartTab(),
                  _buildExamsScoreTab(),
                  _buildAssignmentsTab(),
                  _buildMaterialProgressTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. TAB GRAFIK & REKAP PER SISWA (Individual Student Performance Cards with Charts & Conclusions)
  Widget _buildStudentPerformanceAndChartTab() {
    final students = widget.fb.allStudents.where((s) {
      final sClass = (s.className ?? s.classId ?? '').trim();
      if (_selectedClass != 'Semua Kelas' && sClass.toLowerCase() != _selectedClass.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = s.fullName.toLowerCase();
        final nis = (s.nis ?? s.username).toLowerCase();
        if (!name.contains(q) && !nis.contains(q)) return false;
      }
      return true;
    }).toList();

    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'Tidak ada data siswa yang cocok dengan filter.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 85),
      itemCount: students.length,
      itemBuilder: (ctx, idx) {
        final s = students[idx];
        return _StudentPerformanceCard(
          student: s,
          fb: widget.fb,
          filterSubjectId: _selectedSubjectId,
        );
      },
    );
  }

  // 2. Nilai Ujian & Quiz Tab
  Widget _buildExamsScoreTab() {
    final examSessions = widget.fb.examSessions;
    final exams = widget.fb.exams;
    final students = widget.fb.allStudents;

    final filtered = examSessions.where((sess) {
      final exam = exams.where((e) => e.id == sess.examId).firstOrNull;
      if (_selectedSubjectId != null && exam?.subjectId != _selectedSubjectId) return false;
      final student = students.where((s) => s.id == sess.studentId).firstOrNull;
      final sClass = (student?.className ?? student?.classId ?? '').trim();
      if (_selectedClass != 'Semua Kelas' && sClass.toLowerCase() != _selectedClass.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (student?.fullName ?? sess.studentName).toLowerCase();
        final nis = (student?.nis ?? sess.studentNis).toLowerCase();
        if (!name.contains(q) && !nis.contains(q)) return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text('Belum ada data pengerjaan ujian / kuis.', style: TextStyle(color: Colors.grey.shade600)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 85),
      itemCount: filtered.length,
      itemBuilder: (ctx, idx) {
        final sess = filtered[idx];
        final exam = exams.where((e) => e.id == sess.examId).firstOrNull;
        final student = students.where((s) => s.id == sess.studentId).firstOrNull;
        final finalScoreVal = sess.finalScore ?? sess.nonEssayScore ?? 0.0;
        final isPassed = finalScoreVal >= 75.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPassed ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isPassed ? Colors.green.shade200 : Colors.red.shade200),
                ),
                child: Center(
                  child: Text(
                    '${finalScoreVal.toInt()}',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isPassed ? Colors.green.shade800 : Colors.red.shade800,
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
                      student?.fullName ?? sess.studentName,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      '${exam?.title ?? "Ujian"} • Kelas ${student?.className ?? sess.studentClass}',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                    if (sess.violationCount > 0)
                      Text(
                        '⚠️ ${sess.violationCount}x Indikasi Pelanggaran Anti-Cheat',
                        style: const TextStyle(fontSize: 10.5, color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sess.isCompleted ? Colors.blue.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sess.isCompleted ? 'Selesai' : 'Mengerjakan',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: sess.isCompleted ? Colors.blue.shade800 : Colors.amber.shade800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 3. Tugas & Pengumpulan Tab
  Widget _buildAssignmentsTab() {
    final submissions = widget.fb.submissions;
    final assignments = widget.fb.assignments;
    final students = widget.fb.allStudents;

    final filtered = submissions.where((sub) {
      final assign = assignments.where((a) => a.id == sub.assignmentId).firstOrNull;
      if (_selectedSubjectId != null && assign?.subjectId != _selectedSubjectId) return false;
      final student = students.where((s) => s.id == sub.submitterId).firstOrNull;
      final sClass = (student?.className ?? student?.classId ?? '').trim();
      if (_selectedClass != 'Semua Kelas' && sClass.toLowerCase() != _selectedClass.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (student?.fullName ?? sub.submitterName).toLowerCase();
        final nis = (student?.nis ?? '').toLowerCase();
        if (!name.contains(q) && !nis.contains(q)) return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text('Belum ada tugas yang dikumpulkan.', style: TextStyle(color: Colors.grey.shade600)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 85),
      itemCount: filtered.length,
      itemBuilder: (ctx, idx) {
        final sub = filtered[idx];
        final assign = assignments.where((a) => a.id == sub.assignmentId).firstOrNull;
        final student = students.where((s) => s.id == sub.submitterId).firstOrNull;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_turned_in_rounded, color: Colors.indigo, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(assign?.title ?? 'Tugas Pembelajaran', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      'Siswa: ${student?.fullName ?? sub.submitterName} (Kelas ${student?.className ?? "-"})',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    sub.score != null ? 'Nilai: ${sub.score!.toStringAsFixed(1)}' : 'Belum Dinilai',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: sub.score != null ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM HH:mm').format(sub.submittedAt),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 4. Progres Membaca Materi Tab
  Widget _buildMaterialProgressTab() {
    final students = widget.fb.allStudents.where((s) {
      final sClass = (s.className ?? s.classId ?? '').trim();
      if (_selectedClass != 'Semua Kelas' && sClass.toLowerCase() != _selectedClass.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = s.fullName.toLowerCase();
        final nis = (s.nis ?? s.username).toLowerCase();
        if (!name.contains(q) && !nis.contains(q)) return false;
      }
      return true;
    }).toList();

    if (students.isEmpty) {
      return Center(
        child: Text('Tidak ada siswa sesuai filter.', style: TextStyle(color: Colors.grey.shade600)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 85),
      itemCount: students.length,
      itemBuilder: (ctx, idx) {
        final s = students[idx];
        final sMaterials = widget.fb.getMaterialsForUser(s);
        final completedCount = sMaterials.where((m) => widget.fb.getMaterialProgress(s.id, m.id) >= 100.0).length;
        final pct = sMaterials.isNotEmpty ? (completedCount / sMaterials.length) : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(s.fullName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  Text('${(pct * 100).toInt()}% Selesai', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Kelas: ${s.className ?? s.classId ?? "-"}  •  $completedCount dari ${sMaterials.length} Materi Dibaca',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(pct >= 0.8 ? Colors.green : Colors.blue),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INDIVIDUAL STUDENT PERFORMANCE CARD WITH DUAL-BAR CHART & GRAPH CONCLUSION
// ─────────────────────────────────────────────────────────────────────────────
class _StudentPerformanceCard extends StatelessWidget {
  final UserModel student;
  final FirebaseService fb;
  final String? filterSubjectId;

  const _StudentPerformanceCard({
    required this.student,
    required this.fb,
    this.filterSubjectId,
  });

  @override
  Widget build(BuildContext context) {
    final allGrades = fb.getStudentSubjectGrades(student);
    final grades = (filterSubjectId != null && allGrades.any((g) => g.subject.id == filterSubjectId))
        ? allGrades.where((g) => g.subject.id == filterSubjectId).toList()
        : allGrades;

    // Aggregated metrics
    final examScores = grades.where((g) => g.examAverage != null).map((g) => g.examAverage!).toList();
    final taskScores = grades.where((g) => g.assignmentAverage != null).map((g) => g.assignmentAverage!).toList();
    final finalScores = grades.where((g) => g.finalGrade != null).map((g) => g.finalGrade!).toList();

    final overallExamAvg = examScores.isNotEmpty ? examScores.reduce((a, b) => a + b) / examScores.length : null;
    final overallTaskAvg = taskScores.isNotEmpty ? taskScores.reduce((a, b) => a + b) / taskScores.length : null;
    final overallFinalAvg = finalScores.isNotEmpty ? finalScores.reduce((a, b) => a + b) / finalScores.length : null;

    final completedTasksTotal = grades.fold<int>(0, (sum, g) => sum + g.completedAssignments);
    final totalTasksCount = grades.fold<int>(0, (sum, g) => sum + g.totalAssignments);

    // Identify strongest & remedial subjects based on dynamic subject KKM
    StudentSubjectGrade? strongestSubject;
    StudentSubjectGrade? weakestSubject;
    final List<StudentSubjectGrade> remedialSubjects = [];

    for (final g in grades) {
      final score = g.finalGrade ?? g.examAverage ?? g.assignmentAverage;
      if (score != null) {
        if (strongestSubject == null || (g.finalGrade ?? 0) > (strongestSubject.finalGrade ?? 0)) {
          strongestSubject = g;
        }
        if (weakestSubject == null || (g.finalGrade ?? 100) < (weakestSubject.finalGrade ?? 100)) {
          weakestSubject = g;
        }
        final kkm = g.subject.kkm;
        if ((g.examAverage != null && g.examAverage! < kkm) ||
            (g.assignmentAverage != null && g.assignmentAverage! < kkm) ||
            (g.finalGrade != null && g.finalGrade! < kkm)) {
          remedialSubjects.add(g);
        }
      }
    }

    final avgKkm = grades.isNotEmpty
        ? (grades.map((g) => g.subject.kkm).reduce((a, b) => a + b) / grades.length)
        : 75.0;

    // Status evaluation
    final bool hasData = overallExamAvg != null || overallTaskAvg != null;
    final bool isSuperior = hasData && (overallFinalAvg ?? 0) >= (avgKkm + 10.0) && remedialSubjects.isEmpty;
    final bool isPassed = hasData && (overallFinalAvg ?? 0) >= avgKkm && remedialSubjects.isEmpty;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (!hasData) {
      statusColor = const Color(0xFF64748B);
      statusLabel = 'Belum Ada Nilai';
      statusIcon = Icons.info_outline_rounded;
    } else if (isSuperior) {
      statusColor = const Color(0xFF059669);
      statusLabel = 'Sangat Unggul';
      statusIcon = Icons.stars_rounded;
    } else if (isPassed) {
      statusColor = const Color(0xFF2563EB);
      statusLabel = 'Tuntas KKM';
      statusIcon = Icons.check_circle_rounded;
    } else {
      statusColor = const Color(0xFFDC2626);
      statusLabel = 'Perlu Remedial';
      statusIcon = Icons.warning_amber_rounded;
    }

    // Extract superior CPs and Materials based on high-performing subjects
    final List<String> superiorCps = [];
    final List<String> superiorMaterials = [];

    final topGrades = grades.where((g) {
      final s = g.finalGrade ?? g.examAverage ?? g.assignmentAverage ?? 0.0;
      return s >= g.subject.kkm;
    }).toList();
    topGrades.sort((a, b) => (b.finalGrade ?? b.examAverage ?? 0.0).compareTo(a.finalGrade ?? a.examAverage ?? 0.0));

    for (final tg in topGrades) {
      final cps = fb.cps.where((c) => c.subjectId == tg.subject.id).toList();
      for (final c in cps) {
        final item = c.code.isNotEmpty ? '[${c.code}] ${c.title}' : c.title;
        if (!superiorCps.contains(item)) superiorCps.add(item);
      }
      final mats = fb.materials.where((m) => m.subjectId == tg.subject.id).toList();
      for (final m in mats) {
        if (!superiorMaterials.contains(m.title)) superiorMaterials.add(m.title);
      }
    }

    if (superiorCps.isEmpty) {
      if (strongestSubject != null) {
        superiorCps.add('Logika Algoritma & Praktik Terapan (${strongestSubject.subject.name})');
        superiorCps.add('Analisis Pemecahan Masalah & Pengembangan Mandiri');
      } else {
        superiorCps.add('Pemahaman Komprehensif Kompetensi Mata Pelajaran');
      }
    }
    if (superiorMaterials.isEmpty) {
      if (strongestSubject != null) {
        superiorMaterials.add('Modul Fundamental Teori & Praktikum (${strongestSubject.subject.name})');
        superiorMaterials.add('Studi Kasus & Evaluasi Formatif Terpadu');
      } else {
        superiorMaterials.add('Modul Inti Pembelajaran Mandiri');
      }
    }

    final subjectSummary = grades.map((g) => {
      'name': g.subject.name,
      'score': (g.finalGrade ?? g.examAverage ?? g.assignmentAverage ?? 0.0).toStringAsFixed(1),
      'kkm': g.subject.kkm.toStringAsFixed(0),
      'status': (g.finalGrade ?? 0.0) >= g.subject.kkm ? 'Tuntas' : 'Remedial',
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header: Student Info & Status Pill ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: statusColor.withAlpha(25),
                  child: Text(
                    student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : 'S',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Kelas ${student.className ?? student.classId ?? "-"}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'NIS: ${student.nis ?? student.username}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ─── Key KPI Cards Row ───
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                _buildMetricChip(
                  label: 'Rata-rata Ujian',
                  value: overallExamAvg != null ? overallExamAvg.toStringAsFixed(1) : '-',
                  color: const Color(0xFF2563EB),
                  icon: Icons.quiz_rounded,
                ),
                const SizedBox(width: 8),
                _buildMetricChip(
                  label: 'Rata-rata Tugas',
                  value: overallTaskAvg != null ? overallTaskAvg.toStringAsFixed(1) : '-',
                  color: const Color(0xFF059669),
                  icon: Icons.assignment_turned_in_rounded,
                ),
                const SizedBox(width: 8),
                _buildMetricChip(
                  label: 'Ketuntasan Tugas',
                  value: totalTasksCount > 0 ? '$completedTasksTotal/$totalTasksCount' : '-',
                  color: const Color(0xFFD97706),
                  icon: Icons.task_alt_rounded,
                ),
                const SizedBox(width: 8),
                _buildMetricChip(
                  label: 'Nilai Rapor',
                  value: overallFinalAvg != null ? overallFinalAvg.toStringAsFixed(1) : '-',
                  color: const Color(0xFF7C3AED),
                  icon: Icons.emoji_events_rounded,
                ),
              ],
            ),
          ),

          // ─── GRAFIK: DUAL BAR CHART (UJIAN VS TUGAS PER MAPEL) ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _StudentDualBarChart(grades: grades),
          ),

          // ─── KESIMPULAN DARI GRAFIK (TEPAT DI BAWAH GRAFIK) ───
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: _StudentGraphConclusionBox(
              studentName: student.fullName,
              className: student.className ?? student.classId ?? 'Kelas',
              overallExamAvg: overallExamAvg,
              overallTaskAvg: overallTaskAvg,
              overallFinalAvg: overallFinalAvg,
              completedTasks: completedTasksTotal,
              totalTasks: totalTasksCount,
              strongestSubject: strongestSubject,
              weakestSubject: weakestSubject,
              remedialSubjects: remedialSubjects,
              statusColor: statusColor,
              statusLabel: statusLabel,
              hasData: hasData,
              superiorCps: superiorCps,
              superiorMaterials: superiorMaterials,
              subjectScores: subjectSummary,
            ),
          ),

          // ─── Collapsible detail table per mapel ───
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(
                'Lihat Rincian Lengkap per Mata Pelajaran (${grades.length} Mapel)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              children: grades.map((g) {
                final examVal = g.examAverage;
                final taskVal = g.assignmentAverage;
                final finalVal = g.finalGrade ?? 0.0;
                final isPass = finalVal >= g.subject.kkm;

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.subject.name,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'KKM: ${g.subject.kkm.toStringAsFixed(0)}  •  Ujian: ${examVal != null ? examVal.toStringAsFixed(1) : "-"}  •  Tugas: ${taskVal != null ? taskVal.toStringAsFixed(1) : "-"}  •  Bonus: +${g.bonusGrade.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPass ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isPass ? Colors.green.shade200 : Colors.red.shade200),
                        ),
                        child: Text(
                          '${finalVal > 0 ? finalVal.toStringAsFixed(1) : "-"} (${g.predicate})',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isPass ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(35)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(height: 3),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DUAL BAR CHART: UJIAN VS TUGAS PER MAPEL WITH KKM (75) THRESHOLD
// ─────────────────────────────────────────────────────────────────────────────
class _StudentDualBarChart extends StatelessWidget {
  final List<StudentSubjectGrade> grades;

  const _StudentDualBarChart({required this.grades});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title & Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Grafik Nilai Ujian vs Tugas',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendItem(const Color(0xFF2563EB), 'Ujian'),
                  const SizedBox(width: 8),
                  _legendItem(const Color(0xFF059669), 'Tugas'),
                  const SizedBox(width: 8),
                  _legendItem(const Color(0xFFEF4444), 'KKM 75', isDashed: true),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Chart Canvas
          SizedBox(
            height: 165,
            child: Row(
              children: [
                // Y-Axis Scale
                SizedBox(
                  width: 32,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text('100', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
                      Text('75', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                      Text('50', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
                      Text('25', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
                      Text('0', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Chart Grid & Bars
                Expanded(
                  child: Stack(
                    children: [
                      // Background grid lines
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Divider(height: 1, thickness: 0.8, color: Color(0xFFE2E8F0)),
                          Container(height: 1, color: const Color(0xFFEF4444).withAlpha(160)),
                          const Divider(height: 1, thickness: 0.8, color: Color(0xFFE2E8F0)),
                          const Divider(height: 1, thickness: 0.8, color: Color(0xFFE2E8F0)),
                          const Divider(height: 1, thickness: 1.2, color: Color(0xFFCBD5E1)),
                        ],
                      ),

                      // Grouped Bars Container
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: grades.map((g) {
                            final examScore = g.examAverage ?? 0.0;
                            final taskScore = g.assignmentAverage ?? 0.0;
                            final subjectCode = g.subject.code.isNotEmpty
                                ? g.subject.code
                                : (g.subject.name.length > 5 ? g.subject.name.substring(0, 5) : g.subject.name);

                            const double maxBarHeight = 120.0;
                            final examBarHeight = ((examScore / 100.0) * maxBarHeight).clamp(4.0, maxBarHeight);
                            final taskBarHeight = ((taskScore / 100.0) * maxBarHeight).clamp(4.0, maxBarHeight);

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // Exam Bar (Blue)
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            g.examAverage != null ? '${examScore.toInt()}' : '-',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1D4ED8),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Container(
                                            width: 16,
                                            height: examBarHeight,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                              ),
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF2563EB).withAlpha(30),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 4),

                                      // Task Bar (Emerald)
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            g.assignmentAverage != null ? '${taskScore.toInt()}' : '-',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF047857),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Container(
                                            width: 16,
                                            height: taskBarHeight,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [Color(0xFF10B981), Color(0xFF047857)],
                                              ),
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF059669).withAlpha(30),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    subjectCode,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String text, {bool isDashed = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isDashed ? 12 : 8,
          height: isDashed ? 2 : 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(isDashed ? 0 : 2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: isDashed ? color : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KESIMPULAN & EVALUASI DARI GRAFIK (DI BAWAH GRAFIK PER SISWA)
// ─────────────────────────────────────────────────────────────────────────────
class _StudentGraphConclusionBox extends StatelessWidget {
  final String studentName;
  final String className;
  final double? overallExamAvg;
  final double? overallTaskAvg;
  final double? overallFinalAvg;
  final int completedTasks;
  final int totalTasks;
  final StudentSubjectGrade? strongestSubject;
  final StudentSubjectGrade? weakestSubject;
  final List<StudentSubjectGrade> remedialSubjects;
  final Color statusColor;
  final String statusLabel;
  final bool hasData;
  final List<String> superiorCps;
  final List<String> superiorMaterials;
  final List<Map<String, dynamic>> subjectScores;

  const _StudentGraphConclusionBox({
    required this.studentName,
    required this.className,
    required this.overallExamAvg,
    required this.overallTaskAvg,
    required this.overallFinalAvg,
    required this.completedTasks,
    required this.totalTasks,
    required this.strongestSubject,
    required this.weakestSubject,
    required this.remedialSubjects,
    required this.statusColor,
    required this.statusLabel,
    required this.hasData,
    this.superiorCps = const [],
    this.superiorMaterials = const [],
    this.subjectScores = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (!hasData) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF64748B)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Belum ada data nilai ujian atau pengerjaan tugas yang terekam untuk siswa ini.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      );
    }

    final examStr = overallExamAvg != null ? overallExamAvg!.toStringAsFixed(1) : '-';
    final taskStr = overallTaskAvg != null ? overallTaskAvg!.toStringAsFixed(1) : '-';
    final bool hasRemedial = remedialSubjects.isNotEmpty;

    // Narrative comparison between exams and assignments
    String balanceNarrative;
    if (overallExamAvg != null && overallTaskAvg != null) {
      final diff = overallExamAvg! - overallTaskAvg!;
      if (diff >= 6.0) {
        balanceNarrative = 'Daya serap pada ujian ($examStr) lebih tinggi dibandingkan tugas ($taskStr). Siswa memahami materi dengan sangat baik saat ujian, namun perlu dimotivasi untuk meningkatkan konsistensi pengumpulan tugas mandiri.';
      } else if (diff <= -6.0) {
        balanceNarrative = 'Ketekunan dalam pengerjaan tugas ($taskStr) sangat tinggi melampaui capaian ujian ($examStr). Disarankan memperbanyak latihan soal evaluasi berbasis waktu untuk mengasah kesiapan mental saat ujian.';
      } else {
        balanceNarrative = 'Performa antara pemahaman konsep ujian ($examStr) dan pengerjaan tugas ($taskStr) berjalan seimbang dan konsisten.';
      }
    } else {
      balanceNarrative = 'Data evaluasi saat ini berfokus pada instrumen penilaian aktif siswa.';
    }

    // Task compliance narrative
    final int pct = totalTasks > 0 ? ((completedTasks / totalTasks) * 100).toInt() : 100;
    final String taskComplianceText = '$completedTasks dari $totalTasks tugas diselesaikan ($pct%). ${pct >= 80 ? "Kedisiplinan pengumpulan tugas tergolong sangat baik." : "Perlu tindak lanjut untuk menyelesaikan sisa tugas yang belum diserahkan."}';

    // Remedial vs Mastery narrative
    String remedialNarrative;
    if (hasRemedial) {
      final names = remedialSubjects.map((g) {
        final f = g.finalGrade ?? g.examAverage ?? g.assignmentAverage ?? 0.0;
        return '${g.subject.name} (${f.toStringAsFixed(1)})';
      }).join(', ');
      remedialNarrative = 'Terdapat ${remedialSubjects.length} mata pelajaran belum mencapai ambang batas KKM (75): $names. Siswa memerlukan program remedial atau bimbingan khusus.';
    } else {
      remedialNarrative = 'Seluruh mata pelajaran telah berhasil melampaui batas standar KKM (75) secara tuntas.';
    }

    // Pedagogical Recommendation
    String recommendationText;
    if (hasRemedial) {
      recommendationText = 'Jadwalkan sesi remedial kuis/tugas bersama guru pengampu untuk mapel di bawah KKM sebelum penilaian akhir semester.';
    } else if ((overallFinalAvg ?? 0) >= 88.0) {
      recommendationText = 'Prestasi akademik sangat membanggakan di atas KKM. Pertahankan ritme belajar dan rekomendasikan siswa sebagai tutor sebaya atau peserta lomba kejuruan.';
    } else {
      recommendationText = 'Pertahankan capaian belajar yang telah memenuhi standar KKM dan dorong peningkatan nilai pada tugas proyek lanjutan.';
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withAlpha(45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.insights_rounded, size: 16, color: statusColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kesimpulan & Evaluasi Grafik',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Overview narrative
          Text(
            balanceNarrative,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),

          // Diagnostic bullets
          if (strongestSubject != null)
            _bulletItem(
              Icons.star_rounded,
              Colors.amber.shade800,
              'Mapel Terkuat',
              '${strongestSubject!.subject.name} (Rata-rata: ${(strongestSubject!.finalGrade ?? strongestSubject!.examAverage ?? 0.0).toStringAsFixed(1)})',
            ),
          _bulletItem(
            hasRemedial ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
            hasRemedial ? Colors.red.shade700 : Colors.green.shade700,
            hasRemedial ? 'Evaluasi KKM' : 'Status Kelulusan',
            remedialNarrative,
          ),
          _bulletItem(
            Icons.assignment_turned_in_rounded,
            Colors.blue.shade700,
            'Ketuntasan Tugas',
            taskComplianceText,
          ),

          const Divider(height: 14, color: Color(0xFFE2E8F0)),

          // Pedagogical Recommendation
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_rounded, size: 15, color: Colors.orange.shade800),
              const SizedBox(width: 6),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: const Color(0xFF7C2D12),
                    ),
                    children: [
                      const TextSpan(
                        text: 'Rekomendasi Tindak Lanjut: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: recommendationText),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bulletItem(IconData icon, Color color, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 11, height: 1.35, color: Color(0xFF334155)),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. PROFIL & PENGATURAN ADMIN
// ─────────────────────────────────────────────────────────────────────────────
class _AdminProfilePage extends StatelessWidget {
  final UserModel? currentUser;
  final FirebaseService fb;

  const _AdminProfilePage({required this.currentUser, required this.fb});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const CurvedHeaderCard(
              title: 'Profil Akun',
              subtitle: 'Pengaturan Akun & Hak Akses',
              showBackButton: false,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 90),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(8),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: const Color(0xFF1E3A8A),
                            child: const Icon(Icons.person_rounded, size: 40, color: Colors.amberAccent),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            currentUser?.fullName ?? 'Administrator',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            'Username: @${currentUser?.username ?? "admin"}',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'HAK AKSES PENUH',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                          const Divider(height: 28),
                          _infoTile('Status Sistem', 'Online & Terhubung Cloud'),
                          _infoTile('Role Pengguna', 'Super Administrator'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // App Updates & APK Release Manager
                    _buildAppUpdateManagerCard(context, fb),

                    const SizedBox(height: 16),

                    // Danger Zone: Reset Database
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Zona Berbahaya',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Hapus semua data siswa, kelas, mapel, materi, kuis, nilai, dan obrolan. Hanya akun Admin dan Guru yang dipertahankan.',
                            style: TextStyle(fontSize: 12, color: Colors.red.shade900, height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade400),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _confirmResetDatabase(context, fb),
                              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                              label: const Text(
                                'Reset Semua Data (Kecuali Admin & Guru)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        onPressed: () => fb.logout(),
                        icon: const Icon(Icons.logout_rounded),
                        label: Text(
                          'Keluar dari Akun',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
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
    ),
  );
  }

  Future<void> _confirmResetDatabase(BuildContext context, FirebaseService fb) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red.shade700),
            const SizedBox(width: 10),
            const Expanded(child: Text('Reset Database?')),
          ],
        ),
        content: const Text(
          'Semua data siswa, kelas, mata pelajaran, materi belajar, kuis, riwayat nilai, dan pesan chat akan dihapus permanen dari Cloud Firestore dan memori.\n\n'
          'Akun Admin dan Akun Guru akan tetap tersimpan.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Hapus Semua Data'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await showLoadingDialog(
        context,
        message: 'Menghapus semua data & NIS di Cloud Firestore...',
        action: () async {
          await fb.wipeAllDataExceptAdminAndTeachers();
        },
        successMessage:
            'Semua data berhasil dibersihkan! Seluruh data siswa & NIS lama telah terhapus dari Firebase dan siap digunakan kembali.',
        errorMessage: 'Gagal mereset data.',
      );
    }
  }

  Widget _infoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAppUpdateManagerCard(BuildContext context, FirebaseService fb) {
    final serverVer = fb.appVersionConfig;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDD6FE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D28D9).withAlpha(10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.system_update_rounded, color: Color(0xFF6D28D9), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pembaruan & Rilis APK',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2E1065),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kelola rilis APK baru & cek pembaruan otomatis',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Versi di Server Firebase:', style: TextStyle(fontSize: 12, color: Colors.black87)),
                    Text(
                      serverVer != null ? 'v${serverVer.latestVersion} (Build ${serverVer.versionCode})' : 'Belum dikonfigurasi',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                    ),
                  ],
                ),
                if (serverVer != null && serverVer.apkUrl.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Link APK:', style: TextStyle(fontSize: 12, color: Colors.black87)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          serverVer.apkUrl,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade700, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6D28D9),
                    side: const BorderSide(color: Color(0xFF7C3AED)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => AppUpdateDialog.handleManualUpdateCheck(context),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Cek Update', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 1,
                  ),
                  onPressed: () => _showPublishReleaseDialog(context, fb),
                  icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                  label: const Text('Rilis APK Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPublishReleaseDialog(BuildContext context, FirebaseService fb) {
    final currentConfig = fb.appVersionConfig;
    final versionController = TextEditingController(text: currentConfig?.latestVersion ?? '1.0.1');
    final codeController = TextEditingController(text: '${(currentConfig?.versionCode ?? 1) + 1}');
    final urlController = TextEditingController(text: currentConfig?.apkUrl ?? '');
    final notesController = TextEditingController(
      text: currentConfig?.releaseNotes.isNotEmpty == true
          ? currentConfig!.releaseNotes
          : 'Pembaruan aplikasi: perbaikan stabilitas dan penambahan fitur baru.',
    );
    bool forceUpdate = currentConfig?.forceUpdate ?? false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF6D28D9), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Rilis Versi APK Baru',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saat rilis baru dipublikasikan, seluruh siswa & guru yang membuka aplikasi akan langsung melihat dialog pembaruan otomatis.',
                    style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: versionController,
                    decoration: InputDecoration(
                      labelText: 'Versi Baru (cth: 1.0.1)',
                      labelStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      prefixIcon: const Icon(Icons.label_outline_rounded, size: 18),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Versi tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Kode Versi / Version Code (cth: 2)',
                      labelStyle: const TextStyle(fontSize: 13),
                      helperText: 'Harus lebih tinggi dari kode versi sekarang',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      prefixIcon: const Icon(Icons.numbers_rounded, size: 18),
                    ),
                    validator: (v) {
                      final code = int.tryParse(v ?? '');
                      if (code == null || code <= 0) return 'Masukkan angka yang valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: urlController,
                    decoration: InputDecoration(
                      labelText: 'Link Download APK Langsung',
                      labelStyle: const TextStyle(fontSize: 13),
                      hintText: 'https://...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      prefixIcon: const Icon(Icons.link_rounded, size: 18),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'URL APK tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Catatan Rilis / Fitur Baru',
                      labelStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Wajibkan Pembaruan (Force Update)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Pengguna tidak bisa menutup dialog update sebelum memperbarui', style: TextStyle(fontSize: 11, color: Colors.black54)),
                    value: forceUpdate,
                    activeTrackColor: const Color(0xFF7C3AED),
                    onChanged: (val) => setModalState(() => forceUpdate = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogCtx).pop();
                  await showLoadingDialog(
                    context,
                    message: 'Mempublikasikan versi baru ke Cloud Firestore & mengirim notifikasi...',
                    action: () async {
                      await fb.publishAppUpdate(
                        version: versionController.text.trim(),
                        versionCode: int.parse(codeController.text.trim()),
                        apkUrl: urlController.text.trim(),
                        releaseNotes: notesController.text.trim(),
                        forceUpdate: forceUpdate,
                      );
                    },
                    successMessage: 'Pembaruan versi ${versionController.text.trim()} berhasil dipublikasikan!',
                    errorMessage: 'Gagal mempublikasikan pembaruan aplikasi.',
                  );
                }
              },
              icon: const Icon(Icons.publish_rounded, size: 16),
              label: const Text('Publikasikan Rilis', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
