import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_record.dart';
import 'firebase_service.dart';
import 'health_service.dart';

/// Weekly summary data for the Activity Log UI.
class WeeklySummary {
  final double totalCalories;
  final double totalDistanceMeters;
  final int totalDurationMinutes;
  final int activityCount;
  final Map<int, double> dailyCalories; // weekday (1=Mon, 7=Sun) -> calories
  final double? previousWeekCalories; // for % change badge

  const WeeklySummary({
    required this.totalCalories,
    required this.totalDistanceMeters,
    required this.totalDurationMinutes,
    required this.activityCount,
    required this.dailyCalories,
    this.previousWeekCalories,
  });

  /// Percentage change vs previous week, or null if no previous data.
  double? get percentChange {
    if (previousWeekCalories == null || previousWeekCalories == 0) return null;
    return ((totalCalories - previousWeekCalories!) / previousWeekCalories!) * 100;
  }
}

/// Service for activity CRUD, caching, and sync with health platforms.
///
/// Cache strategy: Memory -> SharedPreferences (30min TTL) -> Firebase.
/// Follows the same pattern as ExerciseCacheService.
class ActivityService {
  // Cache keys
  static const String _cacheKey = 'activities_cache';
  static const String _cacheUpdateKey = 'activities_last_update';
  static const Duration _cacheTTL = Duration(minutes: 30);

  // In-memory cache
  static List<ActivityRecord>? _memoryCache;
  static String? _memoryCacheUid;

  // ============================================================================
  // GET ACTIVITIES (cache-first)
  // ============================================================================

  /// Get recent activities. Checks memory -> SharedPreferences -> Firebase.
  static Future<List<ActivityRecord>> getActivities({int days = 30}) async {
    try {
      final uid = FirebaseService.currentUserId;
      if (uid == null) return [];

      // 1. Check in-memory cache
      if (_memoryCache != null && _memoryCacheUid == uid) {
        return _memoryCache!;
      }

      // 2. Check SharedPreferences cache
      final cached = await _getCachedActivities(uid);
      if (cached != null) {
        _memoryCache = cached;
        _memoryCacheUid = uid;
        return cached;
      }

      // 3. Fetch from Firebase
      return await _fetchAndCacheActivities(uid, days);
    } catch (e) {
      debugPrint('ActivityService.getActivities error: $e');
      return [];
    }
  }

  /// Force refresh from Firebase, bypassing cache.
  static Future<List<ActivityRecord>> refreshActivities({int days = 30}) async {
    final uid = FirebaseService.currentUserId;
    if (uid == null) return [];
    return await _fetchAndCacheActivities(uid, days);
  }

  // ============================================================================
  // SAVE ACTIVITY
  // ============================================================================

  /// Save a single activity to Firestore and update cache.
  static Future<void> saveActivity(ActivityRecord activity) async {
    try {
      await FirebaseService.saveActivity(activity.toMap());
      // Add to memory cache without full refetch
      _addToMemoryCache(activity);
      // Persist updated cache
      await _persistCache();
      debugPrint('Activity saved: ${activity.type.name} ${activity.caloriesBurned} kcal');
    } catch (e) {
      debugPrint('ActivityService.saveActivity error: $e');
      rethrow;
    }
  }

  /// Save activities from a watch sync. Deduplicates against existing records.
  static Future<int> saveActivitiesFromSync(List<ActivityRecord> activities) async {
    if (activities.isEmpty) return 0;

    try {
      // Get existing activity IDs for deduplication
      final earliest = activities.map((a) => a.startTime).reduce(
          (a, b) => a.isBefore(b) ? a : b);
      final latest = activities.map((a) => a.endTime).reduce(
          (a, b) => a.isAfter(b) ? a : b);

      final existingIds = await FirebaseService.getActivityIds(
        from: earliest.subtract(const Duration(days: 1)),
        to: latest.add(const Duration(days: 1)),
      );

      // Filter out duplicates
      final newActivities = activities
          .where((a) => !existingIds.contains(a.id))
          .toList();

      if (newActivities.isEmpty) {
        debugPrint('No new activities to save (all duplicates)');
        return 0;
      }

      // Batch save
      await FirebaseService.saveActivitiesBatch(
        newActivities.map((a) => a.toMap()).toList(),
      );

      // Update cache
      for (final activity in newActivities) {
        _addToMemoryCache(activity);
      }
      await _persistCache();

      debugPrint('Synced ${newActivities.length} new activities');
      return newActivities.length;
    } catch (e) {
      debugPrint('ActivityService.saveActivitiesFromSync error: $e');
      rethrow;
    }
  }

