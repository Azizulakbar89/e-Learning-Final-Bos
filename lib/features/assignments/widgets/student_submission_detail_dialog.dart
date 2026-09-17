import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/assignment_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/url_helper.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../code_compiler/screens/code_playground_screen.dart';
import 'submission_image_viewer.dart';

class StudentSubmissionDetailDialog extends StatefulWidget {
  final AssignmentSubmissionModel submission;
  final AssignmentModel? assignment;
  final VoidCallback? onGraded;

  const StudentSubmissionDetailDialog({
    super.key,
    required this.submission,
    this.assignment,
    this.onGraded,
  });

  static Future<void> show(
    BuildContext context, {
    required AssignmentSubmissionModel submission,
    AssignmentModel? assignment,
    VoidCallback? onGraded,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => StudentSubmissionDetailDialog(
        submission: submission,
        assignment: assignment,
        onGraded: onGraded,
      ),
    );
  }

  @override
  State<StudentSubmissionDetailDialog> createState() => _StudentSubmissionDetailDialogState();
}

class _StudentSubmissionDetailDialogState extends State<StudentSubmissionDetailDialog> {
  late AssignmentSubmissionModel _sub;
  bool _isEditingGrade = false;
  late TextEditingController _scoreCtrl;
  late TextEditingController _feedbackCtrl;

