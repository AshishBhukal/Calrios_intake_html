import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitness2/features/user_auth/domain/auth_state.dart';
import 'package:fitness2/features/user_auth/firebase_auth_implementation/firebase_auth_services.dart';
import 'package:fitness2/utils/app_logger.dart';

/// Industry standard: Single source of truth for auth state
/// Resolves user state once, prevents duplicate checks and scenario bugs
/// OPTIMIZED: Short-lived resolve cache + onboarding cache (plan: app_optimization_plan.txt)
class AuthStateResolver {
  static const Duration _resolveCacheTTL = Duration(seconds: 2);
  static const Duration _onboardingCacheTTL = Duration(minutes: 5);
  static const String _onboardingCompleteKeyPrefix = 'onboarding_complete_';
  static const String _onboardingCacheTimeKeyPrefix = 'onboarding_cache_time_';

  static final Map<String, _CachedResolve> _resolveCache = {};

  final FirebaseAuthService _authService;

  AuthStateResolver(this._authService);

  /// Clear onboarding cache for this uid (call on sign out).
  static Future<void> clearOnboardingCacheForUid(String? uid) async {
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_onboardingCompleteKeyPrefix$uid');
      await prefs.remove('$_onboardingCacheTimeKeyPrefix$uid');
    } catch (_) {}
  }

  /// Fast resolve using ONLY local caches - zero network calls.
  /// Returns null if no cached state is available (first-time user or cache expired).
  /// Use this for instant startup, then call resolve() in the background to verify.
  Future<AuthStateContext?> resolveFast() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return AuthStateContext.unauthenticated();
    }

    final uid = user.uid;
    final email = user.email;

    // Check in-memory resolve cache first (fastest)
    final cachedResolve = _resolveCache[uid];
    if (cachedResolve != null &&
        DateTime.now().difference(cachedResolve.cachedAt) < _resolveCacheTTL) {
      AppLogger.log('AuthStateResolver.resolveFast: using in-memory cache', tag: 'AuthState');
      return cachedResolve.context;
    }

    // Check SharedPreferences onboarding cache (no network, ~5ms)
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedVal = prefs.getBool('$_onboardingCompleteKeyPrefix$uid');
      if (cachedVal != null) {
        // We have a cached onboarding state - trust the persisted auth user
        // The persisted user already has emailVerified from the last session
        final isEmailVerified = user.emailVerified;

        AppLogger.log(
          'AuthStateResolver.resolveFast: instant resolve uid=$uid, emailVerified=$isEmailVerified, onboarding=$cachedVal',
          tag: 'AuthState',
        );

        final context = AuthStateContext(
          isAuthenticated: true,
          isEmailVerified: isEmailVerified,
          isOnboardingComplete: cachedVal,
          uid: uid,
          email: email,
        );
        return context;
      }
    } catch (_) {}

    // No cached state available - caller must use full resolve()
    return null;
  }

  /// Resolve current auth state - called once at entry points
  /// Uses short-lived resolve cache and onboarding cache for faster start/login
  Future<AuthStateContext> resolve() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      AppLogger.log('AuthStateResolver: User not authenticated', tag: 'AuthState');
      return AuthStateContext.unauthenticated();
    }

    final uid = user.uid;
    final email = user.email;

    final cachedResolve = _resolveCache[uid];
    if (cachedResolve != null &&
        DateTime.now().difference(cachedResolve.cachedAt) < _resolveCacheTTL) {
      AppLogger.log('AuthStateResolver: using cached resolve for $uid', tag: 'AuthState');
      return cachedResolve.context;
    }

    final results = await Future.wait([
      user.reload().then((_) => FirebaseAuth.instance.currentUser),
      _getOnboardingComplete(uid),
    ]);

    final refreshedUser = results[0] as User?;
    final isOnboardingComplete = results[1] as bool;

    if (refreshedUser == null) {
      return AuthStateContext.unauthenticated();
    }

    final isEmailVerified = refreshedUser.emailVerified;

    AppLogger.log(
      'AuthStateResolver: uid=$uid, emailVerified=$isEmailVerified, onboardingComplete=$isOnboardingComplete',
      tag: 'AuthState',
    );

    final context = AuthStateContext(
      isAuthenticated: true,
      isEmailVerified: isEmailVerified,
      isOnboardingComplete: isOnboardingComplete,
      uid: uid,
      email: email,
    );
    _resolveCache[uid] = _CachedResolve(context: context, cachedAt: DateTime.now());
    return context;
  }

  Future<bool> _getOnboardingComplete(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedVal = prefs.getBool('$_onboardingCompleteKeyPrefix$uid');
      final timeStr = prefs.getString('$_onboardingCacheTimeKeyPrefix$uid');
      if (cachedVal != null && timeStr != null) {
        final cachedAt = DateTime.tryParse(timeStr);
        if (cachedAt != null &&
            DateTime.now().difference(cachedAt) < _onboardingCacheTTL) {
          AppLogger.log('AuthStateResolver: using cached onboarding=$cachedVal', tag: 'AuthState');
          return cachedVal;
        }
      }
    } catch (_) {}

    final result = await _authService.isOnboardingComplete(uid);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_onboardingCompleteKeyPrefix$uid', result);
      await prefs.setString('$_onboardingCacheTimeKeyPrefix$uid', DateTime.now().toIso8601String());
    } catch (_) {}

    return result;
  }

  /// Determine the resolved state enum from context
  UserAuthState determineState(AuthStateContext context) {
    if (!context.isAuthenticated) {
      return UserAuthState.unauthenticated;
    }

    // For Google sign-in, email is always verified
    // For email/password, check verification status
    if (!context.isEmailVerified) {
      return UserAuthState.emailUnverified;
    }

    if (!context.isOnboardingComplete) {
      return UserAuthState.authenticatedIncomplete;
    }

    return UserAuthState.authenticatedComplete;
  }
}

class _CachedResolve {
  final AuthStateContext context;
  final DateTime cachedAt;
  _CachedResolve({required this.context, required this.cachedAt});
}
