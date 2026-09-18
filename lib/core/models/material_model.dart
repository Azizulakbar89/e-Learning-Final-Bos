class ForumMessageModel {
  final String id;
  final String materialId;
  final String classId; // Strict class isolation
  final String senderId;
  final String senderName;
  final String senderRole; // 'guru' | 'siswa'
  final String message;
  final DateTime createdAt;

  ForumMessageModel({
    required this.id,
    required this.materialId,
    required this.classId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'material_id': materialId,
      'class_id': classId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ForumMessageModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return ForumMessageModel(
      id: id ?? map['id'] ?? '',
      materialId: map['material_id'] ?? '',
      classId: map['class_id'] ?? '',
      senderId: map['sender_id'] ?? '',
      senderName: map['sender_name'] ?? '',
      senderRole: map['sender_role'] ?? 'siswa',
      message: map['message'] ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class MaterialModel {
  final String id;
  final String subjectId;
  final String teacherId;
  final String title;
  final String description;
  final String contentType; // 'youtube' | 'ppt' | 'canva'
  final String mediaUrl; // Embed URL or file link
  final List<String> classIds; // Target classes
  final DateTime? scheduledOpenAt; // null = immediately visible
  final String? assignmentType; // null | 'individu' | 'kelompok' | 'pilihan_ganda'
  final String? aiContextSummary; // Pre-extracted text for AI grounding
  final String? babyLanguageExplanation; // Pre-cached ELI5 explanation
  final DateTime createdAt;

  MaterialModel({
    required this.id,
    required this.subjectId,
    required this.teacherId,
    required this.title,
    required this.description,
    required this.contentType,
    required this.mediaUrl,
    required this.classIds,
    this.scheduledOpenAt,
    this.assignmentType,
    this.aiContextSummary,
    this.babyLanguageExplanation,
    required this.createdAt,
  });

  /// Whether this material is currently visible to students
  bool get isOpen =>
      scheduledOpenAt == null || DateTime.now().isAfter(scheduledOpenAt!);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'title': title,
      'description': description,
      'content_type': contentType,
      'media_url': mediaUrl,
      'class_ids': classIds,
      'scheduled_open_at': scheduledOpenAt?.toIso8601String(),
      'assignment_type': assignmentType,
      'ai_context_summary': aiContextSummary,
      'baby_language_explanation': babyLanguageExplanation,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MaterialModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawClassIds = map['class_ids'] ?? map['classIds'];
    List<String> parsedClassIds = [];
    if (rawClassIds is List) {
      parsedClassIds = rawClassIds.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    } else if (rawClassIds is String && rawClassIds.trim().isNotEmpty) {
      parsedClassIds = [rawClassIds.trim()];
    }

    final rawScheduled = map['scheduled_open_at'] ?? map['scheduledOpenAt'];
    DateTime? scheduledOpen;
    if (rawScheduled != null) {
      scheduledOpen = DateTime.tryParse(rawScheduled.toString());
    }

    final rawCreatedAt = map['created_at'] ?? map['createdAt'];
    DateTime createdAt = DateTime.now();
    if (rawCreatedAt != null) {
      createdAt = DateTime.tryParse(rawCreatedAt.toString()) ?? DateTime.now();
    }

    return MaterialModel(
      id: id ?? map['id']?.toString() ?? '',
      subjectId: (map['subject_id'] ?? map['subjectId'])?.toString() ?? '',
      teacherId: (map['teacher_id'] ?? map['teacherId'])?.toString() ?? '',
      title: (map['title'])?.toString() ?? '',
      description: (map['description'])?.toString() ?? '',
      contentType: (map['content_type'] ?? map['contentType'])?.toString() ?? 'youtube',
      mediaUrl: (map['media_url'] ?? map['mediaUrl'])?.toString() ?? '',
      classIds: parsedClassIds,
      scheduledOpenAt: scheduledOpen,
      assignmentType: (map['assignment_type'] ?? map['assignmentType'])?.toString(),
      aiContextSummary: (map['ai_context_summary'] ?? map['aiContextSummary'])?.toString(),
      babyLanguageExplanation: (map['baby_language_explanation'] ?? map['babyLanguageExplanation'])?.toString(),
      createdAt: createdAt,
    );
  }
}


class StudentMaterialProgress {
  final String studentId;
  final String materialId;
  final double progressPercent; // 0.0 to 100.0
  final bool isCompleted;
  final DateTime lastViewedAt;

  StudentMaterialProgress({
    required this.studentId,
    required this.materialId,
    required this.progressPercent,
    required this.isCompleted,
    required this.lastViewedAt,
  });

  Map<String, dynamic> toMap() => {
        'student_id': studentId,
        'material_id': materialId,
        'progress_percent': progressPercent,
        'is_completed': isCompleted,
        'last_viewed_at': lastViewedAt.toIso8601String(),
      };

  factory StudentMaterialProgress.fromMap(Map<String, dynamic> map) =>
      StudentMaterialProgress(
        studentId: map['student_id'] ?? '',
        materialId: map['material_id'] ?? '',
        progressPercent: (map['progress_percent'] as num?)?.toDouble() ?? 0.0,
        isCompleted: map['is_completed'] ?? false,
        lastViewedAt: map['last_viewed_at'] != null
            ? DateTime.tryParse(map['last_viewed_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}
