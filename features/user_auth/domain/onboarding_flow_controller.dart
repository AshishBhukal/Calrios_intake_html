import 'package:fitness2/features/user_auth/domain/onboarding_mode.dart';
import 'package:fitness2/features/user_auth/domain/auth_state.dart';
import 'package:fitness2/utils/app_logger.dart';

/// Industry standard: Flow Orchestrator
/// Replaces giant if/else blocks with clear state machine
/// Prevents scenario mix-ups by centralizing flow decisions
class OnboardingFlowController {
  /// Determine onboarding context from auth state and login method
  OnboardingContext determineContext({
    required UserAuthState authState,
    required bool isGoogleSignIn,
    String? email,
  }) {
    AppLogger.log(
      'OnboardingFlowController: authState=$authState, isGoogleSignIn=$isGoogleSignIn',
      tag: 'OnboardingFlow',
    );

    switch (authState) {
      case UserAuthState.unauthenticated:
        // New signup
        if (isGoogleSignIn) {
          return OnboardingContext.googleSignup(email ?? '');
        } else {
          return OnboardingContext.emailSignup(prefilledEmail: email);
        }

      case UserAuthState.emailUnverified:
        // Should not reach onboarding - should verify email first
        AppLogger.warning(
          'OnboardingFlowController: User with unverified email reached onboarding',
          tag: 'OnboardingFlow',
        );
        return OnboardingContext.emailSignup(prefilledEmail: email);

      case UserAuthState.authenticatedIncomplete:
        // Resume incomplete onboarding - preserve sign-in method
        return OnboardingContext.resumeOnboarding(
          prefilledEmail: email,
          isGoogleSignIn: isGoogleSignIn,
        );

      case UserAuthState.authenticatedComplete:
        // Should not reach onboarding - already complete
        AppLogger.warning(
          'OnboardingFlowController: User with complete onboarding reached onboarding',
          tag: 'OnboardingFlow',
        );
        return OnboardingContext.resumeOnboarding(
          prefilledEmail: email,
          isGoogleSignIn: isGoogleSignIn,
        );
    }
  }

  /// Determine next step in onboarding flow
  /// This replaces conditional navigation logic
  OnboardingStep getNextStep({
    required OnboardingContext context,
    required int currentPage,
    required String? fitnessGoal,
  }) {
    // Special handling: Skip goal details page for non-weight goals
    if (currentPage == 4) {
      if (fitnessGoal != 'Lose Weight' && fitnessGoal != 'Build Muscle') {
        return OnboardingStep.accountCreation; // Skip to page 7
      }
    }

    // Account creation triggers AI processing
    if (currentPage == 6) {
      return OnboardingStep.aiProcessing;
    }

    // AI processing shows goals
    if (currentPage == 7) {
      return OnboardingStep.goalsPresentation;
    }

    // Goals presentation completes onboarding
    if (currentPage == 8) {
      return OnboardingStep.completed;
    }

    // Default: next page
    return OnboardingStep.values[currentPage + 1];
  }
}

/// Onboarding steps enum - replaces magic numbers
enum OnboardingStep {
  welcome,           // Page 0
  personalDetails,   // Page 1
  stats,             // Page 2
  activity,          // Page 3
  goals,             // Page 4
  goalDetails,       // Page 5
  accountCreation,   // Page 6
  aiProcessing,      // Page 7
  goalsPresentation, // Page 8
  completed,         // Page 9 (final)
}
