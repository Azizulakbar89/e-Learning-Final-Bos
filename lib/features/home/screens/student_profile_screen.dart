import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/gamification_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/app_update_dialog.dart';
import '../../../core/widgets/universal_app_header.dart';
import '../widgets/badge_share_dialog.dart';

class StudentProfileScreen extends StatefulWidget {
  final VoidCallback? onOpenLeaderboard;

  const StudentProfileScreen({super.key, this.onOpenLeaderboard});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  String _badgeFilter = 'all'; // all | earned | locked
  bool _badgeCheckDone = false;

  @override
  void initState() {
    super.initState();
    // Sinkronisasi badge yang sudah dimiliki secara senyap tanpa popup
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncBadgesSilently());
  }

  Future<void> _syncBadgesSilently() async {
    if (_badgeCheckDone) return;
    _badgeCheckDone = true;
    if (!mounted) return;
    final fb = context.read<FirebaseService>();
    final currentUser = fb.currentUser;
    if (currentUser == null || !currentUser.isSiswa) return;
    final badges = fb.getStudentBadges(currentUser);
    await BadgeShareDialog.syncExistingBadges(
      badges: badges,
      student: currentUser,
    );
  }

  void _showEditProfileDialog(BuildContext context, UserModel currentUser, FirebaseService fb) {
    final availableClasses = fb.getAvailableClasses();
    String? selectedClass = currentUser.className ?? currentUser.classId;
    if (selectedClass != null && !availableClasses.contains(selectedClass)) {
      selectedClass = null;
    }
    if (selectedClass == null && availableClasses.isNotEmpty) {
      selectedClass = availableClasses.first;
    }

    final passController = TextEditingController();
    final confirmPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();
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
                          color: AppColors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.manage_accounts_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Ubah Data Siswa',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ubah data kelas dan password akun pembelajaran Anda.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Class Selector Dropdown
                  Text(
                    'Kelas Saat Ini',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  if (availableClasses.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.amber.withAlpha(80)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: AppColors.amber, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Belum ada kelas yang diinput oleh Admin. Kelas belum dapat diubah.',
                              style: TextStyle(fontSize: 11.5, color: AppColors.amber, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedClass,
                        items: availableClasses.isEmpty
                            ? [
                                const DropdownMenuItem(
                                  value: null,
                                  enabled: false,
                                  child: Text('Belum ada kelas dari Admin', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                ),
                              ]
                            : availableClasses
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text('Kelas $c', style: const TextStyle(fontSize: 14)),
                                    ))
                                .toList(),
                        onChanged: availableClasses.isEmpty
                            ? null
                            : (val) {
                                if (val != null) {
                                  setModalState(() => selectedClass = val);
                                }
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  Text(
                    'Password Baru (Kosongkan jika tidak ingin ganti)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: passController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      hintText: 'Masukkan password baru...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setModalState(() => obscure = !obscure),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Confirm Password
                  if (passController.text.isNotEmpty) ...[
                    Text(
                      'Konfirmasi Password Baru',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: confirmPassController,
                      obscureText: obscure,
                      validator: (val) {
                        if (passController.text.isNotEmpty && val != passController.text) {
                          return 'Konfirmasi password tidak cocok!';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'Ketik ulang password baru...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderLight),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 8),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (formKey.currentState?.validate() ?? false) {
                          final newPass = passController.text.trim();
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          await showLoadingDialog(
                            context,
                            message: 'Memperbarui profil...',
                            action: () async {
                              await fb.updateStudentProfile(
                                studentId: currentUser.id,
                                className: selectedClass,
                                newPassword: newPass.isNotEmpty ? newPass : null,
                              );
                            },
                            successMessage: 'Data profil berhasil diperbarui!',
                            errorMessage: 'Gagal memperbarui profil.',
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Simpan Perubahan',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showBadgeDetailDialog(BuildContext context, BadgeModel badge) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badge.isEarned ? badge.color.withAlpha(25) : Colors.grey.shade100,
                border: Border.all(
                  color: badge.isEarned ? badge.color : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(badge.icon, style: const TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              badge.title,
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badge.isEarned ? AppColors.emerald.withAlpha(20) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    badge.isEarned ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                    size: 14,
                    color: badge.isEarned ? AppColors.emerald : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    badge.isEarned ? 'Lencana Diraih' : 'Terkunci',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: badge.isEarned ? AppColors.emerald : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              badge.description,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Progress bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Progres Pencapaian',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        badge.progressText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: badge.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: badge.progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(badge.color),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // How to get
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: badge.color.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, size: 16, color: badge.color),
                      const SizedBox(width: 6),
                      Text(
                        'Cara Mendapatkan:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: badge.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badge.howToGet,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
            if (badge.isMonthly) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B).withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.autorenew_rounded, size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lencana Musiman (${badge.periodLabel}). Reset tiap tanggal 1 awal bulan.',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            if (badge.isEarned) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final fb = context.read<FirebaseService>();
                    final user = fb.currentUser;
                    if (user != null) {
                      BadgeShareDialog.showSingleBadge(
                        context: context,
                        badge: badge,
                        student: user,
                      );
                    }
                  },
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Bagikan Lencana Ini 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final currentUser = fb.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final badges = fb.getStudentBadges(currentUser);
    final earnedBadges = badges.where((b) => b.isEarned).toList();
    final lockedBadges = badges.where((b) => !b.isEarned).toList();

    final monthlyBadges = badges.where((b) => b.isMonthly).toList();
    final permanentBadges = badges.where((b) => !b.isMonthly).toList();

    List<BadgeModel> displayBadges;
    if (_badgeFilter == 'earned') {
      displayBadges = earnedBadges;
    } else if (_badgeFilter == 'locked') {
      displayBadges = lockedBadges;
    } else if (_badgeFilter == 'monthly') {
      displayBadges = monthlyBadges;
    } else if (_badgeFilter == 'permanent') {
      displayBadges = permanentBadges;
    } else {
      displayBadges = badges;
    }

    final monthlyPoints = fb.getStudentMonthlyPoints(currentUser);
    final userClass = currentUser.className ?? currentUser.classId ?? '';
    final leaderboard = fb.getClassLeaderboard(userClass);
    final rankIdx = leaderboard.indexWhere((s) => s.id == currentUser.id);
    final rankNumber = rankIdx != -1 ? rankIdx + 1 : 1;

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
                          'Profil & Lencana',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Kelola Akun & Pencapaian Belajar',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => fb.logout(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withAlpha(45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEF4444).withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.logout_rounded, color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text(
                            'Keluar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
                children: [
                  // Student Profile Card
                  _buildProfileCard(
                    context: context,
                  student: currentUser,
                  monthlyPoints: monthlyPoints,
                  rankNumber: rankNumber,
                  earnedBadgesCount: earnedBadges.length,
                  totalBadgesCount: badges.length,
                  onEditTap: () => _showEditProfileDialog(context, currentUser, fb),
                ),
                const SizedBox(height: 16),


                // Push Notification & Device Token Card
                _buildNotificationCard(context),
                const SizedBox(height: 12),

                // App Version & Update Card
                _buildAppUpdateCard(context),
                const SizedBox(height: 20),

                // Badges Section Header & Filter
                Row(
                  children: [
                    Text(
                      'Lencana Gamifikasi',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${earnedBadges.length} / ${badges.length} Diraih',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Overall progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: badges.isNotEmpty ? earnedBadges.length / badges.length : 0.0,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 14),

                // Filter Buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _badgeFilterChip('Semua (${badges.length})', 'all'),
                      const SizedBox(width: 8),
                      _badgeFilterChip('📅 Reset Bulanan (${monthlyBadges.length})', 'monthly'),
                      const SizedBox(width: 8),
                      _badgeFilterChip('🏆 Permanen (${permanentBadges.length})', 'permanent'),
                      const SizedBox(width: 8),
                      _badgeFilterChip('Diraih (${earnedBadges.length})', 'earned'),
                      const SizedBox(width: 8),
                      _badgeFilterChip('Belum (${lockedBadges.length})', 'locked'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Horizontal Carousel of Badges
                if (displayBadges.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.military_tech_outlined, size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'Tidak ada lencana pada kategori ini',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 190,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          clipBehavior: Clip.none,
                          itemCount: displayBadges.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 12),
                          itemBuilder: (ctx, idx) {
                            final badge = displayBadges[idx];
                            return SizedBox(
                              width: 175,
                              child: _BadgeCard(
                                badge: badge,
                                onTap: () => _showBadgeDetailDialog(context, badge),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.swipe_outlined,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Geser horizontal untuk melihat ${displayBadges.length} lencana',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _badgeFilterChip(String label, String value) {
    final isSelected = _badgeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _badgeFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withAlpha(40),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimaryLight,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navyLight, AppColors.navy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withAlpha(30),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Push Notifikasi',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withAlpha(12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.navy.withAlpha(30)),
                      ),
                      child: const Text(
                        'Aktif',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Ujian, tugas & pengumuman',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => FcmService.triggerTestNotification(context),
            icon: const Icon(Icons.notifications_active_rounded, size: 15),
            label: Text(
              'Tes Pop-Up',
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppUpdateCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.orange, AppColors.orangeDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange.withAlpha(35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pembaruan Aplikasi',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Cek versi & perbaikan sistem',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => AppUpdateDialog.handleManualUpdateCheck(context),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              'Cek Update',
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard({
    required BuildContext context,
    required UserModel student,
    required int monthlyPoints,
    required int rankNumber,
    required int earnedBadgesCount,
    required int totalBadgesCount,
    required VoidCallback onEditTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.orange, AppColors.orangeDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NIS: ${student.nis ?? "-"} • Kelas: ${student.className ?? student.classId ?? "-"}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onEditTap,
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: Text(
                  'Edit Profile',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Stats row - Variasi Gradasi Orange & Biru Dongker
          Row(
            children: [
              Expanded(
                child: _profileStatCard(
                  emoji: '🌟',
                  value: '${student.totalPoints}',
                  label: 'Total Poin',
                  bg: const Color(0xFFFFF7ED), // Soft Orange Tint
                  border: const Color(0xFFFED7AA),
                  textColor: const Color(0xFFC2410C),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _profileStatCard(
                  emoji: '🔥',
                  value: '$monthlyPoints',
                  label: 'Bulan Ini',
                  bg: const Color(0xFFFFFBEB), // Amber Orange Tint
                  border: const Color(0xFFFDE68A),
                  textColor: const Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _profileStatCard(
                  emoji: '🏅',
                  value: '$earnedBadgesCount/$totalBadgesCount',
                  label: 'Lencana',
                  bg: const Color(0xFFF0F4F8), // Soft Navy Tint
                  border: const Color(0xFFCBD5E1),
                  textColor: const Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _profileStatCard(
                  emoji: '🏆',
                  value: '#$rankNumber',
                  label: 'Peringkat',
                  bg: const Color(0xFFE2E8F0), // Solid Navy Slate Tint
                  border: const Color(0xFF94A3B8),
                  textColor: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileStatCard({
    required String emoji,
    required String value,
    required String label,
    required Color bg,
    required Color border,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: textColor.withAlpha(200),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }


}

// ─── Badge Card Widget (Mobile Precision) ───
class _BadgeCard extends StatelessWidget {
  final BadgeModel badge;
  final VoidCallback onTap;

  const _BadgeCard({
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final earnedColor = badge.color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: badge.isEarned
              ? Colors.white
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: badge.isEarned
                ? earnedColor.withAlpha(130)
                : const Color(0xFFE2E8F0),
            width: badge.isEarned ? 1.5 : 1,
          ),
          boxShadow: badge.isEarned
              ? [
                  BoxShadow(
                    color: earnedColor.withAlpha(25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row: Icon + Category Pill + Lock ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gradient Icon Container with optional glow
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: badge.isEarned
                          ? LinearGradient(
                              colors: [
                                earnedColor.withAlpha(50),
                                earnedColor.withAlpha(25),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: badge.isEarned ? null : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(13),
                      border: badge.isEarned
                          ? Border.all(color: earnedColor.withAlpha(80), width: 1)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        badge.icon,
                        style: TextStyle(
                          fontSize: 22,
                          color: badge.isEarned ? null : null,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Category pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badge.isMonthly
                              ? const Color(0xFFFEF9C3)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: badge.isMonthly
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFBFDBFE),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          badge.isMonthly ? 'Bulanan' : 'Permanen',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: badge.isMonthly
                                ? const Color(0xFF92400E)
                                : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Status indicator
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: badge.isEarned
                              ? AppColors.emerald.withAlpha(20)
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          badge.isEarned
                              ? Icons.check_circle_rounded
                              : Icons.lock_outline_rounded,
                          size: 14,
                          color: badge.isEarned
                              ? AppColors.emerald
                              : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ── Title ──
              Text(
                badge.title,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: badge.isEarned
                      ? AppColors.textPrimaryLight
                      : Colors.grey.shade500,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              // ── Description ──
              Expanded(
                child: Text(
                  badge.description,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: badge.isEarned
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 7),
              // ── Progress Bar ──
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: badge.progress,
                  backgroundColor: badge.isEarned
                      ? earnedColor.withAlpha(20)
                      : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    badge.isEarned ? earnedColor : Colors.grey.shade300,
                  ),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 4),
              // ── Progress Label ──
              Text(
                badge.isEarned ? '✅ Diraih' : badge.progressText,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: badge.isEarned ? earnedColor : Colors.grey.shade400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
