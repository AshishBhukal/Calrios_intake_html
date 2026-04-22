import 'dart:io';
import 'dart:math';

/// Shared data collected during onboarding v2 flow.
/// Step 1: firstName, lastName, username, profileImage.
/// Step 3: gender, age, isImperial, heightCm, weightKg.
/// Step 5: primaryGoal, targetWeightKg, paceValue (0-100).
/// Step 7: workoutsPerWeek, dietPreference, trackFocus.
/// Step 9: challengesSelected.
/// Step 11: calorieExperience, startPreference.
/// Step 12: AI-calculated goals.
class OnboardingV2Data {
  String firstName;
  String lastName;
  String username;
  String gender;
  int age;
  bool isImperial;
  double heightCm;
  double weightKg;

  /// Profile image picked by user (null if skipped).
  File? profileImageFile;

  /// Profile image download URL after upload.
  String? profileImageUrl;

  /// 'lose_weight' | 'maintain' | 'gain_weight' | 'build_muscle'
  String primaryGoal;

  /// Target weight in kg (null if maintain).
  double? targetWeightKg;

  /// Slider 0-100 (slow to fast).
  int paceValue;

  /// 'light' | 'active' | 'athlete'
  String workoutsPerWeek;

  /// e.g. 'no_restrictions' | 'vegetarian' | 'vegan' | 'keto_paleo' | 'other'
  String dietPreference;

  /// 'calories' | 'workouts'
  String trackFocus;

  /// Up to 2 challenge keys.
  List<String> challengesSelected;

  /// 'experienced' | 'tried_few' | 'new'
  String calorieExperience;

  /// 'tips_tutorials' | 'basics'
  String startPreference;

  /// Selected "why now" reason keys.
  List<String> motivationReasons;

  // --- AI-calculated goals (set after step 11) ---
  double? dailyCalories;
  double? protein;
  double? carbs;
  double? fat;
  double? waterIntake;
  String? aiExplanation;
  int? adjustedTimelineMonths;
  String? timelineAdjustmentReason;

  /// Whether the user is already authenticated (e.g. resuming incomplete onboarding).
  bool isAlreadyAuthenticated;

  /// Pre-filled email for Google sign-in flow.
  String? prefilledEmail;

  /// Whether user came from Google sign-in.
  bool isGoogleSignIn;

  OnboardingV2Data({
    this.firstName = '',
    this.lastName = '',
    this.username = '',
    this.gender = 'female',
    this.age = 28,
    this.isImperial = true,
    this.heightCm = 175.0,
    this.weightKg = 70.0,
    this.profileImageFile,
    this.profileImageUrl,
    this.primaryGoal = 'lose_weight',
    this.targetWeightKg,
    this.paceValue = 50,
    this.workoutsPerWeek = 'active',
    this.dietPreference = 'no_restrictions',
    this.trackFocus = 'calories',
    List<String>? challengesSelected,
    this.calorieExperience = 'experienced',
    this.startPreference = 'tips_tutorials',
    List<String>? motivationReasons,
    this.dailyCalories,
    this.protein,
    this.carbs,
    this.fat,
    this.waterIntake,
    this.aiExplanation,
    this.adjustedTimelineMonths,
    this.timelineAdjustmentReason,
    this.isAlreadyAuthenticated = false,
    this.prefilledEmail,
    this.isGoogleSignIn = false,
  })  : challengesSelected = challengesSelected ?? [],
        motivationReasons = motivationReasons ?? [];

  /// Height in feet (imperial display).
  int get heightFeet => (heightCm / 30.48).floor();

  /// Height in inches remainder (imperial display).
  int get heightInches =>
      ((heightCm / 2.54) - (heightFeet * 12)).round().clamp(0, 11);

  /// Weight in lb (imperial display).
  int get weightLb => (weightKg * 2.205).round();

  void setHeightImperial(int feet, int inches) {
    heightCm = feet * 30.48 + inches * 2.54;
  }

  void setWeightLb(double lb) {
    weightKg = lb / 2.205;
  }

  /// Map workoutsPerWeek to the activity level expected by the Firebase function.
  String get activityLevel {
    switch (workoutsPerWeek) {
      case 'light':
        return 'Lightly Active';
      case 'active':
        return 'Moderately Active';
      case 'athlete':
        return 'Very Active';
      default:
        return 'Moderately Active';
    }
  }

  /// Map primaryGoal to the fitness goal string expected by the Firebase function.
  String get fitnessGoal {
    switch (primaryGoal) {
      case 'lose_weight':
        return 'Lose Weight';
      case 'maintain':
        return 'Maintain Weight';
      case 'gain_weight':
        return 'Gain Weight';
      case 'build_muscle':
        return 'Build Muscle';
      default:
        return 'Maintain Weight';
    }
  }

  /// Approximate dateOfBirth from age (function expects this).
  String get approximateDateOfBirth {
    final now = DateTime.now();
    final birthYear = now.year - age;
    return '$birthYear-01-01';
  }

