import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../features/social_and_gamification/screens/chat_list_screen.dart';
import '../../features/social_and_gamification/screens/notification_center_screen.dart';
import '../services/firebase_service.dart';

/// Universal floating modern header matching the design:
/// Deep Indigo/Purple gradient card, neon gradient avatar, greeting,
/// class & NIS/ID pills, fire streak badge, and chat button.
class UniversalAppHeader extends StatelessWidget {
  final bool showBackButton;
  final String? customTitle;
  final String? customSubtitle;
  final Widget? bottomContent;
  final Widget? trailingActions;

  const UniversalAppHeader({
    super.key,
    this.showBackButton = false,
    this.customTitle,
    this.customSubtitle,
    this.bottomContent,
    this.trailingActions,
  });

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final user = fb.currentUser;
    final isTeacher = user?.isGuru ?? false;

    final fullName = user?.fullName ?? (isTeacher ? 'Bapak/Ibu Guru' : 'Siswa');
    final firstName = fullName.split(' ').first;
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : (isTeacher ? 'G' : 'S');
    final availableClasses = fb.getAvailableClasses();
    final teacherClasses = isTeacher ? fb.getTeacherClasses(user) : <String>[];
    final defaultClass = availableClasses.isNotEmpty ? availableClasses.first : 'Umum';
    final classId = isTeacher
        ? (teacherClasses.isNotEmpty
            ? (teacherClasses.length == 1 ? teacherClasses.first : '${teacherClasses.length} Kelas')
            : 'Belum Diplot')
        : (user?.className ?? user?.classId ?? defaultClass);
    final idNumber = isTeacher ? (user?.nis ?? user?.username ?? 'GURU') : (user?.nis ?? '2727');
    final teacherLabel = teacherClasses.isNotEmpty
        ? (teacherClasses.length == 1 ? 'Kelas ${teacherClasses.first}' : '${teacherClasses.length} Kelas Ajar')
        : 'Belum Diplot Admin';

    final streak = isTeacher ? 0 : fb.getEffectiveStreakCount(user?.id);
    final isStreakActive = !isTeacher && fb.hasActiveStreak(user?.id);
    final studyStreak = isTeacher ? null : fb.getStudyStreak(user?.id);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF060F1E), // Darkest Navy
            Color(0xFF0A1931), // Deep Navy
            Color(0xFF0F2552), // Primary Navy
            Color(0xFF1E3A8A), // Medium Navy
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x280A1931),
            blurRadius: 20,
            offset: Offset(0, 6),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Colors.white.withAlpha(24),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
          if (showBackButton) ...[
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(24),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withAlpha(35)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // Avatar with calibrated orange gradient accent ring
          Container(
            width: 50,
            height: 50,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFB923C), // Soft Warm Orange
                  Color(0xFFEA580C), // Deep Rich Orange
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEA580C).withAlpha(50),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0A1931),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Greeting and Info Pills
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  customTitle ?? 'Halo, $firstName! 👋',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Class pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withAlpha(60)),
                      ),
                      child: Text(
                        customSubtitle ?? (isTeacher ? teacherLabel : 'Kelas $classId'),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // NIS or NIP pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        isTeacher ? 'NIP: $idNumber' : 'NIS: $idNumber',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withAlpha(220),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Fire streak pill (Hanya untuk siswa yang aktif belajar/mengerjakan tugas/kuis)
          if (!isTeacher) ...[
            GestureDetector(
              onTap: () => _showStreakInfoDialog(context, streak, isStreakActive, studyStreak),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  gradient: isStreakActive
                      ? const LinearGradient(
                          colors: [Color(0xFFFF5722), Color(0xFFFF9800)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF334155), Color(0xFF475569)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: isStreakActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF5722).withAlpha(100),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isStreakActive ? '🔥' : '💤', style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '$streak',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Tombol Notifikasi Materi & Kuis untuk Siswa & Guru
          Material(
            color: Colors.transparent,
            child: Tooltip(
              message: 'Pusat Notifikasi Kelas',
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(50)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.notifications_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    Builder(
                      builder: (ctx) {
                        final unreadCount = fb.getUnreadNotificationCount(user);
                        if (unreadCount <= 0) return const SizedBox.shrink();
                        return Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              shape: unreadCount > 9 ? BoxShape.rectangle : BoxShape.circle,
                              borderRadius: unreadCount > 9 ? BorderRadius.circular(10) : null,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Logo / Tombol Pesan & Chat untuk Siswa & Guru
          Material(
            color: Colors.transparent,
            child: Tooltip(
              message: 'Pesan & Diskusi Belajar (Streaks)',
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatListScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(50)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          if (trailingActions != null) ...[
            const SizedBox(width: 8),
            trailingActions!,
          ],
        ],
      ),
      if (bottomContent != null) ...[
        const SizedBox(height: 12),
        bottomContent!,
      ],
    ],
  ),
);
  }

  void _showStreakInfoDialog(
    BuildContext context,
    int streakCount,
    bool isActive,
    dynamic studyStreak,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: Row(
          children: [
            Text(isActive ? '🔥' : '💤', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(
              isActive ? 'Streak Belajar Aktif' : 'Streak Belajar Padam',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.orange.shade900.withAlpha(50)
                    : const Color(0xFF1E293B).withAlpha(120),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? Colors.orangeAccent.withAlpha(100) : Colors.white24,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '$streakCount',
                    style: GoogleFonts.outfit(
                      color: isActive ? const Color(0xFFFF9800) : Colors.white60,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isActive
                          ? 'Hari berturut-turut Anda aktif belajar! Pertahankan apinya 🔥'
                          : 'Streak sedang padam. Selesaikan 1 aktivitas untuk menyalakannya kembali!',
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Cara Menyalakan & Menjaga Streak (Non-Chat):',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            _streakActivityItem('💬', 'Kirim Pesan & Chat', 'Kirim pesan setiap hari di chat kelas/guru untuk streak chat'),
            const SizedBox(height: 6),
            _streakActivityItem('📖', 'Belajar Modul Materi', 'Baca atau tonton video pembelajaran'),
            const SizedBox(height: 6),
            _streakActivityItem('📝', 'Mengerjakan Tugas', 'Kumpulkan submission tugas sekolah'),
            const SizedBox(height: 6),
            _streakActivityItem('🎯', 'Mengerjakan Ujian & Kuis', 'Selesaikan ujian atau kuis materi'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatListScreen()),
              );
            },
            icon: const Icon(Icons.chat_bubble_rounded, size: 15),
            label: const Text('Buka Pesan & Chat'),
          ),
        ],
      ),
    );
  }

  Widget _streakActivityItem(String emoji, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
