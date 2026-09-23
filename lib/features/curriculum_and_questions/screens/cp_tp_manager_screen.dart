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
    final subjects = fbService.currentUser?.isGuru == true
        ? fbService.getTeacherSubjects(fbService.currentUser)
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
          : FloatingActionButton.extended(
              onPressed: _showAddCpDialog,
              icon: const Icon(Icons.add),
              label: const Text('Tambah CP Baru'),
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
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  const Text('Pilih Mata Pelajaran: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedSubjectId.isNotEmpty ? _selectedSubjectId : null,
                      items: subjects.map((s) {
                        return DropdownMenuItem(value: s.id, child: Text(s.name));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSubjectId = val);
                      },
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),

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
                    ? const Center(child: Text('Belum ada CP untuk mata pelajaran ini.'))
                    : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: cps.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final cp = cps[index];
                      final tps = fbService.tps.where((t) => t.cpId == cp.id).toList();

                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.borderLight),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withAlpha(20),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      cp.code,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      cp.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _showAddTpDialog(cp.id),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Tambah TP'),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondaryLight),
                                    tooltip: 'Opsi CP',
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
                              const SizedBox(height: 6),
                              Text(
                                cp.description,
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Daftar Tujuan Pembelajaran (TP) • ${tps.length}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (tps.isEmpty)
                                const Text('Belum ada TP terdaftar.',
                                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey))
                              else
                                ...tps.map(
                                  (tp) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.backgroundLight,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.borderLight.withAlpha(153)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.check_circle_outline, size: 18, color: AppColors.emerald),
                                        const SizedBox(width: 8),
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
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: AppColors.borderLight),
                                                    ),
                                                    child: Text(
                                                      tp.code,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppColors.textPrimaryLight,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      tp.title,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
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
                                                    fontSize: 12,
                                                    color: AppColors.textSecondaryLight,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                          tooltip: 'Edit TP',
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          onPressed: () => _showEditTpDialog(tp),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          tooltip: 'Hapus TP',
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          onPressed: () => _confirmDeleteTp(tp),
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
