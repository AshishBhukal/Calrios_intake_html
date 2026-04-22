import 'package:flutter/material.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_data.dart';
import 'package:fitness2/onboardingv2/step_05.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_helpers.dart';

// Align with onv2 design system (step_01, step_07, onv2 HTML): navy background, brand blue, surface cards
const Color _kPrimary = Color(0xFF1E54FF);
const Color _kBackground = Color(0xFF0B1221);
const Color _kCardBg = Color(0xFF16161A);
const Color _kCardBorder = Color(0xFF2A2A2E);
const Color _kTextMuted = Color(0xFF94A3B8);
const double _kRadiusCard = 16.0;
const double _kRadiusButton = 12.0;
const double _kRadiusPill = 999.0;

/// Step 4: Motivation screen – "You CAN achieve this!", transformation card, 90% results, Continue.
class OnboardingStep04 extends StatelessWidget {
  final OnboardingV2Data data;

  const OnboardingStep04({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgressBar(currentStep: 4),
            Expanded(
              child: OnboardingScrollBody(
                padding: EdgeInsets.fromLTRB(24.rw, 20.rh, 24.rw, 24.rh),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _backButton(context),
              ),
              SizedBox(height: 28.rh),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    letterSpacing: -0.5,
                  ),
                  children: [
                    const TextSpan(text: 'You '),
                    TextSpan(text: 'CAN', style: TextStyle(color: _kPrimary)),
                    const TextSpan(text: ' achieve this!'),
                  ],
                ),
              ),
              SizedBox(height: 12.rh),
              Text(
                'Your fitness journey starts here',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _kTextMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 32.rh),
                    // Transformation card – surface-dark, border-dark, rounded-2xl
                    Container(
                      decoration: BoxDecoration(
                        color: _kCardBg,
                        borderRadius: BorderRadius.circular(_kRadiusCard),
                        border: Border.all(color: _kCardBorder, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(_kRadiusCard),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Image area
                            AspectRatio(
                              aspectRatio: 4 / 3,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.asset(
                                    'assets/jogging_man.png',
                                    fit: BoxFit.cover,
                                    alignment: Alignment.topCenter,
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      height: 100,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            _kCardBg.withOpacity(0.6),
                                            _kCardBg,
                                          ],
                                          stops: const [0.0, 0.5, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 20.rw,
                                    right: 20.rw,
                                    bottom: 20.rh,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 6.rh),
                                              decoration: BoxDecoration(
                                                color: _kPrimary,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: const Text(
                                                'TRANSFORMATION',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: 8.rh),
                                            const Text(
                                              'Month 1 → Month 3',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _progressDot(active: true),
                                            _progressDot(active: true),
                                            _progressDot(active: false),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(20.r),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Current Level',
                                        style: TextStyle(
                                          color: _kTextMuted,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Text(
                                        'Goal Reached',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12.rh),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: 0.75,
                                      backgroundColor: Colors.white.withOpacity(0.08),
                                      valueColor: const AlwaysStoppedAnimation<Color>(_kPrimary),
                                      minHeight: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24.rh),
                    // 90% results card – primary tint, rounded-2xl
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 28.rh, horizontal: 24.rw),
                      decoration: BoxDecoration(
                        color: _kPrimary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(_kRadiusCard),
                        border: Border.all(color: _kPrimary.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '90%',
                            style: TextStyle(
                              color: _kPrimary,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                          SizedBox(height: 10.rh),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                              children: [
                                const TextSpan(text: 'of users see visible results\n'),
                                TextSpan(
                                  text: 'in 30 days',
                                  style: TextStyle(
                                    color: _kPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 28.rh),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star_rounded, size: 22, color: _kPrimary),
                        SizedBox(width: 10.rw),
                        Text(
                          'With Breezi you are not alone',
                          style: TextStyle(
                            color: _kTextMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
      color: _kCardBg,
      borderRadius: BorderRadius.circular(_kRadiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(_kRadiusPill),
        onTap: () => Navigator.maybePop(context),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: const Icon(Icons.arrow_back, size: 22, color: Colors.white),
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
          onTap: () {
          Navigator.push(
            context,
            OnboardingPageRoute(child: OnboardingStep05(data: data)),
          );
        },
        borderRadius: BorderRadius.circular(_kRadiusButton),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: 18.rh),
          decoration: BoxDecoration(
            color: _kPrimary,
            borderRadius: BorderRadius.circular(_kRadiusButton),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              SizedBox(width: 10),
              Icon(Icons.arrow_forward, size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _progressDot({required bool active}) {
    return Container(
      margin: const EdgeInsets.only(left: 5),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? _kPrimary : Colors.white.withOpacity(0.25),
      ),
    );
  }
}
