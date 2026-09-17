import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/assignment_model.dart';
import '../../../core/models/material_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/excel_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/universal_app_header.dart';
import '../../assignments/widgets/student_submission_detail_dialog.dart';
import 'material_detail_screen.dart';
import 'material_form_screen.dart';

class TeacherMaterialsScreen extends StatefulWidget {
  final bool showBackButton;

  const TeacherMaterialsScreen({super.key, this.showBackButton = false});

  @override
  State<TeacherMaterialsScreen> createState() => _TeacherMaterialsScreenState();
}

class _TeacherMaterialsScreenState extends State<TeacherMaterialsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedSubjectFilter;
  String _selectedClassFilter = 'all';
  String _selectedAssignmentFilter = 'all'; // all, individu, kelompok, pilihan_ganda, none

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final currentUser = fb.currentUser;
    final subjects = fb.getTeacherSubjects(currentUser);
    final classes = fb.getTeacherClasses(currentUser);
    final allMaterials = fb.getTeacherMaterials(currentUser);

    // Filter materials
    final filtered = allMaterials.where((m) {
      if (_selectedSubjectFilter != null && m.subjectId != _selectedSubjectFilter) {
        return false;
      }
      if (_selectedClassFilter != 'all') {
        if (m.classIds.isNotEmpty && !m.classIds.contains(_selectedClassFilter)) {
          return false;
        }
      }
      if (_selectedAssignmentFilter != 'all') {
        if (_selectedAssignmentFilter == 'none' && m.assignmentType != null) {
          return false;
        } else if (_selectedAssignmentFilter != 'none' && m.assignmentType != _selectedAssignmentFilter) {
          return false;
        }
      }
      if (_searchQuery.isNotEmpty) {
        final titleMatch = m.title.toLowerCase().contains(_searchQuery);
        final descMatch = m.description.toLowerCase().contains(_searchQuery);
        if (!titleMatch && !descMatch) return false;
      }
      return true;
    }).toList();

    // Sort descending by creation
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Universal Header (Sticky at top)
            UniversalAppHeader(
              showBackButton: widget.showBackButton,
                bottomContent: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Materi Belajar Guru',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${filtered.length} Modul • Kelola & Nilai Tugas',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        if (subjects.isEmpty || classes.isEmpty) {
                          AppSnackBar.error(
                            context,
                            'Anda belum diplot untuk mata pelajaran atau kelas oleh Admin.',
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MaterialFormScreen(
                              subjectId: _selectedSubjectFilter,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: const Text('Tambah Materi'),
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
            // Scrollable Content
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Filter and Search Header
                  SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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

                    // Search input
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
                    const SizedBox(height: 14),

                    // Filter Chips (Subject & Type)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Subject Filter
                          Text(
                            'Mapel: ',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: Text('Semua Mapel', style: GoogleFonts.outfit(fontSize: 12)),
                            selected: _selectedSubjectFilter == null,
                            selectedColor: AppColors.primary.withAlpha(30),
                            checkmarkColor: AppColors.primary,
                            side: BorderSide(
                              color: _selectedSubjectFilter == null
                                  ? AppColors.primary
                                  : const Color(0xFFCBD5E1),
                            ),
                            onSelected: (_) => setState(() => _selectedSubjectFilter = null),
                          ),
                          const SizedBox(width: 6),
                          ...subjects.map((s) {
                            final sel = _selectedSubjectFilter == s.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text(s.name, style: GoogleFonts.outfit(fontSize: 12)),
                                selected: sel,
                                selectedColor: AppColors.primary.withAlpha(30),
                                checkmarkColor: AppColors.primary,
                                side: BorderSide(
                                  color: sel ? AppColors.primary : const Color(0xFFCBD5E1),
                                ),
                                onSelected: (_) => setState(() => _selectedSubjectFilter = sel ? null : s.id),
                              ),
                            );
                          }),
                          const SizedBox(width: 14),
                          Container(width: 1, height: 24, color: const Color(0xFFCBD5E1)),
                          const SizedBox(width: 14),

                          // Class Filter
                          Text(
                            'Kelas: ',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: Text('Semua Kelas', style: GoogleFonts.outfit(fontSize: 12)),
                            selected: _selectedClassFilter == 'all',
                            selectedColor: AppColors.primary.withAlpha(30),
                            checkmarkColor: AppColors.primary,
                            side: BorderSide(
                              color: _selectedClassFilter == 'all'
                                  ? AppColors.primary
                                  : const Color(0xFFCBD5E1),
                            ),
                            onSelected: (_) => setState(() => _selectedClassFilter = 'all'),
                          ),
                          const SizedBox(width: 6),
                          ...classes.map((cls) {
                            final sel = _selectedClassFilter == cls;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text(cls, style: GoogleFonts.outfit(fontSize: 12)),
                                selected: sel,
                                selectedColor: AppColors.primary.withAlpha(30),
                                checkmarkColor: AppColors.primary,
                                side: BorderSide(
                                  color: sel ? AppColors.primary : const Color(0xFFCBD5E1),
                                ),
                                onSelected: (_) => setState(() => _selectedClassFilter = sel ? 'all' : cls),
                              ),
                            );
                          }),
                          const SizedBox(width: 14),
                          Container(width: 1, height: 24, color: const Color(0xFFCBD5E1)),
                          const SizedBox(width: 14),

                          // Assignment Type Filter
                          Text(
                            'Tugas: ',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildTypeChip('all', 'Semua'),
                          _buildTypeChip('individu', 'Individu'),
                          _buildTypeChip('kelompok', 'Kelompok'),
                          _buildTypeChip('pilihan_ganda', 'Kuis PG'),
                          _buildTypeChip('none', 'Tanpa Tugas'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Material List / Empty state
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          size: 48,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tidak ada materi yang ditemukan',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Coba ubah filter pencarian atau buat materi baru.',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _searchCtrl.clear();
                            _selectedSubjectFilter = null;
                            _selectedAssignmentFilter = 'all';
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text('Reset Filter', style: GoogleFonts.outfit()),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    if (width >= 1100) {
                      return SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 310,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final material = filtered[index];
                            return _buildMaterialCard(context, fb, material);
                          },
                          childCount: filtered.length,
                        ),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final material = filtered[index];
                          return _buildMaterialCard(context, fb, material);
                        },
                        childCount: filtered.length,
                      ),
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        ),
      ),
    ],
  ),
),
);
  }

  Widget _buildTypeChip(String key, String label) {
    final sel = _selectedAssignmentFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: GoogleFonts.outfit(fontSize: 12)),
        selected: sel,
        selectedColor: AppColors.primary.withAlpha(30),
        checkmarkColor: AppColors.primary,
        side: BorderSide(
          color: sel ? AppColors.primary : const Color(0xFFCBD5E1),
        ),
        onSelected: (_) => setState(() => _selectedAssignmentFilter = key),
      ),
    );
  }

  Widget _buildMaterialCard(BuildContext context, FirebaseService fb, MaterialModel material) {
    final subject = fb.subjects.where((s) => s.id == material.subjectId).firstOrNull;
    final assignments = fb.getAssignmentsForMaterial(material.id);
    final assignment = assignments.isNotEmpty ? assignments.first : null;

    final mediaBadge = _getMediaBadge(material.contentType);
    final assignBadge = _getAssignmentBadge(material.assignmentType);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top badging row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Subject badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withAlpha(60)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.school_outlined, size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                subject != null ? '${subject.name} (${subject.code})' : 'Mata Pelajaran',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Media type badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: mediaBadge.color.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(mediaBadge.icon, size: 13, color: mediaBadge.color),
                            const SizedBox(width: 4),
                            Text(
                              mediaBadge.label,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: mediaBadge.color,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Assignment badge
                      if (assignBadge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: assignBadge.color.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(assignBadge.icon, size: 13, color: assignBadge.color),
                              const SizedBox(width: 4),
                              Text(
                                assignBadge.label,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: assignBadge.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit Materi',
                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF3B82F6), size: 20),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MaterialFormScreen(
                            subjectId: material.subjectId,
                            existingMaterial: material,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus Materi',
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                      onPressed: () => _confirmDeleteMaterial(context, fb, material),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title & Description
            Text(
              material.title,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            if (material.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                material.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Schedule info & Class chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (material.scheduledOpenAt != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFFD97706)),
                        const SizedBox(width: 5),
                        Text(
                          'Jadwal Buka: ${_formatDateTime(material.scheduledOpenAt!)}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Classes tags
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Kelas: ',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    ...material.classIds.map((cid) {
                      final className = fb.schoolClasses.where((c) => c.id == cid).firstOrNull?.name ?? cid;
                      return Container(
                        margin: const EdgeInsets.only(right: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          className,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            // Bottom Actions: Horizontal side-by-side with equal width
            Row(
              children: [
                // View Material details
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MaterialDetailScreen(material: material),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: Text(
                      'Buka Materi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E3A8A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),

                // Grade & Class Assessment button
                if (assignment != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openGradingModal(context, fb, material, assignment),
                      icon: const Icon(Icons.rate_review_rounded, size: 15),
                      label: Text(
                        'Nilai & Rekap',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openGradingModal(
    BuildContext context,
    FirebaseService fb,
    MaterialModel material,
    AssignmentModel assignment,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TeacherClassGradingSheet(
        material: material,
        assignment: assignment,
      ),
    );
  }

  void _confirmDeleteMaterial(BuildContext context, FirebaseService fb, MaterialModel material) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Hapus Materi?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Materi "${material.title}" beserta tugas terkait akan dihapus secara permanen.',
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
                action: () async {
                  await fb.deleteMaterial(material.id);
                },
                successMessage: 'Materi berhasil dihapus.',
                errorMessage: 'Gagal menghapus materi. Silakan coba lagi.',
              );
            },
            child: Text('Hapus', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  _BadgeInfo _getMediaBadge(String type) {
    switch (type) {
      case 'youtube':
        return _BadgeInfo('YouTube', Icons.play_circle_filled_rounded, Colors.red.shade600);
      case 'canva':
        return _BadgeInfo('Canva', Icons.design_services_rounded, Colors.blue.shade600);
      case 'ppt':
        return _BadgeInfo('PPT / Slide', Icons.slideshow_rounded, Colors.orange.shade700);
      default:
        return _BadgeInfo('Media', Icons.attach_file_rounded, Colors.teal);
    }
  }

  _BadgeInfo? _getAssignmentBadge(String? type) {
    if (type == null) return null;
    switch (type) {
      case 'individu':
        return _BadgeInfo('Tugas Individu', Icons.person_rounded, const Color(0xFF1E3A8A));
      case 'kelompok':
        return _BadgeInfo('Tugas Kelompok', Icons.groups_rounded, const Color(0xFF1E40AF));
      case 'pilihan_ganda':
        return _BadgeInfo('Kuis PG', Icons.quiz_rounded, const Color(0xFFEA580C));
      default:
        return _BadgeInfo(type, Icons.assignment_rounded, const Color(0xFF2563EB));
    }
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} $h:$min';
  }
}

class _BadgeInfo {
  final String label;
  final IconData icon;
  final Color color;
  const _BadgeInfo(this.label, this.icon, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
// MODAL PENILAIAN PER KELAS + DOWNLOAD EXCEL
// ─────────────────────────────────────────────────────────────────────────────

class _TeacherClassGradingSheet extends StatefulWidget {
  final MaterialModel material;
  final AssignmentModel assignment;

  const _TeacherClassGradingSheet({
    required this.material,
    required this.assignment,
  });

  @override
  State<_TeacherClassGradingSheet> createState() => _TeacherClassGradingSheetState();
}

class _TeacherClassGradingSheetState extends State<_TeacherClassGradingSheet> {
  late String _selectedClassId;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.material.classIds.isNotEmpty ? widget.material.classIds.first : '';
  }

  Future<void> _downloadExcel(FirebaseService fb) async {
    if (_selectedClassId.isEmpty) return;

    setState(() => _isDownloading = true);
    try {
      final rows = fb.getGradeRowsByClass(
        assignmentId: widget.assignment.id,
        classId: _selectedClassId,
      );

      final excelBytes = ExcelService.generateDetailedGradeExcel(
        sheetTitle: '${widget.material.title} - Kelas $_selectedClassId',
        rows: rows,
      );

      final safeTitle = widget.material.title
          .replaceAll(RegExp(r'[^\w\s\-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');

      final displayClassName = fb.schoolClasses.where((c) => c.id == _selectedClassId).firstOrNull?.name ?? _selectedClassId;
      final fileName = 'Nilai_${safeTitle}_Kelas_$displayClassName.xlsx';

      await ExcelService.downloadExcel(
        bytes: excelBytes,
        fileName: fileName,
      );

      if (mounted) {
        AppSnackBar.success(
          context,
          'Berhasil mengunduh nilai Kelas $displayClassName ke Excel!',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          'Gagal mengunduh file Excel: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _showGradeDialog(BuildContext context, FirebaseService fb, UserModel student, AssignmentSubmissionModel? submission) {
    final scoreCtrl = TextEditingController(text: submission?.score?.toStringAsFixed(0) ?? '');
    final feedbackCtrl = TextEditingController(text: submission?.teacherFeedback ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          submission?.groupName != null
              ? 'Beri Nilai Kelompok: ${submission!.groupName}'
              : 'Beri Nilai: ${student.fullName}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (submission?.groupName != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nilai ini akan otomatis disinkronkan ke seluruh anggota kelompok.',
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.purple.shade800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text('Nilai (0 - 100) *', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: scoreCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '85',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            Text('Feedback / Catatan Guru', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: feedbackCtrl,
              maxLines: 3,
              style: GoogleFonts.outfit(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Kerja bagus! Perhatikan kerapian struktur kode...',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.outfit()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emerald,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final scoreVal = double.tryParse(scoreCtrl.text.trim());
              if (scoreVal == null || scoreVal < 0 || scoreVal > 100) {
                AppSnackBar.error(
                  context,
                  'Nilai harus berupa angka 0 - 100',
                );
                return;
              }

              if (submission != null) {
                await fb.gradeAssignmentSubmission(
                  submissionId: submission.id,
                  score: scoreVal,
                  feedback: feedbackCtrl.text.trim(),
                );
              }

              if (context.mounted) {
                Navigator.pop(context);
                AppSnackBar.success(
                  context,
                  'Nilai berhasil disimpan!',
                );
              }
            },
            child: Text('Simpan Nilai', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _previewAnswer(BuildContext context, AssignmentSubmissionModel sub) {
    StudentSubmissionDetailDialog.show(
      context,
      submission: sub,
      assignment: widget.assignment,
      onGraded: () => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final allSubs = fb.getSubmissionsForAssignment(widget.assignment.id);

    final targetClass = _selectedClassId.trim().toLowerCase();
    final matchingClass = fb.schoolClasses.where((c) =>
        c.id.trim().toLowerCase() == targetClass ||
        c.name.trim().toLowerCase() == targetClass).firstOrNull;
    final validTokens = <String>{
      targetClass,
      if (matchingClass != null) ...[
        matchingClass.id.trim().toLowerCase(),
        matchingClass.name.trim().toLowerCase(),
      ],
    };

    final studentsInClass = fb.allStudents.where((s) {
      final sClass = (s.className ?? s.classId ?? '').trim().toLowerCase();
      return validTokens.contains(sClass);
    }).toList();

    // Summary counts
    final submittedCount = studentsInClass.where((st) {
      return allSubs.any((s) => s.submitterId == st.id || s.memberStudentIds.contains(st.id));
    }).length;

    final gradedCount = studentsInClass.where((st) {
      final sub = allSubs.where((s) => s.submitterId == st.id || s.memberStudentIds.contains(st.id)).firstOrNull;
      return sub != null && sub.score != null;
    }).length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title & Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Penilaian Tugas per Kelas',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.material.title} • ${widget.assignment.title}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Class Selection Tabs + Download Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.school_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Pilih Kelas:',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: _isDownloading ? null : () => _downloadExcel(fb),
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.file_download_rounded, size: 16),
                      label: Text(
                        'Unduh Excel (Kelas ${fb.schoolClasses.where((c) => c.id == _selectedClassId).firstOrNull?.name ?? _selectedClassId})',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.material.classIds.map((cid) {
                      final className = fb.schoolClasses.where((c) => c.id == cid).firstOrNull?.name ?? cid;
                      final sel = _selectedClassId == cid || _selectedClassId == className;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(Icons.meeting_room_rounded, size: 14, color: sel ? Colors.white : AppColors.primary),
                          label: Text(
                            'Kelas $className',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: sel ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                          selected: sel,
                          selectedColor: AppColors.primary,
                          backgroundColor: Colors.white,
                          side: BorderSide(color: sel ? AppColors.primary : const Color(0xFFCBD5E1)),
                          labelStyle: TextStyle(color: sel ? Colors.white : const Color(0xFF334155)),
                          onSelected: (val) {
                            if (val) setState(() => _selectedClassId = cid);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Class Summary Bar - evenly distributed cards
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                _summaryItem('Total Siswa', '${studentsInClass.length}', const Color(0xFF1E3A8A), const Color(0xFFEFF6FF)),
                const SizedBox(width: 8),
                _summaryItem('Terkumpul', '$submittedCount', AppColors.primary, AppColors.primary.withAlpha(20)),
                const SizedBox(width: 8),
                _summaryItem('Dinilai', '$gradedCount', const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
                const SizedBox(width: 8),
                _summaryItem('Belum Kumpul', '${studentsInClass.length - submittedCount}', const Color(0xFFEA580C), const Color(0xFFFFEDD5)),
              ],
            ),
          ),

          // Student List for selected class
          Expanded(
            child: studentsInClass.isEmpty
                ? Center(
                    child: Text(
                      'Belum ada data siswa terdaftar di Kelas $_selectedClassId',
                      style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: studentsInClass.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final student = studentsInClass[index];

                      // Find submission
                      final sub = allSubs.where((s) {
                        return s.submitterId == student.id || s.memberStudentIds.contains(student.id);
                      }).firstOrNull;

                      final hasSubmitted = sub != null;
                      final isGraded = sub?.score != null;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isGraded
                                ? const Color(0xFF2563EB).withAlpha(80)
                                : (hasSubmitted ? Colors.orange.shade200 : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: hasSubmitted
                                  ? (isGraded ? const Color(0xFFEFF6FF) : Colors.orange.shade50)
                                  : const Color(0xFFF1F5F9),
                              child: Text(
                                student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : '?',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: hasSubmitted
                                      ? (isGraded ? const Color(0xFF1E40AF) : Colors.orange.shade800)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Name, NIS, Group info (strictly constrained against overflow)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${student.fullName}${student.nis != null && student.nis!.isNotEmpty ? " (${student.nis})" : ""}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (sub?.groupName != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Kelompok: ${sub!.groupName} (oleh ${sub.submitterName})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF1E40AF),
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    Text(
                                      hasSubmitted ? 'Tugas Mandiri / Individu' : 'Belum mengumpulkan',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: hasSubmitted ? const Color(0xFF64748B) : Colors.orange.shade800,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Status Chip
                            if (!hasSubmitted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Belum Kumpul',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              )
                            else if (!isGraded)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: Text(
                                  'Perlu Dinilai',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.emerald.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.emerald.withAlpha(80)),
                                ),
                                child: Text(
                                  'Nilai: ${sub.score!.toStringAsFixed(0)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.emerald,
                                  ),
                                ),
                              ),

                            const SizedBox(width: 12),

                            // Actions: Preview & Grade
                            if (hasSubmitted) ...[
                              FilledButton.tonalIcon(
                                onPressed: () => _previewAnswer(context, sub),
                                icon: const Icon(Icons.remove_red_eye_rounded, size: 16),
                                label: const Text('Lihat Jawaban'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              FilledButton(
                                onPressed: () => _showGradeDialog(context, fb, student, sub),
                                style: FilledButton.styleFrom(
                                  backgroundColor: isGraded ? const Color(0xFF475569) : AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(
                                  isGraded ? 'Ubah Nilai' : 'Beri Nilai',
                                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
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

  Widget _summaryItem(String label, String value, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
