/// Shared workout exercise and set models used by tracker and routine screens.
class Exercise {
  final String name;
  final String muscle;
  final String icon;
  final String? exerciseId;
  List<ExerciseSet> sets;
  String notes;
  bool completed;
  bool started;
  int? supersetId;

  Exercise({
    required this.name,
    required this.muscle,
    required this.icon,
    this.exerciseId,
    List<ExerciseSet>? sets,
    this.notes = '',
    this.completed = false,
    this.started = false,
    this.supersetId,
  }) : sets = sets ?? [];
}

class ExerciseSet {
  double weight;
  int reps;
  String previous;
  String setType; // 'normal', 'warmup', 'failure', 'dropset'

  ExerciseSet({
    this.weight = 0,
    this.reps = 0,
    this.previous = '',
    this.setType = 'normal',
  });
}
