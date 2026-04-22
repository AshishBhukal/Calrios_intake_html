import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitness2/services/firebase_service.dart';

class UnitPreferenceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Default unit preferences
  static const Map<String, String> defaultUnits = {
    'weight': 'kg',
    'height': 'cm',
    'distance': 'km',
    'energy': 'kcal',
  };

  /// Metric preset (kg, cm, km, kcal)
  static const Map<String, String> metricPreset = {
    'weight': 'kg',
    'height': 'cm',
    'distance': 'km',
    'energy': 'kcal',
  };

  /// Imperial preset (lb, ft-in, miles, cal)
  static const Map<String, String> imperialPreset = {
    'weight': 'lb',
    'height': 'ft-in',
    'distance': 'miles',
    'energy': 'cal',
  };

  /// Get user's unit preferences (uses FirebaseService user doc cache to avoid duplicate reads)
  static Future<Map<String, String>> getUserUnitPreferences() async {
    final user = _auth.currentUser;
    if (user == null) return defaultUnits;

    try {
      final data = await FirebaseService.getUserData();
      if (data != null) {
        return {
          'weight': data['weightUnit']?.toString() ?? defaultUnits['weight']!,
          'height': data['heightUnit']?.toString() ?? defaultUnits['height']!,
          'distance': data['distanceUnit']?.toString() ?? defaultUnits['distance']!,
          'energy': data['energyUnit']?.toString() ?? defaultUnits['energy']!,
        };
      }
    } catch (e) {
      print('Error fetching unit preferences: $e');
    }

    return defaultUnits;
  }

  /// Save user's unit preferences to Firebase
  static Future<void> saveUserUnitPreferences(Map<String, String> units) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (units.containsKey('weight')) updateData['weightUnit'] = units['weight'];
      if (units.containsKey('height')) updateData['heightUnit'] = units['height'];
      if (units.containsKey('distance')) updateData['distanceUnit'] = units['distance'];
      if (units.containsKey('energy')) updateData['energyUnit'] = units['energy'];
      await _firestore.collection('users').doc(user.uid).set(
        updateData,
        SetOptions(merge: true),
      );
      FirebaseService.invalidateUserDocumentCache();
    } catch (e) {
      print('Error saving unit preferences: $e');
      rethrow;
    }
  }

  /// Get user's preferred weight unit
  static Future<String> getWeightUnit() async {
    final preferences = await getUserUnitPreferences();
    return preferences['weight']!;
  }

  /// Get user's preferred height unit
  static Future<String> getHeightUnit() async {
    final preferences = await getUserUnitPreferences();
    return preferences['height']!;
  }

  /// Get user's preferred distance unit
  static Future<String> getDistanceUnit() async {
    final preferences = await getUserUnitPreferences();
    return preferences['distance']!;
  }

  /// Get user's preferred energy unit (kcal or cal)
  static Future<String> getEnergyUnit() async {
    final preferences = await getUserUnitPreferences();
    return preferences['energy']!;
  }
}

/// Unit conversion utilities
class UnitConverter {
  // Weight conversions (to kg)
  static double convertWeightToKg(double value, String fromUnit) {
    switch (fromUnit.toLowerCase()) {
      case 'lb':
      case 'lbs':
        return value * 0.453592;
      case 'kg':
        return value;
      default:
        return value;
    }
  }

  // Weight conversions (from kg)
  static double convertWeightFromKg(double kgValue, String toUnit) {
    switch (toUnit.toLowerCase()) {
      case 'lb':
      case 'lbs':
        return kgValue / 0.453592;
      case 'kg':
        return kgValue;
      default:
        return kgValue;
    }
  }

  // Height conversions (to cm)
  // Note: 'ft-in' unit stores height as total inches (e.g., 5'10" = 70 inches)
  static double convertHeightToCm(double value, String fromUnit) {
    switch (fromUnit.toLowerCase()) {
      case 'in':
      case 'inch':
      case 'inches':
      case 'ft-in': // ft-in stores value as total inches
        return value * 2.54;
      case 'ft':
      case 'feet':
        return value * 30.48;
      case 'cm':
        return value;
      default:
        return value;
    }
  }

