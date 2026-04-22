import 'workout_repository.dart';
import 'routine_repository.dart';
import 'exercise_repository.dart';

/// Singleton provider for repository instances.
/// Allows dependency injection for testing while providing easy access in production.
class RepositoryProvider {
  static final RepositoryProvider _instance = RepositoryProvider._internal();
  factory RepositoryProvider() => _instance;
  RepositoryProvider._internal();

  WorkoutRepository? _workoutRepository;
  RoutineRepository? _routineRepository;
  ExerciseRepository? _exerciseRepository;

  /// Get the workout repository instance
  WorkoutRepository get workoutRepository {
    _workoutRepository ??= WorkoutRepository();
    return _workoutRepository!;
  }

  /// Get the routine repository instance
  RoutineRepository get routineRepository {
    _routineRepository ??= RoutineRepository();
    return _routineRepository!;
  }

  /// Get the exercise repository instance
  ExerciseRepository get exerciseRepository {
    _exerciseRepository ??= ExerciseRepository();
    return _exerciseRepository!;
  }

  // Testing support - allows injecting mock repositories

  /// Set custom workout repository (for testing)
  void setWorkoutRepository(WorkoutRepository repo) {
    _workoutRepository = repo;
  }

  /// Set custom routine repository (for testing)
  void setRoutineRepository(RoutineRepository repo) {
    _routineRepository = repo;
  }

  /// Set custom exercise repository (for testing)
  void setExerciseRepository(ExerciseRepository repo) {
    _exerciseRepository = repo;
  }

  /// Reset all repositories to default (useful after tests)
  void reset() {
    _workoutRepository = null;
    _routineRepository = null;
    _exerciseRepository = null;
  }
}
