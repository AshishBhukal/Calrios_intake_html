import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitness2/services/unit_preference_service.dart';
import '../services/exercise_cache_service.dart';
import '../features/extra/constants.dart';

// Firebase Exercise Structure
class FirebaseExercise {
  final int id;
  final String name;
  final String description;
  final String category;
  final List<String> muscles;
  final List<String> musclesSecondary;
  final List<String> equipment;
  final List<String> images;

  FirebaseExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.muscles,
    required this.musclesSecondary,
    required this.equipment,
    required this.images,
  });

  factory FirebaseExercise.fromMap(Map<String, dynamic> map) {
    return FirebaseExercise(
      id: map['id'] ?? 0,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      muscles: List<String>.from(map['muscles'] ?? []),
      musclesSecondary: List<String>.from(map['muscles_secondary'] ?? []),
      equipment: List<String>.from(map['equipment'] ?? []),
      images: List<String>.from(map['images'] ?? []),
    );
  }
}

class LeaderboardFriendsPage extends StatelessWidget {
  const LeaderboardFriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'Friends Leaderboard',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF050c1a), Color(0xFF0A192F)],
          ),
        ),
        padding: EdgeInsets.all(16.0.r),
        child: Column(
          children: [
            Expanded(child: LeaderboardFriends()),
            // Bottom padding for floating navigation bar
            SizedBox(height: 120.rh),
          ],
        ),
      ),
    );
  }
}

class LeaderboardFriends extends StatefulWidget {
  const LeaderboardFriends({super.key});

  @override
  _LeaderboardFriendsState createState() => _LeaderboardFriendsState();
}

