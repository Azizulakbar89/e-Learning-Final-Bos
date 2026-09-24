import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/assignment_model.dart';
import '../../../core/models/curriculum_model.dart';
import '../../../core/models/material_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/embedded_media_viewer.dart';
import '../../ai_tutor/widgets/ai_tutor_sheet.dart';
import '../../ai_tutor/widgets/baby_language_dialog.dart';
import '../../assignments/screens/assignment_detail_screen.dart';
import '../../assignments/screens/assignment_form_screen.dart';
import 'class_forum_view.dart';
import 'material_form_screen.dart';

class MaterialDetailScreen extends StatefulWidget {
  final MaterialModel material;

  const MaterialDetailScreen({super.key, required this.material});

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final ScrollController _scrollController = ScrollController();
  Timer? _autoProgressTimer;
  double _progressPercent = 0.0;
  bool _initializedProgress = false;
  String? _selectedForumClass;

  List<AssignmentModel> _getApplicableAssignments(FirebaseService fbService, [String? materialId]) {
    final mId = (materialId ?? widget.material.id).trim();
    if (mId.isEmpty) return [];
    final assignments = fbService.getAssignmentsForMaterial(mId);
    final user = fbService.currentUser;
    final userClass = (user?.className ?? user?.classId ?? '').trim().toLowerCase();
    if (user == null || user.isGuru || user.role == 'guru' || user.isAdmin) {
      return assignments;
    }
    return assignments.where((a) {
      if (a.classIds.isEmpty) return true;
      if (userClass.isEmpty) return true;
      return a.classIds.any((c) => c.trim().toLowerCase() == userClass);
    }).toList();
  }

  bool _areAssignmentsCompleted(FirebaseService fbService, List<AssignmentModel> assignments) {
    if (assignments.isEmpty) return true;
    final user = fbService.currentUser;
    if (user == null) return false;
    for (final a in assignments) {
      final subs = fbService.getSubmissionsForAssignment(a.id);
      final submitted = subs.any((s) => s.submitterId == user.id || s.memberStudentIds.contains(user.id));
      if (!submitted) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_handleScrollProgress);
  }

  void _handleScrollProgress() {
    if (!_scrollController.hasClients) return;
    final fb = context.read<FirebaseService>();
    final applicable = _getApplicableAssignments(fb);
    final hasAsg = applicable.isNotEmpty;
    final asgDone = _areAssignmentsCompleted(fb, applicable);
    final isStudent = fb.currentUser?.isSiswa ?? false;
    final maxLimit = (isStudent && hasAsg && !asgDone) ? 50.0 : 100.0;

    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (max > 0) {
      final ratio = (current / max).clamp(0.0, 1.0);
      if (maxLimit <= 50.0) {
        if (ratio >= 0.85 && _progressPercent < 50.0) {
          _recordProgress(50.0);
        } else if (ratio >= 0.45 && _progressPercent < 35.0) {
          _recordProgress(35.0);
        }
      } else {
        if (ratio >= 0.85 && _progressPercent < 80.0) {
          _recordProgress(80.0);
        } else if (ratio >= 0.45 && _progressPercent < 50.0) {
          _recordProgress(50.0);
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedProgress) {
      _initializedProgress = true;
      final fb = context.read<FirebaseService>();
      final sid = fb.currentUser?.id ?? '';
      final saved = fb.getMaterialProgress(sid, widget.material.id);
      if (saved > 0) {
        _progressPercent = saved;
      }
      // Nyalakan / segarkan Streak Belajar Mandiri siswa saat belajar materi (post-frame)
      if (sid.isNotEmpty && (fb.currentUser?.isSiswa ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<FirebaseService>().triggerStudyActivityStreak(
              studentId: sid,
              activityType: 'materi',
              detail: widget.material.title,
            );
            if (_progressPercent < 100.0) {
              _startAutoProgressTimer(fb, sid);
            }
          }
        });
      }
    }
  }

