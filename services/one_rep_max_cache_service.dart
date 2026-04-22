import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OneRepMaxCacheService {
  static const String _cacheKey = 'one_rep_max_cache';
  static const String _lastUpdateKey = 'one_rep_max_last_update';
  
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get cached one rep max data
  static Future<Map<String, Map<String, double>>> getCachedOneRepMax() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return {};

      final cacheKey = '${_cacheKey}_${user.uid}';
      final cachedData = prefs.getString(cacheKey);
      
      if (cachedData != null) {
        final Map<String, dynamic> decoded = json.decode(cachedData);
        final Map<String, Map<String, double>> result = {};
        
        decoded.forEach((date, exercises) {
          result[date] = Map<String, double>.from(exercises);
        });
        
        return result;
      }
    } catch (e) {
      print('Error loading cached one rep max: $e');
    }
    
    return {};
  }

  /// Save one rep max data to cache
  static Future<void> saveCachedOneRepMax(Map<String, Map<String, double>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return;

      final cacheKey = '${_cacheKey}_${user.uid}';
      final jsonString = json.encode(data);
      
      await prefs.setString(cacheKey, jsonString);
      await prefs.setString('${_lastUpdateKey}_${user.uid}', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error saving cached one rep max: $e');
    }
  }

  /// Check if cache needs update by comparing with latest workout
  static Future<bool> needsCacheUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return true;

      final lastUpdateKey = '${_lastUpdateKey}_${user.uid}';
      final lastUpdateString = prefs.getString(lastUpdateKey);
      
      if (lastUpdateString == null) return true;
      
      final lastUpdate = DateTime.parse(lastUpdateString);
      
      // Get the latest workout timestamp from Firebase
      final latestWorkout = await _firestore
          .collection('workouts')
          .where('userId', isEqualTo: user.uid)
          .orderBy('workoutStartTime', descending: true)
          .limit(1)
          .get();
      
      if (latestWorkout.docs.isEmpty) return false;
      
      final latestWorkoutTime = (latestWorkout.docs.first.data()['workoutStartTime'] as Timestamp).toDate();
      
      // If latest workout is newer than last cache update, we need to update
      return latestWorkoutTime.isAfter(lastUpdate);
    } catch (e) {
      print('Error checking cache update: $e');
      return true;
    }
  }

  /// Calculate one rep max for a specific workout and update cache
  static Future<Map<String, Map<String, double>>> calculateAndUpdateOneRepMax(
    Map<String, List<Map<String, dynamic>>> workoutData
  ) async {
    // Load existing cached data to preserve historical data
    final Map<String, Map<String, double>> existingCache = await getCachedOneRepMax();
    
    // Process new workout data
    for (var dateEntry in workoutData.entries) {
      final date = dateEntry.key;
      final workouts = dateEntry.value;
      
      // Initialize date entry if it doesn't exist
      if (!existingCache.containsKey(date)) {
        existingCache[date] = {};
      }
      
      for (var workout in workouts) {
        final exercises = workout['exercises'] as List<dynamic>? ?? [];
        
        for (var exercise in exercises) {
          final exerciseName = exercise['name'] as String? ?? '';
          final sets = exercise['sets'] as List<dynamic>? ?? [];
          
          // Track the highest estimated 1-rep max for this exercise
          double highestEstimatedMax = 0.0;
          
          for (var set in sets) {
            // Get weight in kg (standard unit) from Firebase
            final weightInKg = (set['weight'] ?? 0.0).toDouble();
            final reps = set['reps'] as int? ?? 0;
            
            // Only calculate for sets with meaningful weight and reps
            if (weightInKg > 0 && reps > 0 && reps <= 10) {
              // Use Brzycki formula: 1RM = weight / (1.0278 - 0.0278 × reps)
              double estimatedMaxInKg = weightInKg / (1.0278 - 0.0278 * reps);
              
              if (estimatedMaxInKg > highestEstimatedMax) {
                highestEstimatedMax = estimatedMaxInKg;
              }
            }
          }
          
          // If we found a meaningful estimated max, record it
          if (highestEstimatedMax > 0) {
            // Only keep the highest 1RM for each exercise per day
            // This prevents multiple entries for the same exercise on the same day
            if (!existingCache[date]!.containsKey(exerciseName) || 
                existingCache[date]![exerciseName]! < highestEstimatedMax) {
              existingCache[date]![exerciseName] = highestEstimatedMax;
            }
          }
        }
      }
    }
    
    // Save updated cache (preserves all historical data)
    await saveCachedOneRepMax(existingCache);
    
    return existingCache;
  }

  /// Get one rep max data (from cache or calculate if needed)
  static Future<Map<String, Map<String, double>>> getOneRepMaxData(
    Map<String, List<Map<String, dynamic>>> workoutData
  ) async {
    // Check if cache needs update
    final needsUpdate = await needsCacheUpdate();
    
    if (needsUpdate) {
      // Calculate and update cache (preserves historical data)
      return await calculateAndUpdateOneRepMax(workoutData);
    } else {
      // Return cached data (includes all historical data)
      return await getCachedOneRepMax();
    }
  }

  /// Filter to only include personal records (new all-time highs per exercise).
  /// A 1RM entry is only a "PR" if it exceeds every previous estimated max
  /// for that exercise across all earlier dates.
  static Map<String, Map<String, double>> filterForPersonalRecords(
    Map<String, Map<String, double>> allData,
  ) {
    final Map<String, Map<String, double>> prData = {};

    final sortedDates = allData.keys.toList()..sort();

    // Running all-time best per exercise name
    final Map<String, double> allTimeBest = {};

    for (final date in sortedDates) {
      final exercises = allData[date]!;
      final Map<String, double> prsOnDate = {};

      for (final entry in exercises.entries) {
        final exerciseName = entry.key;
        final estimatedMax = entry.value;

        final currentBest = allTimeBest[exerciseName] ?? 0.0;

        if (estimatedMax > currentBest) {
          allTimeBest[exerciseName] = estimatedMax;
          prsOnDate[exerciseName] = estimatedMax;
        }
      }

      if (prsOnDate.isNotEmpty) {
        prData[date] = prsOnDate;
      }
    }

    return prData;
  }

  /// Get one rep max data for a specific date range (for display purposes)
  static Future<Map<String, Map<String, double>>> getOneRepMaxForDateRange(
    DateTime startDate, 
    DateTime endDate
  ) async {
    final allCachedData = await getCachedOneRepMax();
    final Map<String, Map<String, double>> filteredData = {};
    
    for (var entry in allCachedData.entries) {
      final date = DateTime.parse(entry.key);
      if (date.isAfter(startDate.subtract(const Duration(days: 1))) && 
          date.isBefore(endDate.add(const Duration(days: 1)))) {
        filteredData[entry.key] = entry.value;
      }
    }
    
    return filteredData;
  }

  /// Clear cache (useful for testing or when user signs out)
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return;

      final cacheKey = '${_cacheKey}_${user.uid}';
      final lastUpdateKey = '${_lastUpdateKey}_${user.uid}';
      
      await prefs.remove(cacheKey);
      await prefs.remove(lastUpdateKey);
    } catch (e) {
      print('Error clearing one rep max cache: $e');
    }
  }

  /// Force cache update (useful when new workout is saved)
  static Future<void> forceCacheUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return;

      final lastUpdateKey = '${_lastUpdateKey}_${user.uid}';
      await prefs.remove(lastUpdateKey);
    } catch (e) {
      print('Error forcing cache update: $e');
    }
  }
}
