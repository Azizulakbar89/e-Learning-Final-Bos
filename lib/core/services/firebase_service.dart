import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/user_model.dart';
import '../models/curriculum_model.dart';
import '../models/question_model.dart';
import '../models/material_model.dart';
import '../models/assignment_model.dart';
import '../models/exam_model.dart';
import '../models/streak_model.dart';
import '../models/gamification_model.dart';
import '../models/school_class_model.dart';
import '../models/notification_model.dart';
import '../models/app_version_model.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/security_utils.dart';
import 'content_filter_service.dart';
import 'fcm_service.dart';
import 'fcm_sender_service.dart';

class FirebaseService extends ChangeNotifier {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get db => FirebaseFirestore.instance;
  final _uuid = const Uuid();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  // Reactive stores populated directly from Cloud Firestore in real-time
  final List<SubjectModel> _subjects = [];
  final List<CurriculumCpModel> _cps = [];
  final List<CurriculumTpModel> _tps = [];
  final List<QuestionModel> _questions = [];
  final List<MaterialModel> _materials = [];
  final List<ForumMessageModel> _forumMessages = [];
  final List<AssignmentModel> _assignments = [];
  final List<AssignmentSubmissionModel> _submissions = [];
  final List<ExamModel> _exams = [];
  final List<ExamSessionModel> _examSessions = [];
  final List<StreakModel> _streaks = [];
  final List<ChatMessageModel> _chatMessages = [];
  final List<UserModel> _allStudents = [];
  final List<UserModel> _allTeachers = [];
  final List<PointTransactionModel> _pointTransactions = [];
  final List<GradeRedeemModel> _gradeRedeems = [];
  final List<SchoolClassModel> _schoolClasses = [];
  final List<AppNotificationModel> _notifications = [];
  bool _isFirstNotificationBatch = true;
  final Map<String, double> _materialProgress = {};
  final Map<String, List<String>> _studentCodeRuns = {};

  List<SubjectModel> get subjects => List.unmodifiable(_subjects);
  List<CurriculumCpModel> get cps => List.unmodifiable(_cps);
  List<CurriculumTpModel> get tps => List.unmodifiable(_tps);
  List<QuestionModel> get questions => List.unmodifiable(_questions);
  List<MaterialModel> get materials => List.unmodifiable(_materials);
  List<AssignmentModel> get assignments => List.unmodifiable(_assignments);
  List<AssignmentSubmissionModel> get submissions => List.unmodifiable(_submissions);
  List<ExamModel> get exams => List.unmodifiable(_exams);
  List<ExamSessionModel> get examSessions => List.unmodifiable(_examSessions);
  List<StreakModel> get streaks => List.unmodifiable(_streaks);
  List<ChatMessageModel> get chatMessages => List.unmodifiable(_chatMessages);
  List<UserModel> get allStudents => List.unmodifiable(_allStudents);
  List<UserModel> get allTeachers => List.unmodifiable(_allTeachers);
  List<PointTransactionModel> get pointTransactions => List.unmodifiable(_pointTransactions);
  List<GradeRedeemModel> get gradeRedeems => List.unmodifiable(_gradeRedeems);
  List<SchoolClassModel> get schoolClasses => List.unmodifiable(_schoolClasses);
  List<AppNotificationModel> get notifications => List.unmodifiable(_notifications);

  AppVersionModel? _appVersionConfig;
  AppVersionModel? get appVersionConfig => _appVersionConfig;

  bool _initialized = false;
  final List<StreamSubscription> _subscriptions = [];
  static const String _sessionKey = 'auth_session_user_id';

