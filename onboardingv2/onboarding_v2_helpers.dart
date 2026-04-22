import 'package:flutter/material.dart';

const int kOnboardingTotalSteps = 10;

/// Smooth fade + gentle slide transition for onboarding navigation.
class OnboardingPageRoute<T> extends PageRouteBuilder<T> {
  OnboardingPageRoute({required Widget child})
      : super(
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

/// Thin animated progress bar pinned at the top of each onboarding screen.
class OnboardingProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const OnboardingProgressBar({
    super.key,
    required this.currentStep,
    this.totalSteps = kOnboardingTotalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: (currentStep - 1) / totalSteps, end: currentStep / totalSteps),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Container(
          height: 3,
          color: Colors.white.withOpacity(0.06),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E54FF), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E54FF).withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Scrollable body that pins [actionSection] to the screen bottom when content
/// is shorter than the viewport, and scrolls normally when content overflows.
class OnboardingScrollBody extends StatelessWidget {
  final EdgeInsets padding;
  final CrossAxisAlignment crossAxisAlignment;
  final List<Widget> children;
  final Widget actionSection;

  const OnboardingScrollBody({
    super.key,
    required this.padding,
    required this.children,
    required this.actionSection,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  crossAxisAlignment: crossAxisAlignment,
                  children: children,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: actionSection,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
