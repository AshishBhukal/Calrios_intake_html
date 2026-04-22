import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitness2/features/extra/leaderboard_player_profile.dart';
import 'package:fitness2/leaderboard_widgets/leaderboard_exercise_selection.dart';
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

class LeaderboardGlobalPage extends StatelessWidget {
  const LeaderboardGlobalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Leaderboard', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          // More prominent button as backup
          IconButton(
            icon: const Icon(Icons.fitness_center, color: Colors.white, size: 24),
            tooltip: 'Change Exercises',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LeaderboardExerciseSelectionPage(),
                ),
              );
              
              if (result != null) {
                // The exercises will be reloaded when the user navigates back
                // The LeaderboardGlobal widget will automatically refresh
              }
            },
          ),
          // Three-dot menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
            tooltip: 'More Options',
            onSelected: (value) async {
              if (value == 'change_exercises') {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LeaderboardExerciseSelectionPage(),
                  ),
                );
                
                if (result != null) {
                  // The exercises will be reloaded when the user navigates back
                  // The LeaderboardGlobal widget will automatically refresh
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'change_exercises',
                child: Row(
                  children: [
                    const Icon(Icons.fitness_center, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text('Change Exercises'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF050c1a),
              Color(0xFF0A192F),
            ],
          ),
        ),
        padding: EdgeInsets.all(16.0.r),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                indicatorColor: const Color(0xFF4361ee),
                labelColor: const Color(0xFF4361ee),
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Global'),
                  Tab(text: 'Friends'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    LeaderboardGlobal(),
                    Center(
                      child: Text(
                        'Friends Leaderboard (Coming Soon)',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom padding for floating navigation bar
              SizedBox(height: 120.rh),
            ],
          ),
        ),
      ),
    );
  }
}

class LeaderboardGlobal extends StatefulWidget {
  const LeaderboardGlobal({super.key});

  @override
  _LeaderboardGlobalState createState() => _LeaderboardGlobalState();
}

