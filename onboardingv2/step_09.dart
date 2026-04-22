import 'package:flutter/material.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_data.dart';
import 'package:fitness2/onboardingv2/onboarding_goal_calculator.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_helpers.dart';

// Match app theme + 7. user_challenges_onboarding.html
const Color _kPrimary = Color(0xFF1E54FF);
const Color _kBackground = Color(0xFF0B1221);
const Color _kCardBg = Color(0xFF121c36);
const Color _kCardBorder = Color(0x1AFFFFFF);
const double _kCardRadius = 16.0;

/// Challenge option: key for data, label for UI.
const List<MapEntry<String, String>> _kChallenges = [
  MapEntry('staying_consistent', 'Staying consistent'),
  MapEntry('knowing_what_to_eat', 'Knowing what to eat'),
  MapEntry('finding_time', 'Finding time to workout'),
  MapEntry('emotional_eating', 'Emotional eating'),
  MapEntry('no_meal_ideas', 'No meal ideas'),
  MapEntry('tracking_everything', 'Tracking everything'),
  MapEntry('staying_motivated', 'Staying motivated'),
];

/// Step 9: "What's been hardest for you?" – select top 2 challenges.
class OnboardingStep09 extends StatefulWidget {
  final OnboardingV2Data data;

  const OnboardingStep09({super.key, required this.data});

  @override
  State<OnboardingStep09> createState() => _OnboardingStep09State();
}

class _OnboardingStep09State extends State<OnboardingStep09> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.data.challengesSelected);
  }

  void _toggle(String key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else if (_selected.length < 2) {
        _selected.add(key);
      }
    });
  }

  void _onContinue() {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one challenge'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    widget.data.challengesSelected = List.from(_selected);
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
            const OnboardingProgressBar(currentStep: 9),
            Expanded(
              child: OnboardingScrollBody(
                padding: EdgeInsets.fromLTRB(24.rw, 16.rh, 24.rw, 24.rh),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Back button
              Material(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.maybePop(context),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.arrow_back, size: 22, color: Colors.white),
                  ),
                ),
              ),
              SizedBox(height: 16.rh),
              const Text(
                "What's been hardest for you?",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '(Select your top 2)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 24.rh),
              ..._kChallenges.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _challengeTile(e.key, e.value),
                  )),
              SizedBox(height: 20.rh),
              // Tip box
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kPrimary.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: _kPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lightbulb_outline, color: Colors.white, size: 20),
                    ),
                    SizedBox(width: 14.rw),
                    Expanded(
                      child: Text(
                        "We'll customize tips for YOUR specific struggles",
                        style: TextStyle(
                          color: _kPrimary.withOpacity(0.95),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.rh),
                ],
                actionSection: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 18.rh),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: _kPrimary.withOpacity(0.3),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _challengeTile(String key, String label) {
    final selected = _selected.contains(key);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kCardRadius),
        onTap: () => _toggle(key),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 14.rh),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(_kCardRadius),
            border: Border.all(color: selected ? _kPrimary : _kCardBorder, width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? _kPrimary : Colors.white24, width: 2),
                  color: selected ? _kPrimary : Colors.transparent,
                ),
                child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
