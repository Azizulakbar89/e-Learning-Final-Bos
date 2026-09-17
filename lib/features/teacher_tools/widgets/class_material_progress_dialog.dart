import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firebase_service.dart';

class ClassMaterialProgressDialog extends StatefulWidget {
  final String classId;
  final String subjectId;
  final String? subjectName;

  const ClassMaterialProgressDialog({
    super.key,
    required this.classId,
    required this.subjectId,
    this.subjectName,
  });

  static Future<void> show(
    BuildContext context, {
    required String classId,
    required String subjectId,
    String? subjectName,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ClassMaterialProgressDialog(
        classId: classId,
        subjectId: subjectId,
        subjectName: subjectName,
      ),
    );
  }

  @override
  State<ClassMaterialProgressDialog> createState() => _ClassMaterialProgressDialogState();
}

class _ClassMaterialProgressDialogState extends State<ClassMaterialProgressDialog> {
  int _currentPage = 1;
  static const int _pageSize = 6;

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final summary = fb.getClassMaterialProgressSummary(widget.classId, widget.subjectId);
    final double avgProgress = summary['averageProgress'] as double;
    final int totalStudents = summary['totalStudents'] as int;
    final int totalMaterials = summary['totalMaterials'] as int;
    final List<Map<String, dynamic>> allProgress =
        List<Map<String, dynamic>>.from(summary['studentProgress'] ?? []);

    final int totalPages = (allProgress.isEmpty) ? 1 : ((allProgress.length + _pageSize - 1) ~/ _pageSize);
    if (_currentPage > totalPages) _currentPage = totalPages;
    if (_currentPage < 1) _currentPage = 1;

    final int startIndex = (_currentPage - 1) * _pageSize;
    final int endIndex = (startIndex + _pageSize > allProgress.length)
        ? allProgress.length
        : startIndex + _pageSize;

    final List<Map<String, dynamic>> pageProgress =
        allProgress.isEmpty ? [] : allProgress.sublist(startIndex, endIndex);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 660),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: AppColors.emerald, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progress Materi: Kelas ${widget.classId}',
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

            // Average Progress Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.emerald.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.emerald.withAlpha(40)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.trending_up_rounded, color: AppColors.emerald, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Rata-rata Progress Kelas:',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                          ),
                        ],
                      ),
                      Text(
                        '${avgProgress.toStringAsFixed(1)}%',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.emerald,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (avgProgress / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.white,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emerald),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Student List
            Expanded(
              child: pageProgress.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada siswa atau materi untuk kelas ${widget.classId}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      itemCount: pageProgress.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = pageProgress[index];
                        final UserModel student = item['student'] as UserModel;
                        final double progress = item['progressPercent'] as double;
                        final int completedCount = item['completedMaterialsCount'] as int;

                        final isComplete = progress >= 100.0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 17,
                                    backgroundColor: (isComplete ? AppColors.emerald : AppColors.primary).withAlpha(20),
                                    child: Text(
                                      student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isComplete ? AppColors.emerald : AppColors.primary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          student.fullName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'NIS: ${student.nis ?? "-"} • $completedCount/$totalMaterials Selesai',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (isComplete ? AppColors.emerald : AppColors.primary).withAlpha(15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${progress.toInt()}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isComplete ? AppColors.emerald : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (progress / 100).clamp(0.0, 1.0),
                                  minHeight: 5,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isComplete ? AppColors.emerald : AppColors.primary,
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
