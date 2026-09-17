import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firebase_service.dart';

class ClassStudentScoresDialog extends StatefulWidget {
  final String classId;
  final String? subjectId;
  final String? subjectName;

  const ClassStudentScoresDialog({
    super.key,
    required this.classId,
    this.subjectId,
    this.subjectName,
  });

  static Future<void> show(
    BuildContext context, {
    required String classId,
    String? subjectId,
    String? subjectName,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ClassStudentScoresDialog(
        classId: classId,
        subjectId: subjectId,
        subjectName: subjectName,
      ),
    );
  }

  @override
  State<ClassStudentScoresDialog> createState() => _ClassStudentScoresDialogState();
}

class _ClassStudentScoresDialogState extends State<ClassStudentScoresDialog> {
  int _currentPage = 1;
  static const int _pageSize = 6;

  Color _getScoreColor(double score) {
    if (score >= 80) return AppColors.emerald;
    if (score >= 70) return const Color(0xFF3B82F6);
    if (score >= 60) return const Color(0xFFF59E0B);
    return AppColors.rose;
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final summary = fb.getClassScoreSummary(widget.classId, subjectId: widget.subjectId);
    final double avgScore = summary['averageScore'] as double;
    final int totalStudents = summary['totalStudents'] as int;
    final List<Map<String, dynamic>> allScores =
        List<Map<String, dynamic>>.from(summary['studentScores'] ?? []);

    final int totalPages = (allScores.isEmpty) ? 1 : ((allScores.length + _pageSize - 1) ~/ _pageSize);
    if (_currentPage > totalPages) _currentPage = totalPages;
    if (_currentPage < 1) _currentPage = 1;

    final int startIndex = (_currentPage - 1) * _pageSize;
    final int endIndex = (startIndex + _pageSize > allScores.length)
        ? allScores.length
        : startIndex + _pageSize;

    final List<Map<String, dynamic>> pageScores =
        allScores.isEmpty ? [] : allScores.sublist(startIndex, endIndex);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 650),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rekap Nilai: Kelas ${widget.classId}',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      if (widget.subjectName != null && widget.subjectName!.isNotEmpty)
                        Text(
                          widget.subjectName!,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Average Score Card Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _getScoreColor(avgScore).withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getScoreColor(avgScore).withAlpha(40)),
              ),
              child: Row(
                children: [
                  Icon(Icons.analytics_rounded, color: _getScoreColor(avgScore), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Rata-rata Kelas:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                  ),
                  const Spacer(),
                  Text(
                    avgScore.toStringAsFixed(1),
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _getScoreColor(avgScore),
                    ),
                  ),
                  Text(
                    ' / 100',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Student List
            Expanded(
              child: pageScores.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada siswa terdaftar di kelas ${widget.classId}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      itemCount: pageScores.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = pageScores[index];
                        final UserModel student = item['student'] as UserModel;
                        final double score = (item['averageScore'] as num?)?.toDouble() ?? 0.0;
                        final bool hasScore = (item['hasScore'] as bool?) ?? (score > 0);
                        final int completedCount = (item['completedCount'] as int?) ?? 0;
                        final int completedAssignments = (item['completedAssignmentsCount'] as int?) ?? 0;

                        final subParts = <String>[
                          'NIS: ${student.nis ?? "-"}',
                          if (completedCount > 0) '$completedCount Ujian',
                          if (completedAssignments > 0) '$completedAssignments Tugas',
                          if (completedCount == 0 && completedAssignments == 0) 'Belum ada evaluasi',
                        ];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primary.withAlpha(25),
                                child: Text(
                                  student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 13,
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
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      subParts.join(' • '),
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: hasScore ? _getScoreColor(score).withAlpha(20) : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: hasScore ? _getScoreColor(score).withAlpha(50) : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  hasScore ? score.toStringAsFixed(1) : '-',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: hasScore ? _getScoreColor(score) : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const Divider(height: 16),

            // Pagination Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hal. $_currentPage / $totalPages ($totalStudents Siswa)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      tooltip: 'Halaman Sebelumnya',
                      onPressed: _currentPage > 1
                          ? () => setState(() => _currentPage--)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$_currentPage',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      tooltip: 'Halaman Selanjutnya',
                      onPressed: _currentPage < totalPages
                          ? () => setState(() => _currentPage++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
