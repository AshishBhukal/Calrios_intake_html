import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitness2/features/extra/my_leaderboard_ranking_profile.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/services/unit_preference_service.dart';

class UserLeaderboardRankings extends StatefulWidget {
  final String userId;

  const UserLeaderboardRankings({super.key, required this.userId});

  @override
  State<UserLeaderboardRankings> createState() => _UserLeaderboardRankingsState();
}

class _UserLeaderboardRankingsState extends State<UserLeaderboardRankings> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _userWeightUnit = 'kg';
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _loadUserUnitPreferences();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload unit preferences in case they changed
    _loadUserUnitPreferences();
  }

  /// Load user unit preferences
  Future<void> _loadUserUnitPreferences() async {
    try {
      final weightUnit = await UnitPreferenceService.getWeightUnit();
      if (mounted) {
        setState(() {
          _userWeightUnit = weightUnit;
          _refreshKey++; // Increment to force FutureBuilder refresh
        });
      }
    } catch (e) {
      print('Error loading unit preferences: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      key: ValueKey('my_rankings_${_userWeightUnit}_$_refreshKey'),
      stream: _firestore.collection('users').doc(widget.userId).snapshots(),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (profileSnapshot.hasError || !profileSnapshot.hasData || !profileSnapshot.data!.exists) {
          return Center(
            child: Text('Failed to load profile. Please try again.',
              style: const TextStyle(color: Colors.white)),
          );
        }

        final userProfile = profileSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        final userGender = userProfile['gender'] ?? '';
        final bodyWeight = (userProfile['weight'] as num?)?.toDouble() ?? 0.0;
        
        if (userGender.isEmpty || bodyWeight <= 0) {
          return Center(
            child: Text(
              'Gender or body weight not set in profile. Please update your profile.',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          );
        }
        
        final weightCategory = _calculateWeightCategory(bodyWeight);
        final monthKey = _getCurrentMonthKey();
        
        print('My Rankings: Profile data - bodyWeight=${bodyWeight}kg, gender=$userGender, weightCategory=$weightCategory');

        // Fetch rankings from new structure
        return FutureBuilder<List<Map<String, dynamic>>>(
          key: ValueKey('rankings_$weightCategory\_$userGender'),
          future: _fetchMyRankings(weightCategory, userGender, monthKey),
          builder: (context, rankSnapshot) {
            if (rankSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (rankSnapshot.hasError) {
              return Center(
                child: Text('Failed to calculate rankings. Please try again.',
                  style: const TextStyle(color: Colors.white)),
              );
            }

            if (!rankSnapshot.hasData || rankSnapshot.data!.isEmpty) {
              return _buildNoRankingsWidget();
            }

            final rankings = rankSnapshot.data!;
            rankings.sort((a, b) => a['rank'].compareTo(b['rank']));

            return Column(
              children: rankings.map((ranking) => _buildRankingCard(context, ranking)).toList(),
            );
          },
        );
      },
    );
  }


  /// Calculate weight category from body weight (in kg)
  String _calculateWeightCategory(double bodyWeight) {
    if (bodyWeight < 60) {
      return "<60";
    } else if (bodyWeight < 67) {
      return "60-67";
    } else if (bodyWeight < 75) {
      return "67-75";
    } else if (bodyWeight < 82) {
      return "75-82";
    } else if (bodyWeight < 90) {
      return "82-90";
    } else if (bodyWeight < 100) {
      return "90-100";
    } else if (bodyWeight < 110) {
      return "100-110";
    } else {
      return "110+";
    }
  }

  /// Get current month key in YYYY-MM format
  String _getCurrentMonthKey() {
    final now = DateTime.now();
    final year = now.year;
    final month = (now.month).toString().padLeft(2, '0');
    return '$year-$month';
  }

  /// Fetch exercise name by ID
  Future<String> _getExerciseName(int exerciseId) async {
    try {
      final doc = await _firestore.collection('exercises').doc(exerciseId.toString()).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['name'] ?? 'Exercise $exerciseId';
      }
      return 'Exercise $exerciseId';
    } catch (e) {
      return 'Exercise $exerciseId';
    }
  }

  /// Fetch my rankings from new leaderboard structure
  Future<List<Map<String, dynamic>>> _fetchMyRankings(
    String weightCategory,
    String gender,
    String monthKey,
  ) async {
    final List<Map<String, dynamic>> rankings = [];
    
    try {
      print('My Rankings: Fetching for userId: ${widget.userId}, weightCategory: $weightCategory, gender: $gender, month: $monthKey');
      
      final categoryId = '${weightCategory}_$gender';
      
      // FASTEST APPROACH: Only check user's selected leaderboard exercises
      // These are the exercises they care about tracking (typically 7 exercises)
      // Use server source to bypass cache and get fresh data
      final userDoc = await _firestore.collection('users').doc(widget.userId).get(const GetOptions(source: Source.server));
      final userData = userDoc.data();
      
      List<int> exercisesToCheck = [];
      
      if (userData != null && userData.containsKey('leaderboardExercises')) {
        exercisesToCheck = List<int>.from(userData['leaderboardExercises'] ?? []);
      }
      
      // If user hasn't selected any exercises, use defaults
      if (exercisesToCheck.isEmpty) {
        exercisesToCheck = [73, 83, 43, 20, 91, 167, 148]; // Default 7 exercises
      }
      
      print('My Rankings: Checking ${exercisesToCheck.length} selected exercises for leaderboard entries');
      
      // Now check only these specific exercises for leaderboard entries
      for (var exerciseId in exercisesToCheck) {
        // Path to user's entry for this exercise
        final entryPath = 'leaderboards/$exerciseId/months/$monthKey/categories/$categoryId/entries/${widget.userId}';
        
        // Use server source to bypass cache
        final entryDoc = await _firestore.doc(entryPath).get(const GetOptions(source: Source.server));
        
        if (!entryDoc.exists) {
          continue;
        }
        
        // Get user's entry data
        final entryData = entryDoc.data();
        if (entryData == null) {
          continue;
        }
        
        final userWeight = (entryData['weight'] as num?)?.toDouble();
        final timestamp = entryData['timestamp'] as Timestamp?;
        
        if (userWeight == null) {
          continue;
        }
        
        print('My Rankings: Found entry for exercise $exerciseId with weight $userWeight kg');
        
        // Get the category document to find user's rank
        final categoryPath = 'leaderboards/$exerciseId/months/$monthKey/categories/$categoryId';
        // Use server source to bypass cache
        final categoryDoc = await _firestore.doc(categoryPath).get(const GetOptions(source: Source.server));
        
        int userRank = 0; // Default rank if not in top10
        
        if (categoryDoc.exists) {
          final categoryData = categoryDoc.data();
          final top10 = categoryData?['top10'] as List<dynamic>? ?? [];
          
          // Find user's rank in top10
          bool foundInTop10 = false;
          for (int i = 0; i < top10.length; i++) {
            final entry = top10[i] as Map<String, dynamic>;
            if (entry['userId'] == widget.userId) {
              userRank = entry['rank'] ?? (i + 1);
              foundInTop10 = true;
              break;
            }
          }
          
          // If not in top10, calculate rank by counting entries with higher weight
          if (!foundInTop10) {
            // Get all entries to calculate rank
            // Use server source to bypass cache
            final entriesSnapshot = await _firestore
                .collection('leaderboards/$exerciseId/months/$monthKey/categories/$categoryId/entries')
                .get(const GetOptions(source: Source.server));
            
            int higherWeightCount = 0;
            for (var doc in entriesSnapshot.docs) {
              final data = doc.data();
              final weight = (data['weight'] as num?)?.toDouble() ?? 0.0;
              if (weight > userWeight) {
                higherWeightCount++;
              }
            }
            userRank = higherWeightCount + 1;
          }
        }
        
        final exerciseName = await _getExerciseName(exerciseId);
        final weightInUserUnit = UnitConverter.convertWeightFromKg(userWeight, _userWeightUnit);
        
        rankings.add({
          'exercise': exerciseName,
          'exerciseId': exerciseId,
          'rank': userRank,
          'weight': weightInUserUnit,
          'weightInKg': userWeight,
          'timestamp': timestamp,
          'monthKey': monthKey,
          'weightCategory': weightCategory,
          'gender': gender,
        });
        
        print('My Rankings: Added $exerciseName - Rank #$userRank with $weightInUserUnit');
      }
      
      print('My Rankings: Successfully loaded ${rankings.length} ranking(s)');
    } catch (e) {
      print('Error fetching my rankings: $e');
    }
    
    return rankings;
  }

  Widget _buildNoRankingsWidget() {
    return Container(
      padding: EdgeInsets.all(20.r),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.leaderboard_outlined,
              size: 48,
              color: Colors.white.withOpacity(0.4),
            ),
            SizedBox(height: 12.rh),
            Text(
              'No Rankings Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start logging workouts to see your rankings',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRecentRankingsWidget() {
    return Container(
      padding: EdgeInsets.all(20.r),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 48,
              color: Colors.white.withOpacity(0.4),
            ),
            SizedBox(height: 12.rh),
            Text(
              'No Recent Rankings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No rankings found in the last 30 days',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingCard(BuildContext context, Map<String, dynamic> ranking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MyLeaderboardRankingProfile(
                  userId: widget.userId,
                  exerciseId: ranking['exerciseId'],
                  exercise: ranking['exercise'],
                  rank: ranking['rank'],
                  weight: ranking['weight'],
                  monthKey: ranking['monthKey'],
                  ageGroup: ranking['weightCategory'],
                  gender: ranking['gender'],
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
            decoration: BoxDecoration(
              border: ranking['rank'] != null ? 
                Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)) : null,
            ),
            child: Row(
              children: [
                // Rank Badge
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: Text(
                      '${ranking['rank']}',
                      style: TextStyle(
                        color: _getRankColor(ranking['rank']),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.rw),
                // Exercise Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ranking['exercise'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (ranking['timestamp'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _formatDate(ranking['timestamp'].toDate()),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Weight Score
                Text(
                  UnitConverter.formatWeight(ranking['weight'], _userWeightUnit),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4cc9f0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1: return const Color(0xFFFFD700); // Gold
      case 2: return const Color(0xFFC0C0C0); // Silver
      case 3: return const Color(0xFFCD7F32); // Bronze
      default: return Colors.white;
    }
  }
}