import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for caching graph data to reduce Firebase reads and improve performance
class GraphCacheService {
  // Cache keys
  static const String _caloriesDataKey = 'calories_graph_data';
  static const String _caloriesGoalKey = 'calories_goal';
  static const String _caloriesLastUpdateKey = 'calories_graph_last_update';
  
  static const String _exerciseDataKey = 'exercise_graph_data';
  static const String _exerciseLastUpdateKey = 'exercise_graph_last_update';
  
  // Cache expiry duration (1 hour)
  static const Duration _cacheExpiry = Duration(hours: 1);
  
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================================
  // CALORIES GRAPH CACHING
  // ============================================================================

  /// Get cached calories graph data
  static Future<Map<String, dynamic>?> getCachedCaloriesData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return null;

      final cacheKey = '${_caloriesDataKey}_${user.uid}';
      final cachedData = prefs.getString(cacheKey);
      
      if (cachedData == null) return null;

      // Check if cache is still valid
      if (!await _isCaloriesCacheValid()) {
        return null;
      }
      
      return json.decode(cachedData) as Map<String, dynamic>;
    } catch (e) {
      print('Error loading cached calories data: $e');
      return null;
    }
  }

  /// Save calories graph data to cache
  /// Data format: { 'data': [...], 'goal': 2000.0 }
  static Future<void> saveCachedCaloriesData(List<Map<String, dynamic>> data, double goal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return;

      final cacheKey = '${_caloriesDataKey}_${user.uid}';
      final goalKey = '${_caloriesGoalKey}_${user.uid}';
      final lastUpdateKey = '${_caloriesLastUpdateKey}_${user.uid}';
      
      final cacheData = {
        'data': data,
        'goal': goal,
      };
      
      await prefs.setString(cacheKey, json.encode(cacheData));
      await prefs.setDouble(goalKey, goal);
      await prefs.setString(lastUpdateKey, DateTime.now().toIso8601String());
      
      print('✅ Calories graph data cached successfully');
    } catch (e) {
      print('Error saving cached calories data: $e');
    }
  }

  /// Check if calories cache is still valid
  static Future<bool> _isCaloriesCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return false;

      final lastUpdateKey = '${_caloriesLastUpdateKey}_${user.uid}';
      final lastUpdateString = prefs.getString(lastUpdateKey);
      
      if (lastUpdateString == null) return false;
      
      final lastUpdate = DateTime.parse(lastUpdateString);
      final now = DateTime.now();
      
      // Cache is valid if it's less than 1 hour old
      return now.difference(lastUpdate) < _cacheExpiry;
    } catch (e) {
      print('Error checking calories cache validity: $e');
      return false;
    }
  }

  /// Invalidate calories cache (call when new food is logged)
  static Future<void> invalidateCaloriesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return;

      final cacheKey = '${_caloriesDataKey}_${user.uid}';
      final lastUpdateKey = '${_caloriesLastUpdateKey}_${user.uid}';
      
      await prefs.remove(cacheKey);
      await prefs.remove(lastUpdateKey);
      
      print('✅ Calories cache invalidated');
    } catch (e) {
      print('Error invalidating calories cache: $e');
    }
  }

  // ============================================================================
  // EXERCISE GRAPH CACHING
  // ============================================================================

  /// Get cached exercise graph data
  static Future<Map<String, List<Map<String, dynamic>>>?> getCachedExerciseData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return null;

      final cacheKey = '${_exerciseDataKey}_${user.uid}';
      final cachedData = prefs.getString(cacheKey);
      
      if (cachedData == null) return null;

      // Check if cache is still valid
      if (!await _isExerciseCacheValid()) {
        return null;
      }
      
      final Map<String, dynamic> decoded = json.decode(cachedData);
      final Map<String, List<Map<String, dynamic>>> result = {};
      
      decoded.forEach((key, value) {
        result[key] = List<Map<String, dynamic>>.from(
          (value as List).map((item) => Map<String, dynamic>.from(item))
        );
      });
      
      return result;
    } catch (e) {
      print('Error loading cached exercise data: $e');
      return null;
    }
  }

  /// Save exercise graph data to cache
  /// Data format: { 'ExerciseName': [{ 'date': '2025-01-01', 'oneRepMax': 100.0 }] }
  static Future<void> saveCachedExerciseData(Map<String, List<Map<String, dynamic>>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return;

      final cacheKey = '${_exerciseDataKey}_${user.uid}';
      final lastUpdateKey = '${_exerciseLastUpdateKey}_${user.uid}';
      
      await prefs.setString(cacheKey, json.encode(data));
      await prefs.setString(lastUpdateKey, DateTime.now().toIso8601String());
      
      print('✅ Exercise graph data cached successfully');
    } catch (e) {
      print('Error saving cached exercise data: $e');
    }
  }

  /// Check if exercise cache is still valid
  static Future<bool> _isExerciseCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return false;

      final lastUpdateKey = '${_exerciseLastUpdateKey}_${user.uid}';
      final lastUpdateString = prefs.getString(lastUpdateKey);
      
      if (lastUpdateString == null) return false;
      
      final lastUpdate = DateTime.parse(lastUpdateString);
      final now = DateTime.now();
      
      // Cache is valid if it's less than 1 hour old
      return now.difference(lastUpdate) < _cacheExpiry;
    } catch (e) {
      print('Error checking exercise cache validity: $e');
      return false;
    }
  }

  /// Invalidate exercise cache (call when new workout is saved)
  static Future<void> invalidateExerciseCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return;

      final cacheKey = '${_exerciseDataKey}_${user.uid}';
      final lastUpdateKey = '${_exerciseLastUpdateKey}_${user.uid}';
      
      await prefs.remove(cacheKey);
      await prefs.remove(lastUpdateKey);
      
      print('✅ Exercise cache invalidated');
    } catch (e) {
      print('Error invalidating exercise cache: $e');
    }
  }

  // ============================================================================
  // GENERAL CACHE MANAGEMENT
  // ============================================================================

  /// Clear all graph caches (useful for testing or when user signs out)
  static Future<void> clearAllCaches() async {
    await invalidateCaloriesCache();
    await invalidateExerciseCache();
    print('✅ All graph caches cleared');
  }

  /// Get cache status for debugging
  static Future<Map<String, dynamic>> getCacheStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'user': 'Not logged in',
          'caloriesCache': 'N/A',
          'exerciseCache': 'N/A',
        };
      }

      final caloriesLastUpdate = prefs.getString('${_caloriesLastUpdateKey}_${user.uid}');
      final exerciseLastUpdate = prefs.getString('${_exerciseLastUpdateKey}_${user.uid}');
      
      return {
        'userId': user.uid,
        'caloriesCache': {
          'exists': prefs.containsKey('${_caloriesDataKey}_${user.uid}'),
          'lastUpdate': caloriesLastUpdate,
          'valid': await _isCaloriesCacheValid(),
        },
        'exerciseCache': {
          'exists': prefs.containsKey('${_exerciseDataKey}_${user.uid}'),
          'lastUpdate': exerciseLastUpdate,
          'valid': await _isExerciseCacheValid(),
        },
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}

