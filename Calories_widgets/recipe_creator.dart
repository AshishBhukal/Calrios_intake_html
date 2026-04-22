import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_functions_service.dart';
import '../widgets/animated_loading_screen.dart';
import '../utils/app_logger.dart';
import '../features/extra/constants.dart';

// Ingredient model
class Ingredient {
  final int id;
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final String category;
  final String servingSize;

  Ingredient({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.category,
    required this.servingSize,
  });
}

// Selected ingredient with quantity information
class SelectedIngredient {
  final Ingredient ingredient;
  final double quantity;
  final String servingMultiplier;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final String displayQuantity;

  SelectedIngredient({
    required this.ingredient,
    required this.quantity,
    required this.servingMultiplier,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.displayQuantity,
  });

  // Factory constructor to create from ingredient and quantity
  factory SelectedIngredient.fromIngredient({
    required Ingredient ingredient,
    required double quantity,
    required String servingMultiplier,
  }) {
    // Parse serving multiplier (e.g., "1.5x" -> 1.5)
    final multiplierValue = double.parse(servingMultiplier.replaceAll('x', ''));
    
    // Calculate total multiplier (quantity × serving multiplier)
    final totalMultiplier = quantity * multiplierValue;
    
    // Calculate adjusted nutrition values
    final totalCalories = ingredient.calories * totalMultiplier;
    final totalProtein = ingredient.protein * totalMultiplier;
    final totalCarbs = ingredient.carbs * totalMultiplier;
    final totalFat = ingredient.fat * totalMultiplier;
    
    // Create display quantity string
    String displayQuantity;
    if (totalMultiplier == 1.0) {
      displayQuantity = ingredient.servingSize;
    } else {
      displayQuantity = '${totalMultiplier.toStringAsFixed(1)}x ${ingredient.servingSize}';
    }
    
    return SelectedIngredient(
      ingredient: ingredient,
      quantity: quantity,
      servingMultiplier: servingMultiplier,
      totalCalories: totalCalories,
      totalProtein: totalProtein,
      totalCarbs: totalCarbs,
      totalFat: totalFat,
      displayQuantity: displayQuantity,
    );
  }

  // Create from JSON
  factory SelectedIngredient.fromJson(Map<String, dynamic> json) {
    final originalIngredient = Ingredient(
      id: json['originalIngredient']['id'],
      name: json['originalIngredient']['name'],
      calories: json['originalIngredient']['calories'],
      protein: json['originalIngredient']['protein'].toDouble(),
      carbs: json['originalIngredient']['carbs'].toDouble(),
      fat: json['originalIngredient']['fat'].toDouble(),
      category: json['originalIngredient']['category'],
      servingSize: json['originalIngredient']['servingSize'],
    );

    return SelectedIngredient(
      ingredient: originalIngredient,
      quantity: json['quantity'].toDouble(),
      servingMultiplier: json['servingMultiplier'],
      totalCalories: json['totalCalories'].toDouble(),
      totalProtein: json['totalProtein'].toDouble(),
      totalCarbs: json['totalCarbs'].toDouble(),
      totalFat: json['totalFat'].toDouble(),
      displayQuantity: json['displayQuantity'],
    );
  }
}

// AI Recipe Response Models
class AIRecipeIngredient {
  final String name;
  final double quantity;
  final String unit;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;

  AIRecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    this.sugar = 0,
    this.sodium = 0,
  });

  factory AIRecipeIngredient.fromJson(Map<String, dynamic> json) {
    return AIRecipeIngredient(
      name: json['name'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      calories: (json['calories'] ?? 0).toDouble(),
      protein: (json['protein'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
      fiber: (json['fiber'] ?? 0).toDouble(),
      sugar: (json['sugar'] ?? 0).toDouble(),
      sodium: (json['sodium'] ?? 0).toDouble(),
    );
  }
}

class AIRecipeTotals {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;

  AIRecipeTotals({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    this.sugar = 0,
    this.sodium = 0,
  });

  factory AIRecipeTotals.fromJson(Map<String, dynamic> json) {
    return AIRecipeTotals(
      calories: (json['calories'] ?? 0).toDouble(),
      protein: (json['protein'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
      fiber: (json['fiber'] ?? 0).toDouble(),
      sugar: (json['sugar'] ?? 0).toDouble(),
      sodium: (json['sodium'] ?? 0).toDouble(),
    );
  }
}

class AIRecipeResponse {
  final String recipeName;
  final String description;
  final String instructions;
  final List<AIRecipeIngredient> ingredients;
  final AIRecipeTotals totals;
  final int healthStar; // 1-5 rating

  AIRecipeResponse({
    required this.recipeName,
    required this.description,
    required this.instructions,
    required this.ingredients,
    required this.totals,
    this.healthStar = 3,
  });

  factory AIRecipeResponse.fromJson(Map<String, dynamic> json) {
    return AIRecipeResponse(
      recipeName: json['recipeName'] ?? '',
      description: json['description'] ?? '',
      instructions: json['instructions'] ?? '',
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((item) => AIRecipeIngredient.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      totals: AIRecipeTotals.fromJson(Map<String, dynamic>.from(json['totals'] as Map)),
      healthStar: (json['healthStar'] as num?)?.toInt().clamp(1, 5) ?? 3,
    );
  }
}

// AI Recipe Service - Uses Firebase Cloud Functions for secure AI integration
class AIRecipeService {
  /// Analyze recipe via Firebase Cloud Function.
  /// Returns parsed AIRecipeResponse or null on failure.
  /// Throws [RateLimitExceededException] if rate limited.
  static Future<AIRecipeResponse?> analyzeRecipe({
    required String recipeName,
    required String ingredients,
    String? instructions,
    String? mealTime,
  }) async {
    try {
      final response = await FirebaseFunctionsService.generateRecipe(
        recipeName: recipeName,
        ingredients: ingredients,
        instructions: instructions,
        mealTime: mealTime,
      );

      if (response != null) {
        return AIRecipeResponse.fromJson(response);
      } else {
        AppLogger.warning('Firebase Function returned null response', tag: 'RecipeCreator');
        return null;
      }
    } on RateLimitExceededException {
      rethrow; // Let UI handle rate limit feedback
    } catch (e) {
      AppLogger.error('Error calling Firebase Function', error: e, tag: 'RecipeCreator');
      return null;
    }
  }
}

// Recipe model for saving
class Recipe {
  final String id;
  final String name;
  final String description;
  final String instructions;
  final List<SelectedIngredient> ingredients;
  final Map<String, double> nutritionTotals;
  final DateTime createdAt;

  Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.instructions,
    required this.ingredients,
    required this.nutritionTotals,
    required this.createdAt,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'instructions': instructions,
      'ingredients': ingredients.map((ingredient) => {
        'ingredientId': ingredient.ingredient.id,
        'ingredientName': ingredient.ingredient.name,
        'quantity': ingredient.quantity,
        'servingMultiplier': ingredient.servingMultiplier,
        'totalCalories': ingredient.totalCalories,
        'totalProtein': ingredient.totalProtein,
        'totalCarbs': ingredient.totalCarbs,
        'totalFat': ingredient.totalFat,
        'displayQuantity': ingredient.displayQuantity,
        'originalIngredient': {
          'id': ingredient.ingredient.id,
          'name': ingredient.ingredient.name,
          'calories': ingredient.ingredient.calories,
          'protein': ingredient.ingredient.protein,
          'carbs': ingredient.ingredient.carbs,
          'fat': ingredient.ingredient.fat,
          'category': ingredient.ingredient.category,
          'servingSize': ingredient.ingredient.servingSize,
        },
      }).toList(),
      'nutritionTotals': nutritionTotals,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory Recipe.fromJson(Map<String, dynamic> json) {
    final ingredientsList = (json['ingredients'] as List).map((ingredientJson) {
      final originalIngredient = Ingredient(
        id: ingredientJson['originalIngredient']['id'],
        name: ingredientJson['originalIngredient']['name'],
        calories: ingredientJson['originalIngredient']['calories'],
        protein: ingredientJson['originalIngredient']['protein'].toDouble(),
        carbs: ingredientJson['originalIngredient']['carbs'].toDouble(),
        fat: ingredientJson['originalIngredient']['fat'].toDouble(),
        category: ingredientJson['originalIngredient']['category'],
        servingSize: ingredientJson['originalIngredient']['servingSize'],
      );

      return SelectedIngredient(
        ingredient: originalIngredient,
        quantity: ingredientJson['quantity'].toDouble(),
        servingMultiplier: ingredientJson['servingMultiplier'],
        totalCalories: ingredientJson['totalCalories'].toDouble(),
        totalProtein: ingredientJson['totalProtein'].toDouble(),
        totalCarbs: ingredientJson['totalCarbs'].toDouble(),
        totalFat: ingredientJson['totalFat'].toDouble(),
        displayQuantity: ingredientJson['displayQuantity'],
      );
    }).toList();

    return Recipe(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      instructions: json['instructions'],
      ingredients: ingredientsList,
      nutritionTotals: Map<String, double>.from(json['nutritionTotals']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  // Factory constructor to create from AI response
  factory Recipe.fromAIResponse(AIRecipeResponse aiResponse) {
    int ingredientIdCounter = DateTime.now().millisecondsSinceEpoch;
    final ingredients = aiResponse.ingredients.map((aiIngredient) {
      // Create ingredient with unique ID (incrementing to avoid duplicates)
      final ingredient = Ingredient(
        id: ingredientIdCounter++,
        name: aiIngredient.name,
        calories: aiIngredient.calories.toInt(),
        protein: aiIngredient.protein,
        carbs: aiIngredient.carbs,
        fat: aiIngredient.fat,
        category: 'AI Generated',
        servingSize: '${aiIngredient.quantity} ${aiIngredient.unit}',
      );

      return SelectedIngredient(
        ingredient: ingredient,
        quantity: aiIngredient.quantity,
        servingMultiplier: '1x',
        totalCalories: aiIngredient.calories,
        totalProtein: aiIngredient.protein,
        totalCarbs: aiIngredient.carbs,
        totalFat: aiIngredient.fat,
        displayQuantity: '${aiIngredient.quantity} ${aiIngredient.unit}',
      );
    }).toList();

    return Recipe(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: aiResponse.recipeName,
      description: aiResponse.description,
      instructions: aiResponse.instructions,
      ingredients: ingredients,
      nutritionTotals: {
        'calories': aiResponse.totals.calories,
        'protein': aiResponse.totals.protein,
        'carbs': aiResponse.totals.carbs,
        'fat': aiResponse.totals.fat,
        'fiber': aiResponse.totals.fiber,
        'sugar': aiResponse.totals.sugar,
        'sodium': aiResponse.totals.sodium,
        'healthStar': aiResponse.healthStar.toDouble(),
      },
      createdAt: DateTime.now(),
    );
  }
}

class RecipeCreatorHomePage extends StatefulWidget {
  const RecipeCreatorHomePage({super.key});

  @override
  State<RecipeCreatorHomePage> createState() => _RecipeCreatorHomePageState();
}

class _RecipeCreatorHomePageState extends State<RecipeCreatorHomePage> {
  final TextEditingController _recipeNameController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  bool _isAnalyzing = false;
  String _selectedMealTime = 'none'; // Default to none
  
  final List<String> _mealTimes = [
    'none',
    'breakfast',
    'lunch', 
    'dinner',
    'snacks'
  ];

  @override
  void dispose() {
    _recipeNameController.dispose();
    _ingredientsController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _analyzeRecipe() async {
    final recipeName = _recipeNameController.text.trim();
    final ingredients = _ingredientsController.text.trim();
    final instructions = _instructionsController.text.trim();
    
    if (recipeName.isEmpty || ingredients.isEmpty) {
      _showErrorDialog('Please provide a recipe name and ingredients list');
      return;
    }
    
    setState(() {
      _isAnalyzing = true;
    });

    // Show animated loading screen
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AnimatedLoadingScreen(
          message: 'Generating your recipe...',
        ),
      );
    }

    try {
      final response = await AIRecipeService.analyzeRecipe(
        recipeName: recipeName,
        ingredients: ingredients,
        instructions: instructions,
        mealTime: _selectedMealTime,
      );
    
      if (mounted) {
        // Close loading screen
        Navigator.of(context).pop();
        
        setState(() {
          _isAnalyzing = false;
        });
        
        if (response != null) {
          // Navigate to results page and wait for result
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RecipeResultsPage(
                aiResponse: response,
                onSaveRecipe: (recipe) {
                  Navigator.of(context).pop({
                    'action': 'recipe_created',
                    'recipe': recipe,
                  });
                },
        ),
      ),
    );
          
          // If recipe was saved, return to the main app
          if (result != null && result['action'] == 'recipe_created') {
            Navigator.of(context).pop(result);
          }
        } else {
          _showErrorDialog('Failed to analyze recipe. Please try again.');
        }
      }
    } on RateLimitExceededException catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        setState(() { _isAnalyzing = false; });
        _showErrorDialog(e.toString());
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        setState(() { _isAnalyzing = false; });
        AppLogger.error('Recipe analysis failed', error: e, tag: 'RecipeCreator');
        _showErrorDialog('Failed to analyze recipe. Please check your connection and try again.');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Get status bar height for Dynamic Island devices
    final statusBarHeight = MediaQuery.of(context).padding.top;
    // Use minimal padding (8px) for status bar, allowing content behind Dynamic Island
    final topPadding = statusBarHeight > 0 ? 8.0 : 0.0;
    
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF0A192F),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A192F), Colors.black],
          ),
        ),
        child: SafeArea(
          top: false, // Allow content behind Dynamic Island
          child: Padding(
            padding: EdgeInsets.only(top: topPadding), // Minimal padding for status bar
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _buildInputSection(),
                ),
                _buildEmptyState(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.rw, 32.rh, 24.rw, 16.rh),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: const Text(
              'AI Recipe Creator',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(20),
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
    );
  }

  static const _labelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: Color(0xFF94A3B8),
  );

  Widget _buildInputSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.rw),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('RECIPE NAME', style: _labelStyle),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _recipeNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. High-Protein Salmon Bowl',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                ),
                contentPadding: EdgeInsets.all(16.r),
              ),
            ),
            SizedBox(height: 24.rh),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('INGREDIENTS', style: _labelStyle),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ingredientsController,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'List your ingredients here...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                ),
                contentPadding: EdgeInsets.all(16.r),
              ),
            ),
            SizedBox(height: 24.rh),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('INSTRUCTIONS', style: _labelStyle),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _instructionsController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'How do you make it?',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                ),
                contentPadding: EdgeInsets.all(16.r),
              ),
            ),
            SizedBox(height: 24.rh),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('MEAL TIME (OPTIONAL)', style: _labelStyle),
            ),
            const SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.rw),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMealTime,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF0A192F),
                  style: const TextStyle(color: Colors.white),
                  items: _mealTimes.map((String mealTime) {
                    return DropdownMenuItem<String>(
                      value: mealTime,
                      child: Text(
                        mealTime.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedMealTime = newValue;
                      });
                    }
                  },
                ),
              ),
            ),
            SizedBox(height: 24.rh),
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isAnalyzing ? null : _analyzeRecipe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isAnalyzing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12.rw),
                          const Text('Analyzing Recipe...'),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 22, color: Colors.white),
                          const SizedBox(width: 8),
                          const Text(
                            'Analyze Recipe',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            SizedBox(height: 24.rh),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.025),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              Icons.restaurant,
              size: 40,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          SizedBox(height: 16.rh),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.rw),
            child: Text(
              'Input your recipe details above to get a full macro breakdown and health score.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// Recipe Results Page
class RecipeResultsPage extends StatefulWidget {
  final AIRecipeResponse aiResponse;
  final Function(Recipe) onSaveRecipe;

  const RecipeResultsPage({
    super.key,
    required this.aiResponse,
    required this.onSaveRecipe,
  });

  @override
  State<RecipeResultsPage> createState() => _RecipeResultsPageState();
}

class _RecipeResultsPageState extends State<RecipeResultsPage> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    // Get status bar height for Dynamic Island devices
    final statusBarHeight = MediaQuery.of(context).padding.top;
    // Use minimal padding (8px) for status bar, allowing content behind Dynamic Island
    final topPadding = statusBarHeight > 0 ? 8.0 : 0.0;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A192F), Colors.black],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: _buildResultsContent(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.rw, vertical: 16.rh),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            ),
          ),
          const Text(
            'Recipe Analysis',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.more_horiz, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsContent(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.rw),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildRecipeSummaryCard(),
          SizedBox(height: 24.rh),
          _buildTotalsCard(),
          SizedBox(height: 24.rh),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ingredients',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '${widget.aiResponse.ingredients.length} Items',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.rh),
          ...widget.aiResponse.ingredients.map((ingredient) => _buildIngredientCard(ingredient)),
          SizedBox(height: 16.rh),
          _buildInstructionsSection(),
          SizedBox(height: 24.rh),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSaving ? null : () async {
                setState(() {
                  _isSaving = true;
                });
                try {
                  final recipe = Recipe.fromAIResponse(widget.aiResponse);
                  try {
                    final recipeData = {
                      'id': recipe.id,
                      'name': recipe.name,
                      'description': recipe.description,
                      'instructions': recipe.instructions,
                      'ingredients': recipe.ingredients.map((ingredient) => {
                        'id': ingredient.ingredient.id,
                        'name': ingredient.ingredient.name,
                        'icon': '🍽️',
                        'calories': ingredient.totalCalories.toInt(),
                        'protein': ingredient.totalProtein,
                        'carbs': ingredient.totalCarbs,
                        'fat': ingredient.totalFat,
                        'fiber': 0.0,
                      }).toList(),
                      'totalNutrition': {
                        'calories': recipe.nutritionTotals['calories']!,
                        'protein': recipe.nutritionTotals['protein']!,
                        'carbs': recipe.nutritionTotals['carbs']!,
                        'fat': recipe.nutritionTotals['fat']!,
                        'fiber': recipe.nutritionTotals['fiber']!,
                        'sugar': recipe.nutritionTotals['sugar'] ?? 0.0,
                        'sodium': recipe.nutritionTotals['sodium'] ?? 0.0,
                      },
                      'healthStar': widget.aiResponse.healthStar,
                      'createdAt': Timestamp.fromDate(recipe.createdAt),
                    };
                    await FirebaseService.saveRecipe(recipeData);
                  } catch (e) {
                    debugPrint('Error saving recipe to Firebase: $e');
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Recipe "${recipe.name}" saved successfully!'),
                      backgroundColor: const Color(0xFF10B981),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  widget.onSaveRecipe(recipe);
                } finally {
                  if (mounted) {
                    setState(() {
                      _isSaving = false;
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _emerald,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: _emerald.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: _isSaving
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12.rw),
                        const Text('Saving Recipe...'),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_add, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Save Recipe',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          SizedBox(height: 20.rh),
        ],
      ),
    );
  }

  static const Color _primaryBlue = Color(0xFF3B82F6);
  static const Color _emerald = Color(0xFF10B981);
  static const Color _emeraldChip = Color(0xFF34D399);
  static const Color _roseChip = Color(0xFFFB7185);
  static const Color _amberChip = Color(0xFFFBBF24);
  static const Color _purpleChip = Color(0xFFA78BFA);

  Widget _buildRecipeSummaryCard() {
    final totals = widget.aiResponse.totals;
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 4),
                decoration: BoxDecoration(
                  color: _primaryBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'AI ANALYZED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.aiResponse.recipeName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.aiResponse.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.65),
                ),
              ),
              SizedBox(height: 16.rh),
              Row(
                children: [
                  _quickStat(Icons.schedule, '— Min'),
                  SizedBox(width: 16.rw),
                  _quickStat(Icons.local_fire_department, '${totals.calories.toInt()} kcal'),
                  SizedBox(width: 16.rw),
                  _quickStat(Icons.restaurant, '1 Serving'),
                ],
              ),
              SizedBox(height: 12.rh),
              // Health Star Rating
              Row(
                children: [
                  const Text(
                    'Health Rating  ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  ...List.generate(5, (index) {
                    return Icon(
                      index < widget.aiResponse.healthStar
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 20,
                      color: index < widget.aiResponse.healthStar
                          ? const Color(0xFFFBBF24)
                          : Colors.white.withOpacity(0.15),
                    );
                  }),
                ],
              ),
            ],
          ),
          Positioned(
            right: -32,
            bottom: -32,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: _primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primaryBlue.withOpacity(0.15),
                    blurRadius: 48,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStat(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF60A5FA)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsSection() {
    if (widget.aiResponse.instructions.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.only(top: 8, bottom: 16.rh),
      title: const Text(
        'Instructions (optional)',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white.withOpacity(0.03),
      collapsedBackgroundColor: Colors.white.withOpacity(0.03),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.rw),
          child: Text(
            widget.aiResponse.instructions,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientCard(AIRecipeIngredient ingredient) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.rh),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(Icons.restaurant, color: Colors.white.withOpacity(0.3), size: 28),
          ),
          SizedBox(width: 16.rw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ingredient.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${ingredient.quantity} ${ingredient.unit}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${ingredient.calories.toInt()} kcal',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.rh),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _ingredientMacroPill('P', ingredient.protein, _emeraldChip),
                    _ingredientMacroPill('C', ingredient.carbs, _roseChip),
                    _ingredientMacroPill('F', ingredient.fat, _amberChip),
                    _ingredientMacroPill('Fb', ingredient.fiber, _purpleChip),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ingredientMacroPill(String prefix, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        '$prefix: ${value.toStringAsFixed(0)}g',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTotalsCard() {
    final totals = widget.aiResponse.totals;
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL NUTRITION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 16.rh),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${totals.calories.toInt()}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'CALORIES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(left: 24.rw),
                  padding: EdgeInsets.only(left: 24.rw),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTotalMacroCompact('Protein', '${totals.protein.toStringAsFixed(0)}g'),
                          ),
                          Expanded(
                            child: _buildTotalMacroCompact('Carbs', '${totals.carbs.toStringAsFixed(0)}g'),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.rh),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTotalMacroCompact('Fat', '${totals.fat.toStringAsFixed(0)}g'),
                          ),
                          Expanded(
                            child: _buildTotalMacroCompact('Fiber', '${totals.fiber.toStringAsFixed(0)}g'),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.rh),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTotalMacroCompact('Sugar', '${totals.sugar.toStringAsFixed(0)}g'),
                          ),
                          Expanded(
                            child: _buildTotalMacroCompact('Sodium', '${totals.sodium.toStringAsFixed(0)}mg'),
                          ),
                        ],
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

  Widget _buildTotalMacroCompact(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white.withOpacity(0.6),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

}

