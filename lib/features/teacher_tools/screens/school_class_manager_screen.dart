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
            // Info Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manajemen Kelas Resmi Sekolah',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Pilihan kelas pada pendaftaran siswa & filter ujian bersumber dari data di bawah ini.',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: classes.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final c = classes[index];
                        final studentCount = fb.allStudents
                            .where((s) => (s.className ?? s.classId ?? '').toUpperCase() == c.name.toUpperCase())
                            .length;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderLight),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
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
                                    Text(
                                      'Kelas ${c.name}',
                                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$studentCount Siswa Terdaftar',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.rose),
                                tooltip: 'Hapus Kelas',
                                onPressed: () => _confirmDeleteClass(c.id, c.name),
                              ),
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
          ? FloatingActionButton.extended(
              onPressed: _showAddClassDialog,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Kelas'),
            )
          : null,
    );
  }
}
