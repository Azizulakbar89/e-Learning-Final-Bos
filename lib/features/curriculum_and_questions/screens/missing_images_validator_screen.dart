import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/question_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/curved_header_card.dart';

class MissingImagesValidatorScreen extends StatelessWidget {
  final String subjectId;

  const MissingImagesValidatorScreen({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context) {
    final fbService = context.watch<FirebaseService>();
    final missingQuestions = fbService.getMissingImageQuestions(subjectId);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const CurvedHeaderCard(
              title: 'Validasi Soal Hilang Gambar',
              subtitle: 'Pemeriksaan Referensi Lampiran Gambar',
            ),
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.amber.withAlpha(25),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.amber, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sistem mendeteksi soal-soal hasil impor PDF yang mengandung kalimat rujukan gambar (misal: "Perhatikan gambar di bawah...") namun belum memiliki lampiran media gambar.',
                    style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: missingQuestions.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 56, color: AppColors.emerald),
                        SizedBox(height: 12),
                        Text(
                          'Semua Soal Lengkap & Valid! 🎉',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tidak ada butir soal yang kehilangan referensi gambar.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: missingQuestions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final q = missingQuestions[index];
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.amber),
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
                                      color: AppColors.amber.withAlpha(30),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      '⚠️ Gambar Belum Terlampir',
                                      style: TextStyle(
                                        color: AppColors.amber,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(q.type.label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                q.content,
                                style: const TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                                  label: const Text('Lampirkan Gambar Sekarang'),
                                  onPressed: () {
                                    // Attach simulated image URL and clear missing flag
                                    fbService.resolveMissingImage(
                                      q.id,
                                      'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500',
                                    );
                                    AppSnackBar.success(
                                      context,
                                      'Gambar berhasil dilampirkan & flag validasi telah bersih!',
                                    );
                                  },
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
