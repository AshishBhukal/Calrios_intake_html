import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

class LeaderboardExerciseSelectionPage extends StatefulWidget {
  const LeaderboardExerciseSelectionPage({super.key});

  @override
  State<LeaderboardExerciseSelectionPage> createState() => _LeaderboardExerciseSelectionPageState();
}

class _LeaderboardExerciseSelectionPageState extends State<LeaderboardExerciseSelectionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<FirebaseExercise> allExercises = [];
  List<FirebaseExercise> selectedExercises = [];
  List<FirebaseExercise> filteredExercises = [];
  bool isLoading = true;
  String searchQuery = '';
  String selectedCategory = 'All Categories';
  String selectedEquipment = 'All Equipment';
  bool _selectedExercisesCollapsed = true;

  // Maximum number of exercises that can be selected
  static const int maxSelectedExercises = 10;

  // Design tokens from Polished theme
  static const Color _primary = Color(0xFF3B82F6);
  static const double _radiusCard = 16.0;
  static const double _radiusPill = 24.0;
  static const double _radiusButton = 12.0;

  @override
  void initState() {
    super.initState();
    _loadExercisesAndUserPreferences();
  }

  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan_leaderboard.txt ID f_9i0j1k_leaderboard
  Future<void> _loadExercisesAndUserPreferences() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get exercises from cache or Firebase
      final exerciseDataList = await ExerciseCacheService.getExercises();

      // Convert to FirebaseExercise objects
      final List<FirebaseExercise> exercises = [];
      for (var data in exerciseDataList) {
        exercises.add(FirebaseExercise.fromMap(data));
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
            final exercise = exercises.firstWhere(
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
        allExercises = exercises;
        selectedExercises = userSelectedExercises;
        filteredExercises = exercises;
        isLoading = false;
      });
      
      print('📦 Loaded ${allExercises.length} exercises from cache');
      print('User selected exercises: ${selectedExercises.map((e) => '${e.name} (${e.id})').join(', ')}');
      print('Filtered exercises: ${filteredExercises.length}');
      
      _filterExercises();
    } catch (e) {
      print('Error loading exercises: $e');
      setState(() {
        isLoading = false;
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

  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan_leaderboard.txt ID f_0j1k2l_leaderboard
  void _filterExercises() {
    setState(() {
      filteredExercises = allExercises.where((exercise) {
        final matchesSearch = exercise.name.toLowerCase().contains(searchQuery.toLowerCase());
        final matchesCategory = selectedCategory == 'All Categories' || exercise.category == selectedCategory;
        final matchesEquipment = selectedEquipment == 'All Equipment' || 
            exercise.equipment.any((e) => e.toLowerCase().contains(selectedEquipment.toLowerCase()));
        
        return matchesSearch && matchesCategory && matchesEquipment;
      }).toList();
    });
  }

  void _toggleExerciseSelection(FirebaseExercise exercise) {
    print('Toggling exercise: ${exercise.name} (ID: ${exercise.id})');
    print('Currently selected: ${selectedExercises.map((e) => '${e.name} (${e.id})').join(', ')}');
    
    setState(() {
      if (selectedExercises.any((e) => e.id == exercise.id)) {
        // Remove exercise if already selected
        print('Removing exercise: ${exercise.name}');
        selectedExercises.removeWhere((e) => e.id == exercise.id);
      } else {
        // Add exercise if not selected and under limit
        if (selectedExercises.length < maxSelectedExercises) {
          print('Adding exercise: ${exercise.name}');
          selectedExercises.add(exercise);
        } else {
          print('Cannot add exercise: limit reached');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You can only select up to $maxSelectedExercises exercises'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    });
    
    print('After toggle - Selected: ${selectedExercises.map((e) => '${e.name} (${e.id})').join(', ')}');
  }

  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan_leaderboard.txt ID f_1k2l3m_leaderboard
  Future<void> _saveUserPreferences() async {
    if (selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one exercise'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({
          'leaderboardExercises': selectedExercises.map((e) => e.id).toList(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exercise preferences saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Return to leaderboard with updated exercises
        Navigator.pop(context, selectedExercises);
      }
    } catch (e) {
      print('Error saving user preferences: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save preferences. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<String> _getUniqueCategories() {
    final categories = allExercises.map((e) => e.category).toSet().toList();
    categories.sort();
    return ['All Categories', ...categories];
  }

  List<String> _getUniqueEquipment() {
    final equipment = <String>{};
    for (var exercise in allExercises) {
      equipment.addAll(exercise.equipment);
    }
    final equipmentList = equipment.toList()..sort();
    return ['All Equipment', ...equipmentList];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background_1.png'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Custom header – Polished theme
                    Padding(
                      padding: EdgeInsets.fromLTRB(12.rw, 8, 20.rw, 12.rh),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Select Leaderboard',
                                  style: TextStyle(
                                    color: Color(0xFFF1F5F9),
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Manage your preferences',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: _primary,
                            borderRadius: BorderRadius.circular(_radiusPill),
                            child: InkWell(
                              onTap: _saveUserPreferences,
                              borderRadius: BorderRadius.circular(_radiusPill),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 24.rw, vertical: 10),
                                child: const Text(
                                  'Save',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Selected exercises section (collapsible like routine creator)
                    if (selectedExercises.isNotEmpty)
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 16.rw),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(_radiusCard),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedExercisesCollapsed = !_selectedExercisesCollapsed;
                                });
                              },
                              borderRadius: BorderRadius.circular(_radiusCard),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 12.rh),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: _primary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'SELECTED EXERCISES (${selectedExercises.length}/$maxSelectedExercises)',
                                      style: TextStyle(
                                        color: _primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedExercisesCollapsed = !_selectedExercisesCollapsed;
                                        });
                                      },
                                      child: Text(
                                        _selectedExercisesCollapsed ? 'Show' : 'Hide',
                                        style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!_selectedExercisesCollapsed)
                              Padding(
                                padding: EdgeInsets.only(left: 16.rw, right: 16.rw, bottom: 12.rh),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: selectedExercises.map((exercise) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _primary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(_radiusPill),
                                        border: Border.all(color: _primary.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            exercise.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          GestureDetector(
                                            onTap: () => _toggleExerciseSelection(exercise),
                                            child: Icon(Icons.close, color: Colors.white.withOpacity(0.85), size: 16),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (selectedExercises.isNotEmpty) SizedBox(height: 16.rh),
                    
                    // Search and filter section
                    Container(
                      padding: EdgeInsets.all(16.r),
                      child: Column(
                        children: [
                          // Search bar
                          TextField(
                            onChanged: (value) {
                              setState(() => searchQuery = value);
                              _filterExercises();
                            },
                            decoration: InputDecoration(
                              hintText: 'Search exercises...',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                              prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5), size: 22),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 14.rh),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(_radiusCard),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(_radiusCard),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(_radiusCard),
                                borderSide: const BorderSide(color: _primary, width: 1.5),
                              ),
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          
                          SizedBox(height: 14.rh),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    setState(() => selectedCategory = value);
                                    _filterExercises();
                                  },
                                  itemBuilder: (context) => _getUniqueCategories()
                                      .map((c) => PopupMenuItem(value: c, child: Text(c)))
                                      .toList(),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(_radiusButton),
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.filter_list, color: Colors.white.withOpacity(0.7), size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          selectedCategory,
                                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.7), size: 20),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    setState(() => selectedEquipment = value);
                                    _filterExercises();
                                  },
                                  itemBuilder: (context) => _getUniqueEquipment()
                                      .map((e) => PopupMenuItem(value: e, child: Text(e)))
                                      .toList(),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(_radiusButton),
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.fitness_center, color: Colors.white.withOpacity(0.7), size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          selectedEquipment,
                                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.7), size: 20),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Exercise list
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16.rw),
                        itemCount: filteredExercises.length,
                        itemBuilder: (context, index) {
                      final exercise = filteredExercises[index];
                      final isSelected = selectedExercises.any((e) => e.id == exercise.id);
                      final muscleText = exercise.muscles.isNotEmpty
                          ? exercise.muscles.join(', ')
                          : exercise.category;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _primary.withOpacity(0.1)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(_radiusCard),
                          border: Border.all(
                            color: isSelected
                                ? _primary.withOpacity(0.2)
                                : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _toggleExerciseSelection(exercise),
                            borderRadius: BorderRadius.circular(_radiusCard),
                            child: Padding(
                              padding: EdgeInsets.all(16.r),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _primary.withOpacity(0.2)
                                          : Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(_radiusButton),
                                      border: isSelected ? null : Border.all(color: Colors.white.withOpacity(0.05)),
                                    ),
                                    child: Icon(
                                      isSelected ? Icons.fitness_center : Icons.directions_run,
                                      color: isSelected ? _primary : Colors.white.withOpacity(0.5),
                                      size: 24,
                                    ),
                                  ),
                                  SizedBox(width: 16.rw),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          exercise.name,
                                          style: const TextStyle(
                                            color: Color(0xFFE2E8F0),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _primary,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'SELECTED',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 2),
                                        Text(
                                          muscleText,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12.rw),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isSelected ? _primary : Colors.white.withOpacity(0.05),
                                      shape: BoxShape.circle,
                                      border: isSelected ? null : Border.all(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    child: Icon(
                                      isSelected ? Icons.check : Icons.add,
                                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                                      size: 18,
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
              },
            ),
          ),
        ),
      ),
    );
  }
}
