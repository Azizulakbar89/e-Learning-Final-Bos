enum SubmissionType {
  pdf,
  link,
  image,
  text,
  code,
}

extension SubmissionTypeExtension on SubmissionType {
  String get label {
    switch (this) {
      case SubmissionType.pdf:
        return 'Berkas PDF';
      case SubmissionType.link:
        return 'Tautan / Link';
      case SubmissionType.image:
        return 'Gambar / Foto';
      case SubmissionType.text:
        return 'Teks Bebas';
      case SubmissionType.code:
        return 'Koding (Compiler IDE)';
    }
  }

  String get code {
    switch (this) {
      case SubmissionType.pdf:
        return 'pdf';
      case SubmissionType.link:
        return 'link';
      case SubmissionType.image:
        return 'image';
      case SubmissionType.text:
        return 'text';
      case SubmissionType.code:
        return 'code';
    }
  }

  static SubmissionType fromString(String val) {
    switch (val) {
      case 'link':
        return SubmissionType.link;
      case 'image':
        return SubmissionType.image;
      case 'text':
        return SubmissionType.text;
      case 'code':
        return SubmissionType.code;
      default:
        return SubmissionType.pdf;
    }
  }
}

class CodeConfig {
  final List<String> allowedLanguages; // 'html', 'css', 'js', 'php', 'arduino'
  final String starterCode;
  final bool requireSuccessfulCompile;

  CodeConfig({
    this.allowedLanguages = const ['html', 'css', 'js', 'php', 'arduino'],
    this.starterCode = '',
    this.requireSuccessfulCompile = true,
  });

  Map<String, dynamic> toMap() => {
        'allowed_languages': allowedLanguages,
        'starter_code': starterCode,
        'require_successful_compile': requireSuccessfulCompile,
      };

  factory CodeConfig.fromMap(Map<String, dynamic> map) => CodeConfig(
        allowedLanguages: List<String>.from(map['allowed_languages'] ?? ['html', 'css', 'js', 'php', 'arduino']),
        starterCode: map['starter_code'] ?? '',
        requireSuccessfulCompile: map['require_successful_compile'] ?? true,
      );
}

class AssignmentModel {
  final String id;
  final String materialId;
  final String subjectId;
  final String teacherId;
  final String title;
  final String description;
  final String assignmentType; // 'individu' | 'kelompok' | 'pilihan_ganda'
  final List<String> classIds; // kelas yang menerima tugas
  final bool isGroup;
  final int maxGroupMembers;
  final List<SubmissionType> allowedSubmissionTypes;
  final CodeConfig? codeConfig;
  final List<String> questionIds; // untuk mode pilihan_ganda
  final DateTime deadline;
  final DateTime createdAt;

