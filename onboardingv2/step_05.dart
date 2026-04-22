import 'package:flutter/material.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_data.dart';
import 'package:fitness2/onboardingv2/step_10.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_helpers.dart';

// Match onv2/9. goal_achievement_redesign.html: primary, navy palette, card styles
const Color _kPrimary = Color(0xFF1E54FF);
const Color _kBackground = Color(0xFF0B1221);
const Color _kNavy800 = Color(0xFF151E33);
const Color _kNavy700 = Color(0xFF1E293B);
const Color _kNavy600 = Color(0xFF334155);
const Color _kMuted = Color(0xFF94A3B8);
const Color _kTextWhite = Color(0xFFF8FAFC);
const double _kCardRadius = 12.0;
const double _kTargetCardRadius = 12.0;
const double _kButtonRadius = 12.0;
const double _kIconBoxSize = 48.0;
const double _kIconBoxRadius = 8.0;
const double _kRadioSize = 20.0;

/// Step 5: "What do you want to achieve?" – primary goal, target weight display, pace slider.
class OnboardingStep05 extends StatefulWidget {
  final OnboardingV2Data data;

  const OnboardingStep05({super.key, required this.data});

  @override
  State<OnboardingStep05> createState() => _OnboardingStep05State();
}

class _OnboardingStep05State extends State<OnboardingStep05> {
  late String _goal;
  late int _paceValue;

  @override
  void initState() {
    super.initState();
    _goal = widget.data.primaryGoal;
    _paceValue = widget.data.paceValue;
  }

  double get _currentKg => widget.data.weightKg;
  int get _currentLb => (_currentKg * 2.205).round();
  bool get _isImperial => widget.data.isImperial;

  double get _targetKg {
    switch (_goal) {
      case 'lose_weight':
        final delta = 2 + (_paceValue / 100) * 8;
        return (_currentKg - delta).clamp(30.0, _currentKg - 1);
      case 'gain_weight':
      case 'build_muscle':
        final delta = 2 + (_paceValue / 100) * 8;
        return _currentKg + delta;
      default:
        return _currentKg;
    }
  }

  int get _targetLb => (_targetKg * 2.205).round();

  String get _paceLabel {
    if (_goal == 'maintain') return '—';
    final perWeekLb = 0.25 + (_paceValue / 100) * 1.75;
    final perWeekKg = perWeekLb / 2.205;
    return _isImperial ? '${perWeekLb.toStringAsFixed(1)} lb/week' : '${perWeekKg.toStringAsFixed(1)} kg/week';
  }