  // ============================================================================
  // DELETE ACTIVITY
  // ============================================================================

  /// Delete an activity from Firestore and update cache.
  static Future<void> deleteActivity(String activityId) async {
    try {
      await FirebaseService.deleteActivity(activityId);
      _memoryCache?.removeWhere((a) => a.id == activityId);
      await _persistCache();
      debugPrint('Activity deleted: $activityId');
    } catch (e) {
      debugPrint('ActivityService.deleteActivity error: $e');
      rethrow;
    }
  }

  // ============================================================================
  // WEEKLY SUMMARY
  // ============================================================================

  /// Calculate weekly summary for the current week (Mon-Sun).
  static Future<WeeklySummary> getWeeklySummary() async {
    final activities = await getActivities(days: 14); // fetch 2 weeks for comparison
    final now = DateTime.now();

    // Current week: Monday to Sunday
    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(currentWeekStart.year, currentWeekStart.month, currentWeekStart.day);
    final weekEnd = weekStart.add(const Duration(days: 7));

    // Previous week
    final prevWeekStart = weekStart.subtract(const Duration(days: 7));

    final currentWeekActivities = activities.where(
      (a) => a.startTime.isAfter(weekStart) && a.startTime.isBefore(weekEnd),
    ).toList();

    final prevWeekActivities = activities.where(
      (a) => a.startTime.isAfter(prevWeekStart) && a.startTime.isBefore(weekStart),
    ).toList();

    // Build daily breakdown
    final Map<int, double> dailyCalories = {};
    for (int i = 1; i <= 7; i++) {
      dailyCalories[i] = 0;
    }
    for (final a in currentWeekActivities) {
      final weekday = a.startTime.weekday; // 1=Mon, 7=Sun
      dailyCalories[weekday] = (dailyCalories[weekday] ?? 0) + a.caloriesBurned;
    }

    final prevTotal = prevWeekActivities.fold<double>(
        0, (sum, a) => sum + a.caloriesBurned);

    return WeeklySummary(
      totalCalories: currentWeekActivities.fold(0, (sum, a) => sum + a.caloriesBurned),
      totalDistanceMeters: currentWeekActivities.fold(
          0, (sum, a) => sum + (a.distanceMeters ?? 0)),
      totalDurationMinutes: currentWeekActivities.fold(
          0, (sum, a) => sum + a.durationMinutes),
      activityCount: currentWeekActivities.length,
      dailyCalories: dailyCalories,
      previousWeekCalories: prevTotal > 0 ? prevTotal : null,
    );
  }

  // ============================================================================
  // WATCH SYNC
  // ============================================================================

  /// Sync activities from the health platform (HealthKit / Health Connect).
  /// Returns the number of new activities imported.
  static Future<int> syncFromWatch({int days = 7}) async {
    try {
      final available = await HealthService.isAvailable();
      if (!available) {
        debugPrint('Health platform not available');
        return 0;
      }

      final hasPerms = await HealthService.hasPermissions();
      if (!hasPerms) {
        final granted = await HealthService.requestPermissions();
        if (!granted) {
          debugPrint('Health permissions not granted');
          return 0;
        }
      }

      final now = DateTime.now();
      final from = now.subtract(Duration(days: days));

      final workouts = await HealthService.fetchWorkouts(from: from, to: now);
      if (workouts.isEmpty) return 0;

      final count = await saveActivitiesFromSync(workouts);
      await HealthService.saveLastSyncTime(now);
      return count;
    } catch (e) {
      debugPrint('ActivityService.syncFromWatch error: $e');
      rethrow;
    }
  }

  // ============================================================================
  // CALORIE ESTIMATION
  // ============================================================================

