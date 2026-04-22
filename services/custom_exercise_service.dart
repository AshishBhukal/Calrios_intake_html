import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firebase_exercise.dart';
import '../repositories/repository_provider.dart';
import '../services/exercise_cache_service.dart';
import '../utils/input_sanitizer.dart';
import '../utils/app_logger.dart';

/// Shared service for creating custom exercises.
/// Used by both the workout tracker and the routine creator to avoid
/// duplicate logic (validation, sanitization, Firebase save, cache update).
class CustomExerciseService {
  static final _exerciseRepo = RepositoryProvider().exerciseRepository;

  /// Creates a custom exercise, saves it to Firebase and the local cache,
  /// and returns the resulting [FirebaseExercise].
  ///
  /// Throws if the user is not logged in or the name is empty after sanitization.
  static Future<FirebaseExercise> createCustomExercise({
    required String name,
    required String description,
    required String category,
    required String muscle,
    required String equipment,
  }) async {
    final user = _exerciseRepo.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    // Sanitize user input
    final sanitizedName = InputSanitizer.sanitizeText(name, maxLength: 200);
    final sanitizedDescription = InputSanitizer.sanitizeNote(description);

    if (sanitizedName.isEmpty) {
      throw Exception('Exercise name cannot be empty');
    }

    // Generate a unique ID (timestamp + microsecond component)
    final customId =
        DateTime.now().millisecondsSinceEpoch +
        (DateTime.now().microsecond % 1000);

    final customExerciseData = <String, dynamic>{
      'id': customId,
      'name': sanitizedName,
      'description': sanitizedDescription,
      'category': category,
      'muscles': [muscle],
      'muscles_secondary': <String>[],
      'equipment': [equipment],
      'images': <String>[],
      'isCustom': true,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Save to Firebase
    final docId = await _exerciseRepo.addCustomExercise(customExerciseData);
    AppLogger.log('Custom exercise "$sanitizedName" saved with docId=$docId',
        tag: 'CustomExerciseService');

    // Update local cache
    customExerciseData['firestoreDocId'] = docId;
    await ExerciseCacheService.addCustomExerciseToCache(customExerciseData);

    // Return the model object
    return FirebaseExercise(
      id: customId.toString(),
      name: sanitizedName,
      description: sanitizedDescription,
      category: category,
      muscles: [muscle],
      musclesSecondary: [],
      equipment: [equipment],
      images: [],
    );
  }
}
