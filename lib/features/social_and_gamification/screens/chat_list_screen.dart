import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/streak_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/curved_header_card.dart';
import '../../../core/widgets/universal_app_header.dart';
import 'chat_conversation_screen.dart';

class ChatListScreen extends StatefulWidget {
  final bool showBackButton;
  final bool isEmbedded;

  const ChatListScreen({
    super.key,
    this.showBackButton = true,
    this.isEmbedded = false,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  int _selectedFilterIndex = 0; // 0: Semua, 1: Diskusi Kelas, 2: Konsultasi Siswa

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FirebaseService>().ensureUserStreaks(context.read<FirebaseService>().currentUser);
      }
    });
  }

  void _confirmDeleteGroupFromList(BuildContext context, FirebaseService fb, StreakModel s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: AppColors.rose),
            const SizedBox(width: 8),
            Text('Hapus Grup Chat?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus grup "${s.title}"?\nGrup dan riwayat pesan akan dihapus secara permanen dari tab Semua maupun Grup Kelas.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () async {
              Navigator.pop(ctx);
              await fb.deleteStreak(s.id);
              if (context.mounted) {
                AppSnackBar.success(context, 'Grup "${s.title}" berhasil dihapus.');
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showNewStreakDialog(BuildContext context) {
    final fb = context.read<FirebaseService>();
    final currentUser = fb.currentUser;
    final isTeacher = currentUser?.isGuru ?? false;

    // Data siswa dan guru diambil langsung dari FirebaseService
    // Untuk Guru: bisa mengakses dan chat dengan seluruh siswa tanpa batasan
    final allStudents = fb.allStudents;
    final allTeachers = fb.allTeachers;
    final userClass = (currentUser?.className ?? currentUser?.classId ?? '').trim();

    // 1. Teman sekelas / Siswa dari Firebase
    // Untuk Guru: daftar semua siswa sekolah agar bebas memilih siapapun
    final List<UserModel> classmates = isTeacher
        ? allStudents.where((s) => s.id != currentUser?.id).toList()
        : allStudents.where((s) {
            if (s.id == currentUser?.id) return false;
            final sClass = (s.className ?? s.classId ?? '').trim().toLowerCase();
            return sClass == userClass.toLowerCase();
          }).toList();

    // 2. Daftar Jenjang / Kelas dari Firebase (memuat seluruh kelas)
    final List<String> gradeClasses = () {
      final Set<String> existingClasses = {};
      for (final s in allStudents) {
        final c = (s.className ?? s.classId ?? '').trim();
        if (c.isNotEmpty) existingClasses.add(c);
      }
      for (final sc in fb.schoolClasses) {
        if (sc.name.trim().isNotEmpty) existingClasses.add(sc.name.trim());
      }
      if (existingClasses.isEmpty) {
        existingClasses.addAll(['Kelas 7', 'Kelas 8', 'Kelas 9']);
      }
      return existingClasses.toList()..sort();
    }();

    // 3. Daftar Guru dari Firebase (jika guru, rekan guru lainnya)
    final List<UserModel> teachers = isTeacher
        ? allTeachers.where((t) => t.id != currentUser?.id).toList()
        : List<UserModel>.from(allTeachers);

    // Helper untuk mengambil siswa dari jenjang/kelas tertentu dari Firebase
    List<UserModel> getStudentsForGrade(String grade) {
      return allStudents.where((s) {
        if (s.id == currentUser?.id) return false;
        final sClass = (s.className ?? s.classId ?? '').trim().toLowerCase();
        return sClass == grade.trim().toLowerCase();
      }).toList();
    }

    // State Variables berbasis String ID (100% aman dari dropdown assertion error)
    int selectedModeIndex = 0; // 0: Teman Sekelas/Siswa Ajar, 1: Antar Kelas/Kelas Ajar, 2: Guru, 3: Grup
    String? selectedClassmateId = classmates.isNotEmpty ? classmates.first.id : null;
    String selectedGrade = gradeClasses.first;
    String? selectedGradeStudentId = getStudentsForGrade(selectedGrade).isNotEmpty
        ? getStudentsForGrade(selectedGrade).first.id
        : null;
    String? selectedTeacherId = teachers.isNotEmpty ? teachers.first.id : null;
    final groupTitleCtrl = TextEditingController(text: 'Kelompok Belajar Bersama');
    final Set<String> groupMemberIds = {};
    if (classmates.isNotEmpty) {
      groupMemberIds.add(classmates.first.id);
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final studentsInGrade = getStudentsForGrade(selectedGrade);
          if (selectedGradeStudentId == null || !studentsInGrade.any((s) => s.id == selectedGradeStudentId)) {
            selectedGradeStudentId = studentsInGrade.isNotEmpty ? studentsInGrade.first.id : null;
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dialog Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: AppColors.flameGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('🔥', style: TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mulai Streak Belajar Baru',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 17),
                              ),
                              const Text(
                                'Data teman & guru terhubung langsung ke Firebase',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Mode Selection Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildModeChip(
                            index: 0,
                            currentIndex: selectedModeIndex,
                            label: isTeacher ? 'Semua Siswa' : 'Teman Sekelas',
                            icon: Icons.school_rounded,
                            onTap: () => setDialogState(() => selectedModeIndex = 0),
                          ),
                          const SizedBox(width: 8),
                          _buildModeChip(
                            index: 1,
                            currentIndex: selectedModeIndex,
                            label: isTeacher ? 'Pilih per Kelas' : 'Kelas 7 / 8 / 9',
                            icon: Icons.groups_2_rounded,
                            onTap: () => setDialogState(() => selectedModeIndex = 1),
                          ),
                          const SizedBox(width: 8),
                          _buildModeChip(
                            index: 2,
                            currentIndex: selectedModeIndex,
                            label: isTeacher ? 'Rekan Guru' : 'Guru Pengajar',
                            icon: Icons.psychology_alt_rounded,
                            onTap: () => setDialogState(() => selectedModeIndex = 2),
                          ),
                          const SizedBox(width: 8),
                          _buildModeChip(
                            index: 3,
                            currentIndex: selectedModeIndex,
                            label: 'Streak Grup',
                            icon: Icons.forum_rounded,
                            onTap: () => setDialogState(() => selectedModeIndex = 3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── MODE 0: TEMAN SEKELAS / SEMUA SISWA ──
                    if (selectedModeIndex == 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isTeacher
                                    ? 'Daftar Seluruh Siswa (${classmates.length} siswa siap diajak chat)'
                                    : 'Kelas Anda di Firebase: $userClass (${classmates.length} teman ditemukan)',
                                style: const TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (classmates.isNotEmpty)
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: isTeacher ? 'Pilih Siswa' : 'Pilih Teman Sekelas',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.person_rounded, color: AppColors.primary),
                          ),
                          initialValue: selectedClassmateId ?? classmates.first.id,
                          items: classmates.map((s) {
                            final cInfo = (s.className ?? s.classId ?? '').trim();
                            return DropdownMenuItem<String>(
                              value: s.id,
                              child: Text(
                                '${s.fullName}${cInfo.isNotEmpty ? " ($cInfo)" : ""}${s.nis != null ? " • ${s.nis}" : ""}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                              ),
                            );
                          }).toList(),
                          onChanged: (id) => setDialogState(() => selectedClassmateId = id),
                        )
                      else ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: const Text(
                            'Belum ada akun siswa lain di kelas ini pada database Firebase. Anda dapat memilih tab "Kelas 7 / 8 / 9" atau "Guru Pengajar".',
                            style: TextStyle(fontSize: 12, color: Colors.brown),
                          ),
                        ),
                      ],
                    ],

                    // ── MODE 1: ANTAR KELAS (KELAS 7, 8, 9) ──
                    if (selectedModeIndex == 1) ...[
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Pilih Jenjang / Kelas',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.meeting_room_rounded, color: AppColors.primaryLight),
                        ),
                        initialValue: selectedGrade,
                        items: gradeClasses.map((gc) {
                          return DropdownMenuItem<String>(
                            value: gc,
                            child: Text(gc, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedGrade = val;
                              final newStudents = getStudentsForGrade(val);
                              selectedGradeStudentId = newStudents.isNotEmpty ? newStudents.first.id : null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      if (studentsInGrade.isNotEmpty)
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Pilih Siswa dari $selectedGrade',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.person_search_rounded, color: AppColors.primaryLight),
                          ),
                          initialValue: selectedGradeStudentId ?? studentsInGrade.first.id,
                          items: studentsInGrade.map((s) {
                            return DropdownMenuItem<String>(
                              value: s.id,
                              child: Text(
                                s.fullName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                              ),
                            );
                          }).toList(),
                          onChanged: (id) => setDialogState(() => selectedGradeStudentId = id),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Text(
                            'Belum ada siswa terdaftar di $selectedGrade pada database Firebase.',
                            style: const TextStyle(fontSize: 12, color: Colors.brown),
                          ),
                        ),
                    ],

                    // ── MODE 2: GURU PENGAJAR ──
                    if (selectedModeIndex == 2) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.auto_stories_rounded, size: 16, color: Colors.purple),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Bimbingan belajar & konsultasi materi bersama guru.',
                                style: TextStyle(fontSize: 11.5, color: Colors.purple, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (teachers.isNotEmpty)
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Pilih Guru Pengajar',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.psychology_alt_rounded, color: Colors.purple),
                          ),
                          initialValue: selectedTeacherId ?? teachers.first.id,
                          items: teachers.map((t) {
                            return DropdownMenuItem<String>(
                              value: t.id,
                              child: Text(
                                t.fullName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (id) => setDialogState(() => selectedTeacherId = id),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: const Text(
                            'Belum ada akun guru yang terdaftar di database Firebase.',
                            style: TextStyle(fontSize: 12, color: Colors.purple),
                          ),
                        ),
                    ],

                    // ── MODE 3: STREAK GRUP BEBAS (SIAPAPUN) ──
                    if (selectedModeIndex == 3) ...[
                      TextField(
                        controller: groupTitleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Nama / Judul Grup Belajar',
                          hintText: 'Contoh: Kelompok Robotika & Coding',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.group_work_rounded, color: Color(0xFF059669)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Pilih Anggota Grup (Siswa / Guru):',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ...allStudents.where((s) => s.id != currentUser?.id).take(8).map((s) => s),
                          ...teachers.where((t) => t.id != currentUser?.id).take(3).map((t) => t),
                        ].map((person) {
                          final isChecked = groupMemberIds.contains(person.id);
                          return FilterChip(
                            label: Text(person.fullName, style: const TextStyle(fontSize: 11)),
                            selected: isChecked,
                            selectedColor: const Color(0xFF059669).withAlpha(30),
                            checkmarkColor: const Color(0xFF059669),
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  groupMemberIds.add(person.id);
                                } else {
                                  groupMemberIds.remove(person.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5722),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            onPressed: () async {
                              const uuid = Uuid();
                              StreakType finalType = StreakType.peer;
                              String finalTitle = '';
                              List<String> participantIds = [currentUser?.id ?? ''];
                              List<String> participantNames = [currentUser?.fullName ?? 'Saya'];

                              if (selectedModeIndex == 0) {
                                // Teman Sekelas
                                if (classmates.isEmpty || selectedClassmateId == null) {
                                  AppSnackBar.error(
                                    context,
                                    'Belum ada teman sekelas yang terdaftar di Firebase.',
                                  );
                                  return;
                                }
                                finalType = StreakType.peer;
                                final partner = classmates.firstWhere(
                                  (s) => s.id == selectedClassmateId,
                                  orElse: () => classmates.first,
                                );
                                finalTitle = partner.fullName;
                                participantIds.add(partner.id);
                                participantNames.add(partner.fullName);
                              } else if (selectedModeIndex == 1) {
                                // Antar Kelas
                                if (studentsInGrade.isEmpty || selectedGradeStudentId == null) {
                                  AppSnackBar.error(
                                    context,
                                    'Belum ada siswa di $selectedGrade pada Firebase.',
                                  );
                                  return;
                                }
                                finalType = StreakType.peer;
                                final partner = studentsInGrade.firstWhere(
                                  (s) => s.id == selectedGradeStudentId,
                                  orElse: () => studentsInGrade.first,
                                );
                                finalTitle = '${partner.fullName} ($selectedGrade)';
                                participantIds.add(partner.id);
                                participantNames.add(partner.fullName);
                              } else if (selectedModeIndex == 2) {
                                // Guru Pengajar
                                if (teachers.isEmpty || selectedTeacherId == null) {
                                  AppSnackBar.error(
                                    context,
                                    'Belum ada guru yang terdaftar di Firebase.',
                                  );
                                  return;
                                }
                                finalType = StreakType.teacher;
                                final teacher = teachers.firstWhere(
                                  (t) => t.id == selectedTeacherId,
                                  orElse: () => teachers.first,
                                );
                                finalTitle = teacher.fullName;
                                participantIds.add(teacher.id);
                                participantNames.add(teacher.fullName);
                              } else {
                                // Grup
                                finalType = StreakType.group;
                                finalTitle = groupTitleCtrl.text.trim().isNotEmpty
                                    ? groupTitleCtrl.text.trim()
                                    : 'Grup Belajar Bersama';
                                final allCandidates = [...allStudents, ...teachers];
                                for (final pid in groupMemberIds) {
                                  participantIds.add(pid);
                                  final pName = allCandidates.firstWhere((c) => c.id == pid, orElse: () => UserModel(id: pid, username: pid, fullName: 'Anggota', role: 'siswa')).fullName;
                                  participantNames.add(pName);
                                }
                              }

                              final newStreak = StreakModel(
                                id: uuid.v4(),
                                type: finalType,
                                title: finalTitle,
                                participantIds: participantIds,
                                participantNames: participantNames,
                                streakCount: 0,
                                lastInteractionAt: DateTime.now(),
                                expiresAt: DateTime.now().add(const Duration(hours: 24)),
                              );

                              // Simpan ke Firestore tanpa pesan otomatis
                              await fb.createStreak(newStreak);

                              if (context.mounted) {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatConversationScreen(streak: newStreak),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              'Mulai Streak 🔥',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModeChip({
    required int index,
    required int currentIndex,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isSelected = index == currentIndex;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5722) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF5722) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOrCreateStudentStreak(BuildContext context, FirebaseService fb, UserModel student) async {
    final currentUser = fb.currentUser;
    if (currentUser == null) return;

    final existing = fb.streaks.where((s) =>
        s.participantIds.contains(student.id) &&
        s.participantIds.contains(currentUser.id) &&
        s.type == StreakType.teacher).firstOrNull;

    if (existing != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatConversationScreen(streak: existing)));
      return;
    }

    final newStreak = StreakModel(
      id: const Uuid().v4(),
      type: StreakType.teacher,
      title: '${student.fullName} (${student.className ?? student.classId ?? ""})',
      participantIds: [currentUser.id, student.id],
      participantNames: [currentUser.fullName, student.fullName],
      streakCount: 0,
      lastInteractionAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    );

    await fb.createStreak(newStreak);

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatConversationScreen(streak: newStreak)));
    }
  }

  Future<void> _openOrCreateClassGroup(BuildContext context, FirebaseService fb, String className) async {
    final currentUser = fb.currentUser;
    if (currentUser == null) return;

    final existing = fb.streaks.where((s) =>
        s.title.toLowerCase().contains(className.toLowerCase()) &&
        s.type == StreakType.group).firstOrNull;

    if (existing != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatConversationScreen(streak: existing)));
      return;
    }

    final students = fb.getClassStudents(className);
    final pIds = [currentUser.id, ...students.map((s) => s.id)];
    final pNames = [currentUser.fullName, ...students.map((s) => s.fullName)];

    final newStreak = StreakModel(
      id: const Uuid().v4(),
      type: StreakType.group,
      title: 'Diskusi Kelas $className',
      participantIds: pIds,
      participantNames: pNames,
      streakCount: 0,
      lastInteractionAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    );

    await fb.createStreak(newStreak);

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatConversationScreen(streak: newStreak)));
    }
  }

  Widget _buildFilterChip(int index, String label, IconData icon) {
    final isSelected = _selectedFilterIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilterIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryLight : const Color(0xFFE2E8F0),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryLight.withAlpha(60),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey.shade600),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final currentUser = fb.currentUser;
    final isTeacher = currentUser?.isGuru ?? false;
    final teacherClasses = isTeacher ? fb.getTeacherClasses(currentUser) : <String>[];

    // 1. Ambil semua streak dari database yang relevan dengan user ini
    final List<StreakModel> userStreaks = fb.streaks.where((s) {
      if (currentUser == null) return true;

      // Logika khusus Guru: Guru bisa chat dengan siswa siapapun tanpa batasan!
      if (isTeacher) {
        // Tampilkan obrolan jika guru termasuk partisipan (1-on-1 dengan siswa/guru manapun)
        if (s.participantIds.contains(currentUser.id)) return true;

        // Obrolan grup: tampilkan jika guru termasuk anggota atau grup kelas yang diajar
        if (s.type == StreakType.group) {
          if (s.participantIds.contains(currentUser.id)) return true;
          for (final cls in teacherClasses) {
            if (s.title.toLowerCase().contains(cls.toLowerCase())) return true;
          }
        }
        return false;
      }

      // Logika untuk Siswa / Pengguna biasa
      // Hanya tampilkan streak yang memang melibatkan user ini
      if (s.participantIds.contains(currentUser.id)) return true;

      // Fallback: cek berdasarkan nama (untuk backward compatibility)
      if (s.participantNames.contains(currentUser.fullName) &&
          !s.participantIds.any((id) => id.isNotEmpty)) {
        return true;
      }

      return false;
    }).toList();

    // 2b. Jika Siswa: otomatis tampilkan grup kelas sendiri (hanya 1 kelas)
    if (!isTeacher && currentUser != null) {
      final userClass = (currentUser.className ?? currentUser.classId ?? '').trim();
      if (userClass.isNotEmpty) {
        final classGroupId = 'streak_class_${userClass.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
        final hasMyClassGroup = userStreaks.any((s) =>
            s.type == StreakType.group &&
            s.title.toLowerCase().contains(userClass.toLowerCase()));

        if (!hasMyClassGroup && !fb.deletedStreakIds.contains(classGroupId)) {
          // Cari grup kelas dari Firebase (sudah dibuat oleh guru)
          final existingInFirebase = fb.streaks.where((s) =>
              s.type == StreakType.group &&
              !fb.deletedStreakIds.contains(s.id) &&
              s.title.toLowerCase().contains(userClass.toLowerCase())).firstOrNull;

          if (existingInFirebase != null) {
            userStreaks.insert(0, existingInFirebase);
          } else {
            // Buat placeholder grup kelas untuk siswa ini jika belum dihapus
            final classmatesAll = fb.allStudents.where((s) {
              final c = (s.className ?? s.classId ?? '').trim().toLowerCase();
              return c == userClass.toLowerCase();
            }).toList();
            final classTeachersList = fb.allTeachers.where((t) {
              final tCls = fb.getTeacherClasses(t);
              return tCls.any((c) => c.trim().toLowerCase() == userClass.toLowerCase());
            }).toList();

            final pIds = <String>{
              currentUser.id,
              ...classmatesAll.map((s) => s.id),
              ...classTeachersList.map((t) => t.id),
            }.toList();
            final pNames = <String>{
              currentUser.fullName,
              ...classmatesAll.map((s) => s.fullName),
              ...classTeachersList.map((t) => t.fullName),
            }.toList();

            userStreaks.insert(
              0,
              StreakModel(
                id: classGroupId,
                type: StreakType.group,
                title: 'Diskusi Kelas $userClass',
                participantIds: pIds,
                participantNames: pNames,
                streakCount: 0,
                lastInteractionAt: DateTime.now(),
                expiresAt: DateTime.now().add(const Duration(hours: 24)),
              ),
            );
          }
        }
      }
    }

    // Pastikan grup/obrolan yang telah dihapus dihilangkan dari semua tampilan tab
    userStreaks.removeWhere((s) => fb.deletedStreakIds.contains(s.id));

    // 3. Filter berdasarkan tab (Streak non-chat ditampilkan di banner khusus)
    final List<StreakModel> displayStreaks = userStreaks.where((s) {
      if (s.type == StreakType.study) return false;
      if (_selectedFilterIndex == 1) return s.type == StreakType.group;
      if (_selectedFilterIndex == 2) return s.type == StreakType.teacher || s.type == StreakType.peer;
      return true;
    }).toList();

    final mainContent = Column(
      children: [
        // ── TOP HEADER ──
        if (widget.isEmbedded)
          UniversalAppHeader(
            showBackButton: false,
            bottomContent: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Pesan & Streaks Belajar',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${userStreaks.length} Obrolan Aktif • Ruang Konsultasi & Diskusi 🔥',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          CurvedHeaderCard(
            showBackButton: widget.showBackButton,
            title: 'Pesan & Streaks Belajar',
            subtitle: '${userStreaks.length} Obrolan Aktif • Ruang Konsultasi & Diskusi 🔥',
          ),

            // ── SHORTCUT CHAT SISWA & KELAS (JIKA GURU) ──
            if (isTeacher && teacherClasses.isNotEmpty)
              Container(
                height: 46,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final cls in teacherClasses)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: const Icon(Icons.forum_rounded, size: 15, color: AppColors.primary),
                          label: Text('Diskusi Kelas $cls', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          backgroundColor: AppColors.primary.withAlpha(20),
                          side: BorderSide(color: AppColors.primary.withAlpha(60)),
                          onPressed: () => _openOrCreateClassGroup(context, fb, cls),
                        ),
                      ),
                    for (final cls in teacherClasses)
                      for (final std in fb.getClassStudents(cls).take(5))
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: const Icon(Icons.person_outline_rounded, size: 15, color: Color(0xFF059669)),
                            label: Text('Chat ${std.fullName}', style: const TextStyle(fontSize: 11.5)),
                            backgroundColor: const Color(0xFF059669).withAlpha(15),
                            side: const BorderSide(color: Color(0xFF059669)),
                            onPressed: () => _openOrCreateStudentStreak(context, fb, std),
                          ),
                        ),
                  ],
                ),
              ),

            // ── STREAK BELAJAR MANDIRI (NON-CHAT) BANNER UNTUK SISWA ──
            if (!isTeacher)
              _buildStudyStreakBanner(context, fb, currentUser),

            // ── TAB FILTER SEGMENTED BUTTONS ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  _buildFilterChip(0, 'Semua (${userStreaks.length})', Icons.all_inbox_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip(1, 'Grup Kelas', Icons.groups_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip(2, isTeacher ? 'Siswa' : 'Guru / Teman', Icons.school_rounded),
                ],
              ),
            ),

            // ── BODY: LIST OR GAMIFIED EMPTY STATE ──
            Expanded(
              child: displayStreaks.isEmpty
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF7A00), Color(0xFFFF0055)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF5722).withAlpha(80),
                                  blurRadius: 24,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text('🔥', style: TextStyle(fontSize: 42)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            isTeacher
                                ? 'Belum Ada Pesan Masuk'
                                : 'Belum Ada Streak Aktif',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isTeacher
                                ? 'Obrolan dari siswa atau grup kelas akan muncul di sini saat ada pesan masuk atau saat Anda mengirimkan pesan baru.'
                                : 'Mulai obrolan dan streak belajar bersama guru atau teman kelasmu! Kirim pesan minimal sekali dalam 24 jam agar apimu tetap berkobar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(10),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _buildFeatureRow(
                                  icon: Icons.local_fire_department_rounded,
                                  color: const Color(0xFFFF5722),
                                  title: 'Api Streak Harian',
                                  subtitle: 'Kirim pesan setiap hari untuk menambah angka streak.',
                                ),
                                const Divider(height: 20),
                                _buildFeatureRow(
                                  icon: Icons.timer_outlined,
                                  color: const Color(0xFFEAB308),
                                  title: 'Batas 24 Jam',
                                  subtitle: 'Peringatan otomatis muncul bila streak hampir hangus.',
                                ),
                                const Divider(height: 20),
                                _buildFeatureRow(
                                  icon: Icons.emoji_events_outlined,
                                  color: const Color(0xFF8B5CF6),
                                  title: 'Bonus XP & Gamifikasi',
                                  subtitle: 'Dapatkan poin bonus untuk keaktifan belajar!',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      itemCount: displayStreaks.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final s = displayStreaks[index];
                        final lastMsg = fb.chatMessages.where((c) => c.streakId == s.id).toList()
                          ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
                        final latestSnippet = lastMsg.isNotEmpty
                            ? lastMsg.last.message
                            : 'Belum ada pesan obrolan.';

                        final isGroup = s.type == StreakType.group;
                        final chatTitle = s.getDisplayName(
                          currentUserId: currentUser?.id,
                          currentUserName: currentUser?.fullName,
                        );
                        final avatarColor = isGroup ? AppColors.primary : const Color(0xFF059669);

                        return Card(
                          elevation: 1.5,
                          shadowColor: Colors.black.withAlpha(20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: s.isExpiringSoon ? Colors.red.shade300 : const Color(0xFFE2E8F0),
                              width: s.isExpiringSoon ? 1.8 : 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            onLongPress: isGroup ? () => _confirmDeleteGroupFromList(context, fb, s) : null,
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: avatarColor.withAlpha(25),
                                  child: isGroup
                                      ? Icon(Icons.groups_rounded, color: avatarColor, size: 22)
                                      : Text(
                                          chatTitle.isNotEmpty ? chatTitle[0].toUpperCase() : 'S',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w800,
                                            color: avatarColor,
                                            fontSize: 18,
                                          ),
                                        ),
                                ),
                                if (s.isExpiringSoon)
                                  const Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: CircleAvatar(
                                      radius: 8,
                                      backgroundColor: Colors.red,
                                      child: Icon(Icons.priority_high_rounded, size: 10, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    chatTitle,
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (s.isExpiringSoon)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: const Text(
                                      'Hampir Hangus!',
                                      style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: isGroup ? Colors.indigo.shade50 : const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isGroup ? 'Grup Kelas' : (isTeacher ? 'Siswa' : s.type.label),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isGroup ? Colors.indigo.shade700 : const Color(0xFF047857),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  latestSnippet,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (s.streakCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: AppColors.flameGradient,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF5722).withAlpha(60),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('🔥', style: TextStyle(fontSize: 13)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${s.streakCount}',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (lastMsg.isNotEmpty)
                                  Text(
                                    AppDateFormatter.formatShortDateTime(lastMsg.last.sentAt),
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (isGroup) ...[
                                  const SizedBox(width: 4),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.black45),
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _confirmDeleteGroupFromList(context, fb, s);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline_rounded, color: AppColors.rose, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              'Hapus Grup',
                                              style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w600, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            onTap: () async {
                              // Ensure streak is in Firestore
                              if (!fb.streaks.any((item) => item.id == s.id)) {
                                await fb.createStreak(s.copyWith(streakCount: 0));
                              }
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatConversationScreen(streak: s),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        );

    if (widget.isEmbedded) {
      return Container(
        color: const Color(0xFFF8FAFC),
        child: SafeArea(
          bottom: false,
          child: mainContent,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: const Color(0xFFFF5722),
        elevation: 4,
        onPressed: () => _showNewStreakDialog(context),
        icon: Icon(
          isTeacher ? Icons.chat_bubble_outline_rounded : Icons.local_fire_department_rounded,
          color: Colors.white,
          size: 18,
        ),
        label: Text(
          isTeacher ? 'Mulai Chat' : 'Streak Baru',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      body: SafeArea(
        child: mainContent,
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudyStreakBanner(BuildContext context, FirebaseService fb, UserModel? user) {
    final studyStreak = fb.getStudyStreak(user?.id);
    final streakCount = (studyStreak != null && !studyStreak.isDead) ? studyStreak.streakCount : 0;
    final isActive = studyStreak != null && !studyStreak.isDead && streakCount > 0;
    final hoursLeft = studyStreak != null && !studyStreak.isDead
        ? studyStreak.expiresAt.difference(DateTime.now()).inHours
        : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [const Color(0xFF7C2D12), const Color(0xFFC2410C), const Color(0xFFEA580C)]
              : [const Color(0xFF1E293B), const Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFFEA580C).withAlpha(80),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(50),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isActive ? '🔥' : '❄️', style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      isActive ? 'Streak Belajar Aktif' : 'Streak Belajar Padam',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                isActive ? '$streakCount Hari' : '0 Hari',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isActive
                ? 'Api belajar Anda menyala! Aktif selama $streakCount hari berturut-turut (sisa: $hoursLeft jam).'
                : 'Streak belajar padam (tidak belajar/chat selama 1 hari). Buka materi, kerjakan tugas, kuis, atau kirim chat hari ini untuk menyalakan api kembali!',
            style: const TextStyle(color: Colors.white, fontSize: 11.5, height: 1.3),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _ActivityMiniChip(icon: Icons.menu_book_rounded, label: 'Materi'),
              SizedBox(width: 6),
              _ActivityMiniChip(icon: Icons.assignment_turned_in_rounded, label: 'Tugas'),
              SizedBox(width: 6),
              _ActivityMiniChip(icon: Icons.quiz_rounded, label: 'Kuis/Ujian'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityMiniChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActivityMiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
