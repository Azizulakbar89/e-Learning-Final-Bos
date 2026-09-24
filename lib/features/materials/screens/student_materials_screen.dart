import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/assignment_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/universal_app_header.dart';
import '../../materials/screens/material_detail_screen.dart';

class StudentMaterialsScreen extends StatefulWidget {
  const StudentMaterialsScreen({super.key});

  @override
  State<StudentMaterialsScreen> createState() =>
      _StudentMaterialsScreenState();
}

class _StudentMaterialsScreenState extends State<StudentMaterialsScreen> {
  String? _selectedSubjectId; // null or 'all' for all subjects
  String _filter = 'all'; // all | youtube | canva | slides

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final user = fb.currentUser;
    final allMaterials = user != null
        ? fb.getMaterialsForUser(user)
        : fb.materials;

    final subjects = fb.subjects;

    final filtered = allMaterials.where((m) {
      final matchSubject = _selectedSubjectId == null ||
          _selectedSubjectId == 'all' ||
          m.subjectId == _selectedSubjectId;
      final matchType = _filter == 'all' || m.contentType == _filter;
      return matchSubject && matchType;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
                  // Dropdown Pilihan Mata Pelajaran (Dipercantik)
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (_selectedSubjectId == null ||
                                _selectedSubjectId == 'all')
                            ? 'all'
                            : (subjects.any((s) => s.id == _selectedSubjectId)
                                ? _selectedSubjectId
                                : 'all'),
                        isExpanded: true,
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'all',
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.auto_stories_rounded,
                                    size: 15,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Semua Mata Pelajaran',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...subjects.map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.book_rounded,
                                      size: 15,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${s.name} (${s.code})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedSubjectId = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter Tipe Media Pembelajaran (YouTube, Canva, PPT)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('Semua Media', 'all'),
                        const SizedBox(width: 8),
                        _filterChip('📺 YouTube', 'youtube'),
                        const SizedBox(width: 8),
                        _filterChip('🎨 Canva', 'canva'),
                        const SizedBox(width: 8),
                        _filterChip('📊 PPT File', 'slides'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book_outlined,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada materi untuk filter ini',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Coba pilih mata pelajaran atau tipe media lainnya.',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, idx) => _MaterialCard(
                        mat: filtered[idx],
                        index: idx,
                        subjects: subjects,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white30,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : Colors.white,
            fontSize: 11.5,
            fontWeight:
                isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── Material Card ────────────────────────────────────────────────────────────
class _MaterialCard extends StatelessWidget {
  final dynamic mat;
  final int index;
  final List<dynamic> subjects;

  const _MaterialCard({
    required this.mat,
    required this.index,
    required this.subjects,
  });

  @override
  Widget build(BuildContext context) {
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
    final cfg = _typeConfig(mat.contentType);
    final subject = subjects.where((s) => s.id == mat.subjectId).firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MaterialDetailScreen(material: mat)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top tag row: Subject badge + Media type badge + Rating
              Row(
                children: [
                  // Subject badge
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

                  // Media type
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cfg.color.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cfg.color.withAlpha(40)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cfg.icon, size: 12, color: cfg.color),
                        const SizedBox(width: 4),
                        Text(
                          cfg.label,
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: cfg.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Rating badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
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
                  color: const Color(0xFF0F172A),
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
                    height: 1.4,
                  ),
                ),
              ],

              // Progress Belajar Siswa
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                color: const Color(0xFF475569),
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

              // Status Tugas / Nilai & Tombol Masuk (→)
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

  ({IconData icon, Color color, String label}) _typeConfig(String type) {
    switch (type) {
      case 'youtube':
        return (
          icon: Icons.play_circle_rounded,
          color: const Color(0xFFDC2626),
          label: 'YouTube Video',
        );
      case 'canva':
        return (
          icon: Icons.palette_rounded,
          color: const Color(0xFF0284C7),
          label: 'Canva Interactive',
        );
      default:
        return (
          icon: Icons.slideshow_rounded,
          color: const Color(0xFFD97706),
          label: 'PPT File',
        );
    }
  }
}
