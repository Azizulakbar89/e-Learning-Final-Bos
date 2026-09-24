import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/curriculum_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/curved_header_card.dart';

class CpTpManagerScreen extends StatefulWidget {
  const CpTpManagerScreen({super.key});

  @override
  State<CpTpManagerScreen> createState() => _CpTpManagerScreenState();
}

class _CpTpManagerScreenState extends State<CpTpManagerScreen> {
  final _uuid = const Uuid();
  String _selectedSubjectId = 'subj_web';

  void _showAddCpDialog() {
    final codeCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tambah Capaian Pembelajaran (CP)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: 'Kode CP', hintText: 'Contoh: CP-WEB-10.2'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Judul CP', hintText: 'Contoh: Arsitektur API Modern'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Deskripsi Capaian'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              final fb = context.read<FirebaseService>();
              fb.addCp(
                CurriculumCpModel(
                  id: _uuid.v4(),
                  subjectId: _selectedSubjectId,
                  teacherId: fb.currentUser?.id ?? 'teacher_budi',
                  code: codeCtrl.text.trim(),
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                ),
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Capaian Pembelajaran (CP) berhasil ditambahkan'),
                  backgroundColor: AppColors.emerald,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Simpan CP'),
          ),
        ],
      ),
    );
  }

  void _showEditCpDialog(CurriculumCpModel cp) {
    final codeCtrl = TextEditingController(text: cp.code);
    final titleCtrl = TextEditingController(text: cp.title);
    final descCtrl = TextEditingController(text: cp.description);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Capaian Pembelajaran (CP)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: 'Kode CP', hintText: 'Contoh: CP-WEB-10.2'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Judul CP', hintText: 'Contoh: Arsitektur API Modern'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Deskripsi Capaian'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              final fb = context.read<FirebaseService>();
              fb.updateCp(
                cp.copyWith(
                  code: codeCtrl.text.trim(),
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                ),
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Capaian Pembelajaran (CP) berhasil diperbarui'),
                  backgroundColor: AppColors.emerald,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Simpan Perubahan'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCp(CurriculumCpModel cp) {
    final tpsCount = context.read<FirebaseService>().tps.where((t) => t.cpId == cp.id).length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Hapus CP?'),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus CP "${cp.code}: ${cp.title}"?'
          '${tpsCount > 0 ? '\n\nPerhatian: Sebanyak $tpsCount Tujuan Pembelajaran (TP) di bawah CP ini juga akan dihapus secara permanen!' : ''}',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final fb = context.read<FirebaseService>();
              fb.deleteCp(cp.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('CP "${cp.code}" dan seluruh TP terkait berhasil dihapus'),
                  backgroundColor: Colors.red.shade700,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Hapus CP', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddTpDialog(String cpId) {
    final codeCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tambah Tujuan Pembelajaran (TP)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: 'Kode TP', hintText: 'Contoh: TP-10.2.1'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Judul TP'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Deskripsi Tujuan'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              final fb = context.read<FirebaseService>();
              fb.addTp(
                CurriculumTpModel(
                  id: _uuid.v4(),
                  cpId: cpId,
                  subjectId: _selectedSubjectId,
                  code: codeCtrl.text.trim(),
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                ),
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tujuan Pembelajaran (TP) berhasil ditambahkan'),
                  backgroundColor: AppColors.emerald,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Simpan TP'),
          ),
        ],
      ),
    );
  }

  void _showEditTpDialog(CurriculumTpModel tp) {
    final codeCtrl = TextEditingController(text: tp.code);
    final titleCtrl = TextEditingController(text: tp.title);
    final descCtrl = TextEditingController(text: tp.description);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Tujuan Pembelajaran (TP)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: 'Kode TP', hintText: 'Contoh: TP-10.2.1'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Judul TP'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Deskripsi Tujuan'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              final fb = context.read<FirebaseService>();
              fb.updateTp(
                tp.copyWith(
                  code: codeCtrl.text.trim(),
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                ),
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tujuan Pembelajaran (TP) berhasil diperbarui'),
                  backgroundColor: AppColors.emerald,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Simpan Perubahan'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTp(CurriculumTpModel tp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Hapus TP?'),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus TP "${tp.code}: ${tp.title}"?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final fb = context.read<FirebaseService>();
              fb.deleteTp(tp.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('TP "${tp.code}" berhasil dihapus'),
                  backgroundColor: Colors.red.shade700,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Hapus TP', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fbService = context.watch<FirebaseService>();
    final currentUser = fbService.currentUser;
    final subjects = (currentUser != null && currentUser.isGuru)
        ? fbService.getTeacherSubjects(currentUser)
        : fbService.subjects;

    if (subjects.isNotEmpty && !subjects.any((s) => s.id == _selectedSubjectId)) {
      _selectedSubjectId = subjects.first.id;
    } else if (subjects.isEmpty) {
      _selectedSubjectId = '';
    }

    final cps = fbService.cps.where((c) => c.subjectId == _selectedSubjectId).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      floatingActionButton: subjects.isEmpty
          ? null
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(90),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                onPressed: _showAddCpDialog,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  'Tambah CP Baru',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const CurvedHeaderCard(
              title: 'Manajemen Kurikulum: CP & TP',
              subtitle: 'Kelola Capaian & Tujuan Pembelajaran',
            ),
            // Subject selector bar
            if (subjects.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Akun guru Anda belum diplot ke mata pelajaran manapun oleh Admin. Penambahan dan pengelolaan CP & TP tidak dapat diproses.',
                        style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Mata Pelajaran',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (subjects.length > 1) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${subjects.length} Mapel Diajar',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              isDense: true,
                              value: _selectedSubjectId.isNotEmpty ? _selectedSubjectId : null,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                              items: subjects.map((s) {
                                return DropdownMenuItem(
                                  value: s.id,
                                  child: Text(
                                    s.name,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedSubjectId = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // CP & TP Hierarchy List
            Expanded(
              child: subjects.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.layers_clear_outlined, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Belum Ada Mapel yang Diplot',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Silakan hubungi Admin Sekolah untuk melakukan plotting mata pelajaran.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  : cps.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(20),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.school_outlined, size: 48, color: AppColors.primary),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Belum Ada Capaian Pembelajaran',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Klik tombol "+ Tambah CP Baru" di bawah untuk mulai menyusun kurikulum.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
                          itemCount: cps.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final cp = cps[index];
                            final tps = fbService.tps.where((t) => t.cpId == cp.id).toList();

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(8),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // CP Header: Code Pill + Title + Add TP Pill + Menu
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppColors.primary.withAlpha(28),
                                                AppColors.primary.withAlpha(14),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.primary.withAlpha(80)),
                                          ),
                                          child: Text(
                                            cp.code,
                                            style: GoogleFonts.outfit(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            cp.title,
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15.5,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        // Button Tambah TP pill
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _showAddTpDialog(cp.id),
                                            borderRadius: BorderRadius.circular(20),
                                            child: Ink(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFF7ED),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: const Color(0xFFFFD8BF)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.add_circle_outline_rounded,
                                                    size: 13,
                                                    color: AppColors.primary,
                                                  ),
                                                  const SizedBox(width: 3.5),
                                                  Text(
                                                    'Tambah TP',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF94A3B8)),
                                          tooltip: 'Opsi CP',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onSelected: (val) {
                                            if (val == 'edit') {
                                              _showEditCpDialog(cp);
                                            } else if (val == 'delete') {
                                              _confirmDeleteCp(cp);
                                            }
                                          },
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                                  SizedBox(width: 8),
                                                  Text('Edit CP', style: TextStyle(fontSize: 13)),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Hapus CP', style: TextStyle(fontSize: 13, color: Colors.red)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (cp.description.isNotEmpty) ...[
                                      const SizedBox(height: 7),
                                      Text(
                                        cp.description,
                                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(Icons.playlist_add_check_rounded, size: 15, color: Color(0xFF64748B)),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Daftar Tujuan Pembelajaran (TP)',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11.5,
                                            color: const Color(0xFF475569),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: tps.isNotEmpty ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${tps.length}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: tps.isNotEmpty ? const Color(0xFF059669) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    if (tps.isEmpty)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.info_outline_rounded, size: 15, color: Colors.grey.shade500),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Belum ada TP terdaftar. Klik "+ Tambah TP" untuk menambahkan.',
                                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      ...tps.map(
                                        (tp) => Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFECFDF5),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                                ),
                                                child: const Icon(
                                                  Icons.check_rounded,
                                                  size: 13,
                                                  color: Color(0xFF059669),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius: BorderRadius.circular(6),
                                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                                          ),
                                                          child: Text(
                                                            tp.code,
                                                            style: GoogleFonts.outfit(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                              color: const Color(0xFF334155),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            tp.title,
                                                            style: GoogleFonts.outfit(
                                                              fontSize: 13.5,
                                                              fontWeight: FontWeight.w600,
                                                              color: const Color(0xFF1E293B),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (tp.description.isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        tp.description,
                                                        style: const TextStyle(
                                                          fontSize: 11.5,
                                                          color: Color(0xFF64748B),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              InkWell(
                                                onTap: () => _showEditTpDialog(tp),
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.withAlpha(20),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              InkWell(
                                                onTap: () => _confirmDeleteTp(tp),
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.withAlpha(20),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
