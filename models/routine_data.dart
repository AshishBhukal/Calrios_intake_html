/// Shared routine metadata model used by routine list and routine creator.
class RoutineData {
  String name;
  String type;
  DateTime? createdAt;
  String? id;

  RoutineData({
    this.name = '',
    this.type = '',
    this.createdAt,
    this.id,
  });

  bool get isValid => name.trim().isNotEmpty && type.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'createdAt': createdAt?.toIso8601String(),
      'id': id,
    };
  }

  factory RoutineData.fromMap(Map<String, dynamic> map) {
    return RoutineData(
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      createdAt:
          map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      id: map['id'],
    );
  }

  RoutineData copyWith({
    String? name,
    String? type,
    DateTime? createdAt,
    String? id,
  }) {
    return RoutineData(
      name: name ?? this.name,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      id: id ?? this.id,
    );
  }
}