class _LeaderboardGlobalState extends State<LeaderboardGlobal> {
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
      print('DEBUG: Loaded weight unit: $weightUnit');
      if (mounted) {
        setState(() {
          _userWeightUnit = weightUnit;
          _refreshKey++; // Increment to force FutureBuilder refresh
        });
        print('DEBUG: Updated _userWeightUnit to: $_userWeightUnit, refreshKey: $_refreshKey');
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
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final selectedExerciseIds = List<int>.from(userData['leaderboardExercises'] ?? []);
          
          // If user has no saved preferences, use default exercises
          if (selectedExerciseIds.isEmpty) {
            selectedExerciseIds.addAll([73, 83, 43, 20, 91, 167, 148]);
          }
          
          for (int id in selectedExerciseIds) {
            final exercise = allExercises.firstWhere(
              (e) => e.id == id,
              orElse: () => FirebaseExercise(
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

  /// Calculate age from date of birth
  int? _calculateAge(Map<String, dynamic> dob) {
    if (dob['year'] == null || dob['month'] == null || dob['day'] == null) {
      return null;
    }
    
    try {
      final birthYear = int.parse(dob['year'].toString());
      final birthMonth = int.parse(dob['month'].toString());
      final birthDay = int.parse(dob['day'].toString());
      
      final now = DateTime.now();
      final birthDate = DateTime(birthYear, birthMonth, birthDay);
      
      int age = now.year - birthDate.year;
      final monthDiff = now.month - birthDate.month;
      
      if (monthDiff < 0 || (monthDiff == 0 && now.day < birthDate.day)) {
        age--;
      }
      
      return age;
    } catch (e) {
      return null;
    }
  }

  /// Calculate age group from age (5-year intervals)
  String _calculateAgeGroup(int age) {
    if (age < 15) {
      return "15-19";
    }
    
    final baseAge = (age ~/ 5) * 5;
    final upperAge = baseAge + 4;
    
    // Handle 60+
    if (baseAge >= 60) {
      return "60+";
    }
    
    return "$baseAge-$upperAge";
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


  /// Fetch leaderboard data from new structure (monthly)
  /// Fetches from leaderboards/{exerciseId}/months/{YYYY-MM}/categories/{weightCategory}_{gender}/top10
  Future<List<LeaderboardEntry>> _fetchLeaderboardData(
    int exerciseId,
    String weightCategory,
    String gender,
  ) async {
    try {
      // Get current month in YYYY-MM format
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      // Firestore path: leaderboards/{exerciseId}/months/{YYYY-MM}/categories/{weightCategory}_{gender}
      final categoryId = '${weightCategory}_$gender';
      final leaderboardPath = 'leaderboards/$exerciseId/months/$monthKey/categories/$categoryId';
      
      print('Fetching leaderboard: exercise=$exerciseId, weightCategory=$weightCategory, gender=$gender, path=$leaderboardPath');
      
      // Use server source to bypass cache and get fresh data
      final doc = await _firestore.doc(leaderboardPath).get(const GetOptions(source: Source.server));
      
      if (!doc.exists) {
        return [];
      }
      
      final data = doc.data();
      final top10 = data?['top10'] as List<dynamic>? ?? [];
      
      return top10.map((entry) {
        final entryMap = Map<String, dynamic>.from(entry as Map);
        return LeaderboardEntry(
          userId: entryMap['userId'] ?? '',
          userName: entryMap['userName'] ?? '',
          firstName: entryMap['firstName'] ?? '',
          lastName: entryMap['lastName'] ?? '',
          age: entryMap['age'] ?? 0,
          weight: (entryMap['weight'] ?? 0.0).toDouble(), // Already in kg
          profileImageUrl: entryMap['profileImageUrl'] ?? '',
        );
      }).toList();
    } catch (e) {
      print('Error fetching leaderboard data: $e');
      return [];
    }
  }

  Color _getBadgeColor(int rank) {
    switch (rank) {
      case 1:
        return Color(0xFFFFD700);
      case 2:
        return Color(0xFFC0C0C0);
      case 3:
        return Color(0xFFCD7F32);
      default:
        return Colors.transparent;
    }
  }

  List<Color> _getRankGradient(int rank) {
    switch (rank) {
      case 1:
        return [Color(0xFFFFD700), Color(0xFFFFC600)];
      case 2:
        return [Color(0xFFC0C0C0), Color(0xFFA0A0A0)];
      case 3:
        return [Color(0xFFCD7F32), Color(0xFFB56C28)];
      default:
        return [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.1)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = _auth.currentUser?.uid;

    if (userId == null) {
      return Center(child: Text('User not logged in', style: TextStyle(color: Colors.white)));
    }

    if (isLoadingExercises) {
      return Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(userId).snapshots(),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Colors.white));
        } else if (profileSnapshot.hasError) {
          return Center(child: Text('Failed to load profile. Please try again.', style: TextStyle(color: Colors.white)));
        } else if (!profileSnapshot.hasData || !profileSnapshot.data!.exists) {
          return Center(child: Text('User profile not found', style: TextStyle(color: Colors.white)));
        } else {
          final userProfile = profileSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          final userGender = userProfile['gender'] ?? '';
          final bodyWeight = (userProfile['weight'] as num?)?.toDouble() ?? 0.0;
          
          if (userGender.isEmpty || bodyWeight <= 0) {
            return Center(
              child: Text(
                'Gender or body weight not set in profile. Please update your profile.',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            );
          }
          
          final weightCategory = _calculateWeightCategory(bodyWeight);
          
          // Debug print to track profile changes
          print('LeaderboardGlobal: Profile data - bodyWeight=${bodyWeight}kg, gender=$userGender, weightCategory=$weightCategory');

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
                          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
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
                          key: ValueKey('${exercise.id}_$weightCategory\_$userGender'),
                          future: _fetchLeaderboardData(exercise.id, weightCategory, userGender),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: Colors.white));
                            } else if (snapshot.hasError) {
                              return Center(child: Text('Failed to load leaderboard. Please try again.', style: TextStyle(color: Colors.white)));
                            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(24.rw, 12.rh, 24.rw, 8),
                                    child: Text(
                                      exercise.name,
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
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
                                            'No Rankings Yet',
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.white.withOpacity(0.7),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'No one has recorded a 1-rep max for this exercise this month',
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
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
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
                                        final data = leaderboardData[index];
                                        final rank = index + 1;
                                        final isCurrentUser = data.userId == userId;
                                        
                                        return Container(
                                          height: 80,
                                          margin: const EdgeInsets.only(bottom: 8),
                                          decoration: BoxDecoration(
                                            color: isCurrentUser 
                                                ? const Color(0xFF4361ee).withOpacity(0.1)
                                                : Colors.white.withOpacity(0.03),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isCurrentUser 
                                                  ? const Color(0xFF4361ee).withOpacity(0.3)
                                                  : Colors.white.withOpacity(0.08),
                                            ),
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(12),
                                              onTap: () {
                                                // Get current month key
                                                final now = DateTime.now();
                                                final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
                                                
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => LeaderboardPlayerProfile(
                                                      userId: data.userId,
                                                      exerciseId: exercise.id,
                                                      monthKey: monthKey,
                                                      ageGroup: weightCategory,
                                                      gender: userGender,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Padding(
                                                padding: EdgeInsets.all(16.r),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        gradient: rank <= 3 ? LinearGradient(
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                          colors: _getRankGradient(rank),
                                                        ) : null,
                                                        color: rank > 3 ? Colors.white.withOpacity(0.1) : null,
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          '$rank',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.w600,
                                                            color: rank <= 3 ? Colors.black : Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 16.rw),
                                                    Stack(
                                                      alignment: Alignment.center,
                                                      children: [
                                                        // Profile picture
                                                        Container(
                                                          width: 48,
                                                          height: 48,
                                                          decoration: BoxDecoration(
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: ClipOval(
                                                            child: data.profileImageUrl.isNotEmpty
                                                                ? Image.network(
                                                                    data.profileImageUrl,
                                                                    fit: BoxFit.cover,
                                                                    width: 48,
                                                                    height: 48,
                                                                    errorBuilder: (context, error, stackTrace) {
                                                                      return Image.asset(
                                                                        'assets/default_profile.png',
                                                                        fit: BoxFit.cover,
                                                                        width: 48,
                                                                        height: 48,
                                                                      );
                                                                    },
                                                                    loadingBuilder: (context, child, loadingProgress) {
                                                                      if (loadingProgress == null) return child;
                                                                      return Container(
                                                                        width: 48,
                                                                        height: 48,
                                                                        color: Colors.grey[800],
                                                                        child: Center(
                                                                          child: CircularProgressIndicator(
                                                                            value: loadingProgress.expectedTotalBytes != null
                                                                                ? loadingProgress.cumulativeBytesLoaded /
                                                                                    loadingProgress.expectedTotalBytes!
                                                                                : null,
                                                                            color: Colors.white,
                                                                            strokeWidth: 2,
                                                                          ),
                                                                        ),
                                                                      );
                                                                    },
                                                                  )
                                                                : Image.asset(
                                                                    'assets/default_profile.png',
                                                                    fit: BoxFit.cover,
                                                                    width: 48,
                                                                    height: 48,
                                                                  ),
                                                          ),
                                                        ),
                                                        // Rank border (on top)
                                                        if (rank <= 3)
                                                          Container(
                                                            width: 48,
                                                            height: 48,
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              border: Border.all(
                                                                color: _getBadgeColor(rank),
                                                                width: 3,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    SizedBox(width: 16.rw),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Text(
                                                            '${data.firstName} ${data.lastName}${isCurrentUser ? ' (You)' : ''}',
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight: FontWeight.w500,
                                                              color: Colors.white,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          SizedBox(height: 4),
                                                          Text(
                                                            '@${data.userName}',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: Colors.white.withOpacity(0.6),
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      UnitConverter.formatWeight(UnitConverter.convertWeightFromKg(data.weight, _userWeightUnit), _userWeightUnit),
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF4895ef),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
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
      },
    );
  }
}

class LeaderboardEntry {
  final String userId;
  final String userName;
  final String firstName;
  final String lastName;
  final int age;
  final double weight;
  final String profileImageUrl;

  LeaderboardEntry({
    required this.userId,
    required this.userName,
    required this.firstName,
    required this.lastName,
    required this.age,
    required this.weight,
    required this.profileImageUrl,
  });
}
