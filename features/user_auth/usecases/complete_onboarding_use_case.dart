import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitness2/features/user_auth/domain/onboarding_mode.dart';
import 'package:fitness2/user_identification/onboarding.dart';
import 'package:fitness2/utils/app_logger.dart';

/// Industry standard: Use Case pattern
/// Separates business logic from UI
/// Each use case handles ONE specific scenario
abstract class CompleteOnboardingUseCase {
  Future<OnboardingResult> execute(OnboardingData data);
}

/// Result of onboarding completion
class OnboardingResult {
  final bool success;
  final User? user;
  final String? error;
  final bool requiresEmailVerification;
  final bool shouldSignOut;

  const OnboardingResult({
    required this.success,
    this.user,
    this.error,
    this.requiresEmailVerification = false,
    this.shouldSignOut = false,
  });

  factory OnboardingResult.success(User user, {bool shouldSignOut = false}) {
    return OnboardingResult(
      success: true,
      user: user,
      shouldSignOut: shouldSignOut,
    );
  }

  factory OnboardingResult.emailVerificationRequired(User user) {
    return OnboardingResult(
      success: true,
      user: user,
      requiresEmailVerification: true,
      shouldSignOut: true, // Always sign out if verification required
    );
  }

  factory OnboardingResult.failure(String error) {
    return OnboardingResult(success: false, error: error);
  }
}
