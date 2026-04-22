import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_exercise.dart';
import '../models/exercise_timer.dart';
import '../utils/app_logger.dart';

class WorkoutStateService {
  static const String _workoutStateKey = 'incomplete_workout_state';
  static const String _workoutStartTimeKey = 'workout_start_time';
  static const String _workoutIdKey = 'workout_id';

  /// Save the current workout state to local storage
  static Future<void> saveWorkoutState({
    required List<Exercise> exercises,
    required DateTime workoutStartTime,
    required Map<int, ExerciseTimer> exerciseTimers,
    required String? workoutId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert exercises to JSON
      final exercisesJson = exercises.map((exercise) => {
        'name': exercise.name,
        'muscle': exercise.muscle,
        'icon': exercise.icon,
        'exerciseId': exercise.exerciseId,
        'notes': exercise.notes,
        'completed': exercise.completed,
        'started': exercise.started,
        'supersetId': exercise.supersetId,
        'sets': exercise.sets.map((set) => {
          'weight': set.weight,
          'reps': set.reps,
          'previous': set.previous,
          'setType': set.setType,
        }).toList(),
      }).toList();

      // Convert exercise timers to JSON
      final timersJson = <String, Map<String, dynamic>>{};
      exerciseTimers.forEach((key, timer) {
        timersJson[key.toString()] = {
          'normalTime': timer.normalTime,
          'restTime': timer.restTime,
          'pauseTime': timer.pauseTime,
          'currentMode': timer.currentMode,
          'normalStartTime': timer.normalStartTime?.millisecondsSinceEpoch,
          'restStartTime': timer.restStartTime?.millisecondsSinceEpoch,
          'pauseStartTime': timer.pauseStartTime?.millisecondsSinceEpoch,
        };
      });

      final workoutState = {
        'exercises': exercisesJson,
        'exerciseTimers': timersJson,
        'workoutStartTime': workoutStartTime.millisecondsSinceEpoch,
        'workoutId': workoutId,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString(_workoutStateKey, jsonEncode(workoutState));
      await prefs.setInt(_workoutStartTimeKey, workoutStartTime.millisecondsSinceEpoch);
      if (workoutId != null) {
        await prefs.setString(_workoutIdKey, workoutId);
      }
      
      AppLogger.log('Workout state saved successfully', tag: 'WorkoutStateService');
    } catch (e) {
      AppLogger.error('Saving workout state', error: e, tag: 'WorkoutStateService');
    }
  }

  /// Load the saved workout state from local storage
  static Future<WorkoutState?> loadWorkoutState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final workoutStateJson = prefs.getString(_workoutStateKey);
      
      if (workoutStateJson == null) {
        return null;
      }

      final workoutState = jsonDecode(workoutStateJson) as Map<String, dynamic>;
      
      // Convert exercises from JSON
      final exercisesJson = workoutState['exercises'] as List<dynamic>;
      final exercises = exercisesJson.map((exerciseJson) {
        final exercise = exerciseJson as Map<String, dynamic>;
        final setsJson = exercise['sets'] as List<dynamic>;
        final sets = setsJson.map((setJson) {
          final set = setJson as Map<String, dynamic>;
          return ExerciseSet(
            weight: (set['weight'] as num).toDouble(),
            reps: set['reps'] as int,
            previous: set['previous'] as String,
            setType: set['setType'] as String,
          );
        }).toList();

        return Exercise(
          name: exercise['name'] as String,
          muscle: exercise['muscle'] as String,
          icon: exercise['icon'] as String,
          exerciseId: exercise['exerciseId']?.toString(),
          notes: exercise['notes'] as String,
          completed: exercise['completed'] as bool,
          started: exercise['started'] as bool,
          supersetId: exercise['supersetId'] as int?,
          sets: sets,
        );
      }).toList();

      // Convert exercise timers from JSON
      final timersJson = workoutState['exerciseTimers'] as Map<String, dynamic>;
      final exerciseTimers = <int, ExerciseTimer>{};
      timersJson.forEach((key, timerJson) {
        final timer = timerJson as Map<String, dynamic>;
        final exerciseTimer = ExerciseTimer();
        exerciseTimer.normalTime = timer['normalTime'] as int;
        exerciseTimer.restTime = timer['restTime'] as int;
        exerciseTimer.pauseTime = timer['pauseTime'] as int;
        exerciseTimer.currentMode = timer['currentMode'] as String;
        
        if (timer['normalStartTime'] != null) {
          exerciseTimer.normalStartTime = DateTime.fromMillisecondsSinceEpoch(timer['normalStartTime'] as int);
        }
        if (timer['restStartTime'] != null) {
          exerciseTimer.restStartTime = DateTime.fromMillisecondsSinceEpoch(timer['restStartTime'] as int);
        }
        if (timer['pauseStartTime'] != null) {
          exerciseTimer.pauseStartTime = DateTime.fromMillisecondsSinceEpoch(timer['pauseStartTime'] as int);
        }
        
        exerciseTimers[int.parse(key)] = exerciseTimer;
      });

      final workoutStartTime = DateTime.fromMillisecondsSinceEpoch(workoutState['workoutStartTime'] as int);
      final workoutId = workoutState['workoutId'] as String?;

      return WorkoutState(
        exercises: exercises,
        exerciseTimers: exerciseTimers,
        workoutStartTime: workoutStartTime,
        workoutId: workoutId,
      );
    } catch (e) {
      AppLogger.error('Loading workout state', error: e, tag: 'WorkoutStateService');
      return null;
    }
  }

  /// Check if there's an incomplete workout saved
  static Future<bool> hasIncompleteWorkout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_workoutStateKey);
    } catch (e) {
      AppLogger.error('Checking for incomplete workout', error: e, tag: 'WorkoutStateService');
      return false;
    }
  }

  /// Clear the saved workout state
  static Future<void> clearWorkoutState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_workoutStateKey);
      await prefs.remove(_workoutStartTimeKey);
      await prefs.remove(_workoutIdKey);
      AppLogger.log('Workout state cleared successfully', tag: 'WorkoutStateService');
    } catch (e) {
      AppLogger.error('Clearing workout state', error: e, tag: 'WorkoutStateService');
    }
  }

  /// Get the saved workout start time
  static Future<DateTime?> getSavedWorkoutStartTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_workoutStartTimeKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      AppLogger.error('Getting saved workout start time', error: e, tag: 'WorkoutStateService');
      return null;
    }
  }

  /// Get the saved workout ID
  static Future<String?> getSavedWorkoutId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_workoutIdKey);
    } catch (e) {
      AppLogger.error('Getting saved workout ID', error: e, tag: 'WorkoutStateService');
      return null;
    }
  }
}

class WorkoutState {
  final List<Exercise> exercises;
  final Map<int, ExerciseTimer> exerciseTimers;
  final DateTime workoutStartTime;
  final String? workoutId;

  WorkoutState({
    required this.exercises,
    required this.exerciseTimers,
    required this.workoutStartTime,
    this.workoutId,
  });
}