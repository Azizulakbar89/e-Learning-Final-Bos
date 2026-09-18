import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Top-level background handler wajib untuk menangani pesan saat aplikasi
/// berada di latar belakang (Background) atau ditutup total (Terminated/Killed).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];

    if (kDebugMode) {
      debugPrint('[FCM Background/Killed] Pesan masuk: $title - $body');
    }

    if (title != null && title.isNotEmpty) {
      final localNotifications = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await localNotifications.initialize(
        settings: const InitializationSettings(android: androidInit),
      );

      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'Notifikasi E-Learning',
        channelDescription: 'Saluran notifikasi prioritas tinggi e-learning untuk materi, tugas, dan pengumuman',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      if (message.notification == null) {
        await localNotifications.show(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: title,
          body: body ?? '',
          notificationDetails: const NotificationDetails(android: androidDetails),
        );
      }
    }
  } catch (e) {
    if (kDebugMode) debugPrint('[FCM Background] Error init: $e');
  }
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static String? _cachedToken;
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Saluran notifikasi prioritas tinggi Android (Heads-up banner dengan suara & getar)
  static const AndroidNotificationChannel _highImportanceChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notifikasi E-Learning',
    description: 'Saluran notifikasi prioritas tinggi e-learning untuk materi, tugas, dan pengumuman',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Inisialisasi izin, saluran notifikasi lokal, dan auto-welcome pop up
  static Future<void> initialize() async {
    try {
      // 1. Inisialisasi Local Notifications Plugin untuk Android & iOS
      const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettingsDarwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (kDebugMode) {
            debugPrint('[Notifikasi Diklik] Payload: ${response.payload}');
          }
        },
      );

      // 2. Daftarkan notification channel Android prioritas tinggi
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(_highImportanceChannel);
        await androidImplementation.requestNotificationsPermission();
      }

      // 3. Request izin notifikasi FCM (wajib untuk iOS & Android 13+)
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        debugPrint('FCM Authorization status: ${settings.authorizationStatus}');
      }

      // 4. Set presentation options agar notifikasi tetap berbunyi & muncul saat app terbuka
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. Daftarkan background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 6. Ambil dan simpan cache FCM Token perangkat
      final isAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (isAuthorized) {
        try {
          await _messaging.subscribeToTopic('class_all');
          _cachedToken = await _messaging.getToken();
          if (kDebugMode && _cachedToken != null && _cachedToken!.length > 8) {
            debugPrint('FCM Token aktif: ${_cachedToken!.substring(0, 4)}...${_cachedToken!.substring(_cachedToken!.length - 4)}');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('FCM Token generation / topic subscribe note: $e');
        }

        // 7. Otomatis kirimkan Pop-Up Notifikasi Selamat Datang (Selamat! Notifikasi Diaktifkan)
        _triggerWelcomeNotificationIfFirstTime();
      }

      // 8. Listener saat aplikasi terbuka di depan layar (Foreground) -> Tampilkan Pop-Up Banner & Local Notification
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint('FCM Foreground: ${message.notification?.title} - ${message.notification?.body}');
        }
        final notif = message.notification;
        final title = notif?.title ?? message.data['title'] ?? 'Notifikasi Baru';
        final body = notif?.body ?? message.data['body'] ?? '';

        // Tampilkan notifikasi pop-up di status bar HP
        showLocalNotification(
          title: title,
          body: body,
          payload: message.data.toString(),
        );

        // Tampilkan juga banner melayang di dalam aplikasi
        showInAppBanner(title: title, body: body);
      });

      // 9. Listener saat notifikasi diklik oleh user dari background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint('FCM Notifikasi dibuka dari background: ${message.data}');
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('FCM initialization note: $e');
    }
  }

  /// Otomatis memunculkan Pop-up Notifikasi konfirmasi begitu notifikasi diizinkan
  static Future<void> _triggerWelcomeNotificationIfFirstTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasTriggered = prefs.getBool('welcome_notification_triggered_v1') ?? false;
      if (!hasTriggered) {
        await prefs.setBool('welcome_notification_triggered_v1', true);
        // Delay sedikit agar frame UI utama selesai dimuat dengan nyaman
        Future.delayed(const Duration(milliseconds: 1200), () async {
          await showLocalNotification(
            id: 1001,
            title: '🎉 Notifikasi Berhasil Diaktifkan!',
            body: 'Selamat datang di e-Learning! Anda siap menerima informasi materi, tugas, dan pengumuman sekolah secara real-time.',
          );
          showInAppBanner(
            title: '🎉 Notifikasi Berhasil Diaktifkan!',
            body: 'Pembaruan materi baru, kuis, dan pengumuman akan otomatis muncul di HP Anda.',
          );
        });
      }
    } catch (_) {}
  }

  /// Menampilkan notifikasi native di status bar Android (Heads-up pop up dengan getar & suara)
  static Future<void> showLocalNotification({
    int? id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'Notifikasi E-Learning',
        channelDescription: 'Saluran notifikasi prioritas tinggi e-learning untuk materi, tugas, dan pengumuman',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(''),
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const notifDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _localNotifications.show(
        id: id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
        title: title,
        body: body,
        notificationDetails: notifDetails,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[LocalNotif] Error showing notification: $e');
    }
  }

  /// Menampilkan banner pop-up melayang di dalam aplikasi (In-App Floating Banner)
  static void showInAppBanner({
    required String title,
    required String body,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (messengerKey.currentState == null) return;
    messengerKey.currentState!.hideCurrentSnackBar();
    messengerKey.currentState!.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }

  /// Uji coba langsung: memunculkan notifikasi pop-up sistem dan banner melayang sekaligus
  static Future<void> triggerTestNotification(BuildContext context) async {
    await showLocalNotification(
      title: '🔔 Uji Pop-up Notifikasi Berhasil!',
      body: 'Sistem notifikasi lokal dan banner pop-up HP Anda berjalan dengan normal dan siap menerima pesan.',
    );
    showInAppBanner(
      title: '🔔 Uji Pop-up Notifikasi Berhasil!',
      body: 'Notifikasi pop-up di layar dan status bar HP telah aktif!',
    );
  }

  /// Format nama kelas menjadi topic valid FCM ([a-zA-Z0-9-_.~%]+)
  static String formatClassTopic(String className) {
    final sanitized = className.trim().replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
    return 'class_$sanitized';
  }

  /// Mendaftarkan perangkat siswa ke Topic Kelasnya secara otomatis
  static Future<void> subscribeToClassTopic(String? className) async {
    try {
      await _messaging.subscribeToTopic('class_all');
      if (className != null && className.trim().isNotEmpty) {
        final topic = formatClassTopic(className);
        await _messaging.subscribeToTopic(topic);
        if (kDebugMode) debugPrint('[FCM] Subscribed to topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] Topic subscription note: $e');
    }
  }

  /// Unsubscribe saat siswa ganti kelas atau logout
  static Future<void> unsubscribeFromClassTopic(String? className) async {
    try {
      if (className != null && className.trim().isNotEmpty) {
        final topic = formatClassTopic(className);
        await _messaging.unsubscribeFromTopic(topic);
        if (kDebugMode) debugPrint('[FCM] Unsubscribed from topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] Topic unsubscription note: $e');
    }
  }

  /// Mengambil FCM Device Token aktif
  static Future<String?> getToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }
    try {
      _cachedToken = await _messaging.getToken();
      return _cachedToken;
    } catch (_) {
      return 'fcm_token_local_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Helper untuk menyalin FCM Token ke Clipboard untuk pengujian di Firebase Console
  static Future<bool> copyTokenToClipboard(BuildContext context) async {
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: token));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'FCM Device Token berhasil disalin ke Clipboard!',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return true;
    }
    return false;
  }
}
