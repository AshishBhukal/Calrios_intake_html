import 'package:flutter/material.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_data.dart';
import 'package:fitness2/onboardingv2/onboarding_goal_calculator.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_helpers.dart';

// Match onv2/4. experience_quiz_corrected_blue.html
const Color _kPrimary = Color(0xFF1E54FF);
const Color _kBackground = Color(0xFF0B1221);
const Color _kCardBorder = Color(0x331E54FF); // primary/20
const Color _kCardBorderSelected = Color(0xFF1E54FF);
const Color _kRadioBorder = Color(0x4d1E54FF); // primary/30
const Color _kTextPrimary = Color(0xFFf8fafc);
const Color _kTextSecondary = Color(0xFF94a3b8);

/// Step 11: Quick question – calorie tracking experience + how to start.
class OnboardingStep11 extends StatefulWidget {
  final OnboardingV2Data data;

  const OnboardingStep11({super.key, required this.data});

  @override
  State<OnboardingStep11> createState() => _OnboardingStep11State();
}

class _OnboardingStep11State extends State<OnboardingStep11> {
  late String _experience;
  late String _startPreference;

  @override
  void initState() {
    super.initState();
    _experience = widget.data.calorieExperience;
    _startPreference = widget.data.startPreference;
  }

  void _onContinue() {
    widget.data.calorieExperience = _experience;
    widget.data.startPreference = _startPreference;
    Navigator.push(
      context,
      OnboardingPageRoute(child: OnboardingGoalCalculator(data: widget.data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgressBar(currentStep: 11),
            // Header: back only
            Padding(
              padding: EdgeInsets.fromLTRB(16.rw, 8.rh, 16.rw, 0),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => Navigator.maybePop(context),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.arrow_back,
                          size: 24,
                          color: _kTextPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable content
            Expanded(
              child: OnboardingScrollBody(
                padding: EdgeInsets.fromLTRB(24.rw, 24.rh, 24.rw, 24.rh),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Question 1
                    Text(
                      'Have you used calorie tracking apps before?',
                      style: TextStyle(
                        color: _kTextPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 24.rh),
                    _optionCard(
                      value: 'experienced',
                      groupValue: _experience,
                      onChanged: (v) => setState(() => _experience = v!),
                      label: "Yes, I'm experienced",
                    ),
                    SizedBox(height: 12),
                    _optionCard(
                      value: 'tried_few',
                      groupValue: _experience,
                      onChanged: (v) => setState(() => _experience = v!),
                      label: 'Tried a few',
                    ),
                    SizedBox(height: 12),
                    _optionCard(
                      value: 'new',
                      groupValue: _experience,
                      onChanged: (v) => setState(() => _experience = v!),
                      label: 'No, this is new to me',
                    ),
                    SizedBox(height: 40.rh),
                    // Reassuring info box
                    Container(
                      padding: EdgeInsets.all(20.r),
                      decoration: BoxDecoration(
                        color: _kPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kPrimary.withOpacity(0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: _kPrimary, size: 24),
                          SizedBox(width: 16.rw),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Don't worry — we make it simple for beginners!",
                                  style: TextStyle(
                                    color: _kTextPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "We'll guide you every step of the way with clear instructions.",
                                  style: TextStyle(
                                    color: _kTextSecondary,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 40.rh),
                    // Question 2
                    Text(
                      'How would you like to start?',
                      style: TextStyle(
                        color: _kTextPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 24.rh),
                    _optionCard(
                      value: 'tips_tutorials',
                      groupValue: _startPreference,
                      onChanged: (v) => setState(() => _startPreference = v!),
                      label: 'I want tips & tutorials',
                    ),
                    SizedBox(height: 12),
                    _optionCard(
                      value: 'basics',
                      groupValue: _startPreference,
                      onChanged: (v) => setState(() => _startPreference = v!),
                      label: 'Just show me the basics',
                    ),
                ],
                actionSection: _buildFooter(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(24.rw, 16.rh, 24.rw, 24.rh + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: _kBackground.withOpacity(0.85),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: Material(
            color: _kPrimary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _onContinue,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.rh),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _optionCard({
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
    required String label,
  }) {
    final selected = groupValue == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 16.rh),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _kCardBorderSelected : _kCardBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: _kTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _radioDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radioDot({required bool selected}) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? _kPrimary : _kRadioBorder,
          width: 2,
        ),
        color: selected ? _kPrimary : Colors.transparent,
      ),
      child: selected
          ? const Icon(Icons.circle, size: 8, color: Colors.white)
          : null,
    );
  }
}
