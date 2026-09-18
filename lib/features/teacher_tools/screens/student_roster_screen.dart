import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/curved_header_card.dart';

class StudentRosterScreen extends StatefulWidget {
  const StudentRosterScreen({super.key});

  @override
  State<StudentRosterScreen> createState() => _StudentRosterScreenState();
}

class _StudentRosterScreenState extends State<StudentRosterScreen> {
  String _selectedClassFilter = 'Semua Kelas';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final fbService = context.watch<FirebaseService>();
    final currentUser = fbService.currentUser;
    final allStudents = fbService.allStudents;

    // Filter students taught by this teacher
    final taughtClasses = fbService.getTeacherClasses(currentUser);
    final filterItems = ['Semua Kelas', ...taughtClasses];
    final activeFilter = filterItems.contains(_selectedClassFilter) ? _selectedClassFilter : 'Semua Kelas';

    final filteredStudents = taughtClasses.isEmpty
        ? <UserModel>[]
        : allStudents.where((s) {
            final sClass = (s.className ?? s.classId ?? '').trim();
            final matchesTaught = taughtClasses.any((tc) =>
                tc.toLowerCase() == sClass.toLowerCase() ||
                tc.toLowerCase() == (s.classId ?? '').trim().toLowerCase());
            if (!matchesTaught) return false;
            if (activeFilter != 'Semua Kelas' &&
                sClass.toLowerCase() != activeFilter.toLowerCase() &&
                (s.classId ?? '').trim().toLowerCase() != activeFilter.toLowerCase()) {
              return false;
            }
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              return s.fullName.toLowerCase().contains(q) || (s.nis?.contains(q) ?? false);
            }
            return true;
          }).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const CurvedHeaderCard(
              title: 'Data Siswa & Kredensial Akun',
              subtitle: 'Manajemen Akun & Reset Kredensial Siswa',
            ),
          // Header description
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primary.withAlpha(15),
            child: Row(
              children: [
                const Icon(Icons.security_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Guru pengampu berhak melihat NIS dan password akun siswa binaan untuk keperluan pendampingan teknis dan reset sandi di sekolah.',
                    style: TextStyle(fontSize: 12, color: AppColors.primaryDark),
                  ),
                ),
              ],
            ),
          ),

          // Taught classes info pill
          if (taughtClasses.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.groups_rounded, size: 15, color: Color(0xFF1E3A8A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Menampilkan ${filteredStudents.length} siswa binaan • Kelas: ${taughtClasses.join(", ")}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                    ),
                  ),
                ],
              ),
            ),

          // Filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau NIS siswa...',
                      prefixIcon: const Icon(Icons.search),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: activeFilter,
                  items: filterItems.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedClassFilter = val);
                  },
                ),
              ],
            ),
          ),

          // Student List
          Expanded(
              child: filteredStudents.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.school_outlined, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              taughtClasses.isEmpty
                                  ? 'Belum Ada Kelas yang Diplot Oleh Admin'
                                  : 'Tidak Ada Siswa Ditemukan',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              taughtClasses.isEmpty
                                  ? 'Akun guru Anda belum diplot ke kelas manapun. Data siswa akan tampil secara otomatis setelah Admin menugaskan rombel kelas untuk Anda.'
                                  : 'Tidak ada siswa yang sesuai dengan filter atau kata kunci pencarian.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
                    itemCount: filteredStudents.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final student = filteredStudents[index];

                      // Calculate mock/live subject grade average
                      final studentExams = fbService.examSessions
                          .where((es) => es.studentId == student.id && es.finalScore != null)
                          .toList();
                      final avgGrade = studentExams.isNotEmpty
                          ? studentExams.map((e) => e.finalScore!).reduce((a, b) => a + b) / studentExams.length
                          : 88.5; // Baseline good score

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
                                  CircleAvatar(
                                    backgroundColor: AppColors.primaryLight.withAlpha(50),
                                    child: Text(
                                      student.fullName.isNotEmpty ? student.fullName[0] : 'S',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          student.fullName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text(
                                          'Kelas: ${student.classId ?? "-"} • NIS: ${student.nis ?? "-"}',
                                          style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.emerald.withAlpha(20),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.grade_rounded, size: 16, color: AppColors.emerald),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Nilai: ${avgGrade.toStringAsFixed(1)}',
                                          style: const TextStyle(
                                            color: AppColors.emerald,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),

                              // Credential Display for Teacher
                              Row(
                                children: [
                                  const Icon(Icons.key_rounded, size: 16, color: AppColors.amber),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Password Akun Siswa: ',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  SelectableText(
                                    student.initialPassword ?? 'siswa12345',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Poin: ${student.totalPoints} 🌟',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                  ),
                                ],
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
