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
            },
            child: const Text('Simpan CP'),
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
            },
            child: const Text('Simpan TP'),
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
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                cp.description,
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                              const Text('Daftar Tujuan Pembelajaran (TP):',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              if (tps.isEmpty)
                                const Text('Belum ada TP terdaftar.',
                                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey))
                              else
                                ...tps.map(
                                  (tp) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.check_circle_outline, size: 16, color: AppColors.emerald),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${tp.code}: ${tp.title}',
                                            style: const TextStyle(fontSize: 13),
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