  AssignmentModel({
    required this.id,
    required this.materialId,
    required this.subjectId,
    required this.teacherId,
    required this.title,
    required this.description,
    this.assignmentType = 'individu',
    this.classIds = const [],
    this.isGroup = false,
    this.maxGroupMembers = 1,
    required this.allowedSubmissionTypes,
    this.codeConfig,
    this.questionIds = const [],
    required this.deadline,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'material_id': materialId,
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'title': title,
      'description': description,
      'assignment_type': assignmentType,
      'class_ids': classIds,
      'is_group': isGroup,
      'max_group_members': maxGroupMembers,
      'allowed_submission_types': allowedSubmissionTypes.map((t) => t.code).toList(),
      'code_config': codeConfig?.toMap(),
      'question_ids': questionIds,
      'deadline': deadline.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AssignmentModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawClassIds = map['class_ids'] ?? map['classIds'];
    List<String> parsedClassIds = [];
    if (rawClassIds is List) {
      parsedClassIds = rawClassIds.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    } else if (rawClassIds is String && rawClassIds.trim().isNotEmpty) {
      parsedClassIds = [rawClassIds.trim()];
    }

    final rawSubmTypes = map['allowed_submission_types'] ?? map['allowedSubmissionTypes'];
    List<SubmissionType> parsedSubmTypes = [SubmissionType.pdf];
    if (rawSubmTypes is List && rawSubmTypes.isNotEmpty) {
      parsedSubmTypes = rawSubmTypes
          .map((item) => SubmissionTypeExtension.fromString(item.toString()))
          .toList();
    }

    final rawCodeConfig = map['code_config'] ?? map['codeConfig'];
    CodeConfig? parsedCodeConfig;
    if (rawCodeConfig is Map<String, dynamic>) {
      parsedCodeConfig = CodeConfig.fromMap(rawCodeConfig);
    } else if (rawCodeConfig is Map) {
      parsedCodeConfig = CodeConfig.fromMap(Map<String, dynamic>.from(rawCodeConfig));
    }

    final rawQuestions = map['question_ids'] ?? map['questionIds'];
    List<String> parsedQuestionIds = [];
    if (rawQuestions is List) {
      parsedQuestionIds = rawQuestions.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }

    final rawDeadline = map['deadline'];
    DateTime deadline = DateTime.now().add(const Duration(days: 7));
    if (rawDeadline != null) {
      deadline = DateTime.tryParse(rawDeadline.toString()) ?? deadline;
    }

    final rawCreatedAt = map['created_at'] ?? map['createdAt'];
    DateTime createdAt = DateTime.now();
    if (rawCreatedAt != null) {
      createdAt = DateTime.tryParse(rawCreatedAt.toString()) ?? createdAt;
    }

    return AssignmentModel(
      id: id ?? map['id']?.toString() ?? '',
      materialId: (map['material_id'] ?? map['materialId'] ?? '').toString().trim(),
      subjectId: (map['subject_id'] ?? map['subjectId'] ?? '').toString().trim(),
      teacherId: (map['teacher_id'] ?? map['teacherId'] ?? '').toString().trim(),
      title: (map['title'] ?? '').toString().trim(),
      description: (map['description'] ?? '').toString().trim(),
      assignmentType: (map['assignment_type'] ?? map['assignmentType'] ?? 'individu').toString(),
      classIds: parsedClassIds,
      isGroup: map['is_group'] == true || map['isGroup'] == true,
      maxGroupMembers: (map['max_group_members'] as num? ?? map['maxGroupMembers'] as num?)?.toInt() ?? 1,
      allowedSubmissionTypes: parsedSubmTypes,
      codeConfig: parsedCodeConfig,
      questionIds: parsedQuestionIds,
      deadline: deadline,
      createdAt: createdAt,
    );
  }
}

class AssignmentSubmissionModel {
  final String id;
  final String assignmentId;
  final String? groupId;
  final String? groupName;
  final String submitterId;
  final String submitterName;
  final List<String> memberStudentIds; // Grade is synced to all these students
  final SubmissionType type;
  final String? pdfUrl;
  final String? linkUrl;
  final List<String> imageUrls;
  final String? textContent;
  final String? codeLanguage;
  final String? sourceCode;
  final String? compileLog;
  final bool compileSuccess;
  final double? score; // Grade
  final String? teacherFeedback;
  final DateTime submittedAt;
  final DateTime? gradedAt;

  AssignmentSubmissionModel({
    required this.id,
    required this.assignmentId,
    this.groupId,
    this.groupName,
    required this.submitterId,
    required this.submitterName,
    required this.memberStudentIds,
    required this.type,
    this.pdfUrl,
    this.linkUrl,
    this.imageUrls = const [],
    this.textContent,
    this.codeLanguage,
    this.sourceCode,
    this.compileLog,
    this.compileSuccess = false,
    this.score,
    this.teacherFeedback,
    required this.submittedAt,
    this.gradedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'assignment_id': assignmentId,
      'group_id': groupId,
      'group_name': groupName,
      'submitter_id': submitterId,
      'submitter_name': submitterName,
      'member_student_ids': memberStudentIds,
      'type': type.code,
      'pdf_url': pdfUrl,
      'link_url': linkUrl,
      'image_urls': imageUrls,
      'text_content': textContent,
      'code_language': codeLanguage,
      'source_code': sourceCode,
      'compile_log': compileLog,
      'compile_success': compileSuccess,
      'score': score,
      'teacher_feedback': teacherFeedback,
      'submitted_at': submittedAt.toIso8601String(),
      'graded_at': gradedAt?.toIso8601String(),
    };
  }

