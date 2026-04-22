import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'package:fitness2/utils/app_logger.dart';
import 'package:fitness2/utils/security_validator.dart';
import 'package:fitness2/features/user_auth/domain/auth_state_resolver.dart';
import 'package:fitness2/services/firebase_service.dart';

// one more
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save user progress
  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan.txt ID f_3w4x5y
  Future<void> saveUserProgress(
    String userId,
    Map<String, dynamic> progressData,
  ) async {
    SecurityValidator.validateUserId(userId);
    await _firestore
        .collection('users')
        .doc(userId)
        .set(progressData, SetOptions(merge: true));
  }

  // Get user progress
  Future<Map<String, dynamic>?> getUserProgress(String userId) async {
    DocumentSnapshot snapshot =
        await _firestore.collection('users').doc(userId).get();
    return snapshot.data() as Map<String, dynamic>?;
  }
}

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up with email and password
  Future<Map<String, dynamic>> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send email verification link
      if (credential.user != null) {
        try {
          await sendEmailVerification(credential.user!);
          AppLogger.log("Email verification link sent to $email", tag: 'Auth');
        } catch (e) {
          // If email verification fails, account is still created
          // Log the error but don't fail the signup
          AppLogger.error(
            "Error sending email verification, but account created",
            error: e,
            tag: 'Auth',
          );
        }
      }

      return {'user': credential.user, 'error': null}; // Return success
    } on FirebaseAuthException catch (e) {
      AppLogger.error("Error during sign up", error: e, tag: 'Auth');
      String errorMessage = _getAuthErrorMessage(e.code);
      return {'user': null, 'error': errorMessage};
    } catch (e) {
      AppLogger.error("Unexpected error during sign up", error: e, tag: 'Auth');
      return {
        'user': null,
        'error': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  // Get user-friendly error message from Firebase Auth error code
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'The email address is not valid. Please check and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again or reset your password.';
      case 'email-already-in-use':
        return 'An account already exists with this email. Please sign in instead.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password (at least 6 characters).';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      case 'requires-recent-login':
        return 'For security, please sign out and sign in again to continue.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials and try again.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please check and try again.';
      case 'invalid-verification-id':
        return 'Verification session expired. Please try again.';
      case 'credential-already-in-use':
        return 'This account is already linked to another account. Please use a different sign-in method.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      case 'invalid-action-code':
        return 'This link has expired or is invalid. Please request a new one.';
      case 'expired-action-code':
        return 'This link has expired. Please request a new one.';
      case 'user-mismatch':
        return 'The credentials provided do not match the current user.';
      case 'provider-already-linked':
        return 'This account is already linked to this sign-in method.';
      case 'no-auth-event':
        return 'Authentication session expired. Please try again.';
      case 'quota-exceeded':
        return 'Service temporarily unavailable. Please try again later.';
      case 'unverified-email':
        return 'Please verify your email address before signing in.';
      case 'missing-email':
        return 'Email address is required. Please provide a valid email.';
      case 'missing-password':
        return 'Password is required. Please provide a password.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  // Send email verification
  Future<void> sendEmailVerification(User user) async {
    try {
      if (!user.emailVerified) {
        await user.sendEmailVerification();
        AppLogger.log("Email verification sent", tag: 'Auth');
      }
    } on FirebaseAuthException catch (e) {
      AppLogger.error(
        "Error sending email verification",
        error: e,
        tag: 'Auth',
      );
      String errorMessage = _getAuthErrorMessage(e.code);
      throw Exception(errorMessage);
    } catch (e) {
      AppLogger.error(
        "Error sending email verification",
        error: e,
        tag: 'Auth',
      );
      throw Exception('Unable to send verification email. Please try again.');
    }
  }

  /// Send password reset email to the specified email address
  Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      AppLogger.log("Password reset email sent to $email", tag: 'Auth');
      return {'success': true, 'error': null};
    } on FirebaseAuthException catch (e) {
      AppLogger.error(
        "Error sending password reset email",
        error: e,
        tag: 'Auth',
      );
      String errorMessage = _getAuthErrorMessage(e.code);
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      AppLogger.error(
        "Unexpected error sending password reset email",
        error: e,
        tag: 'Auth',
      );
      return {
        'success': false,
        'error': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  // Sign in with email and password
  Future<Map<String, dynamic>> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return {'user': credential.user, 'error': null}; // Return success
    } on FirebaseAuthException catch (e) {
      AppLogger.error("Error during sign in", error: e, tag: 'Auth');
      String errorMessage = _getAuthErrorMessage(e.code);
      return {'user': null, 'error': errorMessage};
    } catch (e) {
      AppLogger.error("Unexpected error during sign in", error: e, tag: 'Auth');
      return {
        'user': null,
        'error': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  // Check if user exists by email
  Future<bool> checkUserExistsByEmail(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      AppLogger.error("Error checking if user exists", error: e, tag: 'Auth');
      return false;
    }
  }

  // Sign in with Google - returns user if exists, or email if new user
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      // Configure Google Sign-In with proper scopes
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      // Obtain the auth details from the request
      final GoogleSignInAuthentication? googleAuth =
          await googleUser?.authentication;

      if (googleAuth == null || googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      final email = googleUser.email;
      if (email == null) {
        AppLogger.error("Google sign-in: No email provided", tag: 'Auth');
        return null;
      }

      // Check if there's an existing email/password account with this email
      // This helps us handle the edge case where user signed up with email/password
      // but never verified, then signs in with Google using the same email
      final signInMethods = await _auth.fetchSignInMethodsForEmail(email);
      final hasEmailPassword = signInMethods.contains('password');

      // ALWAYS sign in first to get the user
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential;
      try {
        userCredential = await _auth.signInWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        // Handle account-exists-with-different-credential error
        // This happens when there's an unverified email/password account
        if (e.code == 'account-exists-with-different-credential') {
          AppLogger.log(
            'Google sign-in: Account exists with email/password. Email ownership proven via Google, but accounts cannot be automatically linked without password.',
            tag: 'Auth',
          );
          // Since Google sign-in proves email ownership, we can consider the email verified
          // However, Firebase requires the user to sign in with email/password first to link accounts
          // For now, we'll let the Google sign-in proceed (Firebase may create a new account or link automatically)
          // The user can use Google sign-in going forward
          AppLogger.log(
            'Proceeding with Google sign-in. User can use Google sign-in for this email going forward.',
            tag: 'Auth',
          );
          // Return null to show error, but actually we could try to continue
          // For better UX, let's show a helpful message
          return null;
        }
        rethrow;
      }

      final user = userCredential.user;

      if (user == null) {
        return null;
      }

      // Google accounts are automatically verified (Google verifies emails)
      // If there was an unverified email/password account, the user is now signed in with Google
      // which proves email ownership, so we can consider the email verified
      // Note: The Google account itself will have emailVerified = true
      if (hasEmailPassword) {
        AppLogger.log(
          'Google sign-in with email that had email/password account. Email ownership proven via Google sign-in.',
          tag: 'Auth',
        );
        // The Google account is verified, so email verification is not needed
        // User can continue using Google sign-in
      }

      // Check if user has data in Firestore (completed onboarding)
      final hasData = await isOnboardingComplete(user.uid);

      if (hasData) {
        // User has complete data → existing user with full profile
        AppLogger.log(
          'User has complete data, signing in to home',
          tag: 'Auth',
        );
        return {'user': user, 'isNewUser': false};
      } else {
        // User has NO data → send to onboarding to complete setup
        AppLogger.log(
          'User account exists but no Firestore data, sending to onboarding',
          tag: 'Auth',
        );

        // Return as new user to trigger onboarding flow
        // User will complete onboarding and create data
        return {'email': email, 'isNewUser': true, 'user': user};
      }
    } on FirebaseAuthException catch (e) {
      AppLogger.error("Error during Google sign in", error: e, tag: 'Auth');

      // Provide user-friendly error message
      if (e.code == 'account-exists-with-different-credential') {
        AppLogger.error(
          "Account exists with different credential. User should use email/password sign-in or verify their account.",
          tag: 'Auth',
        );
      }

      return null;
    } on PlatformException catch (e) {
      AppLogger.error(
        "Platform error during Google sign in",
        error: e,
        tag: 'Auth',
      );

      // Handle specific error codes
      if (e.code == 'sign_in_failed' && e.message?.contains('10') == true) {
        AppLogger.error(
          "DEVELOPER_ERROR (10): Google Sign-In is not properly configured. Check SHA-1 fingerprint and OAuth client configuration.",
          tag: 'Auth',
        );
      }
      return null;
    } catch (e) {
      AppLogger.error("Error during Google sign in", error: e, tag: 'Auth');
      return null;
    }
  }

  // Complete Google sign-in for new user after onboarding
  // This signs in the user with Google after they complete onboarding
  Future<User?> completeGoogleSignIn(String email) async {
    try {
      // Configure Google Sign-In with proper scopes
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Try to sign in silently first (uses cached Google account from initial sign-in)
      GoogleSignInAccount? googleUser = await googleSignIn.signInSilently();

      // If silent sign-in fails, prompt again (should be quick since user already authenticated)
      if (googleUser == null || googleUser.email != email) {
        googleUser = await googleSignIn.signIn();
        if (googleUser == null || googleUser.email != email) {
          AppLogger.error(
            'Google sign-in failed or email mismatch',
            tag: 'Auth',
          );
          return null;
        }
      }

      // Get authentication credentials
      final GoogleSignInAuthentication? googleAuth =
          await googleUser.authentication;
      if (googleAuth == null) {
        AppLogger.error('Failed to get Google authentication', tag: 'Auth');
        return null;
      }

      // Create credential and sign in to Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // Save user data to Firestore if it's a new user
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        final user = userCredential.user;
        if (user != null) {
          SecurityValidator.validateUserId(user.uid);
          await _firestore.collection('users').doc(user.uid).set({
            'email': user.email,
            'displayName': user.displayName ?? '',
            'photoURL': user.photoURL ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          FirebaseService.invalidateUserDocumentCache();
        }
      }

      return userCredential.user;
    } catch (e) {
      AppLogger.error("Error completing Google sign in", error: e, tag: 'Auth');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) AuthStateResolver.clearOnboardingCacheForUid(uid);
      FirebaseService.clearUserDocumentCache();
      // Sign out from Google if user signed in with Google
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      // Sign out from Firebase
      await _auth.signOut();
    } catch (e) {
      AppLogger.error("Error during sign out", error: e, tag: 'Auth');
    }
  }

  // Get the current user's UID
  String? getCurrentUserUID() {
    return _auth.currentUser?.uid; // Return the current user's UID
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  // Stream to listen to authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Delete user account
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      AppLogger.error("Error deleting account", error: e, tag: 'Auth');
      String errorMessage = _getAuthErrorMessage(e.code);
      throw Exception(errorMessage);
    } catch (e) {
      AppLogger.error("Error deleting account", error: e, tag: 'Auth');
      throw Exception('Unable to delete account. Please try again.');
    }
  }

  // Update user profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName);
      await _auth.currentUser?.updatePhotoURL(photoURL);
    } on FirebaseAuthException catch (e) {
      AppLogger.error("Error updating profile", error: e, tag: 'Auth');
      String errorMessage = _getAuthErrorMessage(e.code);
      throw Exception(errorMessage);
    } catch (e) {
      AppLogger.error("Error updating profile", error: e, tag: 'Auth');
      throw Exception('Unable to update profile. Please try again.');
    }
  }







  // Check if email is verified (for Firebase email verification)
  Future<bool> isEmailVerified(String email) async {
    try {
      final user = _auth.currentUser;
      if (user != null && user.email == email) {
        await user.reload();
        return user.emailVerified;
      }
      return false;
    } catch (e) {
      AppLogger.error(
        "Error checking email verification",
        error: e,
        tag: 'Auth',
      );
      return false;
    }
  }

  // Check if user has completed onboarding
  Future<bool> isOnboardingComplete(String? uid) async {
    if (uid == null) {
      AppLogger.log('isOnboardingComplete: uid is null', tag: 'Auth');
      return false;
    }

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        AppLogger.log(
          'isOnboardingComplete: User document does not exist for uid: $uid',
          tag: 'Auth',
        );
        return false;
      }

      final data = doc.data();
      if (data == null) {
        AppLogger.log('isOnboardingComplete: User data is null', tag: 'Auth');
        return false;
      }

      final onboardingCompleted = data['onboardingCompleted'] == true;

      AppLogger.log(
        'isOnboardingComplete: onboardingCompleted flag = $onboardingCompleted',
        tag: 'Auth',
      );

      // First check the explicit onboardingCompleted flag
      if (onboardingCompleted) {
        AppLogger.log(
          'isOnboardingComplete: Onboarding is complete (flag=true)',
          tag: 'Auth',
        );
        return true;
      }

      // If onboardingCompleted is not set, check for essential fields
      // This handles existing users who completed onboarding before this field was added
      final hasFirstName = data['firstName'] != null;
      final hasLastName = data['lastName'] != null;
      final hasWeight = data['weight'] != null;
      final hasHeight = data['height'] != null;
      final hasGoals = data['goals'] != null;

      AppLogger.log(
        'isOnboardingComplete: Essential fields - firstName: $hasFirstName, lastName: $hasLastName, weight: $hasWeight, height: $hasHeight, goals: $hasGoals',
        tag: 'Auth',
      );

      final hasEssentialFields =
          hasFirstName && hasLastName && hasWeight && hasHeight && hasGoals;

      if (hasEssentialFields) {
        AppLogger.log(
          'isOnboardingComplete: Onboarding is complete (essential fields present)',
          tag: 'Auth',
        );
      } else {
        AppLogger.log(
          'isOnboardingComplete: Onboarding is NOT complete (missing essential fields)',
          tag: 'Auth',
        );
      }

      return hasEssentialFields;
    } catch (e) {
      AppLogger.error(
        "Error checking onboarding completion",
        error: e,
        tag: 'Auth',
      );
      return false;
    }
  }
}
