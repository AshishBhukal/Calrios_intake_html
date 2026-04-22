import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:fitness2/onboardingv2/onboarding_v2_data.dart';
import 'package:fitness2/onboardingv2/step_12.dart';
import '../features/extra/constants.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_helpers.dart';

// Match step_01 (Personalize Your Experience): same background and primary
const Color _kPrimary = Color(0xFF1E54FF);
const Color _kBackground = Color(0xFF0B1221);
const Color _kCardBg = Color(0xFF121c36);
const Color _kCardBorder = Color(0x1AFFFFFF);
const Color _kAccent = Color(0xFFfa6238);

/// Transition screen between step 11 and step 12.
/// Calls the Firebase `calculateOnboardingGoals` function, stores the results
/// in the data model, and then navigates to the final summary screen.
/// Falls back to local BMR/TDEE calculation on any error.
class OnboardingGoalCalculator extends StatefulWidget {
  final OnboardingV2Data data;

  const OnboardingGoalCalculator({super.key, required this.data});

  @override
  State<OnboardingGoalCalculator> createState() =>
      _OnboardingGoalCalculatorState();
}

class _OnboardingGoalCalculatorState extends State<OnboardingGoalCalculator>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _calculate();
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    try {
      final input = widget.data.toFunctionInput();
      final result = await FirebaseFunctions.instance
          .httpsCallable(
            'calculateOnboardingGoals',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          )
          .call(input);

      final resData = result.data;
      if (resData == null) throw Exception('Empty response');

      final data = resData['data'] as Map<dynamic, dynamic>?;
      if (data == null) throw Exception('Missing data payload');

      widget.data.dailyCalories =
          (data['dailyCalories'] as num?)?.toDouble();
      widget.data.protein = (data['protein'] as num?)?.toDouble();
      widget.data.carbs = (data['carbs'] as num?)?.toDouble();
      widget.data.fat = (data['fat'] as num?)?.toDouble();
      widget.data.waterIntake = (data['waterIntake'] as num?)?.toDouble();
      widget.data.aiExplanation = data['explanation'] as String?;
      widget.data.adjustedTimelineMonths =
          (data['adjustedTimelineMonths'] as num?)?.toInt();
      widget.data.timelineAdjustmentReason =
          data['adjustmentReason'] as String?;

      // Validate AI response values are within safe nutritional bounds
      final cal = widget.data.dailyCalories;
      final pro = widget.data.protein;
      final carb = widget.data.carbs;
      final fatVal = widget.data.fat;
      if (cal == null || cal < 800 || cal > 8000 ||
          pro == null || pro < 0 || pro > 500 ||
          carb == null || carb < 0 || carb > 1000 ||
          fatVal == null || fatVal < 0 || fatVal > 500) {
        throw Exception('AI returned out-of-range nutritional values');
      }
    } catch (e) {
      debugPrint('AI goal calculation failed, using local fallback: $e');
      if (mounted) setState(() => _failed = true);
      widget.data.calculateFallbackGoals();
    }

    if (!mounted) return;
    // Brief pause so the user sees the animation
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      OnboardingPageRoute(child: OnboardingStep12(data: widget.data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24.rw, 16.rh, 24.rw, 32.rh),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              SizedBox(height: 40.rh),
              // Hero badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20.rw, vertical: 12.rh),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _kPrimary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: _kAccent, size: 26),
                    const SizedBox(width: 10),
                    Text(
                      'PERSONALIZED PLAN',
                      style: TextStyle(
                        color: _kPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.auto_awesome, color: _kAccent, size: 26),
                  ],
                ),
              ),
              SizedBox(height: 28.rh),
              // Headline
              const Text(
                'Calculating your\npersonalized plan...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              SizedBox(height: 12.rh),
              Text(
                'Using AI to tailor your goals to your body and lifestyle',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 32.rh),
              // Card with spinner
              Container(
                padding: EdgeInsets.all(28.r),
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kCardBorder),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        color: _kPrimary,
                        strokeWidth: 4,
                      ),
                    ),
                    SizedBox(height: 20.rh),
                    Text(
                      'Calories · Protein · Carbs · Fat',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.rh),
              if (_failed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Using backup calculation',
                    style: TextStyle(
                      color: _kAccent.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
