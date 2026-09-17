import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/universal_app_header.dart';

class StudentLeaderboardScreen extends StatefulWidget {
  const StudentLeaderboardScreen({super.key});

  @override
  State<StudentLeaderboardScreen> createState() =>
      _StudentLeaderboardScreenState();
}

class _StudentLeaderboardScreenState extends State<StudentLeaderboardScreen> {
  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final currentUser = fb.currentUser;
    final userClass = currentUser?.className ?? currentUser?.classId ?? 'X-RPL-1';
    final leaderboard = fb.getClassLeaderboard(userClass);

    final currentStudentRank = leaderboard.indexWhere((s) => s.id == currentUser?.id);
    final myMonthlyPoints = currentUser != null ? fb.getStudentMonthlyPoints(currentUser) : 0;

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
                  // Row Info Peringkat
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.emoji_events_rounded,
                            color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Peringkat Kelas',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Papan Skor Prestasi • Reset Tiap Bulan',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(35),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withAlpha(50)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 13),
                            SizedBox(width: 4),
                            Text(
                              'Top Siswa',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Sub-row: Reset notification and my rank pill
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Reset Tanggal 1 Tiap Bulan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (currentStudentRank != -1)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Posisi: #${currentStudentRank + 1} ($myMonthlyPoints Poin)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFD97706),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                children: [
                  // Info Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Peringkat dihitung berdasarkan akumulasi poin belajar bulan ini. Tingkatkan quiz & tugasmu!',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Top 3 Podium
                  if (leaderboard.isNotEmpty) ...[
                    _buildPodium(context, leaderboard, fb, currentUser?.id),
                    const SizedBox(height: 20),
                  ],

                  // Full Rankings List Header
                  Row(
                    children: [
                      Text(
                        'Semua Siswa Kelas $userClass',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${leaderboard.length} Siswa',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // List of classmates
                  if (leaderboard.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada siswa di kelas ini.',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  else
                    ...List.generate(leaderboard.length, (idx) {
                      final student = leaderboard[idx];
                      final rank = idx + 1;
                      final isMe = student.id == currentUser?.id;
                      final monthlyPts = fb.getStudentMonthlyPoints(student);

                      return _LeaderboardRow(
                        rank: rank,
                        student: student,
                        isMe: isMe,
                        monthlyPoints: monthlyPts,
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Top 3 Podium Widget ───
  Widget _buildPodium(
    BuildContext context,
    List<UserModel> leaderboard,
    FirebaseService fb,
    String? currentUserId,
  ) {
    final first = leaderboard.isNotEmpty ? leaderboard[0] : null;
    final second = leaderboard.length > 1 ? leaderboard[1] : null;
    final third = leaderboard.length > 2 ? leaderboard[2] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd Place
              if (second != null)
                Expanded(
                  child: _podiumColumn(
                    rank: 2,
                    student: second,
                    points: fb.getStudentMonthlyPoints(second),
                    badge: '🥈',
                    height: 120,
                    color: const Color(0xFF94A3B8),
                    isMe: second.id == currentUserId,
                  ),
                )
              else
                const Expanded(child: SizedBox()),

              const SizedBox(width: 8),

              // 1st Place (Center, Tallest)
              if (first != null)
                Expanded(
                  child: _podiumColumn(
                    rank: 1,
                    student: first,
                    points: fb.getStudentMonthlyPoints(first),
                    badge: '👑',
                    height: 155,
                    color: const Color(0xFFF59E0B),
                    isMe: first.id == currentUserId,
                  ),
                )
              else
                const Expanded(child: SizedBox()),

              const SizedBox(width: 8),

              // 3rd Place
              if (third != null)
                Expanded(
                  child: _podiumColumn(
                    rank: 3,
                    student: third,
                    points: fb.getStudentMonthlyPoints(third),
                    badge: '🥉',
                    height: 100,
                    color: const Color(0xFFD97706),
                    isMe: third.id == currentUserId,
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _podiumColumn({
    required int rank,
    required UserModel student,
    required int points,
    required String badge,
    required double height,
    required Color color,
    required bool isMe,
  }) {
    final nameParts = student.fullName.split(' ');
    final displayName = nameParts.length > 1 ? '${nameParts[0]} ${nameParts[1][0]}.' : nameParts[0];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge emoji
        Text(badge, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),

        // Avatar
        Container(
          width: rank == 1 ? 48 : 42,
          height: rank == 1 ? 48 : 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isMe ? AppColors.primary : color,
              width: rank == 1 ? 3 : 2,
            ),
            color: color.withAlpha(30),
          ),
          child: Center(
            child: Text(
              student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : 'S',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: rank == 1 ? 18 : 15,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Name
        Text(
          displayName,
          style: GoogleFonts.inter(
            fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
            color: isMe ? AppColors.primary : AppColors.textPrimaryLight,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        if (isMe)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Kamu',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        const SizedBox(height: 6),

        // Podium Block
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withAlpha(50), color.withAlpha(150)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: color.withAlpha(100)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#$rank',
                style: GoogleFonts.outfit(
                  fontSize: rank == 1 ? 24 : 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 12, color: Color(0xFFD97706)),
                    const SizedBox(width: 3),
                    Text(
                      '$points',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Row for rankings list ───
class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final UserModel student;
  final bool isMe;
  final int monthlyPoints;

  const _LeaderboardRow({
    required this.rank,
    required this.student,
    required this.isMe,
    required this.monthlyPoints,
  });

  @override
  Widget build(BuildContext context) {
    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFF59E0B);
    } else if (rank == 2) {
      rankColor = const Color(0xFF94A3B8);
    } else if (rank == 3) {
      rankColor = const Color(0xFFD97706);
    } else {
      rankColor = AppColors.textSecondaryLight;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary.withAlpha(15) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? AppColors.primary.withAlpha(100) : AppColors.borderLight,
          width: isMe ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank number
          Container(
            width: 28,
            alignment: Alignment.center,
            child: Text(
              '#$rank',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: rankColor,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: isMe ? AppColors.primary : Colors.grey.shade200,
            child: Text(
              student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : 'S',
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.textPrimaryLight,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name and NIS
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        student.fullName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                          color: isMe ? AppColors.primary : AppColors.textPrimaryLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Kamu',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'NIS: ${student.nis ?? "-"} • Total Poin: ${student.totalPoints}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),

          // Monthly Points Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withAlpha(20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF59E0B).withAlpha(50)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded, size: 14, color: Color(0xFFD97706)),
                const SizedBox(width: 4),
                Text(
                  '$monthlyPoints',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
