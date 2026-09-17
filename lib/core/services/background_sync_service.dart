import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// Top-level callback dispatcher wajib untuk WorkManager Android
/// Fungsi ini dieksekusi oleh OS Android di latar belakang meskipun aplikasi ditutup total (Killed/Terminated)
@pragma('vm:entry-point')
void backgroundSyncCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp();

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('auth_session_user_id');
      final userClass = prefs.getString('auth_session_user_class');
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Ambil timestamp pengecekan terakhir (default 3 jam lalu jika belum pernah)
      final lastCheckMs = prefs.getInt('last_bg_notif_sync_ts') ?? (nowMs - (3 * 3600 * 1000));

      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('created_at', descending: true)
          .limit(15)
          .get();

      if (snap.docs.isEmpty) {
        await prefs.setInt('last_bg_notif_sync_ts', nowMs);
        return Future.value(true);
      }

      final localNotif = FlutterLocalNotificationsPlugin();
      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'Notifikasi E-Learning',
        channelDescription: 'Saluran notifikasi untuk materi belajar, tugas, kuis, dan pengumuman sekolah',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(''),
      );

      const notifDetails = NotificationDetails(android: androidDetails);

      int newestTimestampSeen = lastCheckMs;

      for (final doc in snap.docs) {
        final data = doc.data();
        DateTime? createdAt;
        final rawCreated = data['created_at'];
        if (rawCreated is Timestamp) {
          createdAt = rawCreated.toDate();
        } else if (rawCreated is String) {
          createdAt = DateTime.tryParse(rawCreated);
        }

        final notifMs = createdAt?.millisecondsSinceEpoch ?? 0;
        if (notifMs <= lastCheckMs) {
          continue;
        }

        if (notifMs > newestTimestampSeen) {
          newestTimestampSeen = notifMs;
        }

        final title = data['title']?.toString() ?? 'Pemberitahuan Baru';
        final body = data['body']?.toString() ?? 'Buka aplikasi e-Learning untuk melihat detailnya.';
        final targetClasses = List<String>.from(data['target_class_ids'] ?? []);
        final targetUsers = List<String>.from(data['target_user_ids'] ?? []);

        // Filter apakah ditujukan untuk kelas atau user ini
        final forClass = targetClasses.isEmpty ||
            (userClass != null && targetClasses.any((c) => c.toLowerCase() == userClass.toLowerCase()));
        final forUser = targetUsers.isEmpty ||
            (userId != null && targetUsers.contains(userId));

        if (forClass && forUser) {
          await localNotif.show(
            id: doc.id.hashCode,
            title: title,
            body: body,
            notificationDetails: notifDetails,
          );
        }
      }

      await prefs.setInt('last_bg_notif_sync_ts', newestTimestampSeen > lastCheckMs ? newestTimestampSeen : nowMs);
      return Future.value(true);
    } catch (e) {
      if (kDebugMode) debugPrint('[WorkManager] Background task error: $e');
      return Future.value(false);
    }
  });
}

class BackgroundSyncService {
  static const String periodicTaskName = 'elearning_periodic_notif_sync';

  /// Inisialisasi Android WorkManager untuk sinkronisasi notifikasi saat app ditutup
  static Future<void> initialize() async {
    // WorkManager hanya didukung secara penuh di Android & iOS
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await Workmanager().initialize(
          backgroundSyncCallbackDispatcher,
        );

        await Workmanager().registerPeriodicTask(
          periodicTaskName,
          'sync_notifications_task',
          frequency: const Duration(minutes: 15),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
        );
        if (kDebugMode) debugPrint('[WorkManager] Periodic notification sync task registered');
      } catch (e) {
        if (kDebugMode) debugPrint('[WorkManager] Error initializing: $e');
      }
    }
  }

  /// Memperbarui informasi profil pengguna aktif ke memori lokal agar dapat dibaca oleh WorkManager
  static Future<void> saveUserSyncContext({required String userId, String? userClass}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_session_user_id', userId);
      if (userClass != null && userClass.isNotEmpty) {
        await prefs.setString('auth_session_user_class', userClass);
      }
    } catch (_) {}
  }
}
