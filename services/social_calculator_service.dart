import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class WeeklySummary {
  final String userId;
  final String weekKey;
  final double avgCalories;
  final int daysLogged;
  final int streak;
  final Map<String, int> dailyCalories;

  const WeeklySummary({
    required this.userId,
    required this.weekKey,
    required this.avgCalories,
    required this.daysLogged,
    required this.streak,
    required this.dailyCalories,
  });
}

class FriendWeeklyData {
  final String userId;
  final String firstName;
  final String lastName;
  final String userName;
  final String profileImageUrl;
  final WeeklySummary weeklySummary;
  final int dailyGoal;
  final bool isOnline;
  final DateTime lastActivity;

  const FriendWeeklyData({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.userName,
    required this.profileImageUrl,
    required this.weeklySummary,
    required this.dailyGoal,
    required this.isOnline,
    required this.lastActivity,
  });
}

class SocialCalculatorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get week key from date (format: "2024-W01")
  /// Uses ISO 8601 week numbering for correctness.
  String getWeekKey(DateTime date) {
    final year = date.year;
    final weekNumber = _getIsoWeekNumber(date);
    return '$year-W${weekNumber.toString().padLeft(2, '0')}';
  }

  /// ISO 8601 week number calculation.
  /// Week 1 is the week containing the first Thursday of the year.
  int _getIsoWeekNumber(DateTime date) {
    // Find the Thursday of the current week
    final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
    // Week 1 starts on the Monday of the week containing Jan 4
    final jan4 = DateTime(thursday.year, 1, 4);
    final startOfWeek1 =
        jan4.subtract(Duration(days: jan4.weekday - DateTime.monday));
    return ((thursday.difference(startOfWeek1).inDays) / 7).floor() + 1;
  }

  /// Get start date of week (Monday)
  DateTime getWeekStartDate(String weekKey) {
    final parts = weekKey.split('-W');
    final year = int.parse(parts[0]);
    final weekNum = int.parse(parts[1]);

    // Jan 4 is always in ISO week 1
    final jan4 = DateTime(year, 1, 4);
    final startOfWeek1 =
        jan4.subtract(Duration(days: jan4.weekday - DateTime.monday));
    return startOfWeek1.add(Duration(days: (weekNum - 1) * 7));
  }

  /// Get end date of week (Sunday)
  DateTime getWeekEndDate(String weekKey) {
    return getWeekStartDate(weekKey).add(const Duration(days: 6));
  }

  /// Format date to YYYY-MM-DD
  String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Calculate weekly average for a user
  Future<WeeklySummary> getUserWeeklyAverage(
    String userId,
    String weekKey,
  ) async {
    try {
      final weekStart = getWeekStartDate(weekKey);
      final weekEnd = getWeekEndDate(weekKey);

      final startDateKey = formatDate(weekStart);
      final endDateKey = formatDate(weekEnd);

      // Query daily_totals for the week
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_totals')
          .where('date', isGreaterThanOrEqualTo: startDateKey)
          .where('date', isLessThanOrEqualTo: endDateKey)
          .get();

      final Map<String, int> dailyCalories = {};
      int totalCalories = 0;
      int daysWithData = 0;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final date = data['date'] as String? ?? '';
        final calories = (data['calories'] as int? ?? 0);

        if (calories > 0) {
          dailyCalories[date] = calories;
          totalCalories += calories;
          daysWithData++;
        }
      }

      final avgCalories =
          daysWithData > 0 ? totalCalories / daysWithData : 0.0;
      final streak = await calculateStreak(userId);

      return WeeklySummary(
        userId: userId,
        weekKey: weekKey,
        avgCalories: avgCalories,
        daysLogged: daysWithData,
        streak: streak,
        dailyCalories: dailyCalories,
      );
    } catch (e) {
      debugPrint('Error calculating weekly average: $e');
      return WeeklySummary(
        userId: userId,
        weekKey: weekKey,
        avgCalories: 0.0,
        daysLogged: 0,
        streak: 0,
        dailyCalories: const {},
      );
    }
  }

  /// Calculate streak (consecutive days with calories logged).
  ///
  /// Optimized: queries the last 30 days in a single batch read instead
  /// of making up to 30 individual document reads sequentially.
  Future<int> calculateStreak(String userId) async {
    try {
      final today = DateTime.now();
      final thirtyDaysAgo = today.subtract(const Duration(days: 30));

      final startDateKey = formatDate(thirtyDaysAgo);
      final endDateKey = formatDate(today);

      // Single batch query instead of N+1 individual reads
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_totals')
          .where('date', isGreaterThanOrEqualTo: startDateKey)
          .where('date', isLessThanOrEqualTo: endDateKey)
          .get();

      // Build a set of dates that have calories > 0
      final Set<String> datesWithCalories = {};
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final date = data['date'] as String? ?? '';
        final calories = (data['calories'] as int? ?? 0);
        if (calories > 0 && date.isNotEmpty) {
          datesWithCalories.add(date);
        }
      }

      // Count consecutive days backwards from today
      int streak = 0;
      DateTime currentDate = today;
      while (streak < 30) {
        final dateKey = formatDate(currentDate);
        if (datesWithCalories.contains(dateKey)) {
          streak++;
          currentDate = currentDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      return streak;
    } catch (e) {
      debugPrint('Error calculating streak: $e');
      return 0;
    }
  }

  /// Get all friends' weekly data
  Future<List<FriendWeeklyData>> getFriendsWeeklyData(
      String weekKey) async {
    final String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    try {
      final friendIds = await fetchFriendList(currentUserId);
      friendIds.add(currentUserId); // Include current user

      // Fetch all friends' data in parallel
      final futures =
          friendIds.map((friendId) => _fetchFriendData(friendId, weekKey));

      final results = await Future.wait(futures);
      final friendsData =
          results.whereType<FriendWeeklyData>().toList();

      // Sort by weekly average (descending)
      friendsData.sort((a, b) =>
          b.weeklySummary.avgCalories.compareTo(a.weeklySummary.avgCalories));

      return friendsData;
    } catch (e) {
      debugPrint('Error getting friends weekly data: $e');
      return [];
    }
  }

  /// Fetch data for a single friend. Returns null on failure.
  Future<FriendWeeklyData?> _fetchFriendData(
    String friendId,
    String weekKey,
  ) async {
    try {
      final userDoc =
          await _firestore.collection('users').doc(friendId).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      final goals = userData['goals'] as Map<String, dynamic>? ?? {};
      final caloriesValue = goals['calories'];
      final dailyGoal = caloriesValue != null
          ? (caloriesValue is int
              ? caloriesValue
              : (caloriesValue is double
                  ? caloriesValue.toInt()
                  : 2000))
          : 2000;

      final weeklySummary =
          await getUserWeeklyAverage(friendId, weekKey);
      final lastActivity = await _getLastActivity(friendId);

      return FriendWeeklyData(
        userId: friendId,
        firstName: userData['firstName'] ?? '',
        lastName: userData['lastName'] ?? '',
        userName: userData['userName'] ?? '',
        profileImageUrl: userData['profileImageUrl'] ?? '',
        weeklySummary: weeklySummary,
        dailyGoal: dailyGoal,
        isOnline: _isOnline(lastActivity),
        lastActivity: lastActivity,
      );
    } catch (e) {
      debugPrint('Error fetching friend data for $friendId: $e');
      return null;
    }
  }

  /// Fetch a user's friend list.
  Future<List<String>> fetchFriendList(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .get();

      if (querySnapshot.docs.isEmpty) return [];

      return querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            // Support both old and new formats
            return data['friendId'] as String? ??
                data['userId'] as String? ??
                doc.id;
          })
          .where((id) => id.isNotEmpty && id != userId)
          .toList();
    } catch (e) {
      debugPrint('Error fetching friend list: $e');
      return [];
    }
  }

  /// Get last activity timestamp
  Future<DateTime> _getLastActivity(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_totals')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          return timestamp.toDate();
        }
      }
    } catch (e) {
      debugPrint('Error getting last activity: $e');
    }

    return DateTime.now().subtract(const Duration(days: 30));
  }

  /// Check if user is online (active within last 15 minutes)
  bool _isOnline(DateTime lastActivity) {
    return DateTime.now().difference(lastActivity).inMinutes < 15;
  }

  /// Get user's ranking in friends list
  Future<int> getUserRanking(String userId, String weekKey) async {
    final friendsData = await getFriendsWeeklyData(weekKey);

    for (int i = 0; i < friendsData.length; i++) {
      if (friendsData[i].userId == userId) {
        return i + 1;
      }
    }

    return friendsData.length + 1;
  }
}
