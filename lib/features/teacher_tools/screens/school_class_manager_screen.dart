import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/curved_header_card.dart';

class SchoolClassManagerScreen extends StatefulWidget {
  const SchoolClassManagerScreen({super.key});

  @override
  State<SchoolClassManagerScreen> createState() => _SchoolClassManagerScreenState();
}

class _SchoolClassManagerScreenState extends State<SchoolClassManagerScreen> {
  final _classNameController = TextEditingController();

  @override
  void dispose() {
    _classNameController.dispose();
    super.dispose();
  }

  void _showAddClassDialog() {
    _classNameController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.meeting_room_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Text('Tambah Kelas Baru', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan nama atau kode kelas (contoh: X-RPL-1, XI-TKJ-2, XII-SIJA-1).',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _classNameController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Nama Kelas',
                hintText: 'X-RPL-1',
                prefixIcon: const Icon(Icons.class_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final name = _classNameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final fb = context.read<FirebaseService>();
              await showLoadingDialog(
                context,
                message: 'Menambahkan kelas $name...',
                action: () => fb.addSchoolClass(name),
                successMessage: 'Kelas $name berhasil ditambahkan!',
                errorMessage: 'Gagal menambahkan kelas. Mungkin nama sudah ada.',
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showEditClassDialog(String classId, String currentName) {
    _classNameController.text = currentName;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_note_rounded, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            Text('Edit Nama Kelas', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ubah nama atau kode rombel kelas.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _classNameController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Nama Kelas',
                hintText: 'Contoh: 8 ERBIUM',
                prefixIcon: const Icon(Icons.class_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final newName = _classNameController.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              final fb = context.read<FirebaseService>();
              await showLoadingDialog(
                context,
                message: 'Memperbarui kelas $newName...',
                action: () => fb.updateSchoolClass(classId, newName),
                successMessage: 'Nama kelas berhasil diperbarui!',
                errorMessage: 'Gagal memperbarui nama kelas.',
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteClass(String classId, String className) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kelas'),
        content: Text('Apakah Anda yakin ingin menghapus kelas "$className"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () async {
              Navigator.pop(ctx);
              final fb = context.read<FirebaseService>();
              await showLoadingDialog(
                context,
                message: 'Menghapus kelas $className...',
                action: () => fb.deleteSchoolClass(classId),
                successMessage: 'Kelas $className berhasil dihapus.',
                errorMessage: 'Gagal menghapus kelas.',
              );
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final classes = fb.schoolClasses;
    final currentUser = fb.currentUser;

    // Daftar kelas yang diajar oleh guru saat ini
    final taughtClassNames = fb.getTeacherClasses(currentUser).map((c) => c.trim().toUpperCase()).toSet();
    final taughtClassIds = (currentUser?.classIds ?? []).map((c) => c.trim().toUpperCase()).toSet();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const CurvedHeaderCard(
              title: 'Kelola Kelas Sekolah',
              subtitle: 'Manajemen Data Rombel & Jenjang Kelas',
            ),

            // Class List
            Expanded(
              child: classes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Belum Ada Kelas yang Diinput',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Klik tombol di bawah untuk menambahkan kelas pertama.',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _showAddClassDialog,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Tambah Kelas Sekarang'),
                            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                      itemCount: classes.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final c = classes[index];
                        final studentCount = fb.allStudents
                            .where((s) => (s.className ?? s.classId ?? '').toUpperCase() == c.name.toUpperCase())
                            .length;

                        // Periksa apakah kelas ini diajar oleh guru yang login
                        final bool isTaughtByCurrentTeacher = (currentUser == null || !currentUser.isGuru) ||
                            taughtClassNames.contains(c.name.trim().toUpperCase()) ||
                            taughtClassIds.contains(c.id.trim().toUpperCase()) ||
                            taughtClassIds.contains(c.name.trim().toUpperCase());

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isTaughtByCurrentTeacher
                                  ? AppColors.primary.withAlpha(50)
                                  : const Color(0xFFE2E8F0),
                              width: isTaughtByCurrentTeacher ? 1.3 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(6),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: isTaughtByCurrentTeacher
                                      ? AppColors.primaryGradient
                                      : const LinearGradient(
                                          colors: [Color(0xFF94A3B8), Color(0xFF64748B)],
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Icon(Icons.class_rounded, color: Colors.white, size: 22),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Kelas ${c.name}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF1E293B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (currentUser?.isGuru == true && isTaughtByCurrentTeacher) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFA7F3D0)),
                                            ),
                                            child: const Text(
                                              'Kelas Ajar',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF059669),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$studentCount Siswa Terdaftar',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),

                              // Aksi Edit & Hapus HANYA untuk kelas yang diajar guru (atau Admin)
                              if (isTaughtByCurrentTeacher) ...[
                                InkWell(
                                  onTap: () => _showEditClassDialog(c.id, c.name),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withAlpha(20),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.edit_outlined, size: 17, color: Colors.blue),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _confirmDeleteClass(c.id, c.name),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withAlpha(20),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.delete_outline_rounded, size: 17, color: AppColors.rose),
                                  ),
                                ),
                              ] else ...[
                                // Indikator bukan kelas ajar (hanya lihat)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_outline_rounded, size: 13, color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Hanya Lihat',
                                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: classes.isNotEmpty
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(80),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: _showAddClassDialog,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  'Tambah Kelas',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            )
          : null,
    );
  }
}
