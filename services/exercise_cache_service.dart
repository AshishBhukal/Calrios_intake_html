import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for caching exercise list to reduce Firebase reads and improve performance
/// Handles both standard exercises and custom user-created exercises
class ExerciseCacheService {
  // Cache keys
  static const String _exercisesKey = 'exercises_cache';
  static const String _lastUpdateKey = 'exercises_last_update';
  
  // Cache expiry duration (24 hours - exercises don't change often)
  static const Duration _cacheExpiry = Duration(hours: 24);
  
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // In-memory cache to avoid repeated SharedPreferences reads + JSON decode
  // within the same app session. Cleared on invalidate/clear.
  static List<Map<String, dynamic>>? _memoryCache;
  static String? _memoryCacheUid;

  // ============================================================================
  // EXERCISE LIST CACHING
  // ============================================================================

  /// Get cached exercise list
  /// Returns list of exercise data as maps
  static Future<List<Map<String, dynamic>>?> getCachedExercises() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return null;

      final cacheKey = '${_exercisesKey}_${user.uid}';
      final cachedData = prefs.getString(cacheKey);
      
      if (cachedData == null) return null;

      // Check if cache is still valid
      if (!await _isExerciseCacheValid()) {
        return null;
      }
      
      final List<dynamic> decoded = json.decode(cachedData);
      return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      print('Error loading cached exercises: $e');
      return null;
    }
  }

  /// Save exercise list to cache
  /// Includes both standard and custom exercises
  static Future<void> saveCachedExercises(List<Map<String, dynamic>> exercises) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return;

      final cacheKey = '${_exercisesKey}_${user.uid}';
      final lastUpdateKey = '${_lastUpdateKey}_${user.uid}';
      
      await prefs.setString(cacheKey, json.encode(exercises));
      await prefs.setString(lastUpdateKey, DateTime.now().toIso8601String());

      // Update in-memory cache
      _memoryCache = exercises;
      _memoryCacheUid = user.uid;
    } catch (e) {
      print('Error saving cached exercises: $e');
    }
  }

  /// Check if exercise cache is still valid
  static Future<bool> _isExerciseCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return false;

      final lastUpdateKey = '${_lastUpdateKey}_${user.uid}';
      final lastUpdateString = prefs.getString(lastUpdateKey);
      
      if (lastUpdateString == null) return false;
      
      final lastUpdate = DateTime.parse(lastUpdateString);
      final now = DateTime.now();
      
      // Cache is valid if it's less than 24 hours old
      return now.difference(lastUpdate) < _cacheExpiry;
    } catch (e) {
      print('Error checking exercise cache validity: $e');
      return false;
    }
  }

  /// Invalidate exercise cache (call when new custom exercise is created)
  static Future<void> invalidateExerciseCache() async {
    // Clear in-memory cache immediately
    _memoryCache = null;
    _memoryCacheUid = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return;

      final cacheKey = '${_exercisesKey}_${user.uid}';
      final lastUpdateKey = '${_lastUpdateKey}_${user.uid}';
      
      await prefs.remove(cacheKey);
      await prefs.remove(lastUpdateKey);
    } catch (e) {
      print('Error invalidating exercise cache: $e');
    }
  }

  /// Fetch exercises from Firebase and cache them
  /// Includes both standard exercises and user's custom exercises
  static Future<List<Map<String, dynamic>>> fetchAndCacheExercises() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      print('🔄 Fetching exercises from Firebase...');
      
      // Fetch all exercises from Firebase
      final querySnapshot = await _firestore
          .collection('exercises')
          .get();

      final List<Map<String, dynamic>> exercises = [];
      
      for (var doc in querySnapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = int.tryParse(doc.id) ?? 0;
        data['firestoreDocId'] = doc.id; // Store Firestore document ID
        
        // Convert Firestore Timestamp objects to ISO8601 strings for JSON serialization
        data.forEach((key, value) {
          if (value is Timestamp) {
            data[key] = value.toDate().toIso8601String();
          }
        });
        
        // Include all exercises (standard + custom)
        // Custom exercises have 'isCustom' = true and 'createdBy' = userId
        exercises.add(data);
      }

      // Cache the exercises
      await saveCachedExercises(exercises);
      
      print('✅ Fetched and cached ${exercises.length} exercises');
      
      return exercises;
    } catch (e) {
      print('Error fetching exercises from Firebase: $e');
      rethrow;
    }
  }

  /// Get exercises (from memory → SharedPrefs → Firebase, in that order)
  static Future<List<Map<String, dynamic>>> getExercises() async {
    try {
      final user = _auth.currentUser;
      final uid = user?.uid;

      // 1. Check in-memory cache first (instant, no I/O)
      if (_memoryCache != null && _memoryCacheUid == uid && uid != null) {
        return _memoryCache!;
      }

      // 2. Try SharedPreferences disk cache
      final cachedExercises = await getCachedExercises();
      if (cachedExercises != null) {
        // Promote to memory cache for future calls
        _memoryCache = cachedExercises;
        _memoryCacheUid = uid;
        return cachedExercises;
      }
      
      // 3. Cache miss or expired - fetch from Firebase
      return await fetchAndCacheExercises();
    } catch (e) {
      print('Error getting exercises: $e');
      return [];
    }
  }

  /// Filter exercises to only include user's custom exercises
  static List<Map<String, dynamic>> filterCustomExercises(
    List<Map<String, dynamic>> exercises,
    String userId,
  ) {
    return exercises.where((exercise) {
      return exercise['isCustom'] == true && exercise['createdBy'] == userId;
    }).toList();
  }

  /// Filter exercises to only include standard exercises
  static List<Map<String, dynamic>> filterStandardExercises(
    List<Map<String, dynamic>> exercises,
  ) {
    return exercises.where((exercise) {
      return exercise['isCustom'] != true;
    }).toList();
  }

  /// Clear exercise cache (useful when user signs out)
  static Future<void> clearCache() async {
    // Clear in-memory cache immediately
    _memoryCache = null;
    _memoryCacheUid = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return;

      final cacheKey = '${_exercisesKey}_${user.uid}';
      final lastUpdateKey = '${_lastUpdateKey}_${user.uid}';
      
      await prefs.remove(cacheKey);
      await prefs.remove(lastUpdateKey);
    } catch (e) {
      print('Error clearing exercise cache: $e');
    }
  }

  /// Get cache status for debugging
  static Future<Map<String, dynamic>> getCacheStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'user': 'Not logged in',
          'exerciseCache': 'N/A',
        };
      }

      final lastUpdate = prefs.getString('${_lastUpdateKey}_${user.uid}');
      final cachedData = prefs.getString('${_exercisesKey}_${user.uid}');
      
      int exerciseCount = 0;
      if (cachedData != null) {
        final List<dynamic> decoded = json.decode(cachedData);
        exerciseCount = decoded.length;
      }
      
      return {
        'userId': user.uid,
        'exerciseCache': {
          'exists': prefs.containsKey('${_exercisesKey}_${user.uid}'),
          'lastUpdate': lastUpdate,
          'valid': await _isExerciseCacheValid(),
          'exerciseCount': exerciseCount,
        },
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Add a custom exercise to cache without full refetch
  /// This is an optimization to avoid refetching all exercises
  static Future<void> addCustomExerciseToCache(Map<String, dynamic> exercise) async {
    try {
      final cachedExercises = await getCachedExercises();
      
      if (cachedExercises != null) {
        // Add new exercise to cached list
        cachedExercises.add(exercise);
        await saveCachedExercises(cachedExercises);
        print('✅ Added custom exercise to cache');
      } else {
        // No cache exists, just invalidate so next fetch gets it
        await invalidateExerciseCache();
      }
    } catch (e) {
      print('Error adding custom exercise to cache: $e');
      // If something goes wrong, just invalidate cache
      await invalidateExerciseCache();
    }
  }
}