class _LeaderboardFriendsState extends State<LeaderboardFriends> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PageController _pageController = PageController(
    viewportFraction: 1.0,
    initialPage: 0,
  );

  // Default exercises (will be replaced by Firebase data)
  List<FirebaseExercise> exercises = [];
  bool isLoadingExercises = true;

  // Unit preferences
  String _userWeightUnit = 'kg';
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _loadUserUnitPreferences();
    _loadExercisesFromFirebase();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload exercises when dependencies change (e.g., after returning from selection page)
    _loadExercisesFromFirebase();
    // Also reload unit preferences in case they changed
    _loadUserUnitPreferences();
  }

  /// Load user unit preferences
  Future<void> _loadUserUnitPreferences() async {
    try {
      final weightUnit = await UnitPreferenceService.getWeightUnit();
      print('DEBUG: Friends leaderboard loaded weight unit: $weightUnit');
      if (mounted) {
        setState(() {
          _userWeightUnit = weightUnit;
          _refreshKey++; // Increment to force FutureBuilder refresh
        });
        print(
          'DEBUG: Friends leaderboard updated _userWeightUnit to: $_userWeightUnit, refreshKey: $_refreshKey',
        );
      }
    } catch (e) {
      print('Error loading unit preferences: $e');
    }
  }

  Future<void> _loadExercisesFromFirebase() async {
    setState(() {
      isLoadingExercises = true;
    });

    try {
      // Get exercises from cache or Firebase
      final exerciseDataList = await ExerciseCacheService.getExercises();

      // Convert to FirebaseExercise objects
      final List<FirebaseExercise> allExercises = [];
      for (var data in exerciseDataList) {
        allExercises.add(FirebaseExercise.fromMap(data));
      }

      // Load user's selected exercises
      final user = _auth.currentUser;
      List<FirebaseExercise> userSelectedExercises = [];

      if (user != null) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final selectedExerciseIds = List<int>.from(
            userData['leaderboardExercises'] ?? [],
          );

          // If user has no saved preferences, use default exercises
          if (selectedExerciseIds.isEmpty) {
            selectedExerciseIds.addAll([73, 83, 43, 20, 91, 167, 148]);
          }

          for (int id in selectedExerciseIds) {
            final exercise = allExercises.firstWhere(
              (e) => e.id == id,
              orElse:
                  () => FirebaseExercise(
                    id: id,
                    name: _getExerciseNameById(id),
                    description: '',
                    category: _getExerciseCategoryById(id),
                    muscles: [],
                    musclesSecondary: [],
                    equipment: [],
                    images: [],
                  ),
            );
            userSelectedExercises.add(exercise);
          }
        }
      }

      setState(() {
        exercises = userSelectedExercises;
        isLoadingExercises = false;
      });
    } catch (e) {
      print('Error loading exercises: $e');
      setState(() {
        isLoadingExercises = false;
      });
    }
  }

  String _getExerciseNameById(int id) {
    switch (id) {
      case 73:
        return 'Bench Press';
      case 83:
        return 'Bent Over Rowing';
      case 43:
        return 'Barbell Hack Squats';
      case 20:
        return 'Arnold Shoulder Press';
      case 91:
        return 'Biceps Curls With Barbell';
      case 167:
        return 'Crunches';
      case 148:
        return 'Calf Raises on Hackenschmitt Machine';
      default:
        return 'Unknown Exercise';
    }
  }

  String _getExerciseCategoryById(int id) {
    switch (id) {
      case 73:
        return 'Chest';
      case 83:
        return 'Back';
      case 43:
        return 'Legs';
      case 20:
        return 'Shoulders';
      case 91:
        return 'Arms';
      case 167:
        return 'Abs';
      case 148:
        return 'Calves';
      default:
        return 'Unknown';
    }
  }

  /// Fetch friends leaderboard data from new structure
  /// Fetches from friendsLeaderboard/{exerciseId}/months/{YYYY-MM} and filters by friends
  Future<List<LeaderboardEntry>> _fetchFriendsLeaderboardData(
    int exerciseId,
  ) async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      // Get current month in YYYY-MM format
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      // Fetch friend list
      final friendIds = await _fetchFriendList(userId);
      friendIds.add(userId); // Include current user

      // Fetch only docs we're allowed to read (self + friends) to satisfy Firestore rules
      final usersPath = 'friendsLeaderboard/$exerciseId/months/$monthKey/users';
      final List<LeaderboardEntry> friendsEntries = [];

      for (final entryUserId in friendIds) {
        final doc = await _firestore.doc('$usersPath/$entryUserId').get();
        if (!doc.exists) continue;
        final data = doc.data()!;
        friendsEntries.add(
          LeaderboardEntry(
            userId: entryUserId,
            firstName: data['firstName'] ?? '',
            lastName: data['lastName'] ?? '',
            userName: data['userName'] ?? '',
            profileImageUrl: data['profileImageUrl'] ?? '',
            maxWeight: (data['weight'] ?? 0.0).toDouble(), // Already in kg
            reps: data['reps'] ?? 0,
            weightCategory: '', // Not used for friends leaderboard
            userGender: '', // Not used for friends leaderboard
            userWeight: 0.0, // Not used for friends leaderboard
          ),
        );
      }

      // Sort by weight descending
      friendsEntries.sort((a, b) => b.maxWeight.compareTo(a.maxWeight));

      return friendsEntries;
    } catch (e) {
      print('Error fetching friends leaderboard data: $e');
      return [];
    }
  }

  /// Fetch the current user's friend list from the 'friends' subcollection
  Future<List<String>> _fetchFriendList(String userId) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('friends')
              .get();

      // Extract friend IDs from the 'friends' subcollection
      return querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            return data['friendId'] as String? ?? doc.id;
          })
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error fetching friend list: $e');
      return [];
    }
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

    if (isLoadingExercises) {
      return Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = _pageController.page! - index;
                    value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
                  }
                  return Center(
                    child: SizedBox(
                      height: Curves.easeOut.transform(value) * 600,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FutureBuilder<List<LeaderboardEntry>>(
                    key: ValueKey(
                      '${exercise.id}_${_userWeightUnit}_$_refreshKey',
                    ),
                    future: _fetchFriendsLeaderboardData(exercise.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      } else if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Failed to load leaderboard. Please try again.',
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(24.rw, 12.rh, 24.rw, 8),
                              child: Text(
                                exercise.name,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.fitness_center_rounded,
                                      size: 48,
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                    SizedBox(height: 16.rh),
                                    Text(
                                      'No Friends Data',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white.withOpacity(0.7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'You and your friends haven\'t recorded any lifts for this exercise this month',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        final leaderboardData = snapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(24.rw, 12.rh, 24.rw, 8),
                              child: Text(
                                exercise.name,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding: EdgeInsets.only(
                                  left: 24.rw,
                                  right: 24.rw,
                                  bottom: 8,
                                ),
                                itemCount: leaderboardData.length,
                                itemBuilder: (context, index) {
                                  final entry = leaderboardData[index];
                                  final isCurrentUser = entry.userId == userId;

                                  return Container(
                                    margin: EdgeInsets.only(bottom: 12.rh),
                                    decoration: BoxDecoration(
                                      color:
                                          isCurrentUser
                                              ? const Color(
                                                0xFF4361ee,
                                              ).withOpacity(0.1)
                                              : Colors.white.withOpacity(0.03),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color:
                                            isCurrentUser
                                                ? const Color(
                                                  0xFF4361ee,
                                                ).withOpacity(0.3)
                                                : Colors.white.withOpacity(
                                                  0.08,
                                                ),
                                      ),
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                        ),
                                        child: ClipOval(
                                          child:
                                              entry.profileImageUrl.isNotEmpty
                                                  ? Image.network(
                                                    entry.profileImageUrl,
                                                    fit: BoxFit.cover,
                                                    width: 48,
                                                    height: 48,
                                                    errorBuilder: (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return Container(
                                                        width: 48,
                                                        height: 48,
                                                        color: Colors.grey[800],
                                                        child: Center(
                                                          child: Text(
                                                            '${entry.firstName.isNotEmpty ? entry.firstName[0] : ''}${entry.lastName.isNotEmpty ? entry.lastName[0] : ''}',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 20,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    loadingBuilder: (
                                                      context,
                                                      child,
                                                      loadingProgress,
                                                    ) {
                                                      if (loadingProgress ==
                                                          null)
                                                        return child;
                                                      return Container(
                                                        width: 48,
                                                        height: 48,
                                                        color: Colors.grey[800],
                                                        child: Center(
                                                          child: CircularProgressIndicator(
                                                            value:
                                                                loadingProgress
                                                                            .expectedTotalBytes !=
                                                                        null
                                                                    ? loadingProgress
                                                                            .cumulativeBytesLoaded /
                                                                        loadingProgress
                                                                            .expectedTotalBytes!
                                                                    : null,
                                                            color: Colors.white,
                                                            strokeWidth: 2,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  )
                                                  : Container(
                                                    width: 48,
                                                    height: 48,
                                                    color: Colors.grey[800],
                                                    child: Center(
                                                      child: Text(
                                                        '${entry.firstName.isNotEmpty ? entry.firstName[0] : ''}${entry.lastName.isNotEmpty ? entry.lastName[0] : ''}',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                        ),
                                      ),
                                      title: Text(
                                        '${entry.firstName} ${entry.lastName}${isCurrentUser ? ' (You)' : ''}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '@${entry.userName}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            UnitConverter.formatWeight(
                                              UnitConverter.convertWeightFromKg(
                                                entry.maxWeight,
                                                _userWeightUnit,
                                              ),
                                              _userWeightUnit,
                                            ),
                                            style: TextStyle(
                                              color: Color(0xFF4895ef),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            '${entry.reps} rep${entry.reps != 1 ? 's' : ''}',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.6,
                                              ),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class LeaderboardEntry {
  final String userId;
  final String firstName;
  final String lastName;
  final String userName;
  final String profileImageUrl;
  final double maxWeight;
  final int reps;
  final String weightCategory;
  final String userGender;
  final double userWeight;

  LeaderboardEntry({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.userName,
    required this.profileImageUrl,
    required this.maxWeight,
    required this.reps,
    required this.weightCategory,
    required this.userGender,
    required this.userWeight,
  });
}
