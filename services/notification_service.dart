import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

/// Handles local notifications: workout reminder, incomplete workout, streak, etc.
/// Call [initialize] from main after WidgetsBinding.ensureInitialized().
/// Call [setNotificationTapHandler] from BottomNavBar when home is visible.
class NotificationService {
  static const String _prefsKeyPrefix = 'notification_prefs_';
  static const String _workoutReminderEnabled = 'workout_reminder_enabled';
  static const String _workoutReminderHour = 'workout_reminder_hour';
  static const String _workoutReminderMinute = 'workout_reminder_minute';

  static const int idWorkoutReminder = 1;
  static const int idIncompleteWorkout = 2;
  static const int idStreak = 3;

  static const String _channelId = 'fitness2_reminders';
  static const String _channelName = 'Reminders';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static void Function(int tabIndex, String? pushRoute)? _tapHandler;
  static (int tabIndex, String? pushRoute)? _pendingPayload;

  /// Call from main() after WidgetsBinding.ensureInitialized().
  static Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      AppLogger.log('Timezone init fallback to UTC: $e', tag: 'NotificationService');
      tz.setLocalLocation(tz.UTC);
    }

    final android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
    );
    final initSettings =
        InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    final androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Workout and reminder notifications',
      importance: Importance.defaultImportance,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialized = true;
    AppLogger.log('NotificationService initialized', tag: 'NotificationService');
  }

  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    int tabIndex = 0;
    String? pushRoute;
    try {
      final parts = payload.split('_');
      if (parts.isNotEmpty) {
        final tab = int.tryParse(parts[0]);
        if (tab != null) tabIndex = tab.clamp(0, 4);
      }
      if (parts.length > 1 && parts[1] == 'continue') pushRoute = 'continue_workout';
      if (parts.length > 1 && parts[1] == 'calories') pushRoute = 'calories';
    } catch (_) {}

    _pendingPayload = (tabIndex, pushRoute);
    if (_tapHandler != null) {
      _tapHandler!(tabIndex, pushRoute);
      _pendingPayload = null;
    }
  }

  /// Set from BottomNavBar so notification tap can switch tab and push route.
  static void setNotificationTapHandler(
      void Function(int tabIndex, String? pushRoute) handler) {
    _tapHandler = handler;
    final pending = _pendingPayload;
    if (pending != null) {
      _pendingPayload = null;
      handler(pending.$1, pending.$2);
    }
  }

  /// Call from BottomNavBar.initState to handle notification that opened the app.
  static (int tabIndex, String? pushRoute)? consumePendingPayload() {
    final p = _pendingPayload;
    _pendingPayload = null;
    return p;
  }

  /// Request notification permission (iOS and Android 13+).
  static Future<bool> requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      if (granted != true) return false;
    }
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (granted != true) return false;
    }
    return true;
  }

  // ---------- Workout reminder (daily at user time) ----------

  static Future<void> scheduleWorkoutReminder({
    required int hour,
    required int minute,
  }) async {
    await cancelWorkoutReminder();
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    final tzDate = tz.TZDateTime.from(scheduled, tz.local);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.defaultImportance,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      idWorkoutReminder,
      'Time to work out',
      'Time to work out',
      tzDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '0',
    );
    AppLogger.log('Workout reminder scheduled at $hour:$minute',
        tag: 'NotificationService');
  }

  static Future<void> cancelWorkoutReminder() async {
    await _plugin.cancel(idWorkoutReminder);
  }

  /// Apply workout reminder from saved preferences; call after login or when prefs change.
  static Future<void> applyWorkoutReminderFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefsKeyPrefix + _workoutReminderEnabled) ?? false;
    if (!enabled) {
      await cancelWorkoutReminder();
      return;
    }
    final hour = prefs.getInt(_prefsKeyPrefix + _workoutReminderHour) ?? 9;
    final minute = prefs.getInt(_prefsKeyPrefix + _workoutReminderMinute) ?? 0;
    await scheduleWorkoutReminder(hour: hour, minute: minute);
  }

  static Future<void> saveWorkoutReminderPrefs({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyPrefix + _workoutReminderEnabled, enabled);
    await prefs.setInt(_prefsKeyPrefix + _workoutReminderHour, hour);
    await prefs.setInt(_prefsKeyPrefix + _workoutReminderMinute, minute);
    if (enabled) {
      await scheduleWorkoutReminder(hour: hour, minute: minute);
    } else {
      await cancelWorkoutReminder();
    }
  }

  static Future<({bool enabled, int hour, int minute})> getWorkoutReminderPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      enabled: prefs.getBool(_prefsKeyPrefix + _workoutReminderEnabled) ?? false,
      hour: prefs.getInt(_prefsKeyPrefix + _workoutReminderHour) ?? 9,
      minute: prefs.getInt(_prefsKeyPrefix + _workoutReminderMinute) ?? 0,
    );
  }

  // ---------- Incomplete workout (once per day until continued/discarded) ----------

  /// Schedule "You have an unfinished workout from [date]. Tap to continue."
  /// Call when app detects incomplete workout (e.g. on Tracker tab load).
  static Future<void> scheduleIncompleteWorkoutIfNeeded({
    required DateTime workoutStartDate,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final workoutDay = DateTime(
        workoutStartDate.year, workoutStartDate.month, workoutStartDate.day);
    if (workoutDay == today) return;

    final scheduled = DateTime(now.year, now.month, now.day, 9, 0);
    if (scheduled.isBefore(now)) return;

    final dateStr = '${workoutStartDate.year}-${workoutStartDate.month.toString().padLeft(2, '0')}-${workoutStartDate.day.toString().padLeft(2, '0')}';
    final tzDate = tz.TZDateTime.from(scheduled, tz.local);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.defaultImportance,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      idIncompleteWorkout,
      'Unfinished workout',
      'You have an unfinished workout from $dateStr. Tap to continue.',
      tzDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '0_continue',
    );
  }

  static Future<void> cancelIncompleteWorkoutNotification() async {
    try {
      await _plugin.cancel(idIncompleteWorkout);
    } catch (e) {
      AppLogger.error('Cancelling incomplete workout notification', error: e, tag: 'NotificationService');
    }
  }

  // ---------- Streak (one-time congrats) ----------

  static Future<void> showStreakNotification({required int streak}) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.defaultImportance,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.show(
      idStreak,
      'Keep it up!',
      "You've hit your goal $streak days in a row. Keep it up.",
      details,
      payload: '0',
    );
  }
}
