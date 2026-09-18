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
      title: 'E-Learning SuperApp',
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

class _AuthGateState extends State<AuthGate> {
  bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAutoUpdate());
  }

  Future<void> _checkAutoUpdate() async {
    if (_updateChecked) return;
    _updateChecked = true;
    try {
      final fbService = context.read<FirebaseService>();
      final result = await fbService.checkForAppUpdate();
      if (result.hasUpdate && mounted) {
        final prefs = await SharedPreferences.getInstance();
        final dismissedVersion = prefs.getString('dismissed_update_version');
        if (!result.isForceUpdate && dismissedVersion == result.serverVersion?.latestVersion) {
          return;
        }
        if (!mounted) return;
        AppUpdateDialog.show(context, result);
      }
    } catch (_) {}
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
