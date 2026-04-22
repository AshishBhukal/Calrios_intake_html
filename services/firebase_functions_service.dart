import 'package:cloud_functions/cloud_functions.dart';

/// Custom exception for rate limit errors
class RateLimitExceededException implements Exception {
  final String message;
  RateLimitExceededException(this.message);
  
  @override
  String toString() => message;
}

/// Service for calling Firebase Functions
class FirebaseFunctionsService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Call onboarding goals calculation function
  static Future<Map<String, dynamic>?> calculateOnboardingGoals({
    required String firstName,
    required String lastName,
    required String gender,
    required String dateOfBirth,
    required String weightUnit,
    required String heightUnit,
    required double currentWeight,
    required double height,
    required String activityLevel,
    required String fitnessGoal,
    double? goalWeight,
    int? timelineValue,
    String? timelineUnit,
  }) async {
    try {
      print('Calling calculateOnboardingGoals for $firstName with goal: $fitnessGoal');
      final callable = _functions.httpsCallable('calculateOnboardingGoals');
      
      final result = await callable.call({
        'firstName': firstName,
        'lastName': lastName,
        'gender': gender,
        'dateOfBirth': dateOfBirth,
        'weightUnit': weightUnit,
        'heightUnit': heightUnit,
        'currentWeight': currentWeight,
        'height': height,
        'activityLevel': activityLevel,
        'fitnessGoal': fitnessGoal,
        if (goalWeight != null) 'goalWeight': goalWeight,
        if (timelineValue != null) 'timelineValue': timelineValue,
        if (timelineUnit != null) 'timelineUnit': timelineUnit,
      });
      
      final data = result.data;
      print('calculateOnboardingGoals response received: ${data?.toString().substring(0, data.toString().length > 200 ? 200 : data.toString().length)}');
      
      if (data == null) {
        print('calculateOnboardingGoals returned null data');
        return null;
      }
      
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        
        print('Response keys: ${map.keys.toList()}');
        if (map.containsKey('success')) {
          print('Success: ${map['success']}');
        }
        if (map.containsKey('error')) {
          print('Error from function: ${map['error']}');
        }
        
        if (map['success'] == true && map.containsKey('data') && map['data'] is Map) {
          final unwrappedData = Map<String, dynamic>.from(map['data'] as Map);
          print('Returning unwrapped data with ${unwrappedData.keys.length} keys');
          return unwrappedData;
        }
        
        if (map['success'] == false) {
          final errorMsg = map['error']?.toString() ?? 'AI calculation failed';
          print('calculateOnboardingGoals returned success:false - $errorMsg');
          throw Exception(errorMsg);
        }
        
        if (map.containsKey('data') && map['data'] is Map) {
          final unwrappedData = Map<String, dynamic>.from(map['data'] as Map);
          return unwrappedData;
        }
        
        print('Returning map directly (unexpected structure)');
        return map;
      }
      
      print('calculateOnboardingGoals data is not a Map: ${data.runtimeType}');
      return null;
    } on FirebaseFunctionsException catch (e) {
      print('FirebaseFunctionsException calling calculateOnboardingGoals: ${e.code} - ${e.message} - ${e.details}');
      if (e.code == 'resource-exhausted') {
        throw RateLimitExceededException(
          'Daily AI usage limit exceeded. Please try again tomorrow.'
        );
      }
      if (e.code == 'unauthenticated') {
        print('User not authenticated during onboarding goals calculation');
        // Don't throw - allow fallback handling in the UI
      }
      return null;
    } on RateLimitExceededException {
      rethrow;
    } catch (e) {
      print('Unexpected error calling calculateOnboardingGoals: $e');
      return null;
    }
  }

  /// Call food analysis function
  static Future<Map<String, dynamic>?> analyzeFood({
    required String foodDescription,
  }) async {
    try {
      final callable = _functions.httpsCallable('analyzeFood');
      
      final result = await callable.call({
        'foodDescription': foodDescription,
      });
      final data = result.data;
      if (data == null) return null;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        
        if (map['success'] == false) {
          final errorMsg = map['error']?.toString() ?? 'AI analysis failed';
          print('analyzeFood returned success:false - $errorMsg');
          throw Exception(errorMsg);
        }
        
        if (map.containsKey('data') && map['data'] is Map) {
          return Map<String, dynamic>.from(map['data'] as Map);
        }
        return map;
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      print('Error calling analyzeFood: ${e.code} - ${e.message}');
      if (e.code == 'resource-exhausted') {
        throw RateLimitExceededException(
          'Daily AI usage limit exceeded. Please try again tomorrow.'
        );
      }
      return null;
    } on RateLimitExceededException {
      rethrow;
    } catch (e) {
      print('Error calling analyzeFood: $e');
      return null;
    }
  }

  /// Call AI image food analysis function
  static Future<Map<String, dynamic>?> analyzeFoodImage({
    required String imageUrl,
    required String requestId,
    String? clarificationText,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'analyzeFoodImage',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );
      
      final result = await callable.call({
        'imageUrl': imageUrl,
        'requestId': requestId,
        if (clarificationText != null && clarificationText.isNotEmpty)
          'clarificationText': clarificationText,
      });
      
      final data = result.data;
      if (data == null) return null;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      print('Error calling analyzeFoodImage: ${e.code} - ${e.message}');
      if (e.code == 'resource-exhausted') {
        throw RateLimitExceededException(
          'Daily image analysis limit exceeded (15/day). Please try again tomorrow.'
        );
      }
      if (e.code == 'deadline-exceeded') {
        throw Exception('Analysis timed out. Please try again with a clearer photo.');
      }
      return {'error': e.message ?? 'Image analysis failed'};
    } catch (e) {
      print('Error calling analyzeFoodImage: $e');
      return {'error': e.toString()};
    }
  }

  /// Call recipe generation function
  static Future<Map<String, dynamic>?> generateRecipe({
    required String recipeName,
    required String ingredients,
    String? instructions,
    String? mealTime,
  }) async {
    try {
      final callable = _functions.httpsCallable('generateRecipe');
      
      final result = await callable.call({
        'recipeName': recipeName,
        'ingredients': ingredients,
        if (instructions != null) 'instructions': instructions,
        if (mealTime != null) 'mealTime': mealTime,
      });
      final data = result.data;
      if (data == null) return null;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        
        if (map['success'] == false) {
          final errorMsg = map['error']?.toString() ?? 'Recipe generation failed';
          print('generateRecipe returned success:false - $errorMsg');
          throw Exception(errorMsg);
        }
        
        if (map.containsKey('data') && map['data'] is Map) {
          return Map<String, dynamic>.from(map['data'] as Map);
        }
        return map;
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      print('Error calling generateRecipe: ${e.code} - ${e.message}');
      if (e.code == 'resource-exhausted') {
        throw RateLimitExceededException(
          'Daily AI usage limit exceeded. Please try again tomorrow.'
        );
      }
      return null;
    } on RateLimitExceededException {
      rethrow;
    } catch (e) {
      print('Error calling generateRecipe: $e');
      return null;
    }
  }
}