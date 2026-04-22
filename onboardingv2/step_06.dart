import 'package:flutter/material.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_data.dart';
import 'package:fitness2/onboardingv2/step_07.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_helpers.dart';

// Match onv2/6. generated_screen_2.html reference: brandDeepNavy, brandVibrantBlue, brandCardBg
const Color _kPrimary = Color(0xFF1e54ff); // brandVibrantBlue
const Color _kBackground = Color(0xFF0b1221); // brandDeepNavy
const Color _kCardBg = Color(0xFF161f30); // brandCardBg
const Color _kCardBorder = Color(0x0DFFFFFF); // white/5
const Color _kAccent = Color(0xFFfa6238);
const double _kCardRadius = 24.0; // rounded-3xl
const double _kButtonRadius = 20.0; // rounded-2xl

/// Step 6: Consistency reward – 30% off for 14-day streak, pricing, Continue to Meals.
class OnboardingStep06 extends StatelessWidget {
  final OnboardingV2Data data;

  const OnboardingStep06({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgressBar(currentStep: 6),
            Expanded(
              child: OnboardingScrollBody(
                padding: EdgeInsets.fromLTRB(24.rw, 32.rh, 24.rw, 24.rh),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // Back button (reference: rounded-full, p-2)
              Align(
                alignment: Alignment.centerLeft,
                child: _backButton(context),
              ),
              SizedBox(height: 24.rh),
              // Hero badge (reference: uppercase tracking-widest, rounded-full, small text)
              Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 6.rh),
                  decoration: BoxDecoration(
                    color: _kPrimary,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: _kPrimary.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department, color: Colors.white, size: 18),
                      SizedBox(width: 6.rw),
                      Text(
                        '30% OFF FOR CONSISTENCY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(width: 6.rw),
                      Icon(Icons.local_fire_department, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32.rh),
              // Headline (reference: text-3xl/4xl font-extrabold, gray-400 subtitle)
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                  children: [
                    const TextSpan(text: 'Log your meals for 14 days '),
                    TextSpan(text: '→\n', style: TextStyle(color: _kPrimary)),
                    const TextSpan(text: 'Get 30% off'),
                  ],
                ),
              ),
              SizedBox(height: 8.rh),
              Text(
                'We reward consistency, not just signups!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 32.rh),
              // Streak meter card (reference: rounded-3xl, p-6, shadow-xl, border white/5)
              Container(
                padding: EdgeInsets.all(24.r),
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(_kCardRadius),
                  border: Border.all(color: _kCardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Current Streak',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '6 days achieved',
                                    style: TextStyle(
                                      color: _kPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const Text(
                                '42%',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20.rh),
                          Row(
                            children: [
                              ...List.generate(6, (_) => Expanded(child: _streakSegment(filled: true))),
                              ...List.generate(8, (_) => Expanded(child: _streakSegment(filled: false))),
                            ],
                          ),
                          SizedBox(height: 12.rh),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Day 0',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                'Target: Day 14',
                                style: TextStyle(
                                  color: _kPrimary.withOpacity(0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 28.rh),
                    // Pricing cards (reference: rounded-3xl, consistent padding)
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(20.r),
                            decoration: BoxDecoration(
                              color: _kCardBg,
                              borderRadius: BorderRadius.circular(_kCardRadius),
                              border: Border.all(color: _kCardBorder),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'STANDARD',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.45),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '\$8.00',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.35),
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                Text(
                                  'per month',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.45),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 16.rw),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.fromLTRB(20.rw, 28.rh, 20.rw, 20.rh),
                            decoration: BoxDecoration(
                              color: _kPrimary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(_kCardRadius),
                              border: Border.all(color: _kPrimary.withOpacity(0.6), width: 2),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: const BoxDecoration(
                                    color: _kPrimary,
                                    borderRadius: BorderRadius.all(Radius.circular(6)),
                                  ),
                                  child: const Text(
                                    'BEST VALUE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 12.rh),
                                Text(
                                  'CONSISTENCY PRICE',
                                  style: TextStyle(
                                    color: _kPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '\$5.60',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'per month',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.rh),
                    // Savings note (reference: pill style, clear hierarchy)
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 16.rh, horizontal: 20.rw),
                      decoration: BoxDecoration(
                        color: _kAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _kAccent.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.savings, color: _kAccent, size: 22),
                          SizedBox(width: 12.rw),
                          Text(
                            "That's \$29 saved/year!",
                            style: TextStyle(
                              color: _kAccent,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 28.rh),
                    Text(
                      '"The secret to results is showing up every day. We\'re here to make that habit stick."',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 32.rh),
                    // Trust indicator (reference: star icon + "With Breezi you are not alone")
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star_rounded, color: _kPrimary, size: 20),
                        SizedBox(width: 8.rw),
                        Text(
                          'With Breezi you are not alone',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
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
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Navigator.maybePop(context);
          });
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(Icons.arrow_back, size: 24, color: Colors.white),
        ),
      ),
    );
  }

  Widget _continueButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kButtonRadius),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Navigator.push(
              context,
              OnboardingPageRoute(child: OnboardingStep07(data: data)),
            );
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 20.rh),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kButtonRadius)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(width: 10.rw),
            Icon(Icons.arrow_forward, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _streakSegment({required bool filled}) {
    return Container(
      margin: const EdgeInsets.only(right: 3),
      height: 16,
      decoration: BoxDecoration(
        color: filled ? _kPrimary : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        boxShadow: filled ? [BoxShadow(color: _kPrimary.withOpacity(0.4), blurRadius: 6)] : null,
      ),
    );
  }
}
