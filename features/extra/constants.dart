// lib/constants.dart

import 'package:flutter/material.dart';

/// Responsive scaling utility for adaptive layouts across screen sizes.
/// Reference design: iPhone X (375 × 812 logical pixels).
///
/// Call [Responsive.init] once (e.g. in MaterialApp.builder) before using
/// the [ResponsiveNum] extensions (.rw, .rh, .r).
class Responsive {
  Responsive._();

  static double _sw = 1.0;
  static double _sh = 1.0;
  static bool _ready = false;

  static const double _dw = 375.0;
  static const double _dh = 812.0;

  static void init(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    _sw = s.width / _dw;
    _sh = s.height / _dh;
    _ready = true;
  }

  static double w(double v) => _ready ? v * _sw : v;
  static double h(double v) => _ready ? v * _sh : v;
  static double r(double v) {
    if (!_ready) return v;
    return v * (_sw < _sh ? _sw : _sh);
  }
}

extension ResponsiveNum on num {
  /// Width-proportional value (horizontal padding, widths)
  double get rw => Responsive.w(toDouble());

  /// Height-proportional value (vertical padding, spacing)
  double get rh => Responsive.h(toDouble());

  /// Responsive value using the smaller scale factor (general padding)
  double get r => Responsive.r(toDouble());
}

class AppConstants {
  // SECURITY FIX: API keys removed from client code
  // All AI operations now use Firebase Cloud Functions with Secret Manager
  // See: functions/src/ for server-side implementations
  
  // Legacy constants (kept for reference, not used)
  // static const String baseUrl = 'https://api.openai.com/v1';
  // static const String defaultModel = 'gpt-3.5-turbo';
}

class DesignSystem {
  // Color Palette
  static const Color primary = Color(0xFF4361EE);
  static const Color primaryLight = Color(0xFF4895EF);
  static const Color primaryDark = Color(0xFF3A0CA3);
  static const Color accent = Color(0xFF4CC9F0);
  static const Color success = Color(0xFF38B000);
  static const Color warning = Color(0xFFFFAA00);
  static const Color danger = Color(0xFFF72585);
  static const Color dark = Color(0xFF0A192F);
  static const Color darker = Color(0xFF050C1A);
  static const Color darkCard = Color(0xFF121C36);
  static const Color borderDark = Color(0xFF1E293B);
  static const Color light = Color(0xFFF8F9FA);
  static const Color lightGray = Color(0xFFE9ECEF);
  static const Color mediumGray = Color(0xFFADB5BD);
  static const Color darkGray = Color(0xFF495057);
  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);
  static const Color platinum = Color(0xFFE5E4E2);

  // Glass Effect Colors
  static const Color cardBg = Color.fromRGBO(255, 255, 255, 0.03);
  static const Color cardBorder = Color.fromRGBO(255, 255, 255, 0.08);
  static const Color glassBg = Color.fromRGBO(16, 18, 37, 0.6);
  static const Color glassBorder = Color.fromRGBO(255, 255, 255, 0.1);

  // Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darker, dark],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient appBarGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primaryDark, dark],
  );

  static const LinearGradient textGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primaryLight, accent],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color.fromRGBO(67, 97, 238, 0.05), Colors.transparent],
    stops: [0.0, 0.6],
  );

  // Shadows
  static List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: primary.withOpacity(0.3),
      blurRadius: 15,
      offset: const Offset(0, 0),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: primary.withOpacity(0.3),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: primary.withOpacity(0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get buttonHoverShadow => [
    BoxShadow(
      color: primary.withOpacity(0.4),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  // Border Radius
  static const double cardRadius = 12.0;
  static const double buttonRadius = 12.0;
  static const double smallRadius = 8.0;

  // Spacing
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;

  // Typography
  static const TextStyle titleLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: light,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: light,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    color: light,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: light,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: light,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: light,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: light,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 14,
    color: mediumGray,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    color: mediumGray,
  );

  // Glass Card Decoration
  static BoxDecoration get glassCard => BoxDecoration(
    color: glassBg,
    borderRadius: BorderRadius.circular(cardRadius),
    border: Border.all(color: glassBorder, width: 1),
    boxShadow: glowShadow,
  );

  // Glassmorphic Decorations
  static BoxDecoration get glassmorphicCard => BoxDecoration(
    color: Colors.white.withOpacity(0.05),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: Colors.white.withOpacity(0.05)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration get glassmorphicButton => BoxDecoration(
    color: Colors.white.withOpacity(0.1),
    borderRadius: BorderRadius.circular(50),
    border: Border.all(color: Colors.white.withOpacity(0.1)),
  );

  // Button Decoration
  static BoxDecoration get primaryButton => BoxDecoration(
    gradient: primaryGradient,
    borderRadius: BorderRadius.circular(buttonRadius),
    boxShadow: buttonShadow,
  );
  
  // PHASE 4: Additional colors for consistency
  static const Color background = Color(0xFF0A192F); // Main app background
  static const Color dialogBg = Color(0xFF1E2A3A); // AlertDialog background
  static const Color textSecondary = Color.fromRGBO(255, 255, 255, 0.7);
  static const Color textMuted = Color.fromRGBO(255, 255, 255, 0.5);
}

/// PHASE 4: App Routes for consistent navigation
/// Use these constants instead of hardcoded strings
class AppRoutes {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String onboarding = '/onboarding';
  static const String splash = '/';
  
  // Navigation patterns documentation:
  // 1. pushNamedAndRemoveUntil(route, (route) => false) - Clear entire stack, go to route (login success, logout)
  // 2. pushReplacementNamed(route) - Replace current screen (back to login from signup)
  // 3. push(MaterialPageRoute(...)) - Add to stack, allow back navigation (settings, profiles)
}