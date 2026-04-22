/// Single source of truth for authentication and onboarding state
/// This prevents scenario mix-ups by centralizing all state resolution
enum UserAuthState {
  /// No user authenticated
  unauthenticated,
  
  /// User authenticated but email not verified (email/password accounts only)
  emailUnverified,
  
  /// User authenticated, email verified, but onboarding incomplete
  authenticatedIncomplete,
  
  /// User authenticated, email verified, onboarding complete
  authenticatedComplete,
}

/// Context for determining auth state
class AuthStateContext {
  final bool isAuthenticated;
  final bool isEmailVerified;
  final bool isOnboardingComplete;
  final String? uid;
  final String? email;

  const AuthStateContext({
    required this.isAuthenticated,
    required this.isEmailVerified,
    required this.isOnboardingComplete,
    this.uid,
    this.email,
  });

  /// Factory for unauthenticated state
  factory AuthStateContext.unauthenticated() {
    return const AuthStateContext(
      isAuthenticated: false,
      isEmailVerified: false,
      isOnboardingComplete: false,
    );
  }
}
