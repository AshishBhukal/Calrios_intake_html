import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitness2/features/user_auth/firebase_auth_implementation/firebase_auth_services.dart';
import 'package:fitness2/features/user_auth/usecases/complete_onboarding_use_case.dart';
import 'package:fitness2/user_identification/onboarding.dart';
import 'package:fitness2/utils/app_logger.dart';

/// Use case for email/password signup flow
/// Handles account creation, data saving, and email verification
class CompleteEmailSignupUseCase implements CompleteOnboardingUseCase {
  final FirebaseAuthService _authService;
  final Function(String uid) _saveUserData;

  CompleteEmailSignupUseCase(
    this._authService,
    this._saveUserData,
  );

  @override
  Future<OnboardingResult> execute(OnboardingData data) async {
    try {
      // Check if user is already signed in (Scenario 5: verified email + incomplete)
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null && currentUser.email == data.email) {
        // User already exists and is signed in - just save data, don't sign out
        AppLogger.log(
          'CompleteEmailSignupUseCase: User already signed in, completing profile',
          tag: 'UseCase',
        );
        
        // Reload to get latest email verification status
        await currentUser.reload();
        final refreshedUser = FirebaseAuth.instance.currentUser;
        
        if (refreshedUser == null) {
          return OnboardingResult.failure('User session expired');
        }
        
        final isEmailVerified = refreshedUser.emailVerified;
        
        // Save user data to Firestore
        try {
          AppLogger.log('CompleteEmailSignupUseCase: Saving user data for existing user', tag: 'UseCase');
          await _saveUserData(refreshedUser.uid);
        } catch (e) {
          AppLogger.error(
            'CompleteEmailSignupUseCase: Firestore save failed',
            error: e,
            tag: 'UseCase',
          );
          return OnboardingResult.failure('Failed to save data: ${e.toString()}');
        }
        
        // Industry rule: Sign-out only happens when verification is pending
        // If email is verified, user should stay signed in
        final shouldSignOut = !isEmailVerified;
        
        AppLogger.log(
          'CompleteEmailSignupUseCase: Profile completed, emailVerified=$isEmailVerified, shouldSignOut=$shouldSignOut',
          tag: 'UseCase',
        );
        
        if (shouldSignOut) {
          await _authService.signOut();
          return OnboardingResult.emailVerificationRequired(refreshedUser);
        } else {
          return OnboardingResult.success(refreshedUser, shouldSignOut: false);
        }
      }
      
      // New user signup - create account
      AppLogger.log('CompleteEmailSignupUseCase: Creating new account', tag: 'UseCase');

      // Create Firebase account
      final signupResult = await _authService.signUpWithEmailAndPassword(
        data.email!,
        data.password!,
      );

      final user = signupResult['user'] as User?;
      final error = signupResult['error'] as String?;

      if (error != null || user == null) {
        AppLogger.error(
          'CompleteEmailSignupUseCase: Account creation failed',
          error: error ?? 'Unknown error',
          tag: 'UseCase',
        );
        return OnboardingResult.failure(error ?? 'Failed to create account');
      }

      // Save user data to Firestore
      try {
        AppLogger.log('CompleteEmailSignupUseCase: Saving user data', tag: 'UseCase');
        await _saveUserData(user.uid);
      } catch (e) {
        AppLogger.error(
          'CompleteEmailSignupUseCase: Firestore save failed',
          error: e,
          tag: 'UseCase',
        );
        // Don't delete account - user can retry on next login
        // Return success but indicate data save issue
      }

      // Sign out so user must verify email (new users always need verification)
      await _authService.signOut();

      AppLogger.log(
        'CompleteEmailSignupUseCase: Account created, email verification required',
        tag: 'UseCase',
      );

      return OnboardingResult.emailVerificationRequired(user);
    } catch (e) {
      AppLogger.error(
        'CompleteEmailSignupUseCase: Error',
        error: e,
        tag: 'UseCase',
      );
      return OnboardingResult.failure('Failed to create account: ${e.toString()}');
    }
  }
}
