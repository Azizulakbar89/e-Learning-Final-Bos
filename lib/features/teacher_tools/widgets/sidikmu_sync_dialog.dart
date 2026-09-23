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
  late String _cpCode;
  late String _tpCode;

  // Progress state
  double _progressPercentage = 0.0;
  String _progressMessage = 'Menyiapkan sinkronisasi...';

  // Result state
  SidikmuSyncResult? _syncResult;

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
    _cpCode = widget.targetCpCode ?? '';
    _tpCode = widget.targetTpCode ?? '';

    _initWebView();
  }

  void _initWebView() {
    try {
      if (WebViewPlatform.instance == null) {
        debugPrint('[SidikMu] WebViewPlatform.instance is null on this device. Using HTTP direct sync.');
        _webController = null;
        return;
      }
      _webController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(
            'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36')
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

  Future<void> _startSync() async {
    final fb = context.read<FirebaseService>();
    final teacher = fb.currentUser;

    if (teacher == null || !teacher.hasSidikmuAccount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun SidikMu belum ditautkan. Silakan hubungkan di menu Profil.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _currentPhase = 'syncing';
      _progressPercentage = 0.05;
      _progressMessage = 'Menginisialisasi automasi SidikMu...';
    });

    final sidikmuUrl = teacher.sidikmuUrl ?? SidikmuService.defaultUrl;
    final username = teacher.sidikmuUsername!;
    final password = teacher.sidikmuPassword!;

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
        targetCpCode: _cpCode.isNotEmpty ? _cpCode : null,
        targetTpCode: _tpCode.isNotEmpty ? _tpCode : null,
        studentGradesByNis: widget.studentGradesByNis,
        studentNamesByNis: widget.studentNamesByNis,
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
        targetCpCode: _cpCode.isNotEmpty ? _cpCode : null,
        targetTpCode: _tpCode.isNotEmpty ? _tpCode : null,
        studentGradesByNis: widget.studentGradesByNis,
        studentNamesByNis: widget.studentNamesByNis,
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

    if (result.isSuccess) {
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Stack(
          children: [
            // Headless WebView container (only active if WebView platform is available)
            if (_webController != null)
              SizedBox(
                width: 1,
                height: 1,
                child: Opacity(
                  opacity: 0.01,
                  child: WebViewWidget(controller: _webController!),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  if (_currentPhase == 'confirm') _buildConfirmPhase(),
                  if (_currentPhase == 'syncing') _buildSyncingPhase(),
                  if (_currentPhase == 'result') _buildResultPhase(),
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
                  fontSize: 18,
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
    final totalStudents = widget.studentGradesByNis.length;

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
            children: [
              _buildParamRow(
                icon: Icons.calendar_month_rounded,
                label: 'Tahun Ajaran & Semester',
                value: '$_academicYear ($_semester)',
              ),
              const Divider(height: 16),
              _buildParamRow(
                icon: Icons.meeting_room_rounded,
                label: 'Kelas Target',
                value: _className,
              ),
              const Divider(height: 16),
              _buildParamRow(
                icon: Icons.menu_book_rounded,
                label: 'Mata Pelajaran',
                value: _subjectName,
              ),
              if (!widget.isFormatif) ...[
                const Divider(height: 16),
                _buildParamRow(
                  icon: Icons.grading_rounded,
                  label: 'Jenis Nilai Sumatif',
                  value: _sumatifType,
                ),
              ],
              if (_cpCode.isNotEmpty) ...[
                const Divider(height: 16),
                _buildParamRow(
                  icon: Icons.bookmark_added_rounded,
                  label: 'Kode CP',
                  value: _cpCode,
                ),
              ],
              if (widget.isFormatif && _tpCode.isNotEmpty) ...[
                const Divider(height: 16),
                _buildParamRow(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Kode TP',
                  value: _tpCode,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Info Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.people_alt_rounded, size: 20, color: Color(0xFF0284C7)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$totalStudents nilai siswa siap dicocokkan berdasarkan NIS.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _startSync,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow_rounded, size: 22),
              const SizedBox(width: 8),
              Text(
                'Mulai Sinkronisasi Sekarang',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
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
          'Proses sinkronisasi otomatis sedang berjalan di background.\nMohon tunggu hingga selesai 100%.',
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

    return Column(
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
                isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                size: 44,
                color: isSuccess ? const Color(0xFF16A34A) : Colors.redAccent,
              ),
              const SizedBox(height: 8),
              Text(
                isSuccess ? 'Sinkronisasi Selesai!' : 'Sinkronisasi Belum Berhasil',
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
        const SizedBox(height: 16),

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
            constraints: const BoxConstraints(maxHeight: 180),
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
          const SizedBox(height: 16),
        ],

        // Tombol Aksi Akhir
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  launchUrl(
                    Uri.parse('https://smpm12gkb.sidikmu.com'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Color(0xFF0284C7)),
                ),
                child: Text(
                  'Buka Web SidikMu',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0284C7),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  'Selesai',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
