import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitness2/models/firebase_exercise.dart';
import 'package:fitness2/services/social_calculator_service.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/social_widget/exercise_deep_dive.dart';
import '../leaderboard_widgets/leaderboard_exercise_selection.dart'
    hide FirebaseExercise;

class SocialExercise extends StatefulWidget {
  const SocialExercise({super.key});

  @override
  State<SocialExercise> createState() => _SocialExerciseState();
}

class _SocialExerciseState extends State<SocialExercise> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SocialCalculatorService _socialService = SocialCalculatorService();

  List<FirebaseExercise> _exercises = [];
  bool _isLoadingExercises = true;

  List<_TrendingItem> _trendingItems = [];
  bool _isLoadingTrending = false;

  List<String>? _cachedFriendIds;

  static const List<String> _defaultExerciseIds = [
    '73', '83', '43', '20', '91', '167', '148',
  ];

  static const Map<String, _ExerciseMeta> _fallbackExercises = {
    '73': _ExerciseMeta('Bench Press', 'Chest'),
    '83': _ExerciseMeta('Bent Over Rowing', 'Back'),
    '43': _ExerciseMeta('Barbell Hack Squats', 'Legs'),
    '20': _ExerciseMeta('Arnold Shoulder Press', 'Shoulders'),
    '91': _ExerciseMeta('Biceps Curls With Barbell', 'Arms'),
    '167': _ExerciseMeta('Crunches', 'Abs'),
    '148': _ExerciseMeta('Calf Raises on Hackenschmitt Machine', 'Calves'),
  };

  @override
  void initState() {
    super.initState();
    _loadExercisesFromFirebase();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadExercisesFromFirebase() async {
    if (!mounted) return;
    setState(() => _isLoadingExercises = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoadingExercises = false);
        return;
      }

      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      List<String> selectedExerciseIds =
          (userDoc.data()?['leaderboardExercises'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();
      if (selectedExerciseIds.isEmpty) {
        selectedExerciseIds = List.from(_defaultExerciseIds);
      }

      // Firestore whereIn supports up to 30 values
      final querySnapshot = await _firestore
          .collection('exercises')
          .where(FieldPath.documentId, whereIn: selectedExerciseIds)
          .get();

      final Map<String, FirebaseExercise> exerciseMap = {};
      for (var doc in querySnapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data.forEach((key, value) {
          if (value is Timestamp) {
            data[key] = value.toDate().toIso8601String();
          }
        });
        final exercise = FirebaseExercise.fromMap(data, doc.id);
        exerciseMap[exercise.id] = exercise;
      }

      final List<FirebaseExercise> userSelectedExercises = [];
      for (String id in selectedExerciseIds) {
        final exercise = exerciseMap[id] ??
            FirebaseExercise(
              id: id,
              name: _fallbackExercises[id]?.name ?? 'Unknown Exercise',
              description: '',
              category: _fallbackExercises[id]?.category ?? 'Unknown',
              muscles: const [],
              musclesSecondary: const [],
              equipment: const [],
              images: const [],
            );
        userSelectedExercises.add(exercise);
      }

      if (mounted) {
        setState(() {
          _exercises = userSelectedExercises;
          _isLoadingExercises = false;
        });
        _loadTrendingData();
      }
    } catch (e) {
      debugPrint('Error loading exercises: $e');
      if (mounted) setState(() => _isLoadingExercises = false);
    }
  }

  Future<void> _loadTrendingData() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || _exercises.isEmpty) return;

    if (!mounted) return;
    setState(() => _isLoadingTrending = true);

    try {
      _cachedFriendIds ??= await _socialService.fetchFriendList(userId);
      final friendIds = <String>{...?_cachedFriendIds, userId};

      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      // Fetch only docs we're allowed to read (self + friends) to satisfy Firestore rules
      final futures = _exercises.map((exercise) async {
        final usersPath =
            'friendsLeaderboard/${exercise.id}/months/$monthKey/users';
        int count = 0;
        for (final uid in friendIds) {
          final doc = await _firestore.doc('$usersPath/$uid').get();
          if (doc.exists) count++;
        }
        return _TrendingItem(
          exercise: exercise,
          friendCount: count,
          sessionCount: count,
        );
      });

      final items = await Future.wait(futures);

      if (mounted) {
        setState(() {
          _trendingItems = items;
          _isLoadingTrending = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading trending data: $e');
      if (mounted) setState(() => _isLoadingTrending = false);
    }
  }

  void _clearCacheAndReload() {
    _cachedFriendIds = null;
    _loadExercisesFromFirebase();
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = _auth.currentUser?.uid;

    if (userId == null) {
      return const Center(
        child: Text(
          'User not logged in',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    if (_isLoadingExercises) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16.rw, 8, 16.rw, 100.rh),
            children: _buildExerciseList(userId),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.rw, 8, 16.rw, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Friends Leaderboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          Semantics(
            label: 'Change exercises',
            button: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const LeaderboardExerciseSelectionPage(),
                    ),
                  );
                  if (result != null) {
                    _clearCacheAndReload();
                  }
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.swap_horiz,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExerciseList(String userId) {
    if (_isLoadingTrending) {
      return [
        Padding(
          padding: EdgeInsets.all(24.r),
          child:
              const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ];
    }
    if (_trendingItems.isEmpty) {
      return [
        Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: DesignSystem.darkCard.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DesignSystem.borderDark),
          ),
          child: Center(
            child: Text(
              'No exercises selected. Tap the icon above to choose exercises.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ];
    }
    return _trendingItems
        .map((item) => _buildTrendingCard(item, userId))
        .toList();
  }

  Widget _buildTrendingCard(_TrendingItem item, String userId) {
    final exercise = item.exercise;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.rh),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openExerciseLeaderboard(exercise, userId),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: DesignSystem.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DesignSystem.borderDark),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: DesignSystem.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fitness_center,
                      color: DesignSystem.primary, size: 26),
                ),
                SizedBox(width: 16.rw),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '${item.friendCount} friends',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '•',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${item.sessionCount} sessions',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openExerciseLeaderboard(FirebaseExercise exercise, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ExerciseDeepDiveScreen(
          exerciseName: exercise.name,
          exerciseId: exercise.id,
          userId: userId,
        ),
      ),
    );
  }
}

class _ExerciseMeta {
  final String name;
  final String category;
  const _ExerciseMeta(this.name, this.category);
}

class _TrendingItem {
  final FirebaseExercise exercise;
  final int friendCount;
  final int sessionCount;

  const _TrendingItem({
    required this.exercise,
    required this.friendCount,
    required this.sessionCount,
  });
}
