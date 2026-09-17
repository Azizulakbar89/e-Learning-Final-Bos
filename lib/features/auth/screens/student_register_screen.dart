import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/input_validators.dart';
import '../../../core/widgets/app_loading_overlay.dart';

class StudentRegisterScreen extends StatefulWidget {
  const StudentRegisterScreen({super.key});

  @override
  State<StudentRegisterScreen> createState() => _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends State<StudentRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nisController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedClass;

  @override
  void dispose() {
    _nisController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_selectedClass == null || _selectedClass!.isEmpty) {
      AppSnackBar.error(
        context,
        'Pilih kelas terlebih dahulu. Jika belum ada kelas, hubungi Admin.',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final fbService = context.read<FirebaseService>();
    final success = await showLoadingDialog(
      context,
      message: 'Mendaftarkan akun siswa...',
      action: () async {
        await fbService.registerStudent(
          nis: _nisController.text.trim(),
          className: _selectedClass!,
          fullName: _nameController.text.trim(),
          password: _passwordController.text.trim(),
        );
      },
      successMessage: 'Pendaftaran berhasil! Selamat datang dan selamat belajar.',
      errorMessage: 'Gagal mendaftar akun.',
    );

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final availableClasses = fb.getAvailableClasses();
    if (_selectedClass != null && !availableClasses.contains(_selectedClass)) {
      _selectedClass = null;
    }
    if (_selectedClass == null && availableClasses.isNotEmpty) {
      _selectedClass = availableClasses.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendaftaran Akun Siswa Baru'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(25),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: AppColors.primary,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Daftar Sebagai Siswa',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Lengkapi data untuk membuat akun',
                                    style: TextStyle(
                                      color: AppColors.textSecondaryLight,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nisController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Nomor Induk Siswa (NIS)',
                            prefixIcon: Icon(Icons.badge_outlined),
                            hintText: 'Contoh: 1001',
                          ),
                          validator: InputValidators.validateNis,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nama Lengkap',
                            prefixIcon: Icon(Icons.person_outline),
                            hintText: 'Nama lengkap sesuai kartu pelajar',
                          ),
                          validator: InputValidators.validateFullName,
                        ),
                        const SizedBox(height: 16),
                        if (availableClasses.isEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.amber.withAlpha(100)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: AppColors.amber, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Belum ada kelas yang diinput oleh Admin. Kelas belum dapat dipilih. Silakan hubungi pihak sekolah/Admin.',
                                    style: TextStyle(fontSize: 12, color: AppColors.amber, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        DropdownButtonFormField<String>(
                          initialValue: _selectedClass,
                          decoration: InputDecoration(
                            labelText: 'Rombongan Belajar (Kelas)',
                            prefixIcon: const Icon(Icons.meeting_room_outlined),
                            helperText: availableClasses.isEmpty
                                ? 'Kelas belum diinput oleh Admin'
                                : null,
                          ),
                          items: availableClasses.isEmpty
                              ? [
                                  const DropdownMenuItem(
                                    value: null,
                                    enabled: false,
                                    child: Text(
                                      'Belum ada kelas (Hubungi Admin)',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                ]
                              : availableClasses.map((c) {
                                  return DropdownMenuItem(value: c, child: Text('Kelas $c'));
                                }).toList(),
                          onChanged: availableClasses.isEmpty
                              ? null
                              : (val) {
                                  if (val != null) setState(() => _selectedClass = val);
                                },
                          validator: (val) {
                            if (availableClasses.isEmpty) {
                              return 'Kelas belum diinput oleh Admin';
                            }
                            if (val == null || val.isEmpty) {
                              return 'Silakan pilih kelas';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password Akun',
                            prefixIcon: Icon(Icons.lock_outline),
                            hintText: 'Minimal 6 karakter',
                          ),
                          validator: InputValidators.validatePassword,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.withAlpha(50)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Catatan: Password Anda akan dapat dilihat oleh Guru pengampu untuk bantuan reset jika terlupa.',
                                  style: TextStyle(fontSize: 12, color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: availableClasses.isEmpty ? null : _handleRegister,
                          child: const Text('Daftar & Masuk Sekarang'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
