import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/exam_model.dart';
import '../../../core/models/question_model.dart';
import '../../../core/services/anti_cheat_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/smart_math_text.dart';
import '../../home/widgets/badge_share_dialog.dart';

class ExamTakingScreen extends StatefulWidget {
  final ExamModel exam;

  const ExamTakingScreen({super.key, required this.exam});

  @override
  State<ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends State<ExamTakingScreen> {
  late ExamSessionModel _session;
  int _currentIndex = 0;
  final Map<String, dynamic> _localAnswers = {};
  // Keyed essay controllers — prevent RTL bug from recreating controller on every build
  final Map<String, TextEditingController> _essayControllers = {};
  bool _isInit = false;
  bool _isLoadingQuestions = true;

  // ─── Countdown Timer ───
  Timer? _countdownTimer;
  late int _remainingSeconds; // in seconds

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final fb = context.read<FirebaseService>();
      final currentUser = fb.currentUser!;
      _session = fb.getOrCreateExamSession(examId: widget.exam.id, student: currentUser);
      _localAnswers.addAll(_session.answers);
      _currentIndex = _session.currentQuestionIndex;

      fb.loadQuestionsForExam(widget.exam).then((_) {
        if (mounted) {
          setState(() => _isLoadingQuestions = false);
        }
      });

      // ─── Init countdown timer with recovery support ───
      final totalExamSeconds = widget.exam.durationMinutes * 60;
      final elapsedSeconds = DateTime.now().difference(_session.startedAt).inSeconds;
      _remainingSeconds = (totalExamSeconds - elapsedSeconds).clamp(0, totalExamSeconds);

      final isTimeOver = _remainingSeconds <= 0;
      final isScheduleExpired = widget.exam.endTime != null && DateTime.now().isAfter(widget.exam.endTime!);

      // Jika ujian sudah selesai, waktu pengerjaan habis, atau jadwal telah lewat:
      if (_session.isCompleted || isTimeOver || isScheduleExpired) {
        _isInit = true;
        if (!_session.isCompleted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final fb = context.read<FirebaseService>();
              fb.finishExam(_session.id);
              AntiCheatService().stopLockdown();
              _showExamResultDialog(fb, isAutoSubmitted: true);
            }
          });
        }
        return;
      }

      // Beri notifikasi jika ini adalah sesi lanjutan setelah reboot / pemulihan
      if (_localAnswers.isNotEmpty || elapsedSeconds > 10) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppSnackBar.info(
            context,
            'Sesi ujian berhasil dipulihkan. Jawaban Anda tersimpan, silakan lanjutkan pengerjaan.',
          );
        });
      }

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds <= 0) {
          timer.cancel();
          // Auto-finish when time runs out
          if (mounted) {
            final fb = context.read<FirebaseService>();
            fb.finishExam(_session.id);
            AntiCheatService().stopLockdown();
            _showExamResultDialog(fb, isAutoSubmitted: true);
          }
        } else {
          if (mounted) setState(() => _remainingSeconds--);
        }
      });

      // Start Anti-Cheat Zero-Tolerance Lockdown if enabled and not exempted for this student
      if (widget.exam.antiCheatEnabled && !_session.antiCheatDisabledForStudent) {
        AntiCheatService().startLockdown(
          onViolation: (reason, {bool instantLock = false}) {
            fb.reportExamViolation(
              sessionId: _session.id,
              reason: reason,
              instantLock: instantLock,
            );
          },
        );
      }
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    AntiCheatService().stopLockdown();
    for (final c in _essayControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Format seconds → MM:SS
  String get _timerLabel {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// True when less than 5 minutes left
  bool get _isUrgent => _remainingSeconds <= 300;
  bool get _isCritical => _remainingSeconds <= 60;

  void _saveCurrentAnswer(String questionId, dynamic answer) {
    if (_session.isCompleted) return;
    setState(() {
      _localAnswers[questionId] = answer;
    });

    final fb = context.read<FirebaseService>();
    fb.saveExamAnswer(
      sessionId: _session.id,
      questionId: questionId,
      answer: answer,
      nextQuestionIndex: _currentIndex,
    );
  }

  void _showExamResultDialog(FirebaseService fb, {bool isAutoSubmitted = false}) {
    final updatedSession = fb.examSessions.firstWhere(
      (s) => s.id == _session.id,
      orElse: () => _session,
    );
    final exam = widget.exam;
    final examQuestions = fb.questions.where((q) => exam.questionIds.contains(q.id)).toList();
    final essayQuestions = examQuestions.where((q) => q.type == QuestionType.essay).toList();
    final hasEssay = essayQuestions.isNotEmpty;
    final nonEssayQuestions = examQuestions.where((q) => q.type != QuestionType.essay).toList();
    final nonEssayScore = updatedSession.nonEssayScore ?? 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasEssay
                        ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                        : [const Color(0xFF10B981), const Color(0xFF059669)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (hasEssay ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withAlpha(80),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  hasEssay ? Icons.hourglass_top_rounded : Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasEssay ? 'Ujian Berhasil Dikumpulkan!' : 'Hasil Ujian Langsung Keluar! 🎉',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              if (isAutoSubmitted)
                const Text(
                  '⏰ Waktu ujian habis. Jawaban telah tersimpan dan dinilai.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                )
              else
                Text(
                  exam.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              const SizedBox(height: 16),

              // Score Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                decoration: BoxDecoration(
                  color: hasEssay ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasEssay ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      hasEssay ? 'NILAI SEMENTARA (SOAL OBJEKTIF)' : 'NILAI AKHIR ANDA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: hasEssay ? const Color(0xFFB45309) : const Color(0xFF047857),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${nonEssayScore.round()}',
                          style: GoogleFonts.outfit(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: hasEssay ? const Color(0xFFB45309) : const Color(0xFF047857),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '/ 100',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    if (nonEssayQuestions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Dinilai otomatis dari ${nonEssayQuestions.length} butir soal objektif',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: hasEssay ? const Color(0xFF92400E) : const Color(0xFF065F46),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Essay Note if applicable
              if (hasEssay)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Terdapat ${essayQuestions.length} butir soal esai yang menunggu koreksi guru. Guru akan memberi nilai (1-5 per nomor) yang diakumulasikan ke nilai akhir.',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
              // Gamification +40 Poin Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF59E0B).withAlpha(80)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 16),
                    SizedBox(width: 6),
                    Text(
                      '+40 Poin Gamifikasi Didapatkan! 🌟',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogCtx); // close result dialog
                    final user = fb.currentUser;
                    if (user != null && user.isSiswa && mounted) {
                      final updatedBadges = fb.getStudentBadges(user);
                      await BadgeShareDialog.checkAndShowNewBadges(
                        context: context,
                        badges: updatedBadges,
                        student: user,
                      );
                    }
                    if (!mounted) return;
                    Navigator.pop(context); // return to exams screen
                  },
                  child: const Text('Kembali ke Daftar Ujian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _finishExam() {
    showDialog(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        title: const Text('Konfirmasi Selesai Ujian'),
        content: const Text(
          'Apakah Anda yakin ingin menyelesaikan ujian ini sekarang? Seluruh jawaban Anda akan dinilai langsung oleh sistem.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(confirmCtx), child: const Text('Periksa Kembali')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            onPressed: () {
              Navigator.pop(confirmCtx);
              final fb = context.read<FirebaseService>();
              fb.finishExam(_session.id);
              AntiCheatService().stopLockdown();
              _showExamResultDialog(fb);
            },
            child: const Text('Ya, Selesai Ujian'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    // Re-fetch latest session state (to detect lock / unblock in real-time)
    final liveSession = fb.examSessions.firstWhere(
      (s) => s.id == _session.id,
      orElse: () => _session,
    );

    final totalExamSeconds = widget.exam.durationMinutes * 60;
    final elapsedSeconds = DateTime.now().difference(_session.startedAt).inSeconds;
    final isTimeOver = elapsedSeconds >= totalExamSeconds;
    final isScheduleExpired = widget.exam.endTime != null && DateTime.now().isAfter(widget.exam.endTime!);
    final isClosedOrCompleted = liveSession.isCompleted || isTimeOver || isScheduleExpired;

    // ================= ALREADY COMPLETED OR TIME EXPIRED SCREEN =================
    if (isClosedOrCompleted) {
      if (!liveSession.isCompleted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          fb.finishExam(_session.id);
        });
      }
      final exam = widget.exam;
      final examQuestions = fb.questions.where((q) => exam.questionIds.contains(q.id)).toList();
      final essayQuestions = examQuestions.where((q) => q.type == QuestionType.essay).toList();
      final hasEssay = essayQuestions.isNotEmpty;
      final isGraded = !hasEssay || (liveSession.essayScores.length >= essayQuestions.length);
      final finalScore = liveSession.finalScore ?? liveSession.nonEssayScore;
      final isTimeOutReason = isTimeOver || isScheduleExpired;

      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          title: Text(exam.title),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isTimeOutReason && !liveSession.isCompleted
                              ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                              : [const Color(0xFF10B981), const Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isTimeOutReason && !liveSession.isCompleted
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981))
                                .withAlpha(80),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        isTimeOutReason && !liveSession.isCompleted
                            ? Icons.timer_off_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isTimeOutReason && !liveSession.isCompleted
                          ? 'Waktu Pengerjaan Habis! ⏰'
                          : 'Ujian Telah Selesai Dikerjakan! 🎉',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isTimeOutReason
                          ? 'Waktu pengerjaan ujian "${exam.title}" telah habis. Jawaban Anda telah otomatis dikumpulkan dan dinilai oleh sistem.'
                          : 'Anda sudah menyelesaikan ujian "${exam.title}". Nilai Anda telah tercatat dan ujian tidak dapat dikerjakan ulang.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Nilai Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'NILAI YANG DIPEROLEH',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF047857), letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${finalScore?.round() ?? 0}',
                                style: GoogleFonts.outfit(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF047857),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '/ 100',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          if (hasEssay && !isGraded) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '⏳ Menunggu koreksi jawaban esai oleh guru',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Warning: cannot retake
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.lock_clock_rounded, size: 18, color: Color(0xFF1D4ED8)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Ujian yang sudah dikerjakan tidak dapat diulang kembali.',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Kembali ke Menu Ujian'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ================= ZERO-TOLERANCE LOCK SCREEN =================
    if (liveSession.isLocked) {
      return Scaffold(
        backgroundColor: const Color(0xFF7F1D1D), // Dark Red
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(100),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.lock_rounded, size: 72, color: Colors.white),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'AKSES UJIAN TERKUNCI! 🚨',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Penyebab: ${liveSession.lastViolationReason ?? "Terdeteksi perpindahan aplikasi atau interupsi layar"}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Sistem Zero-Tolerance Anti-Cheat telah mengunci lembar ujian Anda dan mengirimkan peringatan ke Pengawas/Guru. Silakan hubungi Guru Anda untuk membuka blokir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Menunggu tindakan Guru (Unblock)...',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ================= NORMAL EXAM TAKING INTERFACE =================
    final rawExamQuestions = fb.questions.where((q) => widget.exam.questionIds.contains(q.id)).toList();
    if (rawExamQuestions.isEmpty) {
      if (_isLoadingQuestions) {
        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            title: Text(widget.exam.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            elevation: 0,
          ),
          body: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Menyiapkan lembar soal ujian...',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text(widget.exam.title)),
        body: const Center(child: Text('Tidak ada butir soal pada ujian ini.')),
      );
    }

    // Acak urutan butir soal khusus per akun siswa agar tidak bisa saling contekan berdasarkan nomor
    final questionMap = {for (var q in rawExamQuestions) q.id: q};
    final currentUser = fb.currentUser;
    final orderedIds = liveSession.orderedQuestionIds.isNotEmpty
        ? liveSession.orderedQuestionIds
        : (List<String>.from(widget.exam.questionIds)
          ..shuffle(Random('${widget.exam.id}_${currentUser?.id ?? ""}'.hashCode)));

    final List<QuestionModel> examQuestions = [];
    for (final qId in orderedIds) {
      if (questionMap.containsKey(qId)) {
        examQuestions.add(questionMap[qId]!);
      }
    }
    for (final q in rawExamQuestions) {
      if (!examQuestions.contains(q)) {
        examQuestions.add(q);
      }
    }

    if (_currentIndex >= examQuestions.length) {
      _currentIndex = examQuestions.length - 1;
    }
    if (_currentIndex < 0) {
      _currentIndex = 0;
    }

    final currentQuestion = examQuestions[_currentIndex];
    final currentAnswer = _localAnswers[currentQuestion.id];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildExamAppBar(examQuestions.length),
      bottomNavigationBar: _buildExamBottomNav(examQuestions),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Index Grid
            _buildQuestionGrid(examQuestions),
            const SizedBox(height: 24),

            // Question Card + Answer Controls
            _buildQuestionCard(currentQuestion),
            const SizedBox(height: 24),
            _buildAnswerControls(currentQuestion, currentAnswer),
          ],
        ),
      ),
    );
  }

  // ─── PREMIUM APPBAR ─────────────────────────────────────────────────────────
  PreferredSizeWidget _buildExamAppBar(int totalQuestions) {
    final progress = totalQuestions > 0 ? (_currentIndex + 1) / totalQuestions : 0.0;
    final answeredCount = _localAnswers.length;

    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    // Anti-cheat badge
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: widget.exam.antiCheatEnabled
                            ? AppColors.rose.withAlpha(40)
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.exam.antiCheatEnabled
                            ? Icons.security_rounded
                            : Icons.shield_outlined,
                        color: widget.exam.antiCheatEnabled
                            ? AppColors.rose
                            : Colors.white54,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.exam.title,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Terjawab: $answeredCount/$totalQuestions soal',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Timer chip
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _isCritical
                            ? AppColors.rose.withAlpha(60)
                            : (_isUrgent
                                ? AppColors.amber.withAlpha(40)
                                : Colors.white12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isCritical
                              ? AppColors.rose
                              : (_isUrgent ? AppColors.amber : Colors.white24),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isCritical
                                ? Icons.timer_off_rounded
                                : Icons.timer_outlined,
                            size: 15,
                            color: _isCritical
                                ? AppColors.rose
                                : (_isUrgent ? AppColors.amber : Colors.white),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _timerLabel,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: _isCritical
                                  ? AppColors.rose
                                  : (_isUrgent ? AppColors.amber : Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Progress bar
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isCritical
                      ? AppColors.rose
                      : (_isUrgent ? AppColors.amber : AppColors.primaryLight),
                ),
                minHeight: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── BOTTOM NAV ─────────────────────────────────────────────────────────────
  Widget _buildExamBottomNav(List<dynamic> examQuestions) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        children: [
          // Previous button
          _navButton(
            icon: Icons.arrow_back_ios_rounded,
            label: 'Sebelum',
            onTap: _currentIndex > 0
                ? () => setState(() => _currentIndex--)
                : null,
            isPrimary: false,
          ),
          // Center: soal indicator
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Soal ${_currentIndex + 1}',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  'dari ${examQuestions.length} soal',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          // Next / Finish button
          if (_currentIndex < examQuestions.length - 1)
            _navButton(
              icon: Icons.arrow_forward_ios_rounded,
              label: 'Lanjut',
              onTap: () => setState(() => _currentIndex++),
              isPrimary: true,
            )
          else
            _navButton(
              icon: Icons.check_circle_rounded,
              label: 'Selesai',
              onTap: _finishExam,
              isPrimary: true,
              isFinish: true,
            ),
        ],
      ),
    );
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isPrimary,
    bool isFinish = false,
  }) {
    final color = isFinish ? AppColors.orange : AppColors.navy;
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: isPrimary && !isDisabled
              ? LinearGradient(
                  colors: isFinish
                      ? [AppColors.orangeDark, AppColors.orange]
                      : [AppColors.navyMid, AppColors.navy],
                )
              : null,
          color: isPrimary ? null : (isDisabled ? Colors.grey.shade100 : AppColors.backgroundLight),
          borderRadius: BorderRadius.circular(14),
          border: isPrimary
              ? null
              : Border.all(
                  color: isDisabled ? Colors.grey.shade200 : AppColors.borderLight,
                ),
          boxShadow: isPrimary && !isDisabled
              ? [
                  BoxShadow(
                    color: color.withAlpha(60),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isPrimary) ...[Icon(icon, size: 16, color: isDisabled ? Colors.grey.shade300 : AppColors.textSecondaryLight), const SizedBox(width: 6)],
            Text(
              label,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isPrimary
                    ? (isDisabled ? Colors.grey : Colors.white)
                    : (isDisabled ? Colors.grey.shade300 : AppColors.textSecondaryLight),
              ),
            ),
            if (isPrimary) ...[const SizedBox(width: 6), Icon(icon, size: 16, color: isDisabled ? Colors.grey : Colors.white)],
          ],
        ),
      ),
    );
  }

  // ─── QUESTION GRID ──────────────────────────────────────────────────────────
  Widget _buildQuestionGrid(List<dynamic> examQuestions) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: examQuestions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final qId = examQuestions[idx].id;
          final isAnswered = _localAnswers.containsKey(qId);
          final isSelected = _currentIndex == idx;

          return InkWell(
            onTap: () => setState(() => _currentIndex = idx),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.orange
                    : (isAnswered ? AppColors.navy.withAlpha(20) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppColors.orange
                      : (isAnswered ? AppColors.navy : Colors.grey.shade300),
                ),
              ),
              child: Text(
                '${idx + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (isAnswered ? AppColors.navy : Colors.black87),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── QUESTION CARD ──────────────────────────────────────────────────────────
  Widget _buildQuestionCard(QuestionModel currentQuestion) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Soal Nomor ${_currentIndex + 1} · ${currentQuestion.type.label}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              if (currentQuestion.type == QuestionType.essay) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Skor maks: ${currentQuestion.maxEssayScore}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          SmartMathText(
            text: currentQuestion.content,
            style: const TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.w600),
          ),

          // Math equation render — MS Word style display block (if not already in content)
          if (currentQuestion.equationLatex != null &&
              !currentQuestion.content.contains(currentQuestion.equationLatex!.replaceAll(r'$', ''))) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "Formula" badge like MS Word equation block
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.functions, size: 11, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Formula',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SmartMathText(
                        text: currentQuestion.equationLatex!,
                        style: const TextStyle(
                          fontSize: 22,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Question Image if available
          if (currentQuestion.hasImage && currentQuestion.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                currentQuestion.imageUrls.first,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 120,
                  color: Colors.grey.shade200,
                  child: const Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerControls(QuestionModel question, dynamic currentAnswer) {
    if (question.type == QuestionType.single) {
      return RadioGroup<String>(
        groupValue: currentAnswer as String?,
        onChanged: (val) => _saveCurrentAnswer(question.id, val),
        child: Column(
          children: question.options.map((opt) {
            final isSelected = currentAnswer == opt.id;
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withAlpha(15) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.borderLight,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: RadioListTile<String>(
                value: opt.id,
                title: Row(
                  children: [
                    Text('${opt.id}. ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: SmartMathText(text: opt.text)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );
    } else if (question.type == QuestionType.multi) {
      final selectedList = List<String>.from(currentAnswer as List? ?? []);
      return Column(
        children: question.options.map((opt) {
          final isChecked = selectedList.contains(opt.id);
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isChecked ? AppColors.primary.withAlpha(15) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isChecked ? AppColors.primary : AppColors.borderLight,
                width: isChecked ? 2 : 1,
              ),
            ),
            child: CheckboxListTile(
              value: isChecked,
              onChanged: (checked) {
                if (checked == true) {
                  selectedList.add(opt.id);
                } else {
                  selectedList.remove(opt.id);
                }
                _saveCurrentAnswer(question.id, selectedList);
              },
              title: Row(
                children: [
                  Text('${opt.id}. ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: SmartMathText(text: opt.text)),
                ],
              ),
            ),
          );
        }).toList(),
      );
    } else if (question.type == QuestionType.trueFalse) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: currentAnswer == true ? AppColors.navy : Colors.white,
                foregroundColor: currentAnswer == true ? Colors.white : Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: currentAnswer == true ? AppColors.navy : Colors.grey.shade300),
                elevation: currentAnswer == true ? 3 : 0,
              ),
              onPressed: () => _saveCurrentAnswer(question.id, true),
              child: const Text('BENAR', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: currentAnswer == false ? AppColors.orange : Colors.white,
                foregroundColor: currentAnswer == false ? Colors.white : Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: currentAnswer == false ? AppColors.orange : Colors.grey.shade300),
                elevation: currentAnswer == false ? 3 : 0,
              ),
              onPressed: () => _saveCurrentAnswer(question.id, false),
              child: const Text('SALAH', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    } else if (question.type == QuestionType.matching) {
      // Build a shuffled list of right-side options for the dropdowns
      final rightOptions = question.options.map((o) => o.matchingKey ?? '').where((k) => k.isNotEmpty).toList();
      // Current answer: Map<String, String> — { optionId: selectedMatchingKey }
      final answerMap = Map<String, String>.from(
        (currentAnswer as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {},
      );

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Pasangkan pernyataan dengan jawaban yang tepat:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih jawaban dari dropdown di setiap baris.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const Divider(height: 20),
            ...question.options.asMap().entries.map((entry) {
              final idx = entry.key;
              final opt = entry.value;
              final selectedKey = answerMap[opt.id];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: selectedKey != null ? AppColors.primary.withAlpha(8) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedKey != null ? AppColors.primary.withAlpha(80) : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Prompt (kiri) ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              opt.text,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Divider ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          const Icon(Icons.subdirectory_arrow_right_rounded,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Pasangkan dengan:',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // ── Dropdown full-width ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: DropdownButtonHideUnderline(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selectedKey != null
                                  ? AppColors.primary
                                  : Colors.grey.shade300,
                              width: selectedKey != null ? 1.5 : 1,
                            ),
                            boxShadow: selectedKey != null
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withAlpha(20),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: DropdownButton<String>(
                            value: selectedKey,
                            isExpanded: true,
                            hint: Row(
                              children: [
                                Icon(Icons.touch_app_rounded,
                                    size: 14, color: Colors.grey.shade400),
                                const SizedBox(width: 6),
                                Text(
                                  'Pilih jawaban yang tepat...',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: selectedKey != null
                                  ? AppColors.primary
                                  : Colors.grey.shade400,
                            ),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            items: rightOptions.map((key) {
                              return DropdownMenuItem<String>(
                                value: key,
                                child: Text(
                                  key,
                                  softWrap: true,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              );
                            }).toList(),
                            selectedItemBuilder: (context) => rightOptions.map((key) {
                              return Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      size: 15, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      key,
                                      overflow: TextOverflow.visible,
                                      softWrap: true,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                            onChanged: (val) {
                              final updated = Map<String, String>.from(answerMap);
                              if (val == null) {
                                updated.remove(opt.id);
                              } else {
                                updated[opt.id] = val;
                              }
                              _saveCurrentAnswer(question.id, updated);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            if (answerMap.length == question.options.length)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.navy.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.navy.withAlpha(35)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.navy, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Semua pasangan sudah diisi!',
                      style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    } else if (question.type == QuestionType.essay) {
      // Use a persistent controller to prevent RTL / cursor-jumping bug
      final controller = _essayControllers.putIfAbsent(
        question.id,
        () => TextEditingController(text: currentAnswer as String? ?? ''),
      );
      // Sync controller text if answer changed externally (e.g. session restore)
      if (controller.text != (currentAnswer as String? ?? '')) {
        controller.text = currentAnswer?.toString() ?? '';
        controller.selection = TextSelection.collapsed(offset: controller.text.length);
      }
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Jawaban Esai Anda (Penilaian Guru 1–5):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              onChanged: (val) => _saveCurrentAnswer(question.id, val),
              decoration: InputDecoration(
                hintText: 'Tuliskan argumen atau penjelasan lengkap Anda di sini...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                alignLabelWithHint: true,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(currentAnswer?.toString() ?? '').length} karakter',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox();
  }
}