  // Height conversions (from cm)
  // Note: 'ft-in' unit returns height as total inches (e.g., 177.8 cm = 70 inches = 5'10")
  static double convertHeightFromCm(double cmValue, String toUnit) {
    switch (toUnit.toLowerCase()) {
      case 'in':
      case 'inch':
      case 'inches':
      case 'ft-in': // ft-in returns value as total inches
        return cmValue / 2.54;
      case 'ft':
      case 'feet':
        return cmValue / 30.48;
      case 'cm':
        return cmValue;
      default:
        return cmValue;
    }
  }

  // Distance conversions (to km)
  static double convertDistanceToKm(double value, String fromUnit) {
    switch (fromUnit.toLowerCase()) {
      case 'miles':
      case 'mi':
        return value * 1.60934;
      case 'km':
        return value;
      case 'm':
        return value / 1000;
      default:
        return value;
    }
  }

  // Distance conversions (from km)
  static double convertDistanceFromKm(double kmValue, String toUnit) {
    switch (toUnit.toLowerCase()) {
      case 'miles':
      case 'mi':
        return kmValue / 1.60934;
      case 'km':
        return kmValue;
      case 'm':
        return kmValue * 1000;
      default:
        return kmValue;
    }
  }

  /// Format weight with unit
  static String formatWeight(double value, String unit, {int decimals = 1}) {
    final formattedValue = value.toStringAsFixed(decimals);
    return '$formattedValue $unit';
  }

  /// Format height with unit
  /// For ft-in: value should be total inches, will display as X'Y"
  static String formatHeight(double value, String unit, {int decimals = 1}) {
    if (unit.toLowerCase() == 'ft-in') {
      int totalInches = value.round();
      int feet = totalInches ~/ 12;
      int inches = totalInches % 12;
      return "$feet'$inches\"";
    }
    final formattedValue = value.toStringAsFixed(decimals);
    return '$formattedValue $unit';
  }
  
  /// Helper to parse ft-in string back to total inches
  /// Input format: 5'10" or 5'10 returns 70.0 (feet and inches)
  static double? parseFeetInches(String input) {
    // Remove any spaces and handle various formats
    final cleaned = input.replaceAll(' ', '');
    
    // Try to match patterns like 5'10", 5'10, 5ft10in, etc.
    final regex = RegExp(r"(\d+)['\s]*(?:ft)?['\s]*(\d+)?[\x22in]*");
    final match = regex.firstMatch(cleaned);
    
    if (match != null) {
      int feet = int.tryParse(match.group(1) ?? '0') ?? 0;
      int inches = int.tryParse(match.group(2) ?? '0') ?? 0;
      return (feet * 12 + inches).toDouble();
    }
    
    // If just a number, assume it's total inches
    return double.tryParse(cleaned);
  }

  /// Format distance with unit
  static String formatDistance(double value, String unit, {int decimals = 2}) {
    final formattedValue = value.toStringAsFixed(decimals);
    return '$formattedValue $unit';
  }

  /// Format energy with unit (kcal and cal are the same value, just different label)
  static String formatEnergy(double value, String unit, {int decimals = 0}) {
    final formattedValue = value.toStringAsFixed(decimals);
    return '$formattedValue $unit';
  }
}

/// Available unit options
class UnitOptions {
  static const List<String> weightUnits = ['kg', 'lb'];
  static const List<String> heightUnits = ['cm', 'ft-in']; // Standardized: cm or feet+inches
  static const List<String> distanceUnits = ['km', 'miles', 'm'];
  
  static const Map<String, String> weightUnitLabels = {
    'kg': 'Kilograms',
    'lb': 'Pounds',
  };
  
  static const Map<String, String> heightUnitLabels = {
    'cm': 'Centimeters',
    'ft-in': 'Feet & Inches',
  };
  
  static const Map<String, String> distanceUnitLabels = {
    'km': 'Kilometers',
    'miles': 'Miles',
    'm': 'Meters',
  };

  static const List<String> energyUnits = ['kcal', 'cal'];

  static const Map<String, String> energyUnitLabels = {
    'kcal': 'Kilocalories (kcal)',
    'cal': 'Calories (cal)',
  };
}
