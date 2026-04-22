import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Repository for exercise-related Firebase operations.
/// Handles custom exercise creation and queries.
class ExerciseRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ExerciseRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Get current authenticated user
  User? get currentUser => _auth.currentUser;

  /// Add a custom exercise
  Future<String> addCustomExercise(Map<String, dynamic> exerciseData) async {
    final docRef = await _firestore.collection('exercises').add(exerciseData);
    return docRef.id;
  }

  /// Get all exercises (optional: filter by userId for custom exercises)
  Future<List<Map<String, dynamic>>> getExercises({String? userId}) async {
    Query<Map<String, dynamic>> query = _firestore.collection('exercises');
    
    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }
    
    final querySnapshot = await query.get();
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['firestoreDocId'] = doc.id;
      return data;
    }).toList();
  }
}
