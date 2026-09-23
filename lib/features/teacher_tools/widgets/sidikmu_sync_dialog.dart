import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/sidikmu_service.dart';

class SidikmuSyncDialog extends StatefulWidget {
  final bool isFormatif;
  final String targetClassName;
  final String targetSubjectName;
  final String? targetCpCode;
  final String? targetTpCode;
  final String? examTitle;
  final String? assignmentId;
  final String? examId;
  final Map<String, double?> studentGradesByNis;
  final Map<String, String> studentNamesByNis;

  const SidikmuSyncDialog({
    super.key,
    required this.isFormatif,
    required this.targetClassName,
    required this.targetSubjectName,
    this.targetCpCode,
    this.targetTpCode,
    this.examTitle,
    this.assignmentId,
    this.examId,
    required this.studentGradesByNis,
    required this.studentNamesByNis,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isFormatif,
    required String targetClassName,
    required String targetSubjectName,
    String? targetCpCode,
    String? targetTpCode,
    String? examTitle,
    String? assignmentId,
    String? examId,
    required Map<String, double?> studentGradesByNis,
    required Map<String, String> studentNamesByNis,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SidikmuSyncDialog(
        isFormatif: isFormatif,
        targetClassName: targetClassName,
        targetSubjectName: targetSubjectName,
        targetCpCode: targetCpCode,
        targetTpCode: targetTpCode,
        examTitle: examTitle,
        assignmentId: assignmentId,
        examId: examId,
        studentGradesByNis: studentGradesByNis,
        studentNamesByNis: studentNamesByNis,
      ),
    );
  }

  @override
  State<SidikmuSyncDialog> createState() => _SidikmuSyncDialogState();
}

class _SidikmuSyncDialogState extends State<SidikmuSyncDialog> {
  WebViewController? _webController;
  bool _isWebViewReady = false;

  // Phase: 'confirm' -> 'syncing' -> 'result'
  String _currentPhase = 'confirm';

  // Config parameters
  late String _academicYear;
  late String _semester;
  late String _sumatifType;
  late String _className;
  late String _subjectName;

  // Interactive student data
  late Map<String, double?> _studentGradesByNis;
  late Map<String, String> _studentNamesByNis;
  late final TextEditingController _cpCtrl;
  late final TextEditingController _tpCtrl;
  bool _showStudentList = false;

  // Progress state
  double _progressPercentage = 0.0;
  String _progressMessage = 'Menyiapkan sinkronisasi...';

  // Result state
  SidikmuSyncResult? _syncResult;

  // Quick SidikMu credentials input when teacher hasn't linked account yet
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final period = SidikmuService.calculateAcademicPeriod();
    _academicYear = period.academicYear;
    _semester = period.semester;
    _sumatifType = widget.examTitle != null
        ? SidikmuService.detectSumatifType(widget.examTitle!)
        : 'Harian';
    _className = widget.targetClassName;
    _subjectName = widget.targetSubjectName;

    final initialCp = (widget.targetCpCode != null && widget.targetCpCode!.isNotEmpty)
        ? widget.targetCpCode!
        : 'CP 1';
    final initialTp = (widget.targetTpCode != null && widget.targetTpCode!.isNotEmpty)
        ? widget.targetTpCode!
        : '1.1';

    _cpCtrl = TextEditingController(text: initialCp);
    _tpCtrl = TextEditingController(text: initialTp);

    _studentGradesByNis = widget.studentGradesByNis.map((k, v) => MapEntry(k, v ?? 0.0));
    _studentNamesByNis = Map.from(widget.studentNamesByNis);

