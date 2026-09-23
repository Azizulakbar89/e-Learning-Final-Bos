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
    _cpCode = widget.targetCpCode ?? '';
    _tpCode = widget.targetTpCode ?? '';

    _initWebView();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Headless Desktop-viewport WebView container for Android Automation
            // Placed at (0, 0) inside bounds with micro-scale so Android compositor never culls or pauses JS/DOM
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
                            setState(() => _className = val);
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
        const SizedBox(height: 14),

        // Android Background Automation Banner / Setup Card
        if (!kIsWeb) ...[
          Builder(builder: (context) {
            final fb = context.watch<FirebaseService>();
            final teacher = fb.currentUser;
            final isLinked = teacher?.hasSidikmuAccount ?? false;

            if (isLinked) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.smart_toy_rounded, color: Color(0xFF16A34A), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Mode Automasi Latar Belakang Aktif',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Akun SidikMu terhubung: ${teacher?.sidikmuUsername}. Sistem akan otomatis login, memilih kelas & mapel, mengisi nilai $totalStudents siswa, dan menyimpannya di SidikMu di latar belakang tanpa membuka browser.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              );
            } else {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.key_rounded, color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Tautkan Akun SidikMu Guru',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Masukkan username & password SidikMu sekali saja untuk automasi login dan input nilai tanpa keluar aplikasi:',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _usernameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Username SidikMu',
                        labelStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password SidikMu',
                        labelStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }
          }),
          const SizedBox(height: 14),
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
                    const Icon(Icons.android_rounded, size: 20, color: Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    Text(
                      'Automasi Penuh 100% (Aplikasi Android)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Untuk automasi sinkronisasi 100% di latar belakang tanpa membuka SidikMu sama sekali, jalankan melalui Aplikasi Android E-Learning.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _openApkDownload,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Unduh Aplikasi Android (.apk)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

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
                  '$totalStudents nilai siswa siap disinkronkan ke SidikMu.',
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
              const Icon(Icons.smart_toy_rounded, size: 22),
              const SizedBox(width: 8),
              Text(
                '🚀 Mulai Sinkronisasi Otomatis 100%',
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