  /// Generate a unique 10-char ID for the user.
  static String generateUniqueId() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Map v2 data to the Firebase function's expected input format.
  Map<String, dynamic> toFunctionInput() {
    final map = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender[0].toUpperCase() + gender.substring(1), // capitalize
      'dateOfBirth': approximateDateOfBirth,
      'weightUnit': 'kg',
      'heightUnit': 'cm',
      'currentWeight': weightKg,
      'height': heightCm,
      'activityLevel': activityLevel,
      'fitnessGoal': fitnessGoal,
    };
    if (targetWeightKg != null && primaryGoal != 'maintain') {
      map['goalWeight'] = targetWeightKg;
    }
    return map;
  }

  /// Produce the Firestore document matching the v1 schema so the rest of
  /// the app (calories tab, leaderboard, account, etc.) works unchanged.
  Map<String, dynamic> toFirebaseMap(String email) {
    final map = <String, dynamic>{
      'firstName': _sanitize(firstName, maxLength: maxNameLength),
      'lastName': _sanitize(lastName, maxLength: maxNameLength),
      'userName': _sanitize(username, maxLength: maxUsernameLength),
      'email': email,
      'gender': gender[0].toUpperCase() + gender.substring(1),
      'dob': {
        'year': (DateTime.now().year - age).toString(),
        'month': '1',
        'day': '1',
      },
      'age': age,
      'weight': weightKg,
      'height': heightCm,
      'weightUnit': isImperial ? 'lb' : 'kg',
      'heightUnit': isImperial ? 'ft-in' : 'cm',
      'distanceUnit': isImperial ? 'miles' : 'km',
      'energyUnit': isImperial ? 'cal' : 'kcal',
      'activityLevel': activityLevel,
      'fitnessGoal': fitnessGoal,
      'goals': {
        'calories': dailyCalories ?? 2000,
        'protein': protein ?? 150,
        'carbs': carbs ?? 250,
        'fat': fat ?? 65,
      },
      'waterGoal': waterIntake ?? 2500,
      'onboardingCompleted': true,
      'createdAt': DateTime.now().toIso8601String(),
      'uniqueID': generateUniqueId(),
      // v2-specific fields stored for reference
      'onboardingVersion': 2,
      'dietPreference': dietPreference,
      'trackFocus': trackFocus,
      'challengesSelected': challengesSelected,
      'calorieExperience': calorieExperience,
      'startPreference': startPreference,
      'motivationReasons': motivationReasons,
    };

    if (targetWeightKg != null && primaryGoal != 'maintain') {
      map['goalWeight'] = targetWeightKg;
    }
    if (profileImageUrl != null) {
      map['profileImageUrl'] = profileImageUrl;
    }
    if (aiExplanation != null) {
      map['aiExplanation'] = aiExplanation;
    }
    if (adjustedTimelineMonths != null) {
      map['timelineMonths'] = adjustedTimelineMonths;
    }
    return map;
  }

  /// Local fallback calorie/macro calculation using Mifflin-St Jeor + TDEE.
  void calculateFallbackGoals() {
    // BMR via Mifflin-St Jeor
    double bmr;
    if (gender == 'male') {
      bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
    } else {
      bmr = 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
    }

    // Activity multiplier
    double multiplier;
    switch (workoutsPerWeek) {
      case 'light':
        multiplier = 1.375;
        break;
      case 'athlete':
        multiplier = 1.725;
        break;
      default:
        multiplier = 1.55;
    }
    double tdee = bmr * multiplier;

    // Adjust for goal
    switch (primaryGoal) {
      case 'lose_weight':
        tdee -= 500;
        break;
      case 'gain_weight':
      case 'build_muscle':
        tdee += 300;
        break;
      default:
        break;
    }
    tdee = tdee.clamp(1200, 5000);

    dailyCalories = tdee.roundToDouble();
    protein = (weightKg * 1.8).roundToDouble();
    carbs = ((tdee * 0.45) / 4).roundToDouble();
    fat = ((tdee * 0.25) / 9).roundToDouble();
    waterIntake = (weightKg * 35).roundToDouble();
    aiExplanation =
        'Goals calculated locally based on your profile using the Mifflin-St Jeor equation.';
  }

  static const int maxNameLength = 50;
  static const int maxUsernameLength = 30;

  /// Sanitize free-text input: trim, strip control characters and common injection chars, enforce length.
  static String _sanitize(String input, {int maxLength = maxNameLength}) {
    var result = input
        .trim()
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'[<>{}\[\]\\/$]'), '');
    if (result.length > maxLength) result = result.substring(0, maxLength);
    return result;
  }

  /// Validate that all required onboarding fields are within acceptable bounds.
  /// Returns null if valid, or a user-facing error message.
  String? validate() {
    if (firstName.trim().isEmpty) return 'First name is required.';
    if (firstName.trim().length > maxNameLength) return 'First name is too long.';
    if (lastName.trim().length > maxNameLength) return 'Last name is too long.';
    if (username.trim().length < 3 || username.trim().length > maxUsernameLength) {
      return 'Username must be 3-$maxUsernameLength characters.';
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      return 'Username contains invalid characters.';
    }
    if (!const {'male', 'female', 'other'}.contains(gender)) {
      return 'Invalid gender selection.';
    }
    if (age < 18 || age > 100) return 'Age must be between 18 and 100.';
    if (heightCm < 100 || heightCm > 250) return 'Height is out of range.';
    if (weightKg < 30 || weightKg > 300) return 'Weight is out of range.';
    if (!const {'lose_weight', 'maintain', 'gain_weight', 'build_muscle'}.contains(primaryGoal)) {
      return 'Invalid goal selection.';
    }
    if (!const {'light', 'active', 'athlete'}.contains(workoutsPerWeek)) {
      return 'Invalid workout frequency.';
    }
    if (!const {'no_restrictions', 'vegetarian', 'vegan', 'keto_paleo', 'other'}.contains(dietPreference)) {
      return 'Invalid diet preference.';
    }
    if (!const {'calories', 'workouts'}.contains(trackFocus)) {
      return 'Invalid track focus.';
    }
    return null;
  }
}