    _initWebView();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _cpCtrl.dispose();
    _tpCtrl.dispose();
    super.dispose();
  }

  void _initWebView() {
    if (kIsWeb) {
      _webController = null;
      return;
    }
    try {
      _webController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) {
              if (!_isWebViewReady && mounted) {
                setState(() => _isWebViewReady = true);
              }
            },
          ),
        );
    } catch (e) {
      debugPrint('[SidikMu] WebViewController initialization safe fallback: $e');
      _webController = null;
    }
  }

  void _openApkDownload() {
    launchUrl(
      Uri.parse('https://github.com/Azizulakbar89/e-Learning-Final-Bos/releases'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _onClassChanged(String newClass, FirebaseService fb) {
    setState(() {
      _className = newClass;
      final classStudents = fb.allStudents.where((s) {
        final sClass = (s.className ?? s.classId ?? '').trim().toLowerCase();
        final target = newClass.trim().toLowerCase();
        if (target.isEmpty || target == 'semua kelas') return true;
        return sClass == target ||
            (s.classId != null && s.classId!.toLowerCase() == target) ||
            (s.className != null && target.contains(s.className!.toLowerCase())) ||
            (s.className != null && s.className!.toLowerCase().contains(target));
      }).toList();

      if (classStudents.isNotEmpty) {
        final newGrades = <String, double?>{};
        final newNames = <String, String>{};

        for (final s in classStudents) {
          final nis = (s.nis ?? '').trim();
          if (nis.isNotEmpty) {
            newGrades[nis] = 0.0;
            newNames[nis] = s.fullName;
          }
        }

        if (widget.assignmentId != null) {
          final submissions = fb.getSubmissionsForAssignment(widget.assignmentId!);
          for (final sub in submissions) {
            final student = fb.allStudents.where((std) => std.id == sub.submitterId).firstOrNull;
            final nis = (student?.nis ?? '').trim();
            if (nis.isNotEmpty && newGrades.containsKey(nis)) {
              newGrades[nis] = sub.score ?? 0.0;
              newNames[nis] = student!.fullName.isNotEmpty ? student.fullName : sub.submitterName;
            }
            for (final memId in sub.memberStudentIds) {
              final mem = fb.allStudents.where((m) => m.id == memId).firstOrNull;
              final memNis = (mem?.nis ?? '').trim();
              if (memNis.isNotEmpty && newGrades.containsKey(memNis)) {
                newGrades[memNis] = sub.score ?? 0.0;
                newNames[memNis] = mem!.fullName;
              }
            }
          }
        } else {
          for (final entry in widget.studentGradesByNis.entries) {
            if (newGrades.containsKey(entry.key)) {
              newGrades[entry.key] = entry.value ?? 0.0;
            }
          }
        }

        _studentGradesByNis = newGrades;
        _studentNamesByNis = newNames;
      }
    });
  }

  Future<void> _startSync() async {
    final fb = context.read<FirebaseService>();
    var teacher = fb.currentUser;

    if (!kIsWeb && (teacher == null || !teacher.hasSidikmuAccount)) {
      if (_usernameCtrl.text.trim().isNotEmpty && _passwordCtrl.text.isNotEmpty) {
        if (teacher != null) {
          try {
            await fb.updateTeacherSidikmuCredentials(
              teacherId: teacher.id,
              sidikmuUrl: SidikmuService.defaultUrl,
              sidikmuUsername: _usernameCtrl.text.trim(),
              sidikmuPassword: _passwordCtrl.text,
            );
            teacher = fb.currentUser;
          } catch (e) {
            debugPrint('[SidikmuSyncDialog] updateTeacherSidikmuCredentials error: $e');
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan masukkan username dan password SidikMu untuk melanjutkan.'),
            backgroundColor: Color(0xFFD97706),
          ),
        );
        return;
      }
    }

    setState(() {
      _currentPhase = 'syncing';
      _progressPercentage = 0.05;
      _progressMessage = 'Menginisialisasi sinkronisasi SidikMu...';
    });

    final sidikmuUrl = teacher?.sidikmuUrl ?? SidikmuService.defaultUrl;
    final username = teacher?.sidikmuUsername ?? _usernameCtrl.text.trim();
    final password = teacher?.sidikmuPassword ?? _passwordCtrl.text;
    final sanitizedGrades = _studentGradesByNis.map((k, v) => MapEntry(k, v ?? 0.0));

    final SidikmuSyncResult result;
    if (_webController != null) {
      result = await SidikmuService.syncGradesAutomation(
        controller: _webController!,
        url: sidikmuUrl,
        username: username,
        password: password,
        isFormatif: widget.isFormatif,
        academicYear: _academicYear,
        semester: _semester,
        sumatifType: _sumatifType,
        targetClassName: _className,
        targetSubjectName: _subjectName,
        targetCpCode: _cpCtrl.text.trim().isNotEmpty ? _cpCtrl.text.trim() : null,
        targetTpCode: _tpCtrl.text.trim().isNotEmpty ? _tpCtrl.text.trim() : null,
        studentGradesByNis: sanitizedGrades,
        studentNamesByNis: _studentNamesByNis,
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _progressPercentage = p.percentage;
              _progressMessage = p.stageMessage;
            });
          }
        },
      );
    } else {
      result = await SidikmuService.syncGradesViaHttp(
        url: sidikmuUrl,
        username: username,
        password: password,
        isFormatif: widget.isFormatif,
        academicYear: _academicYear,
        semester: _semester,
        sumatifType: _sumatifType,
        targetClassName: _className,
        targetSubjectName: _subjectName,
        targetCpCode: _cpCtrl.text.trim().isNotEmpty ? _cpCtrl.text.trim() : null,
        targetTpCode: _tpCtrl.text.trim().isNotEmpty ? _tpCtrl.text.trim() : null,
        studentGradesByNis: sanitizedGrades,
        studentNamesByNis: _studentNamesByNis,
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _progressPercentage = p.percentage;
              _progressMessage = p.stageMessage;
            });
          }
        },
      );
    }

    if (result.isSuccess && teacher != null) {
      await fb.updateTeacherSidikmuLastSynced(teacherId: teacher.id);
    }

    if (mounted) {
      setState(() {
        _currentPhase = 'result';
        _syncResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 750),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Headless Desktop-viewport WebView container for Android Automation
            if (_webController != null)
              Positioned(
                left: 0,
                top: 0,
                child: SizedBox(
                  width: 1,
                  height: 1,
                  child: OverflowBox(
                    minWidth: 1280,
                    maxWidth: 1280,
                    minHeight: 800,
                    maxHeight: 800,
                    alignment: Alignment.topLeft,
                    child: Transform.scale(
                      scale: 0.001,
                      alignment: Alignment.topLeft,
                      child: IgnorePointer(
                        child: WebViewWidget(controller: _webController!),
                      ),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_currentPhase == 'confirm') _buildConfirmPhase(),
                          if (_currentPhase == 'syncing') _buildSyncingPhase(),
                          if (_currentPhase == 'result') _buildResultPhase(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7).withAlpha(30),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.cloud_sync_rounded,
            color: Color(0xFF0284C7),
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sinkronisasi Nilai SidikMu',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.isFormatif ? 'Kategori: Nilai Formatif (Tugas)' : 'Kategori: Nilai Sumatif (Ujian)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        if (_currentPhase != 'syncing')
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            color: Colors.grey.shade600,
          ),
      ],
    );
  }

  Widget _buildConfirmPhase() {
    final totalStudents = _studentGradesByNis.length;
    final filledCount = _studentGradesByNis.values.where((v) => v != null).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF0284C7)),
                  const SizedBox(width: 10),
                  Text(
                    'Tahun & Smt',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const Spacer(),
                  DropdownButton<String>(
                    value: ['2026/2027', '2025/2026', '2024/2025'].contains(_academicYear) ? _academicYear : '2026/2027',
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                    items: ['2026/2027', '2025/2026', '2024/2025'].map((y) {
                      return DropdownMenuItem(value: y, child: Text(y));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _academicYear = val);
                    },
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: ['Gasal', 'Genap'].contains(_semester) ? _semester : 'Gasal',
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                    items: ['Gasal', 'Genap'].map((s) {
                      return DropdownMenuItem(value: s, child: Text(s));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _semester = val);
                    },
                  ),
                ],
              ),
              const Divider(height: 14),
              Builder(builder: (context) {
                final fb = context.watch<FirebaseService>();
                final availableClasses = fb.getAvailableClasses();
                if (availableClasses.length > 1) {
                  return Row(
                    children: [
                      const Icon(Icons.meeting_room_rounded, size: 18, color: Color(0xFF0284C7)),
                      const SizedBox(width: 10),
                      Text(
                        'Kelas Target',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const Spacer(),
                      DropdownButton<String>(
                        value: availableClasses.contains(_className) ? _className : availableClasses.firstOrNull,
                        underline: const SizedBox.shrink(),
                        isDense: true,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryLight,
                        ),
                        items: availableClasses.map((c) {
                          return DropdownMenuItem<String>(
                            value: c,
                            child: Text(c),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            _onClassChanged(val, fb);
                          }
                        },
                      ),
                    ],
                  );
                }
                return _buildParamRow(
                  icon: Icons.meeting_room_rounded,
                  label: 'Kelas Target',
                  value: _className,
                );
              }),
              const Divider(height: 14),
              _buildParamRow(
                icon: Icons.menu_book_rounded,
                label: 'Mata Pelajaran',
                value: _subjectName,
              ),
              if (!widget.isFormatif) ...[
                const Divider(height: 14),
                _buildParamRow(
                  icon: Icons.grading_rounded,
                  label: 'Jenis Nilai Sumatif',
                  value: _sumatifType,
                ),
              ],
              const Divider(height: 14),
              // Kode CP
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.bookmark_added_rounded, size: 18, color: Color(0xFF0284C7)),
                  const SizedBox(width: 10),
                  Text(
                    'Kode CP',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 120,
                    height: 34,
                    child: TextFormField(
                      controller: _cpCtrl,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                      textAlign: TextAlign.end,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        hintText: 'e.g. CP 1',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: ['CP 1', 'CP 2', 'CP 3', 'CP 4'].map((chip) {
                  final isSelected = _cpCtrl.text.trim().toLowerCase() == chip.toLowerCase();
                  return ChoiceChip(
                    label: Text(chip, style: TextStyle(fontSize: 10.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _cpCtrl.text = chip),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                }).toList(),
              ),

              if (widget.isFormatif) ...[
                const Divider(height: 14),
                // Kode TP
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF0284C7)),
                    const SizedBox(width: 10),
                    Text(
                      'Kode TP',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 120,
                      height: 34,
                      child: TextFormField(
                        controller: _tpCtrl,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryLight,
                        ),
                        textAlign: TextAlign.end,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          hintText: 'e.g. 1.1',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: ['1.1', '1.2', '1.3', '2.1'].map((chip) {
                    final isSelected = _tpCtrl.text.trim().toLowerCase() == chip.toLowerCase();
                    return ChoiceChip(
                      label: Text(chip, style: TextStyle(fontSize: 10.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _tpCtrl.text = chip),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Interactive Student List & Scores Preview (NIS, Nama, Nilai)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => setState(() => _showStudentList = !_showStudentList),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.format_list_numbered_rounded, color: Color(0xFF0284C7), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Daftar Nilai Siswa ($totalStudents Siswa)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$filledCount Terisi',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _showStudentList ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showStudentList) ...[
                const Divider(height: 1),
                Container(
                  color: Colors.grey.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: const Row(
                    children: [
                      SizedBox(width: 24, child: Text('No', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey))),
                      SizedBox(width: 60, child: Text('NIS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey))),
                      Expanded(child: Text('Nama Siswa', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey))),
                      SizedBox(width: 55, child: Text('Nilai', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey))),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _studentGradesByNis.length,
                    separatorBuilder: (_, index) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (ctx, idx) {
                      final nis = _studentGradesByNis.keys.elementAt(idx);
                      final name = _studentNamesByNis[nis] ?? 'Siswa $nis';
                      final score = _studentGradesByNis[nis] ?? 0.0;
                      final scoreStr = score % 1 == 0 ? score.toInt().toString() : score.toString();

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                nis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w500),
                              ),
                            ),
                            SizedBox(
                              width: 55,
                              height: 30,
                              child: TextFormField(
                                key: ValueKey('score_$nis'),
                                initialValue: scoreStr,
                                textAlign: TextAlign.center,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: score > 0 ? const Color(0xFF15803D) : Colors.grey.shade700,
                                ),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  contentPadding: EdgeInsets.zero,
                                  filled: true,
                                  fillColor: score > 0 ? const Color(0xFFF0FDF4) : Colors.grey.shade100,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                onChanged: (val) {
                                  final numVal = double.tryParse(val.trim()) ?? 0.0;
                                  _studentGradesByNis[nis] = numVal;
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Android Background Automation Banner / Setup Card
        if (!kIsWeb) ...[
          Builder(builder: (context) {
            final fb = context.watch<FirebaseService>();
            final teacher = fb.currentUser;
            final isLinked = teacher?.hasSidikmuAccount ?? false;

            if (isLinked) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.smart_toy_rounded, color: Color(0xFF16A34A), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Mode Automasi Latar Belakang Aktif',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Akun SidikMu: ${teacher?.sidikmuUsername}. Sistem akan otomatis login, memilih filter, mengisi nilai $totalStudents siswa, dan menyimpannya di SidikMu.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              );
            } else {
              return Container(
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
                        const Icon(Icons.key_rounded, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Tautkan Akun SidikMu Guru',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Masukkan username & password SidikMu untuk automasi login dan input nilai:',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _usernameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Username SidikMu',
                        labelStyle: const TextStyle(fontSize: 11),
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 16),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password SidikMu',
                        labelStyle: const TextStyle(fontSize: 11),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 16),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 16),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }
          }),
          const SizedBox(height: 12),
        ],

        // Web Browser Info Banner
        if (kIsWeb) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.android_rounded, size: 18, color: Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    Text(
                      'Automasi Penuh (Aplikasi Android)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Untuk sinkronisasi otomatis di latar belakang, jalankan melalui Aplikasi Android.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                ElevatedButton.icon(
                  onPressed: _openApkDownload,
                  icon: const Icon(Icons.download_rounded, size: 15),
                  label: const Text('Unduh Aplikasi Android (.apk)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Info Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$totalStudents nilai siswa siap disinkronkan ($filledCount nilai terisi).',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ElevatedButton(
          onPressed: _startSync,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.smart_toy_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                '🚀 Mulai Sinkronisasi Otomatis 100%',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParamRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0284C7)),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppColors.textSecondaryLight,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildSyncingPhase() {
    final pctInt = (_progressPercentage * 100).toInt().clamp(0, 100);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: CircularProgressIndicator(
                value: _progressPercentage,
                strokeWidth: 8,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$pctInt%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0284C7),
                  ),
                ),
                Text(
                  'Memproses',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          _progressMessage,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Proses sinkronisasi sedang berjalan.\nMohon tunggu sejenak...',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildResultPhase() {
    final res = _syncResult;
    if (res == null) return const SizedBox.shrink();

    final isSuccess = res.isSuccess;
    final emptyOrZero = res.emptyOrZeroStudents;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Icon Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSuccess ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSuccess ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  size: 44,
                  color: isSuccess ? const Color(0xFF16A34A) : Colors.amber.shade800,
                ),
                const SizedBox(height: 8),
                Text(
                  isSuccess
                      ? (kIsWeb ? 'Data Nilai Siap Digunakan!' : 'Sinkronisasi Selesai!')
                      : 'Sinkronisasi Belum Berhasil',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isSuccess ? const Color(0xFF15803D) : Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  res.message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Ringkasan Hasil Sinkronisasi
          if (isSuccess) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '${res.totalStudents}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Total Siswa',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      Container(height: 30, width: 1, color: Colors.grey.shade300),
                      Column(
                        children: [
                          Text(
                            '${res.syncedStudents}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tersimpan',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      Container(height: 30, width: 1, color: Colors.grey.shade300),
                      Column(
                        children: [
                          Text(
                            '${emptyOrZero.length}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: emptyOrZero.isNotEmpty ? Colors.orange.shade800 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kosong / 0',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nilai seluruh siswa telah berhasil diisi dan disimpan ke portal SidikMu secara otomatis di latar belakang.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Rekap Siswa Nilai Kosong atau 0
          if (emptyOrZero.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
                const SizedBox(width: 6),
                Text(
                  'Perhatian: ${emptyOrZero.length} Siswa Bernilai Kosong / 0',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: emptyOrZero.length,
                separatorBuilder: (context, index) => Divider(height: 12, color: Colors.grey.shade200),
                itemBuilder: (ctx, idx) {
                  final item = emptyOrZero[idx];
                  final isZero = item.score == 0.0;
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isZero ? Colors.orange.shade50 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'NIS: ${item.nis}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isZero ? Colors.orange.shade900 : Colors.grey.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.studentName.isNotEmpty ? item.studentName : 'Siswa ${item.nis}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isZero ? 'Nilai: 0' : 'Kosong',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isZero ? Colors.orange.shade800 : Colors.red.shade700,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Link Download Aplikasi Android khusus jika di Web
          if (kIsWeb) ...[
            InkWell(
              onTap: _openApkDownload,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.android_rounded, size: 16, color: Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Gunakan Aplikasi Android untuk automasi 100% di latar belakang',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF16A34A),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Tombol Selesai / Tutup
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: isSuccess ? const Color(0xFF0284C7) : Colors.grey.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              isSuccess ? 'Selesai & Tutup' : 'Tutup Dialog',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
