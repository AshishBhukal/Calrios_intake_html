import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_record.dart';

/// Service wrapping the `health` Flutter package for Apple HealthKit & Google Health Connect.
///
/// Flow: Watch -> Health Platform (HealthKit / Health Connect) -> HealthService -> ActivityService -> UI
class HealthService {
  static final Health _health = Health();
  static bool _initialized = false;

  // SharedPreferences keys
  static const String _lastSyncKey = 'health_last_sync_time';
  static const String _permissionGrantedKey = 'health_permission_granted';

  /// Health data types we want to read.
  static final List<HealthDataType> _readTypes = [
    HealthDataType.WORKOUT,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.HEART_RATE,
    HealthDataType.STEPS,
  ];

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  /// Configure the Health instance. Call once at app startup or before first use.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _health.configure();
      _initialized = true;
      debugPrint('HealthService initialized');
    } catch (e) {
      debugPrint('HealthService initialization error: $e');
    }
  }

  // ============================================================================
  // PLATFORM DETECTION
  // ============================================================================

  /// Returns the health platform name based on the current OS.
  static String? getConnectedPlatform() {
    if (Platform.isIOS) return 'Apple HealthKit';
    if (Platform.isAndroid) return 'Health Connect';
    return null;
  }

  /// Whether the current platform supports health data.
  static bool get isSupported => Platform.isIOS || Platform.isAndroid;

  /// Check if Health Connect is installed on Android.
  /// On iOS, HealthKit is always available.
  static Future<bool> isAvailable() async {
    if (!isSupported) return false;
    try {
      await initialize();
      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        return status == HealthConnectSdkStatus.sdkAvailable;
      }
      // HealthKit is always available on iOS
      return true;
    } catch (e) {
      debugPrint('HealthService.isAvailable error: $e');
      return false;
    }
  }

  // ============================================================================
  // PERMISSIONS
  // ============================================================================

  /// Request read permissions for health data types.
  /// Returns true if all permissions were granted.
  static Future<bool> requestPermissions() async {
    try {
      await initialize();
      final permissions = _readTypes.map((_) => HealthDataAccess.READ).toList();
      final granted = await _health.requestAuthorization(
        _readTypes,
        permissions: permissions,
      );
      if (granted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_permissionGrantedKey, true);
      }
      debugPrint('Health permissions granted: $granted');
      return granted;
    } catch (e) {
      debugPrint('HealthService.requestPermissions error: $e');
      return false;
    }
  }

  /// Check if permissions have been previously granted (cached check).
  static Future<bool> hasPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_permissionGrantedKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Revoke health permissions and clear local state.
  static Future<void> revokePermissions() async {
    try {
      await initialize();
      await _health.revokePermissions();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_permissionGrantedKey, false);
      await prefs.remove(_lastSyncKey);
      debugPrint('Health permissions revoked');
    } catch (e) {
      debugPrint('HealthService.revokePermissions error: $e');
    }
  }

  // ============================================================================
  // DATA FETCHING
  // ============================================================================

  /// Fetch workout sessions from the health platform within the given date range.
  /// Returns a list of [ActivityRecord] converted from health platform workout data.
  static Future<List<ActivityRecord>> fetchWorkouts({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      await initialize();

      // Fetch workout data
      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: from,
        endTime: to,
      );

      // Remove duplicates from different sources
      final uniqueData = _health.removeDuplicates(healthData);

      final List<ActivityRecord> activities = [];

      for (final dataPoint in uniqueData) {
        if (dataPoint.value is! WorkoutHealthValue) continue;

        final workout = dataPoint.value as WorkoutHealthValue;
        final activityType = _mapWorkoutType(workout.workoutActivityType);
        final duration = dataPoint.dateTo.difference(dataPoint.dateFrom);

        // Get calories and distance from the workout value
        // totalEnergyBurned is int? (kcal), totalDistance is int? (meters)
        final calories = workout.totalEnergyBurned?.toDouble() ?? 0.0;
        final distanceMeters = workout.totalDistance?.toDouble();

        if (duration.inMinutes < 1) continue; // Skip very short entries

        activities.add(ActivityRecord(
          id: '${dataPoint.dateFrom.millisecondsSinceEpoch}_${activityType.name}',
          type: activityType,
          caloriesBurned: calories,
          distanceMeters: distanceMeters, // already in meters from health API
          durationMinutes: duration.inMinutes,
          startTime: dataPoint.dateFrom,
          endTime: dataPoint.dateTo,
          source: ActivitySource.watch,
          createdAt: DateTime.now(),
        ));
      }

      // Also try to fetch heart rate data to enrich activities
      await _enrichWithHeartRate(activities, from, to);

      // Also try to fetch steps
      await _enrichWithSteps(activities, from, to);

      // Update last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

      debugPrint('Fetched ${activities.length} workouts from health platform');
      return activities;
    } catch (e) {
      debugPrint('HealthService.fetchWorkouts error: $e');
      return [];
    }
  }

  /// Enrich activity records with average heart rate data.
  static Future<void> _enrichWithHeartRate(
    List<ActivityRecord> activities,
    DateTime from,
    DateTime to,
  ) async {
    try {
      final heartRateData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: from,
        endTime: to,
      );

      for (int i = 0; i < activities.length; i++) {
        final activity = activities[i];
        final relevantHR = heartRateData.where((dp) =>
            dp.dateFrom.isAfter(activity.startTime.subtract(const Duration(minutes: 1))) &&
            dp.dateTo.isBefore(activity.endTime.add(const Duration(minutes: 1))));

        if (relevantHR.isNotEmpty) {
          double total = 0;
          int count = 0;
          for (final dp in relevantHR) {
            if (dp.value is NumericHealthValue) {
              total += (dp.value as NumericHealthValue).numericValue.toDouble();
              count++;
            }
          }
          if (count > 0) {
            activities[i] = activity.copyWith(avgHeartRate: total / count);
          }
        }
      }
    } catch (e) {
      debugPrint('HealthService._enrichWithHeartRate error: $e');
    }
  }

  /// Enrich activity records with step count data.
  static Future<void> _enrichWithSteps(
    List<ActivityRecord> activities,
    DateTime from,
    DateTime to,
  ) async {
    try {
      final stepsData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: from,
        endTime: to,
      );

      for (int i = 0; i < activities.length; i++) {
        final activity = activities[i];
        if (activity.type != ActivityType.running &&
            activity.type != ActivityType.walking) {
          continue;
        }

        final relevantSteps = stepsData.where((dp) =>
            dp.dateFrom.isAfter(activity.startTime.subtract(const Duration(minutes: 1))) &&
            dp.dateTo.isBefore(activity.endTime.add(const Duration(minutes: 1))));

        if (relevantSteps.isNotEmpty) {
          int totalSteps = 0;
          for (final dp in relevantSteps) {
            if (dp.value is NumericHealthValue) {
              totalSteps += (dp.value as NumericHealthValue).numericValue.toInt();
            }
          }
          if (totalSteps > 0) {
            activities[i] = activity.copyWith(steps: totalSteps);
          }
        }
      }
    } catch (e) {
      debugPrint('HealthService._enrichWithSteps error: $e');
    }
  }

  // ============================================================================
  // SYNC METADATA
  // ============================================================================

  /// Get the last sync time, or null if never synced.
  static Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_lastSyncKey);
      if (stored == null) return null;
      return DateTime.parse(stored);
    } catch (e) {
      return null;
    }
  }

  /// Save the last sync time.
  static Future<void> saveLastSyncTime(DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, time.toIso8601String());
    } catch (e) {
      debugPrint('HealthService.saveLastSyncTime error: $e');
    }
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  /// Map health platform workout type to our ActivityType enum.
  static ActivityType _mapWorkoutType(HealthWorkoutActivityType workoutType) {
    switch (workoutType) {
      case HealthWorkoutActivityType.RUNNING:
      case HealthWorkoutActivityType.RUNNING_TREADMILL:
        return ActivityType.running;
      case HealthWorkoutActivityType.BIKING:
      case HealthWorkoutActivityType.BIKING_STATIONARY:
        return ActivityType.cycling;
      case HealthWorkoutActivityType.WALKING:
      case HealthWorkoutActivityType.HIKING:
        return ActivityType.walking;
      case HealthWorkoutActivityType.SWIMMING:
      case HealthWorkoutActivityType.SWIMMING_OPEN_WATER:
      case HealthWorkoutActivityType.SWIMMING_POOL:
        return ActivityType.swimming;
      case HealthWorkoutActivityType.YOGA:
      case HealthWorkoutActivityType.PILATES:
        return ActivityType.yoga;
      case HealthWorkoutActivityType.STRENGTH_TRAINING:
      case HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING:
      case HealthWorkoutActivityType.WEIGHTLIFTING:
      case HealthWorkoutActivityType.CROSS_TRAINING:
      case HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING:
      case HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING:
        return ActivityType.strength;
      default:
        return ActivityType.other;
    }
  }
}
