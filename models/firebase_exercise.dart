/// Model representing an exercise from Firebase database.
class FirebaseExercise {
  final String id;
  final String name;
  final String description;
  final String category;
  final List<String> muscles;
  final List<String> musclesSecondary;
  final List<String> equipment;
  final List<String> images;

  FirebaseExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.muscles,
    required this.musclesSecondary,
    required this.equipment,
    required this.images,
  });

  /// Factory constructor for parsing from a map.
  /// If [docId] is provided and non-empty, it takes precedence over map['id'].
  factory FirebaseExercise.fromMap(Map<String, dynamic> map, [String? docId]) {
    final resolvedId = (docId != null && docId.isNotEmpty) 
        ? docId 
        : (map['id']?.toString() ?? '');
    return FirebaseExercise(
      id: resolvedId,
      name: (map['name'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      muscles: List<String>.from(map['muscles'] ?? const <String>[]),
      musclesSecondary: List<String>.from(map['muscles_secondary'] ?? const <String>[]),
      equipment: List<String>.from(map['equipment'] ?? const <String>[]),
      images: List<String>.from(map['images'] ?? const <String>[]),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'muscles': muscles,
      'muscles_secondary': musclesSecondary,
      'equipment': equipment,
      'images': images,
    };
  }
}
