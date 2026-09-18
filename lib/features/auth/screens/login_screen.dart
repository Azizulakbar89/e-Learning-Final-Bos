import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/input_validators.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/responsive_layout.dart';
import 'student_register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;
  int _remainingLockoutSeconds = 0;
  String? _errorMessage;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final now = DateTime.now();
      if (_lockoutUntil == null || now.isAfter(_lockoutUntil!)) {
        timer.cancel();
        setState(() {
          _remainingLockoutSeconds = 0;
          _lockoutUntil = null;
        });
      } else {
        setState(() {
          _remainingLockoutSeconds = _lockoutUntil!.difference(now).inSeconds + 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_remainingLockoutSeconds > 0) {
      setState(() {
        _errorMessage = 'Akun dikunci sementara. Tunggu $_remainingLockoutSeconds detik.';
      });
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    final userErr = InputValidators.validateRequired(username, 'Username atau NIS');
    if (userErr != null) {
      setState(() => _errorMessage = userErr);
      return;
    }
    final passErr = InputValidators.validateRequired(password, 'Password');
    if (passErr != null) {
      setState(() => _errorMessage = passErr);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fbService = context.read<FirebaseService>();
      await fbService.login(usernameOrNis: username, password: password);
      _failedAttempts = 0;
    } catch (e) {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        final waitSec = _failedAttempts >= 7 ? 180 : 60;
        _lockoutUntil = DateTime.now().add(Duration(seconds: waitSec));
        _remainingLockoutSeconds = waitSec;
        _startLockoutCountdown();
      }
      if (mounted) {
        setState(() {
          if (_remainingLockoutSeconds > 0) {
            _errorMessage = 'Terlalu banyak percobaan gagal (5x). Akun dikunci sementara selama $_remainingLockoutSeconds detik demi keamanan.';
          } else {
            final sisa = 5 - _failedAttempts;
            final warn = (sisa > 0 && sisa <= 2) ? ' (Sisa $sisa kesempatan sebelum dikunci)' : '';
            _errorMessage = '${e.toString().replaceAll('Exception: ', '')}$warn';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveLayout(
        breakpoint: 900,
        mobile: _buildMobileLayout(),
        desktop: _buildDesktopLayout(),
      ),
    );
  }

  // ─── MOBILE ────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF040D1F), Color(0xFF071540), Color(0xFF0D2B6E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          _buildBgOrbs(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        _buildBrandLogo(),
                        const SizedBox(height: 32),
                        _buildLoginForm(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── DESKTOP ────────────────────────────────────────────────────────────────
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left hero panel
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF040D1F), Color(0xFF0D2B6E), Color(0xFF1A4DB5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                _buildBgOrbs(),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withAlpha(100),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'e-learning spemdalas',
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'SMP Muhammadiyah 12 GKB',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          'Platform Edukasi\nGenerasi Berikutnya.',
                          style: GoogleFonts.outfit(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Belajar lebih cerdas dengan AI Tutor, compiler kode terintegrasi,\n'
                          'ujian anti-cheat, dan gamifikasi streak yang viral.',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Colors.white60,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Feature highlights
                        ..._desktopFeatures.map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: f.color.withAlpha(40),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(f.icon, color: f.color, size: 18),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          f.title,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          f.subtitle,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        const Spacer(),
                        Text(
                          '© 2026 E-Learning SuperApp. Powered by Flutter & Firebase.',
                          style: TextStyle(color: Colors.white.withAlpha(40), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right form panel
        Expanded(
          flex: 4,
          child: Container(
            color: const Color(0xFF040D1F),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Selamat Datang 👋',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Masuk ke akun Anda untuk melanjutkan',
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 36),
                          _buildLoginForm(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── SHARED COMPONENTS ──────────────────────────────────────────────────────
  Widget _buildBrandLogo() {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(120),
                blurRadius: 30,
                spreadRadius: 4,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'e-learning spemdalas',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'SMP Muhammadiyah 12 GKB Gresik',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondaryDark),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return GlassCard(
      color: const Color(0xFF071540),
      borderColor: AppColors.borderDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Masuk ke Akun',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Guru: Username • Siswa: NIS',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.rose.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.rose.withAlpha(100)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.rose, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.rose, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Username field
          _buildTextField(
            controller: _usernameController,
            label: 'Username / NIS',
            prefixIcon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),

          // Password field
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.textSecondaryDark,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 24),

          // Login button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (_isLoading || _remainingLockoutSeconds > 0) ? null : () => _handleLogin(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _remainingLockoutSeconds > 0 ? Colors.grey.shade700 : AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(
                      _remainingLockoutSeconds > 0
                          ? 'Terkunci (${_remainingLockoutSeconds}s)'
                          : 'Masuk Sekarang',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // Register button
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentRegisterScreen()),
              );
            },
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: const Text('Siswa Belum Punya Akun? Daftar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: BorderSide(color: AppColors.accent.withAlpha(150)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
        prefixIcon: Icon(prefixIcon, color: AppColors.primaryLight, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withAlpha(8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
      ),
    );
  }


  // Background decorative orbs
  Widget _buildBgOrbs() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withAlpha(80),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.purple.withAlpha(70),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.sizeOf(context).height * 0.4,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withAlpha(50),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Feature highlights for desktop panel
class _FeatureItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _FeatureItem(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.color});
}

const _desktopFeatures = [
  _FeatureItem(
    title: 'AI Tutor & Bahasa Bayi (ELI5)',
    subtitle: 'Pahami materi rumit dengan cara termudah',
    icon: Icons.auto_awesome_rounded,
    color: AppColors.purple,
  ),
  _FeatureItem(
    title: 'Compiler IDE Terintegrasi',
    subtitle: 'HTML, CSS, JS, PHP, Arduino — in-app',
    icon: Icons.terminal_rounded,
    color: AppColors.emerald,
  ),
  _FeatureItem(
    title: 'Zero-Tolerance Anti-Cheat Exam',
    subtitle: 'Ujian terkunci mutlak dengan pemantauan real-time',
    icon: Icons.security_rounded,
    color: AppColors.rose,
  ),
  _FeatureItem(
    title: 'Streak & Gamifikasi Viral',
    subtitle: 'Poin tukar nilai akademik, streak harian',
    icon: Icons.local_fire_department_rounded,
    color: AppColors.amber,
  ),
];
