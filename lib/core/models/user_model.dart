class UserModel {
  final String id;
  final String username;
  final String fullName;
  final String role; // 'admin' | 'guru' | 'siswa'
  final String? nis;
  final String? classId;
  final String? className;
  final String? initialPassword; // For student credentials view by teachers
  final String? passwordHash; // SHA-256 hashed password with salt
  final List<String> subjectIds; // For teachers (can teach > 1 subject)
  final List<String> classIds; // For teachers (classes taught)
  final int totalPoints;
  final String? fcmToken;
  final String? sidikmuUrl;
  final String? sidikmuUsername;
  final String? sidikmuPassword;
  final DateTime? sidikmuLastSyncedAt;

  UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.nis,
    this.classId,
    this.className,
    this.initialPassword,
    this.passwordHash,
    this.subjectIds = const [],
    this.classIds = const [],
    this.totalPoints = 0,
    this.fcmToken,
    this.sidikmuUrl = 'https://smpm12gkb.sidikmu.com',
    this.sidikmuUsername,
    this.sidikmuPassword,
    this.sidikmuLastSyncedAt,
  });

  bool get isSiswa => role == 'siswa';
  bool get isGuru => role == 'guru';
  bool get isAdmin => role == 'admin';
  bool get hasSidikmuAccount =>
      (sidikmuUsername != null && sidikmuUsername!.trim().isNotEmpty) &&
      (sidikmuPassword != null && sidikmuPassword!.isNotEmpty);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'role': role,
      'nis': nis,
      'class_id': classId,
      'class_name': className,
      'initial_password': initialPassword,
      'password_hash': passwordHash,
      'subject_ids': subjectIds,
      'class_ids': classIds,
      'total_points': totalPoints,
      'fcm_token': fcmToken,
      'sidikmu_url': sidikmuUrl,
      'sidikmu_username': sidikmuUsername,
      'sidikmu_password': sidikmuPassword,
      'sidikmu_last_synced_at': sidikmuLastSyncedAt?.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final userId = id ?? map['id'] ?? '';
    final role = map['role'] ?? 'siswa';

    // Robust parsing for subjectIds
    final rawSubj = map['subject_ids'] ?? map['subjectIds'] ?? map['subjects'] ?? map['subject_id'] ?? map['subjectId'];
    List<String> parsedSubjs = [];
    if (rawSubj is List) {
      parsedSubjs = rawSubj.map((e) => e.toString()).toList();
    } else if (rawSubj is String && rawSubj.isNotEmpty) {
      parsedSubjs = [rawSubj];
    }

    // Robust parsing for classIds
    final rawClass = map['class_ids'] ?? map['classIds'] ?? map['classes'] ?? map['class_id'] ?? map['classId'] ?? map['className'] ?? map['class_name'];
    List<String> parsedClasses = [];
    if (rawClass is List) {
      parsedClasses = rawClass.map((e) => e.toString()).toList();
    } else if (rawClass is String && rawClass.isNotEmpty) {
      parsedClasses = [rawClass];
    }

    return UserModel(
      id: userId,
      username: map['username'] ?? '',
      fullName: map['full_name'] ?? '',
      role: role,
      nis: map['nis'],
      classId: map['class_id'] ?? map['classId'],
      className: map['class_name'] ?? map['className'],
      initialPassword: map['initial_password'],
      passwordHash: map['password_hash'],
      subjectIds: parsedSubjs,
      classIds: parsedClasses,
      totalPoints: (map['total_points'] as num?)?.toInt() ?? 0,
      fcmToken: map['fcm_token'],
      sidikmuUrl: map['sidikmu_url'] as String? ?? 'https://smpm12gkb.sidikmu.com',
      sidikmuUsername: map['sidikmu_username'] as String?,
      sidikmuPassword: map['sidikmu_password'] as String?,
      sidikmuLastSyncedAt: map['sidikmu_last_synced_at'] != null
          ? DateTime.tryParse(map['sidikmu_last_synced_at'].toString())
          : null,
    );
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? fullName,
    String? role,
    String? nis,
    String? classId,
    String? className,
    String? initialPassword,
    String? passwordHash,
    List<String>? subjectIds,
    List<String>? classIds,
    int? totalPoints,
    String? fcmToken,
    String? sidikmuUrl,
    String? sidikmuUsername,
    String? sidikmuPassword,
    DateTime? sidikmuLastSyncedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      nis: nis ?? this.nis,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      initialPassword: initialPassword ?? this.initialPassword,
      passwordHash: passwordHash ?? this.passwordHash,
      subjectIds: subjectIds ?? this.subjectIds,
      classIds: classIds ?? this.classIds,
      totalPoints: totalPoints ?? this.totalPoints,
      fcmToken: fcmToken ?? this.fcmToken,
      sidikmuUrl: sidikmuUrl ?? this.sidikmuUrl,
      sidikmuUsername: sidikmuUsername ?? this.sidikmuUsername,
      sidikmuPassword: sidikmuPassword ?? this.sidikmuPassword,
      sidikmuLastSyncedAt: sidikmuLastSyncedAt ?? this.sidikmuLastSyncedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
