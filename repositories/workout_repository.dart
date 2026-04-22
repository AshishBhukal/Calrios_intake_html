import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Repository for workout-related Firebase operations.
/// Provides abstraction layer between UI and Firebase for better testability.
/// OPTIMIZED: In-memory cache for getWorkoutsForMonth (plan: app_optimization_plan.txt)
class WorkoutRepository {
  static const Duration _monthCacheTTL = Duration(minutes: 2);
  static final Map<String, _MonthWorkoutsEntry> _monthCache = {};

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  WorkoutRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Get current authenticated user
  User? get currentUser => _auth.currentUser;

  static String _monthCacheKey(String userId, DateTime firstDay) {
    return '${userId}_${firstDay.year}_${firstDay.month}';
  }

  static void _invalidateMonthCacheForUser(String userId) {
    _monthCache.removeWhere((key, _) => key.startsWith('${userId}_'));
  }

  /// Get workouts for a specific month (used by tracker_tab calendar)
  /// Uses short-lived in-memory cache to avoid repeated Firestore reads
  Future<List<Map<String, dynamic>>> getWorkoutsForMonth(
    String userId,
    DateTime firstDay,
    DateTime lastDay,
  ) async {
    final key = _monthCacheKey(userId, firstDay);
    final cached = _monthCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.cachedAt) < _monthCacheTTL) {
      return cached.workouts;
    }

    final querySnapshot = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: userId)
        .where('workoutStartTime', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
        .where('workoutStartTime', isLessThanOrEqualTo: Timestamp.fromDate(lastDay))
        .orderBy('workoutStartTime', descending: true)
        .get();

    final workouts = querySnapshot.docs.map((doc) => doc.data()).toList();
    _monthCache[key] = _MonthWorkoutsEntry(workouts: workouts, cachedAt: DateTime.now());
    return workouts;
  }

  /// Save a new workout document
  Future<DocumentReference> saveWorkout(Map<String, dynamic> data) async {
    final ref = await _firestore.collection('workouts').add(data);
    final uid = _auth.currentUser?.uid;
    if (uid != null) _invalidateMonthCacheForUser(uid);
    return ref;
  }

  /// Get workout by ID
  Future<Map<String, dynamic>?> getWorkoutById(String workoutId) async {
    final doc = await _firestore.collection('workouts').doc(workoutId).get();
    return doc.exists ? doc.data() : null;
  }

  /// Create workout with specific ID
  Future<void> createWorkoutWithId(String workoutId, Map<String, dynamic> data) async {
    await _firestore.collection('workouts').doc(workoutId).set(data);
    final uid = _auth.currentUser?.uid;
    if (uid != null) _invalidateMonthCacheForUser(uid);
  }

  /// Update existing workout
  Future<void> updateWorkout(String workoutId, Map<String, dynamic> data) async {
    await _firestore.collection('workouts').doc(workoutId).update(data);
    final uid = _auth.currentUser?.uid;
    if (uid != null) _invalidateMonthCacheForUser(uid);
  }

  /// Get recent workouts for an exercise (for "previous" column in progress.dart)
  Future<List<Map<String, dynamic>>> getRecentWorkouts(
    String userId, {
    int limit = 10,
  }) async {
    final querySnapshot = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return querySnapshot.docs.map((doc) => doc.data()).toList();
  }
}

class _MonthWorkoutsEntry {
  final List<Map<String, dynamic>> workouts;
  final DateTime cachedAt;
  _MonthWorkoutsEntry({required this.workouts, required this.cachedAt});
}