// Edit Recipe Page
class EditRecipePage extends StatefulWidget {
  final Recipe recipe;
  final Function(Recipe) onRecipeUpdated;

  const EditRecipePage({
    super.key,
    required this.recipe,
    required this.onRecipeUpdated,
  });

  @override
  State<EditRecipePage> createState() => _EditRecipePageState();
}

class _EditRecipePageState extends State<EditRecipePage> {
  final TextEditingController _recipeNameController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  bool _isAnalyzing = false;
  String _selectedMealTime = 'none';
  
  final List<String> _mealTimes = [
    'none',
    'breakfast',
    'lunch', 
    'dinner',
    'snacks'
  ];

  @override
  void initState() {
    super.initState();
    // Pre-populate fields with existing recipe data
    _recipeNameController.text = widget.recipe.name;
    _instructionsController.text = widget.recipe.instructions;
    
    // Convert ingredients to text format
    final ingredientsText = widget.recipe.ingredients.map((ingredient) {
      return '${ingredient.displayQuantity} ${ingredient.ingredient.name}';
    }).join(', ');
    _ingredientsController.text = ingredientsText;
  }

  @override
  void dispose() {
    _recipeNameController.dispose();
    _ingredientsController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _analyzeAndUpdateRecipe() async {
    final recipeName = _recipeNameController.text.trim();
    final ingredients = _ingredientsController.text.trim();
    final instructions = _instructionsController.text.trim();
    
    if (recipeName.isEmpty || ingredients.isEmpty) {
      _showErrorDialog('Please provide a recipe name and ingredients list');
      return;
    }
    
    setState(() {
      _isAnalyzing = true;
    });

    // Show animated loading screen
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AnimatedLoadingScreen(
          message: 'Updating your recipe...',
        ),
      );
    }

