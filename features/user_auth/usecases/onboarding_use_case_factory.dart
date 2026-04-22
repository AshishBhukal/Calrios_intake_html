import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitness2/features/user_auth/domain/onboarding_mode.dart';
import 'package:fitness2/features/user_auth/firebase_auth_implementation/firebase_auth_services.dart';
import 'package:fitness2/features/user_auth/usecases/complete_onboarding_use_case.dart';
import 'package:fitness2/features/user_auth/usecases/complete_email_signup_use_case.dart';
import 'package:fitness2/features/user_auth/usecases/complete_google_signup_use_case.dart';
import 'package:fitness2/utils/app_logger.dart';

/// Factory pattern: Creates appropriate use case based on context
/// This prevents scenario mix-ups by ensuring correct use case is used
class OnboardingUseCaseFactory {
  final FirebaseAuthService _authService;
  final Function(String uid) _saveUserData;

  OnboardingUseCaseFactory(
    this._authService,
    this._saveUserData,
  );

  /// Create use case based on onboarding context
  CompleteOnboardingUseCase create(OnboardingContext context) {
    AppLogger.log(
      'OnboardingUseCaseFactory: Creating use case for mode=${context.mode}',
      tag: 'UseCaseFactory',
    );

    switch (context.mode) {
      case OnboardingMode.emailSignup:
        return CompleteEmailSignupUseCase(_authService, _saveUserData);

      case OnboardingMode.googleSignup:
        if (context.prefilledEmail == null) {
          throw Exception('Google signup requires email');
        }
        return CompleteGoogleSignupUseCase(
          _authService,
          _saveUserData,
          context.prefilledEmail!,
        );

      case OnboardingMode.resumeOnboarding:
        // For resume, check if user is Google or email
        // This handles edge case where user started with Google but needs to resume
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && currentUser.providerData.any((p) => p.providerId == 'google.com')) {
          // User signed in with Google
          return CompleteGoogleSignupUseCase(
            _authService,
            _saveUserData,
            currentUser.email ?? context.prefilledEmail ?? '',
          );
        } else {
          // User signed in with email/password
          return CompleteEmailSignupUseCase(_authService, _saveUserData);
        }
    }
  }
}
