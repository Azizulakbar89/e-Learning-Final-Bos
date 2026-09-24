enum QuestionType {
  single, // Pilihan Ganda
  multi, // Pilihan Ganda Multi / Kompleks
  trueFalse, // Benar / Salah
  matching, // Menjodohkan
  essay, // Esai (1-5 point scale)
}

extension QuestionTypeExtension on QuestionType {
  String get label {
    switch (this) {
      case QuestionType.single:
        return 'Pilihan Ganda';
      case QuestionType.multi:
        return 'Pilihan Ganda Kompleks';
      case QuestionType.trueFalse:
        return 'Benar / Salah';
      case QuestionType.matching:
        return 'Menjodohkan';
      case QuestionType.essay:
        return 'Esai (Skala 1-5)';
    }
  }

  String get code {
    switch (this) {
      case QuestionType.single:
        return 'single';
      case QuestionType.multi:
        return 'multi';
      case QuestionType.trueFalse:
        return 'true_false';
      case QuestionType.matching:
        return 'matching';
      case QuestionType.essay:
        return 'essay';
    }
  }

  static QuestionType fromString(String val) {
    switch (val) {
      case 'multi':
        return QuestionType.multi;
      case 'true_false':
        return QuestionType.trueFalse;
      case 'matching':
        return QuestionType.matching;
      case 'essay':
        return QuestionType.essay;
      default:
        return QuestionType.single;
    }
  }
}

class QuestionOption {
  final String id;
  final String text;
  final String? equationLatex;
  final String? matchingKey; // For matching pairs: prompt (left) or match (right)

  QuestionOption({
    required this.id,
    required this.text,
    this.equationLatex,
    this.matchingKey,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'equation_latex': equationLatex,
        'matching_key': matchingKey,
      };

  factory QuestionOption.fromMap(Map<String, dynamic> map) => QuestionOption(
        id: map['id'] ?? '',
        text: map['text'] ?? '',
        equationLatex: map['equation_latex'],
        matchingKey: map['matching_key'],
      );
}

class QuestionModel {
  final String id;
  final String subjectId;
  final String? cpId;
  final String? tpId;
  final String? teacherId;
  final String? creatorName;
  final QuestionType type;
  final String content; // Text / WYSIWYG
  final String? equationLatex; // Math formula in LaTeX
  final bool hasImage;
  final List<String> imageUrls;
  final bool missingImageFlag; // Flags questions mentioning images but missing media
  final List<QuestionOption> options;
  final dynamic correctAnswers; // String for single, List<String> for multi, Map for matching, bool for TF
  final int maxEssayScore; // Scale 1 - 5 for essay

  QuestionModel({
    required this.id,
    required this.subjectId,
    this.cpId,
    this.tpId,
    this.teacherId,
    this.creatorName,
    required this.type,
    required this.content,
    this.equationLatex,
    this.hasImage = false,
    this.imageUrls = const [],
    this.missingImageFlag = false,
    this.options = const [],
    this.correctAnswers,
    this.maxEssayScore = 5,
  });

  bool get hasMissingMediaReference => missingImageFlag;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_id': subjectId,
      'cp_id': cpId,
      'tp_id': tpId,
      'teacher_id': teacherId,
      'creator_name': creatorName,
      'question_type': type.code,
      'content': content,
      'equation_latex': equationLatex,
      'has_image': hasImage,
      'image_urls': imageUrls,
      'missing_image_flag': missingImageFlag,
      'options': options.map((o) => o.toMap()).toList(),
      'correct_answers': correctAnswers,
      'max_essay_score': maxEssayScore,
    };
  }

  factory QuestionModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return QuestionModel(
      id: id ?? map['id'] ?? '',
      subjectId: map['subject_id'] ?? '',
      cpId: map['cp_id'],
      tpId: map['tp_id'],
      teacherId: map['teacher_id'],
      creatorName: map['creator_name'],
      type: QuestionTypeExtension.fromString(map['question_type'] ?? 'single'),
      content: map['content'] ?? '',
      equationLatex: map['equation_latex'],
      hasImage: map['has_image'] ?? false,
      imageUrls: List<String>.from(map['image_urls'] ?? []),
      missingImageFlag: map['missing_image_flag'] ?? false,
      options: (map['options'] as List<dynamic>? ?? [])
          .map((item) => QuestionOption.fromMap(item as Map<String, dynamic>))
          .toList(),
      correctAnswers: map['correct_answers'],
      maxEssayScore: (map['max_essay_score'] as num?)?.toInt() ?? 5,
    );
  }

  QuestionModel copyWith({
    String? id,
    String? subjectId,
    String? cpId,
    String? tpId,
    String? teacherId,
    String? creatorName,
    QuestionType? type,
    String? content,
    String? equationLatex,
    bool? hasImage,
    List<String>? imageUrls,
    bool? missingImageFlag,
    List<QuestionOption>? options,
    dynamic correctAnswers,
    int? maxEssayScore,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      cpId: cpId ?? this.cpId,
      tpId: tpId ?? this.tpId,
      teacherId: teacherId ?? this.teacherId,
      creatorName: creatorName ?? this.creatorName,
      type: type ?? this.type,
      content: content ?? this.content,
      equationLatex: equationLatex ?? this.equationLatex,
      hasImage: hasImage ?? this.hasImage,
      imageUrls: imageUrls ?? this.imageUrls,
      missingImageFlag: missingImageFlag ?? this.missingImageFlag,
      options: options ?? this.options,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      maxEssayScore: maxEssayScore ?? this.maxEssayScore,
    );
  }
}