    try {
      final response = await AIRecipeService.analyzeRecipe(
        recipeName: recipeName,
        ingredients: ingredients,
        instructions: instructions,
        mealTime: _selectedMealTime,
      );
    
      if (mounted) {
        // Close loading screen
        Navigator.of(context).pop();
        
        setState(() {
          _isAnalyzing = false;
        });
        
        if (response != null) {
          // Navigate to results page and wait for result
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EditRecipeResultsPage(
                aiResponse: response,
                originalRecipe: widget.recipe,
                onUpdateRecipe: (updatedRecipe) {
                  Navigator.of(context).pop({
                    'action': 'recipe_updated',
                    'recipe': updatedRecipe,
                  });
                },
              ),
            ),
          );
          
          // If recipe was updated, return to the main app
          if (result != null && result['action'] == 'recipe_updated') {
            Navigator.of(context).pop(result);
          }
        } else {
          _showErrorDialog('Failed to analyze recipe. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        setState(() { _isAnalyzing = false; });
        AppLogger.error('Edit recipe analysis failed', error: e, tag: 'RecipeCreator');
        _showErrorDialog('Failed to analyze recipe. Please check your connection and try again.');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get status bar height for Dynamic Island devices
    final statusBarHeight = MediaQuery.of(context).padding.top;
    // Use minimal padding (8px) for status bar, allowing content behind Dynamic Island
    final topPadding = statusBarHeight > 0 ? 8.0 : 0.0;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A192F), Colors.black],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: Column(
              children: [
                _buildHeader(),
                _buildInputSection(),
                Expanded(
                  child: _buildEmptyState(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(24.r),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Edit Recipe',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
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
    );
  }

  Widget _buildInputSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.rw),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recipe Name:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _recipeNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g., "Chicken Stir-Fry"',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4361ee), width: 2),
                ),
                contentPadding: EdgeInsets.all(16.r),
              ),
            ),
            SizedBox(height: 16.rh),
            const Text(
              'Ingredients:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ingredientsController,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'e.g., "2 chicken breasts, 1 cup broccoli, 1/2 cup rice, 2 tbsp soy sauce, 2 cloves garlic"',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4361ee), width: 2),
                ),
                contentPadding: EdgeInsets.all(16.r),
              ),
            ),
            SizedBox(height: 16.rh),
            const Text(
              'Instructions (Optional):',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _instructionsController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g., "Cut chicken into strips, heat oil in pan, cook chicken until golden..."',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4361ee), width: 2),
                ),
                contentPadding: EdgeInsets.all(16.r),
              ),
            ),
            SizedBox(height: 16.rh),
            const Text(
              'Meal Time (Optional):',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.rw),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMealTime,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF0A192F),
                  style: const TextStyle(color: Colors.white),
                  items: _mealTimes.map((String mealTime) {
                    return DropdownMenuItem<String>(
                      value: mealTime,
                      child: Text(
                        mealTime.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedMealTime = newValue;
                      });
                    }
                  },
                ),
              ),
            ),
            SizedBox(height: 24.rh),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isAnalyzing ? null : _analyzeAndUpdateRecipe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4361ee),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isAnalyzing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12.rw),
                          const Text('Analyzing Recipe...'),
                        ],
                      )
                    : const Text(
                        'Update Recipe',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 20.rh),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.edit,
            size: 80,
            color: Colors.white54,
          ),
          SizedBox(height: 16.rh),
          const Text(
            'Edit your recipe details above, then tap "Update Recipe" to see the new nutritional breakdown',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Edit Recipe Results Page
class EditRecipeResultsPage extends StatefulWidget {
  final AIRecipeResponse aiResponse;
  final Recipe originalRecipe;
  final Function(Recipe) onUpdateRecipe;

  const EditRecipeResultsPage({
    super.key,
    required this.aiResponse,
    required this.originalRecipe,
    required this.onUpdateRecipe,
  });

  @override
  State<EditRecipeResultsPage> createState() => _EditRecipeResultsPageState();
}

class _EditRecipeResultsPageState extends State<EditRecipeResultsPage> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    // Get status bar height for Dynamic Island devices
    final statusBarHeight = MediaQuery.of(context).padding.top;
    // Use minimal padding (8px) for status bar, allowing content behind Dynamic Island
    final topPadding = statusBarHeight > 0 ? 8.0 : 0.0;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A192F), Colors.black],
          ),
        ),
        child: SafeArea(
          top: false, // Allow content behind Dynamic Island
          child: Padding(
            padding: EdgeInsets.only(top: topPadding), // Minimal padding for status bar
            child: Column(
              children: [
                // Header
                _buildHeader(context),
                
                // Results content
                Expanded(
                  child: _buildResultsContent(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24.r),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Updated Recipe',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
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
    );
  }

  Widget _buildResultsContent(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.rw),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecipeInfoCard(),
          SizedBox(height: 20.rh),
          const Text(
            'Ingredients:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12.rh),
          ...widget.aiResponse.ingredients.map((ingredient) => _buildIngredientCard(ingredient)),
          SizedBox(height: 20.rh),
          _buildTotalsCard(),
          SizedBox(height: 20.rh),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSaving ? null : () async {
                setState(() {
                  _isSaving = true;
                });
                try {
                  final updatedRecipe = Recipe(
                    id: widget.originalRecipe.id,
                    name: widget.aiResponse.recipeName,
                    description: widget.aiResponse.description,
                    instructions: widget.aiResponse.instructions,
                    ingredients: widget.aiResponse.ingredients.map((aiIngredient) {
                      final ingredient = Ingredient(
                        id: DateTime.now().millisecondsSinceEpoch,
                        name: aiIngredient.name,
                        calories: aiIngredient.calories.toInt(),
                        protein: aiIngredient.protein,
                        carbs: aiIngredient.carbs,
                        fat: aiIngredient.fat,
                        category: 'AI Generated',
                        servingSize: '${aiIngredient.quantity} ${aiIngredient.unit}',
                      );
                      return SelectedIngredient(
                        ingredient: ingredient,
                        quantity: aiIngredient.quantity,
                        servingMultiplier: '1x',
                        totalCalories: aiIngredient.calories,
                        totalProtein: aiIngredient.protein,
                        totalCarbs: aiIngredient.carbs,
                        totalFat: aiIngredient.fat,
                        displayQuantity: '${aiIngredient.quantity} ${aiIngredient.unit}',
                      );
                    }).toList(),
                    nutritionTotals: {
                      'calories': widget.aiResponse.totals.calories,
                      'protein': widget.aiResponse.totals.protein,
                      'carbs': widget.aiResponse.totals.carbs,
                      'fat': widget.aiResponse.totals.fat,
                      'fiber': widget.aiResponse.totals.fiber,
                      'sugar': widget.aiResponse.totals.sugar,
                      'sodium': widget.aiResponse.totals.sodium,
                    },
                    createdAt: widget.originalRecipe.createdAt,
                  );
                  try {
                    final recipeData = {
                      'id': updatedRecipe.id,
                      'name': updatedRecipe.name,
                      'description': updatedRecipe.description,
                      'instructions': updatedRecipe.instructions,
                      'ingredients': updatedRecipe.ingredients.map((ingredient) => {
                        'id': ingredient.ingredient.id,
                        'name': ingredient.ingredient.name,
                        'icon': '🍽️',
                        'calories': ingredient.totalCalories.toInt(),
                        'protein': ingredient.totalProtein,
                        'carbs': ingredient.totalCarbs,
                        'fat': ingredient.totalFat,
                        'fiber': 0.0,
                      }).toList(),
                      'totalNutrition': {
                        'calories': updatedRecipe.nutritionTotals['calories']!,
                        'protein': updatedRecipe.nutritionTotals['protein']!,
                        'carbs': updatedRecipe.nutritionTotals['carbs']!,
                        'fat': updatedRecipe.nutritionTotals['fat']!,
                        'fiber': updatedRecipe.nutritionTotals['fiber']!,
                        'sugar': updatedRecipe.nutritionTotals['sugar'] ?? 0.0,
                        'sodium': updatedRecipe.nutritionTotals['sodium'] ?? 0.0,
                      },
                      'createdAt': Timestamp.fromDate(updatedRecipe.createdAt),
                    };
                    await FirebaseService.updateRecipe(updatedRecipe.id, recipeData);
                  } catch (e) {
                    debugPrint('Error updating recipe in Firebase: $e');
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Recipe "${updatedRecipe.name}" updated successfully!'),
                      backgroundColor: const Color(0xFF10B981),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  widget.onUpdateRecipe(updatedRecipe);
                } finally {
                  if (mounted) {
                    setState(() {
                      _isSaving = false;
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: _isSaving
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12.rw),
                        const Text('Updating Recipe...'),
                      ],
                    )
                  : const Text(
                      'Save Updated Recipe',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 20.rh),
        ],
      ),
    );
  }

  Widget _buildRecipeInfoCard() {
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
            widget.aiResponse.recipeName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.aiResponse.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          SizedBox(height: 12.rh),
          const Text(
            'Instructions:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.aiResponse.instructions,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientCard(AIRecipeIngredient ingredient) {
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
              Expanded(
                child: Text(
                  ingredient.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '${ingredient.quantity} ${ingredient.unit}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.rh),
          Row(
            children: [
              Expanded(child: _buildMacroChip('Calories', '${ingredient.calories.toInt()}', const Color(0xFF4361ee))),
              const SizedBox(width: 8),
              Expanded(child: _buildMacroChip('Protein', '${ingredient.protein.toStringAsFixed(1)}g', const Color(0xFF4CAF50))),
              const SizedBox(width: 8),
              Expanded(child: _buildMacroChip('Carbs', '${ingredient.carbs.toStringAsFixed(1)}g', const Color(0xFFFF6B6B))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildMacroChip('Fat', '${ingredient.fat.toStringAsFixed(1)}g', const Color(0xFFFFD166))),
              const SizedBox(width: 8),
              Expanded(child: _buildMacroChip('Fiber', '${ingredient.fiber.toStringAsFixed(1)}g', const Color(0xFF9C27B0))),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard() {
    final totals = widget.aiResponse.totals;
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
            'Total Nutrition',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16.rh),
          Row(
            children: [
              Expanded(child: _buildTotalMacro('Calories', '${totals.calories.toInt()}', Colors.white)),
              SizedBox(width: 12.rw),
              Expanded(child: _buildTotalMacro('Protein', '${totals.protein.toStringAsFixed(1)}g', Colors.white)),
              SizedBox(width: 12.rw),
              Expanded(child: _buildTotalMacro('Carbs', '${totals.carbs.toStringAsFixed(1)}g', Colors.white)),
            ],
          ),
          SizedBox(height: 12.rh),
          Row(
            children: [
              Expanded(child: _buildTotalMacro('Fat', '${totals.fat.toStringAsFixed(1)}g', Colors.white)),
              SizedBox(width: 12.rw),
              Expanded(child: _buildTotalMacro('Fiber', '${totals.fiber.toStringAsFixed(1)}g', Colors.white)),
              SizedBox(width: 12.rw),
              Expanded(child: _buildTotalMacro('Sugar', '${totals.sugar.toStringAsFixed(1)}g', Colors.white)),
            ],
          ),
          SizedBox(height: 12.rh),
          Row(
            children: [
              Expanded(child: _buildTotalMacro('Sodium', '${totals.sodium.toStringAsFixed(0)}mg', Colors.white)),
              SizedBox(width: 12.rw),
              const Expanded(child: SizedBox()),
              SizedBox(width: 12.rw),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalMacro(String label, String value, Color color) {
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
}
