enum ExamCategory {
  quiz,
  harian,
  pts,
  pas;

  String get label {
    switch (this) {
      case ExamCategory.quiz:
        return 'Quiz';
      case ExamCategory.harian:
        return 'Harian';
      case ExamCategory.pts:
        return 'PTS';
      case ExamCategory.pas:
        return 'PAS';
    }
  }

  String get fullLabel {
    switch (this) {
      case ExamCategory.quiz:
        return 'Kuis Interaktif';
      case ExamCategory.harian:
        return 'Penilaian Harian (PH)';
      case ExamCategory.pts:
        return 'Penilaian Tengah Semester (PTS)';
      case ExamCategory.pas:
        return 'Penilaian Akhir Semester (PAS)';
    }
  }

  static ExamCategory fromString(String? val) {
    if (val == null) return ExamCategory.harian;
    final normalized = val.toLowerCase().trim();
    if (normalized == 'quiz' || normalized == 'kuis') return ExamCategory.quiz;
    if (normalized == 'harian' || normalized == 'ph' || normalized == 'ulangan harian') return ExamCategory.harian;
    if (normalized == 'pts' || normalized == 'uts') return ExamCategory.pts;
    if (normalized == 'pas' || normalized == 'pat' || normalized == 'uas') return ExamCategory.pas;
    return ExamCategory.harian;
  }
}

class ExamModel {
  final String id;
  final String subjectId;
  final String teacherId;
  final List<String> classIds;
  final String title;
  final String description;
  final ExamCategory category;
  final int durationMinutes;
  final bool antiCheatEnabled; // Toggleable by teacher during exam
  final List<String> questionIds;
  final DateTime createdAt;
  final DateTime? startTime; // Jadwal mulai ujian
  final DateTime? endTime; // Jadwal akhir ujian

  ExamModel({
    required this.id,
    required this.subjectId,
    required this.teacherId,
    required this.classIds,
    required this.title,
    required this.description,
    this.category = ExamCategory.harian,
    this.durationMinutes = 60,
    this.antiCheatEnabled = true,
    required this.questionIds,
    required this.createdAt,
    this.startTime,
    this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'class_ids': classIds,
      'title': title,
      'description': description,
      'category': category.name,
      'duration_minutes': durationMinutes,
      'anti_cheat_enabled': antiCheatEnabled,
      'question_ids': questionIds,
      'created_at': createdAt.toIso8601String(),
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
    };
  }

