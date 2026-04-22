import 'package:flutter/material.dart';
import 'dart:async';
import 'recipe_creator.dart' as rc;
import 'food.dart';
import '../services/firebase_service.dart';
import '../services/graph_cache_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../barcode_scanner_complete.dart';
import 'food_input_method_selector.dart';
import 'ai_image_food_analyzer.dart';
import '../models/food_analysis_result.dart';
import '../utils/app_logger.dart';
import '../services/unit_preference_service.dart';
import '../services/activity_service.dart';
import '../features/extra/constants.dart';

// Legacy FoodItem for backward compatibility
class FoodItem {
  final String id;
  final String name;
  final String icon;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final int healthStar; // 1-5 rating
  /// Nutri-Score grade (A–E) for barcode products; null for other sources.
  final String? nutritionGrade;

  FoodItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    this.sugar = 0,
    this.sodium = 0,
    this.healthStar = 3,
    this.nutritionGrade,
  });
}

class DailyTotals {
  int calories;
  double protein;
  double carbs;
  double fat;
  double fiber;
  double sugar;
  double sodium;

  DailyTotals({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.sugar = 0,
    this.sodium = 0,
  });

  void addFood(FoodItem food) {
    calories += food.calories;
    protein += food.protein;
    carbs += food.carbs;
    fat += food.fat;
    fiber += food.fiber;
    sugar += food.sugar;
    sodium += food.sodium;
  }

  void removeFood(FoodItem food) {
    calories = (calories - food.calories).clamp(0, double.maxFinite.toInt());
    protein = (protein - food.protein).clamp(0.0, double.maxFinite);
    carbs = (carbs - food.carbs).clamp(0.0, double.maxFinite);
    fat = (fat - food.fat).clamp(0.0, double.maxFinite);
    fiber = (fiber - food.fiber).clamp(0.0, double.maxFinite);
    sugar = (sugar - food.sugar).clamp(0.0, double.maxFinite);
    sodium = (sodium - food.sodium).clamp(0.0, double.maxFinite);
  }

  void reset() {
    calories = 0;
    protein = 0;
    carbs = 0;
    fat = 0;
    fiber = 0;
    sugar = 0;
    sodium = 0;
  }
}

class FoodEntry {
  final String id;
  final FoodItem food;
  final DateTime timestamp;
  final String? firebaseDocId; // Firebase document ID for deletion

  FoodEntry({
    required this.id,
    required this.food,
    required this.timestamp,
    this.firebaseDocId,
  });
}

class WaterIntakeOption {
  final String id;
  final String name;
  final double amount;
  final String unit; // 'mL' or 'L'
  final bool isDefault;

  WaterIntakeOption({
    required this.id,
    required this.name,
    required this.amount,
    required this.unit,
    this.isDefault = false,
  });

  double get amountInMl => unit == 'L' ? amount * 1000 : amount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'unit': unit,
      'isDefault': isDefault,
    };
  }

  factory WaterIntakeOption.fromMap(Map<String, dynamic> map) {
    return WaterIntakeOption(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'mL',
      isDefault: map['isDefault'] ?? false,
    );
  }
}

class Recipe {
  final String id;
  final String name;
  final String description;
  final List<FoodItem> ingredients;
  final String instructions;
  final DailyTotals totalNutrition;

  Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.ingredients,
    required this.instructions,
    required this.totalNutrition,
  });
}

class CaloriesInScreen extends StatefulWidget {
  const CaloriesInScreen({super.key});

  @override
  State<CaloriesInScreen> createState() => CaloriesInScreenState();
}

class CaloriesInScreenState extends State<CaloriesInScreen> {
  // State Management for Phase 3
  late DailyTotals dailyTotals;
  Map<String, dynamic> goals = {
    'calories': 2000,
    'protein': 110,
    'carbs': 50,
    'fat': 22,
    'fiber': 25,
  };

  // Water tracking system
  double waterIntake = 0.0; // in mL
  double waterGoal = 2000.0; // in mL, default 2L
  List<WaterIntakeOption> waterIntakeOptions = [];
  WaterIntakeOption? defaultIntakeOption;
  late final ValueNotifier<double> _waterIntakeNotifier;

  // Food log and recipes
  final List<FoodEntry> foodLog = [];
  final List<Recipe> recipes = [];

  // User's energy unit preference
  String _energyUnit = 'kcal';

  // Calorie behavior settings
  bool _caloriesRollIn = true;
  bool _deductCaloriesOut = true;
  int _rollInBonus = 0; // Extra calories from yesterday's deficit (max 200)
  double _caloriesBurnedToday = 0; // From calories out / activity service

  // Swipe-right-to-reveal delete: which entry is slid and how far (0.._slidableDeleteWidth)
  String? _slidableEntryId;
  double _slidableOffset = 0;
  static const double _slidableDeleteWidth = 72;

  // Loading states for skeleton/shimmer feedback
  bool _isLoadingData = true;
  bool _isLoadingMoreFoodLog = false;
  bool _hasMoreFoodLogEntries = true;
  DocumentSnapshot? _lastFoodLogDocument;
  static const int _foodLogPageSize = 20;

  @override
  void initState() {
    super.initState();
    dailyTotals = DailyTotals();
    _waterIntakeNotifier = ValueNotifier(waterIntake);
    _initializeWaterOptions();
    _loadDataFromFirebase();
    loadMacroGoals();
    _loadEnergyUnit();
    _loadCalorieBehaviorSettings();
  }

  // NOTE: loadMacroGoals() is called from initState() and externally via
  // GlobalKey when returning from CaloriesSettingsScreen. Removed from
  // didChangeDependencies to prevent excessive Firebase calls.

  void _initializeWaterOptions() {
    // Initialize default water intake options
    waterIntakeOptions = [
      WaterIntakeOption(id: '1', name: 'Small Glass', amount: 200, unit: 'mL'),
      WaterIntakeOption(
        id: '2',
        name: 'Regular Glass',
        amount: 250,
        unit: 'mL',
      ),
      WaterIntakeOption(id: '3', name: 'Large Glass', amount: 350, unit: 'mL'),
      WaterIntakeOption(id: '4', name: 'Water Bottle', amount: 500, unit: 'mL'),
      WaterIntakeOption(id: '5', name: 'Large Bottle', amount: 1, unit: 'L'),
    ];

    // Set default option
    defaultIntakeOption = waterIntakeOptions[1]; // Regular Glass
  }

  Future<void> _loadEnergyUnit() async {
    try {
      final unit = await UnitPreferenceService.getEnergyUnit();
      if (mounted) setState(() => _energyUnit = unit);
    } catch (_) {}
  }

