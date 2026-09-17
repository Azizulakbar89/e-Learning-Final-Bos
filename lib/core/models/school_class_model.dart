class SchoolClassModel {
  final String id;
  final String name;
  final DateTime createdAt;

  SchoolClassModel({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SchoolClassModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return SchoolClassModel(
      id: id ?? map['id'] ?? '',
      name: map['name'] ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  SchoolClassModel copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
  }) {
    return SchoolClassModel(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
