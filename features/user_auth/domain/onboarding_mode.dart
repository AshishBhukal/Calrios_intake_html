/// Onboarding flow modes - determines which use cases to execute
enum OnboardingMode {
  /// New user signing up with email/password
  emailSignup,
  
  /// New user signing up with Google
  googleSignup,
  
  /// Existing user completing incomplete profile
  resumeOnboarding,
}

/// Context for onboarding flow
class OnboardingContext {
  final OnboardingMode mode;
  final String? prefilledEmail;
  final bool isGoogleSignIn;

  const OnboardingContext({
    required this.mode,
    this.prefilledEmail,
    this.isGoogleSignIn = false,
  });

  factory OnboardingContext.emailSignup({String? prefilledEmail}) {
    return OnboardingContext(
      mode: OnboardingMode.emailSignup,
      prefilledEmail: prefilledEmail,
      isGoogleSignIn: false,
    );
  }

  factory OnboardingContext.googleSignup(String email) {
    return OnboardingContext(
      mode: OnboardingMode.googleSignup,
      prefilledEmail: email,
      isGoogleSignIn: true,
    );
  }

  factory OnboardingContext.resumeOnboarding({
    String? prefilledEmail,
    bool isGoogleSignIn = false,
  }) {
    return OnboardingContext(
      mode: OnboardingMode.resumeOnboarding,
      prefilledEmail: prefilledEmail,
      isGoogleSignIn: isGoogleSignIn,
    );
  }
}