  /// Simpan ID pengguna ke penyimpanan lokal agar sesi tidak hilang saat aplikasi ditutup
  Future<void> _saveUserSession(String userId, [String? userClass]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, userId);
      if (userClass != null && userClass.isNotEmpty) {
        await prefs.setString('auth_session_user_class', userClass);
      }
      debugPrint('[Session] User session saved: $userId (class: $userClass)');
    } catch (e) {
      debugPrint('[Session] Error saving session: $e');
    }
  }

  /// Hapus sesi dari penyimpanan lokal saat logout
  Future<void> _clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      await prefs.remove('auth_session_user_class');
      debugPrint('[Session] User session cleared');
    } catch (e) {
      debugPrint('[Session] Error clearing session: $e');
    }
  }

  /// Pulihkan sesi pengguna yang tersimpan saat aplikasi pertama kali dinyalakan
  Future<void> _restoreUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString(_sessionKey);
      if (savedUserId == null || savedUserId.isEmpty) return;

      debugPrint('[Session] Memulihkan sesi pengguna tersimpan: $savedUserId');

      // 1. Cek di cache memori pengguna jika sudah terisi
      UserModel? user = _allStudents.where((u) => u.id == savedUserId).firstOrNull ??
          _allTeachers.where((u) => u.id == savedUserId).firstOrNull;

      // 2. Jika belum ada di memori lokal, ambil dokumen langsung dari Cloud Firestore
      if (user == null) {
        try {
          final doc = await db.collection('users').doc(savedUserId).get();
          if (doc.exists && doc.data() != null) {
            user = UserModel.fromMap(doc.data()!, id: doc.id);
            if (user.isSiswa && !_allStudents.any((s) => s.id == user!.id)) {
              _allStudents.add(user);
            } else if (user.isGuru && !_allTeachers.any((t) => t.id == user!.id)) {
              _allTeachers.add(user);
            }
          }
        } catch (e) {
          debugPrint('[Session] Note fetching user from Firestore: $e');
        }
      }

      // 3. Fallback jika akun default admin_1 atau teacher_budi
      if (user == null) {
        if (savedUserId == 'admin_1') {
          user = UserModel(
            id: 'admin_1',
            username: 'admin',
            fullName: 'Administrator Sekolah',
            role: 'admin',
            initialPassword: 'admin',
          );
        } else if (savedUserId == 'teacher_budi') {
          user = UserModel(
            id: 'teacher_budi',
            username: 'guru',
            fullName: 'Budi Santoso, M.Kom.',
            role: 'guru',
            initialPassword: 'guru',
            subjectIds: [],
            classIds: [],
          );
        }
      }

      if (user != null) {
        _currentUser = user;
        notifyListeners();
        unawaited(syncFcmToken(user.id));
        debugPrint('[Session] Sesi berhasil dipulihkan untuk: ${user.fullName} (${user.role})');
      }
    } catch (e) {
      debugPrint('[Session] Error restoring user session: $e');
    }
  }

  /// Initialize real-time synchronization with Cloud Firestore
  Future<void> initializeAndSeed() async {
    if (_initialized) return;
    _initialized = true;

    _initFirestoreStreams();
    await _ensureInitialMasterAccounts();
    await _checkAndPerformInitialWipe();
    await _restoreUserSession();
  }

  /// Real-time live subscriptions to Cloud Firestore collections
  void _initFirestoreStreams() {
    try {
      // 1. Users
      _subscriptions.add(
        db.collection('users').snapshots().listen((snap) {
          _allStudents.clear();
          _allTeachers.clear();
          for (final doc in snap.docs) {
            final u = UserModel.fromMap(doc.data(), id: doc.id);
            if (u.isSiswa) {
              _allStudents.add(u);
            } else if (u.isGuru) {
              _allTeachers.add(u);
            }
            if (_currentUser != null && _currentUser!.id == u.id) {
              _currentUser = u;
            }
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] Users stream note: $e')),
      );

      // 2. Materials
      _subscriptions.add(
        db.collection('materials').snapshots().listen((snap) {
          _materials.clear();
          for (final doc in snap.docs) {
            _materials.add(MaterialModel.fromMap(doc.data(), id: doc.id));
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] Materials stream note: $e')),
      );

      // 3. Exams
      _subscriptions.add(
        db.collection('exams').snapshots().listen((snap) {
          _exams.clear();
          for (final doc in snap.docs) {
            _exams.add(ExamModel.fromMap(doc.data(), id: doc.id));
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] Exams stream note: $e')),
      );

      // 4. Questions
      _subscriptions.add(
        db.collection('questions').snapshots().listen((snap) {
          _questions.clear();
          for (final doc in snap.docs) {
            _questions.add(QuestionModel.fromMap(doc.data(), id: doc.id));
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] Questions stream note: $e')),
      );

      // 5. Exam Sessions
      _subscriptions.add(
        db.collection('exam_sessions').snapshots().listen((snap) {
          _examSessions.clear();
          for (final doc in snap.docs) {
            _examSessions.add(ExamSessionModel.fromMap(doc.data(), id: doc.id));
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] Exam sessions stream note: $e')),
      );

      // 6. Subjects
      _subscriptions.add(
        db.collection('subjects').snapshots().listen((snap) {
          _subjects.clear();
          for (final doc in snap.docs) {
            _subjects.add(SubjectModel.fromMap(doc.data(), id: doc.id));
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] Subjects stream note: $e')),
      );

      // 7. CPs
      _subscriptions.add(
        db.collection('cps').snapshots().listen((snap) {
          _cps.clear();
          for (final doc in snap.docs) {
            _cps.add(CurriculumCpModel.fromMap(doc.data(), id: doc.id));
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] CPs stream note: $e')),
      );

      // 8. TPs
      _subscriptions.add(
        db.collection('tps').snapshots().listen((snap) {
          _tps.clear();
          for (final doc in snap.docs) {
            _tps.add(CurriculumTpModel.fromMap(doc.data(), id: doc.id));
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] TPs stream note: $e')),
      );

      // 9. Assignments
      _subscriptions.add(
        db.collection('assignments').snapshots().listen((snap) {
          _assignments.clear();
          for (final doc in snap.docs) {
            _assignments.add(AssignmentModel.fromMap(doc.data(), id: doc.id));
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] Assignments stream note: $e')),
      );

      // 10. Submissions
      _subscriptions.add(
        db.collection('assignment_submissions').snapshots().listen((snap) {
          _submissions.clear();
          for (final doc in snap.docs) {
            _submissions.add(AssignmentSubmissionModel.fromMap(doc.data(), id: doc.id));
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] Submissions stream note: $e')),
      );

      // 11. Streaks
      _subscriptions.add(
        db.collection('streaks').snapshots().listen((snap) {
          _streaks.clear();
          for (final doc in snap.docs) {
            _streaks.add(StreakModel.fromMap(doc.data(), id: doc.id));
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] Streaks stream note: $e')),
      );

      // 12. Chat Messages
      _subscriptions.add(
        db.collection('chat_messages').snapshots().listen((snap) {
          _chatMessages.clear();
          for (final doc in snap.docs) {
            _chatMessages.add(ChatMessageModel.fromMap(doc.data(), id: doc.id));
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] Chat messages stream note: $e')),
      );

      // 13. Forum Messages
      _subscriptions.add(
        db.collection('forum_messages').snapshots().listen((snap) {
          _forumMessages.clear();
          for (final doc in snap.docs) {
            _forumMessages.add(ForumMessageModel.fromMap(doc.data(), id: doc.id));
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] Forum messages stream note: $e')),
      );

      // 14. Point Transactions
      _subscriptions.add(
        db.collection('point_transactions').snapshots().listen((snap) {
          _pointTransactions.clear();
          for (final doc in snap.docs) {
            _pointTransactions.add(PointTransactionModel.fromMap(doc.data(), id: doc.id));
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] Point transactions stream note: $e')),
      );

      // 15. Grade Redeems
      _subscriptions.add(
        db.collection('grade_redeems').snapshots().listen((snap) {
          _gradeRedeems.clear();
          for (final doc in snap.docs) {
            _gradeRedeems.add(GradeRedeemModel.fromMap(doc.data(), id: doc.id));
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] Grade redeems stream note: $e')),
      );

      // 16. School Classes (Input by Admin)
      _subscriptions.add(
        db.collection('classes').snapshots().listen((snap) {
          _schoolClasses.clear();
          for (final doc in snap.docs) {
            _schoolClasses.add(SchoolClassModel.fromMap(doc.data(), id: doc.id));
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] Classes stream note: $e')),
      );

      // 17. Group Registrations
      _subscriptions.add(
        db.collection('group_registrations').snapshots().listen((snap) {
          _groupRegistrations.clear();
          for (final doc in snap.docs) {
            _groupRegistrations.add(GroupRegistrationModel.fromMap(doc.data(), id: doc.id));
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] Group registrations stream note: $e')),
      );

      // 18. Material Learning Progress per Student
      _subscriptions.add(
        db.collection('material_progress').snapshots().listen((snap) {
          _materialProgress.clear();
          for (final doc in snap.docs) {
            final data = doc.data();
            final sid = data['studentId']?.toString() ?? '';
            final mid = data['materialId']?.toString() ?? '';
            if (sid.isNotEmpty && mid.isNotEmpty) {
              final key = '${sid}_$mid';
              _materialProgress[key] = (data['progress'] as num?)?.toDouble() ?? 0.0;
            }
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] Material progress stream note: $e')),
      );

      // 19. Class-Targeted Notifications (Materi & Kuis/Ujian)
      _subscriptions.add(
        db.collection('notifications').snapshots().listen((snap) {
          final isInitial = _isFirstNotificationBatch;
          _isFirstNotificationBatch = false;

          final newDocs = <AppNotificationModel>[];
          for (final change in snap.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data != null) {
                final model = AppNotificationModel.fromMap(data, id: change.doc.id);
                if (!isInitial) {
                  newDocs.add(model);
                }
              }
            }
          }

          _notifications.clear();
          for (final doc in snap.docs) {
            _notifications.add(AppNotificationModel.fromMap(doc.data(), id: doc.id));
          }
          _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          notifyListeners();

          // Jika ada notifikasi baru secara live, langsung munculkan pop-up lokal & banner!
          if (!isInitial && newDocs.isNotEmpty) {
            final userClass = _currentUser?.className ?? _currentUser?.classId;
            final userId = _currentUser?.id;

            for (final notif in newDocs) {
              final forClass = notif.targetClassIds.isEmpty ||
                  (userClass != null && notif.targetClassIds.contains(userClass));
              final forUser = notif.targetUserIds.isEmpty ||
                  (userId != null && notif.targetUserIds.contains(userId));

              if (forClass && forUser) {
                FcmService.showLocalNotification(
                  title: notif.title,
                  body: notif.body,
                );
                FcmService.showInAppBanner(
                  title: notif.title,
                  body: notif.body,
                );
              }
            }
          }
        }, onError: (e) => debugPrint('[Firestore] Notifications stream note: $e')),
      );

      // 20. App Version & In-App Update Configuration
      _subscriptions.add(
        db.collection('system_info').doc('app_version').snapshots().listen((doc) {
          if (!doc.exists || doc.data() == null) {
            final defaultVer = AppVersionModel(
              latestVersion: '1.0.0',
              versionCode: 1,
              minSupportedVersionCode: 1,
              apkUrl: '',
              releaseNotes: 'Versi rilis awal E-Learning SuperApp.',
              releasedAt: DateTime.now(),
              forceUpdate: false,
            );
            _appVersionConfig = defaultVer;
            try {
              db.collection('system_info').doc('app_version').set(defaultVer.toMap());
            } catch (_) {}
          } else {
            _appVersionConfig = AppVersionModel.fromMap(doc.data()!);
          }
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] App version stream note: $e')),
      );
    } catch (e) {
      debugPrint('[Firestore] Note initializing streams: $e');
    }
  }

  /// Pengecekan otomatis apakah ada versi APK baru yang dirilis
  Future<AppUpdateCheckResult> checkForAppUpdate() async {
    String currentVer = '1.0.0';
    int currentCode = 1;
    try {
      final info = await PackageInfo.fromPlatform();
      currentVer = info.version;
      currentCode = int.tryParse(info.buildNumber) ?? 1;
    } catch (e) {
      debugPrint('[UpdateChecker] Note reading PackageInfo: $e');
    }

    if (_appVersionConfig == null) {
      try {
        final doc = await db.collection('system_info').doc('app_version').get();
        if (doc.exists && doc.data() != null) {
          _appVersionConfig = AppVersionModel.fromMap(doc.data()!);
        }
      } catch (e) {
        debugPrint('[UpdateChecker] Note fetching server version: $e');
      }
    }

    final server = _appVersionConfig;
    final effectiveServer = (server != null && server.versionCode > 1)
        ? server
        : AppVersionModel(
            latestVersion: '1.0.1',
            versionCode: 2,
            minSupportedVersionCode: 1,
            apkUrl: server?.apkUrl ?? '',
            releaseNotes: server?.releaseNotes.isNotEmpty == true
                ? server!.releaseNotes
                : 'Pembaruan aplikasi: perbaikan performa, notifikasi pop-up otomatis, dan in-app installer.',
            releasedAt: DateTime.now(),
            forceUpdate: false,
          );

    final isNewerCode = effectiveServer.versionCode > currentCode;
    final semverDiff = _compareSemver(currentVer, effectiveServer.latestVersion);
    final isSameOrNewerVersion = semverDiff >= 0;

    // Ada update HANYA jika server memiliki versionCode lebih tinggi DAN string versi server lebih tinggi dari yang terpasang
    final hasUpdate = isNewerCode && !isSameOrNewerVersion;
    final isForceUpdate = hasUpdate && (effectiveServer.forceUpdate || effectiveServer.minSupportedVersionCode > currentCode);

    return AppUpdateCheckResult(
      hasUpdate: hasUpdate,
      isForceUpdate: isForceUpdate,
      currentVersion: currentVer,
      currentVersionCode: currentCode,
      serverVersion: effectiveServer,
    );
  }

  /// Helper untuk membandingkan format versi semver (misal: 1.0.1 vs 1.0.0)
  int _compareSemver(String v1, String v2) {
    try {
      final p1 = v1.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final p2 = v2.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map((e) => int.tryParse(e) ?? 0).toList();
      while (p1.length < 3) {
        p1.add(0);
      }
      while (p2.length < 3) {
        p2.add(0);
      }
      for (int i = 0; i < 3; i++) {
        if (p1[i] > p2[i]) return 1;
        if (p1[i] < p2[i]) return -1;
      }
      return 0;
    } catch (_) {
      return v1 == v2 ? 0 : -1;
    }
  }

  /// Mempublikasikan rilis APK pembaruan aplikasi baru (Khusus Admin)
  Future<void> publishAppUpdate({
    required String version,
    required int versionCode,
    required String apkUrl,
    required String releaseNotes,
    bool forceUpdate = false,
  }) async {
    final model = AppVersionModel(
      latestVersion: version.trim(),
      versionCode: versionCode,
      apkUrl: apkUrl.trim(),
      releaseNotes: releaseNotes.trim(),
      releasedAt: DateTime.now(),
      forceUpdate: forceUpdate,
    );

    await db.collection('system_info').doc('app_version').set(model.toMap());
    _appVersionConfig = model;
    notifyListeners();

    unawaited(createNotification(
      title: '🚀 Pembaruan Aplikasi v$version Tersedia!',
      body: releaseNotes.isNotEmpty ? releaseNotes : 'Silakan perbarui aplikasi untuk menikmati fitur dan stabilitas terbaru.',
      type: 'announcement',
    ));
  }

  /// Automatically provision master accounts in Firestore if the database has 0 users
  Future<void> _ensureInitialMasterAccounts() async {
    try {
      final snap = await db.collection('users').limit(1).get();
      if (snap.docs.isEmpty) {
        // Master Admin
        final admin = UserModel(
          id: 'admin_1',
          username: 'admin',
          fullName: 'Administrator Sekolah',
          role: 'admin',
          initialPassword: 'admin',
        );
        // Master Guru
        final guru = UserModel(
          id: 'teacher_budi',
          username: 'guru',
          fullName: 'Budi Santoso, M.Kom.',
          role: 'guru',
          initialPassword: 'guru',
          subjectIds: [],
          classIds: [],
        );

        await db.collection('users').doc(admin.id).set(admin.toMap());
        await db.collection('users').doc(guru.id).set(guru.toMap());
        debugPrint('[Firestore] Akun awal Admin & Guru berhasil dibuat di Firestore.');
      }
    } catch (e) {
      debugPrint('[Firestore] Note checking initial accounts: $e');
    }
  }

  /// One-time database reset flag or wipe method
  Future<void> _checkAndPerformInitialWipe() async {
    try {
      final markerRef = db.collection('system_metadata').doc('data_wipe_v3');
      final marker = await markerRef.get();
      if (!marker.exists) {
        debugPrint('[Firestore] Menjalankan pembersihan database awal...');
        await wipeAllDataExceptAdminAndTeachers();
        await markerRef.set({
          'wipedAt': FieldValue.serverTimestamp(),
          'version': 3,
          'note': 'Clean slate: only admin and teacher accounts preserved.',
        });
        debugPrint('[Firestore] Pembersihan data awal selesai.');
      }
    } catch (e) {
      debugPrint('[Firestore] Note checking initial wipe: $e');
      _wipeInMemoryDataExceptAdminAndTeachers();
    }
  }

  /// Hapus semua data dari Cloud Firestore dan memori lokal,
  /// KECUALI akun Admin dan Guru.
  Future<void> wipeAllDataExceptAdminAndTeachers() async {
    debugPrint('[Firestore] Memulai pembersihan semua data kecuali akun admin & guru...');

    // 1. Daftar koleksi yang akan dihapus total
    final collectionsToWipe = [
      'classes',
      'subjects',
      'materials',
      'exams',
      'exam_sessions',
      'assignments',
      'assignment_submissions',
      'questions',
      'cps',
      'tps',
      'streaks',
      'chat_messages',
      'forum_messages',
      'point_transactions',
      'grade_redeems',
      'group_registrations',
      'material_progress',
    ];

    for (final col in collectionsToWipe) {
      await _deleteCollectionDocs(col);
    }

    // 2. Hapus semua akun user KECUALI role admin dan guru (Hapus total data siswa & NIS)
    try {
      final snap = await db.collection('users').get();
      final studentDocs = <DocumentSnapshot>[];
      final teacherDocs = <DocumentSnapshot>[];

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final role = (data['role'] ?? '').toString().trim().toLowerCase();
        if (role != 'admin' && role != 'guru') {
          studentDocs.add(doc);
        } else if (role == 'guru') {
          teacherDocs.add(doc);
        }
      }

      // Hapus dokumen siswa dalam batch dengan fallback ke individual delete jika gagal
      for (var i = 0; i < studentDocs.length; i += 300) {
        final end = (i + 300 < studentDocs.length) ? i + 300 : studentDocs.length;
        final chunk = studentDocs.sublist(i, end);
        try {
          final batch = db.batch();
          for (final doc in chunk) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        } catch (e) {
          debugPrint('[Firestore] Batch delete students failed, fallback to individual: $e');
          for (final doc in chunk) {
            try {
              await doc.reference.delete();
            } catch (err) {
              debugPrint('[Firestore] Individual delete failed for ${doc.id}: $err');
            }
          }
        }
      }

      // Extra safety: pastikan tidak ada dokumen siswa dengan NIS tertinggal
      try {
        final nisDocs = await db.collection('users').where('nis', isNull: false).get();
        for (final doc in nisDocs.docs) {
          final data = doc.data();
          final r = (data['role'] ?? '').toString().trim().toLowerCase();
          if (r != 'admin' && r != 'guru') {
            try {
              await doc.reference.delete();
            } catch (_) {}
          }
        }
      } catch (_) {}

      // Reset plotting guru secara terpisah agar aman
      for (final doc in teacherDocs) {
        try {
          await doc.reference.set({
            'subject_ids': [],
            'class_ids': [],
            'subjectIds': [],
            'classIds': [],
            'className': null,
            'class_name': null,
            'classId': null,
            'class_id': null,
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('[Firestore] Note resetting teacher ${doc.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('[Firestore] Note wiping student users: $e');
    }

    // 3. Pastikan akun master Admin & Guru tetap tersedia
    await _ensureMasterAccountsPreserved();

    // 4. Catat marker data wipe ke Firestore
    try {
      await db.collection('system_metadata').doc('data_wipe_v3').set({
        'wipedAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      });
    } catch (_) {}

    // 5. Bersihkan state in-memory
    _wipeInMemoryDataExceptAdminAndTeachers();

    notifyListeners();
    debugPrint('[Firestore] Selesai menghapus semua data. Hanya akun admin dan guru yang tersimpan.');
  }

  Future<void> _deleteCollectionDocs(String collectionName) async {
    try {
      final snap = await db.collection(collectionName).get();
      if (snap.docs.isEmpty) return;

      for (var i = 0; i < snap.docs.length; i += 300) {
        final end = (i + 300 < snap.docs.length) ? i + 300 : snap.docs.length;
        final chunk = snap.docs.sublist(i, end);
        try {
          final batch = db.batch();
          for (final doc in chunk) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        } catch (e) {
          debugPrint('[Firestore] Batch delete on $collectionName failed, fallback to individual: $e');
          for (final doc in chunk) {
            try {
              await doc.reference.delete();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[Firestore] Note wiping collection $collectionName: $e');
    }
  }

  Future<void> _ensureMasterAccountsPreserved() async {
    try {
      final adminSnap = await db.collection('users').where('role', isEqualTo: 'admin').limit(1).get();
      if (adminSnap.docs.isEmpty) {
        final admin = UserModel(
          id: 'admin_1',
          username: 'admin',
          fullName: 'Administrator Sekolah',
          role: 'admin',
          initialPassword: 'admin',
        );
        await db.collection('users').doc(admin.id).set(admin.toMap());
      }

      final guruSnap = await db.collection('users').where('role', isEqualTo: 'guru').limit(1).get();
      if (guruSnap.docs.isEmpty) {
        final guru = UserModel(
          id: 'teacher_budi',
          username: 'guru',
          fullName: 'Budi Santoso, M.Kom.',
          role: 'guru',
          initialPassword: 'guru',
          subjectIds: [],
          classIds: [],
        );
        await db.collection('users').doc(guru.id).set(guru.toMap());
      }
    } catch (e) {
      debugPrint('[Firestore] Note ensuring master accounts: $e');
    }
  }

  void _wipeInMemoryDataExceptAdminAndTeachers() {
    _allStudents.clear();
    _schoolClasses.clear();
    _subjects.clear();
    _materials.clear();
    _exams.clear();
    _examSessions.clear();
    _assignments.clear();
    _submissions.clear();
    _questions.clear();
    _cps.clear();
    _tps.clear();
    _streaks.clear();
    _chatMessages.clear();
    _forumMessages.clear();
    _pointTransactions.clear();
    _gradeRedeems.clear();
    _groupRegistrations.clear();
    _materialProgress.clear();
    _studentCodeRuns.clear();

    if (_allTeachers.isEmpty) {
      _allTeachers.add(UserModel(
        id: 'teacher_budi',
        username: 'guru',
        fullName: 'Budi Santoso, M.Kom.',
        role: 'guru',
        initialPassword: 'guru',
        subjectIds: [],
        classIds: [],
      ));
    } else {
      final updated = _allTeachers.map((t) => t.copyWith(
        subjectIds: [],
        classIds: [],
        className: null,
        classId: null,
      )).toList();
      _allTeachers.clear();
      _allTeachers.addAll(updated);
    }

    if (_currentUser != null && _currentUser!.isGuru) {
      _currentUser = _currentUser!.copyWith(
        subjectIds: [],
        classIds: [],
        className: null,
        classId: null,
      );
    }
  }

  /// Ensure relevant class group and student consultation streaks exist for current user
  Future<void> ensureUserStreaks(UserModel? user) async {
    if (user == null) return;
    try {
      if (user.isGuru || user.isAdmin) {
        // Jangan membuat streak dummy otomatis untuk guru agar tidak spam bot di database.
        // Ruang chat dan streak hanya muncul ketika ada chat masuk atau guru mengirim pesan.
        return;
      }

      // Ensure student's non-chat study streak exists
      if (user.isSiswa || user.role == 'siswa') {
        final stdStreakId = 'streak_study_${user.id}';
        final exists = _streaks.any((s) => s.id == stdStreakId);
        if (!exists) {
          final studyStreak = StreakModel(
            id: stdStreakId,
            type: StreakType.study,
            title: 'Streak Belajar Mandiri 🔥',
            participantIds: [user.id],
            participantNames: [user.fullName],
            streakCount: 0,
            lastInteractionAt: DateTime.now(),
            expiresAt: DateTime.now().add(const Duration(hours: 24)),
          );
          _streaks.add(studyStreak);
          try {
            await db.collection('streaks').doc(studyStreak.id).set(studyStreak.toMap());
          } catch (_) {}
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[Firestore] Note ensuring user streaks: $e');
    }
  }

  // ==================== AUTHENTICATION (FIRESTORE) ====================

  /// Login for Guru & Admin (username/password) or Siswa (NIS/password) directly via Cloud Firestore
  Future<UserModel> login({required String usernameOrNis, required String password}) async {
    final term = usernameOrNis.trim();
    final pass = password.trim();

    try {
      // 1. Check by username in Firestore
      var querySnap = await db
          .collection('users')
          .where('username', isEqualTo: term)
          .limit(1)
          .get();

      // 2. If not found, check by NIS in Firestore
      if (querySnap.docs.isEmpty) {
        querySnap = await db
            .collection('users')
            .where('nis', isEqualTo: term)
            .limit(1)
            .get();
      }

      if (querySnap.docs.isNotEmpty) {
        final doc = querySnap.docs.first;
        final user = UserModel.fromMap(doc.data(), id: doc.id);

        bool isPasswordValid = false;
        // 1. Verifikasi dengan SHA-256 password_hash jika sudah ada
        if (user.passwordHash != null && user.passwordHash!.isNotEmpty) {
          isPasswordValid = SecurityUtils.verifyPassword(pass, user.passwordHash!, salt: user.id);
        }
        // 2. Backward compatibility: jika belum ada hash, verifikasi plaintext
        if (!isPasswordValid) {
          final storedPass = user.initialPassword?.trim() ?? '';
          if (storedPass.isNotEmpty && storedPass == pass) {
            isPasswordValid = true;
          } else if (storedPass.isEmpty && (user.passwordHash == null || user.passwordHash!.isEmpty) && (pass == '123456' || pass == term)) {
            isPasswordValid = true;
          }
        }

        if (isPasswordValid) {
          // Automatic Security Upgrade: otomatis upgrade ke SHA-256 hash jika belum ada
          UserModel updatedUser = user;
          if (user.passwordHash == null || user.passwordHash!.isEmpty) {
            final newHash = SecurityUtils.hashPassword(pass, salt: user.id);
            updatedUser = user.copyWith(passwordHash: newHash);
            db.collection('users').doc(user.id).update({
              'password_hash': newHash,
            }).catchError((e) {
              debugPrint('[Firestore] Error upgrading password hash: $e');
            });
          }
          _currentUser = updatedUser;
          unawaited(_saveUserSession(updatedUser.id, updatedUser.className ?? updatedUser.classId));
          unawaited(syncFcmToken(updatedUser.id));
          notifyListeners();
          return updatedUser;
        } else {
          throw Exception('Password yang Anda masukkan salah.');
        }
      }

      // 3. Fallback provision for initial admin / guru on fresh installations
      if (term == 'admin' && (pass == 'admin' || pass == 'admin123')) {
        final admin = UserModel(
          id: 'admin_1',
          username: 'admin',
          fullName: 'Administrator Sekolah',
          role: 'admin',
          initialPassword: 'admin',
          passwordHash: SecurityUtils.hashPassword('admin', salt: 'admin_1'),
        );
        try {
          await db.collection('users').doc(admin.id).set(admin.toMap());
        } catch (_) {}
        _currentUser = admin;
        unawaited(_saveUserSession(admin.id));
        unawaited(syncFcmToken(admin.id));
        notifyListeners();
        return admin;
      }

      if (term == 'guru' && (pass == 'guru' || pass == 'guru123')) {
        final guru = UserModel(
          id: 'teacher_budi',
          username: 'guru',
          fullName: 'Budi Santoso, M.Kom.',
          role: 'guru',
          initialPassword: 'guru',
          passwordHash: SecurityUtils.hashPassword('guru', salt: 'teacher_budi'),
          subjectIds: [],
          classIds: [],
        );
        try {
          await db.collection('users').doc(guru.id).set(guru.toMap());
        } catch (_) {}
        _currentUser = guru;
        unawaited(_saveUserSession(guru.id));
        unawaited(syncFcmToken(guru.id));
        notifyListeners();
        return guru;
      }

      throw Exception('Username atau NIS "$term" tidak terdaftar di database.');
    } catch (e) {
      if (e is Exception && !e.toString().contains('No Firebase App') && !e.toString().contains('not initialized')) {
        rethrow;
      }
      // Resilient fallback when Firebase App is not configured (e.g. unit tests or offline)
      if (term == 'admin') {
        final admin = UserModel(
          id: 'admin_1',
          username: 'admin',
          fullName: 'Administrator Sekolah',
          role: 'admin',
          initialPassword: 'admin',
        );
        _currentUser = admin;
        notifyListeners();
        return admin;
      }
      if (term == 'guru' || term == 'guru_budi') {
        final guru = UserModel(
          id: 'teacher_budi',
          username: term,
          fullName: 'Budi Santoso, M.Kom.',
          role: 'guru',
          initialPassword: pass,
          subjectIds: [],
          classIds: [],
        );
        _currentUser = guru;
        notifyListeners();
        return guru;
      }
      final inMemory = _allStudents.where((u) => u.username == term || u.nis == term).firstOrNull;
      if (inMemory != null) {
        _currentUser = inMemory;
        notifyListeners();
        return inMemory;
      }
      throw Exception('Username atau NIS "$term" tidak terdaftar.');
    }
  }

  /// Student Self-Registration saved directly to Cloud Firestore
  Future<UserModel> registerStudent({
    required String nis,
    required String className,
    required String fullName,
    required String password,
  }) async {
    final cleanNis = nis.trim();
    final cleanClass = className.trim();
    final cleanName = fullName.trim();
    final cleanPass = password.trim();

    try {
      // Check duplicate NIS in Firestore
      final existing = await db
          .collection('users')
          .where('nis', isEqualTo: cleanNis)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        throw Exception('NIS $cleanNis sudah terdaftar dalam sistem!');
      }
    } catch (e) {
      if (e.toString().contains('sudah terdaftar')) rethrow;
      // If Firestore is offline or testing, check local list
      if (_allStudents.any((s) => s.nis == cleanNis)) {
        throw Exception('NIS $cleanNis sudah terdaftar dalam sistem!');
      }
    }

    final studentId = _uuid.v4();
    final passwordHash = SecurityUtils.hashPassword(cleanPass, salt: studentId);

    final newStudent = UserModel(
      id: studentId,
      username: cleanNis,
      nis: cleanNis,
      fullName: cleanName,
      role: 'siswa',
      classId: cleanClass,
      className: cleanClass,
      initialPassword: cleanPass,
      passwordHash: passwordHash,
      totalPoints: 100, // Welcome points
    );

    _allStudents.add(newStudent);
    _currentUser = newStudent;

    // Save to Firestore
    try {
      await db.collection('users').doc(newStudent.id).set(newStudent.toMap());

      // Award welcome point transaction in Firestore
      final tx = PointTransactionModel(
        id: _uuid.v4(),
        studentId: newStudent.id,
        points: 100,
        reason: 'Bonus Pendaftaran Akun Siswa Baru',
        createdAt: DateTime.now(),
      );
      await db.collection('point_transactions').doc(tx.id).set(tx.toMap());
    } catch (e) {
      debugPrint('[Firestore] Note saving student: $e');
    }

    _currentUser = newStudent;
    notifyListeners();
    unawaited(_saveUserSession(newStudent.id, newStudent.className ?? newStudent.classId));
    unawaited(syncFcmToken(newStudent.id));
    return newStudent;
  }

  /// Sinkronisasi FCM Device Token ke Firestore agar perangkat dapat menerima notifikasi
  /// push saat aplikasi ditutup total (Killed/Terminated) ataupun di latar belakang (Background).
  Future<void> syncFcmToken([String? explicitUserId]) async {
    final uid = explicitUserId ?? _currentUser?.id;
    if (uid == null || uid.isEmpty) return;
    try {
      final token = await FcmService.getToken();
      if (token != null && token.isNotEmpty) {
        await db.collection('users').doc(uid).set({
          'fcm_token': token,
          'fcm_updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('[FCM] Token synced for user: $uid');
      }
      // Otomatis subscribe siswa ke Topik Kelasnya di FCM
      if (_currentUser != null && _currentUser!.isSiswa) {
        final className = _currentUser!.className ?? _currentUser!.classId;
        await FcmService.subscribeToClassTopic(className);
      }
    } catch (e) {
      debugPrint('[FCM] Token sync note: $e');
    }
  }

  void logout() {
    if (_currentUser != null && _currentUser!.isSiswa) {
      final className = _currentUser!.className ?? _currentUser!.classId;
      unawaited(FcmService.unsubscribeFromClassTopic(className));
    }
    _currentUser = null;
    unawaited(_clearUserSession());
    notifyListeners();
  }

  // ==================== NOTIFICATIONS ENGINE (MATERI, KUIS, & CHAT) ====================

  /// Membuat notifikasi baru di Firestore yang ditargetkan untuk kelas tertentu atau user tertentu (Chat)
  Future<void> createNotification({
    required String title,
    required String body,
    required String type, // 'material' | 'exam' | 'chat' | 'announcement'
    List<String> targetClassIds = const [],
    List<String> targetUserIds = const [],
    String? referenceId,
  }) async {
    final notifId = _uuid.v4();
    final notif = AppNotificationModel(
      id: notifId,
      title: title,
      body: body,
      type: type,
      targetClassIds: targetClassIds,
      targetUserIds: targetUserIds,
      referenceId: referenceId,
      creatorId: _currentUser?.id,
      creatorName: _currentUser?.fullName,
      createdAt: DateTime.now(),
      readByUserIds: [],
    );

    // Optimistic insert di awal list
    _notifications.removeWhere((n) => n.id == notifId);
    _notifications.insert(0, notif);
    notifyListeners();

    try {
      await db.collection('notifications').doc(notifId).set(notif.toMap());
      debugPrint('[Notification Engine] Notifikasi tersimpan di Firestore (type: $type)');

      // Kirim sinyal push notifikasi langsung lewat Google FCM (Bangunkan HP meski aplikasi dimatikan)
      if (targetUserIds.isNotEmpty) {
        for (final uid in targetUserIds) {
          final userDoc = await db.collection('users').doc(uid).get();
          final token = userDoc.data()?['fcm_token'] as String?;
          if (token != null && token.isNotEmpty) {
            unawaited(FcmSenderService.sendToDevice(
              fcmToken: token,
              title: title,
              body: body,
              data: {'type': type, 'referenceId': referenceId ?? '', 'notifId': notifId},
            ));
          }
        }
      } else if (targetClassIds.isNotEmpty) {
        for (final cid in targetClassIds) {
          final topic = FcmService.formatClassTopic(cid);
          unawaited(FcmSenderService.sendToTopic(
            topic: topic,
            title: title,
            body: body,
            data: {'type': type, 'referenceId': referenceId ?? '', 'notifId': notifId},
          ));
        }
      } else {
        unawaited(FcmSenderService.sendToTopic(
          topic: 'class_all',
          title: title,
          body: body,
          data: {'type': type, 'referenceId': referenceId ?? '', 'notifId': notifId},
        ));
      }
    } catch (e) {
      debugPrint('[Notification Engine] Error saving/dispatching notification: $e');
    }
  }

  /// Ambil daftar notifikasi yang relevan untuk user
  List<AppNotificationModel> getNotificationsForUser(UserModel? user) {
    if (user == null) return [];
    final uid = user.id;

    return _notifications.where((n) {
      // 1. Notifikasi pesan masuk / chat spesifik per user
      if (n.targetUserIds.isNotEmpty) {
        return n.targetUserIds.contains(uid);
      }
      // 2. Guru & Admin melihat semua notifikasi pengumuman/materi/kuis
      if (user.isGuru || user.isAdmin) {
        return true;
      }
      // 3. Siswa: filter kelas disesuaikan secara ketat dengan data kelas di Firebase
      final studentClass = (user.className ?? user.classId ?? '').trim();
      if (n.targetClassIds.isEmpty) return true;
      if (studentClass.isEmpty) return true;
      return isClassMatching(studentClass, n.targetClassIds);
    }).toList();
  }

  /// Hitung jumlah notifikasi yang belum dibaca oleh user
  int getUnreadNotificationCount(UserModel? user) {
    if (user == null) return 0;
    final list = getNotificationsForUser(user);
    return list.where((n) => !n.readByUserIds.contains(user.id)).length;
  }

  /// Tandai notifikasi sebagai sudah dibaca oleh user
  Future<void> markNotificationAsRead(String notificationId, String userId) async {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1 && !_notifications[idx].readByUserIds.contains(userId)) {
      final updated = _notifications[idx].copyWith(
        readByUserIds: [..._notifications[idx].readByUserIds, userId],
      );
      _notifications[idx] = updated;
      notifyListeners();
    }
    try {
      await db.collection('notifications').doc(notificationId).set({
        'read_by_user_ids': FieldValue.arrayUnion([userId]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Notification Engine] Error marking as read: $e');
    }
  }

  /// Tandai semua notifikasi milik user sebagai sudah dibaca
  Future<void> markAllNotificationsAsRead(String userId) async {
    final userNotifs = getNotificationsForUser(_currentUser).where((n) => !n.readByUserIds.contains(userId));
    for (final n in userNotifs) {
      await markNotificationAsRead(n.id, userId);
    }
  }

  // ==================== MATERIAL & CLASS-ISOLATED FORUM ====================

  List<MaterialModel> getMaterialsForUser(UserModel user) {
    if (user.isGuru) {
      return _materials
          .where((m) => m.teacherId == user.id || user.subjectIds.contains(m.subjectId))
          .toList();
    }
    // For student: filter by their class AND scheduled open time
    final studentClassId = (user.classId ?? '').trim().toLowerCase();
    final studentClassName = (user.className ?? '').trim().toLowerCase();

    // Matching classes from _schoolClasses
    final matchingClasses = _schoolClasses.where((c) {
      final cName = c.name.trim().toLowerCase();
      final cId = c.id.trim().toLowerCase();
      return (studentClassId.isNotEmpty && (cName == studentClassId || cId == studentClassId)) ||
          (studentClassName.isNotEmpty && (cName == studentClassName || cId == studentClassName));
    }).toList();

    final validClassTokens = <String>{
      if (studentClassId.isNotEmpty) studentClassId,
      if (studentClassName.isNotEmpty) studentClassName,
      for (final mc in matchingClasses) ...[
        mc.id.trim().toLowerCase(),
        mc.name.trim().toLowerCase(),
      ],
    };

    return _materials.where((m) {
      if (m.classIds.isEmpty) return true; // Available to all if not restricted
      final match = m.classIds.any((cid) {
        final cleanCid = cid.trim().toLowerCase();
        if (validClassTokens.contains(cleanCid)) return true;
        // Check if cleanCid matches id of any school class whose name is in validClassTokens
        final sc = _schoolClasses.where((c) => c.id.trim().toLowerCase() == cleanCid).firstOrNull;
        if (sc != null && validClassTokens.contains(sc.name.trim().toLowerCase())) {
          return true;
        }
        return false;
      });
      return match && m.isOpen;
    }).toList();
  }

  Future<void> addMaterial(MaterialModel material) async {
    _materials.removeWhere((m) => m.id == material.id);
    _materials.insert(0, material);
    notifyListeners();
    try {
      await db.collection('materials').doc(material.id).set(material.toMap());

      // Auto-trigger push notification for students in the material's target classes
      final teacherName = _currentUser?.fullName ?? 'Bapak/Ibu Guru';
      final classesText = material.classIds.isNotEmpty ? material.classIds.join(', ') : 'Semua Kelas';
      unawaited(createNotification(
        title: '📚 Materi Baru: ${material.title}',
        body: '$teacherName telah mengunggah materi baru untuk kelas $classesText. Buka sekarang untuk mempelajari materinya!',
        type: 'material',
        targetClassIds: material.classIds,
        referenceId: material.id,
      ));
    } catch (e) {
      debugPrint('[Firestore] Error adding material: $e');
    }
  }

  Future<void> updateMaterial(MaterialModel material) async {
    final idx = _materials.indexWhere((m) => m.id == material.id);
    if (idx != -1) {
      _materials[idx] = material;
      notifyListeners();
    }
    try {
      await db.collection('materials').doc(material.id).update(material.toMap());
    } catch (e) {
      debugPrint('[Firestore] Error updating material: $e');
    }
  }

  Future<void> deleteMaterial(String materialId) async {
    _materials.removeWhere((m) => m.id == materialId);
    final relatedAssignmentIds = _assignments
        .where((a) => a.materialId == materialId)
        .map((a) => a.id)
        .toList();
    _assignments.removeWhere((a) => a.materialId == materialId);
    _submissions.removeWhere((s) => relatedAssignmentIds.contains(s.assignmentId));
    notifyListeners();
    try {
      await db.collection('materials').doc(materialId).delete();
      for (final aid in relatedAssignmentIds) {
        await db.collection('assignments').doc(aid).delete();
      }
    } catch (e) {
      debugPrint('[Firestore] Error deleting material: $e');
    }
  }

  /// Get real-time material progress percentage (0.0 to 100.0)
  double getMaterialProgress(String studentId, String materialId) {
    if (studentId.isEmpty || materialId.isEmpty) return 0.0;
    return _materialProgress['${studentId}_$materialId'] ?? 0.0;
  }

  /// Update and persist real-time material progress to Cloud Firestore
  Future<void> updateMaterialProgress(
    String studentId,
    String materialId,
    double progressPercent,
  ) async {
    if (studentId.isEmpty || materialId.isEmpty) return;
    final clamped = progressPercent.clamp(0.0, 100.0).toDouble();
    final key = '${studentId}_$materialId';
    final oldProgress = _materialProgress[key] ?? 0.0;
    _materialProgress[key] = clamped;
    notifyListeners();

    // Reward active learning: +20 points when module reading is completed 100%
    if (clamped >= 100.0 && oldProgress < 100.0) {
      final mat = _materials.where((m) => m.id == materialId).firstOrNull;
      final matTitle = mat?.title ?? 'Modul Materi';
      await addPoints(
        studentId: studentId,
        points: 20,
        reason: 'Selesai Belajar Modul Materi: $matTitle 📖',
      );
    }

    // 🔥 Nyalakan / perbarui Streak Belajar Non-Chat
    await triggerStudyActivityStreak(
      studentId: studentId,
      activityType: 'materi',
      detail: _materials.where((m) => m.id == materialId).firstOrNull?.title,
    );

    try {
      await db.collection('material_progress').doc(key).set({
        'studentId': studentId,
        'materialId': materialId,
        'progress': clamped,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Firestore] updateMaterialProgress note: $e');
    }
  }

  /// Get forum messages strictly isolated by classId
  List<ForumMessageModel> getForumMessages({required String materialId, required String classId}) {
    return _forumMessages
        .where((m) => m.materialId == materialId && m.classId == classId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> sendForumMessage({
    required String materialId,
    required String classId,
    required String message,
  }) async {
    if (_currentUser == null || message.trim().isEmpty) return;

    // Terapkan filter konten sebelum menyimpan
    final filteredMessage =
        ContentFilterService.instance.filter(message.trim());

    final newMsg = ForumMessageModel(
      id: _uuid.v4(),
      materialId: materialId,
      classId: classId, // Strict class isolation
      senderId: _currentUser!.id,
      senderName: _currentUser!.fullName,
      senderRole: _currentUser!.role,
      message: filteredMessage,
      createdAt: DateTime.now(),
    );

    _forumMessages.add(newMsg);
    notifyListeners();

    try {
      await db.collection('forum_messages').doc(newMsg.id).set(newMsg.toMap());
    } catch (e) {
      debugPrint('[Firestore] Error sending forum message: $e');
    }
  }

  // ==================== ASSIGNMENTS & GROUP SUBMISSION ====================

  List<AssignmentModel> getAssignmentsForMaterial(String materialId) {
    return _assignments.where((a) => a.materialId == materialId).toList();
  }

  Future<void> addAssignment(AssignmentModel assignment) async {
    _assignments.insert(0, assignment);
    notifyListeners();
    try {
      await db.collection('assignments').doc(assignment.id).set(assignment.toMap());
    } catch (e) {
      debugPrint('[Firestore] Error adding assignment: $e');
    }
  }

  List<AssignmentSubmissionModel> getSubmissionsForAssignment(String assignmentId) {
    return _submissions.where((s) => s.assignmentId == assignmentId).toList();
  }

  Future<void> submitAssignment(AssignmentSubmissionModel submission) async {
    final existingIndex = _submissions.indexWhere(
      (s) => s.assignmentId == submission.assignmentId &&
          (s.submitterId == submission.submitterId || s.memberStudentIds.contains(submission.submitterId)),
    );
    if (existingIndex != -1) {
      final old = _submissions[existingIndex];
      if (old.score != null) {
        debugPrint('[FirebaseService] Tugas ini sudah dinilai guru. Tidak dapat diubah.');
        return;
      }
      // Izinkan pembaruan berkas / kumpul ulang jika belum dinilai
      final updatedSubmission = submission.copyWith(
        id: old.id, // Tetap gunakan ID yang sama agar rapi
      );
      _submissions[existingIndex] = updatedSubmission;
      notifyListeners();

      try {
        await db
            .collection('assignment_submissions')
            .doc(old.id)
            .set(updatedSubmission.toMap())
            .timeout(const Duration(seconds: 8));
        debugPrint('[Firestore] Assignment submission successfully updated: ${old.id}');
      } catch (e) {
        debugPrint('[Firestore] Error updating assignment: $e');
      }
      return;
    }

    _submissions.insert(0, submission);
    notifyListeners();

    try {
      await db
          .collection('assignment_submissions')
          .doc(submission.id)
          .set(submission.toMap())
          .timeout(const Duration(seconds: 8));
      debugPrint('[Firestore] Assignment submission successfully saved to Firebase: ${submission.id}');
    } catch (e) {
      debugPrint('[Firestore] Error submitting assignment: $e');
    }

    // Award gamification points & streak to all group members (or individual)
    final allMembers = {submission.submitterId, ...submission.memberStudentIds};
    for (final memberId in allMembers) {
      await addPoints(
        studentId: memberId,
        points: 50,
        reason: submission.memberStudentIds.length > 1
            ? 'Pengumpulan Tugas Kelompok (${submission.groupName ?? "Kelompok"}): ${submission.type.label}'
            : 'Pengumpulan Tugas: ${submission.type.label}',
      );

      // 🔥 Nyalakan / perbarui Streak Belajar Non-Chat untuk setiap anggota kelompok
      await triggerStudyActivityStreak(
        studentId: memberId,
        activityType: 'tugas',
        detail: submission.type.label,
      );
    }

    // Otomatisasi progres materi: Jika tugas terkait materi diselesaikan, buka progres menuju 100%
    try {
      final asg = _assignments.where((a) => a.id == submission.assignmentId).firstOrNull;
      if (asg != null && asg.materialId.isNotEmpty) {
        final studentIds = {submission.submitterId, ...submission.memberStudentIds};
        final matAssignments = getAssignmentsForMaterial(asg.materialId);

        for (final sId in studentIds) {
          final student = _allStudents.where((s) => s.id == sId).firstOrNull ?? _currentUser;
          final studentClass = student?.className ?? student?.classId ?? '';
          final applicable = matAssignments.where((a) {
            if (a.classIds.isEmpty) return true;
            if (studentClass.isEmpty) return true;
            return a.classIds.any((c) => c.toLowerCase() == studentClass.toLowerCase());
          }).toList();

          if (applicable.isNotEmpty) {
            final allDone = applicable.every((a) {
              if (a.id == submission.assignmentId) return true;
              return _submissions.any((s) =>
                  s.assignmentId == a.id &&
                  (s.submitterId == sId || s.memberStudentIds.contains(sId)));
            });

            if (allDone) {
              final currentProgress = getMaterialProgress(sId, asg.materialId);
              final newProgress = currentProgress >= 50.0 ? 100.0 : (currentProgress + 50.0).clamp(0.0, 100.0);
              await updateMaterialProgress(sId, asg.materialId, newProgress);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[FirebaseService] Auto material progress error on submit: $e');
    }
  }

  Future<void> gradeAssignmentSubmission({
    required String submissionId,
    required double score,
    String? feedback,
  }) async {
    final index = _submissions.indexWhere((s) => s.id == submissionId);
    if (index != -1) {
      final sub = _submissions[index];
      final updated = sub.copyWith(
        score: score,
        teacherFeedback: feedback,
        gradedAt: DateTime.now(),
      );
      _submissions[index] = updated;
      notifyListeners();

      try {
        await db.collection('assignment_submissions').doc(submissionId).update({
          'score': score,
          'teacher_feedback': feedback,
          'graded_at': DateTime.now().toIso8601String(),
        });

        // Sync grade to all group members if this is a group submission
        if (sub.memberStudentIds.isNotEmpty) {
          for (final memberId in sub.memberStudentIds) {
            if (memberId == sub.submitterId) continue;
            // Find if there's a separate submission for this member (shouldn't exist for group,
            // but sync the grade to any personal record if found)
            final memberSubIdx = _submissions.indexWhere(
              (s) => s.assignmentId == sub.assignmentId && s.submitterId == memberId,
            );
            if (memberSubIdx != -1) {
              _submissions[memberSubIdx] = _submissions[memberSubIdx].copyWith(
                score: score,
                teacherFeedback: feedback,
                gradedAt: DateTime.now(),
              );
              await db
                  .collection('assignment_submissions')
                  .doc(_submissions[memberSubIdx].id)
                  .update({
                'score': score,
                'teacher_feedback': feedback,
                'graded_at': DateTime.now().toIso8601String(),
              });
            }
          }
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[Firestore] Error grading assignment: $e');
      }
    }
  }

  // ── Group Registration ────────────────────────────────────────────────────

  final List<GroupRegistrationModel> _groupRegistrations = [];
  List<GroupRegistrationModel> get groupRegistrations => List.unmodifiable(_groupRegistrations);

  List<GroupRegistrationModel> getGroupsForAssignment(String assignmentId) {
    return _groupRegistrations.where((g) => g.assignmentId == assignmentId).toList();
  }

  GroupRegistrationModel? getGroupForStudent(String assignmentId, String studentId) {
    try {
      return _groupRegistrations.firstWhere(
        (g) => g.assignmentId == assignmentId && g.memberIds.contains(studentId),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> addGroupRegistration(GroupRegistrationModel group) async {
    _groupRegistrations.removeWhere(
      (g) => g.id == group.id,
    );
    _groupRegistrations.add(group);
    notifyListeners();
    try {
      await db.collection('group_registrations').doc(group.id).set(group.toMap());
    } catch (e) {
      debugPrint('[Firestore] Error adding group registration: $e');
    }
  }

  // ── PPT Upload ────────────────────────────────────────────────────────────

  Future<String> uploadPptFile({
    required Uint8List bytes,
    required String fileName,
    required String materialId,
  }) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('ppt_materials')
        .child(materialId)
        .child(fileName);
    await ref.putData(bytes);
    return await ref.getDownloadURL();
  }

  // ── In-Memory File Cache & Universal Resolver ──────────────────────────────
  static final Map<String, Uint8List> _fileBytesCache = {};

  /// Mengambil bytes dari cache in-memory jika tersedia
  static Uint8List? getCachedFileBytes(String url) {
    return _fileBytesCache[url.trim()];
  }

  /// Menyimpan bytes secara manual ke cache
  static void cacheFileBytes(String url, Uint8List bytes) {
    _fileBytesCache[url.trim()] = bytes;
  }

  /// Mengambil Uint8List bytes dari URL manapun (HTTP/HTTPS, Base64 Data URI, atau Firestore Chunked Storage)
  Future<Uint8List> resolveFileBytes(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw Exception('URL berkas kosong.');
    }

    if (_fileBytesCache.containsKey(trimmed)) {
      return _fileBytesCache[trimmed]!;
    }

    // 1. Base64 Data URI (data:application/pdf;base64,... atau data:image/...;base64,...)
    if (trimmed.startsWith('data:')) {
      final commaIdx = trimmed.indexOf(',');
      final base64Str = commaIdx != -1 ? trimmed.substring(commaIdx + 1) : trimmed;
      final bytes = base64Decode(base64Str);
      _fileBytesCache[trimmed] = bytes;
      return bytes;
    }

    // 2. HTTP / HTTPS (Firebase Storage URL atau link web publik)
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final response = await http.get(Uri.parse(trimmed)).timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw Exception('Waktu unduh berkas habis (timeout). Silakan periksa koneksi internet.'),
      );
      if (response.statusCode == 200) {
        _fileBytesCache[trimmed] = response.bodyBytes;
        return response.bodyBytes;
      } else {
        throw Exception('Gagal mengunduh berkas dari server (Status ${response.statusCode})');
      }
    }

    // 3. Firestore Chunked Storage (firestore://uploaded_files/<fileId>)
    if (trimmed.startsWith('firestore://uploaded_files/')) {
      final uri = Uri.parse(trimmed);
      final fileId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : uri.host;
      final chunksSnap = await db
          .collection('uploaded_files')
          .doc(fileId)
          .collection('chunks')
          .orderBy('chunk_index')
          .get()
          .timeout(const Duration(seconds: 20));

      if (chunksSnap.docs.isEmpty) {
        throw Exception('Berkas tidak ditemukan di database Firestore (mungkin sudah dihapus).');
      }

      final bytesBuilder = BytesBuilder(copy: false);
      for (final doc in chunksSnap.docs) {
        final data = doc.data();
        final b64Part = data['data'] as String? ?? '';
        if (b64Part.isNotEmpty) {
          bytesBuilder.add(base64Decode(b64Part));
        }
      }
      final fullBytes = bytesBuilder.toBytes();
      _fileBytesCache[trimmed] = fullBytes;
      return fullBytes;
    }

    // 4. Raw file name fallback (e.g. "TP 2 (1).pdf")
    throw Exception(
      'Format URL atau berkas tidak valid ("$trimmed").\n'
      'Berkas ini sebelumnya hanya tersimpan nama filenya karena layanan Firebase Storage belum aktif di Firebase Console saat pengumpulan.\n'
      'Silakan kumpulkan ulang berkas tugas sekarang (aplikasi kini otomatis menyimpan berkas ke database Firestore sehingga dapat langsung dilihat).',
    );
  }

  // ── Assignment File Upload ──────────────────────────────────────────────────

  Future<String> uploadAssignmentFile({
    required Uint8List bytes,
    required String fileName,
    required String assignmentId,
    required String studentId,
  }) async {
    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    final mime = isPdf ? 'application/pdf' : 'image/jpeg';
    final safeName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';

    // 1. Coba upload ke Firebase Storage dengan timeout singkat (3 detik)
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('assignment_submissions')
          .child(assignmentId)
          .child(studentId)
          .child(safeName);

      final metadata = SettableMetadata(contentType: mime);
      final task = ref.putData(bytes, metadata);
      final snapshot = await task.timeout(const Duration(seconds: 3));
      final downloadUrl = await snapshot.ref.getDownloadURL().timeout(const Duration(seconds: 3));
      debugPrint('[FirebaseStorage] Upload berhasil: $downloadUrl');
      _fileBytesCache[downloadUrl] = bytes;
      return downloadUrl;
    } catch (e) {
      debugPrint('[FirebaseStorage] Storage tidak aktif atau timeout: $e. Beralih ke penyimpanan Firestore...');
    }

    // 2. Fallback A: Jika ukuran <= 750 KB, simpan langsung sebagai Base64 Data URI (Cepat, 0 query tambahan)
    if (bytes.lengthInBytes <= 750 * 1024) {
      final b64 = base64Encode(bytes);
      final dataUri = 'data:$mime;base64,$b64';
      _fileBytesCache[dataUri] = bytes;
      debugPrint('[FirestoreFallback] Berkas $fileName (${bytes.lengthInBytes} bytes) disimpan sebagai Data URI.');
      return dataUri;
    }

    // 3. Fallback B: Jika ukuran > 750 KB (hingga puluhan MB), simpan chunked di koleksi Firestore 'uploaded_files'
    try {
      final fileId = 'file_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}';
      const chunkSize = 400 * 1024; // 400 KB per chunk (aman dari limit 1MB Firestore)
      final totalChunks = (bytes.lengthInBytes / chunkSize).ceil();

      // Simpan metadata berkas
      await db.collection('uploaded_files').doc(fileId).set({
        'id': fileId,
        'file_name': fileName,
        'mime_type': mime,
        'total_size': bytes.lengthInBytes,
        'total_chunks': totalChunks,
        'assignment_id': assignmentId,
        'student_id': studentId,
        'uploaded_at': DateTime.now().toIso8601String(),
      });

      // Simpan potongan chunk ke subkoleksi
      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize > bytes.lengthInBytes) ? bytes.lengthInBytes : (start + chunkSize);
        final chunkBytes = bytes.sublist(start, end);
        final chunkB64 = base64Encode(chunkBytes);

        await db.collection('uploaded_files').doc(fileId).collection('chunks').doc('$i').set({
          'chunk_index': i,
          'data': chunkB64,
          'size': chunkBytes.length,
        });
      }

      final firestoreUrl = 'firestore://uploaded_files/$fileId?name=${Uri.encodeComponent(fileName)}';
      _fileBytesCache[firestoreUrl] = bytes;
      debugPrint('[FirestoreFallback] Berkas $fileName (${bytes.lengthInBytes} bytes) berhasil di-chunk ke $totalChunks dokumen.');
      return firestoreUrl;
    } catch (err) {
      debugPrint('[FirestoreFallback] Error menyimpan chunked file: $err');
      // Bila masih darurat, simpan sebagai base64 Data URI jika memungkinkan (< 950 KB)
      if (bytes.lengthInBytes <= 950 * 1024) {
        final b64 = base64Encode(bytes);
        final dataUri = 'data:$mime;base64,$b64';
        _fileBytesCache[dataUri] = bytes;
        return dataUri;
      }
      return fileName;
    }
  }

  // ── Download Grades by Class ──────────────────────────────────────────────

  /// Returns rows suitable for Excel/CSV export.
  /// Each row: [Nama Siswa, Kelas, Nama Kelompok, Nilai, Feedback, Dikumpulkan Oleh]
  List<List<dynamic>> getGradeRowsByClass({
    required String assignmentId,
    required String classId,
  }) {
    final rows = <List<dynamic>>[
      ['Nama Siswa', 'Kelas', 'Nama Kelompok', 'Nilai', 'Feedback', 'Dikumpulkan Oleh'],
    ];

    final subs = _submissions.where((s) => s.assignmentId == assignmentId).toList();
    final targetClass = classId.trim().toLowerCase();
    final matchingClass = _schoolClasses.where((c) =>
        c.id.trim().toLowerCase() == targetClass ||
        c.name.trim().toLowerCase() == targetClass).firstOrNull;
    final validTokens = <String>{
      targetClass,
      if (matchingClass != null) ...[
        matchingClass.id.trim().toLowerCase(),
        matchingClass.name.trim().toLowerCase(),
      ],
    };

    final students = _allStudents.where((s) {
      final sClass = (s.className ?? s.classId ?? '').trim().toLowerCase();
      return validTokens.contains(sClass);
    }).toList();

    for (final student in students) {
      // Find submission for this student (direct or as group member)
      AssignmentSubmissionModel? sub;
      try {
        sub = subs.firstWhere(
          (s) => s.submitterId == student.id || s.memberStudentIds.contains(student.id),
        );
      } catch (_) {
        sub = null;
      }

      rows.add([
        student.fullName,
        student.classId,
        sub?.groupName ?? '-',
        sub?.score?.toStringAsFixed(0) ?? 'Belum dinilai',
        sub?.teacherFeedback ?? '-',
        sub != null ? (sub.submitterId == student.id ? 'Ya (pengumpul)' : sub.submitterName) : 'Belum kumpul',
      ]);
    }
    return rows;
  }

  // ==================== CURRICULUM (CP / TP / SUBJECT) ====================

  Future<void> addSubject(SubjectModel subject) async {
    _subjects.add(subject);
    notifyListeners();
    try {
      await db.collection('subjects').doc(subject.id).set(subject.toMap());
    } catch (e) {
      debugPrint('[Firestore] Error adding subject: $e');
    }
  }

  Future<void> updateSubject(SubjectModel subject) async {
    final idx = _subjects.indexWhere((s) => s.id == subject.id);
    if (idx != -1) {
      _subjects[idx] = subject;
    } else {
      _subjects.add(subject);
    }
    notifyListeners();
    try {
      await db.collection('subjects').doc(subject.id).set(subject.toMap());
    } catch (e) {
      debugPrint('[Firestore] Error updating subject: $e');
    }
  }

  Future<void> deleteSubject(String subjectId) async {
    _subjects.removeWhere((s) => s.id == subjectId);
    notifyListeners();
    try {
      await db.collection('subjects').doc(subjectId).delete();
    } catch (e) {
      debugPrint('[Firestore] Error deleting subject: $e');
    }
  }

  Future<void> addTeacherUser(UserModel teacher) async {
    UserModel userToSave = teacher;
    if (teacher.passwordHash == null || teacher.passwordHash!.isEmpty) {
      final pass = teacher.initialPassword ?? 'guru123';
      userToSave = teacher.copyWith(
        passwordHash: SecurityUtils.hashPassword(pass, salt: teacher.id),
      );
    }
    final idx = _allTeachers.indexWhere((t) => t.id == userToSave.id);
    if (idx != -1) {
      _allTeachers[idx] = userToSave;
    } else {
      _allTeachers.add(userToSave);
    }
    notifyListeners();
    try {
      await db.collection('users').doc(userToSave.id).set(userToSave.toMap());
    } catch (e) {
      debugPrint('[Firestore] Error adding teacher: $e');
    }
  }

  Future<void> updateTeacherUser(UserModel teacher) async {
    UserModel userToSave = teacher;
    if ((teacher.passwordHash == null || teacher.passwordHash!.isEmpty) && teacher.initialPassword != null) {
      userToSave = teacher.copyWith(
        passwordHash: SecurityUtils.hashPassword(teacher.initialPassword!, salt: teacher.id),
      );
    }
    final idx = _allTeachers.indexWhere((t) => t.id == userToSave.id);
    if (idx != -1) {
      _allTeachers[idx] = userToSave;
      if (_currentUser?.id == userToSave.id) {
        _currentUser = userToSave;
      }
      notifyListeners();
      try {
        await db.collection('users').doc(userToSave.id).set(userToSave.toMap());
      } catch (e) {
        debugPrint('[Firestore] Error updating teacher: $e');
      }
    }
  }

  Future<void> deleteTeacherUser(String teacherId) async {
    _allTeachers.removeWhere((t) => t.id == teacherId);
    notifyListeners();
    try {
      await db.collection('users').doc(teacherId).delete();
    } catch (e) {
      debugPrint('[Firestore] Error deleting teacher: $e');
    }
  }

  Future<void> addStudentUser(UserModel student) async {
    UserModel userToSave = student;
    if (student.passwordHash == null || student.passwordHash!.isEmpty) {
      final pass = student.initialPassword ?? 'siswa123';
      userToSave = student.copyWith(
        passwordHash: SecurityUtils.hashPassword(pass, salt: student.id),
      );
    }
    final idx = _allStudents.indexWhere((s) => s.id == userToSave.id);
    if (idx != -1) {
      _allStudents[idx] = userToSave;
    } else {
      _allStudents.add(userToSave);
    }
    notifyListeners();
    try {
      await db.collection('users').doc(userToSave.id).set(userToSave.toMap());
    } catch (e) {
      debugPrint('[Firestore] Error adding student: $e');
    }
  }

  Future<void> deleteStudentUser(String studentId) async {
    _allStudents.removeWhere((s) => s.id == studentId);
    notifyListeners();
    try {
      await db.collection('users').doc(studentId).delete();
    } catch (e) {
      debugPrint('[Firestore] Error deleting student: $e');
    }
  }

  Future<void> assignTeacherToSubjectsAndClasses({
    required String teacherId,
    required List<String> subjectIds,
    required List<String> classIds,
  }) async {
    final teacherIndex = _allTeachers.indexWhere((t) => t.id == teacherId);
    if (teacherIndex != -1) {
      _allTeachers[teacherIndex] = _allTeachers[teacherIndex].copyWith(
        subjectIds: subjectIds,
        classIds: classIds,
      );
    }
    if (_currentUser?.id == teacherId) {
      _currentUser = _currentUser!.copyWith(
        subjectIds: subjectIds,
        classIds: classIds,
      );
    }
    notifyListeners();
    try {
      await db.collection('users').doc(teacherId).update({
        'subject_ids': subjectIds,
        'class_ids': classIds,
      });
    } catch (e) {
      debugPrint('[Firestore] assignTeacher error: $e');
    }
  }

  Future<void> addCp(CurriculumCpModel cp) async {
    _cps.add(cp);
    notifyListeners();
    try {
      await db.collection('cps').doc(cp.id).set(cp.toMap());
    } catch (e) {
      debugPrint('[Firestore] Error adding cp: $e');
    }
  }

  Future<void> addTp(CurriculumTpModel tp) async {
    _tps.add(tp);
    notifyListeners();
    try {
      await db.collection('tps').doc(tp.id).set(tp.toMap());
    } catch (e) {
      debugPrint('[Firestore] Error adding tp: $e');
    }
  }

  // ==================== QUESTION BANK ====================

  Future<void> addQuestion(QuestionModel question) async {
    _questions.insert(0, question);
    notifyListeners();
    try {
      await db.collection('questions').doc(question.id).set(question.toMap());
    } catch (e) {
      debugPrint('[Firestore] Error adding question: $e');
    }
  }

  Future<void> addQuestionsBulk(List<QuestionModel> newQuestions) async {
    _questions.addAll(newQuestions);
    notifyListeners();
    try {
      final batch = db.batch();
      for (final q in newQuestions) {
        batch.set(db.collection('questions').doc(q.id), q.toMap());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[Firestore] Error bulk adding questions: $e');
    }
  }

  List<QuestionModel> getQuestions({
    required String subjectId,
    String? cpId,
    String? tpId,
    QuestionType? type,
  }) {
    return _questions.where((q) {
      if (q.subjectId != subjectId) return false;
      if (cpId != null && q.cpId != cpId) return false;
      if (tpId != null && q.tpId != tpId) return false;
      if (type != null && q.type != type) return false;
      return true;
    }).toList();
  }

  List<QuestionModel> getQuestionsByFilter({
    required String subjectId,
    String? cpId,
    String? tpId,
    QuestionType? type,
  }) => getQuestions(subjectId: subjectId, cpId: cpId, tpId: tpId, type: type);

  List<QuestionModel> getMissingImageQuestions(String subjectId) {
    return _questions
        .where((q) => q.subjectId == subjectId && q.missingImageFlag)
        .toList();
  }

  Future<void> resolveMissingImage(String questionId, String imageUrl) async {
    final index = _questions.indexWhere((q) => q.id == questionId);
    if (index != -1) {
      final updated = _questions[index].copyWith(
        hasImage: true,
        imageUrls: [imageUrl],
        missingImageFlag: false,
      );
      _questions[index] = updated;
      notifyListeners();

      try {
        await db.collection('questions').doc(questionId).update({
          'has_image': true,
          'image_urls': [imageUrl],
          'missing_image_flag': false,
        });
      } catch (e) {
        debugPrint('[Firestore] Error resolving missing image: $e');
      }
    }
  }

  // ==================== EXAM & ANTI-CHEAT ENGINE ====================

  Future<void> addExam(ExamModel exam) async {
    _exams.insert(0, exam);
    notifyListeners();
    try {
      await db.collection('exams').doc(exam.id).set(exam.toMap());

      // Auto-trigger push notification for students in the exam's target classes
      final teacherName = _currentUser?.fullName ?? 'Bapak/Ibu Guru';
      final classesText = exam.classIds.isNotEmpty ? exam.classIds.join(', ') : 'Semua Kelas';
      unawaited(createNotification(
        title: '📝 Kuis/Ujian Baru: ${exam.title}',
        body: '$teacherName telah menerbitkan kuis/ujian baru untuk kelas $classesText. Segera persiapkan dirimu!',
        type: 'exam',
        targetClassIds: exam.classIds,
        referenceId: exam.id,
      ));
    } catch (e) {
      debugPrint('[Firestore] Error adding exam: $e');
    }
  }

  Future<void> updateExam(ExamModel exam) async {
    final index = _exams.indexWhere((e) => e.id == exam.id);
    if (index != -1) {
      _exams[index] = exam;
    } else {
      _exams.insert(0, exam);
    }
    notifyListeners();
    try {
      await db.collection('exams').doc(exam.id).set(exam.toMap());
    } catch (e) {
      debugPrint('[Firestore] Error updating exam: $e');
    }
  }

  Future<void> toggleExamAntiCheat(String examId, bool enabled) async {
    final index = _exams.indexWhere((e) => e.id == examId);
    if (index != -1) {
      _exams[index] = _exams[index].copyWith(antiCheatEnabled: enabled);
      notifyListeners();
      try {
        await db.collection('exams').doc(examId).update({
          'anti_cheat_enabled': enabled,
        });
      } catch (e) {
        debugPrint('[Firestore] Error toggling anti cheat: $e');
      }
    }
  }

  Future<void> deleteExam(String examId) async {
    _exams.removeWhere((e) => e.id == examId);
    _examSessions.removeWhere((s) => s.examId == examId);
    notifyListeners();
    try {
      await db.collection('exams').doc(examId).delete();
      final sessions = await db
          .collection('exam_sessions')
          .where('exam_id', isEqualTo: examId)
          .get();
      for (final doc in sessions.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('[Firestore] Error deleting exam: $e');
    }
  }

  /// Mengecek apakah ujian untuk siswa ini sudah selesai, sudah di-submit, atau waktu pengerjaannya telah habis.
  bool isExamFinishedForStudent({
    required String examId,
    required String studentId,
  }) {
    final exam = _exams.where((e) => e.id == examId).firstOrNull;
    final session = _examSessions
        .where((s) => s.examId == examId && s.studentId == studentId)
        .firstOrNull;

    if (session != null) {
      if (session.isCompleted) return true;
      if (exam != null) {
        final totalExamSeconds = exam.durationMinutes * 60;
        final elapsedSeconds = DateTime.now().difference(session.startedAt).inSeconds;
        final isTimeOver = elapsedSeconds >= totalExamSeconds;
        final isScheduleOver = exam.endTime != null && DateTime.now().isAfter(exam.endTime!);
        if (isTimeOver || isScheduleOver) {
          // Otomatis selesaikan sesi jika waktu pengerjaan telah habis
          finishExam(session.id);
          return true;
        }
      }
    } else if (exam != null && exam.endTime != null && DateTime.now().isAfter(exam.endTime!)) {
      // Jadwal ujian sudah berakhir sebelum siswa memulai
      return true;
    }
    return false;
  }

  ExamSessionModel getOrCreateExamSession({
    required String examId,
    required UserModel student,
  }) {
    final existingIndex = _examSessions.indexWhere(
      (s) => s.examId == examId && s.studentId == student.id,
    );

    if (existingIndex != -1) {
      final existing = _examSessions[existingIndex];
      // Jika sesi sudah selesai, langsung kembalikan tanpa mengizinkan modifikasi
      if (existing.isCompleted) {
        return existing;
      }
      // Cek apakah waktu pengerjaan sesi ini sebenarnya sudah habis atau jadwal sudah lewat
      final exam = _exams.where((e) => e.id == examId).firstOrNull;
      if (exam != null) {
        final totalExamSeconds = exam.durationMinutes * 60;
        final elapsedSeconds = DateTime.now().difference(existing.startedAt).inSeconds;
        final isTimeOver = elapsedSeconds >= totalExamSeconds;
        final isScheduleOver = exam.endTime != null && DateTime.now().isAfter(exam.endTime!);
        if (isTimeOver || isScheduleOver) {
          finishExam(existing.id);
          return _examSessions.firstWhere((s) => s.id == existing.id, orElse: () => existing);
        }
      }

      // Jika sesi sudah ada namun belum memiliki orderedQuestionIds, lengkapi acakannya
      if (existing.orderedQuestionIds.isEmpty) {
        if (exam != null && exam.questionIds.isNotEmpty) {
          final shuffled = List<String>.from(exam.questionIds);
          final seed = '${examId}_${student.id}'.hashCode;
          shuffled.shuffle(Random(seed));
          final updated = existing.copyWith(orderedQuestionIds: shuffled);
          _examSessions[existingIndex] = updated;
          db.collection('exam_sessions').doc(updated.id).update({
            'ordered_question_ids': shuffled,
          }).catchError((_) {});
          return updated;
        }
      }
      return existing;
    }

    // Acak urutan butir soal khusus untuk akun siswa ini (seed berbasis examId + student.id)
    final exam = _exams.where((e) => e.id == examId).firstOrNull;

    // Jika jadwal ujian sudah lewat sebelum siswa memulai, buat sesi status completed dengan nilai 0
    final isScheduleExpired = exam != null && exam.endTime != null && DateTime.now().isAfter(exam.endTime!);

    final shuffledQuestionIds = <String>[];
    if (exam != null && exam.questionIds.isNotEmpty) {
      shuffledQuestionIds.addAll(exam.questionIds);
      final seed = '${examId}_${student.id}'.hashCode;
      shuffledQuestionIds.shuffle(Random(seed));
    }

    final newSession = ExamSessionModel(
      id: _uuid.v4(),
      examId: examId,
      studentId: student.id,
      studentNis: student.nis ?? 'NIS-${student.id.substring(0, 4)}',
      studentName: student.fullName,
      studentClass: student.classId ?? 'Umum',
      status: isScheduleExpired ? 'completed' : 'in_progress',
      orderedQuestionIds: shuffledQuestionIds,
      startedAt: DateTime.now(),
      finishedAt: isScheduleExpired ? DateTime.now() : null,
      nonEssayScore: isScheduleExpired ? 0.0 : null,
      finalScore: isScheduleExpired ? 0.0 : null,
      updatedAt: DateTime.now(),
    );

    _examSessions.add(newSession);
    notifyListeners();

    // Persist session to Firestore
    db.collection('exam_sessions').doc(newSession.id).set(newSession.toMap()).catchError((e) {
      debugPrint('[Firestore] Error creating exam session: $e');
    });

    return newSession;
  }

  void saveExamAnswer({
    required String sessionId,
    required String questionId,
    required dynamic answer,
    int? nextQuestionIndex,
  }) {
    final index = _examSessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      final session = _examSessions[index];
      if (session.isCompleted) {
        debugPrint('[FirebaseService] Ujian sudah selesai. Jawaban tidak dapat diubah lagi.');
        return;
      }
      final exam = _exams.where((e) => e.id == session.examId).firstOrNull;
      if (exam != null) {
        final totalExamSeconds = exam.durationMinutes * 60;
        final elapsedSeconds = DateTime.now().difference(session.startedAt).inSeconds;
        final isTimeOver = elapsedSeconds >= totalExamSeconds;
        final isScheduleOver = exam.endTime != null && DateTime.now().isAfter(exam.endTime!);
        if (isTimeOver || isScheduleOver) {
          debugPrint('[FirebaseService] Waktu ujian telah habis. Jawaban ditolak dan ujian otomatis diselesaikan.');
          finishExam(sessionId);
          return;
        }
      }
      final newAnswers = Map<String, dynamic>.from(session.answers);
      newAnswers[questionId] = answer;

      final updated = session.copyWith(
        answers: newAnswers,
        currentQuestionIndex: nextQuestionIndex ?? session.currentQuestionIndex,
        updatedAt: DateTime.now(),
      );
      _examSessions[index] = updated;
      notifyListeners();

      db.collection('exam_sessions').doc(sessionId).set(
        updated.toMap(),
        SetOptions(merge: true),
      ).catchError((e) {
        debugPrint('[Firestore] Error saving answer: $e');
      });
    }
  }

  void reportExamViolation({
    required String sessionId,
    required String reason,
    bool instantLock = false,
  }) =>
      recordAntiCheatViolation(
        sessionId: sessionId,
        reason: reason,
        instantLock: instantLock,
      );

  void recordAntiCheatViolation({
    required String sessionId,
    required String reason,
    bool instantLock = false,
  }) {
    final index = _examSessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      final session = _examSessions[index];
      if (session.antiCheatDisabledForStudent) {
        // Guru menonaktifkan deteksi kecurangan khusus untuk siswa ini
        return;
      }
      final newViolationCount = session.violationCount + 1;
      final isLocked = instantLock || newViolationCount >= 3;

      final updated = session.copyWith(
        violationCount: newViolationCount,
        lastViolationReason: reason,
        status: isLocked ? 'locked' : session.status,
        updatedAt: DateTime.now(),
      );
      _examSessions[index] = updated;
      notifyListeners();

      db.collection('exam_sessions').doc(sessionId).update({
        'violation_count': newViolationCount,
        'last_violation_reason': reason,
        if (isLocked) 'status': 'locked',
        'updated_at': DateTime.now().toIso8601String(),
      }).catchError((e) {
        debugPrint('[Firestore] Error recording violation: $e');
      });
    }
  }

  /// Sakelar pengawasan anti-cheat khusus per masing-masing siswa (misal HP siswa error/bermasalah)
  void toggleStudentAntiCheat(String sessionId, bool disabled) {
    final index = _examSessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      final session = _examSessions[index];
      final updated = session.copyWith(
        antiCheatDisabledForStudent: disabled,
        // Jika dinonaktifkan dan sedang terkunci, otomatis unblock siswa
        status: (disabled && session.isLocked) ? 'in_progress' : session.status,
        updatedAt: DateTime.now(),
      );
      _examSessions[index] = updated;
      notifyListeners();

      db.collection('exam_sessions').doc(sessionId).update({
        'anti_cheat_disabled_for_student': disabled,
        if (disabled && session.isLocked) 'status': 'in_progress',
        'updated_at': DateTime.now().toIso8601String(),
      }).catchError((e) {
        debugPrint('[Firestore] Error toggling student anti-cheat: $e');
      });
    }
  }

  void unblockExamSession(String sessionId) {
    final index = _examSessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      final session = _examSessions[index];
      final updated = session.copyWith(
        status: 'in_progress',
        violationCount: 0,
        updatedAt: DateTime.now(),
      );
      _examSessions[index] = updated;
      notifyListeners();

      db.collection('exam_sessions').doc(sessionId).update({
        'status': 'in_progress',
        'violation_count': 0,
        'updated_at': DateTime.now().toIso8601String(),
      }).catchError((e) {
        debugPrint('[Firestore] Error unblocking session: $e');
      });
    }
  }

  /// Soft Session Refresh: merefresh koneksi tanpa menghapus lembar jawaban siswa
  void clearExamSessionCache(String sessionId) {
    final index = _examSessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      final session = _examSessions[index];
      final updated = session.copyWith(
        updatedAt: DateTime.now(),
      );
      _examSessions[index] = updated;
      notifyListeners();

      db.collection('exam_sessions').doc(sessionId).update({
        'updated_at': DateTime.now().toIso8601String(),
      }).catchError((e) {
        debugPrint('[Firestore] Error clearing session cache: $e');
      });
    }
  }

  void resetExamSession(String sessionId) {
    final index = _examSessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      final session = _examSessions[index];
      // Acak ulang jika direset
      final exam = _exams.where((e) => e.id == session.examId).firstOrNull;
      final shuffledIds = <String>[];
      if (exam != null && exam.questionIds.isNotEmpty) {
        shuffledIds.addAll(exam.questionIds);
        shuffledIds.shuffle();
      }
      final updated = session.copyWith(
        status: 'in_progress',
        orderedQuestionIds: shuffledIds.isNotEmpty ? shuffledIds : session.orderedQuestionIds,
        answers: {},
        essayScores: {},
        violationCount: 0,
        currentQuestionIndex: 0,
        finishedAt: null,
        finalScore: null,
        nonEssayScore: null,
        updatedAt: DateTime.now(),
      );
      _examSessions[index] = updated;
      notifyListeners();

      db.collection('exam_sessions').doc(sessionId).set(updated.toMap()).catchError((e) {
        debugPrint('[Firestore] Error resetting session: $e');
      });
    }
  }

  void finishExam(String sessionId) {
    final index = _examSessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      final session = _examSessions[index];
      if (session.isCompleted) {
        debugPrint('[FirebaseService] Ujian sudah pernah diselesaikan.');
        return;
      }
      final exam = _exams.firstWhere((e) => e.id == session.examId, orElse: () => ExamModel(
        id: '', subjectId: '', teacherId: '', classIds: [], title: '', description: '', questionIds: [], createdAt: DateTime.now()
      ));
      final examQuestions = _questions.where((q) => exam.questionIds.contains(q.id)).toList();

      int nonEssayTotal = 0;
      int nonEssayCorrect = 0;

      for (final q in examQuestions) {
        if (q.type != QuestionType.essay) {
          nonEssayTotal++;
          final ans = session.answers[q.id];
          if (ans != null) {
            if (q.type == QuestionType.single && ans.toString() == q.correctAnswers.toString()) {
              nonEssayCorrect++;
            } else if (q.type == QuestionType.trueFalse && ans == q.correctAnswers) {
              nonEssayCorrect++;
            } else if (q.type == QuestionType.multi) {
              final correctList = List<String>.from(q.correctAnswers is List ? q.correctAnswers : [q.correctAnswers.toString()]);
              if (correctList.isNotEmpty) {
                final studentList = List<String>.from(ans is List ? ans : [ans.toString()]);
                if (correctList.length == studentList.length &&
                    correctList.every((elem) => studentList.contains(elem))) {
                  nonEssayCorrect++;
                }
              }
            } else if (q.type == QuestionType.matching) {
              if (ans is Map && q.correctAnswers is Map) {
                bool matchAll = true;
                (q.correctAnswers as Map).forEach((k, v) {
                  if (ans[k]?.toString() != v?.toString()) matchAll = false;
                });
                if (matchAll) nonEssayCorrect++;
              }
            }
          }
        }
      }

      final hasEssay = examQuestions.any((q) => q.type == QuestionType.essay);
      final nonEssayScore = nonEssayTotal > 0 ? (nonEssayCorrect / nonEssayTotal) * 100.0 : 100.0;
      final updated = session.copyWith(
        status: 'completed',
        nonEssayScore: nonEssayScore,
        finalScore: hasEssay ? null : nonEssayScore,
        finishedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _examSessions[index] = updated;
      notifyListeners();

      db.collection('exam_sessions').doc(sessionId).set(updated.toMap()).catchError((e) {
        debugPrint('[Firestore] Error finishing exam: $e');
      });

      // Award points for completing exam (balanced: 10-50 pts + 20 bonus for perfect 100)
      int pts = (nonEssayScore * 0.5).round().clamp(10, 50);
      String ptsReason = 'Penyelesaian Kuis: ${exam.title}';
      if (nonEssayScore >= 100.0) {
        pts += 20;
        ptsReason = 'Nilai Sempurna 100! Kuis: ${exam.title} 💯';
      }
      addPoints(
        studentId: session.studentId,
        points: pts,
        reason: ptsReason,
      );

      // 🔥 Nyalakan / perbarui Streak Belajar Non-Chat
      final isQuiz = exam.title.toLowerCase().contains('kuis') ||
          exam.title.toLowerCase().contains('quiz');
      triggerStudyActivityStreak(
        studentId: session.studentId,
        activityType: isQuiz ? 'quiz' : 'ujian',
        detail: exam.title,
      );
    }
  }

  void gradeExamEssay({
    required String sessionId,
    required String questionId,
    required double score, // 1 to 5
  }) {
    final index = _examSessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      final session = _examSessions[index];
      final newEssayScores = Map<String, double>.from(session.essayScores);
      newEssayScores[questionId] = score.clamp(1.0, 5.0);

      final exam = _exams.firstWhere((e) => e.id == session.examId, orElse: () => ExamModel(
        id: '', subjectId: '', teacherId: '', classIds: [], title: '', description: '', questionIds: [], createdAt: DateTime.now()
      ));
      final examQuestions = _questions.where((q) => exam.questionIds.contains(q.id)).toList();
      final totalEssays = examQuestions.where((q) => q.type == QuestionType.essay).length;

      double? finalScore = session.nonEssayScore;
      if (totalEssays > 0) {
        final totalEssaySum = newEssayScores.values.fold(0.0, (acc, s) => acc + s);
        final essayScore100 = (totalEssaySum / (totalEssays * 5.0)) * 100.0;
        finalScore = ((session.nonEssayScore ?? 0.0) * 0.7) + (essayScore100 * 0.3);
      }

      final updated = session.copyWith(
        essayScores: newEssayScores,
        finalScore: finalScore,
        updatedAt: DateTime.now(),
      );
      _examSessions[index] = updated;
      notifyListeners();

      db.collection('exam_sessions').doc(sessionId).set(updated.toMap()).catchError((e) {
        debugPrint('[Firestore] Error grading essay: $e');
      });
    }
  }

  void gradeExamEssays({
    required String sessionId,
    required Map<String, double> essayScores,
  }) {
    final index = _examSessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      final session = _examSessions[index];
      final newEssayScores = Map<String, double>.from(session.essayScores);
      newEssayScores.addAll(essayScores);

      final exam = _exams.firstWhere((e) => e.id == session.examId, orElse: () => ExamModel(
        id: '', subjectId: '', teacherId: '', classIds: [], title: '', description: '', questionIds: [], createdAt: DateTime.now()
      ));
      final examQuestions = _questions.where((q) => exam.questionIds.contains(q.id)).toList();
      final totalEssays = examQuestions.where((q) => q.type == QuestionType.essay).length;

      double? finalScore = session.nonEssayScore;
      if (totalEssays > 0) {
        final totalEssaySum = newEssayScores.values.fold(0.0, (acc, s) => acc + s);
        final essayScore100 = (totalEssaySum / (totalEssays * 5.0)) * 100.0;
        finalScore = ((session.nonEssayScore ?? 0.0) * 0.7) + (essayScore100 * 0.3);
      }

      final updated = session.copyWith(
        essayScores: newEssayScores,
        finalScore: finalScore,
        status: 'finished',
        updatedAt: DateTime.now(),
      );
      _examSessions[index] = updated;
      notifyListeners();

      db.collection('exam_sessions').doc(sessionId).set(updated.toMap()).catchError((e) {
        debugPrint('[Firestore] Error grading essays: $e');
      });
    }
  }

  // ==================== STREAKS & CHAT ====================

  Future<void> createStreak(StreakModel streak) async {
    _streaks.add(streak);
    notifyListeners();
    try {
      await db.collection('streaks').doc(streak.id).set(streak.toMap());
    } catch (e) {
      debugPrint('[Firestore] Error creating streak: $e');
    }
  }

  Future<void> sendChatMessage({
    required String streakId,
    required String message,
    String? replyToMessageId,
    String? replyToSenderName,
    String? replyToText,
  }) async {
    if (_currentUser == null || message.trim().isEmpty) return;

    // Terapkan filter konten sebelum menyimpan
    final filteredMessage =
        ContentFilterService.instance.filter(message.trim());
    final filteredReplyText = replyToText != null
        ? ContentFilterService.instance.filter(replyToText)
        : null;

    final newMsg = ChatMessageModel(
      id: _uuid.v4(),
      streakId: streakId,
      senderId: _currentUser!.id,
      senderName: _currentUser!.fullName,
      message: filteredMessage,
      sentAt: DateTime.now(),
      replyToMessageId: replyToMessageId,
      replyToSenderName: replyToSenderName,
      replyToText: filteredReplyText,
    );

    _chatMessages.add(newMsg);
    notifyListeners();

    try {
      await db.collection('chat_messages').doc(newMsg.id).set(newMsg.toMap());

      // Otomatis kirim notifikasi pesan baru ke penerima chat
      final sIdx = _streaks.indexWhere((s) => s.id == streakId);
      if (sIdx != -1) {
        final streak = _streaks[sIdx];
        final recipientIds = streak.participantIds.where((id) => id != _currentUser!.id).toList();
        if (recipientIds.isNotEmpty) {
          final snippet = filteredMessage.length > 50
              ? '${filteredMessage.substring(0, 50)}...'
              : filteredMessage;
          unawaited(createNotification(
            title: '💬 Pesan dari ${_currentUser!.fullName}',
            body: snippet,
            type: 'chat',
            targetUserIds: recipientIds,
            referenceId: streakId,
          ));
        }
      }
    } catch (e) {
      debugPrint('[Firestore] Error sending chat: $e');
    }

    // Refresh streak timer & count (Hanya berlaku 1 hari 1 streak, guru tidak memiliki streak)
    final streakIndex = _streaks.indexWhere((s) => s.id == streakId);
    if (streakIndex != -1) {
      final s = _streaks[streakIndex];
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastDate = DateTime(
        s.lastInteractionAt.year,
        s.lastInteractionAt.month,
        s.lastInteractionAt.day,
      );
      final diffDays = today.difference(lastDate).inDays;

      int newStreak = s.streakCount;
      bool isNewDay = false;

      if (s.isDead || diffDays > 1) {
        // Jika streak padam (> 24 jam / lewat lebih dari 1 hari kalender), pulih mulai dari 1
        newStreak = 1;
        isNewDay = true;
      } else if (diffDays == 1) {
        // Beda tepat 1 hari kalender: tambah 1
        newStreak = (s.streakCount > 0 ? s.streakCount : 0) + 1;
        isNewDay = true;
      } else {
        // diffDays <= 0 (hari yang sama): streak count TIDAK bertambah (1 hari 1 doang!)
        newStreak = s.streakCount > 0 ? s.streakCount : 1;
        isNewDay = false;
      }

      // Expire at the end of tomorrow (23:59:59)
      final endOfTomorrow = DateTime(today.year, today.month, today.day + 2).subtract(const Duration(seconds: 1));

      // Poin HANYA untuk siswa dan jika hari kalender baru
      if (isNewDay && _currentUser != null && _currentUser!.isSiswa && !_isTeacherOrAdmin(_currentUser!.id)) {
        await addPoints(
          studentId: _currentUser!.id,
          points: 20,
          reason: 'Streak Chat Hari ke-$newStreak 🔥',
        );
      }

      final updated = s.copyWith(
        streakCount: newStreak,
        lastInteractionAt: now,
        expiresAt: endOfTomorrow,
        isRestored: false,
      );
      _streaks[streakIndex] = updated;
      notifyListeners();

      try {
        await db.collection('streaks').doc(streakId).update({
          'streak_count': newStreak,
          'last_interaction_at': now.toIso8601String(),
          'expires_at': endOfTomorrow.toIso8601String(),
          'is_restored': false,
        });
      } catch (e) {
        debugPrint('[Firestore] Error updating streak: $e');
      }
    }

    // Juga sinkronkan / nyalakan streak belajar mandiri siswa jika pengirim adalah siswa
    if (_currentUser != null && _currentUser!.isSiswa && !_isTeacherOrAdmin(_currentUser!.id)) {
      await triggerStudyActivityStreak(
        studentId: _currentUser!.id,
        activityType: 'chat',
      );
    }
  }

  /// Pulihkan streak yang mati/padam tanpa batas
  Future<void> restoreStreak({required String streakId}) async {
    final streakIndex = _streaks.indexWhere((s) => s.id == streakId);
    if (streakIndex == -1) return;

    final s = _streaks[streakIndex];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endOfTomorrow = DateTime(today.year, today.month, today.day + 2).subtract(const Duration(seconds: 1));
    final restoredCount = s.streakCount > 0 ? s.streakCount : 1;

    final updated = s.copyWith(
      streakCount: restoredCount,
      lastInteractionAt: now,
      expiresAt: endOfTomorrow,
      isRestored: true,
    );

    _streaks[streakIndex] = updated;
    notifyListeners();

    try {
      await db.collection('streaks').doc(streakId).update({
        'streak_count': restoredCount,
        'last_interaction_at': now.toIso8601String(),
        'expires_at': endOfTomorrow.toIso8601String(),
        'is_restored': true,
      });
    } catch (e) {
      debugPrint('[Firestore] Error restoring streak: $e');
    }
  }

  /// Helper untuk testing: mensimulasikan streak hangus / padam (> 1 hari)
  void expireStreakForTesting(String streakId) {
    final idx = _streaks.indexWhere((s) => s.id == streakId);
    if (idx != -1) {
      _streaks[idx] = _streaks[idx].copyWith(
        expiresAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      notifyListeners();
    }
  }

  /// Helper pengecekan apakah user adalah guru atau admin (guru & admin tidak memiliki streak)
  bool _isTeacherOrAdmin(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    if (_currentUser?.id == userId) {
      return _currentUser!.isGuru || _currentUser!.role == 'guru' || _currentUser!.role == 'admin';
    }
    final teacher = _allTeachers.where((t) => t.id == userId).firstOrNull;
    if (teacher != null) return true;
    final student = _allStudents.where((s) => s.id == userId).firstOrNull;
    if (student != null) {
      return student.isGuru || student.role == 'guru' || student.role == 'admin';
    }
    return false;
  }

  /// Memperbarui / menyalakan Streak Belajar Mandiri (Non-Chat) siswa
  /// Dipanggil saat siswa:
  /// 1. Belajar materi (membaca modul/menonton video materi)
  /// 2. Mengerjakan tugas (submit tugas)
  /// 3. Mengerjakan ujian atau quiz (menyelesaikan kuis/ujian)
  /// 4. Berpartisipasi dalam diskusi chat belajar
  /// CATATAN: Guru & admin tidak memiliki streak. Streak hanya bertambah 1 per hari kalender (1 hari 1 doang).
  Future<void> triggerStudyActivityStreak({
    required String studentId,
    required String activityType, // 'materi' | 'tugas' | 'ujian' | 'quiz' | 'chat'
    String? detail,
  }) async {
    if (studentId.isEmpty) return;
    if (_isTeacherOrAdmin(studentId)) return; // Guru dan Admin tidak memiliki streak!

    final student = _allStudents.where((u) => u.id == studentId).firstOrNull ??
        (_currentUser?.id == studentId ? _currentUser : null);
    if (student == null || student.isGuru || student.role == 'guru' || student.role == 'admin') {
      return;
    }
    final studentName = student.fullName.isNotEmpty ? student.fullName : 'Siswa';

    final streakId = 'streak_study_$studentId';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Expire di akhir besok (23:59:59) sehingga user memiliki sisa hari ini dan sepanjang hari besok
    final endOfTomorrow = DateTime(today.year, today.month, today.day + 2).subtract(const Duration(seconds: 1));

    final existingIndex = _streaks.indexWhere((s) => s.id == streakId);
    StreakModel studyStreak;

    int newStreak = 1;
    bool isNewDay = false;

    if (existingIndex != -1) {
      final s = _streaks[existingIndex];
      final lastDate = DateTime(
        s.lastInteractionAt.year,
        s.lastInteractionAt.month,
        s.lastInteractionAt.day,
      );
      final diffDays = today.difference(lastDate).inDays;

      if (s.isDead || diffDays > 1) {
        // Jika sudah padam / lewat lebih dari 1 hari, mulai kembali dari 1
        newStreak = 1;
        isNewDay = true;
      } else if (diffDays == 1) {
        // Hari kalender berikutnya (konsekutif): tambah 1 hari
        newStreak = (s.streakCount > 0 ? s.streakCount : 0) + 1;
        isNewDay = true;
      } else {
        // diffDays <= 0 (hari yang sama): streak count TIDAK bertambah (1 hari 1 doang!)
        newStreak = s.streakCount > 0 ? s.streakCount : 1;
        isNewDay = false;
      }

      studyStreak = s.copyWith(
        streakCount: newStreak,
        lastInteractionAt: now,
        expiresAt: endOfTomorrow,
        isRestored: false,
      );
      _streaks[existingIndex] = studyStreak;
    } else {
      // Belum ada streak belajar, buat baru dan langsung nyalakan ke-1
      studyStreak = StreakModel(
        id: streakId,
        type: StreakType.study,
        title: 'Streak Belajar Mandiri 🔥',
        participantIds: [studentId],
        participantNames: [studentName],
        streakCount: 1,
        lastInteractionAt: now,
        expiresAt: endOfTomorrow,
      );
      _streaks.add(studyStreak);
      newStreak = 1;
      isNewDay = true;
    }

    Future.microtask(() {
      notifyListeners();
    });

    try {
      await db.collection('streaks').doc(streakId).set(studyStreak.toMap());
    } catch (e) {
      debugPrint('[Firestore] Error saving study streak: $e');
    }

    // Berikan reward poin HANYA jika streak bertambah di hari baru
    if (isNewDay && (student.isSiswa || student.role == 'siswa')) {
      String activityLabel;
      switch (activityType) {
        case 'materi':
          activityLabel = 'Belajar Materi 📖';
          break;
        case 'tugas':
          activityLabel = 'Mengerjakan Tugas 📝';
          break;
        case 'ujian':
          activityLabel = 'Mengerjakan Ujian 🎯';
          break;
        case 'quiz':
          activityLabel = 'Mengerjakan Kuis 🏆';
          break;
        case 'chat':
          activityLabel = 'Diskusi Belajar 💬';
          break;
        default:
          activityLabel = 'Aktivitas Belajar 🚀';
      }

      await addPoints(
        studentId: studentId,
        points: 20,
        reason: 'Streak Belajar Hari ke-$newStreak 🔥 ($activityLabel)',
      );
    }
  }

  /// Mendapatkan jumlah streak efektif tertinggi milik user yang sedang aktif.
  /// Guru & Admin selalu bernilai 0 karena streak dikhususkan untuk siswa.
  int getEffectiveStreakCount(String? userId) {
    if (userId == null || userId.isEmpty) return 0;
    if (_isTeacherOrAdmin(userId)) return 0; // Guru dan Admin tidak memiliki streak!

    final userStreaks = _streaks.where((s) => s.participantIds.contains(userId)).toList();
    if (userStreaks.isEmpty) return 0;

    final activeCounts = userStreaks
        .where((s) => !s.isDead && s.streakCount > 0)
        .map((s) => s.streakCount)
        .toList();

    if (activeCounts.isNotEmpty) {
      return activeCounts.reduce((a, b) => a > b ? a : b);
    }
    return 0;
  }

  /// Mengecek apakah user memiliki setidaknya satu streak yang sedang aktif.
  /// Guru & Admin selalu bernilai false.
  bool hasActiveStreak(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    if (_isTeacherOrAdmin(userId)) return false; // Guru dan Admin tidak memiliki streak!

    return _streaks.any((s) => s.participantIds.contains(userId) && !s.isDead && s.streakCount > 0);
  }

  /// Mendapatkan model Streak Belajar Mandiri (Non-Chat) siswa.
  /// Guru & Admin selalu bernilai null.
  StreakModel? getStudyStreak(String? studentId) {
    if (studentId == null || studentId.isEmpty) return null;
    if (_isTeacherOrAdmin(studentId)) return null; // Guru dan Admin tidak memiliki streak!

    return _streaks
        .where((s) =>
            s.id == 'streak_study_$studentId' ||
            (s.type == StreakType.study && s.participantIds.contains(studentId)))
        .firstOrNull;
  }

  /// Edit pesan yang sudah terkirim (mirip WhatsApp)
  Future<void> editChatMessage({
    required String messageId,
    required String newText,
  }) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;

    // Terapkan filter konten sebelum menyimpan
    final filteredText = ContentFilterService.instance.filter(trimmed);

    final idx = _chatMessages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      final old = _chatMessages[idx];
      final updated = old.copyWith(
        message: filteredText,
        isEdited: true,
        editedAt: DateTime.now(),
      );
      _chatMessages[idx] = updated;
      notifyListeners();

      try {
        await db.collection('chat_messages').doc(messageId).update({
          'message': filteredText,
          'is_edited': true,
          'edited_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('[Firestore] Error editing message: $e');
      }
    }
  }

  /// Hapus pesan (mirip WhatsApp)
  Future<void> deleteChatMessage({required String messageId}) async {
    _chatMessages.removeWhere((m) => m.id == messageId);
    notifyListeners();

    try {
      await db.collection('chat_messages').doc(messageId).delete();
    } catch (e) {
      debugPrint('[Firestore] Error deleting message: $e');
    }
  }

  // ==================== GAMIFICATION & POINTS ====================

  Future<void> addPoints({
    required String studentId,
    required int points,
    required String reason,
  }) async {
    // Update local currentUser
    if (_currentUser != null && _currentUser!.id == studentId) {
      _currentUser = _currentUser!.copyWith(
        totalPoints: _currentUser!.totalPoints + points,
      );
    }

    // Update _allStudents
    final studentIndex = _allStudents.indexWhere((s) => s.id == studentId);
    if (studentIndex != -1) {
      final s = _allStudents[studentIndex];
      _allStudents[studentIndex] = s.copyWith(
        totalPoints: s.totalPoints + points,
      );
    }

    final tx = PointTransactionModel(
      id: _uuid.v4(),
      studentId: studentId,
      points: points,
      reason: reason,
      isDebit: false,
      createdAt: DateTime.now(),
    );
    _pointTransactions.insert(0, tx);
    notifyListeners();

    // Persist transaction & user point increment in Firestore
    try {
      await db.collection('point_transactions').doc(tx.id).set(tx.toMap());
      await db.collection('users').doc(studentId).update({
        'total_points': FieldValue.increment(points),
      });
    } catch (e) {
      debugPrint('[Firestore] Error adding points: $e');
    }
  }

  /// Get total redeemed bonus points for a student in a specific subject
  double getSubjectRedeemedBonus(String studentId, String subjectId, [String? subjectName]) {
    final redeems = _gradeRedeems.where((r) =>
        r.studentId == studentId &&
        (r.subjectId == subjectId ||
            (subjectName != null &&
                r.subjectName.trim().toLowerCase() == subjectName.trim().toLowerCase())));
    return redeems.fold(0.0, (acc, r) => acc + r.bonusGrade);
  }

  /// Record activity in Code Playground and award initial daily points
  Future<void> recordCodePlaygroundActivity({
    required String studentId,
    required String language,
  }) async {
    if (studentId.isEmpty) return;
    final list = _studentCodeRuns.putIfAbsent(studentId, () => []);
    list.add(language.toLowerCase());

    // Daily coding reward: award +15 points once per day
    final now = DateTime.now();
    final alreadyAwardedToday = _pointTransactions.any((t) =>
        t.studentId == studentId &&
        !t.isDebit &&
        t.reason.contains('Code Playground') &&
        t.createdAt.year == now.year &&
        t.createdAt.month == now.month &&
        t.createdAt.day == now.day);

    if (!alreadyAwardedToday) {
      await addPoints(
        studentId: studentId,
        points: 15,
        reason: 'Eksplorasi Praktikum IDE: ${language.toUpperCase()} 💻',
      );
    }
    notifyListeners();
  }

  int getStudentCodeRunsCount(String studentId) {
    return _studentCodeRuns[studentId]?.length ?? 0;
  }

  bool hasStudentTestedLanguage(String studentId, String lang) {
    return _studentCodeRuns[studentId]?.any((l) => l.contains(lang.toLowerCase())) ?? false;
  }

  Future<void> redeemGradeBonus({
    required String studentId,
    required String subjectId,
    required String subjectName,
    required int pointsToSpend,
  }) async {
    final currentPoints = _currentUser?.totalPoints ?? 0;
    if (currentPoints < pointsToSpend) {
      throw Exception('Poin tidak mencukupi untuk melakukan penukaran.');
    }
    if (pointsToSpend < 500) {
      throw Exception('Minimal penukaran adalah 500 poin (+1.0 nilai).');
    }

    final bonusGrade = (pointsToSpend / 500).floor() * 1.0;

    // Anti-Inflation Guard: Maximum +5.0 bonus grade per subject to maintain academic integrity
    const maxBonusAllowed = 5.0;
    final currentBonus = getSubjectRedeemedBonus(studentId, subjectId, subjectName);
    if (currentBonus + bonusGrade > maxBonusAllowed) {
      final remaining = (maxBonusAllowed - currentBonus).clamp(0.0, maxBonusAllowed);
      if (remaining <= 0) {
        throw Exception(
          'Mata pelajaran $subjectName sudah mencapai batas maksimal penukaran bonus (+5.0 Nilai). Kebijakan ini diberlakukan agar tidak terjadi inflasi nilai akademik.',
        );
      } else {
        throw Exception(
          'Penukaran melebihi batas anti-inflasi! Anda hanya dapat menambah maksimal +${remaining.toStringAsFixed(1)} lagi untuk $subjectName (maksimal akumulasi +5.0 nilai).',
        );
      }
    }

    // Deduct local points
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        totalPoints: _currentUser!.totalPoints - pointsToSpend,
      );
    }

    final studentIndex = _allStudents.indexWhere((s) => s.id == studentId);
    if (studentIndex != -1) {
      _allStudents[studentIndex] = _allStudents[studentIndex].copyWith(
        totalPoints: _allStudents[studentIndex].totalPoints - pointsToSpend,
      );
    }

    final tx = PointTransactionModel(
      id: _uuid.v4(),
      studentId: studentId,
      points: pointsToSpend,
      reason: 'Penukaran $pointsToSpend Poin ke Nilai Mapel $subjectName (+$bonusGrade)',
      isDebit: true,
      createdAt: DateTime.now(),
    );
    _pointTransactions.insert(0, tx);

    final redeem = GradeRedeemModel(
      id: _uuid.v4(),
      studentId: studentId,
      subjectId: subjectId,
      subjectName: subjectName,
      pointsSpent: pointsToSpend,
      bonusGrade: bonusGrade,
      createdAt: DateTime.now(),
    );
    _gradeRedeems.insert(0, redeem);
    notifyListeners();

    try {
      await db.collection('point_transactions').doc(tx.id).set(tx.toMap());
      await db.collection('grade_redeems').doc(redeem.id).set(redeem.toMap());
      await db.collection('users').doc(studentId).update({
        'total_points': FieldValue.increment(-pointsToSpend),
      });
    } catch (e) {
      debugPrint('[Firestore] Error redeeming grade bonus: $e');
    }
  }

  Future<void> redeemPointsForGrade({
    required String studentId,
    required String subjectId,
    required String subjectName,
    required int pointsToSpend,
  }) => redeemGradeBonus(
    studentId: studentId,
    subjectId: subjectId,
    subjectName: subjectName,
    pointsToSpend: pointsToSpend,
  );

  /// Calculate grades per subject for a student (combines exams, assignments, & gamification bonus)
  List<StudentSubjectGrade> getStudentSubjectGrades(UserModel student) {
    var subjectList = List<SubjectModel>.from(_subjects);
    if (subjectList.isEmpty) {
      subjectList = [
        SubjectModel(
          id: 'subj_web',
          name: 'Informatika & Pemrograman Web',
          code: 'INF-10',
          icon: 'code',
        ),
        SubjectModel(
          id: 'subj_db',
          name: 'Basis Data & SQL',
          code: 'BD-11',
          icon: 'storage',
        ),
        SubjectModel(
          id: 'subj_pbo',
          name: 'Pemrograman Berorientasi Objek',
          code: 'PBO-11',
          icon: 'terminal',
        ),
      ];
    }

    final List<StudentSubjectGrade> results = [];

    for (final subject in subjectList) {
      // 1. Exams for this subject
      final subjectExams = _exams.where((e) => e.subjectId == subject.id).toList();
      final subjectExamIds = subjectExams.map((e) => e.id).toSet();

      final studentSessions = _examSessions.where((s) =>
          s.studentId == student.id &&
          s.isCompleted &&
          subjectExamIds.contains(s.examId)).toList();

      final double? examAvg = studentSessions.isNotEmpty
          ? (studentSessions.map((s) => s.finalScore ?? 0.0).reduce((a, b) => a + b) /
              studentSessions.length)
          : null;

      // 2. Assignments for this subject
      final subjectAssignments = _assignments.where((a) => a.subjectId == subject.id).toList();
      final subjectAssignIds = subjectAssignments.map((a) => a.id).toSet();

      final studentSubmissions = _submissions.where((s) =>
          (s.submitterId == student.id || s.memberStudentIds.contains(student.id)) &&
          subjectAssignIds.contains(s.assignmentId) &&
          s.score != null).toList();

      final double? assignAvg = studentSubmissions.isNotEmpty
          ? (studentSubmissions.map((s) => s.score!).reduce((a, b) => a + b) /
              studentSubmissions.length)
          : null;

      // 3. Bonus points redeemed for this subject
      final redeems = _gradeRedeems.where((r) =>
          r.studentId == student.id &&
          (r.subjectId == subject.id || r.subjectName.toLowerCase() == subject.name.toLowerCase()));
      final double bonusGrade = redeems.fold(0.0, (acc, r) => acc + r.bonusGrade);

      // 4. Calculate final score
      double? finalScore;
      if (examAvg != null && assignAvg != null) {
        finalScore = (examAvg * 0.6) + (assignAvg * 0.4) + bonusGrade;
      } else if (examAvg != null) {
        finalScore = examAvg + bonusGrade;
      } else if (assignAvg != null) {
        finalScore = assignAvg + bonusGrade;
      } else if (bonusGrade > 0) {
        finalScore = bonusGrade;
      }

      if (finalScore != null) {
        finalScore = double.parse(finalScore.clamp(0.0, 100.0).toStringAsFixed(1));
      }

      // Predicate and Status Color
      String predicate;
      Color statusColor;
      if (finalScore == null) {
        predicate = 'Belum Ada Nilai';
        statusColor = const Color(0xFF94A3B8); // Slate
      } else if (finalScore >= 88.0) {
        predicate = 'A (Sangat Baik)';
        statusColor = const Color(0xFF10B981); // Emerald
      } else if (finalScore >= 75.0) {
        predicate = 'B (Baik)';
        statusColor = const Color(0xFF3B82F6); // Blue
      } else if (finalScore >= 65.0) {
        predicate = 'C (Cukup)';
        statusColor = const Color(0xFFF59E0B); // Amber
      } else {
        predicate = 'D (Perlu Bimbingan)';
        statusColor = const Color(0xFFEF4444); // Red
      }

      results.add(StudentSubjectGrade(
        subject: subject,
        examAverage: examAvg,
        completedExams: studentSessions.length,
        totalExams: subjectExams.length,
        assignmentAverage: assignAvg,
        completedAssignments: studentSubmissions.length,
        totalAssignments: subjectAssignments.length,
        bonusGrade: bonusGrade,
        finalGrade: finalScore,
        predicate: predicate,
        statusColor: statusColor,
      ));
    }

    return results;
  }

  // ==================== STUDENT PROFILE & GAMIFICATION METHODS ====================

  /// Update student profile (class and password) in Cloud Firestore
  Future<void> updateStudentProfile({
    required String studentId,
    String? className,
    String? newPassword,
    String? fullName,
  }) async {
    final updateData = <String, dynamic>{};
    String? passwordHash;
    if (className != null && className.isNotEmpty) {
      updateData['class_id'] = className.trim();
      updateData['class_name'] = className.trim();
    }
    if (newPassword != null && newPassword.isNotEmpty) {
      final cleanPass = newPassword.trim();
      passwordHash = SecurityUtils.hashPassword(cleanPass, salt: studentId);
      updateData['initial_password'] = cleanPass;
      updateData['password_hash'] = passwordHash;
    }
    if (fullName != null && fullName.isNotEmpty) {
      updateData['full_name'] = fullName.trim();
    }

    // Update local state immediately
    final idx = _allStudents.indexWhere((s) => s.id == studentId);
    if (idx != -1) {
      final updated = _allStudents[idx].copyWith(
        className: className ?? _allStudents[idx].className,
        classId: className ?? _allStudents[idx].classId,
        initialPassword: newPassword ?? _allStudents[idx].initialPassword,
        passwordHash: passwordHash ?? _allStudents[idx].passwordHash,
        fullName: fullName ?? _allStudents[idx].fullName,
      );
      _allStudents[idx] = updated;

      if (_currentUser?.id == studentId) {
        _currentUser = updated;
      }
      notifyListeners();
    }

    if (updateData.isNotEmpty) {
      try {
        await db.collection('users').doc(studentId).update(updateData);
      } catch (e) {
        debugPrint('[Firestore] Error updating student profile: $e');
      }
    }
  }

  /// Update teacher profile (name, password, and assigned classes)
  Future<void> updateTeacherProfile({
    required String teacherId,
    String? fullName,
    String? newPassword,
    List<String>? classIds,
  }) async {
    final updateData = <String, dynamic>{};
    String? passwordHash;
    if (newPassword != null && newPassword.isNotEmpty) {
      final cleanPass = newPassword.trim();
      passwordHash = SecurityUtils.hashPassword(cleanPass, salt: teacherId);
      updateData['initial_password'] = cleanPass;
      updateData['password_hash'] = passwordHash;
    }
    if (fullName != null && fullName.isNotEmpty) {
      updateData['full_name'] = fullName.trim();
    }
    if (classIds != null) {
      updateData['class_ids'] = classIds;
    }

    if (_currentUser?.id == teacherId) {
      _currentUser = _currentUser!.copyWith(
        fullName: (fullName != null && fullName.isNotEmpty) ? fullName.trim() : _currentUser!.fullName,
        initialPassword: (newPassword != null && newPassword.isNotEmpty) ? newPassword.trim() : _currentUser!.initialPassword,
        passwordHash: passwordHash ?? _currentUser!.passwordHash,
        classIds: classIds ?? _currentUser!.classIds,
      );
      notifyListeners();
    }

    if (updateData.isNotEmpty) {
      try {
        await db.collection('users').doc(teacherId).update(updateData);
      } catch (e) {
        debugPrint('[Firestore] updateTeacherProfile error: $e');
      }
    }
  }


  /// Get available classes strictly configured in Firestore
  List<String> getAvailableClasses() {
    // Prioritas utama: daftar kelas yang dikelola Admin di Firebase Firestore (_schoolClasses)
    if (_schoolClasses.isNotEmpty) {
      final list = _schoolClasses
          .map((c) => c.name.trim())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();
      list.sort();
      return list;
    }

    final classes = <String>{};
    for (final s in _allStudents) {
      final cName = (s.className ?? s.classId ?? '').trim();
      if (cName.isNotEmpty) classes.add(cName);
    }
    for (final e in _exams) {
      for (final cid in e.classIds) {
        final trimmed = cid.trim();
        if (trimmed.isNotEmpty) classes.add(trimmed);
      }
    }
    for (final m in _materials) {
      for (final cid in m.classIds) {
        final trimmed = cid.trim();
        if (trimmed.isNotEmpty) classes.add(trimmed);
      }
    }
    final list = classes.toList();
    list.sort();
    return list;
  }

  /// Get subjects specifically taught by the teacher (strictly based on Admin plotting)
  List<SubjectModel> getTeacherSubjects([UserModel? teacher]) {
    final user = teacher ?? _currentUser;
    if (user == null || !user.isGuru) return subjects;

    if (user.subjectIds.isNotEmpty) {
      final userSubjLower = user.subjectIds.map((s) => s.trim().toLowerCase()).toSet();
      final matched = subjects.where((s) =>
          userSubjLower.contains(s.id.toLowerCase()) ||
          userSubjLower.contains(s.name.toLowerCase()) ||
          userSubjLower.contains(s.code.toLowerCase())).toList();
      if (matched.isNotEmpty) return matched;
    }

    // STRICT: If not plotted by admin, return empty list!
    return <SubjectModel>[];
  }

  /// Get classes specifically taught by the teacher (strictly based on Admin plotting)
  List<String> getTeacherClasses([UserModel? teacher]) {
    final user = teacher ?? _currentUser;
    final allAvailable = getAvailableClasses();
    if (user == null || !user.isGuru) return allAvailable;

    // STRICT: If teacher has not been assigned classes by Admin, return empty list!
    if (user.classIds.isEmpty) {
      return <String>[];
    }

    final matched = <String>{};
    for (final cid in user.classIds) {
      final trimmed = cid.trim();
      if (trimmed.isEmpty) continue;

      // Match against _schoolClasses by id or name
      final sc = _schoolClasses.where((c) =>
          c.id.toLowerCase() == trimmed.toLowerCase() ||
          c.name.toLowerCase() == trimmed.toLowerCase()).firstOrNull;
      if (sc != null) {
        matched.add(sc.name);
      } else if (allAvailable.any((a) => a.toLowerCase() == trimmed.toLowerCase())) {
        final exact = allAvailable.firstWhere((a) => a.toLowerCase() == trimmed.toLowerCase());
        matched.add(exact);
      } else {
        matched.add(trimmed);
      }
    }

    final list = matched.toList();
    list.sort();
    return list;
  }

  /// Get all students belonging to classes taught by the teacher
  List<UserModel> getTeacherStudents([UserModel? teacher]) {
    final user = teacher ?? _currentUser;
    if (user != null && !user.isGuru) return _allStudents;

    final taughtClasses = getTeacherClasses(user);
    if (taughtClasses.isEmpty) return <UserModel>[];

    final taughtClassesLower = taughtClasses.map((c) => c.trim().toLowerCase()).toSet();
    final list = _allStudents.where((s) {
      final sClass = (s.className ?? s.classId ?? '').trim().toLowerCase();
      return taughtClassesLower.contains(sClass);
    }).toList();
    for (final s in list) {
      _ensureStudentDataSeeded(s);
    }
    return list;
  }

  /// Get exams specifically taught by this teacher (strictly matching taught subjects & classes)
  List<ExamModel> getTeacherExams([UserModel? teacher]) {
    final user = teacher ?? _currentUser;
    if (user == null || !user.isGuru) return exams;

    final taughtSubjects = getTeacherSubjects(user);
    final taughtClasses = getTeacherClasses(user);

    // If teacher is not plotted to any subject AND not plotted to any class, return empty!
    if (taughtSubjects.isEmpty && taughtClasses.isEmpty) return <ExamModel>[];

    final taughtSubjectIds = taughtSubjects.map((s) => s.id.toLowerCase()).toSet();
    final taughtClassesLower = taughtClasses.map((c) => c.trim().toLowerCase()).toSet();

    return _exams.where((e) {
      final isAuthor = e.teacherId == user.id;
      final subjectMatch = taughtSubjectIds.contains(e.subjectId.toLowerCase());
      if (!subjectMatch && !isAuthor) return false;

      // Author can always see their own exams
      if (isAuthor) return true;

      // If teacher teaches this subject
      if (subjectMatch) {
        if (e.classIds.isEmpty) return true;
        if (taughtClassesLower.isNotEmpty) {
          final match = e.classIds.any((cid) => taughtClassesLower.contains(cid.trim().toLowerCase()));
          if (match) return true;
          return true;
        }
        return true;
      }
      return false;
    }).toList();
  }

  /// Get materials specifically taught by this teacher (strictly matching taught subjects & classes)
  List<MaterialModel> getTeacherMaterials([UserModel? teacher]) {
    final user = teacher ?? _currentUser;
    if (user == null || !user.isGuru) return materials;

    final taughtSubjects = getTeacherSubjects(user);
    final taughtClasses = getTeacherClasses(user);

    // If teacher is not plotted to any subject AND not plotted to any class, return empty!
    if (taughtSubjects.isEmpty && taughtClasses.isEmpty) return <MaterialModel>[];

    final taughtSubjectIds = taughtSubjects.map((s) => s.id.toLowerCase()).toSet();
    final taughtClassesLower = taughtClasses.map((c) => c.trim().toLowerCase()).toSet();

    return _materials.where((m) {
      final isAuthor = m.teacherId == user.id;
      final subjectMatch = taughtSubjectIds.contains(m.subjectId.toLowerCase());
      if (!subjectMatch && !isAuthor) return false;

      // Author can always see their own materials
      if (isAuthor) return true;

      // If teacher teaches this subject
      if (subjectMatch) {
        if (m.classIds.isEmpty) return true;
        if (taughtClassesLower.isNotEmpty) {
          final match = m.classIds.any((cid) => taughtClassesLower.contains(cid.trim().toLowerCase()));
          if (match) return true;
          return true;
        }
        return true;
      }
      return false;
    }).toList();
  }

  /// Get question bank filtered for teacher's taught subjects
  List<QuestionModel> getTeacherQuestions([UserModel? teacher]) {
    final user = teacher ?? _currentUser;
    if (user == null || !user.isGuru) return questions;

    final taughtSubjects = getTeacherSubjects(user);
    if (taughtSubjects.isEmpty) return <QuestionModel>[];

    final taughtSubjectIds = taughtSubjects.map((s) => s.id).toSet();
    return _questions.where((q) => taughtSubjectIds.contains(q.subjectId)).toList();
  }

  /// Get CPs filtered for teacher's taught subjects
  List<CurriculumCpModel> getTeacherCps([UserModel? teacher]) {
    final user = teacher ?? _currentUser;
    if (user == null || !user.isGuru) return cps;

    final taughtSubjects = getTeacherSubjects(user);
    if (taughtSubjects.isEmpty) return <CurriculumCpModel>[];

    final taughtSubjectIds = taughtSubjects.map((s) => s.id).toSet();
    return _cps.where((c) => taughtSubjectIds.contains(c.subjectId)).toList();
  }

  /// Get TPs filtered for teacher's taught subjects
  List<CurriculumTpModel> getTeacherTps([UserModel? teacher]) {
    final user = teacher ?? _currentUser;
    if (user == null || !user.isGuru) return tps;

    final taughtSubjects = getTeacherSubjects(user);
    if (taughtSubjects.isEmpty) return <CurriculumTpModel>[];

    final taughtSubjectIds = taughtSubjects.map((s) => s.id).toSet();
    return _tps.where((t) => taughtSubjectIds.contains(t.subjectId)).toList();
  }

  /// Get streaks / chats strictly scoped for the teacher
  List<StreakModel> getTeacherStreaks([UserModel? teacher]) {
    final user = teacher ?? _currentUser;
    if (user == null || !user.isGuru) return streaks;

    final taughtClasses = getTeacherClasses(user);
    final taughtStudents = getTeacherStudents(user);
    final taughtStudentIds = taughtStudents.map((s) => s.id).toSet();
    final taughtStudentNames = taughtStudents.map((s) => s.fullName.toLowerCase()).toSet();
    final taughtClassesLower = taughtClasses.map((c) => c.toLowerCase()).toSet();

    return _streaks.where((s) {
      // 1. Class group chats
      if (s.type == StreakType.group) {
        if (taughtClassesLower.isEmpty) return false;
        return taughtClassesLower.any((cls) => s.title.toLowerCase().contains(cls));
      }

      // 2. Teacher-student consultations
      if (s.type == StreakType.teacher) {
        // Must involve this teacher
        if (!s.participantIds.contains(user.id) && !s.participantNames.contains(user.fullName)) {
          return false;
        }
        // Student participant must belong to teacher's taught classes
        final otherIds = s.participantIds.where((id) => id != user.id);
        if (otherIds.any((id) => taughtStudentIds.contains(id))) return true;

        final otherNames = s.participantNames.where((name) => name != user.fullName);
        return otherNames.any((name) => taughtStudentNames.contains(name.toLowerCase()));
      }

      // 3. Peer/other chats that the teacher participates in (e.g. teacher-to-teacher or admin)
      if (s.participantIds.contains(user.id)) return true;

      return false;
    }).toList();
  }

  /// No-op: Real student exam sessions and progress are saved when students take exams and view materials
  /// Checks if a target class (ID or Name) matches a list of class IDs / Names
  bool isClassMatching(String classIdOrName, List<String> targetClassIds) {
    if (targetClassIds.isEmpty) return false;
    final cleanTarget = classIdOrName.trim().toLowerCase();
    if (cleanTarget.isEmpty) return false;

    final targetNorm = cleanTarget.replaceAll(RegExp(r'^(kelas\s*|\s+)'), '');

    // Resolve matching school classes from _schoolClasses
    final matchingClasses = _schoolClasses.where((c) {
      final cName = c.name.trim().toLowerCase();
      final cId = c.id.trim().toLowerCase();
      return cName == cleanTarget || cId == cleanTarget;
    }).toList();

    final validTokens = <String>{
      cleanTarget,
      if (targetNorm.isNotEmpty) targetNorm,
      for (final mc in matchingClasses) ...[
        mc.id.trim().toLowerCase(),
        mc.name.trim().toLowerCase(),
        mc.name.trim().toLowerCase().replaceAll(RegExp(r'^(kelas\s*|\s+)'), ''),
      ],
    };

    return targetClassIds.any((cid) {
      final cleanCid = cid.trim().toLowerCase();
      if (validTokens.contains(cleanCid)) return true;
      final cidNorm = cleanCid.replaceAll(RegExp(r'^(kelas\s*|\s+)'), '');
      if (cidNorm.isNotEmpty && validTokens.contains(cidNorm)) return true;

      final sc = _schoolClasses.where((c) => c.id.trim().toLowerCase() == cleanCid).firstOrNull;
      if (sc != null) {
        final scName = sc.name.trim().toLowerCase();
        final scNorm = scName.replaceAll(RegExp(r'^(kelas\s*|\s+)'), '');
        if (validTokens.contains(scName) || validTokens.contains(scNorm)) return true;
      }
      return false;
    });
  }

  void _ensureStudentDataSeeded(UserModel s) {}

  /// Get students belonging to a class
  List<UserModel> getClassStudents(String classId) {
    final clean = classId.trim().toLowerCase();
    final targetNorm = clean.replaceAll(RegExp(r'^(kelas\s*|\s+)'), '');
    final matchingClasses = _schoolClasses.where((c) {
      final cName = c.name.trim().toLowerCase();
      final cId = c.id.trim().toLowerCase();
      return clean.isNotEmpty && (cName == clean || cId == clean);
    }).toList();

    final validTokens = <String>{
      if (clean.isNotEmpty) clean,
      if (targetNorm.isNotEmpty) targetNorm,
      for (final mc in matchingClasses) ...[
        mc.id.trim().toLowerCase(),
        mc.name.trim().toLowerCase(),
        mc.name.trim().toLowerCase().replaceAll(RegExp(r'^(kelas\s*|\s+)'), ''),
      ],
    };

    final list = _allStudents.where((s) {
      final c = (s.className ?? s.classId ?? '').trim().toLowerCase();
      if (c.isEmpty) return false;
      if (validTokens.contains(c)) return true;
      final cNorm = c.replaceAll(RegExp(r'^(kelas\s*|\s+)'), '');
      return cNorm.isNotEmpty && validTokens.contains(cNorm);
    }).toList();

    for (final s in list) {
      _ensureStudentDataSeeded(s);
    }
    return list;
  }

  /// Get class score statistics
  Map<String, dynamic> getClassScoreSummary(String classId, {String? subjectId}) {
    final students = getClassStudents(classId);
    for (final s in students) {
      _ensureStudentDataSeeded(s);
    }
    if (students.isEmpty) {
      return {
        'averageScore': 0.0,
        'totalStudents': 0,
        'completedExamsCount': 0,
        'studentScores': <Map<String, dynamic>>[],
      };
    }

    double totalScoreSum = 0.0;
    int evaluatedStudentsCount = 0;

    final studentScores = students.map((s) {
      final grades = getStudentSubjectGrades(s);
      StudentSubjectGrade? targetGrade;
      if (subjectId != null && subjectId.isNotEmpty && subjectId != 'all') {
        final cleanSubj = subjectId.trim().toLowerCase();
        targetGrade = grades.where((g) =>
            g.subject.id.toLowerCase() == cleanSubj ||
            g.subject.name.toLowerCase() == cleanSubj ||
            g.subject.name.toLowerCase().contains(cleanSubj) ||
            cleanSubj.contains(g.subject.name.toLowerCase())).firstOrNull;
      }

      double? score;
      int completedCount = 0;
      int completedAssignments = 0;

      if (targetGrade != null) {
        score = targetGrade.finalGrade;
        completedCount = targetGrade.completedExams;
        completedAssignments = targetGrade.completedAssignments;
      } else if (grades.isNotEmpty) {
        final valid = grades.where((g) => g.finalGrade != null).toList();
        if (valid.isNotEmpty) {
          score = valid.map((g) => g.finalGrade!).reduce((a, b) => a + b) / valid.length;
        }
        completedCount = grades.fold(0, (acc, g) => acc + g.completedExams);
        completedAssignments = grades.fold(0, (acc, g) => acc + g.completedAssignments);
      }

      // Fallback to direct exam sessions check if targetGrade not found
      if (score == null) {
        final relevantExams = (subjectId != null && subjectId.isNotEmpty && subjectId != 'all')
            ? _exams.where((e) => e.subjectId == subjectId).map((e) => e.id).toSet()
            : _exams.map((e) => e.id).toSet();
        final sessions = _examSessions.where((sess) =>
            sess.studentId == s.id &&
            relevantExams.contains(sess.examId) &&
            (sess.finalScore != null || sess.nonEssayScore != null)).toList();
        if (sessions.isNotEmpty) {
          final sum = sessions.fold<double>(0.0, (acc, sess) => acc + (sess.finalScore ?? sess.nonEssayScore ?? 0.0));
          score = sum / sessions.length;
          completedCount = sessions.length;
        }
      }

      final bool hasScore = score != null;
      final double finalScoreVal = score ?? 0.0;

      if (hasScore) {
        totalScoreSum += finalScoreVal;
        evaluatedStudentsCount++;
      }

      return {
        'student': s,
        'averageScore': finalScoreVal,
        'hasScore': hasScore,
        'completedCount': completedCount,
        'completedAssignmentsCount': completedAssignments,
      };
    }).toList();

    // Sort descending: students with scores first, then by average score
    studentScores.sort((a, b) {
      final aHas = a['hasScore'] as bool? ?? false;
      final bHas = b['hasScore'] as bool? ?? false;
      if (aHas != bHas) return aHas ? -1 : 1;
      return (b['averageScore'] as double).compareTo(a['averageScore'] as double);
    });

    final classAvg = evaluatedStudentsCount > 0 ? (totalScoreSum / evaluatedStudentsCount) : 0.0;

    return {
      'averageScore': classAvg,
      'totalStudents': students.length,
      'evaluatedStudentsCount': evaluatedStudentsCount,
      'studentScores': studentScores,
    };
  }

  /// Get class material progress summary
  Map<String, dynamic> getClassMaterialProgressSummary(String classId, String subjectId) {
    final students = getClassStudents(classId);
    for (final s in students) {
      _ensureStudentDataSeeded(s);
    }

    // STRICT: Only include materials uploaded for this class (or open if classIds is empty)
    final subjectMaterials = _materials.where((m) {
      final matchesSubject = subjectId.isEmpty || m.subjectId == subjectId;
      if (!matchesSubject) return false;
      if (m.classIds.isEmpty) return true;
      return isClassMatching(classId, m.classIds);
    }).toList();

    if (students.isEmpty || subjectMaterials.isEmpty) {
      return {
        'averageProgress': 0.0,
        'totalStudents': students.length,
        'totalMaterials': subjectMaterials.length,
        'studentProgress': <Map<String, dynamic>>[],
      };
    }

    double totalClassProgress = 0.0;

    final studentProgressList = students.map((s) {
      double sTotalProgress = 0.0;
      int completedCount = 0;

      for (final m in subjectMaterials) {
        final p = getMaterialProgress(s.id, m.id);
        sTotalProgress += p;
        if (p >= 100.0) completedCount++;
      }

      final sAvgProgress = sTotalProgress / subjectMaterials.length;
      totalClassProgress += sAvgProgress;

      return {
        'student': s,
        'progressPercent': sAvgProgress,
        'completedMaterialsCount': completedCount,
        'totalMaterialsCount': subjectMaterials.length,
      };
    }).toList();

    studentProgressList.sort((a, b) => (b['progressPercent'] as double).compareTo(a['progressPercent'] as double));

    final classAvgProgress = totalClassProgress / students.length;

    return {
      'averageProgress': classAvgProgress,
      'totalStudents': students.length,
      'totalMaterials': subjectMaterials.length,
      'studentProgress': studentProgressList,
    };
  }

  Future<void> addSchoolClass(String className) async {
    final clean = className.trim().toUpperCase();
    if (clean.isEmpty) throw Exception('Nama kelas tidak boleh kosong.');
    if (_schoolClasses.any((c) => c.name.toUpperCase() == clean)) {
      throw Exception('Kelas $clean sudah terdaftar!');
    }
    final newClass = SchoolClassModel(
      id: _uuid.v4(),
      name: clean,
      createdAt: DateTime.now(),
    );
    _schoolClasses.add(newClass);
    notifyListeners();

    try {
      await db.collection('classes').doc(newClass.id).set(newClass.toMap());
    } catch (e) {
      debugPrint('[Firestore] Error saving class: $e');
    }
  }

  Future<void> updateSchoolClass(String classId, String newName) async {
    final clean = newName.trim().toUpperCase();
    if (clean.isEmpty) throw Exception('Nama kelas tidak boleh kosong.');
    final idx = _schoolClasses.indexWhere((c) => c.id == classId);
    if (idx != -1) {
      final oldName = _schoolClasses[idx].name;
      _schoolClasses[idx] = _schoolClasses[idx].copyWith(name: clean);
      // Synchronize students who have the old class name
      for (int i = 0; i < _allStudents.length; i++) {
        if ((_allStudents[i].className ?? '').toUpperCase() == oldName.toUpperCase() ||
            (_allStudents[i].classId ?? '').toUpperCase() == oldName.toUpperCase()) {
          _allStudents[i] = _allStudents[i].copyWith(className: clean, classId: clean);
        }
      }
      notifyListeners();

      try {
        await db.collection('classes').doc(classId).update({'name': clean});
      } catch (e) {
        debugPrint('[Firestore] Error updating class: $e');
      }
    }
  }

  Future<void> deleteSchoolClass(String classId) async {
    _schoolClasses.removeWhere((c) => c.id == classId);
    notifyListeners();

    try {
      await db.collection('classes').doc(classId).delete();
    } catch (e) {
      debugPrint('[Firestore] Error deleting class: $e');
    }
  }

  /// Get monthly points for a student (resets every month)
  int getStudentMonthlyPoints(UserModel student) {
    final now = DateTime.now();
    final monthlyTxs = _pointTransactions.where((t) =>
        t.studentId == student.id &&
        t.createdAt.month == now.month &&
        t.createdAt.year == now.year &&
        !t.isDebit);
    if (monthlyTxs.isNotEmpty) {
      return monthlyTxs.fold<int>(0, (total, t) => total + t.points);
    }
    return student.totalPoints;
  }

  /// Get leaderboard for a specific class, sorted by monthly points
  List<UserModel> getClassLeaderboard(String classId) {
    final classmates = _allStudents.where((s) {
      final c = s.className ?? s.classId ?? '';
      return c.toLowerCase().trim() == classId.toLowerCase().trim();
    }).toList();

    classmates.sort((a, b) {
      final pB = getStudentMonthlyPoints(b);
      final pA = getStudentMonthlyPoints(a);
      if (pB != pA) return pB.compareTo(pA);
      return b.totalPoints.compareTo(a.totalPoints);
    });

    return classmates;
  }

  /// Get all exams assigned to student
  List<ExamModel> getExamsForStudent(UserModel student) {
    final studentClass = (student.className ?? student.classId ?? '').trim();
    return _exams.where((e) {
      if (e.classIds.isEmpty) return true;
      return e.classIds.any((c) => c.trim().toLowerCase() == studentClass.toLowerCase());
    }).toList();
  }

  /// Get count of uncompleted exams for student
  int getUncompletedExamsCount(UserModel student) {
    final exams = getExamsForStudent(student);
    int count = 0;
    for (final exam in exams) {
      final isFinished = isExamFinishedForStudent(examId: exam.id, studentId: student.id);
      if (!isFinished) {
        count++;
      }
    }
    return count;
  }

  /// Calculate gamification badges for a student based on real data
  List<BadgeModel> getStudentBadges(UserModel student) {
    final now = DateTime.now();
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final currentMonthLabel = '${months[now.month - 1]} ${now.year}';

    // 1. Streak count & status
    final studentStreaks = _streaks.where((s) => s.participantIds.contains(student.id)).toList();
    final maxStreak = studentStreaks.isNotEmpty
        ? studentStreaks.map((s) => s.streakCount).reduce((a, b) => a > b ? a : b)
        : 0;
    final hasActiveStreak = studentStreaks.any((s) => !s.isDead && s.streakCount > 0);

    // 2. Exam scores & sessions (overall & monthly)
    final studentSessions = _examSessions.where((s) => s.studentId == student.id && s.isCompleted).toList();
    final completedExamsCount = studentSessions.length;
    final maxScore = studentSessions.isNotEmpty
        ? studentSessions.map((s) => s.finalScore ?? 0.0).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final perfectScoresCount = studentSessions.where((s) => (s.finalScore ?? 0.0) >= 100.0).length;
    final highScoresCount = studentSessions.where((s) => (s.finalScore ?? 0.0) >= 85.0).length;
    final consistent80Count = studentSessions.where((s) => (s.finalScore ?? 0.0) >= 80.0).length;

    final monthlySessions = studentSessions.where((s) =>
        s.updatedAt.month == now.month && s.updatedAt.year == now.year).length;

    // 3. Class rank (Monthly Leaderboard)
    final classId = student.className ?? student.classId ?? '';
    final leaderboard = getClassLeaderboard(classId);
    final rankIndex = leaderboard.indexWhere((s) => s.id == student.id);
    final rank = rankIndex != -1 ? rankIndex + 1 : 999;

    // 4. Points (overall & monthly)
    final monthlyPoints = getStudentMonthlyPoints(student);
    final totalPoints = student.totalPoints;

    // 5. Chat & Forum messages (overall & monthly)
    final chatCount = _chatMessages.where((m) => m.senderId == student.id).length;
    final forumCount = _forumMessages.where((m) => m.senderId == student.id).length;
    final totalMessages = chatCount + forumCount;

    final monthlyChat = _chatMessages.where((m) =>
        m.senderId == student.id &&
        m.sentAt.month == now.month &&
        m.sentAt.year == now.year).length;
    final monthlyForum = _forumMessages.where((m) =>
        m.senderId == student.id &&
        m.createdAt.month == now.month &&
        m.createdAt.year == now.year).length;
    final monthlyMessages = monthlyChat + monthlyForum;

    // 6. Materials Progress
    final studentMaterials = getMaterialsForUser(student);
    final completedMaterials = studentMaterials.where((m) => getMaterialProgress(student.id, m.id) >= 100.0).length;
    final totalClassMaterials = studentMaterials.length;

    // 7. Grade Redeems & Investments
    final studentRedeems = _gradeRedeems.where((r) => r.studentId == student.id).toList();
    final hasRedeemedGrade = studentRedeems.isNotEmpty;
    final totalPointsSpent = studentRedeems.fold(0, (acc, r) => acc + r.pointsSpent);

    // 8. Code Activities (from IDE Playground)
    final codeRuns = getStudentCodeRunsCount(student.id);
    final hasTestedArduino = hasStudentTestedLanguage(student.id, 'arduino');
    final hasTestedWeb = hasStudentTestedLanguage(student.id, 'html') || hasStudentTestedLanguage(student.id, 'javascript');

    return [
      // ══════════════════ 1. LENCANA BULANAN (RESET TIAP AWAL BULAN) ══════════════════
      BadgeModel(
        id: 'monthly_champ',
        title: 'Juara Bulanan',
        description: 'Menjadi peringkat #1 di kelas pada periode $currentMonthLabel.',
        icon: '👑',
        color: const Color(0xFFF59E0B),
        isEarned: rank == 1 && leaderboard.isNotEmpty,
        progressText: rank == 1 ? 'Juara #1 🥇' : 'Peringkat #$rank',
        progress: rank == 1 ? 1.0 : (rank <= 3 ? 0.6 : 0.2),
        howToGet: 'Pertahankan posisi teratas di papan peringkat kelas bulan ini.',
        isMonthly: true,
        category: 'bulanan',
        periodLabel: 'Reset Tiap Bulan',
      ),
      BadgeModel(
        id: 'monthly_top3',
        title: 'Podium 3 Besar',
        description: 'Tembus posisi 3 besar di kelas pada periode $currentMonthLabel.',
        icon: '🥈',
        color: const Color(0xFFEAB308),
        isEarned: rank <= 3 && leaderboard.isNotEmpty,
        progressText: rank <= 3 ? 'Top #$rank' : 'Peringkat #$rank',
        progress: rank <= 3 ? 1.0 : (rank <= 5 ? 0.5 : 0.2),
        howToGet: 'Kumpulkan poin lebih banyak dari teman sekelas bulan ini.',
        isMonthly: true,
        category: 'bulanan',
        periodLabel: 'Reset Tiap Bulan',
      ),
      BadgeModel(
        id: 'monthly_quiz_master',
        title: 'Penakluk Kuis Bulanan',
        description: 'Selesaikan minimal 2 kuis/ujian di bulan $currentMonthLabel.',
        icon: '🎯',
        color: const Color(0xFFEC4899),
        isEarned: monthlySessions >= 2,
        progressText: '$monthlySessions / 2 Kuis',
        progress: (monthlySessions / 2).clamp(0.0, 1.0),
        howToGet: 'Kerjakan dan tuntaskan kuis aktif di bulan ini.',
        isMonthly: true,
        category: 'bulanan',
        periodLabel: 'Reset Tiap Bulan',
      ),
      BadgeModel(
        id: 'monthly_quiz_expert',
        title: 'Pakar Evaluasi Bulanan',
        description: 'Selesaikan minimal 4 kuis/evaluasi belajar pada bulan $currentMonthLabel.',
        icon: '📝',
        color: const Color(0xFF8B5CF6),
        isEarned: monthlySessions >= 4,
        progressText: '$monthlySessions / 4 Kuis',
        progress: (monthlySessions / 4).clamp(0.0, 1.0),
        howToGet: 'Rutin menyelesaikan latihan kuis dan ujian bulanan.',
        isMonthly: true,
        category: 'bulanan',
        periodLabel: 'Reset Tiap Bulan',
      ),
      BadgeModel(
        id: 'monthly_point_hunter',
        title: 'Pemburu Poin Bulanan',
        description: 'Kumpulkan 150 poin dari aktivitas belajar di bulan $currentMonthLabel.',
        icon: '⚡',
        color: const Color(0xFF1A4DB5),
        isEarned: monthlyPoints >= 150,
        progressText: '$monthlyPoints / 150 Poin',
        progress: (monthlyPoints / 150).clamp(0.0, 1.0),
        howToGet: 'Dapatkan poin dari kuis, streak, dan materi di bulan ini.',
        isMonthly: true,
        category: 'bulanan',
        periodLabel: 'Reset Tiap Bulan',
      ),
      BadgeModel(
        id: 'monthly_point_master',
        title: 'Master Akumulasi Bulanan',
        description: 'Kumpulkan 300 poin dari aktivitas belajar di bulan $currentMonthLabel.',
        icon: '💰',
        color: const Color(0xFF10B981),
        isEarned: monthlyPoints >= 300,
        progressText: '$monthlyPoints / 300 Poin',
        progress: (monthlyPoints / 300).clamp(0.0, 1.0),
        howToGet: 'Maksimalkan poin dari membaca materi, streak, dan tugas.',
        isMonthly: true,
        category: 'bulanan',
        periodLabel: 'Reset Tiap Bulan',
      ),
      BadgeModel(
        id: 'monthly_streak_flame',
        title: 'Api Semangat Bulanan',
        description: 'Pertahankan streak interaksi belajar minimal 5 hari di bulan ini.',
        icon: '🔥',
        color: const Color(0xFFF97316),
        isEarned: maxStreak >= 5,
        progressText: '$maxStreak / 5 Hari',
        progress: (maxStreak / 5).clamp(0.0, 1.0),
        howToGet: 'Chat dan berinteraksi setiap hari agar streak tidak terputus.',
        isMonthly: true,
        category: 'bulanan',
        periodLabel: 'Reset Tiap Bulan',
      ),
      BadgeModel(
        id: 'monthly_collaborator',
        title: 'Sahabat Diskusi Bulanan',
        description: 'Kirim minimal 5 pesan diskusi pada periode $currentMonthLabel.',
        icon: '💬',
        color: const Color(0xFF06B6D4),
        isEarned: monthlyMessages >= 5,
        progressText: '$monthlyMessages / 5 Pesan',
        progress: (monthlyMessages / 5).clamp(0.0, 1.0),
        howToGet: 'Aktif berdiskusi di materi dan chat dengan guru/teman.',
        isMonthly: true,
        category: 'bulanan',
        periodLabel: 'Reset Tiap Bulan',
      ),

      // ══════════════════ 2. LENCANA PRESTASI KUIS & NILAI (PERMANEN) ══════════════════
      BadgeModel(
        id: 'perm_first_step',
        title: 'Langkah Pertama',
        description: 'Menyelesaikan ujian atau kuis pertama di aplikasi.',
        icon: '🎓',
        color: const Color(0xFF3B82F6),
        isEarned: completedExamsCount >= 1,
        progressText: completedExamsCount >= 1 ? 'Diraih' : '0 / 1 Selesai',
        progress: completedExamsCount >= 1 ? 1.0 : 0.0,
        howToGet: 'Kerjakan dan selesaikan satu kuis di menu Quiz & Ujian.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_quiz_5',
        title: 'Penembak Jitu',
        description: 'Menyelesaikan total 5 kuis/evaluasi pembelajaran.',
        icon: '🎯',
        color: const Color(0xFF2563EB),
        isEarned: completedExamsCount >= 5,
        progressText: '$completedExamsCount / 5 Selesai',
        progress: (completedExamsCount / 5).clamp(0.0, 1.0),
        howToGet: 'Selesaikan minimal 5 evaluasi kuis pembelajaran.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_quiz_10',
        title: 'Ahli Evaluasi',
        description: 'Menyelesaikan total 10 kuis atau ujian evaluasi.',
        icon: '📚',
        color: const Color(0xFF0D2B6E),
        isEarned: completedExamsCount >= 10,
        progressText: '$completedExamsCount / 10 Selesai',
        progress: (completedExamsCount / 10).clamp(0.0, 1.0),
        howToGet: 'Tuntaskan 10 kali kuis evaluasi materi secara konsisten.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_score_100',
        title: 'Perfeksionis Sempurna',
        description: 'Meraih nilai sempurna 100 tanpa salah pada ujian evaluasi.',
        icon: '💯',
        color: const Color(0xFF10B981),
        isEarned: perfectScoresCount >= 1,
        progressText: perfectScoresCount >= 1 ? 'Diraih ($perfectScoresCount kali)' : '${maxScore.toStringAsFixed(0)} / 100',
        progress: perfectScoresCount >= 1 ? 1.0 : (maxScore / 100).clamp(0.0, 1.0),
        howToGet: 'Jawab semua butir soal kuis dengan benar tanpa kesalahan.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_high_score',
        title: 'Otak Cemerlang',
        description: 'Meraih skor minimal 85 pada salah satu kuis atau ujian.',
        icon: '🧠',
        color: const Color(0xFF1A4DB5),
        isEarned: highScoresCount >= 1,
        progressText: highScoresCount >= 1 ? 'Diraih ($highScoresCount kali)' : '${maxScore.toStringAsFixed(0)} / 85 Nilai',
        progress: highScoresCount >= 1 ? 1.0 : (maxScore / 85).clamp(0.0, 1.0),
        howToGet: 'Raih nilai 85 ke atas dalam evaluasi kuis.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_consistent_80',
        title: 'Konsistensi Emas',
        description: 'Meraih nilai 80 ke atas di minimal 3 kuis yang berbeda.',
        icon: '⭐',
        color: const Color(0xFFF59E0B),
        isEarned: consistent80Count >= 3,
        progressText: '$consistent80Count / 3 Kuis (>=80)',
        progress: (consistent80Count / 3).clamp(0.0, 1.0),
        howToGet: 'Pertahankan nilai minimal 80 pada 3 kali evaluasi kuis.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),

      // ══════════════════ 3. LENCANA KONSISTENSI & STREAK (PERMANEN) ══════════════════
      BadgeModel(
        id: 'perm_streak_3',
        title: 'Percikan Awal',
        description: 'Mencapai streak interaksi belajar 3 hari berturut-turut.',
        icon: '🔥',
        color: const Color(0xFFFB923C),
        isEarned: maxStreak >= 3,
        progressText: '$maxStreak / 3 Hari',
        progress: (maxStreak / 3).clamp(0.0, 1.0),
        howToGet: 'Jaga api streak belajar dengan teman atau guru selama 3 hari.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_streak_7',
        title: 'Dedikasi 7 Hari',
        description: 'Mencapai streak interaksi belajar 7 hari berturut-turut.',
        icon: '⚡',
        color: const Color(0xFFD97706),
        isEarned: maxStreak >= 7,
        progressText: '$maxStreak / 7 Hari',
        progress: (maxStreak / 7).clamp(0.0, 1.0),
        howToGet: 'Jaga api streak selama satu minggu penuh tanpa jeda.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_streak_14',
        title: 'Konsistensi Dua Pekan',
        description: 'Mencapai streak interaksi belajar 14 hari berturut-turut.',
        icon: '🌟',
        color: const Color(0xFFEA580C),
        isEarned: maxStreak >= 14,
        progressText: '$maxStreak / 14 Hari',
        progress: (maxStreak / 14).clamp(0.0, 1.0),
        howToGet: 'Pertahankan komitmen belajar harian selama dua pekan penuh.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_streak_30',
        title: 'Benteng Ketekunan',
        description: 'Mencapai streak interaksi belajar 30 hari berturut-turut.',
        icon: '🏰',
        color: const Color(0xFFC026D3),
        isEarned: maxStreak >= 30,
        progressText: '$maxStreak / 30 Hari',
        progress: (maxStreak / 30).clamp(0.0, 1.0),
        howToGet: 'Belajar dan berdiskusi secara konsisten selama satu bulan penuh.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_streak_revive',
        title: 'Pejuang Bangkit',
        description: 'Berhasil menjaga atau memulihkan api streak belajar yang aktif.',
        icon: '🌅',
        color: const Color(0xFF14B8A6),
        isEarned: hasActiveStreak,
        progressText: hasActiveStreak ? 'Aktif 🔥' : 'Mati / Belum Ada',
        progress: hasActiveStreak ? 1.0 : 0.0,
        howToGet: 'Kirim chat harian untuk mengaktifkan atau memulihkan streak belajar.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),

      // ══════════════════ 4. LENCANA LITERASI & MODUL MATERI (PERMANEN) ══════════════════
      BadgeModel(
        id: 'perm_book_1',
        title: 'Pembaca Pemula',
        description: 'Menyelesaikan modul pembelajaran pertama hingga 100%.',
        icon: '📖',
        color: const Color(0xFF0284C7),
        isEarned: completedMaterials >= 1,
        progressText: '$completedMaterials / 1 Modul',
        progress: completedMaterials >= 1 ? 1.0 : 0.0,
        howToGet: 'Buka materi modul dan pelajari hingga selesai 100%.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_bookworm',
        title: 'Kutu Buku',
        description: 'Menyelesaikan minimal 3 modul materi pembelajaran hingga tuntas.',
        icon: '📚',
        color: const Color(0xFF8B5CF6),
        isEarned: completedMaterials >= 3,
        progressText: '$completedMaterials / 3 Modul',
        progress: (completedMaterials / 3).clamp(0.0, 1.0),
        howToGet: 'Pelajari 3 modul materi pembelajaran yang disediakan guru.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_book_6',
        title: 'Kolektor Pengetahuan',
        description: 'Menyelesaikan minimal 6 modul materi pembelajaran.',
        icon: '🌐',
        color: const Color(0xFF071540),
        isEarned: completedMaterials >= 6,
        progressText: '$completedMaterials / 6 Modul',
        progress: (completedMaterials / 6).clamp(0.0, 1.0),
        howToGet: 'Tuntaskan bacaan di berbagai modul mata pelajaran.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_curriculum_master',
        title: 'Penguasa Kurikulum',
        description: 'Menyelesaikan seluruh modul materi yang tersedia untuk kelas Anda.',
        icon: '🧙‍♂️',
        color: const Color(0xFF8B5CF6),
        isEarned: totalClassMaterials > 0 && completedMaterials >= totalClassMaterials,
        progressText: '$completedMaterials / $totalClassMaterials Selesai',
        progress: totalClassMaterials > 0 ? (completedMaterials / totalClassMaterials).clamp(0.0, 1.0) : 0.0,
        howToGet: 'Tuntaskan seluruh modul materi yang ditugaskan di kelas Anda.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),

      // ══════════════════ 5. LENCANA PRAKTIKUM & CODING IDE (PERMANEN) ══════════════════
      BadgeModel(
        id: 'perm_code_hello',
        title: 'Halo Dunia!',
        description: 'Menjalankan atau menguji baris kode di Code Playground IDE.',
        icon: '💻',
        color: const Color(0xFF059669),
        isEarned: codeRuns >= 1,
        progressText: codeRuns >= 1 ? 'Diraih' : '0 / 1 Run',
        progress: codeRuns >= 1 ? 1.0 : 0.0,
        howToGet: 'Buka menu Code Playground dan klik Jalankan / Run kode.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_code_web',
        title: 'Web Explorer',
        description: 'Praktikum kompilasi bahasa web (HTML atau JavaScript) di IDE.',
        icon: '🌐',
        color: const Color(0xFF0284C7),
        isEarned: hasTestedWeb,
        progressText: hasTestedWeb ? 'Diraih ✅' : 'Belum Dicoba',
        progress: hasTestedWeb ? 1.0 : 0.0,
        howToGet: 'Pilih bahasa HTML atau JavaScript lalu jalankan di Code Playground.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_code_iot',
        title: 'Master Arduino & IoT',
        description: 'Menguji simulasi kode mikrokontroler Arduino C++ di Playground.',
        icon: '🤖',
        color: const Color(0xFF0D9488),
        isEarned: hasTestedArduino,
        progressText: hasTestedArduino ? 'Diraih ✅' : 'Belum Dicoba',
        progress: hasTestedArduino ? 1.0 : 0.0,
        howToGet: 'Pilih template Arduino C++ di IDE dan jalankan kompilasi.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),

      // ══════════════════ 6. LENCANA GAMIFIKASI, EKONOMI, & SOSIAL (PERMANEN) ══════════════════
      BadgeModel(
        id: 'perm_redeemer',
        title: 'Penebus Nilai',
        description: 'Berhasil menukarkan poin belajar menjadi nilai akademik mata pelajaran.',
        icon: '💎',
        color: const Color(0xFF0EA5E9),
        isEarned: hasRedeemedGrade,
        progressText: hasRedeemedGrade ? 'Diraih ✅' : 'Belum Ditukar',
        progress: hasRedeemedGrade ? 1.0 : 0.0,
        howToGet: 'Tukarkan poin pada menu Tukar Nilai di dashboard.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_investor',
        title: 'Ahli Investasi Poin',
        description: 'Menginvestasikan total 300 poin untuk meningkatkan nilai akademik rapor.',
        icon: '📈',
        color: const Color(0xFF10B981),
        isEarned: totalPointsSpent >= 300,
        progressText: '$totalPointsSpent / 300 Poin Terpakai',
        progress: (totalPointsSpent / 300).clamp(0.0, 1.0),
        howToGet: 'Gunakan minimal 300 poin belajar untuk bonus nilai akademik.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_point_300',
        title: 'Kolektor Poin',
        description: 'Akumulasi perolehan 300 total poin dari semua aktivitas belajar.',
        icon: '🏆',
        color: const Color(0xFFF59E0B),
        isEarned: totalPoints >= 300,
        progressText: '$totalPoints / 300 Poin',
        progress: (totalPoints / 300).clamp(0.0, 1.0),
        howToGet: 'Kumpulkan poin dari materi, kuis, streak, dan tugas.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_legend_500',
        title: 'Sultan Edukasi',
        description: 'Mencapai status master dengan total akumulasi 500 poin belajar.',
        icon: '🌟',
        color: const Color(0xFFE11D48),
        isEarned: totalPoints >= 500,
        progressText: '$totalPoints / 500 Poin',
        progress: (totalPoints / 500).clamp(0.0, 1.0),
        howToGet: 'Raih 500 poin dari konsistensi belajar tingkat tinggi.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_legend_1000',
        title: 'Legenda Abadi',
        description: 'Mencapai puncak gamifikasi dengan akumulasi 1000 poin belajar.',
        icon: '👑',
        color: const Color(0xFF7E22CE),
        isEarned: totalPoints >= 1000,
        progressText: '$totalPoints / 1000 Poin',
        progress: (totalPoints / 1000).clamp(0.0, 1.0),
        howToGet: 'Kumpulkan 1000 poin sebagai bukti ketekunan belajar tiada henti.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_social_star',
        title: 'Komunikator Aktif',
        description: 'Berpartisipasi aktif dalam diskusi kelas atau pesan chat minimal 10 kali.',
        icon: '💬',
        color: const Color(0xFF0D9488),
        isEarned: totalMessages >= 10,
        progressText: '$totalMessages / 10 Pesan',
        progress: (totalMessages / 10).clamp(0.0, 1.0),
        howToGet: 'Kirimkan pesan dan tanggapan di forum materi atau chat belajar.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
      BadgeModel(
        id: 'perm_social_champion',
        title: 'Kolaborator Teladan',
        description: 'Berpartisipasi aktif dalam diskusi kelas atau pesan chat minimal 25 kali.',
        icon: '🤝',
        color: const Color(0xFF0891B2),
        isEarned: totalMessages >= 25,
        progressText: '$totalMessages / 25 Pesan',
        progress: (totalMessages / 25).clamp(0.0, 1.0),
        howToGet: 'Terus aktif berdiskusi dan membantu teman belajar di forum/chat.',
        isMonthly: false,
        category: 'prestasi',
        periodLabel: 'Prestasi Permanen',
      ),
    ];
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
