import 'package:flutter/material.dart';

class PointTransactionModel {
  final String id;
  final String studentId;
  final int points;
  final String reason; // e.g. "Selesai Baca Materi", "Streak Harian", "Tukar Nilai"
  final bool isDebit; // true if spending, false if earning
  final DateTime createdAt;

  PointTransactionModel({
    required this.id,
    required this.studentId,
    required this.points,
    required this.reason,
    this.isDebit = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'points': points,
        'reason': reason,
        'is_debit': isDebit,
        'created_at': createdAt.toIso8601String(),
      };

  factory PointTransactionModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      PointTransactionModel(
        id: id ?? map['id'] ?? '',
        studentId: map['student_id'] ?? '',
        points: (map['points'] as num?)?.toInt() ?? 0,
        reason: map['reason'] ?? '',
        isDebit: map['is_debit'] ?? false,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

class GradeRedeemModel {
  final String id;
  final String studentId;
  final String subjectId;
  final String subjectName;
  final int pointsSpent;
  final double bonusGrade; // e.g. 500 points = +5 bonus grade
  final DateTime createdAt;

  GradeRedeemModel({
    required this.id,
    required this.studentId,
    required this.subjectId,
    required this.subjectName,
    required this.pointsSpent,
    required this.bonusGrade,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'subject_id': subjectId,
        'subject_name': subjectName,
        'points_spent': pointsSpent,
        'bonus_grade': bonusGrade,
        'created_at': createdAt.toIso8601String(),
      };

  factory GradeRedeemModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      GradeRedeemModel(
        id: id ?? map['id'] ?? '',
        studentId: map['student_id'] ?? '',
        subjectId: map['subject_id'] ?? '',
        subjectName: map['subject_name'] ?? '',
        pointsSpent: (map['points_spent'] as num?)?.toInt() ?? 0,
        bonusGrade: (map['bonus_grade'] as num?)?.toDouble() ?? 0.0,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

class BadgeModel {
  final String id;
  final String title;
  final String description;
  final String icon; // Emoji e.g. '🔥', '⚡', '🏆'
  final Color color;
  final bool isEarned;
  final String progressText;
  final double progress; // 0.0 to 1.0
  final String howToGet;
  final bool isMonthly;
  final String category; // 'bulanan' | 'prestasi'
  final String periodLabel;

  BadgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isEarned,
    required this.progressText,
    required this.progress,
    required this.howToGet,
    this.isMonthly = false,
    this.category = 'prestasi',
    this.periodLabel = 'Permanen',
  });
}