  factory AssignmentSubmissionModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return AssignmentSubmissionModel(
      id: id ?? map['id'] ?? '',
      assignmentId: map['assignment_id'] ?? '',
      groupId: map['group_id'],
      groupName: map['group_name'],
      submitterId: map['submitter_id'] ?? '',
      submitterName: map['submitter_name'] ?? '',
      memberStudentIds: List<String>.from(map['member_student_ids'] ?? []),
      type: SubmissionTypeExtension.fromString(map['type'] ?? 'pdf'),
      pdfUrl: map['pdf_url'],
      linkUrl: map['link_url'],
      imageUrls: List<String>.from(map['image_urls'] ?? []),
      textContent: map['text_content'],
      codeLanguage: map['code_language'],
      sourceCode: map['source_code'],
      compileLog: map['compile_log'],
      compileSuccess: map['compile_success'] ?? false,
      score: (map['score'] as num?)?.toDouble(),
      teacherFeedback: map['teacher_feedback'],
      submittedAt: map['submitted_at'] != null
          ? DateTime.tryParse(map['submitted_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      gradedAt: map['graded_at'] != null ? DateTime.tryParse(map['graded_at'].toString()) : null,
    );
  }

  AssignmentSubmissionModel copyWith({
    String? id,
    String? assignmentId,
    String? groupId,
    String? groupName,
    String? submitterId,
    String? submitterName,
    List<String>? memberStudentIds,
    SubmissionType? type,
    String? pdfUrl,
    String? linkUrl,
    List<String>? imageUrls,
    String? textContent,
    String? codeLanguage,
    String? sourceCode,
    String? compileLog,
    bool? compileSuccess,
    double? score,
    String? teacherFeedback,
    DateTime? submittedAt,
    DateTime? gradedAt,
  }) {
    return AssignmentSubmissionModel(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      submitterId: submitterId ?? this.submitterId,
      submitterName: submitterName ?? this.submitterName,
      memberStudentIds: memberStudentIds ?? this.memberStudentIds,
      type: type ?? this.type,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      linkUrl: linkUrl ?? this.linkUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      textContent: textContent ?? this.textContent,
      codeLanguage: codeLanguage ?? this.codeLanguage,
      sourceCode: sourceCode ?? this.sourceCode,
      compileLog: compileLog ?? this.compileLog,
      compileSuccess: compileSuccess ?? this.compileSuccess,
      score: score ?? this.score,
      teacherFeedback: teacherFeedback ?? this.teacherFeedback,
      submittedAt: submittedAt ?? this.submittedAt,
      gradedAt: gradedAt ?? this.gradedAt,
    );
  }
}

// ─── Group Registration Model ────────────────────────────────────────────────
/// Represents a student-formed group for a group assignment.
/// The leader creates this, selecting members from the same class.
class GroupRegistrationModel {
  final String id;
  final String assignmentId;
  final String groupName;
  final String leaderId;
  final String leaderName;
  final List<String> memberIds; // includes leaderId
  final List<String> memberNames;
  final String classId;
  final DateTime createdAt;

  GroupRegistrationModel({
    required this.id,
    required this.assignmentId,
    required this.groupName,
    required this.leaderId,
    required this.leaderName,
    required this.memberIds,
    required this.memberNames,
    required this.classId,
    required this.createdAt,
  });

  bool get hasSubmitted => false; // overridden by submission lookup

  Map<String, dynamic> toMap() => {
        'id': id,
        'assignment_id': assignmentId,
        'group_name': groupName,
        'leader_id': leaderId,
        'leader_name': leaderName,
        'member_ids': memberIds,
        'member_names': memberNames,
        'class_id': classId,
        'created_at': createdAt.toIso8601String(),
      };

  factory GroupRegistrationModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      GroupRegistrationModel(
        id: id ?? map['id'] ?? '',
        assignmentId: map['assignment_id'] ?? '',
        groupName: map['group_name'] ?? '',
        leaderId: map['leader_id'] ?? '',
        leaderName: map['leader_name'] ?? '',
        memberIds: List<String>.from(map['member_ids'] ?? []),
        memberNames: List<String>.from(map['member_names'] ?? []),
        classId: map['class_id'] ?? '',
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}
