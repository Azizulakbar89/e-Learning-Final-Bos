class AppNotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // 'material' | 'exam' | 'chat' | 'announcement'
  final List<String> targetClassIds; // Daftar target kelas siswa. Kosong = semua kelas (jika targetUserIds kosong).
  final List<String> targetUserIds; // Target user spesifik (misal: chat pesan masuk). Kosong = broadcast kelas.
  final String? referenceId; // ID Material, ID Exam, atau Streak/Chat ID untuk direct navigation
  final String? creatorId;
  final String? creatorName;
  final DateTime createdAt;
  final List<String> readByUserIds;

  AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.targetClassIds = const [],
    this.targetUserIds = const [],
    this.referenceId,
    this.creatorId,
    this.creatorName,
    required this.createdAt,
    this.readByUserIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'target_class_ids': targetClassIds,
      'target_user_ids': targetUserIds,
      'reference_id': referenceId,
      'creator_id': creatorId,
      'creator_name': creatorName,
      'created_at': createdAt.toIso8601String(),
      'read_by_user_ids': readByUserIds,
    };
  }

  factory AppNotificationModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return AppNotificationModel(
      id: id ?? map['id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'announcement',
      targetClassIds: List<String>.from(map['target_class_ids'] ?? []),
      targetUserIds: List<String>.from(map['target_user_ids'] ?? []),
      referenceId: map['reference_id'],
      creatorId: map['creator_id'],
      creatorName: map['creator_name'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      readByUserIds: List<String>.from(map['read_by_user_ids'] ?? []),
    );
  }

  AppNotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    List<String>? targetClassIds,
    List<String>? targetUserIds,
    String? referenceId,
    String? creatorId,
    String? creatorName,
    DateTime? createdAt,
    List<String>? readByUserIds,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      targetClassIds: targetClassIds ?? this.targetClassIds,
      targetUserIds: targetUserIds ?? this.targetUserIds,
      referenceId: referenceId ?? this.referenceId,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      createdAt: createdAt ?? this.createdAt,
      readByUserIds: readByUserIds ?? this.readByUserIds,
    );
  }
}