  @override
  void initState() {
    super.initState();
    _sub = widget.submission;
    _scoreCtrl = TextEditingController(
      text: _sub.score != null ? _sub.score!.toStringAsFixed(0) : '',
    );
    _feedbackCtrl = TextEditingController(text: _sub.teacherFeedback ?? '');
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveGrade() async {
    final scoreVal = double.tryParse(_scoreCtrl.text.trim());
    if (scoreVal == null || scoreVal < 0 || scoreVal > 100) {
      AppSnackBar.error(context, 'Nilai harus berupa angka antara 0 sampai 100!');
      return;
    }

    final fb = context.read<FirebaseService>();
    final feedback = _feedbackCtrl.text.trim();

    final success = await showLoadingDialog(
      context,
      message: 'Menyimpan nilai tugas...',
      action: () async {
        await fb.gradeAssignmentSubmission(
          submissionId: _sub.id,
          score: scoreVal,
          feedback: feedback,
        );
      },
      successMessage: _sub.memberStudentIds.length > 1
          ? 'Nilai berhasil disimpan untuk seluruh anggota kelompok! 👥'
          : 'Nilai dan umpan balik berhasil disimpan!',
      errorMessage: 'Gagal menyimpan nilai.',
    );

    if (success && mounted) {
      setState(() {
        _sub = _sub.copyWith(
          score: scoreVal,
          teacherFeedback: feedback,
          gradedAt: DateTime.now(),
        );
        _isEditingGrade = false;
      });
      widget.onGraded?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final isGraded = _sub.score != null;

    // Resolve group members if any
    final List<UserModel> groupMembers = [];
    if (_sub.memberStudentIds.isNotEmpty) {
      for (final mid in _sub.memberStudentIds) {
        final st = fb.allStudents.where((u) => u.id == mid).firstOrNull;
        if (st != null && !groupMembers.any((m) => m.id == st.id)) {
          groupMembers.add(st);
        }
      }
    }

    final hasImages = _sub.imageUrls.isNotEmpty;
    final hasPdf = _sub.pdfUrl != null && _sub.pdfUrl!.trim().isNotEmpty;
    final hasLink = _sub.linkUrl != null && _sub.linkUrl!.trim().isNotEmpty;
    final hasText = _sub.textContent != null && _sub.textContent!.trim().isNotEmpty;
    final hasCode = _sub.sourceCode != null && _sub.sourceCode!.trim().isNotEmpty;

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 750 ? 700.0 : screenWidth * 0.94;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: maxHeight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── TOP HEADER ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assignment_turned_in_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.assignment?.title ?? 'Detail Jawaban Tugas Siswa',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Tipe Pengumpulan: ${_sub.type.label} • ${AppDateFormatter.formatFullDateTime(_sub.submittedAt)}',
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── SCROLLABLE CONTENT BODY ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. SUBMITTER & GROUP INFO CARD ──
                    _buildSubmitterCard(groupMembers),

                    const SizedBox(height: 18),

                    // ── 2. GRADING STATUS BANNER / FORM ──
                    _buildGradingSection(isGraded),

                    const SizedBox(height: 20),

                    // ── 3. SUBMISSION CONTENT SECTIONS ──
                    if (hasImages || hasLink || hasText || hasCode) ...[
                      Text(
                        'Lampiran & Berkas Jawaban Siswa',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    if (!hasImages && !hasPdf && !hasLink && !hasText && !hasCode)
                      Container(
                        padding: const EdgeInsets.all(20),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Center(
                          child: Text(
                            'Siswa tidak melampirkan berkas teks/file/gambar.',
                            style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13),
                          ),
                        ),
                      ),

                    // ── A. GAMBAR (IMAGES) ──
                    if (hasImages) ...[
                      _buildImagesSection(),
                      const SizedBox(height: 16),
                    ],

                    // ── C. TAUTAN / LINK ──
                    if (hasLink) ...[
                      _buildLinkSection(),
                      const SizedBox(height: 16),
                    ],

                    // ── D. TEKS BIASA / ESSAY ──
                    if (hasText) ...[
                      _buildTextSection(),
                      const SizedBox(height: 16),
                    ],

                    // ── E. KODE SUMBER (CODE) ──
                    if (hasCode) ...[
                      _buildCodeSection(),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),

            // ── BOTTOM ACTIONS ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ID: ${_sub.id.substring(0, _sub.id.length > 8 ? 8 : _sub.id.length)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF334155),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('Tutup', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SUBMITTER & GROUP CARD ──
  Widget _buildSubmitterCard(List<UserModel> groupMembers) {
    final isGroup = _sub.groupName != null || groupMembers.length > 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withAlpha(30),
                child: Text(
                  _sub.submitterName.isNotEmpty ? _sub.submitterName[0].toUpperCase() : 'S',
                  style: GoogleFonts.outfit(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sub.submitterName,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isGroup ? 'Ketua / Pengunggah Tugas' : 'Tugas Mandiri / Siswa Individu',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isGroup ? Colors.purple.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isGroup ? Colors.purple.shade200 : Colors.blue.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGroup ? Icons.group_rounded : Icons.person_rounded,
                      size: 14,
                      color: isGroup ? Colors.purple.shade700 : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isGroup ? (_sub.groupName ?? 'Kelompok') : 'Individu',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isGroup ? Colors.purple.shade700 : Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Group Members Chips
          if (isGroup && groupMembers.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 10),
            Text(
              'Anggota Kelompok (${groupMembers.length} Siswa):',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: groupMembers.map((m) {
                final isLeader = m.id == _sub.submitterId;
                return Chip(
                  avatar: Icon(
                    isLeader ? Icons.star_rounded : Icons.person_outline_rounded,
                    size: 14,
                    color: isLeader ? Colors.amber.shade800 : AppColors.primary,
                  ),
                  label: Text(
                    '${m.fullName}${m.nis != null ? " (${m.nis})" : ""}',
                    style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w500),
                  ),
                  backgroundColor: isLeader ? Colors.amber.shade50 : Colors.white,
                  side: BorderSide(
                    color: isLeader ? Colors.amber.shade300 : const Color(0xFFCBD5E1),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── GRADING SECTION ──
  Widget _buildGradingSection(bool isGraded) {
    if (_isEditingGrade) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Formulir Penilaian Guru',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: const Color(0xFF14532D),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _isEditingGrade = false),
                  child: const Text('Batal'),
                ),
              ],
            ),
            if (_sub.memberStudentIds.length > 1) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.group_rounded, size: 18, color: Colors.purple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Penilaian Tugas Kelompok: Nilai dan feedback otomatis diterapkan sama ke seluruh anggota kelompok (${_sub.memberStudentIds.length} Siswa).',
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.purple.shade900, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _scoreCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Nilai (0 - 100) *',
                hintText: 'Contoh: 88',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.grade_rounded, color: AppColors.emerald),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feedbackCtrl,
              maxLines: 2,
              style: GoogleFonts.outfit(fontSize: 13.5),
              decoration: InputDecoration(
                labelText: 'Feedback / Catatan untuk Siswa',
                hintText: 'Tuliskan catatan evaluasi...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.comment_outlined, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _saveGrade,
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  'Simpan Nilai & Beri Feedback',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isGraded ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGraded ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isGraded ? AppColors.emerald.withAlpha(30) : Colors.amber.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGraded ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
              color: isGraded ? AppColors.emerald : Colors.amber.shade900,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isGraded ? 'Nilai: ' : 'Status: Belum Dinilai',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isGraded ? const Color(0xFF14532D) : Colors.amber.shade900,
                      ),
                    ),
                    if (isGraded)
                      Text(
                        '${_sub.score!.toStringAsFixed(0)} / 100',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.emerald,
                        ),
                      ),
                  ],
                ),
                if (isGraded && _sub.teacherFeedback != null && _sub.teacherFeedback!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Feedback: "${_sub.teacherFeedback}"',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF166534),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => setState(() => _isEditingGrade = true),
            icon: Icon(isGraded ? Icons.edit_rounded : Icons.rate_review_rounded, size: 16),
            label: Text(
              isGraded ? 'Ubah Nilai' : 'Beri Nilai',
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── A. GAMBAR (IMAGES) ──
  Widget _buildImagesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SubmissionImageGalleryGrid(
        imageUrls: _sub.imageUrls,
        title: 'Lampiran Foto Tugas - ${_sub.submitterName}',
      ),
    );
  }


  // ── C. TAUTAN / LINK ──
  Widget _buildLinkSection() {
    final link = _sub.linkUrl!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.link_rounded, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tautan Tugas (Link Eksternal)',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      link,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => openExternalUrl(link),
                icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                label: Text('Kunjungi Link Tautan ↗️', style: GoogleFonts.outfit(fontSize: 12.5)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade800,
                  side: BorderSide(color: Colors.blue.shade300),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  AppSnackBar.success(context, 'Tautan tugas berhasil disalin ke clipboard!');
                },
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: Text('Salin Tautan', style: GoogleFonts.outfit(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── D. TEKS BIASA / ESSAY ──
  Widget _buildTextSection() {
    final text = _sub.textContent!;
    final wordCount = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article_rounded, color: Color(0xFF6366F1), size: 20),
              const SizedBox(width: 8),
              Text(
                'Jawaban Teks / Esai',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                '$wordCount kata • ${text.length} karakter',
                style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SelectableText(
              text,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                height: 1.6,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                AppSnackBar.success(context, 'Teks jawaban berhasil disalin!');
              },
              icon: const Icon(Icons.copy_rounded, size: 15),
              label: Text('Salin Teks', style: GoogleFonts.outfit(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  // ── E. KODE PROGRAM (CODE) ──
  Widget _buildCodeSection() {
    final code = _sub.sourceCode!;
    final lang = _sub.codeLanguage ?? 'code';
    final isSuccess = _sub.compileSuccess;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                const Icon(Icons.code_rounded, color: AppColors.emerald, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Kode Program (${lang.toUpperCase()})',
                  style: GoogleFonts.firaCode(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSuccess ? AppColors.emerald.withAlpha(40) : Colors.amber.withAlpha(40),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSuccess ? AppColors.emerald : Colors.amber,
                    ),
                  ),
                  child: Text(
                    isSuccess ? 'Kompilasi Sukses ✅' : 'Terkumpul ⏳',
                    style: TextStyle(
                      color: isSuccess ? AppColors.emerald : Colors.amber,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Code Container with Monospace Font
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: SelectableText(
                code,
                style: GoogleFonts.firaCode(
                  color: const Color(0xFFE2E8F0),
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ),
          ),

          // Compile Log if available
          if (_sub.compileLog != null && _sub.compileLog!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF020617),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hasil Terminal / Compiler Output:',
                    style: GoogleFonts.firaCode(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _sub.compileLog!,
                    style: GoogleFonts.firaCode(
                      color: isSuccess ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Actions: Copy & Run in Playground
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E293B),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Color(0xFF475569)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    AppSnackBar.success(context, 'Kode program disalin ke clipboard!');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: Text('Salin Kode', style: GoogleFonts.outfit(fontSize: 12)),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CodePlaygroundScreen(
                          initialLanguage: lang,
                          initialCode: code,
                          isAssignmentMode: false,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(
                    'Uji di Code Playground 🚀',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