  void _onContinue() {
    widget.data.primaryGoal = _goal;
    widget.data.paceValue = _paceValue;
    if (_goal != 'maintain') widget.data.targetWeightKg = _targetKg;
    Navigator.push(
      context,
      OnboardingPageRoute(child: OnboardingStep10(data: widget.data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textMuted = _kMuted;

    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgressBar(currentStep: 5),
            Expanded(
              child: OnboardingScrollBody(
                padding: EdgeInsets.fromLTRB(24.rw, 0, 24.rw, 24.rh),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Top bar: back button
                    SizedBox(height: 8.rh),
                    Row(
                      children: [
                        _backButton(),
                        const SizedBox(width: 28),
                      ],
                    ),
                    SizedBox(height: 24.rh),
                    // Header
                    const Text(
                      'What is your goal?',
                      style: TextStyle(
                        color: _kTextWhite,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 8.rh),
                    Text(
                      "We'll tailor your workout and nutrition plan based on your objective.",
                      style: TextStyle(color: textMuted, fontSize: 16, height: 1.5),
                    ),
                    SizedBox(height: 32.rh),
                    // Goal cards — gap-4 from reference
                    _goalCard(
                      value: 'lose_weight',
                      icon: Icons.fitness_center,
                      label: 'Lose Weight',
                      subtitle: 'Burn fat and get leaner with high intensity',
                    ),
                    SizedBox(height: 16.rh),
                    _goalCard(
                      value: 'maintain',
                      icon: Icons.speed,
                      label: 'Maintain',
                      subtitle: 'Keep your current physique and stay healthy',
                    ),
                    SizedBox(height: 16.rh),
                    _goalCard(
                      value: 'gain_weight',
                      icon: Icons.add_circle_outline,
                      label: 'Gain Weight',
                      subtitle: 'Increase mass and focus on calorie surplus',
                    ),
                    SizedBox(height: 16.rh),
                    _goalCard(
                      value: 'build_muscle',
                      icon: Icons.show_chart,
                      label: 'Build Muscle',
                      subtitle: 'Focus on strength and muscle definition',
                    ),
                    SizedBox(height: 40.rh),
                    // Weight Targets section (onv2 card; includes pace slider when not maintain)
                    _targetWeightCard(textMuted),
                    SizedBox(height: 32.rh),
                ],
                actionSection: Column(
                  children: [
                    _standardContinueButton(),
                    SizedBox(height: 16.rh),
                    Text(
                      'You can change your targets anytime in settings',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _kMuted.withOpacity(0.8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.maybePop(context),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.chevron_left, size: 28, color: _kMuted),
        ),
      ),
    );
  }

  Widget _paceSliderSection(Color textMuted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _goal == 'lose_weight' ? 'Losing Speed' : 'Gaining Speed',
              style: TextStyle(color: _kTextWhite.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 6),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _paceLabel,
                style: const TextStyle(color: _kPrimary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.rh),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _kPrimary,
            inactiveTrackColor: _kNavy700,
            thumbColor: _kPrimary,
            overlayColor: _kPrimary.withOpacity(0.2),
            trackHeight: 6,
          ),
          child: Slider(
            value: _paceValue.toDouble(),
            min: 0,
            max: 100,
            onChanged: (v) => setState(() => _paceValue = v.round()),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Steady',
              style: TextStyle(color: _kMuted.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold),
            ),
            Text(
              'Aggressive',
              style: TextStyle(color: _kMuted.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _standardContinueButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kButtonRadius),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _onContinue,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 18.rh),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kButtonRadius)),
          elevation: 0,
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
    );
  }

  Widget _goalCard({
    required String value,
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    final selected = _goal == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kCardRadius),
        onTap: () => setState(() => _goal = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 20.rw, vertical: 20.rh),
          decoration: BoxDecoration(
            color: _kNavy800,
            borderRadius: BorderRadius.circular(_kCardRadius),
            border: Border.all(
              color: selected ? _kPrimary : _kNavy700,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: _kIconBoxSize,
                height: _kIconBoxSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? _kPrimary.withOpacity(0.1) : _kNavy700,
                  borderRadius: BorderRadius.circular(_kIconBoxRadius),
                ),
                child: Icon(icon, size: 24, color: selected ? _kPrimary : _kMuted),
              ),
              SizedBox(width: 16.rw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: _kTextWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 4.rh),
                    Text(
                      subtitle,
                      style: TextStyle(color: _kMuted, fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
              Container(
                width: _kRadioSize,
                height: _kRadioSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? _kPrimary : _kNavy600,
                    width: 2,
                  ),
                  color: selected ? _kPrimary : Colors.transparent,
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _targetWeightCard(Color textMuted) {
    return Container(
      padding: EdgeInsets.all(24.rw),
      decoration: BoxDecoration(
        color: _kNavy800,
        borderRadius: BorderRadius.circular(_kTargetCardRadius),
        border: Border.all(color: _kNavy700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.touch_app, size: 22, color: _kPrimary),
              SizedBox(width: 8.rw),
              Text(
                'Weight Targets',
                style: TextStyle(
                  color: _kTextWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 24.rh),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Current',
                      style: TextStyle(
                        color: _kMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 4.rh),
                    Text.rich(
                      TextSpan(
                        text: _isImperial ? '$_currentLb' : '${_currentKg.round()}',
                        style: const TextStyle(
                          color: _kTextWhite,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(
                            text: _isImperial ? ' lbs' : ' kg',
                            style: TextStyle(
                              color: _kMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.rw),
                child: Icon(Icons.arrow_forward, size: 24, color: _kPrimary),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Target',
                      style: TextStyle(
                        color: _kMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 4.rh),
                    Text.rich(
                      TextSpan(
                        text: _isImperial ? '$_targetLb' : '${_targetKg.round()}',
                        style: const TextStyle(
                          color: _kPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(
                            text: _isImperial ? ' lbs' : ' kg',
                            style: TextStyle(
                              color: _kPrimary.withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_goal != 'maintain') ...[
            SizedBox(height: 32.rh),
            _paceSliderSection(textMuted),
          ],
        ],
      ),
    );
  }
}
