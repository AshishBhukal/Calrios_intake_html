import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Repository for routine-related Firebase operations.
/// Provides abstraction layer between UI and Firebase for better testability.
class RoutineRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  RoutineRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Get current authenticated user
  User? get currentUser => _auth.currentUser;

  /// Get all active routines for user
  Future<List<Map<String, dynamic>>> getRoutines(String userId) async {
    final querySnapshot = await _firestore
        .collection('routines')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['documentId'] = doc.id;
      return data;
    }).toList();
  }

  /// Get routine by ID
  Future<Map<String, dynamic>?> getRoutineById(String routineId) async {
    final doc = await _firestore.collection('routines').doc(routineId).get();
    return doc.exists ? doc.data() : null;
  }

  /// Create a new routine
  Future<String> createRoutine(Map<String, dynamic> data) async {
    final docRef = _firestore.collection('routines').doc();
    data['id'] = docRef.id;
    await docRef.set(data);
    return docRef.id;
  }

  /// Update existing routine
  Future<void> updateRoutine(String routineId, Map<String, dynamic> data) async {
    await _firestore.collection('routines').doc(routineId).update(data);
  }

  /// Soft delete routine (set isActive = false)
  Future<void> deleteRoutine(String routineId) async {
    await _firestore.collection('routines').doc(routineId).update({'isActive': false});
  }

  /// Check if user already has this routine (by originalRoutineId)
  Future<bool> routineExistsForUser(String userId, String originalRoutineId) async {
    final querySnapshot = await _firestore
        .collection('routines')
        .where('userId', isEqualTo: userId)
        .where('originalRoutineId', isEqualTo: originalRoutineId)
        .where('isActive', isEqualTo: true)
        .get();

    return querySnapshot.docs.isNotEmpty;
  }

  /// Download/copy routine from another user
  Future<String> downloadRoutine(String originalRoutineId, String userId) async {
    final originalDoc = await _firestore.collection('routines').doc(originalRoutineId).get();
    if (!originalDoc.exists) {
      throw Exception('Routine not found');
    }

    final newDocRef = _firestore.collection('routines').doc();
    final originalData = originalDoc.data()!;

    // Handle createdAt field conversion
    dynamic originalCreatedAt = originalData['routineData']?['createdAt'];
    String? createdAtString;
    if (originalCreatedAt is Timestamp) {
      createdAtString = originalCreatedAt.toDate().toIso8601String();
    } else if (originalCreatedAt is String) {
      createdAtString = originalCreatedAt;
    }

    await newDocRef.set({
      'userId': userId,
      'routineData': {
        'name': '${originalData['routineData']['name']} (Copy)',
        'type': originalData['routineData']['type'],
        'createdAt': createdAtString,
        'id': newDocRef.id,
      },
      'exercises': originalData['exercises'],
      'workoutId': newDocRef.id,
      'originalRoutineId': originalRoutineId,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return newDocRef.id;
  }
}
