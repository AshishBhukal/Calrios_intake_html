import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitness2/features/user_auth/firebase_auth_implementation/firebase_auth_services.dart';
import 'package:fitness2/features/user_auth/usecases/complete_onboarding_use_case.dart';
import 'package:fitness2/user_identification/onboarding.dart';
import 'package:fitness2/utils/app_logger.dart';

/// Use case for Google signup flow
/// Handles account completion and data saving
class CompleteGoogleSignupUseCase implements CompleteOnboardingUseCase {
  final FirebaseAuthService _authService;
  final Function(String uid) _saveUserData;
  final String _email;

  CompleteGoogleSignupUseCase(
    this._authService,
    this._saveUserData,
    this._email,
  );

  @override
  Future<OnboardingResult> execute(OnboardingData data) async {
    try {
      AppLogger.log('CompleteGoogleSignupUseCase: Completing Google signup', tag: 'UseCase');

      // Ensure email is set
      data.email = _email.trim();

      // Check if user is already signed in
      User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        // Complete Google sign-in
        AppLogger.log('CompleteGoogleSignupUseCase: User not signed in, completing sign-in', tag: 'UseCase');
        user = await _authService.completeGoogleSignIn(_email);
      } else {
        AppLogger.log('CompleteGoogleSignupUseCase: User already signed in: ${user.uid}', tag: 'UseCase');
      }

      if (user == null) {
        return OnboardingResult.failure('Failed to complete Google sign-in');
      }

      // Save user data to Firestore
      AppLogger.log('CompleteGoogleSignupUseCase: Saving user data', tag: 'UseCase');
      await _saveUserData(user.uid);

      AppLogger.log(
        'CompleteGoogleSignupUseCase: Google signup completed successfully',
        tag: 'UseCase',
      );

      return OnboardingResult.success(user);
    } catch (e) {
      AppLogger.error(
        'CompleteGoogleSignupUseCase: Error',
        error: e,
        tag: 'UseCase',
      );
      return OnboardingResult.failure('Failed to complete signup: ${e.toString()}');
    }
  }
}
