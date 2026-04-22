import 'package:flutter/material.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_data.dart';
import 'package:fitness2/onboardingv2/step_03.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_helpers.dart';

// Match step_01 (Personalize Your Experience): same background and continue button
const Color _kPrimary = Color(0xFF1E54FF);
const Color _kBackground = Color(0xFF0B1221);
const Color _kCardBg = Color(0xFF121c36);
const Color _kCardBorder = Color(0xFF1E293B); // navy-700 style for borders
const Color _kTextMuted = Color(0xFF94A3B8); // slate-400
const double _kCardRadius = 16.0;
const double _kButtonRadius = 16.0;

/// Step 2: Coffee comparison paywall – "Costs less than coffee", $8/month, benefits, Continue.
class OnboardingStep02 extends StatelessWidget {
  final OnboardingV2Data data;

  const OnboardingStep02({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgressBar(currentStep: 2),
            Expanded(
              child: OnboardingScrollBody(
                padding: EdgeInsets.fromLTRB(24.rw, 16.rh, 24.rw, 24.rh),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // Header: back button + "Pricing Plans" centered
              SizedBox(height: 8.rh),
              Row(
                children: [
                  _backButton(context),
                  Expanded(
                    child: Text(
                      'Pricing Plans',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _kTextMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(width: 40, height: 40),
                ],
              ),
              SizedBox(height: 24.rh),
              // Headline
              Text(
                'Costs less than coffee',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28.r,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 8.rh),
              Text(
                'Invest in yourself for the price of a drink',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _kTextMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 24.rh),
              // Two-card comparison grid (Premium | Coffee)
              Row(
                children: [
                  Expanded(child: _comparisonCard(
                    icon: Icons.workspace_premium,
                    label: 'Premium Access',
                    value: r'$8',
                    unit: '/mo',
                    isPrimary: true,
                  )),
                  SizedBox(width: 16.rw),
                  Expanded(child: _comparisonCard(
                    icon: Icons.coffee,
                    label: '2 Lattes',
                    value: r'$9',
                    unit: '',
                    isPrimary: false,
                  )),
                ],
              ),
              SizedBox(height: 20.rh),
              // Pill: 1 COFFEE = 1 MONTH OF RESULTS
              Container(
                padding: EdgeInsets.symmetric(vertical: 14.rh, horizontal: 16.rw),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kPrimary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: _kPrimary),
                    SizedBox(width: 8.rw),
                    Text(
                      '2 LATTES = 1 MONTH OF RESULTS',
                      style: TextStyle(
                        color: _kPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.rh),
              // Benefit cards
              _benefitRow(
                icon: Icons.payments,
                title: 'One simple payment',
                subtitle: 'Cancel anytime. No hidden fees.',
              ),
              SizedBox(height: 12.rh),
              _benefitRow(
                icon: Icons.all_inclusive,
                title: 'No multiple subscriptions',
                subtitle: 'All features unlocked in one place.',
              ),
              SizedBox(height: 24.rh),
            ],
                actionSection: Column(
                  children: [
                    _continueButton(context),
                    SizedBox(height: 12.rh),
                    Text(
                      'By continuing, you agree to our Terms of Service and Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _kTextMuted.withOpacity(0.9),
                        fontSize: 11,
                        height: 1.4,
                      ),
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

  Widget _backButton(BuildContext context) {
    return Material(
      color: _kCardBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.maybePop(context),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.arrow_back, size: 22, color: Colors.white),
        ),
      ),
    );
  }

  Widget _comparisonCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required bool isPrimary,
  }) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: _kCardBorder),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: _kPrimary.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isPrimary ? _kPrimary.withOpacity(0.12) : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 28,
              color: isPrimary ? _kPrimary : _kTextMuted,
            ),
          ),
          SizedBox(height: 16.rh),
          Text(
            label,
            style: TextStyle(
              color: _kTextMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: 4.rh),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: unit,
                  style: TextStyle(color: _kTextMuted, fontSize: 13, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.rh),
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: _kBackground.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPrimary ? Icons.self_improvement : Icons.coffee,
              size: 36,
              color: Colors.white.withOpacity(0.25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _continueButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            OnboardingPageRoute(child: OnboardingStep03(data: data)),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 18.rh),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kButtonRadius)),
          elevation: 0,
          shadowColor: _kPrimary.withOpacity(0.25),
        ),
        child: Row(
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

  Widget _benefitRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: _kCardBg.withOpacity(0.6),
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: _kCardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: _kPrimary),
          ),
          SizedBox(width: 16.rw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _kTextMuted,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