  void _startAutoProgressTimer(FirebaseService fb, String sid) {
    final isStudent = fb.currentUser?.isSiswa ?? false;
    if (!isStudent || sid.isEmpty) return;

    final applicable = _getApplicableAssignments(fb);
    final hasAsg = applicable.isNotEmpty;
    final asgDone = _areAssignmentsCompleted(fb, applicable);
    final maxLimit = (!hasAsg || asgDone) ? 100.0 : 50.0;

    if (_progressPercent >= maxLimit || _progressPercent >= 100.0) return;

    // Berikan progres awal membaca jika masih 0%
    if (_progressPercent < 15.0) {
      _recordProgress(15.0);
    }

    _autoProgressTimer?.cancel();
    // Secara berkala (tiap 5 detik) saat siswa menyimak materi di Tab 1, progres bertambah otomatis
    _autoProgressTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final currentFb = context.read<FirebaseService>();
      final currentApp = _getApplicableAssignments(currentFb);
      final currentHasAsg = currentApp.isNotEmpty;
      final currentAsgDone = _areAssignmentsCompleted(currentFb, currentApp);
      final currentMax = (!currentHasAsg || currentAsgDone) ? 100.0 : 50.0;

      if (_tabController.index == 0) {
        if (_progressPercent < currentMax) {
          final next = (_progressPercent + 10.0).clamp(0.0, currentMax);
          _recordProgress(next);
        } else if (currentMax >= 100.0) {
          timer.cancel();
        }
      }
    });
  }

  @override
  void dispose() {
    _autoProgressTimer?.cancel();
    _scrollController.removeListener(_handleScrollProgress);
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _recordProgress(double newPercent) {
    final fb = context.read<FirebaseService>();
    final applicable = _getApplicableAssignments(fb);
    final hasAsg = applicable.isNotEmpty;
    final asgDone = _areAssignmentsCompleted(fb, applicable);
    final isStudent = fb.currentUser?.isSiswa ?? false;
    final maxLimit = (isStudent && hasAsg && !asgDone) ? 50.0 : 100.0;

    final clamped = newPercent.clamp(0.0, maxLimit).toDouble();
    if (clamped <= _progressPercent && clamped < maxLimit) return;
    if (!mounted) return;
    final wasUnder100 = _progressPercent < 100.0;
    setState(() {
      _progressPercent = clamped;
    });
    final sid = fb.currentUser?.id ?? '';
    final wasAlreadyAwarded = sid.isNotEmpty && fb.hasStudentReceivedMaterialPoints(sid, widget.material.id);
    if (sid.isNotEmpty) {
      fb.updateMaterialProgress(sid, widget.material.id, clamped);
    }
    if (wasUnder100 && clamped >= 100.0 && mounted) {
      if (!wasAlreadyAwarded) {
        AppSnackBar.success(
          context,
          'Hebat! Progres belajar tersimpan 100% otomatis di Firebase (+20 Poin)!',
        );
      } else {
        AppSnackBar.info(
          context,
          'Progres belajar tersimpan 100% (Poin materi ini sudah pernah diraih).',
        );
      }
    }
  }

  void _openAiTutor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiTutorSheet(
        materialTitle: widget.material.title,
        materialContent: widget.material.aiContextSummary ?? widget.material.description,
        mediaType: widget.material.contentType,
      ),
    );
  }

  void _openBabyLanguage() {
    showDialog(
      context: context,
      builder: (_) => BabyLanguageDialog(
        materialTitle: widget.material.title,
        materialContent: widget.material.aiContextSummary ?? widget.material.description,
        mediaType: widget.material.contentType,
        cachedExplanation: widget.material.babyLanguageExplanation,
      ),
    );
  }

  void _confirmDeleteMaterial(BuildContext context, FirebaseService fb) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Hapus Materi?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Materi "${widget.material.title}" beserta tugas dan forum terkait akan dihapus secara permanen.',
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
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // leave screen
              await fb.deleteMaterial(widget.material.id);
              if (context.mounted) {
                AppSnackBar.success(
                  context,
                  'Materi berhasil dihapus.',
                );
              }
            },
            child: Text('Hapus', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAssignment(BuildContext context, FirebaseService fb, AssignmentModel asg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Tugas?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Tugas "${asg.title}" beserta seluruh pengumpulan siswa terkait akan dihapus secara permanen.',
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.outfit()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await fb.deleteAssignment(asg.id);
              if (context.mounted) {
                AppSnackBar.success(context, 'Tugas berhasil dihapus.');
              }
            },
            child: Text('Hapus', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fbService = context.watch<FirebaseService>();
    final currentUser = fbService.currentUser;
    final isTeacher = currentUser?.isGuru == true || currentUser?.role == 'guru';
    final currentMaterial = fbService.materials.firstWhere(
      (m) => m.id == widget.material.id,
      orElse: () => widget.material,
    );
    final userClass = currentUser?.classId ?? 'X-RPL-1';
    final availableClasses = fbService.getAvailableClasses();
    final teacherClasses = isTeacher
        ? fbService.getTeacherClasses(currentUser)
        : availableClasses;
    final teacherClassesLower = teacherClasses.map((c) => c.toLowerCase()).toSet();

    final isAuthorized = !isTeacher ||
        currentMaterial.teacherId == currentUser?.id ||
        (fbService.getTeacherSubjects(currentUser).any((s) => s.id == currentMaterial.subjectId) &&
            (currentMaterial.classIds.isEmpty ||
                currentMaterial.classIds.any((cid) => teacherClassesLower.contains(cid.toLowerCase()))));

    if (!isAuthorized) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded, size: 56, color: Color(0xFFDC2626)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Akses Materi Dibatasi',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Anda tidak ditugaskan mengajar mata pelajaran atau kelas pada materi ini oleh Admin Sekolah.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Kembali'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final assignments = fbService.getAssignmentsForMaterial(currentMaterial.id);
    final applicableAssignments = _getApplicableAssignments(fbService, currentMaterial.id);
    final hasAssignments = applicableAssignments.isNotEmpty;
    final assignmentsDone = _areAssignmentsCompleted(fbService, applicableAssignments);
    final maxAllowedProgress = (!hasAssignments || assignmentsDone) ? 100.0 : 50.0;

    final hasAssignmentTab = isTeacher ? assignments.isNotEmpty : applicableAssignments.isNotEmpty;
    final neededTabCount = hasAssignmentTab ? 3 : 2;
    if (_tabController.length != neededTabCount) {
      final oldIndex = _tabController.index.clamp(0, neededTabCount - 1);
      _tabController.dispose();
      _tabController = TabController(length: neededTabCount, vsync: this, initialIndex: oldIndex);
    }

    final savedProgress = fbService.getMaterialProgress(currentUser?.id ?? '', currentMaterial.id);
    if (savedProgress > _progressPercent) {
      _progressPercent = savedProgress;
    }

    // Aturan: Jika ada tugas & belum selesai, maksimal 50%. Jika tugas sudah selesai, buka hingga 100%.
    if (!isTeacher && hasAssignments && !assignmentsDone && _progressPercent > 50.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _recordProgress(50.0);
        }
      });
    } else if (!isTeacher && hasAssignments && assignmentsDone && _progressPercent >= 50.0 && _progressPercent < 100.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _recordProgress(100.0);
        }
      });
    }

    final SubjectModel? subject = fbService.subjects.cast<SubjectModel?>().firstWhere(
      (s) => s?.id == currentMaterial.subjectId,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── Floating Curved Header (Matching Beranda Style) ───
            Container(
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF040D1F), // Deepest Navy
                    Color(0xFF071540), // Deep Navy
                    Color(0xFF0D2B6E), // Primary Navy
                    Color(0xFF1E3A8A), // Medium Navy
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D2B6E).withAlpha(80),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: const Color(0xFFF97316).withAlpha(35),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withAlpha(25),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.maybePop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withAlpha(40)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(30),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        currentMaterial.contentType == 'youtube'
                                            ? Icons.play_circle_fill_rounded
                                            : (currentMaterial.contentType == 'canva'
                                                ? Icons.slideshow_rounded
                                                : Icons.article_rounded),
                                        color: Colors.amberAccent,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        currentMaterial.contentType.toUpperCase(),
                                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    subject?.name ?? 'Modul Belajar',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              currentMaterial.title,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontSize: 17,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      if (currentUser?.isGuru == true || currentUser?.role == 'guru') ...[
                        const SizedBox(width: 4),
                        if (!hasAssignmentTab)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            tooltip: 'Buat Tugas untuk Materi Ini',
                            icon: const Icon(Icons.add_task_rounded, color: Colors.white, size: 18),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AssignmentFormScreen(
                                  materialId: currentMaterial.id,
                                  subjectId: currentMaterial.subjectId,
                                  initialClassIds: currentMaterial.classIds,
                                ),
                              ),
                            ),
                          ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          tooltip: 'Edit Materi',
                          icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MaterialFormScreen(
                                subjectId: currentMaterial.subjectId,
                                existingMaterial: currentMaterial,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          tooltip: 'Hapus Materi Ini',
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFCA5A5), size: 18),
                          onPressed: () => _confirmDeleteMaterial(context, fbService),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Compact horizontal TabBar (Dipercantik & Jelas Kontras)
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(50),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withAlpha(35),
                        width: 1.2,
                      ),
                    ),
                    padding: const EdgeInsets.all(3.5),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(40),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: const Color(0xFF0F172A),
                      unselectedLabelColor: Colors.white,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      tabs: [
                        Tab(
                          height: 34,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.menu_book_rounded, size: 15),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Materi',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Tab(
                          height: 34,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.forum_rounded, size: 15),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Forum Kelas',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasAssignmentTab)
                          Tab(
                            height: 34,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.assignment_rounded, size: 15),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    isTeacher
                                        ? (assignments.isNotEmpty
                                            ? 'Tugas (${assignments.length})'
                                            : 'Tugas')
                                        : 'Tugas (${applicableAssignments.length})',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
            ),
            // Body Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
          // TAB 1: Media Player & Content
          SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Media Viewer Box
                _buildMediaViewer(maxLimit: maxAllowedProgress),
                const SizedBox(height: 16),



                // AI Action Buttons Banner (Hanya untuk role siswa, disembunyikan untuk guru)
                if (currentUser?.isGuru != true && currentUser?.role != 'guru') ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(6),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 15),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Asisten Belajar Cerdas (AI)',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Gemini AI',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF7C3AED),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 2,
                                  shadowColor: const Color(0xFFF59E0B).withAlpha(80),
                                ),
                                onPressed: _openBabyLanguage,
                                icon: const Text('🧸', style: TextStyle(fontSize: 15)),
                                label: Text(
                                  'Bahasa Bayi',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C3AED),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 2,
                                  shadowColor: const Color(0xFF7C3AED).withAlpha(80),
                                ),
                                onPressed: _openAiTutor,
                                icon: const Icon(Icons.psychology_rounded, size: 17),
                                label: Text(
                                  'Tanya AI Tutor',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Description Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(6),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (subject != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D2B6E).withAlpha(15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF0D2B6E).withAlpha(35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.school_rounded, size: 12, color: Color(0xFF0D2B6E)),
                                  const SizedBox(width: 4),
                                  Text(
                                    subject.name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0D2B6E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: currentMaterial.contentType == 'youtube'
                                  ? const Color(0xFFFEE2E2)
                                  : (currentMaterial.contentType == 'canva'
                                      ? const Color(0xFFE0F2FE)
                                      : const Color(0xFFFEF3C7)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  currentMaterial.contentType == 'youtube'
                                      ? Icons.play_circle_fill_rounded
                                      : (currentMaterial.contentType == 'canva'
                                          ? Icons.slideshow_rounded
                                          : Icons.article_rounded),
                                  size: 12,
                                  color: currentMaterial.contentType == 'youtube'
                                      ? const Color(0xFFDC2626)
                                      : (currentMaterial.contentType == 'canva'
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFFD97706)),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  currentMaterial.contentType.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: currentMaterial.contentType == 'youtube'
                                        ? const Color(0xFFDC2626)
                                        : (currentMaterial.contentType == 'canva'
                                            ? const Color(0xFF0284C7)
                                            : const Color(0xFFD97706)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  '~10 Menit Baca',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currentMaterial.title,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          currentMaterial.description.isNotEmpty
                              ? currentMaterial.description
                              : 'Tidak ada deskripsi tambahan untuk materi ini.',
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.6,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // AI Context Summary Card
                if (currentMaterial.aiContextSummary != null &&
                    currentMaterial.aiContextSummary!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.lightbulb_rounded, color: Color(0xFF2563EB), size: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Intisari Pembelajaran (AI Grounding)',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentMaterial.aiContextSummary!,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.55,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // TAB 2: Class-Isolated Forum
          Builder(
            builder: (context) {
              final activeForumClass = isTeacher
                  ? (_selectedForumClass ?? (teacherClasses.isNotEmpty ? teacherClasses.first : userClass))
                  : userClass;

              return Column(
                children: [
                  if (isTeacher)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.forum_outlined, size: 16, color: AppColors.primary),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Pilih Kelas Diskusi Forum:',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.primary.withAlpha(40)),
                                ),
                                child: Text(
                                  'Aktif: $activeForumClass',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: teacherClasses.map((cls) {
                                final isSelected = cls == activeForumClass;
                                final msgCount = fbService.getForumMessages(
                                  materialId: widget.material.id,
                                  classId: cls,
                                ).length;

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          cls,
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isSelected ? Colors.white : const Color(0xFF334155),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isSelected ? Colors.white.withAlpha(50) : AppColors.primary.withAlpha(20),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '$msgCount',
                                            style: GoogleFonts.outfit(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? Colors.white : AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    selected: isSelected,
                                    selectedColor: AppColors.primary,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    showCheckmark: false,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: isSelected ? AppColors.primary : Colors.transparent,
                                      ),
                                    ),
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _selectedForumClass = cls;
                                        });
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ClassForumView(
                      key: ValueKey('forum_${widget.material.id}_$activeForumClass'),
                      materialId: widget.material.id,
                      classId: activeForumClass,
                    ),
                  ),
                ],
              );
            },
          ),

          // TAB 3: Assignments List (Hanya ditampilkan jika materi mengandung tugas)
          if (hasAssignmentTab)
            Builder(
              builder: (context) {
              final displayedAssignments = isTeacher ? assignments : applicableAssignments;

              return Column(
                children: [
                  if (isTeacher)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.add_task_rounded, size: 18),
                          label: Text(
                            'Buat Tugas Baru untuk Materi Ini',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.2,
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AssignmentFormScreen(
                                  materialId: currentMaterial.id,
                                  subjectId: currentMaterial.subjectId,
                                  initialClassIds: currentMaterial.classIds,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  Expanded(
                    child: displayedAssignments.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Tidak ada tugas untuk materi ini.',
                                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: displayedAssignments.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final asg = displayedAssignments[index];

                              // Submission stats for this assignment
                              final allSubs = fbService.getSubmissionsForAssignment(asg.id);
                              final gradedCount = allSubs.where((s) => s.score != null).length;
                              final sub = fbService.submissions.where(
                                (s) => s.assignmentId == asg.id && (s.submitterId == currentUser?.id || s.memberStudentIds.contains(currentUser?.id)),
                              ).firstOrNull;

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: (sub != null && sub.score != null)
                                        ? const Color(0xFF10B981).withAlpha(60)
                                        : const Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x0A0F172A),
                                      blurRadius: 16,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AssignmentDetailScreen(assignment: asg),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Top Row: Type Pill + Action/Score (NO OVERFLOW)
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              // Type Tag Capsule with Icon
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                                                decoration: BoxDecoration(
                                                  color: asg.codeConfig != null
                                                      ? const Color(0xFFEFF6FF)
                                                      : const Color(0xFFFFF7ED),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: asg.codeConfig != null
                                                        ? const Color(0xFFBFDBFE)
                                                        : const Color(0xFFFED7AA),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      asg.codeConfig != null
                                                          ? Icons.code_rounded
                                                          : Icons.assignment_rounded,
                                                      color: asg.codeConfig != null
                                                          ? const Color(0xFF2563EB)
                                                          : AppColors.orange,
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      asg.codeConfig != null
                                                          ? 'Koding (Compiler IDE)'
                                                          : (asg.allowedSubmissionTypes.isNotEmpty
                                                              ? asg.allowedSubmissionTypes.first.label
                                                              : 'Tugas Mandiri'),
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: asg.codeConfig != null
                                                            ? const Color(0xFF1D4ED8)
                                                            : const Color(0xFFC2410C),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Spacer(),
                                              // Right status or Teacher Action
                                              if (isTeacher) ...[
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 19),
                                                  tooltip: 'Hapus Tugas',
                                                  visualDensity: VisualDensity.compact,
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                  onPressed: () => _confirmDeleteAssignment(context, fbService, asg),
                                                ),
                                              ] else ...[
                                                if (sub != null && sub.score != null) ...[
                                                  // Badge Nilai Emerald Premium
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      gradient: const LinearGradient(
                                                        colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                      ),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: const Color(0xFF10B981).withAlpha(30),
                                                          blurRadius: 8,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF059669)),
                                                        const SizedBox(width: 6),
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              'NILAI',
                                                              style: GoogleFonts.outfit(
                                                                fontSize: 8.5,
                                                                fontWeight: FontWeight.w800,
                                                                color: const Color(0xFF047857),
                                                                letterSpacing: 0.5,
                                                              ),
                                                            ),
                                                            Text(
                                                              '${sub.score!.toInt()}',
                                                              style: GoogleFonts.outfit(
                                                                fontSize: 15,
                                                                fontWeight: FontWeight.w900,
                                                                color: const Color(0xFF065F46),
                                                                height: 1.1,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ] else if (sub != null) ...[
                                                  // Terkumpul Menunggu Dinilai
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFFFBEB),
                                                      borderRadius: BorderRadius.circular(10),
                                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFFD97706)),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          'Terkumpul',
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w700,
                                                            color: const Color(0xFF92400E),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ] else ...[
                                                  // Belum dikerjakan CTA
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.orangePale,
                                                      borderRadius: BorderRadius.circular(10),
                                                      border: Border.all(color: AppColors.orangeLight.withAlpha(80)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          'Kerjakan',
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 11.5,
                                                            fontWeight: FontWeight.w700,
                                                            color: AppColors.orangeDark,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        const Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.orangeDark),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ],
                                          ),

                                          const SizedBox(height: 12),

                                          // Assignment Title
                                          Text(
                                            asg.title,
                                            style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0F172A),
                                              letterSpacing: -0.2,
                                              height: 1.3,
                                            ),
                                          ),

                                          if (asg.description.trim().isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              asg.description.trim(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                fontSize: 13,
                                                color: const Color(0xFF64748B),
                                                height: 1.4,
                                              ),
                                            ),
                                          ],

                                          const SizedBox(height: 14),

                                          // Bottom Metadata: Target Kelas & Grup & Submission Stats (Guru) & Arrow
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  children: [
                                                    if (asg.classIds.isNotEmpty)
                                                      ...asg.classIds.map((c) => Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFF1F5F9),
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: Border.all(color: const Color(0xFFCBD5E1)),
                                                            ),
                                                            child: Text(
                                                              c,
                                                              style: GoogleFonts.outfit(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w700,
                                                                color: const Color(0xFF334155),
                                                              ),
                                                            ),
                                                          )),
                                                    if (asg.isGroup)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFEFF6FF),
                                                          borderRadius: BorderRadius.circular(7),
                                                          border: Border.all(color: const Color(0xFFBFDBFE)),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.groups_rounded, size: 13, color: Color(0xFF2563EB)),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              'Kelompok (${asg.maxGroupMembers} Siswa)',
                                                              style: GoogleFonts.outfit(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w600,
                                                                color: const Color(0xFF1D4ED8),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    if (isTeacher)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFEFF6FF),
                                                          borderRadius: BorderRadius.circular(7),
                                                          border: Border.all(color: const Color(0xFFBFDBFE)),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.people_alt_rounded, size: 12.5, color: Color(0xFF2563EB)),
                                                            const SizedBox(width: 4.5),
                                                            Text(
                                                              '${allSubs.length} Kumpul',
                                                              style: GoogleFonts.outfit(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w700,
                                                                color: const Color(0xFF1D4ED8),
                                                              ),
                                                            ),
                                                            if (gradedCount > 0) ...[
                                                              const SizedBox(width: 5),
                                                              Container(
                                                                width: 3.5,
                                                                height: 3.5,
                                                                decoration: const BoxDecoration(
                                                                  color: Color(0xFF10B981),
                                                                  shape: BoxShape.circle,
                                                                ),
                                                              ),
                                                              const SizedBox(width: 5),
                                                              Text(
                                                                '$gradedCount Dinilai',
                                                                style: GoogleFonts.outfit(
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.w700,
                                                                  color: const Color(0xFF059669),
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Icon(
                                                Icons.chevron_right_rounded,
                                                color: Color(0xFF94A3B8),
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  ],
),
),
);
  }

  Widget _buildMediaViewer({double maxLimit = 100.0}) {
    return EmbeddedMediaViewer(
      contentType: widget.material.contentType,
      mediaUrl: widget.material.mediaUrl,
      title: widget.material.title,
      onProgressTriggered: () {
        if (_progressPercent < maxLimit) {
          _recordProgress((_progressPercent + 25).clamp(0.0, maxLimit));
        }
      },
    );
  }
}
