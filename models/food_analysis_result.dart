import '../barcode_scanner_complete.dart';
import '../Calories_widgets/food.dart';

/// Enum representing the source of food analysis
enum FoodSource {
  aiText,
  aiImage,
  barcode,
  recipe,
}

/// Unified model for food items from any analysis source.
/// This normalizes data from AI text, AI image, barcode scanner, and recipes
/// into a single format for consistent handling in the food log.
class AnalyzedFoodItem {
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final int healthStar; // 1-5 rating
  final FoodSource source;
  /// Nutri-Score grade (A–E) for barcode products; null for other sources.
  final String? nutritionGrade;

  AnalyzedFoodItem({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    this.sugar = 0,
    this.sodium = 0,
    this.healthStar = 3,
    required this.source,
    this.nutritionGrade,
  });

  /// Create from AI text analysis result (AIFoodItem from food.dart)
  factory AnalyzedFoodItem.fromAIFoodItem(AIFoodItem item, {int healthStar = 3}) {
    return AnalyzedFoodItem(
      name: item.name,
      calories: item.calories.toInt(),
      protein: item.protein,
      carbs: item.carbs,
      fat: item.fat,
      fiber: item.fiber,
      sugar: item.sugar,
      sodium: item.sodium,
      healthStar: healthStar,
      source: FoodSource.aiText,
    );
  }

  /// Create from AI image analysis result (Map from Firebase Function)
  factory AnalyzedFoodItem.fromImageAnalysis(Map<String, dynamic> foodData) {
    return AnalyzedFoodItem(
      name: foodData['name'] ?? 'Unknown Food',
      calories: (foodData['calories'] as num?)?.toInt() ?? 0,
      protein: (foodData['protein'] as num?)?.toDouble() ?? 0,
      carbs: (foodData['carbs'] as num?)?.toDouble() ?? 0,
      fat: (foodData['fat'] as num?)?.toDouble() ?? 0,
      fiber: (foodData['fiber'] as num?)?.toDouble() ?? 0,
      sugar: (foodData['sugar'] as num?)?.toDouble() ?? 0,
      sodium: (foodData['sodium'] as num?)?.toDouble() ?? 0,
      healthStar: (foodData['healthStar'] as num?)?.toInt().clamp(1, 5) ?? 3,
      source: FoodSource.aiImage,
    );
  }

  /// Create from barcode scanner result (OpenFoodFactsProduct + ServingSize)
  factory AnalyzedFoodItem.fromBarcodeProduct(
    OpenFoodFactsProduct product,
    ServingSize serving,
  ) {
    final nutrition = product.nutritionInfo;
    final servingWeight = serving.gramWeight ?? 100.0;
    final multiplier = servingWeight / 100.0;

    return AnalyzedFoodItem(
      name: product.displayName,
      calories: ((nutrition?.calories100g ?? 0) * multiplier).round(),
      protein: (nutrition?.proteins100g ?? 0) * multiplier,
      carbs: (nutrition?.carbohydrates100g ?? 0) * multiplier,
      fat: (nutrition?.fat100g ?? 0) * multiplier,
      fiber: (nutrition?.fiber100g ?? 0) * multiplier,
      sugar: (nutrition?.sugars100g ?? 0) * multiplier,
      sodium: (nutrition?.sodium100g ?? 0) * multiplier * 1000, // convert g to mg
      healthStar: 3, // Barcode uses Nutri-Score grade instead
      source: FoodSource.barcode,
      nutritionGrade: product.nutritionGrade,
    );
  }

  /// Create from recipe (for future use)
  factory AnalyzedFoodItem.fromRecipe({
    required String name,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
    required double fiber,
    double sugar = 0,
    double sodium = 0,
    int healthStar = 3,
  }) {
    return AnalyzedFoodItem(
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      sugar: sugar,
      sodium: sodium,
      healthStar: healthStar,
      source: FoodSource.recipe,
    );
  }

  /// Get the icon for this food source
  String get icon {
    switch (source) {
      case FoodSource.aiText:
        return '🍽️';
      case FoodSource.aiImage:
        return '📸';
      case FoodSource.barcode:
        return '📦';
      case FoodSource.recipe:
        return '👨‍🍳';
    }
  }

  /// Get a unique ID for this food item based on timestamp and name
  String generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_$name';
  }
}

/// Extension to convert a list of image analysis results
extension ImageAnalysisListExtension on List<dynamic> {
  List<AnalyzedFoodItem> toAnalyzedFoodItems() {
    return map((foodData) => AnalyzedFoodItem.fromImageAnalysis(
      Map<String, dynamic>.from(foodData as Map),
    )).toList();
  }
}

/// Extension to convert AI food response items
extension AIFoodResponseExtension on AIFoodResponse {
  List<AnalyzedFoodItem> toAnalyzedFoodItems() {
    return items.map((item) => AnalyzedFoodItem.fromAIFoodItem(item, healthStar: healthStar)).toList();
  }
}