  Future<void> _openRecipeCreator(BuildContext context) async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const rc.RecipeCreatorHomePage()));

    if (result is Map &&
        result['action'] == 'recipe_created' &&
        result['recipe'] is rc.Recipe) {
      final rcRecipe = result['recipe'] as rc.Recipe;

      // Convert rc.Recipe to local Recipe
      final ingredients =
          rcRecipe.ingredients
              .map(
                (si) => FoodItem(
                  id: si.ingredient.id.toString(),
                  name: si.ingredient.name,
                  icon: '🍽️',
                  calories: si.totalCalories.round(),
                  protein: si.totalProtein,
                  carbs: si.totalCarbs,
                  fat: si.totalFat,
                  fiber: 0,
                ),
              )
              .toList();

      final totals = DailyTotals(
        calories: rcRecipe.nutritionTotals['calories']!.round(),
        protein: rcRecipe.nutritionTotals['protein']!,
        carbs: rcRecipe.nutritionTotals['carbs']!,
        fat: rcRecipe.nutritionTotals['fat']!,
        fiber: rcRecipe.nutritionTotals['fiber'] ?? 0,
        sugar: rcRecipe.nutritionTotals['sugar'] ?? 0,
        sodium: rcRecipe.nutritionTotals['sodium'] ?? 0,
      );

      final newRecipe = Recipe(
        id: rcRecipe.id,
        name: rcRecipe.name,
        description: rcRecipe.description,
        ingredients: ingredients,
        instructions: rcRecipe.instructions,
        totalNutrition: totals,
      );

      if (mounted) {
        setState(() {
          recipes.add(newRecipe);
        });
      }

      // Save recipe to Firebase
      try {
        final recipeData = {
          'id': newRecipe.id,
          'name': newRecipe.name,
          'description': newRecipe.description,
          'instructions': newRecipe.instructions,
          'ingredients':
              newRecipe.ingredients
                  .map(
                    (food) => {
                      'id': food.id,
                      'name': food.name,
                      'icon': food.icon,
                      'calories': food.calories,
                      'protein': food.protein,
                      'carbs': food.carbs,
                      'fat': food.fat,
                      'fiber': food.fiber,
                    },
                  )
                  .toList(),
          'totalNutrition': {
            'calories': newRecipe.totalNutrition.calories,
            'protein': newRecipe.totalNutrition.protein,
            'carbs': newRecipe.totalNutrition.carbs,
            'fat': newRecipe.totalNutrition.fat,
            'fiber': newRecipe.totalNutrition.fiber,
            'sugar': newRecipe.totalNutrition.sugar,
            'sodium': newRecipe.totalNutrition.sodium,
          },
          'createdAt': Timestamp.fromDate(DateTime.now()),
        };

        await FirebaseService.saveRecipe(recipeData);
      } catch (e) {
        debugPrint('Error saving recipe to Firebase: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recipe "${newRecipe.name}" created'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // PageController for swipeable nutrition sections
  final PageController _nutritionPageController = PageController();
  int _currentNutritionPage = 0;

  @override
  void dispose() {
    _waterIntakeNotifier.dispose();
    _nutritionPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(color: Colors.transparent),
        child: _isLoadingData
            ? _buildSkeletonLoading()
            : SingleChildScrollView(
                child: Column(
                  children: [
                    // Header
                    _buildHeader(),

                    // Swipeable: Page 1 = Stats + Macros, Page 2 = Hydration + Sugar/Sodium
                    _buildSwipeableNutritionSection(),

                    // Food Log
                    _buildFoodLog(),

                    SizedBox(height: 80.rh), // Space for FAB
                  ],
                ),
              ),
      ),
      floatingActionButton: _isLoadingData ? null : _buildFloatingActionButton(),
    );
  }

  Widget _buildSwipeableNutritionSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 505, // Stats + full macros table, minimal extra space
          child: PageView(
            controller: _nutritionPageController,
            onPageChanged: (index) {
              setState(() => _currentNutritionPage = index);
            },
            children: [
              // Page 1: Stats Overview + Macros Breakdown
              SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildStatsOverview(),
                    _buildMacrosSection(),
                  ],
                ),
              ),
              // Page 2: Hydration + Sugar/Sodium
              SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildWaterSection(),
                    _buildSugarSodiumSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Page indicator dots – clear gap so they don't overlap the table
        _buildPageIndicator(),
      ],
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(2, (index) {
          final isActive = _currentNutritionPage == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF3B82F6)
                  : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  /// Safe daily limits (WHO/FDA guidelines): sugar 50g, sodium 2300mg.
  static const double _dailySugarLimitG = 50.0;
  static const double _dailySodiumLimitMg = 2300.0;

  Widget _buildSugarSodiumSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 12.rh),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Additional Nutrients',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
          ),
          SizedBox(height: 16.rh),
          Row(
            children: [
              // Sugar (with daily limit)
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.cake, color: Color(0xFFFBBF24), size: 28),
                      const SizedBox(height: 8),
                      Text(
                        '${dailyTotals.sugar.toStringAsFixed(1)} / ${_dailySugarLimitG.toInt()}g',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SUGAR (limit 50g/day)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withValues(alpha: 0.5),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.rw),
              // Sodium (with daily limit)
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.grain, color: Color(0xFF94A3B8), size: 28),
                      const SizedBox(height: 8),
                      Text(
                        '${dailyTotals.sodium.toStringAsFixed(0)} / ${_dailySodiumLimitMg.toInt()}mg',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SODIUM (limit 2300mg/day)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withValues(alpha: 0.5),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Skeleton shimmer loading state shown while Firebase data is loading
  Widget _buildSkeletonLoading() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.rw),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Stats skeleton: 2x2 grid
            Row(
              children: [
                Expanded(child: _buildSkeletonBox(height: 100, borderRadius: 24)),
                SizedBox(width: 12.rw),
                Expanded(child: _buildSkeletonBox(height: 100, borderRadius: 24)),
              ],
            ),
            SizedBox(height: 12.rh),
            Row(
              children: [
                Expanded(child: _buildSkeletonBox(height: 100, borderRadius: 24)),
                SizedBox(width: 12.rw),
                Expanded(child: _buildSkeletonBox(height: 100, borderRadius: 24)),
              ],
            ),
            SizedBox(height: 16.rh),
            // Macros section skeleton
            _buildSkeletonBox(height: 200, borderRadius: 24),
            SizedBox(height: 16.rh),
            // Food log skeleton
            _buildSkeletonBox(height: 250, borderRadius: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonBox({required double height, double borderRadius = 12}) {
    return _ShimmerBox(height: height, borderRadius: borderRadius);
  }

  Widget _buildHeader() {
    return const SizedBox(height: 8);
  }

  Widget _buildStatsOverview() {
    final protGoal = (goals['protein'] as num?)?.toInt() ?? 0;
    final carbsGoal = (goals['carbs'] as num?)?.toInt() ?? 0;
    final fatGoal = (goals['fat'] as num?)?.toInt() ?? 0;

    final calLeft = _getEffectiveCaloriesLeft();
    final protLeft = protGoal - dailyTotals.protein.toInt();
    final carbsLeft = carbsGoal - dailyTotals.carbs.toInt();
    final fatLeft = fatGoal - dailyTotals.fat.toInt();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.rw),
      child: Column(
        children: [
          Row(
            children: [
              // Calories Card (Large Gradient) - shows goal left (can go negative)
              Expanded(
                child: _buildGradientStatCard(
                  'Calories Left',
                  '$calLeft',
                  _energyUnit,
                  Icons.local_fire_department,
                  const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  isOver: calLeft < 0,
                ),
              ),
              SizedBox(width: 12.rw),
              // Protein Card - shows goal left (can go negative)
              Expanded(
                child: _buildMacroGlassCard(
                  'Protein Left',
                  '$protLeft',
                  'g',
                  Icons.fitness_center,
                  Colors.blue,
                  isOver: protLeft < 0,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.rh),
          Row(
            children: [
              // Carbs Card - shows goal left (can go negative)
              Expanded(
                child: _buildMacroGlassCard(
                  'Carbs Left',
                  '$carbsLeft',
                  'g',
                  Icons.bakery_dining,
                  Colors.amber,
                  isOver: carbsLeft < 0,
                ),
              ),
              SizedBox(width: 12.rw),
              // Fat Card - shows goal left (can go negative)
              Expanded(
                child: _buildMacroGlassCard(
                  'Fat Left',
                  '$fatLeft',
                  'g',
                  Icons.opacity,
                  Colors.pink,
                  isOver: fatLeft < 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradientStatCard(
    String label,
    String value,
    String unit,
    IconData icon,
    List<Color> gradientColors, {
    bool isOver = false,
  }) {
    final colors = isOver
        ? [const Color(0xFFDC2626), const Color(0xFFB91C1C)]
        : gradientColors;
    return Container(
      height: 100,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors[0].withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              icon,
              size: 56,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroGlassCard(
    String label,
    String value,
    String unit,
    IconData icon,
    Color accentColor, {
    bool isOver = false,
  }) {
    return Container(
      height: 100,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isOver
            ? Color.lerp(
                const Color(0xFF1E293B).withValues(alpha: 0.4),
                Colors.red.withValues(alpha: 0.25),
                0.2,
              )!
            : const Color(0xFF1E293B).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isOver
              ? Colors.red.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.1),
          width: isOver ? 1.5 : 1,
        ),
        boxShadow: isOver
            ? [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.15),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              icon,
              size: 56,
              color: accentColor.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacrosSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 12.rh),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Text(
            'Macronutrients',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
          ),
          SizedBox(height: 16.rh),
          _buildMacroItem(
            'Protein',
            dailyTotals.protein.toInt(),
            (goals['protein'] as num?)?.toInt() ?? 0,
            Colors.blue,
          ),
          SizedBox(height: 12.rh),
          _buildMacroItem(
            'Carbs',
            dailyTotals.carbs.toInt(),
            (goals['carbs'] as num?)?.toInt() ?? 0,
            Colors.amber,
          ),
          SizedBox(height: 12.rh),
          _buildMacroItem(
            'Fat',
            dailyTotals.fat.toInt(),
            (goals['fat'] as num?)?.toInt() ?? 0,
            Colors.pink,
          ),
          SizedBox(height: 12.rh),
          _buildMacroItem(
            'Fiber',
            dailyTotals.fiber.toInt(),
            (goals['fiber'] as num?)?.toInt() ?? 0,
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildMacroItem(String name, int current, int goal, Color color) {
    final percentage = (goal > 0) ? (current / goal).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            Text(
              '${current}g / ${goal}g',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaterSection() {
    final waterPercentage =
        (waterGoal > 0) ? (waterIntake / waterGoal).clamp(0.0, 1.0) : 0.0;
    final waterIntakeL = waterIntake / 1000;
    final waterGoalL = waterGoal / 1000;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 12.rh),
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hydration',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
          ),
          SizedBox(height: 16.rh),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.water_drop, color: Colors.blue, size: 28),
                    SizedBox(width: 12.rw),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              waterIntakeL.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4361ee),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'L',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/ ${waterGoalL.toStringAsFixed(1)}L',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _buildDefaultWaterButton(),
                  const SizedBox(width: 8),
                  _buildWaterOptionsButton(),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.rh),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: waterPercentage,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultWaterButton() {
    return GestureDetector(
      onTap: () {
        if (defaultIntakeOption != null) {
          AppLogger.log(
            'Adding water: ${defaultIntakeOption!.name} - ${defaultIntakeOption!.amountInMl}mL',
            tag: 'CaloriesIn',
          );
          setState(() {
            waterIntake += defaultIntakeOption!.amountInMl;
          });
          _waterIntakeNotifier.value = waterIntake;

          // Save water intake to Firebase
          _saveWaterIntakeToFirebase();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added ${defaultIntakeOption!.name} (${defaultIntakeOption!.amount}${defaultIntakeOption!.unit})',
              ),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 6),
        decoration: BoxDecoration(
          color: Color(0xFF4361ee),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          defaultIntakeOption != null
              ? '+${defaultIntakeOption!.amount}${defaultIntakeOption!.unit}'
              : '+',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildWaterOptionsButton() {
    return GestureDetector(
      onTap: () {
        _showWaterOptionsModal(context);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 6),
        decoration: BoxDecoration(
          color: Color(0xFF4895ef),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.edit, size: 16, color: Colors.white),
      ),
    );
  }

  Widget _buildFoodLog() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 12.rh),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Meals",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                '${foodLog.length} meal${foodLog.length != 1 ? 's' : ''} logged',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.rh),
          if (foodLog.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.rh),
              child: Text(
                'No meals logged yet today.\nTap + to add your first meal!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.5),
                  height: 1.5,
                ),
              ),
            ),
          ...foodLog.map((entry) => _buildFoodLogItemFromEntry(entry)),
          // Load More button (pagination)
          if (_hasMoreFoodLogEntries && foodLog.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _isLoadingMoreFoodLog
                  ? Padding(
                      padding: EdgeInsets.all(12.r),
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4361ee)),
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: _loadMoreFoodLogEntries,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 12.rh),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4361ee).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF4361ee).withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.expand_more, color: Color(0xFF4361ee), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Load More',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4361ee),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildFoodLogItemFromEntry(FoodEntry entry) {
    final hour = entry.timestamp.toLocal().hour;
    final minute = entry.timestamp.toLocal().minute;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final timeStr = '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $amPm';

    final isSlid = _slidableEntryId == entry.id;
    final offset = isSlid ? _slidableOffset : 0.0;

    return Container(
      key: Key(entry.id),
      margin: EdgeInsets.only(bottom: 12.rh),
      height: 140,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Delete action behind the card – only visible when card is slid right
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _slidableDeleteWidth,
            child: Material(
              color: const Color(0xFFEF4444).withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _removeFoodFromLog(entry),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.white, size: 28),
                      SizedBox(height: 4),
                      Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Card on top – slides right to reveal delete behind it
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () {
                if (offset > 0) {
                  setState(() => _slidableOffset = 0);
                }
              },
              onHorizontalDragStart: (_) {
                setState(() {
                  if (_slidableEntryId != entry.id) {
                    _slidableEntryId = entry.id;
                    _slidableOffset = 0;
                  }
                });
              },
              onHorizontalDragUpdate: (DragUpdateDetails details) {
                setState(() {
                  if (_slidableEntryId != entry.id) return;
                  _slidableOffset = (_slidableOffset + details.delta.dx).clamp(0.0, _slidableDeleteWidth);
                });
              },
              onHorizontalDragEnd: (DragEndDetails details) {
                setState(() {
                  if (_slidableEntryId != entry.id) return;
                  final v = details.velocity.pixelsPerSecond.dx;
                  if (v > 100 || _slidableOffset > _slidableDeleteWidth * 0.5) {
                    _slidableOffset = _slidableDeleteWidth;
                  } else {
                    _slidableOffset = 0;
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                transform: Matrix4.translationValues(offset, 0, 0),
                child: Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Food name + time badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              entry.food.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontFamily: 'Inter',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.6),
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Calories row with fire emoji
                      Row(
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.food.calories} calories',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.8),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Macros row with emojis + health stars
                      Row(
                        children: [
                          const Text('🍗', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 2),
                          Text(
                            '${entry.food.protein.toStringAsFixed(0)}g',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.7),
                              fontFamily: 'Inter',
                            ),
                          ),
                          SizedBox(width: 12.rw),
                          const Text('🌾', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 2),
                          Text(
                            '${entry.food.carbs.toStringAsFixed(0)}g',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.7),
                              fontFamily: 'Inter',
                            ),
                          ),
                          SizedBox(width: 12.rw),
                          const Text('🫐', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 2),
                          Text(
                            '${entry.food.fat.toStringAsFixed(0)}g',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.7),
                              fontFamily: 'Inter',
                            ),
                          ),
                          const Spacer(),
                          _buildHealthStarsOrGrade(entry.food),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _nutritionGradeColor(String grade) {
    switch (grade.toLowerCase()) {
      case 'a': return Colors.green;
      case 'b': return Colors.lightGreen;
      case 'c': return Colors.orange;
      case 'd': return Colors.red;
      case 'e': return Colors.red[900]!;
      default: return Colors.grey;
    }
  }

  Widget _buildHealthStarsOrGrade(FoodItem food) {
    if (food.nutritionGrade != null && food.nutritionGrade!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _nutritionGradeColor(food.nutritionGrade!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          food.nutritionGrade!.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }
    return _buildHealthStars(food.healthStar);
  }

  Widget _buildHealthStars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          size: 16,
          color: index < rating
              ? const Color(0xFFFBBF24)
              : Colors.white.withOpacity(0.15),
        );
      }),
    );
  }

  void _removeFoodFromLog(FoodEntry entry) async {
    setState(() {
      if (_slidableEntryId == entry.id) {
        _slidableEntryId = null;
        _slidableOffset = 0;
      }
      foodLog.removeWhere((item) => item.id == entry.id);
      dailyTotals.removeFood(entry.food);
    });

    // Delete from Firebase if we have the document ID
    if (entry.firebaseDocId != null) {
      try {
        await FirebaseService.deleteFoodLogEntry(entry.firebaseDocId!);
      } catch (e) {
        debugPrint('Error deleting food entry from Firebase: $e');
      }
    }

    // Save updated daily totals to Firebase
    await _saveDailyTotalsToFirebase();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed ${entry.food.name}'),
        backgroundColor: const Color(0xFFEF4444),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () async {
            setState(() {
              foodLog.insert(0, entry);
              dailyTotals.addFood(entry.food);
            });

            // Re-save to Firebase if undoing
            try {
              final entryData = {
                'food': {
                  'id': entry.food.id,
                  'name': entry.food.name,
                  'icon': entry.food.icon,
                  'calories': entry.food.calories,
                  'protein': entry.food.protein,
                  'carbs': entry.food.carbs,
                  'fat': entry.food.fat,
                  'fiber': entry.food.fiber,
                  'sugar': entry.food.sugar,
                  'sodium': entry.food.sodium,
                  'healthStar': entry.food.healthStar,
                  if (entry.food.nutritionGrade != null) 'nutritionGrade': entry.food.nutritionGrade,
                },
                'timestamp': Timestamp.fromDate(entry.timestamp),
              };

              await FirebaseService.saveFoodLogEntry(entryData);
              await _saveDailyTotalsToFirebase();
            } catch (e) {
              debugPrint('Error re-saving food entry to Firebase: $e');
            }
          },
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      margin: EdgeInsets.only(
        bottom: 100.rh,
      ), // Space for floating navigation bar
      constraints: BoxConstraints(maxHeight: 250),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Water button
          Container(
            margin: EdgeInsets.only(bottom: 12.rh),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4cc9f0), Color(0xFF4361ee)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF4cc9f0).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    if (defaultIntakeOption != null) {
                      AppLogger.log(
                        'FAB Adding water: ${defaultIntakeOption!.name} - ${defaultIntakeOption!.amountInMl}mL',
                        tag: 'CaloriesIn',
                      );
                      setState(() {
                        waterIntake += defaultIntakeOption!.amountInMl;
                      });
                      _waterIntakeNotifier.value = waterIntake;

                      // Save water intake to Firebase
                      _saveWaterIntakeToFirebase();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Added ${defaultIntakeOption!.name} (${defaultIntakeOption!.amount}${defaultIntakeOption!.unit})',
                          ),
                          backgroundColor: const Color(0xFF10B981),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.water_drop, color: Colors.white, size: 16),
                        if (defaultIntakeOption != null)
                          Text(
                            '${defaultIntakeOption!.amount}${defaultIntakeOption!.unit}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Scan Barcode mini FAB
          Container(
            margin: EdgeInsets.only(bottom: 12.rh),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF0A192F),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF4CC9F0).withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CC9F0).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _showBarcodeScanner(context, popFirst: false),
                  child: const Center(
                    child: Icon(Icons.qr_code_scanner, color: Color(0xFF4CC9F0), size: 22),
                  ),
                ),
              ),
            ),
          ),
          // Scan Food Photo mini FAB
          Container(
            margin: EdgeInsets.only(bottom: 12.rh),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF0A192F),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF4361EE).withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4361EE).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _showImageFoodAnalyzer(context, popFirst: false),
                  child: const Center(
                    child: Icon(Icons.photo_camera_outlined, color: Color(0xFF4361EE), size: 22),
                  ),
                ),
              ),
            ),
          ),
          // Plus button (opens full menu: Describe Food, From Recipe, etc.)
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4361ee), Color(0xFF4895ef)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF4361ee).withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () {
                  _showAddMenuModal(context);
                },
                child: Center(
                  child: Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  /// Called from top-plus button (any tab). Opens Add Food bottom sheet.
  void showAddMenu() {
    _showAddMenuModal(context);
  }

  void _showAddMenuModal(BuildContext context) {
    // Use parent (scaffold) context for all follow-up navigation so we don't
    // use the modal's context after it's dismissed (avoids black screen).
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return SafeArea(
          top: false,
          left: false,
          right: false,
          bottom: true,
          child: FoodInputMethodSelector(
            onScanFoodPhoto: () => _showImageFoodAnalyzer(parentContext),
            onScanBarcode: () => _showBarcodeScanner(parentContext),
            onDescribeFood: () => _showFoodSelectionModal(parentContext),
            onFromRecipe: () => _showRecipeSelectionModal(parentContext),
          ),
        );
      },
    );
  }

  void _showFoodSelectionModal(BuildContext context, {bool popFirst = true}) {
    if (popFirst) Navigator.of(context).pop(); // Close add menu if open
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return SafeArea(
          top: false,
          left: false,
          right: false,
          bottom: true,
          child: AIFoodInputModal(
            onFoodAnalyzed: (aiResponse) {
              AppLogger.log('AI food analyzed, adding directly to food log', tag: 'CaloriesIn');
              _addFoodToLog(aiResponse: aiResponse);
            },
          ),
        );
      },
    );
  }

  void _showBarcodeScanner(BuildContext context, {bool popFirst = true}) {
    if (popFirst) {
      Navigator.of(context).pop(); // Close add menu if open
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext ctx) => BarcodeScannerComplete(
              onProductSelected: (product, serving) => _addBarcodeProductToLog(product, serving),
              onProductNotFoundTryPhoto: () {
                Navigator.of(ctx).pop();
                _showImageFoodAnalyzer(context, popFirst: false);
              },
            ),
          ),
        );
      });
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => BarcodeScannerComplete(
          onProductSelected: (product, serving) => _addBarcodeProductToLog(product, serving),
          onProductNotFoundTryPhoto: () {
            Navigator.of(ctx).pop();
            _showImageFoodAnalyzer(context, popFirst: false);
          },
        ),
      ),
    );
  }

  void _showImageFoodAnalyzer(BuildContext context, {bool popFirst = true}) {
    if (popFirst) {
      Navigator.of(context).pop(); // Close add menu if open
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext ctx) => AIImageFoodAnalyzer(
              onAnalysisComplete: (result) => _addImageAnalysisResultToLog(result),
            ),
          ),
        ).then((_) {
          if (mounted) setState(() {});
        });
      });
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => AIImageFoodAnalyzer(
          onAnalysisComplete: (result) => _addImageAnalysisResultToLog(result),
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _addBarcodeProductToLog(OpenFoodFactsProduct product, ServingSize serving) async {
    final analyzedItem = AnalyzedFoodItem.fromBarcodeProduct(product, serving);
    await _addAnalyzedFoodToLog([analyzedItem], closeNavigator: true);
  }

  Future<void> _addImageAnalysisResultToLog(Map<String, dynamic> result) async {
    final foods = result['foods'] as List<dynamic>? ?? [];
    final analyzedItems = foods.toAnalyzedFoodItems();
    await _addAnalyzedFoodToLog(analyzedItems);
  }

  void _addFoodToLog({AIFoodResponse? aiResponse}) async {
    if (aiResponse == null) {
      debugPrint('Error: aiResponse is null');
      return;
    }
    final analyzedItems = aiResponse.toAnalyzedFoodItems();
    await _addAnalyzedFoodToLog(analyzedItems);
  }

  // ============================================================================
  // UNIFIED FOOD LOG ADDITION METHOD
  // ============================================================================

  /// Unified method to add analyzed food items to the log.
  /// This replaces the duplicate code in _addBarcodeProductToLog,
  /// _addImageAnalysisResultToLog, and _addFoodToLog.
  Future<void> _addAnalyzedFoodToLog(
    List<AnalyzedFoodItem> items, {
    bool closeNavigator = false,
  }) async {
    if (items.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No food items to add'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    int totalCalories = 0;

    for (final item in items) {
      final food = FoodItem(
        id: item.generateId(),
        name: item.name,
        icon: item.icon,
        calories: item.calories,
        protein: item.protein,
        carbs: item.carbs,
        fat: item.fat,
        fiber: item.fiber,
        sugar: item.sugar,
        sodium: item.sodium,
        healthStar: item.healthStar,
        nutritionGrade: item.nutritionGrade,
      );

      totalCalories += food.calories;

      final foodEntry = FoodEntry(
        id: food.id,
        food: food,
        timestamp: DateTime.now(),
        firebaseDocId: null,
      );

      if (mounted) {
        setState(() {
          foodLog.insert(0, foodEntry);
          dailyTotals.addFood(food);
        });
      }

      // Save to Firebase
      try {
        final entryData = {
          'food': {
            'id': food.id,
            'name': food.name,
            'icon': food.icon,
            'calories': food.calories,
            'protein': food.protein,
            'carbs': food.carbs,
            'fat': food.fat,
            'fiber': food.fiber,
            'sugar': food.sugar,
            'sodium': food.sodium,
            'healthStar': food.healthStar,
            if (food.nutritionGrade != null) 'nutritionGrade': food.nutritionGrade,
          },
          'timestamp': Timestamp.fromDate(foodEntry.timestamp),
        };
        await FirebaseService.saveFoodLogEntry(entryData);
      } catch (e) {
        debugPrint('Error saving food entry to Firebase: $e');
      }
    }

    // Save daily totals and invalidate cache
    await _saveDailyTotalsToFirebase();
    await GraphCacheService.invalidateCaloriesCache();

    // Show success message
    if (mounted) {
      if (closeNavigator) {
        Navigator.of(context).pop();
      }

      final itemCount = items.length;
      final source = items.first.source;
      final sourceText = _getSourceText(source);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            itemCount == 1
                ? 'Added ${items.first.name} ($totalCalories $_energyUnit) $sourceText'
                : 'Added $itemCount items ($totalCalories $_energyUnit) $sourceText',
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Get descriptive text for the food source
  String _getSourceText(FoodSource source) {
    switch (source) {
      case FoodSource.aiText:
        return 'from AI analysis';
      case FoodSource.aiImage:
        return 'from image';
      case FoodSource.barcode:
        return 'from barcode';
      case FoodSource.recipe:
        return 'from recipe';
    }
  }

  void _showWaterOptionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          top: false,
          left: false,
          right: false,
          bottom: true,
          child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0A192F), Colors.black],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 12.rh),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF4361ee),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.all(24.r),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Water Intake',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            _showWaterSettingsModal(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.settings,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Current total (updates instantly when adding)
              ValueListenableBuilder<double>(
                valueListenable: _waterIntakeNotifier,
                builder: (context, currentMl, _) {
                  final currentL = currentMl / 1000;
                  final goalL = waterGoal / 1000;
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.rw, vertical: 8.rh),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.water_drop, color: Color(0xFF4361ee), size: 20),
                        SizedBox(width: 8.rw),
                        Text(
                          'Current: ${currentL.toStringAsFixed(1)} L / ${goalL.toStringAsFixed(1)} L',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Water options list
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.rw),
                  child: Column(
                    children: [
                      // Custom water intake button at top
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: 16.rh),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showCustomWaterInputDialog(
                              context,
                              onAddWater: (amountInMl) {
                                this.setState(() {
                                  waterIntake += amountInMl;
                                });
                                _waterIntakeNotifier.value = waterIntake;
                              },
                            );
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text(
                            'Add Custom Water Intake',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4361ee),
                            padding: EdgeInsets.symmetric(vertical: 16.rh),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      // 2x2 Grid of predefined options
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.2,
                              ),
                          itemCount: waterIntakeOptions.length,
                          itemBuilder: (context, index) {
                            return _buildWaterOptionGridCard(
                              context,
                              waterIntakeOptions[index],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildWaterOptionGridCard(
    BuildContext context,
    WaterIntakeOption option,
  ) {
    final isDefault = defaultIntakeOption?.id == option.id;

    return GestureDetector(
      onTap: () {
        AppLogger.log(
          'Grid card adding water: ${option.name} - ${option.amountInMl}mL',
          tag: 'CaloriesIn',
        );
        setState(() {
          waterIntake += option.amountInMl;
        });
        _waterIntakeNotifier.value = waterIntake;

        // Save water intake to Firebase
        _saveWaterIntakeToFirebase();

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${option.name} (${option.amount}${option.unit})',
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isDefault
                    ? const Color(0xFF10B981)
                    : Colors.white.withOpacity(0.1),
            width: isDefault ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4361ee).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.water_drop,
                color: Color(0xFF4361ee),
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              option.name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${option.amount} ${option.unit}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (isDefault) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '(default)',
                  style: TextStyle(
                    fontSize: 8,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCustomWaterInputDialog(
    BuildContext context, {
    required void Function(double amountInMl) onAddWater,
  }) {
    final TextEditingController customAmountController =
        TextEditingController();
    String selectedUnit = 'mL';
    final bottomSheetContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0A192F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Add Custom Amount',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: customAmountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Amount',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.rw,
                          vertical: 12.rh,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.rh),
                    DropdownButtonFormField<String>(
                      value: selectedUnit,
                      dropdownColor: const Color(0xFF0A192F),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.rw,
                          vertical: 12.rh,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'mL', child: Text('mL')),
                        DropdownMenuItem(value: 'L', child: Text('L')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedUnit = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              contentPadding: EdgeInsets.only(
                left: 24.rw,
                right: 24.rw,
                top: 20.rh,
                bottom: 20.rh,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final text = customAmountController.text
                        .trim()
                        .replaceAll(',', '.');
                    final amount = double.tryParse(text);
                    if (amount != null && amount > 0 && amount <= 10000) {
                      final amountInMl =
                          selectedUnit == 'L' ? amount * 1000 : amount;
                      onAddWater(amountInMl);
                      await _saveWaterIntakeToFirebase();
                      if (!dialogContext.mounted) return;
                      ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                        SnackBar(
                          content: Text('Added $amount $selectedUnit'),
                          backgroundColor: const Color(0xFF10B981),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      Navigator.of(dialogContext).pop();
                    } else {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            amount == null || amount <= 0
                                ? 'Please enter a valid amount (e.g. 250 or 0.5)'
                                : 'Amount must be between 0 and 10000',
                          ),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4361ee),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showWaterSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          top: false,
          left: false,
          right: false,
          bottom: true,
          child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0A192F), Colors.black],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 12.rh),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF4361ee),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.all(24.r),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Water Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Settings content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24.rw),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Update goal button at top
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: 24.rh),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showUpdateGoalDialog(context);
                          },
                          icon: const Icon(Icons.edit, color: Colors.white),
                          label: const Text(
                            'Update Daily Water Goal',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4361ee),
                            padding: EdgeInsets.symmetric(vertical: 16.rh),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      // Current goal display
                      _buildCurrentGoalDisplay(context),
                      SizedBox(height: 24.rh),
                      _buildWaterIntakeOptionsSection(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildCurrentGoalDisplay(BuildContext context) {
    final waterGoalL = waterGoal / 1000;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Daily Water Goal',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12.rh),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF4361ee).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.water_drop,
                  color: Color(0xFF4361ee),
                  size: 24,
                ),
              ),
              SizedBox(width: 12.rw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${waterGoalL.toStringAsFixed(1)} Liters',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Daily target',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUpdateGoalDialog(BuildContext context) {
    final TextEditingController goalController = TextEditingController();
    goalController.text = (waterGoal / 1000).toStringAsFixed(1);
    String selectedUnit = 'L';

    showDialog(
      context: context,
      builder: (dialogContext) {
        final keyboardHeight = MediaQuery.of(dialogContext).viewInsets.bottom;
        final screenHeight = MediaQuery.of(dialogContext).size.height;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0A192F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Update Daily Water Goal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              content: Container(
                constraints: BoxConstraints(
                  maxHeight: (screenHeight * 0.5) - keyboardHeight,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          TextField(
                            controller: goalController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Goal',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12.rw,
                                vertical: 12.rh,
                              ),
                            ),
                          ),
                          SizedBox(height: 12.rh),
                          DropdownButtonFormField<String>(
                            value: selectedUnit,
                            dropdownColor: const Color(0xFF0A192F),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12.rw,
                                vertical: 12.rh,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'L', child: Text('L')),
                              DropdownMenuItem(value: 'mL', child: Text('mL')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedUnit = value!;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              contentPadding: EdgeInsets.only(
                left: 24.rw,
                right: 24.rw,
                top: 20.rh,
                bottom: 20.rh + keyboardHeight,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final goal = double.tryParse(goalController.text);
                    // Reasonable bounds: 0.1L (100mL) to 10L (10000mL)
                    final goalInMl = goal != null
                        ? (selectedUnit == 'L' ? goal * 1000 : goal)
                        : 0.0;
                    if (goal != null && goalInMl >= 100 && goalInMl <= 10000) {
                      this.setState(() {
                        waterGoal = goalInMl;
                      });
                      _saveWaterIntakeToFirebase();
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Water goal updated to $goal$selectedUnit',
                          ),
                          backgroundColor: const Color(0xFF10B981),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a goal between 100mL and 10L'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4361ee),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildWaterIntakeOptionsSection(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Water Intake Options',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: () {
                  _showAddNewOptionDialog(context);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4361ee),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.rh),
          ...waterIntakeOptions.map(
            (option) => _buildWaterOptionSettingsCard(context, option),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterOptionSettingsCard(
    BuildContext context,
    WaterIntakeOption option,
  ) {
    final isDefault = defaultIntakeOption?.id == option.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isDefault
                  ? const Color(0xFF10B981)
                  : Colors.white.withOpacity(0.1),
          width: isDefault ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      option.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '(default)',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                children: [
                  if (defaultIntakeOption?.id != option.id)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          // Find the option in the list and set it as default
                          final index = waterIntakeOptions.indexWhere(
                            (o) => o.id == option.id,
                          );
                          if (index != -1) {
                            defaultIntakeOption = waterIntakeOptions[index];
                            AppLogger.log(
                              'Set new default: ${defaultIntakeOption!.name} - ${defaultIntakeOption!.amountInMl}mL',
                              tag: 'CaloriesIn',
                            );
                          }
                        });

                        // Persist to Firebase
                        _saveWaterOptionsToFirebase();

                        // Force rebuild the settings modal to show the visual change
                        Navigator.of(context).pop(); // Close current modal
                        _showWaterSettingsModal(
                          context,
                        ); // Reopen with updated state

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${option.name} set as default'),
                            backgroundColor: const Color(0xFF10B981),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4361ee).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Set Default',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF4361ee),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        waterIntakeOptions.removeWhere(
                          (o) => o.id == option.id,
                        );
                        // If we removed the default option, set a new default
                        if (defaultIntakeOption?.id == option.id &&
                            waterIntakeOptions.isNotEmpty) {
                          defaultIntakeOption = waterIntakeOptions.first;
                        } else if (waterIntakeOptions.isEmpty) {
                          defaultIntakeOption = null;
                        }
                      });
                      // Persist to Firebase
                      _saveWaterOptionsToFirebase();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${option.name} removed'),
                          backgroundColor: const Color(0xFFEF4444),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Remove',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${option.amount} ${option.unit}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddNewOptionDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    String selectedUnit = 'mL';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0A192F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Add New Water Option',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Option Name (e.g., Coffee Cup)',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.rw,
                          vertical: 12.rh,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.rh),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Amount',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12.rw,
                                vertical: 12.rh,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.rw),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            value: selectedUnit,
                            dropdownColor: const Color(0xFF0A192F),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12.rw,
                                vertical: 12.rh,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'mL',
                                child: Text('mL'),
                              ),
                              DropdownMenuItem(value: 'L', child: Text('L')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedUnit = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              contentPadding: EdgeInsets.only(
                left: 24.rw,
                right: 24.rw,
                top: 20.rh,
                bottom: 20.rh,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final amount = double.tryParse(amountController.text);
                    if (name.isNotEmpty && amount != null && amount > 0) {
                      final newOption = WaterIntakeOption(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: name,
                        amount: amount,
                        unit: selectedUnit,
                      );
                      this.setState(() {
                        waterIntakeOptions.add(newOption);
                      });
                      // Persist to Firebase
                      _saveWaterOptionsToFirebase();
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added $name ($amount$selectedUnit)'),
                          backgroundColor: const Color(0xFF10B981),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4361ee),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRecipeSelectionModal(BuildContext context) {
    Navigator.of(context).pop(); // Close add menu first
    if (!mounted) return;
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return SafeArea(
          top: false,
          left: false,
          right: false,
          bottom: true,
          child: Container(
          height: MediaQuery.of(modalContext).size.height * 0.8,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0A192F), Colors.black],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 12.rh),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF4361ee),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.all(24.r),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Recipe',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(modalContext).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Add new recipe button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.rw),
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 16.rh),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(modalContext).pop(); // Close recipe selection
                      _openRecipeCreator(parentContext);
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Create New Recipe',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4361ee),
                      padding: EdgeInsets.symmetric(vertical: 16.rh),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              // Saved recipes list
              Expanded(
                child:
                    recipes.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(40),
                                ),
                                child: const Icon(
                                  Icons.restaurant,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                              SizedBox(height: 16.rh),
                              const Text(
                                'No saved recipes yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create your first recipe to get started',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        )
                        : Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.rw),
                          child: ListView.builder(
                            itemCount: recipes.length,
                            itemBuilder: (context, index) {
                              return _buildRecipeCard(context, recipes[index]);
                            },
                          ),
                        ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildRecipeCard(BuildContext context, Recipe recipe) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.rh),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF4361ee).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restaurant,
                  color: Color(0xFF4361ee),
                  size: 24,
                ),
              ),
              SizedBox(width: 12.rw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recipe.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  // View button (eye icon)
                  GestureDetector(
                    onTap: () => _viewRecipe(context, recipe),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4cc9f0).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.visibility,
                        color: Color(0xFF4cc9f0),
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Edit button (pencil icon)
                  GestureDetector(
                    onTap: () => _editRecipe(context, recipe),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF9c4dff).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Color(0xFF9c4dff),
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Add button
                  GestureDetector(
                    onTap: () => _showRecipeQuantityDialog(context, recipe),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.rw,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4361ee),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.rh),
          Row(
            children: [
              _buildNutritionChip(
                '${recipe.totalNutrition.calories} $_energyUnit',
                const Color(0xFF4361ee),
              ),
              const SizedBox(width: 8),
              _buildNutritionChip(
                '${recipe.totalNutrition.protein.toInt()}g protein',
                const Color(0xFF4895ef),
              ),
              const Spacer(),
              // Health stars for recipe
              _buildHealthStars(
                (recipe.totalNutrition.fiber > 0 ? 3 : 3), // Default 3 if no star data
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showRecipeQuantityDialog(BuildContext context, Recipe recipe) {
    double quantity = 1.0;
    final controller = TextEditingController(text: '1');
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1a1f2e),
              title: Text(
                'Add to log',
                style: const TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 16.rh),
                  const Text(
                    'Quantity (servings)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '1',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (v) {
                      final parsed = double.tryParse(v.replaceAll(',', '.'));
                      if (parsed != null && parsed > 0) quantity = parsed;
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [0.25, 0.5, 1.0, 1.5, 2.0].map((q) {
                      return GestureDetector(
                        onTap: () {
                          quantity = q;
                          controller.text = q == q.toInt() ? q.toInt().toString() : q.toString();
                          setDialogState(() {});
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4361ee).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            q == q.toInt() ? '${q.toInt()}' : '$q',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                ),
                ElevatedButton(
                  onPressed: () {
                    final parsed = double.tryParse(controller.text.replaceAll(',', '.'));
                    if (parsed != null && parsed > 0) quantity = parsed;
                    Navigator.of(dialogContext).pop();
                    _addRecipeToLog(recipe, quantity);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4361ee)),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addRecipeToLog(Recipe recipe, [double quantity = 1.0]) async {
    Navigator.of(context).pop(); // Close recipe selection modal

    // Scale nutrition by quantity
    final q = quantity.clamp(0.001, 1000.0);
    final recipeFood = FoodItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_recipe_${recipe.id}',
      name: recipe.name,
      icon: '🍽️',
      calories: (recipe.totalNutrition.calories * q).round(),
      protein: recipe.totalNutrition.protein * q,
      carbs: recipe.totalNutrition.carbs * q,
      fat: recipe.totalNutrition.fat * q,
      fiber: recipe.totalNutrition.fiber * q,
      sugar: recipe.totalNutrition.sugar * q,
      sodium: recipe.totalNutrition.sodium * q,
    );

    final foodEntry = FoodEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}_recipe_${recipe.id}',
      food: recipeFood,
      timestamp: DateTime.now(),
      firebaseDocId: null, // Will be set after Firebase save
    );

    setState(() {
      foodLog.insert(0, foodEntry);
      dailyTotals.addFood(recipeFood);
    });

    // Save to Firebase
    try {
      final entryData = {
        'food': {
          'id': recipeFood.id,
          'name': recipeFood.name,
          'icon': recipeFood.icon,
          'calories': recipeFood.calories,
          'protein': recipeFood.protein,
          'carbs': recipeFood.carbs,
          'fat': recipeFood.fat,
          'fiber': recipeFood.fiber,
          'sugar': recipeFood.sugar,
          'sodium': recipeFood.sodium,
          'healthStar': recipeFood.healthStar,
        },
        'timestamp': Timestamp.fromDate(foodEntry.timestamp),
      };

      await FirebaseService.saveFoodLogEntry(entryData);
    } catch (e) {
      debugPrint('Error saving recipe entry to Firebase: $e');
    }

    // Save daily totals to Firebase
    await _saveDailyTotalsToFirebase();

    final servingText = quantity != 1.0
        ? ' (${quantity == quantity.roundToDouble() ? quantity.toInt() : quantity} servings)'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${recipe.name}"$servingText to food log'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _viewRecipe(BuildContext context, Recipe recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          top: false,
          left: false,
          right: false,
          bottom: true,
          child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0A192F), Colors.black],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 12.rh),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF4361ee),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.all(24.r),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recipe Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Recipe content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24.rw),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recipe info
                      _buildViewRecipeInfo(recipe),
                      SizedBox(height: 20.rh),
                      // Ingredients
                      _buildViewIngredients(recipe),
                      SizedBox(height: 20.rh),
                      // Instructions
                      _buildViewInstructions(recipe),
                      SizedBox(height: 20.rh),
                      // Nutrition totals
                      _buildViewNutritionTotals(recipe),
                      SizedBox(height: 20.rh),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  void _editRecipe(BuildContext context, Recipe recipe) {
    Navigator.of(context).pop(); // Close recipe selection modal first

    // Convert local Recipe to rc.Recipe
    final rcRecipe = rc.Recipe(
      id: recipe.id,
      name: recipe.name,
      description: recipe.description,
      instructions: recipe.instructions,
      ingredients:
          recipe.ingredients
              .map(
                (food) => rc.SelectedIngredient(
                  ingredient: rc.Ingredient(
                    id: DateTime.now().millisecondsSinceEpoch,
                    name: food.name,
                    calories: food.calories,
                    protein: food.protein,
                    carbs: food.carbs,
                    fat: food.fat,
                    category: 'Converted',
                    servingSize: '1 serving',
                  ),
                  quantity: 1.0,
                  servingMultiplier: '1x',
                  totalCalories: food.calories.toDouble(),
                  totalProtein: food.protein,
                  totalCarbs: food.carbs,
                  totalFat: food.fat,
                  displayQuantity: '1 serving',
                ),
              )
              .toList(),
      nutritionTotals: {
        'calories': recipe.totalNutrition.calories.toDouble(),
        'protein': recipe.totalNutrition.protein,
        'carbs': recipe.totalNutrition.carbs,
        'fat': recipe.totalNutrition.fat,
        'fiber': recipe.totalNutrition.fiber,
        'sugar': recipe.totalNutrition.sugar,
        'sodium': recipe.totalNutrition.sodium,
      },
      createdAt: DateTime.now(),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => rc.EditRecipePage(
              recipe: rcRecipe,
              onRecipeUpdated: (updatedRcRecipe) {
                // Convert rc.Recipe back to local Recipe
                final updatedRecipe = Recipe(
                  id: updatedRcRecipe.id,
                  name: updatedRcRecipe.name,
                  description: updatedRcRecipe.description,
                  instructions: updatedRcRecipe.instructions,
                  ingredients:
                      updatedRcRecipe.ingredients
                          .map(
                            (si) => FoodItem(
                              id: si.ingredient.id.toString(),
                              name: si.ingredient.name,
                              icon: '🍽️',
                              calories: si.totalCalories.round(),
                              protein: si.totalProtein,
                              carbs: si.totalCarbs,
                              fat: si.totalFat,
                              fiber: 0,
                            ),
                          )
                          .toList(),
                  totalNutrition: DailyTotals(
                    calories:
                        updatedRcRecipe.nutritionTotals['calories']!.round(),
                    protein: updatedRcRecipe.nutritionTotals['protein']!,
                    carbs: updatedRcRecipe.nutritionTotals['carbs']!,
                    fat: updatedRcRecipe.nutritionTotals['fat']!,
                    fiber: updatedRcRecipe.nutritionTotals['fiber']!,
                    sugar: updatedRcRecipe.nutritionTotals['sugar'] ?? 0,
                    sodium: updatedRcRecipe.nutritionTotals['sodium'] ?? 0,
                  ),
                );

                // Update the recipe in the recipes list
                setState(() {
                  final index = recipes.indexWhere(
                    (r) => r.id == updatedRecipe.id,
                  );
                  if (index != -1) {
                    recipes[index] = updatedRecipe;
                  }
                });

                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Recipe "${updatedRecipe.name}" updated successfully!',
                    ),
                    backgroundColor: const Color(0xFF10B981),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
      ),
    );
  }

  Widget _buildViewRecipeInfo(Recipe recipe) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recipe.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewIngredients(Recipe recipe) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ingredients',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12.rh),
          ...recipe.ingredients.map(
            (food) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4361ee),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 12.rw),
                  Expanded(
                    child: Text(
                      food.name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${food.calories} $_energyUnit',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewInstructions(Recipe recipe) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Instructions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12.rh),
          Text(
            recipe.instructions,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewNutritionTotals(Recipe recipe) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4361ee), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nutrition Totals',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16.rh),
          Row(
            children: [
              Expanded(
                child: _buildViewNutritionItem(
                  'Calories',
                  '${recipe.totalNutrition.calories}',
                  Colors.white,
                ),
              ),
              SizedBox(width: 12.rw),
              Expanded(
                child: _buildViewNutritionItem(
                  'Protein',
                  '${recipe.totalNutrition.protein.toInt()}g',
                  Colors.white,
                ),
              ),
              SizedBox(width: 12.rw),
              Expanded(
                child: _buildViewNutritionItem(
                  'Carbs',
                  '${recipe.totalNutrition.carbs.toInt()}g',
                  Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.rh),
          Row(
            children: [
              Expanded(
                child: _buildViewNutritionItem(
                  'Fat',
                  '${recipe.totalNutrition.fat.toInt()}g',
                  Colors.white,
                ),
              ),
              SizedBox(width: 12.rw),
              Expanded(
                child: _buildViewNutritionItem(
                  'Fiber',
                  '${recipe.totalNutrition.fiber.toInt()}g',
                  Colors.white,
                ),
              ),
              SizedBox(width: 12.rw),
              const Expanded(child: SizedBox()), // Empty space for alignment
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewNutritionItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> loadMacroGoals() async {
    try {
      final userData = await FirebaseService.getUserData();
      if (userData != null && userData['goals'] != null) {
        setState(() {
          goals = Map<String, dynamic>.from(userData['goals']);
        });
      }
    } catch (e) {
      debugPrint('Error loading macro goals: $e');
    }
  }

  /// Call when Calories In tab is shown so "Calories Left" reflects latest exercise (calories out).
  Future<void> refreshCaloriesBurned() async {
    await _loadCaloriesBurnedToday();
  }

  // Firebase Data Operations
  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan_calories.txt ID f_3c4d5e_calories
  Future<void> _loadDataFromFirebase() async {
    if (mounted) setState(() => _isLoadingData = true);
    try {
      // Load all data in parallel for faster startup
      await Future.wait([
        _loadFoodLogFromFirebase(),
        _loadRecipesFromFirebase(),
        _loadDailyTotalsFromFirebase(),
        _loadWaterIntakeFromFirebase(),
        _loadWaterOptionsFromFirebase(),
      ]);
    } catch (e) {
      AppLogger.error('Error loading data from Firebase', error: e, tag: 'CaloriesIn');
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan_calories.txt ID f_4d5e6f_calories
  Future<void> _loadFoodLogFromFirebase() async {
    try {
      // Reset pagination state for initial load
      _lastFoodLogDocument = null;
      _hasMoreFoodLogEntries = true;

      final result = await FirebaseService.getFoodLogEntriesPaginated(
        limit: _foodLogPageSize,
        startAfterDocument: null,
      );

      final foodLogData = result['entries'] as List<Map<String, dynamic>>;
      _lastFoodLogDocument = result['lastDocument'] as DocumentSnapshot?;

      if (mounted) {
        setState(() {
          foodLog.clear();
          dailyTotals.reset();

          if (foodLogData.length < _foodLogPageSize) {
            _hasMoreFoodLogEntries = false;
          }

          for (final entryData in foodLogData) {
            final food = FoodItem(
              id: entryData['food']['id'] ?? '',
              name: entryData['food']['name'] ?? '',
              icon: entryData['food']['icon'] ?? '🍽️',
              calories: entryData['food']['calories'] ?? 0,
              protein: (entryData['food']['protein'] ?? 0).toDouble(),
              carbs: (entryData['food']['carbs'] ?? 0).toDouble(),
              fat: (entryData['food']['fat'] ?? 0).toDouble(),
              fiber: (entryData['food']['fiber'] ?? 0).toDouble(),
              sugar: (entryData['food']['sugar'] ?? 0).toDouble(),
              sodium: (entryData['food']['sodium'] ?? 0).toDouble(),
              healthStar: (entryData['food']['healthStar'] ?? 3).toInt().clamp(1, 5),
              nutritionGrade: entryData['food']['nutritionGrade'] as String?,
            );

            final foodEntry = FoodEntry(
              id: entryData['id'] ?? '',
              food: food,
              timestamp:
                  entryData['timestamp'] != null
                      ? (entryData['timestamp'] as Timestamp).toDate()
                      : DateTime.now(),
              firebaseDocId: entryData['id'], // Store Firebase document ID
            );

            foodLog.add(foodEntry);
            dailyTotals.addFood(food);
          }
        });
      }

      // Also load daily totals from Firebase to reconcile
      // (handles entries beyond current page that still count toward totals)
      await _loadDailyTotalsFromFirebase();
    } catch (e) {
      AppLogger.error('Error loading food log from Firebase', error: e, tag: 'CaloriesIn');
    }
  }

  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan_calories.txt ID f_5e6f7g_calories
  Future<void> _loadRecipesFromFirebase() async {
    try {
      final recipesData = await FirebaseService.getRecipes();

      if (mounted) {
        setState(() {
          recipes.clear();

          for (final recipeData in recipesData) {
            final ingredients =
                (recipeData['ingredients'] as List<dynamic>?)
                    ?.map(
                      (ingredientData) => FoodItem(
                        id: ingredientData['id'] ?? '',
                        name: ingredientData['name'] ?? '',
                        icon: ingredientData['icon'] ?? '🍽️',
                        calories: ingredientData['calories'] ?? 0,
                        protein: (ingredientData['protein'] ?? 0).toDouble(),
                        carbs: (ingredientData['carbs'] ?? 0).toDouble(),
                        fat: (ingredientData['fat'] ?? 0).toDouble(),
                        fiber: (ingredientData['fiber'] ?? 0).toDouble(),
                      ),
                    )
                    .toList() ??
                [];

            final totalNutrition = DailyTotals(
              calories: recipeData['totalNutrition']['calories'] ?? 0,
              protein:
                  (recipeData['totalNutrition']['protein'] ?? 0).toDouble(),
              carbs: (recipeData['totalNutrition']['carbs'] ?? 0).toDouble(),
              fat: (recipeData['totalNutrition']['fat'] ?? 0).toDouble(),
              fiber: (recipeData['totalNutrition']['fiber'] ?? 0).toDouble(),
              sugar: (recipeData['totalNutrition']['sugar'] ?? 0).toDouble(),
              sodium: (recipeData['totalNutrition']['sodium'] ?? 0).toDouble(),
            );

            final recipe = Recipe(
              id: recipeData['id'] ?? '',
              name: recipeData['name'] ?? '',
              description: recipeData['description'] ?? '',
              ingredients: ingredients,
              instructions: recipeData['instructions'] ?? '',
              totalNutrition: totalNutrition,
            );

            recipes.add(recipe);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading recipes from Firebase: $e');
    }
  }

  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan_calories.txt ID f_6f7g8h_calories
  Future<void> _loadDailyTotalsFromFirebase() async {
    try {
      final dailyTotalsData = await FirebaseService.getDailyTotals();

      if (dailyTotalsData != null && mounted) {
        setState(() {
          dailyTotals.calories = dailyTotalsData['calories'] ?? 0;
          dailyTotals.protein = (dailyTotalsData['protein'] ?? 0).toDouble();
          dailyTotals.carbs = (dailyTotalsData['carbs'] ?? 0).toDouble();
          dailyTotals.fat = (dailyTotalsData['fat'] ?? 0).toDouble();
          dailyTotals.fiber = (dailyTotalsData['fiber'] ?? 0).toDouble();
          dailyTotals.sugar = (dailyTotalsData['sugar'] ?? 0).toDouble();
          dailyTotals.sodium = (dailyTotalsData['sodium'] ?? 0).toDouble();
        });
      }
    } catch (e) {
      debugPrint('Error loading daily totals from Firebase: $e');
    }
  }

  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan_calories.txt ID f_7g8h9i_calories
  Future<void> _loadWaterIntakeFromFirebase() async {
    try {
      final waterData = await FirebaseService.getWaterIntake();

      if (waterData != null && mounted) {
        setState(() {
          waterIntake = (waterData['waterIntake'] ?? 0).toDouble();
          waterGoal = (waterData['waterGoal'] ?? 2000).toDouble();
        });
        _waterIntakeNotifier.value = waterIntake;
      }
    } catch (e) {
      debugPrint('Error loading water intake from Firebase: $e');
    }
  }

  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan_calories.txt ID f_8h9i0j_calories
  Future<void> _saveDailyTotalsToFirebase() async {
    try {
      final dailyTotalsData = {
        'calories': dailyTotals.calories,
        'protein': dailyTotals.protein,
        'carbs': dailyTotals.carbs,
        'fat': dailyTotals.fat,
        'fiber': dailyTotals.fiber,
        'sugar': dailyTotals.sugar,
        'sodium': dailyTotals.sodium,
      };

      await FirebaseService.saveDailyTotals(dailyTotalsData);
    } catch (e) {
      debugPrint('Error saving daily totals to Firebase: $e');
    }
  }

  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan_calories.txt ID f_9i0j1k_calories
  Future<void> _saveWaterIntakeToFirebase() async {
    try {
      await FirebaseService.saveWaterIntake(waterIntake, waterGoal);
    } catch (e) {
      debugPrint('Error saving water intake to Firebase: $e');
    }
  }

  // ============================================================================
  // WATER OPTIONS PERSISTENCE
  // ============================================================================

  Future<void> _loadWaterOptionsFromFirebase() async {
    try {
      final options = await FirebaseService.getWaterIntakeOptions();
      if (options.isNotEmpty && mounted) {
        setState(() {
          waterIntakeOptions = options
              .map((o) => WaterIntakeOption.fromMap(o))
              .toList();
          // Restore default option
          final defaultOpt = waterIntakeOptions.where(
            (o) => o.isDefault,
          );
          if (defaultOpt.isNotEmpty) {
            defaultIntakeOption = defaultOpt.first;
          } else if (waterIntakeOptions.isNotEmpty) {
            defaultIntakeOption = waterIntakeOptions.first;
          }
        });
      }
      // If no saved options, keep the hardcoded defaults from _initializeWaterOptions
    } catch (e) {
      AppLogger.error('Error loading water options', error: e, tag: 'CaloriesIn');
    }
  }

  Future<void> _saveWaterOptionsToFirebase() async {
    try {
      final optionMaps = waterIntakeOptions.map((o) {
        final map = o.toMap();
        map['isDefault'] = (defaultIntakeOption?.id == o.id);
        return map;
      }).toList();
      await FirebaseService.saveWaterIntakeOptions(optionMaps);
    } catch (e) {
      AppLogger.error('Error saving water options', error: e, tag: 'CaloriesIn');
    }
  }

  // ============================================================================
  // FOOD LOG PAGINATION
  // ============================================================================

  // ============================================================================
  // CALORIE BEHAVIOR SETTINGS
  // ============================================================================

  /// Public so CaloriesCounterTab can refresh after settings change.
  Future<void> reloadCalorieBehaviorSettings() => _loadCalorieBehaviorSettings();

  Future<void> _loadCalorieBehaviorSettings() async {
    try {
      final userData = await FirebaseService.getUserData();
      if (userData != null && mounted) {
        final caloriesRollIn = userData['caloriesRollIn'] ?? true;
        final deductCaloriesOut = userData['deductCaloriesOut'] ?? true;

        setState(() {
          // Also sync goals from the same fetch so _loadRollInBonus
          // always sees the real goal instead of the default 2000.
          if (userData['goals'] != null) {
            goals = Map<String, dynamic>.from(userData['goals']);
          }
          _caloriesRollIn = caloriesRollIn;
          _deductCaloriesOut = deductCaloriesOut;
        });

        if (caloriesRollIn) {
          await _loadRollInBonus();
        } else {
          setState(() => _rollInBonus = 0);
        }

        // Always refresh burned calories so the display is up-to-date.
        await _loadCaloriesBurnedToday();
      }
    } catch (e) {
      debugPrint('Error loading calorie behavior settings: $e');
    }
  }

  Future<void> _loadRollInBonus() async {
    try {
      final yesterdayTotals = await FirebaseService.getYesterdayDailyTotals();
      if (yesterdayTotals != null && mounted) {
        final yesterdayCal = (yesterdayTotals['calories'] ?? 0) as int;
        final calGoal = (goals['calories'] as num?)?.toInt() ?? 0;

        if (calGoal > 0 && yesterdayCal < calGoal) {
          final deficit = calGoal - yesterdayCal;
          // Max 200 cal roll-in per day
          setState(() {
            _rollInBonus = deficit.clamp(0, 200);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading roll-in bonus: $e');
    }
  }

  Future<void> _loadCaloriesBurnedToday() async {
    try {
      final activities = await ActivityService.getActivities(days: 1);
      if (mounted) {
        double totalBurned = 0;
        final today = DateTime.now();
        for (final activity in activities) {
          if (activity.startTime.day == today.day &&
              activity.startTime.month == today.month &&
              activity.startTime.year == today.year) {
            totalBurned += activity.caloriesBurned;
          }
        }
        setState(() {
          _caloriesBurnedToday = totalBurned;
        });
      }
    } catch (e) {
      debugPrint('Error loading calories burned today: $e');
    }
  }

  /// Get effective calories remaining after applying settings
  int _getEffectiveCaloriesLeft() {
    final calGoal = (goals['calories'] as num?)?.toInt() ?? 0;
    int effectiveGoal = calGoal;

    // Add roll-in bonus if enabled
    if (_caloriesRollIn) {
      effectiveGoal += _rollInBonus;
    }

    // Exercise adds to the budget (you earn more calories to eat)
    if (_deductCaloriesOut && _caloriesBurnedToday > 0) {
      effectiveGoal += _caloriesBurnedToday.toInt();
    }

    final consumed = dailyTotals.calories;
    return effectiveGoal - consumed; // can be negative when over goal
  }

  Future<void> _loadMoreFoodLogEntries() async {
    if (_isLoadingMoreFoodLog || !_hasMoreFoodLogEntries) return;
    setState(() => _isLoadingMoreFoodLog = true);

    try {
      final result = await FirebaseService.getFoodLogEntriesPaginated(
        limit: _foodLogPageSize,
        startAfterDocument: _lastFoodLogDocument,
      );

      final entries = result['entries'] as List<Map<String, dynamic>>;
      _lastFoodLogDocument = result['lastDocument'] as DocumentSnapshot?;

      if (mounted) {
        setState(() {
          _isLoadingMoreFoodLog = false;
          if (entries.length < _foodLogPageSize) {
            _hasMoreFoodLogEntries = false;
          }
          for (final entryData in entries) {
            final food = FoodItem(
              id: entryData['food']['id'] ?? '',
              name: entryData['food']['name'] ?? '',
              icon: entryData['food']['icon'] ?? '🍽️',
              calories: entryData['food']['calories'] ?? 0,
              protein: (entryData['food']['protein'] ?? 0).toDouble(),
              carbs: (entryData['food']['carbs'] ?? 0).toDouble(),
              fat: (entryData['food']['fat'] ?? 0).toDouble(),
              fiber: (entryData['food']['fiber'] ?? 0).toDouble(),
              sugar: (entryData['food']['sugar'] ?? 0).toDouble(),
              sodium: (entryData['food']['sodium'] ?? 0).toDouble(),
              healthStar: (entryData['food']['healthStar'] ?? 3).toInt().clamp(1, 5),
              nutritionGrade: entryData['food']['nutritionGrade'] as String?,
            );
            final foodEntry = FoodEntry(
              id: entryData['id'] ?? '',
              food: food,
              timestamp: entryData['timestamp'] != null
                  ? (entryData['timestamp'] as Timestamp).toDate()
                  : DateTime.now(),
              firebaseDocId: entryData['id'],
            );
            foodLog.add(foodEntry);
            dailyTotals.addFood(food);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMoreFoodLog = false);
      AppLogger.error('Error loading more food log', error: e, tag: 'CaloriesIn');
    }
  }
}

/// Shimmer skeleton box for loading placeholders
class _ShimmerBox extends StatefulWidget {
  final double height;
  final double borderRadius;

  const _ShimmerBox({required this.height, this.borderRadius = 12});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = 0.04 + (_controller.value * 0.06);
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
        );
      },
    );
  }
}
