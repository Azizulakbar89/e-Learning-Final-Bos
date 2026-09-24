import 'package:flutter/material.dart';

class SubjectModel {
  final String id;
  final String name;
  final String code;
  final String? icon;
  final double kkm;

  SubjectModel({
    required this.id,
    required this.name,
    required this.code,
    this.icon,
    this.kkm = 75.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'icon': icon,
      'kkm': kkm,
    };
  }

  factory SubjectModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return SubjectModel(
      id: id ?? map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      icon: map['icon'],
      kkm: (map['kkm'] as num?)?.toDouble() ?? 75.0,
    );
  }

  SubjectModel copyWith({
    String? id,
    String? name,
    String? code,
    String? icon,
    double? kkm,
  }) {
    return SubjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      icon: icon ?? this.icon,
      kkm: kkm ?? this.kkm,
    );
  }
}

class CurriculumCpModel {
  final String id;
  final String subjectId;
  final String teacherId;
  final String code; // e.g. "CP-MTK-10.1"
  final String title;
  final String description;

  CurriculumCpModel({
    required this.id,
    required this.subjectId,
    required this.teacherId,
    required this.code,
    required this.title,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'code': code,
      'title': title,
      'description': description,
    };
  }

  factory CurriculumCpModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return CurriculumCpModel(
      id: id ?? map['id'] ?? '',
      subjectId: map['subject_id'] ?? '',
      teacherId: map['teacher_id'] ?? '',
      code: map['code'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
    );
  }
  String get desc => description;

  CurriculumCpModel copyWith({
    String? id,
    String? subjectId,
    String? teacherId,
    String? code,
    String? title,
    String? description,
  }) {
    return CurriculumCpModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      teacherId: teacherId ?? this.teacherId,
      code: code ?? this.code,
      title: title ?? this.title,
      description: description ?? this.description,
    );
  }
}

class CurriculumTpModel {
  final String id;
  final String cpId;
  final String subjectId;
  final String code; // e.g. "TP-10.1.1"
  final String title;
  final String description;

  CurriculumTpModel({
    required this.id,
    required this.cpId,
    required this.subjectId,
    required this.code,
    required this.title,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cp_id': cpId,
      'subject_id': subjectId,
      'code': code,
      'title': title,
      'description': description,
    };
  }

  factory CurriculumTpModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return CurriculumTpModel(
      id: id ?? map['id'] ?? '',
      cpId: map['cp_id'] ?? '',
      subjectId: map['subject_id'] ?? '',
      code: map['code'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
    );
  }

  String get desc => description;

  CurriculumTpModel copyWith({
    String? id,
    String? cpId,
    String? subjectId,
    String? code,
    String? title,
    String? description,
  }) {
    return CurriculumTpModel(
      id: id ?? this.id,
      cpId: cpId ?? this.cpId,
      subjectId: subjectId ?? this.subjectId,
      code: code ?? this.code,
      title: title ?? this.title,
      description: description ?? this.description,
    );
  }
}

class StudentSubjectGrade {
  final SubjectModel subject;
  final double? examAverage;
  final int completedExams;
  final int totalExams;
  final double? assignmentAverage;
  final int completedAssignments;
  final int totalAssignments;
  final double bonusGrade;
  final double? finalGrade;
  final String predicate;
  final Color statusColor;

  StudentSubjectGrade({
    required this.subject,
    this.examAverage,
    required this.completedExams,
    required this.totalExams,
    this.assignmentAverage,
    required this.completedAssignments,
    required this.totalAssignments,
    required this.bonusGrade,
    this.finalGrade,
    required this.predicate,
    required this.statusColor,
  });
}

