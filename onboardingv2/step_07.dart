import 'package:flutter/material.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_data.dart';
import 'package:fitness2/onboardingv2/step_08.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_helpers.dart';

// Match app card style (navy blue tint) like step_02 / step_03
const Color _kPrimary = Color(0xFF1E54FF);
const Color _kBackground = Color(0xFF0B1221);
const Color _kCardBg = Color(0xFF121c36);
const Color _kBorder = Color(0xFF1E293B);
const Color _kTextSecondary = Color(0xFF94A3B8);
const double _kCardRadius = 12.0;   // rounded-xl
const double _kCardRadiusLg = 16.0; // rounded-2xl
const double _kPillRadius = 9999.0; // rounded-full
const double _kButtonRadius = 12.0; // rounded-xl

/// Step 7: Your lifestyle – workouts per week, diet preference, track focus.
class OnboardingStep07 extends StatefulWidget {
  final OnboardingV2Data data;

  const OnboardingStep07({super.key, required this.data});

  @override
  State<OnboardingStep07> createState() => _OnboardingStep07State();
}

class _OnboardingStep07State extends State<OnboardingStep07> {
  late String _workouts;
  late String _diet;
  late String _track;

  @override
  void initState() {
    super.initState();
    _workouts = widget.data.workoutsPerWeek;
    _diet = widget.data.dietPreference;
    _track = widget.data.trackFocus;
    if (_track == 'both') _track = 'calories';
  }

  void _onContinue() {
    widget.data.workoutsPerWeek = _workouts;
    widget.data.dietPreference = _diet;
    widget.data.trackFocus = _track;
    Navigator.push(
      context,
      OnboardingPageRoute(child: OnboardingStep08(data: widget.data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgressBar(currentStep: 7),
            Expanded(
              child: OnboardingScrollBody(
                padding: EdgeInsets.fromLTRB(24.rw, 0, 24.rw, 24.rh),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Top bar: back button (match step_05 / step_08)
                    SizedBox(height: 8.rh),
                    Row(
                      children: [
                        _backButton(context),
                        const SizedBox(width: 28),
                      ],
                    ),
                    SizedBox(height: 24.rh),
                    // Header (match step_05 style)
                    const Text(
                      'Workout Preferences',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 8.rh),
                    Text(
                      "We'll tailor your plan based on how you train and eat.",
                      style: TextStyle(
                        color: _kTextSecondary,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 32.rh),
                    // Section: Workouts per week
                    Text(
                      'Workouts per week',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 16.rh),
                    _workoutCard('light', '0-2 (Light)', 'Occasional exercise or just starting'),
                    SizedBox(height: 12.rh),
                    _workoutCard('active', '3-5 (Active)', 'Consistent weekly routine'),
                    SizedBox(height: 12.rh),
                    _workoutCard('athlete', '6+ (Athlete)', 'High intensity daily training'),
                    SizedBox(height: 32.rh),
                    // Section: Diet Preference
                    Text(
                      'Diet Preference',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 12.rh),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _dietPill('no_restrictions', 'No restrictions'),
                          SizedBox(width: 8.rw),
                          _dietPill('vegetarian', 'Vegetarian'),
                          SizedBox(width: 8.rw),
                          _dietPill('vegan', 'Vegan'),
                          SizedBox(width: 8.rw),
                          _dietPill('keto_paleo', 'Keto/Paleo'),
                          SizedBox(width: 8.rw),
                          _dietPill('other', 'Other'),
                        ],
                      ),
                    ),
                    SizedBox(height: 32.rh),
                    // Section: What is your preference?
                    Text(
                      'What is your preference?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 16.rh),
                    Row(
                      children: [
                        Expanded(child: _trackCard('calories', 'Calories', Icons.restaurant)),
                        SizedBox(width: 16.rw),
                        Expanded(child: _trackCard('workouts', 'Workout', Icons.fitness_center)),
                      ],
                    ),
                ],
                actionSection: _continueButton(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.maybePop(context),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.chevron_left, size: 28, color: _kTextSecondary),
        ),
      ),
    );
  }

  Widget _continueButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onContinue,
          borderRadius: BorderRadius.circular(_kButtonRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(vertical: 16.rh),
            decoration: BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.circular(_kButtonRadius),
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8.rw),
                Icon(Icons.arrow_forward, size: 22, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _workoutCard(String value, String title, String subtitle) {
    final selected = _workouts == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kCardRadius),
        onTap: () => setState(() => _workouts = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 16.rh),
          decoration: BoxDecoration(
            color: selected ? _kPrimary.withOpacity(0.05) : _kCardBg,
            borderRadius: BorderRadius.circular(_kCardRadius),
            border: Border.all(
              color: selected ? _kPrimary : _kBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.rh),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _kTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? _kPrimary : _kBorder,
                    width: 2,
                  ),
                  color: selected ? _kPrimary : Colors.transparent,
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dietPill(String value, String label) {
    final selected = _diet == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kPillRadius),
        onTap: () => setState(() => _diet = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: 20.rw, vertical: 10.rh),
          decoration: BoxDecoration(
            color: selected ? _kPrimary : _kCardBg,
            borderRadius: BorderRadius.circular(_kPillRadius),
            border: Border.all(
              color: selected ? _kPrimary : _kBorder,
              width: 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _kPrimary.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _kTextSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _trackCard(String value, String label, IconData icon) {
    final selected = _track == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kCardRadiusLg),
        onTap: () => setState(() => _track = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: 24.rh, horizontal: 16.rw),
          decoration: BoxDecoration(
            color: selected ? _kPrimary : _kCardBg,
            borderRadius: BorderRadius.circular(_kCardRadiusLg),
            border: Border.all(
              color: selected ? _kPrimary : _kBorder,
              width: 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _kPrimary.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? Colors.white.withOpacity(0.2)
                      : _kPrimary.withOpacity(0.1),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: selected ? Colors.white : _kPrimary,
                ),
              ),
              SizedBox(height: 16.rh),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
