import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:fitness2/services/firebase_functions_service.dart';
import 'package:fitness2/widgets/animated_loading_screen.dart';
import 'package:fitness2/utils/input_sanitizer.dart';
import 'package:fitness2/Calories_widgets/voice_input_mixin.dart';
import 'package:fitness2/utils/app_logger.dart';
import '../features/extra/constants.dart';

// AI Food Response Models
class AIFoodItem {
  final String name;
  final double quantity;
  final String? unit;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;

  AIFoodItem({
    required this.name,
    required this.quantity,
    this.unit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    this.sugar = 0,
    this.sodium = 0,
  });

  factory AIFoodItem.fromJson(Map<String, dynamic> json) {
    return AIFoodItem(
      name: json['name'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      unit: json['unit'],
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

class AIFoodTotals {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;

  AIFoodTotals({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    this.sugar = 0,
    this.sodium = 0,
  });

  factory AIFoodTotals.fromJson(Map<String, dynamic> json) {
    return AIFoodTotals(
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

class AIFoodResponse {
  final List<AIFoodItem> items;
  final AIFoodTotals totals;
  final int healthStar; // 1-5 rating

  AIFoodResponse({
    required this.items,
    required this.totals,
    this.healthStar = 3,
  });

  factory AIFoodResponse.fromJson(Map<String, dynamic> json) {
    return AIFoodResponse(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => AIFoodItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      totals: AIFoodTotals.fromJson(Map<String, dynamic>.from(json['totals'] as Map)),
      healthStar: (json['healthStar'] as num?)?.toInt().clamp(1, 5) ?? 3,
    );
  }
}

// AI Food Service
/// ⚠️ DEPRECATED: This class is deprecated in favor of Firebase Cloud Functions.
/// All AI operations should use FirebaseFunctionsService instead.
/// 
/// SECURITY FIX: API key removed from client code.
/// API keys are now stored securely in Firebase Secret Manager.
class AIFoodService {
  // SECURITY FIX: API key removed from client code
  // All AI operations now use Firebase Cloud Functions with Secret Manager
  // See: functions/src/foodAnalysis.ts for server-side implementation
  // See: lib/services/firebase_functions_service.dart for client usage
  
  // Legacy constants removed - all AI operations now use Firebase Cloud Functions

  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan_calories.txt ID f_1a2b3c_calories
  @Deprecated('Use FirebaseFunctionsService.analyzeFood directly instead')
  static Future<AIFoodResponse?> analyzeFood(String foodDescription) async {
    // Note: This method is a thin wrapper around FirebaseFunctionsService.
    // Consider calling FirebaseFunctionsService.analyzeFood directly.
    try {
      // SECURITY FIX: Sanitize user input to prevent XSS attacks
      final sanitizedDescription = InputSanitizer.sanitizeFoodDescription(foodDescription);
      if (sanitizedDescription.isEmpty) {
        throw Exception('Food description cannot be empty after sanitization');
      }

      // Call Firebase Function instead of direct API
      final result = await FirebaseFunctionsService.analyzeFood(
        foodDescription: sanitizedDescription,
      );
      
      if (result == null) {
        return null;
      }
      
      // Convert Firebase Function response to AIFoodResponse
      return AIFoodResponse.fromJson(result);
    } catch (e) {
      AppLogger.error('Error calling Firebase Function', error: e, tag: 'AIFoodService');
      return null;
    }
  }

  // Legacy method removed - JSON extraction now handled by Firebase Functions
}

// AI Food Input Modal
class AIFoodInputModal extends StatefulWidget {
  final Function(AIFoodResponse) onFoodAnalyzed;

  const AIFoodInputModal({
    super.key,
    required this.onFoodAnalyzed,
  });

  @override
  State<AIFoodInputModal> createState() => _AIFoodInputModalState();
}

class _AIFoodInputModalState extends State<AIFoodInputModal> with VoiceInputMixin {
  final TextEditingController _foodController = TextEditingController();
  bool _isAnalyzing = false;
  AIFoodResponse? _lastResponse;

  @override
  void dispose() {
    _foodController.dispose();
    super.dispose();
  }

  Future<void> _analyzeFood() async {
    final foodDescription = _foodController.text.trim();
    if (foodDescription.isEmpty) return;
    
    // Dismiss keyboard (works on both iOS and Android)
    FocusScope.of(context).unfocus();
    // Also use SystemChannels to ensure keyboard is dismissed on all platforms
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    
    setState(() {
      _isAnalyzing = true;
    });

    // Show animated loading screen
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AnimatedLoadingScreen(
          message: 'Analyzing your food...',
        ),
      );
    }

    try {
      // SECURITY FIX: Sanitize user input to prevent XSS attacks
      final sanitizedDescription = InputSanitizer.sanitizeFoodDescription(foodDescription);
      if (sanitizedDescription.isEmpty) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Food description cannot be empty')),
          );
        }
        setState(() {
          _isAnalyzing = false;
        });
        return;
      }

      final response = await AIFoodService.analyzeFood(sanitizedDescription);
    
      if (mounted) {
        // Close loading screen
        Navigator.of(context).pop();
        
        setState(() {
          _isAnalyzing = false;
          _lastResponse = response;
        });
        // Dismiss keyboard after results are shown so user can see macros and Add to Daily Log button
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            FocusScope.of(context).unfocus();
            SystemChannels.textInput.invokeMethod('TextInput.hide');
          }
        });
      }
    } on RateLimitExceededException catch (e) {
      if (mounted) {
        // Close loading screen
        Navigator.of(context).pop();
        
        setState(() {
          _isAnalyzing = false;
        });
        _showErrorDialog(e.toString());
      }
    } catch (e) {
      if (mounted) {
        // Close loading screen
        Navigator.of(context).pop();
        
        setState(() {
          _isAnalyzing = false;
        });
        _showErrorDialog('Failed to analyze food. Please try again.');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _addToLog() {
    if (_lastResponse != null) {
      AppLogger.log('AI modal: Add to log button tapped', tag: 'AIFoodInput');
      Navigator.of(context).pop(); // Close AI modal first
      widget.onFoodAnalyzed(_lastResponse!); // Then trigger the callback
    }
  }

  // Design tokens from polished theme
  static const Color _primary = Color(0xFF3B82F6);
  static const Color _backgroundDark = Color(0xFF0A192F);
  static const double _radiusLg = 24.0;
  static const double _radiusFull = 40.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_backgroundDark, Colors.black],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar - wider, thinner, muted primary
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 16.rh, bottom: 8),
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.rw, vertical: 16.rh),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'AI Food Analysis',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
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
                      color: Colors.white70,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24.rw,
                right: 24.rw,
                bottom: _lastResponse != null ? 180.rh : 24.rh,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Input section
                  const SizedBox(height: 8),
                  Text(
                    'Describe what you ate',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  SizedBox(height: 12.rh),
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      TextField(
                        controller: _foodController,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        maxLines: 4,
                        minLines: 3,
                        decoration: InputDecoration(
                          hintText: 'e.g. 2 bananas with a glass of milk...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_radiusLg),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_radiusLg),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_radiusLg),
                            borderSide: BorderSide(color: _primary.withOpacity(0.5), width: 2),
                          ),
                          contentPadding: EdgeInsets.fromLTRB(20.rw, 20.rh, 52.rw, 20.rh),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(right: 8, bottom: 12.rh),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            buildVoiceMicButton(
                              controller: _foodController,
                              iconColor: Colors.white70,
                              listeningColor: Colors.red,
                              iconSize: 22,
                            ),
                            Icon(Icons.auto_awesome, size: 20, color: Colors.white.withOpacity(0.2)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.rh),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isAnalyzing ? null : _analyzeFood,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_radiusLg),
                        ),
                      ),
                      child: _isAnalyzing
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12.rw),
                                const Text('Analyzing...', style: TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.psychology_outlined, size: 22),
                                SizedBox(width: 10),
                                Text('Analyze Food', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                    ),
                  ),
                  SizedBox(height: 32.rh),
                  // Results or placeholder
                  if (_lastResponse != null) _buildResultsSection() else _buildPlaceholder(),
                ],
              ),
            ),
          ),
          // Sticky footer: Add to Daily Log + total
          if (_lastResponse != null) _buildStickyFooter(),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: 24.rh, bottom: 80.rh),
        child: Text(
          'Enter a food description and tap "Analyze Food" to see nutritional breakdown',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildStickyFooter() {
    final totals = _lastResponse!.totals;
    return Container(
      padding: EdgeInsets.fromLTRB(24.rw, 16.rh, 24.rw, 24.rh),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.8), Colors.black],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _addToLog,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 8,
            shadowColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radiusFull),
            ),
          ),
          child: Text(
            'Add to Daily Log (${totals.calories.toInt()} kcal)',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_lastResponse == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: 24.rh),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header: Detected Ingredients
          Text(
            'Detected Ingredients',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          SizedBox(height: 12.rh),
          ..._lastResponse!.items.map((item) => _buildFoodItemCard(item)),
        ],
      ),
    );
  }

  Widget _buildFoodItemCard(AIFoodItem item) {
    final description = item.unit != null
        ? '${item.quantity} ${item.unit}'
        : '${item.quantity} serving${item.quantity != 1 ? 's' : ''}';
    return Container(
      margin: EdgeInsets.only(bottom: 12.rh),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(_radiusLg),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${item.calories.toInt()} kcal',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.rh),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildNutrientPill('P', '${item.protein.toStringAsFixed(1)}g', const Color(0xFF60A5FA), const Color(0xFF3B82F6)),
              _buildNutrientPill('C', '${item.carbs.toStringAsFixed(1)}g', const Color(0xFFFBBF24), const Color(0xFFF59E0B)),
              _buildNutrientPill('F', '${item.fat.toStringAsFixed(1)}g', const Color(0xFFFB7185), const Color(0xFFF43F5E)),
              _buildNutrientPill('Fiber', '${item.fiber.toStringAsFixed(1)}g', const Color(0xFF34D399), const Color(0xFF10B981)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientPill(String label, String value, Color textColor, Color borderColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 6),
      decoration: BoxDecoration(
        color: borderColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

}
