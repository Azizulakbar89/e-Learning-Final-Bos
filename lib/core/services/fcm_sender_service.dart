import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class FcmSenderService {
  static const String _projectId = 'e-learning-b183d';
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/firebase.messaging',
  ];

  static AutoRefreshingAuthClient? _authClient;

  /// Memuat kredensial Service Account dari assets/service-account.json atau Firestore
  static Future<void> initialize() async {
    if (_authClient != null) return;

    // 1. Coba baca dari bundle lokal assets/service-account.json
    try {
      final jsonString = await rootBundle.loadString('assets/service-account.json');
      final data = json.decode(jsonString);
      final credentials = ServiceAccountCredentials.fromJson(data);
      _authClient = await clientViaServiceAccount(credentials, _scopes);
      if (kDebugMode) {
        debugPrint('[FcmSender] Direct FCM Push Sender aktif via assets/service-account.json!');
      }
      return;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FcmSender] Assets service account belum tersedia: $e');
      }
    }

    // 2. Fallback: Baca dari Firestore collection 'system_config' doc 'fcm'
    try {
      final doc = await FirebaseFirestore.instance.collection('system_config').doc('fcm').get();
      if (doc.exists && doc.data() != null) {
        final raw = doc.data()!['service_account_json'] ?? doc.data()!['credentials'];
        if (raw != null) {
          final Map<String, dynamic> data = raw is String ? json.decode(raw) : Map<String, dynamic>.from(raw);
          final credentials = ServiceAccountCredentials.fromJson(data);
          _authClient = await clientViaServiceAccount(credentials, _scopes);
          if (kDebugMode) {
            debugPrint('[FcmSender] Direct FCM Push Sender aktif via Firestore system_config/fcm!');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FcmSender] Firestore config note: $e');
      }
    }
  }

  /// Kirim push notifikasi langsung ke token perangkat spesifik (misal: Chat pribadi)
  static Future<bool> sendToDevice({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    return _sendFcmPayload({
      'message': {
        'token': fcmToken,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': data ?? {},
        'android': {
          'priority': 'HIGH',
          'notification': {
            'channel_id': 'high_importance_channel',
            'notification_priority': 'PRIORITY_HIGH',
            'default_sound': true,
            'default_vibrate_timings': true,
          },
        },
      },
    });
  }

  /// Kirim push notifikasi langsung ke topik kelas atau topik umum (misal: Materi / Ujian baru)
  static Future<bool> sendToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final sanitizedTopic = topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
    return _sendFcmPayload({
      'message': {
        'topic': sanitizedTopic,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': data ?? {},
        'android': {
          'priority': 'HIGH',
          'notification': {
            'channel_id': 'high_importance_channel',
            'notification_priority': 'PRIORITY_HIGH',
            'default_sound': true,
            'default_vibrate_timings': true,
          },
        },
      },
    });
  }

  static Future<bool> _sendFcmPayload(Map<String, dynamic> payload) async {
    if (_authClient == null) {
      await initialize();
    }
    if (_authClient == null) {
      return false;
    }

    try {
      final url = Uri.parse('https://fcm.googleapis.com/v1/projects/$_projectId/messages:send');
      final res = await _authClient!.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (res.statusCode == 200) {
        if (kDebugMode) debugPrint('[FcmSender] Sinyal push notifikasi instan berhasil dikirim ke Google FCM!');
        return true;
      } else {
        if (kDebugMode) debugPrint('[FcmSender] Gagal mengirim push FCM: ${res.statusCode} - ${res.body}');
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FcmSender] Error: $e');
      return false;
    }
  }
}
