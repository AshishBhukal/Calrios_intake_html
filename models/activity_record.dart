import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of physical activities tracked by the app.
enum ActivityType {
  running,
  cycling,
  walking,
  strength,
  yoga,
  swimming,
  other;

  String get displayName {
    switch (this) {
      case ActivityType.running:
        return 'Running';
      case ActivityType.cycling:
        return 'Cycling';
      case ActivityType.walking:
        return 'Walking';
      case ActivityType.strength:
        return 'Strength';
      case ActivityType.yoga:
        return 'Yoga';
      case ActivityType.swimming:
        return 'Swimming';
      case ActivityType.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case ActivityType.running:
        return 'directions_run';
      case ActivityType.cycling:
        return 'directions_bike';
      case ActivityType.walking:
        return 'directions_walk';
      case ActivityType.strength:
        return 'fitness_center';
      case ActivityType.yoga:
        return 'self_improvement';
      case ActivityType.swimming:
        return 'pool';
      case ActivityType.other:
        return 'sports';
    }
  }

  /// Base MET value (Metabolic Equivalent of Task) for calorie estimation.
  /// These are median values; intensity slider adjusts the range.
  double get baseMet {
    switch (this) {
      case ActivityType.running:
        return 9.8;
      case ActivityType.cycling:
        return 7.5;
      case ActivityType.walking:
        return 3.8;
      case ActivityType.strength:
        return 5.0;
      case ActivityType.yoga:
        return 3.0;
      case ActivityType.swimming:
        return 7.0;
      case ActivityType.other:
        return 5.0;
    }
  }

  /// MET range [min, max] scaled by intensity slider (0.0 = low, 1.0 = peak).
  List<double> get metRange {
    switch (this) {
      case ActivityType.running:
        return [8.0, 12.0];
      case ActivityType.cycling:
        return [6.0, 10.0];
      case ActivityType.walking:
        return [3.5, 5.0];
      case ActivityType.strength:
        return [3.0, 6.0];
      case ActivityType.yoga:
        return [2.5, 4.0];
      case ActivityType.swimming:
        return [6.0, 10.0];
      case ActivityType.other:
        return [3.0, 8.0];
    }
  }

  /// Whether this activity type typically involves distance.
  bool get hasDistance {
    switch (this) {
      case ActivityType.running:
      case ActivityType.cycling:
      case ActivityType.walking:
      case ActivityType.swimming:
        return true;
      case ActivityType.strength:
      case ActivityType.yoga:
      case ActivityType.other:
        return false;
    }
  }
}

/// Source of the activity data.
enum ActivitySource {
  watch,
  manual;

  String get displayName {
    switch (this) {
      case ActivitySource.watch:
        return 'Watch';
      case ActivitySource.manual:
        return 'Manual';
    }
  }
}

/// A single recorded physical activity session.
class ActivityRecord {
  final String id;
  final ActivityType type;
  final double caloriesBurned;
  final double? distanceMeters;
  final int durationMinutes;
  final DateTime startTime;
  final DateTime endTime;
  final ActivitySource source;
  final double? avgHeartRate;
  final int? steps;
  final double? intensity; // 0.0 - 1.0, only for manual entries
  final String? notes;
  final DateTime createdAt;

  const ActivityRecord({
    required this.id,
    required this.type,
    required this.caloriesBurned,
    this.distanceMeters,
    required this.durationMinutes,
    required this.startTime,
    required this.endTime,
    required this.source,
    this.avgHeartRate,
    this.steps,
    this.intensity,
    this.notes,
    required this.createdAt,
  });

  /// Create from Firestore document map.
  factory ActivityRecord.fromMap(Map<String, dynamic> map) {
    return ActivityRecord(
      id: map['id'] as String? ?? '',
      type: ActivityType.values.firstWhere(
        (e) => e.name == (map['type'] as String? ?? 'other'),
        orElse: () => ActivityType.other,
      ),
      caloriesBurned: (map['caloriesBurned'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble(),
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
      startTime: _parseDateTime(map['startTime']),
      endTime: _parseDateTime(map['endTime']),
      source: ActivitySource.values.firstWhere(
        (e) => e.name == (map['source'] as String? ?? 'manual'),
        orElse: () => ActivitySource.manual,
      ),
      avgHeartRate: (map['avgHeartRate'] as num?)?.toDouble(),
      steps: (map['steps'] as num?)?.toInt(),
      intensity: (map['intensity'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  /// Convert to Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'caloriesBurned': caloriesBurned,
      if (distanceMeters != null) 'distanceMeters': distanceMeters,
      'durationMinutes': durationMinutes,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'source': source.name,
      if (avgHeartRate != null) 'avgHeartRate': avgHeartRate,
      if (steps != null) 'steps': steps,
      if (intensity != null) 'intensity': intensity,
      if (notes != null) 'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Convert to JSON-compatible map for SharedPreferences caching.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'caloriesBurned': caloriesBurned,
      if (distanceMeters != null) 'distanceMeters': distanceMeters,
      'durationMinutes': durationMinutes,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'source': source.name,
      if (avgHeartRate != null) 'avgHeartRate': avgHeartRate,
      if (steps != null) 'steps': steps,
      if (intensity != null) 'intensity': intensity,
      if (notes != null) 'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create from JSON map (SharedPreferences cache).
  factory ActivityRecord.fromJson(Map<String, dynamic> json) {
    return ActivityRecord(
      id: json['id'] as String? ?? '',
      type: ActivityType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? 'other'),
        orElse: () => ActivityType.other,
      ),
      caloriesBurned: (json['caloriesBurned'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      source: ActivitySource.values.firstWhere(
        (e) => e.name == (json['source'] as String? ?? 'manual'),
        orElse: () => ActivitySource.manual,
      ),
      avgHeartRate: (json['avgHeartRate'] as num?)?.toDouble(),
      steps: (json['steps'] as num?)?.toInt(),
      intensity: (json['intensity'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  ActivityRecord copyWith({
    String? id,
    ActivityType? type,
    double? caloriesBurned,
    double? distanceMeters,
    int? durationMinutes,
    DateTime? startTime,
    DateTime? endTime,
    ActivitySource? source,
    double? avgHeartRate,
    int? steps,
    double? intensity,
    String? notes,
    DateTime? createdAt,
  }) {
    return ActivityRecord(
      id: id ?? this.id,
      type: type ?? this.type,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      source: source ?? this.source,
      avgHeartRate: avgHeartRate ?? this.avgHeartRate,
      steps: steps ?? this.steps,
      intensity: intensity ?? this.intensity,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Estimate calories burned using MET formula.
  /// Formula: calories = MET x weightKg x durationHours
  static double estimateCalories({
    required ActivityType type,
    required int durationMinutes,
    required double weightKg,
    double intensity = 0.5, // 0.0 = low, 1.0 = peak
  }) {
    final range = type.metRange;
    final met = range[0] + (range[1] - range[0]) * intensity;
    final durationHours = durationMinutes / 60.0;
    return met * weightKg * durationHours;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    if (value is DateTime) return value;
    return DateTime.now();
  }

  @override
  String toString() =>
      'ActivityRecord(id: $id, type: ${type.name}, calories: $caloriesBurned, '
      'distance: $distanceMeters, duration: $durationMinutes, source: ${source.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityRecord &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