  /// Estimate calories for a manual activity entry.
  /// Uses MET formula: calories = MET x weightKg x durationHours
  static Future<double> estimateCalories({
    required ActivityType type,
    required int durationMinutes,
    double intensity = 0.5,
  }) async {
    // Get user weight from profile
    double weightKg = 70.0; // default
    try {
      final userData = await FirebaseService.getUserData();
      if (userData != null) {
        final weight = userData['weight'];
        if (weight != null && weight is num && weight > 0) {
          weightKg = weight.toDouble();
          // Convert from lb to kg if needed
          final weightUnit = userData['weightUnit'] as String? ?? 'kg';
          if (weightUnit == 'lb') {
            weightKg = weightKg * 0.453592;
          }
        }
      }
    } catch (e) {
      debugPrint('Could not fetch user weight, using default: $e');
    }

    return ActivityRecord.estimateCalories(
      type: type,
      durationMinutes: durationMinutes,
      weightKg: weightKg,
      intensity: intensity,
    );
  }

  // ============================================================================
  // CACHE MANAGEMENT
  // ============================================================================

  /// Invalidate all caches (call after external data changes).
  static Future<void> invalidateCache() async {
    _memoryCache = null;
    _memoryCacheUid = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = FirebaseService.currentUserId;
      if (uid != null) {
        await prefs.remove('${_cacheKey}_$uid');
        await prefs.remove('${_cacheUpdateKey}_$uid');
      }
    } catch (e) {
      debugPrint('ActivityService.invalidateCache error: $e');
    }
  }

  /// Clear all activity caches (call on sign out).
  static Future<void> clearCache() async {
    _memoryCache = null;
    _memoryCacheUid = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = FirebaseService.currentUserId;
      if (uid != null) {
        await prefs.remove('${_cacheKey}_$uid');
        await prefs.remove('${_cacheUpdateKey}_$uid');
      }
    } catch (e) {
      debugPrint('ActivityService.clearCache error: $e');
    }
  }

  // ============================================================================
  // PRIVATE CACHE HELPERS
  // ============================================================================

  static Future<List<ActivityRecord>?> _getCachedActivities(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getString('${_cacheUpdateKey}_$uid');
      if (lastUpdate == null) return null;

      final lastUpdateTime = DateTime.parse(lastUpdate);
      if (DateTime.now().difference(lastUpdateTime) > _cacheTTL) return null;

      final cachedJson = prefs.getString('${_cacheKey}_$uid');
      if (cachedJson == null) return null;

      final List<dynamic> decoded = json.decode(cachedJson);
      return decoded
          .map((item) => ActivityRecord.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('ActivityService._getCachedActivities error: $e');
      return null;
    }
  }

  static Future<List<ActivityRecord>> _fetchAndCacheActivities(
      String uid, int days) async {
    final from = DateTime.now().subtract(Duration(days: days));
    final maps = await FirebaseService.getActivities(from: from, limit: 200);
    final activities = maps.map((m) => ActivityRecord.fromMap(m)).toList();

    // Update memory cache
    _memoryCache = activities;
    _memoryCacheUid = uid;

    // Persist to SharedPreferences
    await _persistCache();

    debugPrint('Fetched ${activities.length} activities from Firebase');
    return activities;
  }

  static Future<void> _persistCache() async {
    if (_memoryCache == null || _memoryCacheUid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _memoryCache!.map((a) => a.toJson()).toList();
      await prefs.setString(
          '${_cacheKey}_$_memoryCacheUid', json.encode(jsonList));
      await prefs.setString(
          '${_cacheUpdateKey}_$_memoryCacheUid', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('ActivityService._persistCache error: $e');
    }
  }

  static void _addToMemoryCache(ActivityRecord activity) {
    final uid = FirebaseService.currentUserId;
    if (uid == null) return;

    _memoryCache ??= [];
    _memoryCacheUid = uid;

    // Remove existing with same ID (in case of update)
    _memoryCache!.removeWhere((a) => a.id == activity.id);
    // Insert at beginning (most recent first)
    _memoryCache!.insert(0, activity);
  }
}
