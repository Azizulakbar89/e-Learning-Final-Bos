import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/curriculum_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/responsive_layout.dart';

class PointRedemptionScreen extends StatefulWidget {
  const PointRedemptionScreen({super.key});

  @override
  State<PointRedemptionScreen> createState() => _PointRedemptionScreenState();
}

class _PointRedemptionScreenState extends State<PointRedemptionScreen> {
  String? _selectedSubjectId;
  int _pointsToRedeem = 500;

  Future<void> _handleRedeem() async {
    final fb = context.read<FirebaseService>();
    final currentUser = fb.currentUser;
    if (currentUser == null) return;

    final subjects = fb.subjects;
    if (subjects.isEmpty) return;

    final subjectId = _selectedSubjectId ?? subjects.first.id;
    final subject = subjects.firstWhere((s) => s.id == subjectId, orElse: () => subjects.first);

    await showLoadingDialog(
      context,
      message: 'Menukarkan $_pointsToRedeem poin gamifikasi...',
      action: () async {
        await fb.redeemPointsForGrade(
          studentId: currentUser.id,
          subjectId: subject.id,
          subjectName: subject.name,
          pointsToSpend: _pointsToRedeem,
        );
      },
      successMessage:
          'Berhasil menukarkan $_pointsToRedeem Poin menjadi bonus nilai +${(_pointsToRedeem / 500).toInt()}.0 pada ${subject.name}!',
      errorMessage: 'Gagal menukarkan poin. Pastikan poin mencukupi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final currentUser = fb.currentUser;
    final totalPoints = currentUser?.totalPoints ?? 0;
    final subjects = fb.subjects;
    final transactions = fb.pointTransactions.where((t) => t.studentId == currentUser?.id).toList();

    // Default selected subject
    if ((_selectedSubjectId == null || !subjects.any((s) => s.id == _selectedSubjectId)) && subjects.isNotEmpty) {
      _selectedSubjectId = subjects.first.id;
    }

    final activeSubject = subjects.where((s) => s.id == _selectedSubjectId).firstOrNull ??
        (subjects.isNotEmpty ? subjects.first : null);

    // Current subject redeemed bonus & remaining cap
    final currentSubjectBonus = (currentUser != null && activeSubject != null)
        ? fb.getSubjectRedeemedBonus(currentUser.id, activeSubject.id, activeSubject.name)
        : 0.0;
    const maxBonusCap = 5.0;
    final remainingBonusCap = (maxBonusCap - currentSubjectBonus).clamp(0.0, maxBonusCap);
    final maxPointsAllowedByCap = (remainingBonusCap * 500).toInt();

    // Calculate max redeemable points given user's balance and subject cap
    final maxSpendablePoints = (totalPoints < maxPointsAllowedByCap ? totalPoints : maxPointsAllowedByCap);
    final normalizedMax = (maxSpendablePoints >= 500) ? (maxSpendablePoints ~/ 500) * 500 : 500;

    // Constrain points to redeem
    if (_pointsToRedeem > normalizedMax && normalizedMax >= 500) {
      _pointsToRedeem = normalizedMax;
    } else if (_pointsToRedeem < 500) {
      _pointsToRedeem = 500;
    }

    // Look up current subject grade
    final subjectGrades = currentUser != null ? fb.getStudentSubjectGrades(currentUser) : <StudentSubjectGrade>[];
    final currentSubjectGradeObj = subjectGrades.where((g) => g.subject.id == activeSubject?.id).firstOrNull;
    final currentGradeVal = currentSubjectGradeObj?.finalGrade;

    final bonusToAdd = (_pointsToRedeem / 500).floor() * 1.0;
    final projectedGrade = currentGradeVal != null
        ? (currentGradeVal + bonusToAdd).clamp(0.0, 100.0)
        : null;

    final canRedeem = totalPoints >= 500 && remainingBonusCap >= 1.0 && _pointsToRedeem <= totalPoints;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Gamifikasi & Tukar Poin',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        elevation: 0,
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      body: ResponsiveFormWrapper(
        maxWidth: 800,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. HERO POINTS BALANCE CARD ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.navyGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(90),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withAlpha(50)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.military_tech_rounded, color: Colors.amberAccent, size: 16),
                            SizedBox(width: 4),
                            Text('Saldo Gamifikasi', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Aktif Belajar', style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text('🌟', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 8),
                      Text(
                        '$totalPoints',
                        style: GoogleFonts.outfit(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Poin',
                        style: GoogleFonts.outfit(
                          color: Colors.white.withAlpha(200),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Learning earning sources pills
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(35),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cara Cepat Kumpulkan Poin dari Belajar:',
                          style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: const [
                            _EarningPill(label: '📖 Baca Modul (+20)'),
                            _EarningPill(label: '🎯 Kuis/Ujian (+10 s/d +50)'),
                            _EarningPill(label: '💯 Skor 100 (+20 Bonus)'),
                            _EarningPill(label: '🔥 Streak Harian (+20)'),
                            _EarningPill(label: '💻 Praktikum IDE (+15)'),
                            _EarningPill(label: '📝 Kumpul Tugas (+50)'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── 2. ANTI-INFLATION POLICY BANNER ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF93C5FD)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Kebijakan Anti-Inflasi Nilai Akademik',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tiap 500 Poin = +1.0 Nilai. Maksimal bonus adalah +5.0 Nilai per mata pelajaran agar nilai rapor tetap seimbang, adil, dan objektif.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── 3. REDEEM CARD ──
            Text(
              'Tukarkan Poin ke Nilai Rapor',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(6),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject selector
                  const Text('Pilih Mata Pelajaran Tujuan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedSubjectId,
                        items: subjects.map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Row(
                            children: [
                              const Icon(Icons.book_rounded, color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedSubjectId = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subject Status Preview (Current vs Redeemed vs Projected)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blueGrey.shade100),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Bonus Saat Ini di Mapel Ini:',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: currentSubjectBonus >= maxBonusCap ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '+${currentSubjectBonus.toStringAsFixed(1)} / +${maxBonusCap.toStringAsFixed(1)} Max',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: currentSubjectBonus >= maxBonusCap ? AppColors.rose : AppColors.emerald,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sisa Kuota Bonus Tersedia:',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                            ),
                            Text(
                              '+${remainingBonusCap.toStringAsFixed(1)} Nilai',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                        if (currentGradeVal != null) ...[
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Proyeksi Nilai Akhir:',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                              ),
                              Row(
                                children: [
                                  Text(
                                    currentGradeVal.toStringAsFixed(1),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.emerald),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${projectedGrade?.toStringAsFixed(1)} (+${bonusToAdd.toStringAsFixed(1)})',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.emerald),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Points Slider & Conversion
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Jumlah Poin Ditukar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.orange.withAlpha(80)),
                        ),
                        child: Text(
                          '$_pointsToRedeem Poin = +${(_pointsToRedeem / 500).toInt()}.0 Nilai',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.orangeDark, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _pointsToRedeem.toDouble().clamp(500.0, normalizedMax.toDouble()),
                    min: 500,
                    max: normalizedMax.toDouble(),
                    divisions: (normalizedMax > 500) ? (normalizedMax ~/ 500) : 1,
                    activeColor: AppColors.orange,
                    inactiveColor: Colors.grey.shade300,
                    onChanged: (canRedeem && normalizedMax > 500)
                        ? (val) => setState(() => _pointsToRedeem = (val ~/ 500) * 500)
                        : null,
                  ),

                  // Quick Preset Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [500, 1000, 1500, 2500].map((pts) {
                      final isCurrent = _pointsToRedeem == pts;
                      final isAffordable = totalPoints >= pts && (pts / 500) <= remainingBonusCap;
                      return ChoiceChip(
                        label: Text(
                          '+${(pts / 500).toInt()} Nilai ($pts pt)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCurrent
                                ? Colors.white
                                : (isAffordable ? AppColors.textPrimaryLight : Colors.grey.shade400),
                          ),
                        ),
                        selected: isCurrent,
                        selectedColor: AppColors.orange,
                        backgroundColor: Colors.grey.shade100,
                        onSelected: isAffordable
                            ? (_) => setState(() => _pointsToRedeem = pts)
                            : null,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canRedeem ? AppColors.orange : Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: canRedeem ? 3 : 0,
                        shadowColor: AppColors.orange.withAlpha(80),
                      ),
                      onPressed: canRedeem ? _handleRedeem : null,
                      icon: const Icon(Icons.swap_horizontal_circle_rounded, size: 18),
                      label: Text(
                        remainingBonusCap < 1.0
                            ? 'Batas Bonus Mapel Ini Telah Penuh (+5.0)'
                            : (totalPoints < 500
                                ? 'Minimal 500 Poin untuk Menukar'
                                : 'Tukarkan $_pointsToRedeem Poin Menjadi +${(_pointsToRedeem / 500).toInt()}.0 Nilai'),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 4. TRANSACTION HISTORY CARD ──
            Text(
              'Riwayat Perolehan & Penukaran Poin',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            if (transactions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history_toggle_off_rounded, size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      const Text(
                        'Belum ada riwayat poin.\nMulailah belajar dan membaca modul materi untuk meraih poin!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final t = transactions[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: t.isDebit ? Colors.red.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          t.isDebit ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded,
                          color: t.isDebit ? AppColors.rose : AppColors.emerald,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        t.reason,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${t.createdAt.day}/${t.createdAt.month}/${t.createdAt.year} ${t.createdAt.hour}:${t.createdAt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: t.isDebit ? AppColors.rose.withAlpha(20) : AppColors.emerald.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${t.isDebit ? "-" : "+"}${t.points}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: t.isDebit ? AppColors.rose : AppColors.emerald,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
  }
}

class _EarningPill extends StatelessWidget {
  final String label;
  const _EarningPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