  factory ExamModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return ExamModel(
      id: id ?? map['id'] ?? '',
      subjectId: map['subject_id'] ?? '',
      teacherId: map['teacher_id'] ?? '',
      classIds: List<String>.from(map['class_ids'] ?? []),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: ExamCategory.fromString(map['category'] ?? map['type']),
      durationMinutes: (map['duration_minutes'] as num?)?.toInt() ?? 60,
      antiCheatEnabled: map['anti_cheat_enabled'] ?? true,
      questionIds: List<String>.from(map['question_ids'] ?? []),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      startTime: map['start_time'] != null ? DateTime.tryParse(map['start_time'].toString()) : null,
      endTime: map['end_time'] != null ? DateTime.tryParse(map['end_time'].toString()) : null,
    );
  }

  ExamModel copyWith({
    String? id,
    String? subjectId,
    String? teacherId,
    List<String>? classIds,
    String? title,
    String? description,
    ExamCategory? category,
    int? durationMinutes,
    bool? antiCheatEnabled,
    List<String>? questionIds,
    DateTime? createdAt,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return ExamModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      teacherId: teacherId ?? this.teacherId,
      classIds: classIds ?? this.classIds,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      antiCheatEnabled: antiCheatEnabled ?? this.antiCheatEnabled,
      questionIds: questionIds ?? this.questionIds,
      createdAt: createdAt ?? this.createdAt,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}

class ExamSessionModel {
  final String id;
  final String examId;
  final String studentId;
  final String studentNis;
  final String studentName;
  final String studentClass;
  final String status; // 'in_progress' | 'locked' | 'completed' | 'reset'
  final int currentQuestionIndex;
  final List<String> orderedQuestionIds; // Urutan soal acak per akun siswa
  final Map<String, dynamic> answers;
  final Map<String, double> essayScores; // 1 to 5 per essay question
  final int violationCount;
  final String? lastViolationReason;
  final double? nonEssayScore;
  final double? finalScore;
  final bool antiCheatDisabledForStudent; // Nonaktifkan cheat khusus untuk siswa ini
  final DateTime startedAt;
  final DateTime? finishedAt;
  final DateTime updatedAt;

  ExamSessionModel({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.studentNis,
    required this.studentName,
    required this.studentClass,
    this.status = 'in_progress',
    this.currentQuestionIndex = 0,
    this.orderedQuestionIds = const [],
    this.answers = const {},
    this.essayScores = const {},
    this.violationCount = 0,
    this.lastViolationReason,
    this.nonEssayScore,
    this.finalScore,
    this.antiCheatDisabledForStudent = false,
    required this.startedAt,
    this.finishedAt,
    required this.updatedAt,
  });

  bool get isLocked => status == 'locked';
  bool get isCompleted =>
      status == 'completed' ||
      status == 'finished' ||
      status == 'graded' ||
      finishedAt != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exam_id': examId,
      'student_id': studentId,
      'student_nis': studentNis,
      'student_name': studentName,
      'student_class': studentClass,
      'status': status,
      'current_question_index': currentQuestionIndex,
      'ordered_question_ids': orderedQuestionIds,
      'answers': answers,
      'essay_scores': essayScores,
      'violation_count': violationCount,
      'last_violation_reason': lastViolationReason,
      'non_essay_score': nonEssayScore,
      'final_score': finalScore,
      'anti_cheat_disabled_for_student': antiCheatDisabledForStudent,
      'started_at': startedAt.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ExamSessionModel.fromMap(Map<String, dynamic> map, {String? id}) {
    Map<String, double> parsedEssayScores = {};
    final rawEssay = map['essay_scores'] ?? map['essayScores'];
    if (rawEssay != null && rawEssay is Map) {
      rawEssay.forEach((k, v) {
        if (v is num) {
          parsedEssayScores[k.toString()] = v.toDouble();
        }
      });
    }

    return ExamSessionModel(
      id: id ?? map['id']?.toString() ?? '',
      examId: (map['exam_id'] ?? map['examId'])?.toString() ?? '',
      studentId: (map['student_id'] ?? map['studentId'])?.toString() ?? '',
      studentNis: (map['student_nis'] ?? map['studentNis'])?.toString() ?? '',
      studentName: (map['student_name'] ?? map['studentName'])?.toString() ?? '',
      studentClass: (map['student_class'] ?? map['studentClass'])?.toString() ?? '',
      status: (map['status'])?.toString() ?? 'in_progress',
      currentQuestionIndex: (map['current_question_index'] ?? map['currentQuestionIndex'] as num?)?.toInt() ?? 0,
      orderedQuestionIds: List<String>.from(map['ordered_question_ids'] ?? map['orderedQuestionIds'] ?? []),
      answers: Map<String, dynamic>.from(map['answers'] ?? {}),
      essayScores: parsedEssayScores,
      violationCount: (map['violation_count'] ?? map['violationCount'] as num?)?.toInt() ?? 0,
      lastViolationReason: (map['last_violation_reason'] ?? map['lastViolationReason'])?.toString(),
      nonEssayScore: (map['non_essay_score'] ?? map['nonEssayScore'] as num?)?.toDouble(),
      finalScore: (map['final_score'] ?? map['finalScore'] as num?)?.toDouble(),
      antiCheatDisabledForStudent: (map['anti_cheat_disabled_for_student'] ?? map['antiCheatDisabledForStudent']) as bool? ?? false,
      startedAt: map['started_at'] != null || map['startedAt'] != null
          ? DateTime.tryParse((map['started_at'] ?? map['startedAt']).toString()) ?? DateTime.now()
          : DateTime.now(),
      finishedAt: map['finished_at'] != null || map['finishedAt'] != null
          ? DateTime.tryParse((map['finished_at'] ?? map['finishedAt']).toString())
          : null,
      updatedAt: map['updated_at'] != null || map['updatedAt'] != null
          ? DateTime.tryParse((map['updated_at'] ?? map['updatedAt']).toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  ExamSessionModel copyWith({
    String? id,
    String? examId,
    String? studentId,
    String? studentNis,
    String? studentName,
    String? studentClass,
    String? status,
    int? currentQuestionIndex,
    List<String>? orderedQuestionIds,
    Map<String, dynamic>? answers,
    Map<String, double>? essayScores,
    int? violationCount,
    String? lastViolationReason,
    double? nonEssayScore,
    double? finalScore,
    bool? antiCheatDisabledForStudent,
    DateTime? startedAt,
    DateTime? finishedAt,
    DateTime? updatedAt,
  }) {
    return ExamSessionModel(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      studentId: studentId ?? this.studentId,
      studentNis: studentNis ?? this.studentNis,
      studentName: studentName ?? this.studentName,
      studentClass: studentClass ?? this.studentClass,
      status: status ?? this.status,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      orderedQuestionIds: orderedQuestionIds ?? this.orderedQuestionIds,
      answers: answers ?? this.answers,
      essayScores: essayScores ?? this.essayScores,
      violationCount: violationCount ?? this.violationCount,
      lastViolationReason: lastViolationReason ?? this.lastViolationReason,
      nonEssayScore: nonEssayScore ?? this.nonEssayScore,
      finalScore: finalScore ?? this.finalScore,
      antiCheatDisabledForStudent: antiCheatDisabledForStudent ?? this.antiCheatDisabledForStudent,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
