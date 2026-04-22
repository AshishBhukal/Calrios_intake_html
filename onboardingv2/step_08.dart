import 'package:flutter/material.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_data.dart';
import 'package:fitness2/onboardingv2/step_09.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_helpers.dart';

// Match onv2 reference (8. generated_screen_4.html): brand-dark, brand-blue, brand-gray, brand-border
const Color _kBackground = Color(0xFF0b1221);
const Color _kPrimary = Color(0xFF1e54ff);
const Color _kBrandGray = Color(0xFF94a3b8);
const Color _kBrandBorder = Color(0xFF1e293b);
const Color _kCardBg = Color(0xFF0f172a); // slate-900/40 equivalent
const Color _kRed = Color(0xFFf87171);
const Color _kGreen = Color(0xFF4ade80);

const double _kRadiusCard = 20.0;
const double _kRadiusButton = 20.0;

/// Step 8: Your privacy matters – encryption hero, We'll NEVER / We WILL, Continue.
class OnboardingStep08 extends StatelessWidget {
  final OnboardingV2Data data;

  const OnboardingStep08({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgressBar(currentStep: 8),
            Expanded(
              child: OnboardingScrollBody(
                padding: EdgeInsets.fromLTRB(24.rw, 20.rh, 24.rw, 24.rh),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // Top navigation – back button (reference: rounded-full, minimal padding)
              Align(
                alignment: Alignment.centerLeft,
                child: _backButton(context),
              ),
              SizedBox(height: 32.rh),
              // Header section (reference: mb-10, text-center, title + subtitle)
              const Text(
                'Your privacy matters',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 12.rh),
              Text(
                'Your fitness data is secured and private.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _kBrandGray,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 40.rh),
              // Hero card: Bank-level encryption (reference: rounded-2xl, border-2 brand-blue, shadow)
              Container(
                padding: EdgeInsets.all(24.r),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(_kRadiusCard),
                  border: Border.all(color: _kPrimary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _kPrimary.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kPrimary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _kPrimary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.verified_user, color: Colors.white, size: 28),
                    ),
                    SizedBox(height: 16.rh),
                    const Text(
                      'Bank-level encryption',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'We protect your data with industry-standard security.',
                      style: TextStyle(
                        color: _kBrandGray,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.rh),
              // Section label: WE'LL NEVER (reference: uppercase, tracking, small, gray)
              Padding(
                padding: EdgeInsets.only(left: 4.rw, bottom: 10.rh),
                child: Text(
                  "WE'LL NEVER:",
                  style: TextStyle(
                    color: _kBrandGray,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(_kRadiusCard),
                  border: Border.all(color: _kBrandBorder),
                ),
                child: Column(
                  children: [
                    _privacyRow(icon: Icons.cancel, iconColor: _kRed, label: 'Sell your data', showDivider: true),
                    _privacyRow(icon: Icons.cancel, iconColor: _kRed, label: 'Share with third parties', showDivider: true),
                    _privacyRow(icon: Icons.cancel, iconColor: _kRed, label: 'Spam your email', showDivider: false),
                  ],
                ),
              ),
              SizedBox(height: 24.rh),
              Padding(
                padding: EdgeInsets.only(left: 4.rw, bottom: 10.rh),
                child: Text(
                  "WE WILL:",
                  style: TextStyle(
                    color: _kPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(_kRadiusCard),
                  border: Border.all(color: _kPrimary.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    _privacyRow(icon: Icons.check_circle, iconColor: _kGreen, label: 'Help you reach goals', showDivider: true),
                    _privacyRow(icon: Icons.check_circle, iconColor: _kGreen, label: 'Support your journey', showDivider: true),
                    _privacyRow(icon: Icons.check_circle, iconColor: _kGreen, label: 'Celebrate wins with you', showDivider: false),
                  ],
                ),
              ),
              SizedBox(height: 32.rh),
              // Footer: disclaimer (reference: text-center, small, gray)
              Text(
                "By continuing, you agree to Breezi's Privacy Policy and Terms of Service.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _kBrandGray,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 24.rh),
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
        onTap: () => Navigator.maybePop(context),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: const Icon(Icons.arrow_back, size: 24, color: Colors.white),
        ),
      ),
    );
  }

  Widget _continueButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: _kPrimary,
        borderRadius: BorderRadius.circular(_kRadiusButton),
        shadowColor: _kPrimary.withOpacity(0.2),
        elevation: 8,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              OnboardingPageRoute(child: OnboardingStep09(data: data)),
            );
          },
          borderRadius: BorderRadius.circular(_kRadiusButton),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20.rh),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 12),
                Icon(Icons.arrow_forward, color: Colors.white, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _privacyRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.rw, vertical: 16.rh),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              SizedBox(width: 16.rw),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: _kBrandBorder, indent: 20.rw, endIndent: 20.rw),
      ],
    );
  }
}
