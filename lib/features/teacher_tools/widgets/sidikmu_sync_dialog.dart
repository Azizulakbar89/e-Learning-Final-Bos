import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/excel_service.dart';
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
  final _directUrlCtrl = TextEditingController();
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
    _directUrlCtrl.dispose();
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

  void _copyAutoFillScript() {
    final cleanMap = <String, num>{};
    final cleanNames = <String, String>{};
    widget.studentGradesByNis.forEach((nis, score) {
      final cleanNis = nis.trim();
      if (score != null) {
        cleanMap[cleanNis] = (score % 1 == 0) ? score.toInt() : score;
      }
      if (widget.studentNamesByNis.containsKey(nis)) {
        cleanNames[cleanNis] = widget.studentNamesByNis[nis]!.trim();
      }
    });

    final jsonGrades = jsonEncode(cleanMap);
    final jsonNames = jsonEncode(cleanNames);
    final script = '''javascript:(function(){
  var g = $jsonGrades;
  var names = $jsonNames;
  var rows = Array.from(document.querySelectorAll("table tbody tr, table tr")).filter(function(r){
    return r.querySelectorAll("td").length >= 2;
  });
  var count = 0;
  rows.forEach(function(row){
    var cells = row.querySelectorAll("td");
    if(cells.length < 2) return;
    var rowText = (row.innerText || "").replace(/\\s+/g, " ");
    var matchedNis = null;

    if(cells.length > 1){
      var cand = (cells[1].innerText || "").trim();
      if(g.hasOwnProperty(cand)) matchedNis = cand;
    }
    if(!matchedNis){
      for(var k in g){
        if(k && rowText.indexOf(k) !== -1){
          matchedNis = k;
          break;
        }
      }
    }
    if(!matchedNis && cells.length > 2){
      var cName = (cells[2].innerText || "").toLowerCase().trim();
      for(var k in names){
        var nm = (names[k] || "").toLowerCase().trim();
        if(nm.length > 3 && (cName.indexOf(nm) !== -1 || nm.indexOf(cName) !== -1)){
          matchedNis = k;
          break;
        }
      }
    }

    if(matchedNis && g.hasOwnProperty(matchedNis)){
      var inps = row.querySelectorAll('input:not([type="hidden"]):not([type="checkbox"])');
      var inp = inps.length > 0 ? inps[inps.length - 1] : row.querySelector('input');
      if(inp){
        var val = g[matchedNis];
        inp.value = val;
        inp.dispatchEvent(new Event("input", {bubbles: true}));
        inp.dispatchEvent(new Event("change", {bubbles: true}));
        inp.dispatchEvent(new Event("blur", {bubbles: true}));
        inp.dispatchEvent(new Event("keyup", {bubbles: true}));
        if(window.jQuery){ window.jQuery(inp).val(val).trigger("input").trigger("change").trigger("blur"); }
        count++;
      }
    }
  });
  alert("Alhamdulillah! Berhasil mengisi " + count + " nilai siswa ke tabel SidikMu.");
})();''';

    Clipboard.setData(ClipboardData(text: script));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Skrip Auto-Fill disalin! Buka web SidikMu -> Tekan F12 -> Console -> Tempel (Paste) & Enter.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _downloadSidikmuExcel() async {
    final records = <Map<String, dynamic>>[];
    widget.studentGradesByNis.forEach((nis, score) {
      records.add({
        'nis': nis.trim(),
        'name': widget.studentNamesByNis[nis] ?? '-',
        'score': score != null ? ((score % 1 == 0) ? score.toInt() : score) : '',
      });
    });

    final excelBytes = ExcelService.generateSidikmuExcel(
      sheetTitle: 'Nilai_${widget.targetClassName}',
      records: records,
    );

    final cleanClass = widget.targetClassName.replaceAll(RegExp(r'[^\w\s\-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');
    final fileName = 'Nilai_SidikMu_$cleanClass.xlsx';

    await ExcelService.downloadExcel(
      bytes: excelBytes,
      fileName: fileName,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.download_done_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'File Excel berhasil diunduh! Klik tombol "Import Excel" di portal SidikMu.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0284C7),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _copyTsvGrades() {
    final sb = StringBuffer('NIS\tNama Siswa\tNilai\n');
    widget.studentGradesByNis.forEach((nis, score) {
      final name = widget.studentNamesByNis[nis] ?? '-';
      final val = score == null ? '-' : (score % 1 == 0 ? score.toInt().toString() : score.toString());
      sb.writeln('$nis\t$name\t$val');
    });

    Clipboard.setData(ClipboardData(text: sb.toString()));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Format kolom NIS & Nilai berhasil disalin! Siap ditempel ke Excel atau lembar kerja.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0284C7),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _openSidikmu() {
    launchUrl(
      Uri.parse('https://smpm12gkb.sidikmu.com'),
      mode: LaunchMode.externalApplication,
    );
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

    final inputUrl = _directUrlCtrl.text.trim();
    final sidikmuUrl = inputUrl.isNotEmpty
        ? inputUrl
        : (teacher?.sidikmuUrl ?? SidikmuService.defaultUrl);
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
            if (_webController != null)
              Positioned(
                left: -4000,
                top: -4000,
                width: 1280,
                height: 800,
                child: IgnorePointer(
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

        // Tautan Langsung Halaman Nilai SidikMu (Opsional)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.link_rounded, size: 18, color: Color(0xFF0284C7)),
                  const SizedBox(width: 8),
                  Text(
                    'Tautan Langsung Tabel SidikMu (Opsional)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Jika tabel nilai sudah dibuka di browser (seperti di gambar Anda), tempelkan link URL-nya di sini agar aplikasi langsung mendeteksi tabel:',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _directUrlCtrl,
                decoration: InputDecoration(
                  hintText: 'Contoh: smpm12gkb.sidikmu.com/index.php?EhZE6wa...',
                  hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    tooltip: 'Tempel dari Clipboard',
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        setState(() => _directUrlCtrl.text = data!.text!.trim());
                      }
                    },
                  ),
                ),
                style: const TextStyle(fontSize: 12),
              ),
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
                          'Mode Automasi Latar Belakang (Android)',
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
                      'Akun SidikMu terhubung: ${teacher?.sidikmuUsername}. Sistem akan otomatis login, membuka formulir kelas, mengisi nilai $totalStudents siswa, dan menyimpannya di latar belakang tanpa membuka browser.',
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

        // Web Quick Helper Banner
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
                    const Icon(Icons.flash_on_rounded, size: 20, color: Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    Text(
                      'Mode Web Browser (Auto-Fill Siap)',
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
                  'Salin skrip Auto-Fill atau salin rekap nilai untuk mengisi formulir nilai di portal SidikMu secara instan.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _copyAutoFillScript,
                        icon: const Icon(Icons.flash_on_rounded, size: 16),
                        label: const Text('Salin Skrip Auto-Fill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _copyTsvGrades,
                      icon: const Icon(Icons.table_chart_outlined, size: 16),
                      label: const Text('Salin Format Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0284C7),
                        side: const BorderSide(color: Color(0xFFBAE6FD)),
                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
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
              Icon(!kIsWeb ? Icons.smart_toy_rounded : Icons.play_arrow_rounded, size: 22),
              const SizedBox(width: 8),
              Text(
                !kIsWeb
                    ? '🚀 Mulai Sinkronisasi Otomatis 100%'
                    : 'Mulai Sinkronisasi Sekarang',
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

          // Auto-Fill Action Card (Sangat praktis untuk Web & Desktop)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFF0F9FF), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 20, color: Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    Text(
                      'Pilihan Input Cepat ke SidikMu',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0369A1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Tombol Utama: Salin Skrip Auto-Fill
                ElevatedButton.icon(
                  onPressed: _copyAutoFillScript,
                  icon: const Icon(Icons.flash_on_rounded, size: 18),
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '⚡ Salin Skrip Auto-Fill SidikMu',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '1-Klik isi seluruh nilai otomatis di formulir SidikMu',
                        style: TextStyle(fontSize: 10, color: Colors.white.withAlpha(220)),
                      ),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 8),

                // Tombol Sekunder: Unduh Excel & Buka Web
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _downloadSidikmuExcel,
                        icon: const Icon(Icons.file_download_outlined, size: 16),
                        label: const Text(
                          'Unduh Excel SidikMu',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openSidikmu,
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text(
                          'Buka Web SidikMu',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0284C7),
                          side: const BorderSide(color: Color(0xFFBAE6FD)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Petunjuk Ringkas Cara Otomatis
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 2 Pilihan Pengisian Otomatis ke SidikMu:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '1. Cara Paling Praktis (Import Excel SidikMu):\n'
                  '   • Klik "Unduh Excel SidikMu" di atas.\n'
                  '   • Di web SidikMu, klik tombol biru "Import Excel" di atas tabel -> Pilih file yang baru diunduh. Nilai langsung masuk otomatis 100%!\n\n'
                  '2. Cara Skrip Auto-Fill:\n'
                  '   • Klik "Salin Skrip Auto-Fill".\n'
                  '   • Di web SidikMu, tekan tombol F12 (atau klik kanan -> Inspect -> tab Console).\n'
                  '   • Tempel (Paste) lalu tekan Enter.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    height: 1.4,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

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

          // Link Download Aplikasi Android
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
                      'Gunakan Aplikasi Android untuk sinkronisasi otomatis 100%',
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

          // Tombol Tutup / Selesai
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              'Tutup Dialog',
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
