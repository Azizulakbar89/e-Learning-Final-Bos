import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

typedef OnViolationCallback = void Function(String reason, {bool instantLock});

class AntiCheatService with WidgetsBindingObserver {
  static final AntiCheatService _instance = AntiCheatService._internal();
  factory AntiCheatService() => _instance;
  AntiCheatService._internal();

  bool _isActive = false;
  OnViolationCallback? _onViolation;
  DateTime? _wentBackgroundAt;
  Timer? _inactiveDebounceTimer;

  bool get isActive => _isActive;

  /// Activates Zero-Tolerance Lockdown
  Future<void> startLockdown({required OnViolationCallback onViolation}) async {
    _isActive = true;
    _onViolation = onViolation;
    _wentBackgroundAt = null;
    _inactiveDebounceTimer?.cancel();
    _inactiveDebounceTimer = null;
    WidgetsBinding.instance.addObserver(this);

    // Keep screen awake (no screen sleep)
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('Wakelock enable note: $e');
    }

    debugPrint('[AntiCheat] Zero-Tolerance Lockdown Activated.');
  }

  /// Deactivates Lockdown when exam finishes
  Future<void> stopLockdown() async {
    _isActive = false;
    _onViolation = null;
    _wentBackgroundAt = null;
    _inactiveDebounceTimer?.cancel();
    _inactiveDebounceTimer = null;
    WidgetsBinding.instance.removeObserver(this);

    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('Wakelock disable note: $e');
    }

    debugPrint('[AntiCheat] Lockdown Deactivated.');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isActive) return;

    // 1. DI WEB: Pindah tab, minimize browser, atau jendela blur langsung seketika diblokir
    if (kIsWeb) {
      if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden) {
        debugPrint('[AntiCheat Web] Pindah tab / jendela lain terdeteksi -> Instant Lock!');
        _onViolation?.call(
          'Pindah tab / membuka jendela lain terdeteksi di browser Web!',
          instantLock: true,
        );
      }
      return;
    }

    // 2. DI MOBILE (Android / iOS):
    // Jika HP mati total atau sistem OS shutdown mendadak (detached):
    // JANGAN laporkan pelanggaran, agar sesi siswa tidak terkunci saat HP dinyalakan kembali.
    if (state == AppLifecycleState.detached) {
      debugPrint('[AntiCheat Mobile] App detached / OS shutdown / device off -> Diabaikan agar tidak terkunci.');
      return;
    }

    // Jika split-screen, floating window, atau panel notifikasi ditarik (inactive)
    if (state == AppLifecycleState.inactive) {
      _inactiveDebounceTimer?.cancel();
      _inactiveDebounceTimer = Timer(const Duration(milliseconds: 1500), () {
        if (_isActive) {
          debugPrint('[AntiCheat Mobile] Split-screen / floating window / loss of focus terdeteksi!');
          _onViolation?.call(
            'Layar kehilangan fokus / split-screen / floating window terdeteksi!',
            instantLock: true,
          );
        }
      });
      return;
    }

    // Jika aplikasi diminimalkan / pengguna beralih ke aplikasi lain (paused / hidden)
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _inactiveDebounceTimer?.cancel();
      _wentBackgroundAt = DateTime.now();
      debugPrint('[AntiCheat Mobile] Aplikasi masuk background pada $_wentBackgroundAt');
      return;
    }

    // Jika pengguna kembali membuka aplikasi (resumed)
    if (state == AppLifecycleState.resumed) {
      _inactiveDebounceTimer?.cancel();
      if (_wentBackgroundAt != null) {
        final awayDuration = DateTime.now().difference(_wentBackgroundAt!);
        _wentBackgroundAt = null;
        debugPrint('[AntiCheat Mobile] Kembali dari background setelah ${awayDuration.inSeconds} detik -> Terbuka aplikasi lain!');
        _onViolation?.call(
          'Pengguna keluar atau beralih ke aplikasi lain saat ujian!',
          instantLock: true,
        );
      }
    }
  }
}
