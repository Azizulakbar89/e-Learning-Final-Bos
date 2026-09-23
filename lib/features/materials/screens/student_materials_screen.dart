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
    }).toList();

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
                  // Row Info Materi
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.menu_book_rounded,
                            color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Materi Belajar',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${filtered.length} Modul Tersedia',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${allMaterials.length} Total',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Dropdown Pilihan Mata Pelajaran
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (_selectedSubjectId == null || _selectedSubjectId == 'all')
                            ? 'all'
                            : (subjects.any((s) => s.id == _selectedSubjectId)
                                ? _selectedSubjectId
                                : 'all'),
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.primary, size: 20),
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Row(
                              children: [
                                Icon(Icons.auto_stories_rounded,
                                    size: 16, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Semua Mata Pelajaran'),
                              ],
                            ),
                          ),
                          ...subjects.map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Row(
                                children: [
                                  const Icon(Icons.bookmark_outline_rounded,
                                      size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${s.name} (${s.code})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
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
    final studentClass = (user?.className ?? user?.classId ?? '').trim().toLowerCase();
    final applicableAssignments = assignments.where((a) {
      if (a.classIds.isEmpty) return true;
      if (studentClass.isEmpty) return true;
      return a.classIds.any((c) => c.trim().toLowerCase() == studentClass);
    }).toList();

    AssignmentSubmissionModel? mySub;
    for (final a in applicableAssignments) {
      final subs = fb.getSubmissionsForAssignment(a.id);
      final found = subs.where((s) => s.submitterId == user?.id || s.memberStudentIds.contains(user?.id)).firstOrNull;
      if (found != null) {
        mySub = found;
        break;
      }
    }

    final cfg = _typeConfig(mat.contentType);
    final subject = subjects.where((s) => s.id == mat.subjectId).firstOrNull;

    final pastelColors = [
      const Color(0xFFF5F3FF), // Soft Lilac
      const Color(0xFFF0FDF4), // Soft Mint
      const Color(0xFFF0F9FF), // Soft Sky
      const Color(0xFFFFFBEB), // Soft Amber
    ];

    final pastelBorders = [
      const Color(0xFFDDD6FE),
      const Color(0xFFBBF7D0),
      const Color(0xFFBAE6FD),
      const Color(0xFFFDE68A),
    ];

    final cardBg = pastelColors[index % pastelColors.length];
    final cardBorder = pastelBorders[index % pastelBorders.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MaterialDetailScreen(material: mat)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top tag row: Subject badge + Media type badge
              Row(
                children: [
                  // Subject badge if available (flexible to prevent overflow)
                  if (subject != null) ...[
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withAlpha(50)),
                        ),
                        child: Text(
                          subject.name,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cfg.icon, size: 12, color: cfg.color),
                        const SizedBox(width: 4),
                        Text(
                          cfg.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: cfg.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
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
                  fontSize: 15,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
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
              if (mySub != null && mySub.score != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded, size: 15, color: Color(0xFF047857)),
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
                ),
              ] else if (mySub != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hourglass_top_rounded, size: 14, color: Color(0xFFB45309)),
                      const SizedBox(width: 4),
                      Text(
                        'Tugas Terkumpul (Menunggu Koreksi)',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (applicableAssignments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primaryLight.withAlpha(50)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.assignment_outlined, size: 14, color: AppColors.primaryDark),
                      const SizedBox(width: 4),
                      Text(
                        'Ada ${applicableAssignments.first.assignmentType == "pilihan_ganda" ? "Kuis Pilihan Ganda" : "Tugas"}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Bottom row: Classmates avatars + Circular arrow button (→)
              Row(
                children: [
                  SizedBox(
                    width: 54,
                    height: 22,
                    child: Stack(
                      children: [
                        _miniAvatar('A', const Color(0xFF3B82F6), 0),
                        _miniAvatar('B', const Color(0xFF10B981), 14),
                        _miniAvatar('C', const Color(0xFFF59E0B), 28),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '+16 Siswa Belajar',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Circular arrow button
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
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

  static Widget _miniAvatar(String initial, Color color, double left) {
    return Positioned(
      left: left,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Center(
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
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
