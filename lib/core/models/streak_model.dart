enum StreakType {
  peer, // Siswa - Siswa
  teacher, // Siswa - Guru
  group, // Grup Belajar
  study, // Belajar Mandiri (Non-Chat: Materi, Tugas, Ujian & Kuis)
}

extension StreakTypeExtension on StreakType {
  String get label {
    switch (this) {
      case StreakType.peer:
        return 'Siswa & Siswa';
      case StreakType.teacher:
        return 'Siswa & Guru';
      case StreakType.group:
        return 'Grup Belajar';
      case StreakType.study:
        return 'Belajar Mandiri';
    }
  }

  String get code {
    switch (this) {
      case StreakType.peer:
        return 'peer';
      case StreakType.teacher:
        return 'teacher';
      case StreakType.group:
        return 'group';
      case StreakType.study:
        return 'study';
    }
  }

  static StreakType fromString(String val) {
    switch (val) {
      case 'teacher':
        return StreakType.teacher;
      case 'group':
        return StreakType.group;
      case 'study':
        return StreakType.study;
      default:
        return StreakType.peer;
    }
  }
}

class StreakModel {
  final String id;
  final StreakType type;
  final String title; // Name of partner or group
  final List<String> participantIds;
  final List<String> participantNames;
  final int streakCount;
  final DateTime lastInteractionAt;
  final DateTime expiresAt;

  final bool isRestored;

  StreakModel({
    required this.id,
    required this.type,
    required this.title,
    required this.participantIds,
    required this.participantNames,
    this.streakCount = 0,
    required this.lastInteractionAt,
    required this.expiresAt,
    this.isRestored = false,
  });

  bool get isExpiringSoon {
    final diff = expiresAt.difference(DateTime.now());
    return diff.inHours <= 4 && diff.inSeconds > 0 && !isDead;
  }

  bool get isDead => DateTime.now().isAfter(expiresAt);
  bool get isExpired => isDead;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.code,
      'title': title,
      'participant_ids': participantIds,
      'participant_names': participantNames,
      'streak_count': streakCount,
      'last_interaction_at': lastInteractionAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'is_restored': isRestored,
    };
  }

  factory StreakModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return StreakModel(
      id: id ?? map['id'] ?? '',
      type: StreakTypeExtension.fromString(map['type'] ?? 'peer'),
      title: map['title'] ?? '',
      participantIds: List<String>.from(map['participant_ids'] ?? []),
      participantNames: List<String>.from(map['participant_names'] ?? []),
      streakCount: (map['streak_count'] as num?)?.toInt() ?? 0,
      lastInteractionAt: map['last_interaction_at'] != null
          ? DateTime.tryParse(map['last_interaction_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: map['expires_at'] != null
          ? DateTime.tryParse(map['expires_at'].toString()) ?? DateTime.now().add(const Duration(hours: 24))
          : DateTime.now().add(const Duration(hours: 24)),
      isRestored: map['is_restored'] as bool? ?? false,
    );
  }

  StreakModel copyWith({
    String? id,
    StreakType? type,
    String? title,
    List<String>? participantIds,
    List<String>? participantNames,
    int? streakCount,
    DateTime? lastInteractionAt,
    DateTime? expiresAt,
    bool? isRestored,
  }) {
    return StreakModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      participantIds: participantIds ?? this.participantIds,
      participantNames: participantNames ?? this.participantNames,
      streakCount: streakCount ?? this.streakCount,
      lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isRestored: isRestored ?? this.isRestored,
    );
  }
}

class ChatMessageModel {
  final String id;
  final String streakId;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime sentAt;
  final String? replyToMessageId;
  final String? replyToSenderName;
  final String? replyToText;
  final bool isEdited;
  final DateTime? editedAt;

  ChatMessageModel({
    required this.id,
    required this.streakId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.sentAt,
    this.replyToMessageId,
    this.replyToSenderName,
    this.replyToText,
    this.isEdited = false,
    this.editedAt,
  });

  bool get hasReply => replyToText != null && replyToText!.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'streak_id': streakId,
        'sender_id': senderId,
        'sender_name': senderName,
        'message': message,
        'sent_at': sentAt.toIso8601String(),
        'reply_to_message_id': replyToMessageId,
        'reply_to_sender_name': replyToSenderName,
        'reply_to_text': replyToText,
        'is_edited': isEdited,
        'edited_at': editedAt?.toIso8601String(),
      };

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      ChatMessageModel(
        id: id ?? map['id'] ?? '',
        streakId: map['streak_id'] ?? '',
        senderId: map['sender_id'] ?? '',
        senderName: map['sender_name'] ?? '',
        message: map['message'] ?? '',
        sentAt: map['sent_at'] != null
            ? DateTime.tryParse(map['sent_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        replyToMessageId: map['reply_to_message_id']?.toString(),
        replyToSenderName: map['reply_to_sender_name']?.toString(),
        replyToText: map['reply_to_text']?.toString(),
        isEdited: map['is_edited'] as bool? ?? false,
        editedAt: map['edited_at'] != null ? DateTime.tryParse(map['edited_at'].toString()) : null,
      );

  ChatMessageModel copyWith({
    String? id,
    String? streakId,
    String? senderId,
    String? senderName,
    String? message,
    DateTime? sentAt,
    String? replyToMessageId,
    String? replyToSenderName,
    String? replyToText,
    bool? isEdited,
    DateTime? editedAt,
  }) =>
      ChatMessageModel(
        id: id ?? this.id,
        streakId: streakId ?? this.streakId,
        senderId: senderId ?? this.senderId,
        senderName: senderName ?? this.senderName,
        message: message ?? this.message,
        sentAt: sentAt ?? this.sentAt,
        replyToMessageId: replyToMessageId ?? this.replyToMessageId,
        replyToSenderName: replyToSenderName ?? this.replyToSenderName,
        replyToText: replyToText ?? this.replyToText,
        isEdited: isEdited ?? this.isEdited,
        editedAt: editedAt ?? this.editedAt,
      );
}
