import 'dart:ui' show PlatformDispatcher;
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/background_sync_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/firebase_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_update_dialog.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/admin_home_screen.dart';
import 'features/home/screens/student_home_screen.dart';
import 'features/home/screens/teacher_home_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Guard against Flutter Web CanvasKit internal hot-restart context loss
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains('_handledContextLostEvent')) {
      return; // Ignored engine-level hot-restart WebGL event
    }
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (error.toString().contains('_handledContextLostEvent')) {
      return true; // Handled async CanvasKit context-loss glitch
    }
    return false;
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FcmService.initialize();
    await BackgroundSyncService.initialize();
  } catch (e) {
    debugPrint('Firebase Core init note: $e');
  }

  // Initialize and seed reactive data
  final firebaseService = FirebaseService();
  await firebaseService.initializeAndSeed();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<FirebaseService>.value(value: firebaseService),
      ],
      child: const ELearningSuperApp(),
    ),
  );
}

class ELearningSuperApp extends StatelessWidget {
  const ELearningSuperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'e-learning spemdalas',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: FcmService.messengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  bool _updateChecked = false;
  DateTime? _lastUpdateCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Delay 2 detik agar proses login selesai dulu sebelum popup muncul
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _checkAutoUpdate(force: false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Dipanggil saat app kembali dari background (resume)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Cek update saat resume, tapi max 1x per jam agar tidak spam
      final now = DateTime.now();
      final lastCheck = _lastUpdateCheck;
      if (lastCheck == null || now.difference(lastCheck).inHours >= 1) {
        _checkAutoUpdate(force: false);
      }
    }
  }

  Future<void> _checkAutoUpdate({bool force = false}) async {
    // Kalau force = false dan sudah cek dalam sesi ini, skip
    if (!force && _updateChecked) return;
    _updateChecked = true;
    _lastUpdateCheck = DateTime.now();
    try {
      final fbService = context.read<FirebaseService>();
      final result = await fbService.checkForAppUpdate();
      if (!mounted) return;
      if (result.hasUpdate) {
        final prefs = await SharedPreferences.getInstance();
        final dismissedVersion = prefs.getString('dismissed_update_version');
        final dismissedAt = prefs.getInt('dismissed_update_at') ?? 0;
        final dismissedTime = DateTime.fromMillisecondsSinceEpoch(dismissedAt);
        final hoursSinceDismiss = DateTime.now().difference(dismissedTime).inHours;

        // Skip hanya jika versi sama DAN belum 24 jam sejak dismiss
        // (Force update tidak bisa di-skip)
        if (!result.isForceUpdate &&
            dismissedVersion == result.serverVersion?.latestVersion &&
            hoursSinceDismiss < 24) {
          return;
        }
        if (!mounted) return;
        AppUpdateDialog.show(context, result);
      }
    } catch (e) {
      debugPrint('[AutoUpdate] Check error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fbService = context.watch<FirebaseService>();
    final user = fbService.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    if (user.isAdmin) {
      return const AdminHomeScreen();
    }

    if (user.isGuru) {
      return const TeacherHomeScreen();
    }

    return const StudentHomeScreen();
  }
}
