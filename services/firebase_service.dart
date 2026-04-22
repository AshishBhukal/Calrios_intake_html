import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // User document cache: reduces duplicate users/{uid} reads (plan: app_optimization_plan.txt)
  static final Map<String, _CachedUserDoc> _userDocCache = {};
  static const Duration _userDocCacheTTL = Duration(minutes: 5);

  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;

  /// Call after any write to users/{uid} so next getUserData() fetches fresh.
  static void invalidateUserDocumentCache() {
    final uid = _auth.currentUser?.uid;
    if (uid != null) _userDocCache.remove(uid);
  }

  /// Call on sign out so next user does not get stale cached data.
  static void clearUserDocumentCache() {
    _userDocCache.clear();
  }

  // Check if user is authenticated
  static bool get isAuthenticated => _auth.currentUser != null;

  // Food Log Operations
  static Future<void> saveFoodLogEntry(Map<String, dynamic> foodEntry) async {
    try {
      if (currentUserId == null) return;

      // Ensure timestamp is set to current time
      foodEntry['timestamp'] = Timestamp.now();

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('food_log')
          .add(foodEntry);
      
      debugPrint('Food log entry saved successfully');
    } catch (e) {
      debugPrint('Error saving food log entry: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getFoodLogEntries() async {
    try {
      if (currentUserId == null) return [];

      // Get today's date range (from midnight to end of day)
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      final snapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('food_log')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting food log entries: $e');
      return [];
    }
  }

  static Future<void> deleteFoodLogEntry(String entryId) async {
    try {
      if (currentUserId == null) return;

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('food_log')
          .doc(entryId)
          .delete();
      
      debugPrint('Food log entry deleted successfully');
    } catch (e) {
      debugPrint('Error deleting food log entry: $e');
      rethrow;
    }
  }

  // Check if it's a new day and reset data if needed
  static Future<bool> checkAndResetDailyData() async {
    try {
      if (currentUserId == null) return false;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Get the last reset date from user preferences
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      
      DateTime? lastResetDate;
      if (userDoc.exists) {
        final lastReset = userDoc.data()?['lastDailyReset'];
        if (lastReset != null) {
          if (lastReset is Timestamp) {
            lastResetDate = lastReset.toDate();
          } else if (lastReset is String) {
            lastResetDate = DateTime.parse(lastReset);
          }
        }
      }
      
      // If no last reset date or it's a different day, reset the data
      if (lastResetDate == null || !_isSameDay(lastResetDate, today)) {
        await _resetDailyData();
        
        // Update the last reset date
        await _firestore
            .collection('users')
            .doc(currentUserId)
            .set({
              'lastDailyReset': Timestamp.fromDate(today),
            }, SetOptions(merge: true));

        invalidateUserDocumentCache();
        debugPrint('Daily data reset completed for ${today.toString()}');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking/resetting daily data: $e');
      return false;
    }
  }

  // Helper method to check if two dates are the same day
  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  // Reset daily data (this is called automatically at midnight)
  static Future<void> _resetDailyData() async {
    try {
      if (currentUserId == null) return;

      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Reset daily totals for today
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('daily_totals')
          .doc(dateKey)
          .set({
            'date': dateKey,
            'calories': 0,
            'protein': 0.0,
            'carbs': 0.0,
            'fat': 0.0,
            'fiber': 0.0,
            'lastUpdated': Timestamp.now(),
          });

      // Reset water intake for today
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('water_intake')
          .doc(dateKey)
          .set({
            'date': dateKey,
            'waterIntake': 0.0,
            'waterGoal': 2000.0,
            'lastUpdated': Timestamp.now(),
          });

      debugPrint('Daily data reset completed');
    } catch (e) {
      debugPrint('Error resetting daily data: $e');
      rethrow;
    }
  }

  // Recipe Operations
  static Future<void> saveRecipe(Map<String, dynamic> recipe) async {
    try {
      if (currentUserId == null) return;

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('recipes')
          .doc(recipe['id'])
          .set(recipe);
      
      debugPrint('Recipe saved successfully');
    } catch (e) {
      debugPrint('Error saving recipe: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getRecipes() async {
    try {
      if (currentUserId == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('recipes')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting recipes: $e');
      return [];
    }
  }

  static Future<void> updateRecipe(String recipeId, Map<String, dynamic> recipe) async {
    try {
      if (currentUserId == null) return;

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('recipes')
          .doc(recipeId)
          .update(recipe);
      
      debugPrint('Recipe updated successfully');
    } catch (e) {
      debugPrint('Error updating recipe: $e');
      rethrow;
    }
  }

  static Future<void> deleteRecipe(String recipeId) async {
    try {
      if (currentUserId == null) return;

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('recipes')
          .doc(recipeId)
          .delete();
      
      debugPrint('Recipe deleted successfully');
    } catch (e) {
      debugPrint('Error deleting recipe: $e');
      rethrow;
    }
  }

  // Daily Totals Operations
  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan.txt ID f_5y6z7a
  static Future<void> saveDailyTotals(Map<String, dynamic> dailyTotals) async {
    try {
      if (currentUserId == null) return;

      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('daily_totals')
          .doc(dateKey)
          .set({
        ...dailyTotals,
        'date': dateKey,
        'timestamp': Timestamp.fromDate(today),
      });
      
      debugPrint('Daily totals saved successfully');
    } catch (e) {
      debugPrint('Error saving daily totals: $e');
      rethrow;
    }
  }

  static Future<void> saveMacroGoals(Map<String, dynamic> goals) async {
    try {
      if (currentUserId == null) return;

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .set({
        'goals': goals,
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));

      invalidateUserDocumentCache();
      debugPrint('Macro goals saved successfully');
    } catch (e) {
      debugPrint('Error saving macro goals: $e');
      rethrow;
    }
  }

  /// Save calorie behavior settings (roll-in and deduct calories out)
  static Future<void> saveCalorieBehaviorSettings({
    required bool caloriesRollIn,
    required bool deductCaloriesOut,
  }) async {
    try {
      if (currentUserId == null) return;

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .set({
        'caloriesRollIn': caloriesRollIn,
        'deductCaloriesOut': deductCaloriesOut,
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));

      invalidateUserDocumentCache();
      debugPrint('Calorie behavior settings saved successfully');
    } catch (e) {
      debugPrint('Error saving calorie behavior settings: $e');
      rethrow;
    }
  }

  /// Get yesterday's daily totals (for calories roll-in feature)
  static Future<Map<String, dynamic>?> getYesterdayDailyTotals() async {
    try {
      if (currentUserId == null) return null;

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final dateKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('daily_totals')
          .doc(dateKey)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting yesterday daily totals: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final uid = currentUserId;
      if (uid == null) return null;

      final cached = _userDocCache[uid];
      if (cached != null &&
          DateTime.now().difference(cached.cachedAt) < _userDocCacheTTL) {
        return cached.data;
      }

      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          _userDocCache[uid] = _CachedUserDoc(data: data, cachedAt: DateTime.now());
        }
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getDailyTotals() async {
    try {
      if (currentUserId == null) return null;

      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('daily_totals')
          .doc(dateKey)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting daily totals: $e');
      return null;
    }
  }

  // Water Intake Operations
  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan.txt ID f_6z7a8b
  static Future<void> saveWaterIntake(double waterIntake, double waterGoal) async {
    try {
      if (currentUserId == null) return;

      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('water_intake')
          .doc(dateKey)
          .set({
        'waterIntake': waterIntake,
        'waterGoal': waterGoal,
        'date': dateKey,
        'timestamp': Timestamp.fromDate(today),
      });
      
      debugPrint('Water intake saved successfully');
    } catch (e) {
      debugPrint('Error saving water intake: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getWaterIntake() async {
    try {
      if (currentUserId == null) return null;

      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('water_intake')
          .doc(dateKey)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting water intake: $e');
      return null;
    }
  }

  // Paginated Food Log Query
  static Future<Map<String, dynamic>> getFoodLogEntriesPaginated({
    required int limit,
    DocumentSnapshot? startAfterDocument,
  }) async {
    try {
      if (currentUserId == null) return {'entries': <Map<String, dynamic>>[], 'lastDocument': null};

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      Query query = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('food_log')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startAfterDocument != null) {
        query = query.startAfterDocument(startAfterDocument);
      }

      final snapshot = await query.get();

      final entries = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      return {
        'entries': entries,
        'lastDocument': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      };
    } catch (e) {
      debugPrint('Error getting paginated food log entries: $e');
      return {'entries': <Map<String, dynamic>>[], 'lastDocument': null};
    }
  }

  // Water Intake Options Persistence
  static Future<void> saveWaterIntakeOptions(List<Map<String, dynamic>> options) async {
    try {
      if (currentUserId == null) return;

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('settings')
          .doc('water_options')
          .set({
        'options': options,
        'lastUpdated': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error saving water intake options: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getWaterIntakeOptions() async {
    try {
      if (currentUserId == null) return [];

      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('settings')
          .doc('water_options')
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['options'] != null) {
          return List<Map<String, dynamic>>.from(
            (data['options'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting water intake options: $e');
      return [];
    }
  }

  // User Settings Operations
  static Future<void> saveUserSettings(Map<String, dynamic> settings) async {
    try {
      if (currentUserId == null) return;

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('settings')
          .doc('user_preferences')
          .set(settings);
      
      debugPrint('User settings saved successfully');
    } catch (e) {
      debugPrint('Error saving user settings: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getUserSettings() async {
    try {
      if (currentUserId == null) return null;

      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('settings')
          .doc('user_preferences')
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user settings: $e');
      return null;
    }
  }

  // Batch operations for better performance
  static Future<void> saveMultipleFoodEntries(List<Map<String, dynamic>> entries) async {
    try {
      if (currentUserId == null) return;

      final batch = _firestore.batch();
      
      for (final entry in entries) {
        final docRef = _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('food_log')
            .doc();
        
        batch.set(docRef, entry);
      }
      
      await batch.commit();
      debugPrint('Multiple food entries saved successfully');
    } catch (e) {
      debugPrint('Error saving multiple food entries: $e');
      rethrow;
    }
  }

  // ============================================================================
  // ACTIVITY OPERATIONS (Calories Out / Watch Integration)
  // ============================================================================

  /// Save an activity record to Firestore.
  static Future<void> saveActivity(Map<String, dynamic> activity) async {
    try {
      if (currentUserId == null) return;

      final docId = activity['id'] as String? ?? '';
      if (docId.isEmpty) return;

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('activities')
          .doc(docId)
          .set(activity);

      debugPrint('Activity saved successfully');
    } catch (e) {
      debugPrint('Error saving activity: $e');
      rethrow;
    }
  }

  /// Save multiple activities in a single batch (for watch sync).
  static Future<void> saveActivitiesBatch(List<Map<String, dynamic>> activities) async {
    try {
      if (currentUserId == null) return;

      final batch = _firestore.batch();
      for (final activity in activities) {
        final docId = activity['id'] as String?;
        if (docId == null || docId.isEmpty) continue;

        final docRef = _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('activities')
            .doc(docId);
        batch.set(docRef, activity);
      }
      await batch.commit();
      debugPrint('Batch saved ${activities.length} activities');
    } catch (e) {
      debugPrint('Error saving activities batch: $e');
      rethrow;
    }
  }

  /// Get activities within a date range, ordered by startTime descending.
  static Future<List<Map<String, dynamic>>> getActivities({
    int limit = 50,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      if (currentUserId == null) return [];

      Query query = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('activities')
          .orderBy('startTime', descending: true);

      if (from != null) {
        query = query.where('startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(from));
      }
      if (to != null) {
        query = query.where('startTime',
            isLessThanOrEqualTo: Timestamp.fromDate(to));
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting activities: $e');
      return [];
    }
  }

  /// Delete an activity by ID.
  static Future<void> deleteActivity(String activityId) async {
    try {
      if (currentUserId == null) return;

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('activities')
          .doc(activityId)
          .delete();

      debugPrint('Activity deleted successfully');
    } catch (e) {
      debugPrint('Error deleting activity: $e');
      rethrow;
    }
  }

  /// Get all activity IDs within a date range (for deduplication during sync).
  static Future<Set<String>> getActivityIds({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      if (currentUserId == null) return {};

      final snapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('activities')
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(to))
          .get();

      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      debugPrint('Error getting activity IDs: $e');
      return {};
    }
  }

  // Real-time listeners
  static Stream<List<Map<String, dynamic>>> getFoodLogStream() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('food_log')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  static Stream<List<Map<String, dynamic>>> getRecipesStream() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('recipes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }
}

class _CachedUserDoc {
  final Map<String, dynamic> data;
  final DateTime cachedAt;
  _CachedUserDoc({required this.data, required this.cachedAt});
}
