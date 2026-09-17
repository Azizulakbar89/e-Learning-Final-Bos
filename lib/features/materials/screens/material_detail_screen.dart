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
  String _selectedAssignmentClass = 'all';

  List<AssignmentModel> _getApplicableAssignments(FirebaseService fbService) {
    final assignments = fbService.getAssignmentsForMaterial(widget.material.id);
    final user = fbService.currentUser;
    final userClass = user?.className ?? user?.classId ?? '';
    if (user == null || user.isGuru || user.role == 'guru') {
      return assignments;
    }
    return assignments.where((a) {
      if (a.classIds.isEmpty) return true;
      if (userClass.isEmpty) return true;
      return a.classIds.any((c) => c.toLowerCase() == userClass.toLowerCase());
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
            _startAutoProgressTimer(fb, sid);
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

    if (_progressPercent >= maxLimit) return;

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
    if (sid.isNotEmpty) {
      fb.updateMaterialProgress(sid, widget.material.id, clamped);
    }
    if (wasUnder100 && clamped >= 100.0 && mounted) {
      AppSnackBar.success(
        context,
        'Hebat! Progres belajar tersimpan 100% otomatis di Firebase (+20 Poin)!',
      );
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
    final applicableAssignments = _getApplicableAssignments(fbService);
    final hasAssignments = applicableAssignments.isNotEmpty;
    final assignmentsDone = _areAssignmentsCompleted(fbService, applicableAssignments);
    final maxAllowedProgress = (!hasAssignments || assignmentsDone) ? 100.0 : 50.0;

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
                  // Compact horizontal TabBar
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withAlpha(20)),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withAlpha(55),
                            Colors.white.withAlpha(30),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white.withAlpha(50)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white60,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      tabs: [
                        Tab(
                          height: 32,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.menu_book_rounded, size: 14),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Materi',
                                  style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Tab(
                          height: 32,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.forum_rounded, size: 14),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Forum Kelas',
                                  style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Tab(
                          height: 32,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.assignment_rounded, size: 14),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  assignments.isNotEmpty ? 'Tugas (${assignments.length})' : 'Tugas',
                                  style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600),
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

                // Real-Time Progress Bar Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _progressPercent >= 100
                          ? const Color(0xFF10B981).withAlpha(100)
                          : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _progressPercent >= 100
                            ? const Color(0xFF10B981).withAlpha(25)
                            : Colors.black.withAlpha(8),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _progressPercent >= 100
                                  ? const Color(0xFFD1FAE5)
                                  : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _progressPercent >= 100
                                  ? Icons.verified_rounded
                                  : Icons.trending_up_rounded,
                              color: _progressPercent >= 100
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF0D2B6E),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Progres Belajar Mandiri',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Tersinkronisasi otomatis ke Guru & Firebase',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _progressPercent >= 100
                                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                    : (_progressPercent >= 50 && hasAssignments && !assignmentsDone)
                                        ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                                        : [const Color(0xFF0D2B6E), const Color(0xFF1E3A8A)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: (_progressPercent >= 100
                                          ? const Color(0xFF10B981)
                                          : (_progressPercent >= 50 && hasAssignments && !assignmentsDone)
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF0D2B6E))
                                      .withAlpha(60),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '${_progressPercent.toInt()}%',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Progress Bar with custom rounded track
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 10,
                          child: Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                color: const Color(0xFFF1F5F9),
                              ),
                              FractionallySizedBox(
                                widthFactor: (_progressPercent / 100).clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _progressPercent >= 100
                                          ? [const Color(0xFF10B981), const Color(0xFF34D399)]
                                          : (_progressPercent >= 50 && hasAssignments && !assignmentsDone)
                                              ? [const Color(0xFFF59E0B), const Color(0xFFFBBF24)]
                                              : [const Color(0xFF0D2B6E), const Color(0xFF3B82F6)],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _progressPercent >= 100
                            ? (hasAssignments
                                ? '🎉 Hebat! Kamu sudah menyelesaikan membaca materi dan mengumpulkan tugas (100% Tuntas).'
                                : '🎉 Hebat! Kamu sudah menyelesaikan materi ini 100% dan tersimpan otomatis di Firebase.')
                            : (hasAssignments && !assignmentsDone)
                                ? (_progressPercent >= 50
                                    ? '📖 Membaca materi selesai (Maks. 50%). Selesaikan tugas materi ini di tab "Tugas" untuk mencapai 100%!'
                                    : '⚡ Progres membaca tercatat ${_progressPercent.toInt()}% (Maksimal 50% untuk membaca materi. Tugas wajib dikerjakan untuk 100%).')
                                : _progressPercent > 0
                                    ? '⚡ Terhubung ke Firebase: Progres tercatat ${_progressPercent.toInt()}% secara otomatis saat membaca slide / menonton video.'
                                    : '📖 Progres bertambah otomatis saat kamu membaca slide, menyimak video, atau menelaah materi.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _progressPercent >= 100
                              ? const Color(0xFF059669)
                              : (hasAssignments && !assignmentsDone && _progressPercent >= 50)
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF64748B),
                          fontWeight: _progressPercent >= 100 || (hasAssignments && !assignmentsDone && _progressPercent >= 50)
                              ? FontWeight.w600
                              : FontWeight.normal,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Status otomatisasi progres (tanpa validasi manual oleh siswa)
                      if (!isTeacher) ...[
                        if (_progressPercent >= 100) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withAlpha(15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF10B981).withAlpha(40)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    hasAssignments
                                        ? 'Materi & Tugas Tuntas 100% (Tervalidasi Otomatis)'
                                        : 'Materi tuntas dipelajari 100% (Tervalidasi Otomatis)',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: const Color(0xFF059669),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '+20 Poin',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (hasAssignments && !assignmentsDone && _progressPercent >= 50) ...[
                          // Membaca mencapai batas maksimal 50%, ajak siswa ke Tab Tugas
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.assignment_late_rounded, color: Color(0xFFD97706), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Membaca Tuntas 50% • Kerjakan Tugas untuk 100%',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF92400E),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Materi ini memiliki tugas yang wajib dikumpulkan agar progres belajarmu tuntas 100%.',
                                  style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD97706),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                                    label: Text(
                                      'Buka Tab Tugas (${applicableAssignments.length})',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    onPressed: () => _tabController.animateTo(2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D2B6E).withAlpha(10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF0D2B6E).withAlpha(25)),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D2B6E)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    hasAssignments
                                        ? 'Progres membaca bertambah otomatis hingga 50% (Selesaikan tugas untuk 100%).'
                                        : 'Progres bertambah otomatis saat kamu membaca materi & menyimak media.',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      color: const Color(0xFF0D2B6E),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

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

          // TAB 3: Assignments List
          Builder(
            builder: (context) {
              final displayedAssignments = isTeacher && _selectedAssignmentClass != 'all'
                  ? assignments.where((a) => a.classIds.isEmpty || a.classIds.contains(_selectedAssignmentClass)).toList()
                  : assignments;

              return Column(
                children: [
                  if (isTeacher) ...[
                    // Class Filter Bar for Assignments
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                                  color: AppColors.emerald.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.tune_rounded, size: 16, color: AppColors.emerald),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Filter Tugas Berdasarkan Kelas:',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(
                                      'Semua Kelas (${assignments.length})',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: _selectedAssignmentClass == 'all' ? FontWeight.bold : FontWeight.w500,
                                        color: _selectedAssignmentClass == 'all' ? Colors.white : const Color(0xFF334155),
                                      ),
                                    ),
                                    selected: _selectedAssignmentClass == 'all',
                                    selectedColor: AppColors.primary,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    showCheckmark: false,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: _selectedAssignmentClass == 'all' ? AppColors.primary : Colors.transparent,
                                      ),
                                    ),
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _selectedAssignmentClass = 'all';
                                        });
                                      }
                                    },
                                  ),
                                ),
                                ...teacherClasses.map((cls) {
                                  final isSelected = _selectedAssignmentClass == cls;
                                  final count = assignments.where((a) => a.classIds.isEmpty || a.classIds.contains(cls)).length;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Text(
                                        '$cls ($count)',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected ? Colors.white : const Color(0xFF334155),
                                        ),
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
                                            _selectedAssignmentClass = cls;
                                          });
                                        }
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.add_task_rounded),
                          label: const Text('Buat Tugas Baru untuk Materi Ini'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AssignmentFormScreen(
                                  materialId: widget.material.id,
                                  subjectId: widget.material.subjectId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
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
                                    isTeacher && _selectedAssignmentClass != 'all'
                                        ? 'Tidak ada tugas untuk kelas $_selectedAssignmentClass.'
                                        : 'Tidak ada tugas untuk materi ini.',
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

                              // For teachers, calculate submission stats for this assignment
                              final allSubs = fbService.getSubmissionsForAssignment(asg.id);
                              final classSubs = _selectedAssignmentClass == 'all'
                                  ? allSubs
                                  : allSubs.where((s) {
                                      final std = fbService.allStudents.where((u) => u.id == s.submitterId).firstOrNull;
                                      final c = std?.className ?? std?.classId ?? 'X-RPL-1';
                                      return c == _selectedAssignmentClass;
                                    }).toList();
                              final gradedCount = classSubs.where((s) => s.score != null).length;

                              return Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: AppColors.borderLight),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: asg.codeConfig != null
                                          ? AppColors.accent.withAlpha(20)
                                          : AppColors.primary.withAlpha(20),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      asg.codeConfig != null ? Icons.code_rounded : Icons.assignment_rounded,
                                      color: asg.codeConfig != null ? AppColors.accent : AppColors.primary,
                                    ),
                                  ),
                                  title: Text(
                                    asg.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(asg.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (asg.classIds.isNotEmpty)
                                            ...asg.classIds.map((c) => Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withAlpha(15),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: AppColors.primary.withAlpha(40)),
                                                  ),
                                                  child: Text(
                                                    c,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                )),
                                          if (asg.isGroup)
                                            Chip(
                                              label: Text('Kelompok (${asg.maxGroupMembers} Siswa)'),
                                              backgroundColor: Colors.blue.shade50,
                                              labelStyle: const TextStyle(fontSize: 10, color: Colors.blue),
                                              padding: EdgeInsets.zero,
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ...asg.allowedSubmissionTypes.map((t) => Chip(
                                                label: Text(t.label),
                                                backgroundColor: Colors.grey.shade100,
                                                labelStyle: const TextStyle(fontSize: 10),
                                                padding: EdgeInsets.zero,
                                                visualDensity: VisualDensity.compact,
                                              )),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Builder(
                                    builder: (context) {
                                      if (isTeacher) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withAlpha(15),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: AppColors.primary.withAlpha(50)),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.groups_outlined, size: 13, color: AppColors.primary),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${classSubs.length} Kumpul',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '$gradedCount Dinilai',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: gradedCount > 0 ? AppColors.emerald : Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      final sub = fbService.submissions.where(
                                        (s) => s.assignmentId == asg.id && (s.submitterId == currentUser?.id || s.memberStudentIds.contains(currentUser?.id)),
                                      ).firstOrNull;

                                      if (sub != null) {
                                        if (sub.score != null) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.emerald.withAlpha(20),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: AppColors.emerald.withAlpha(70)),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  'Nilai',
                                                  style: TextStyle(fontSize: 10, color: AppColors.emerald, fontWeight: FontWeight.bold),
                                                ),
                                                Text(
                                                  '${sub.score!.toInt()}',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w900,
                                                    color: AppColors.emerald,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        } else {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B).withAlpha(20),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0xFFF59E0B).withAlpha(70)),
                                            ),
                                            child: const Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.hourglass_top_rounded, size: 14, color: Color(0xFFB45309)),
                                                SizedBox(height: 2),
                                                Text(
                                                  'Terkumpul',
                                                  style: TextStyle(fontSize: 9.5, color: Color(0xFFB45309), fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      }
                                      return const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.chevron_right, color: Colors.grey),
                                          Text(
                                            'Kerjakan',
                                            style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AssignmentDetailScreen(assignment: asg),
                                      ),
                                    );
                                  },
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
