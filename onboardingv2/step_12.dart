import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitness2/onboardingv2/onboarding_v2_data.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_helpers.dart';

// Match onv2/11. refined_plan_summary.html
const Color _kPrimary = Color(0xFF1E54FF);
const Color _kBackground = Color(0xFF0B1221);
const Color _kCardBg = Color(0xFF0E1B35);
const Color _kCardBorder = Color(0x400E1B35); // blue-900/40
const Color _kCardBorderMuted = Color(0xFF1E293B); // slate-800
const Color _kInputBg = Color(0xFF1e293b);
const Color _kAccent = Color(0xFFFB923C); // orange-400 celebration
const Color _kBlueLabel = Color(0xFF3B82F6); // blue-500
const Color _kBlueValue = Color(0xFF60A5FA); // blue-400
const Color _kIndigoHighlight = Color(0xFF818CF8); // indigo-400
const Color _kRed = Color(0xFFEF4444);
const Color _kTextMuted = Color(0xFF94A3B8); // slate-400
const double _kAuthRadius = 12.0;
const double _kRadiusCard = 16.0; // rounded-2xl
const double _kRadiusInner = 12.0; // rounded-xl

/// Step 12: Your plan is ready – dynamic AI targets, incentives, START MY JOURNEY → auth + save.
class OnboardingStep12 extends StatefulWidget {
  final OnboardingV2Data data;

  const OnboardingStep12({super.key, required this.data});

  @override
  State<OnboardingStep12> createState() => _OnboardingStep12State();
}

class _OnboardingStep12State extends State<OnboardingStep12> {
  bool _isSaving = false;

  // ── Formatters ────────────────────────────────────────────────────────
  String _fmtCal(double? v) =>
      NumberFormat('#,###').format((v ?? 2000).round());
  String _fmtG(double? v) => '${(v ?? 0).round()}g';

  String _goalLine() {
    final d = widget.data;
    switch (d.primaryGoal) {
      case 'maintain':
        return 'Maintain your weight';
      case 'lose_weight':
        if (d.targetWeightKg == null || d.targetWeightKg! >= d.weightKg) {
          return 'Reach your target weight';
        }
        final lbs = ((d.weightKg - d.targetWeightKg!) * 2.205).round();
        final weeks = (lbs * 1.2).round().clamp(2, 52);
        return 'Lose $lbs lbs in ~$weeks weeks';
      case 'gain_weight':
      case 'build_muscle':
        if (d.targetWeightKg == null || d.targetWeightKg! <= d.weightKg) {
          return 'Reach your target weight';
        }
        final lbs = ((d.targetWeightKg! - d.weightKg) * 2.205).round();
        final weeks = (lbs * 1.5).round().clamp(2, 52);
        return 'Gain $lbs lbs in ~$weeks weeks';
      default:
        return 'Customized for your goals';
    }
  }

  // ── START MY JOURNEY ──────────────────────────────────────────────────

  void _onStartJourney() {
    if (widget.data.isAlreadyAuthenticated) {
      // User is already signed in (resuming incomplete onboarding)
      _saveAndNavigate();
    } else {
      _showAuthSheet();
    }
  }

  // ── Auth bottom sheet ─────────────────────────────────────────────────

  void _showAuthSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AuthSheet(
        onAuthComplete: (User user) {
          Navigator.pop(ctx); // close sheet
          _saveAndNavigate();
        },
        onSignInTap: () {
          Navigator.pop(ctx);
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        },
        isGoogleSignIn: widget.data.isGoogleSignIn,
      ),
    );
  }

  // ── Save to Firestore ─────────────────────────────────────────────────

  Future<void> _saveAndNavigate() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final validationError = widget.data.validate();
      if (validationError != null) throw Exception(validationError);

      final uid = user.uid;
      final email = user.email ?? widget.data.prefilledEmail ?? '';
      final firestore = FirebaseFirestore.instance;

      // Upload profile picture if provided
      if (widget.data.profileImageFile != null) {
        await _uploadProfilePicture(uid);
      }

      // Build Firestore document
      final docData = widget.data.toFirebaseMap(email);

      // Atomic save with transaction + retry
      await _saveWithRetry(firestore, uid, docData);

      // Create subcollection documents (daily_totals, water_intake)
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await firestore
          .collection('users')
          .doc(uid)
          .collection('daily_totals')
          .doc(today)
          .set({
        'date': today,
        'calories': 0,
        'protein': 0.0,
        'carbs': 0.0,
        'fat': 0.0,
        'fiber': 0.0,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      await firestore
          .collection('users')
          .doc(uid)
          .collection('water_intake')
          .doc(today)
          .set({
        'date': today,
        'waterIntake': 0.0,
        'waterGoal': widget.data.waterIntake ?? 2500,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Cache onboarding completion and home-tab preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete_$uid', true);
      await prefs.setString(
          'onboarding_cache_time_$uid', DateTime.now().toIso8601String());
      await prefs.setString('track_focus_$uid', widget.data.trackFocus);

      if (!mounted) return;

      // Send email verification for email/password accounts
      if (!user.emailVerified &&
          user.providerData.any((p) => p.providerId == 'password')) {
        try {
          await user.sendEmailVerification();
        } catch (_) {}
        if (!mounted) return;
        // Show verify-your-email dialog, then navigate to login
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: _kCardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Verify your email',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              "We've sent a verification link to ${user.email}. "
              'Please check your inbox and click the link to verify your email, '
              'then sign in to continue.',
              style: TextStyle(color: Colors.white.withOpacity(0.9)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(color: _kPrimary)),
              ),
            ],
          ),
        );
        if (!mounted) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
        return;
      }

      // Navigate to home
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      debugPrint('Onboarding save failed: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Something went wrong. Please try again.'),
          backgroundColor: _kRed,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _saveAndNavigate,
          ),
        ),
      );
    }
  }

  /// Upload profile picture with retry.
  Future<void> _uploadProfilePicture(String uid) async {
    final file = widget.data.profileImageFile!;
    final ref =
        FirebaseStorage.instance.ref().child('profile_pictures/$uid.jpg');
    await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    widget.data.profileImageUrl = await ref.getDownloadURL();
  }

  /// Save user document with up to 3 retries using exponential backoff.
  Future<void> _saveWithRetry(
      FirebaseFirestore firestore, String uid, Map<String, dynamic> data,
      {int maxRetries = 3}) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        await firestore.runTransaction((tx) async {
          final docRef = firestore.collection('users').doc(uid);
          tx.set(docRef, data, SetOptions(merge: true));
        });
        // Verify the save
        final saved = await firestore.collection('users').doc(uid).get();
        if (saved.exists && saved.data()?['onboardingCompleted'] == true) {
          return; // success
        }
        throw Exception('Data verification failed');
      } catch (e) {
        if (attempt == maxRetries - 1) rethrow;
        await Future.delayed(
            Duration(milliseconds: 500 * (attempt + 1))); // exponential backoff
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: _isSaving
            ? _buildSavingState()
            : Column(
                children: [
                  const OnboardingProgressBar(currentStep: 10),
                  // Top bar: back only (match reference sticky bar)
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.rw, 8.rh, 16.rw, 0),
                    child: Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => Navigator.maybePop(context),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.arrow_back,
                                size: 24,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Scrollable content
                  Expanded(
                    child: OnboardingScrollBody(
                      padding: EdgeInsets.fromLTRB(24.rw, 16.rh, 24.rw, 24.rh),
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                          // Header: celebration icon + title (match reference)
                          SizedBox(height: 8.rh),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: _kCardBorderMuted.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.celebration,
                              size: 40,
                              color: _kAccent,
                            ),
                          ),
                          SizedBox(height: 24.rh),
                          const Text(
                            'Your plan is ready!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.25,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Customized for your goals and lifestyle',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _kTextMuted,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 32.rh),

                          // Main card: daily targets + weight bar (reference: single card rounded-2xl)
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _kCardBg.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(_kRadiusCard),
                              border: Border.all(color: _kCardBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.all(32.r),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'DAILY TARGETS',
                                            style: TextStyle(
                                              color: _kBlueLabel,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                          SizedBox(height: 16.rh),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.baseline,
                                            textBaseline:
                                                TextBaseline.alphabetic,
                                            children: [
                                              Text(
                                                _fmtCal(d.dailyCalories),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 48,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'calories',
                                                style: TextStyle(
                                                  color: _kTextMuted,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 32.rh),
                                          Row(
                                            children: [
                                              Expanded(
                                                  child: _macroCell('Protein',
                                                      _fmtG(d.protein))),
                                              SizedBox(width: 12),
                                              Expanded(
                                                  child: _macroCell(
                                                      'Carbs',
                                                      _fmtG(d.carbs))),
                                              SizedBox(width: 12),
                                              Expanded(
                                                  child: _macroCell(
                                                      'Fats', _fmtG(d.fat))),
                                            ],
                                          ),
                                          if (d.waterIntake != null) ...[
                                            SizedBox(height: 24.rh),
                                            _waterCell(d.waterIntake!),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      top: 16,
                                      right: 16,
                                      child: Icon(
                                        Icons.fitness_center,
                                        size: 48,
                                        color: _kPrimary.withOpacity(0.1),
                                      ),
                                    ),
                                  ],
                                ),
                                // Weight loss highlight bar (reference: border-t inside card)
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 32.rw, vertical: 20.rh),
                                  decoration: BoxDecoration(
                                    color: _kBlueLabel.withOpacity(0.05),
                                    border: Border(
                                      top: BorderSide(
                                          color: _kCardBorder.withOpacity(0.5)),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.bolt,
                                          color: _kBlueLabel, size: 28),
                                      SizedBox(width: 16.rw),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            children: _goalLineSpans(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Clip main card bottom so highlight bar sits flush (same container in ref)
                          // We built bar separate; wrap the card+bar in a single rounded container
                          SizedBox(height: 24.rh),

                          // Description / Why box (reference: auto_awesome, rounded-xl, slate)
                          if (d.aiExplanation != null &&
                              d.aiExplanation!.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(24.r),
                              decoration: BoxDecoration(
                                color: _kCardBg.withOpacity(0.3),
                                borderRadius:
                                    BorderRadius.circular(_kRadiusInner),
                                border: Border.all(
                                    color: _kCardBorderMuted.withOpacity(0.5)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.auto_awesome,
                                      color: _kBlueLabel, size: 28),
                                  SizedBox(width: 16.rw),
                                  Expanded(
                                    child: Text(
                                      d.aiExplanation!,
                                      style: TextStyle(
                                        color: _kTextMuted,
                                        fontSize: 12,
                                        height: 1.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24.rh),
                          ],

                          // Incentive rows (keep functionality)
                          _incentiveRow(Icons.star, 'Just \$8/month',
                              'Less than 2 lattes a month'),
                          SizedBox(height: 14.rh),
                          _incentiveRow(Icons.bolt, '30% off at 14-day streak',
                              'We reward your consistency'),
                          SizedBox(height: 14.rh),
                          _incentiveRow(Icons.check_circle, 'Cancel anytime',
                              'No long-term commitments required'),
                          SizedBox(height: 32.rh),
                      ],
                      actionSection: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _onStartJourney,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPrimary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 18.rh),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(_kRadiusInner),
                            ),
                            elevation: 4,
                            shadowColor: _kPrimary.withOpacity(0.25),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'GET STARTED',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<TextSpan> _goalLineSpans() {
    final line = _goalLine();
    // Highlight number like "13 lbs" with indigo if present
    final match = RegExp(r'(\d+)\s*lbs').firstMatch(line);
    if (match != null) {
      final start = line.indexOf(match.group(0)!);
      final end = start + match.group(0)!.length;
      return [
        TextSpan(text: line.substring(0, start)),
        TextSpan(
            text: match.group(0),
            style: const TextStyle(color: _kIndigoHighlight)),
        TextSpan(text: line.substring(end)),
      ];
    }
    return [TextSpan(text: line)];
  }

  Widget _macroCell(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.rh, horizontal: 8.rw),
      decoration: BoxDecoration(
        color: _kCardBorderMuted.withOpacity(0.2),
        borderRadius: BorderRadius.circular(_kRadiusInner),
        border: Border.all(color: _kCardBorderMuted),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: _kTextMuted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: _kBlueValue,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _waterCell(double waterMl) {
    final liters = (waterMl / 1000).toStringAsFixed(1);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20.rh, horizontal: 24.rw),
      decoration: BoxDecoration(
        color: _kCardBorderMuted.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kCardBorderMuted),
      ),
      child: Column(
        children: [
          Text(
            'WATER',
            style: TextStyle(
              color: _kTextMuted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '${liters}L',
            style: TextStyle(
              color: _kBlueLabel,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingState() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24.rw, 16.rh, 24.rw, 32.rh),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            SizedBox(height: 40.rh),
            // Hero badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.rw, vertical: 12.rh),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _kPrimary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add, color: _kAccent, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    'ALMOST THERE',
                    style: TextStyle(
                      color: _kPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.person_add, color: _kAccent, size: 26),
                ],
              ),
            ),
            SizedBox(height: 28.rh),
            const Text(
              'Setting up your account...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            SizedBox(height: 12.rh),
            Text(
              'Saving your plan and preferences',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
            SizedBox(height: 32.rh),
            Container(
              padding: EdgeInsets.all(28.r),
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kCardBorder),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      color: _kPrimary,
                      strokeWidth: 4,
                    ),
                  ),
                  SizedBox(height: 20.rh),
                  Text(
                    'Profile · Goals · Daily targets',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _incentiveRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _kPrimary, size: 22),
        ),
        SizedBox(width: 14.rw),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Auth Bottom Sheet
// ══════════════════════════════════════════════════════════════════════════════

class _AuthSheet extends StatefulWidget {
  final void Function(User user) onAuthComplete;
  final VoidCallback? onSignInTap;
  final bool isGoogleSignIn;

  const _AuthSheet({
    required this.onAuthComplete,
    this.onSignInTap,
    this.isGoogleSignIn = false,
  });

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
  );

  static String? _validatePassword(String password) {
    if (password.length < 8) return 'Password must be at least 8 characters.';
    if (!password.contains(RegExp(r'[A-Z]'))) return 'Include at least one uppercase letter.';
    if (!password.contains(RegExp(r'[a-z]'))) return 'Include at least one lowercase letter.';
    if (!password.contains(RegExp(r'[0-9]'))) return 'Include at least one number.';
    return null;
  }

  Future<void> _signUpWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    final pwError = _validatePassword(password);
    if (pwError != null) {
      setState(() => _error = pwError);
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cred =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user != null) {
        widget.onAuthComplete(cred.user!);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _error = _mapAuthError(e.code);
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return; // cancelled
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      if (cred.user != null) {
        widget.onAuthComplete(cred.user!);
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Google sign-in failed. Please try again.';
      });
    }
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try logging in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters with uppercase, lowercase, and a number.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      default:
        return 'Sign up failed ($code). Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Colors.white.withOpacity(0.6);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          32.rw, 16.rh, 32.rw, MediaQuery.of(context).viewInsets.bottom + 32.rh),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 24.rh),
            const Text(
              'Create Your Account',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign up to save your personalized plan',
              style: TextStyle(
                color: muted,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            SizedBox(height: 32.rh),

            // Google button – full width, h-12, rounded-lg, border
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _loading ? null : _signUpWithGoogle,
                style: OutlinedButton.styleFrom(
                  backgroundColor: _kInputBg,
                  foregroundColor: Colors.white,
                  side: BorderSide(color: _kCardBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_kAuthRadius),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24.rw),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.g_mobiledata, size: 24, color: Colors.white),
                    SizedBox(width: 12.rw),
                    const Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24.rh),

            // Divider – "OR" uppercase, tracking
            Row(
              children: [
                Expanded(child: Divider(color: _kCardBorder, thickness: 1)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.rw),
                  child: Text(
                    'or',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: _kCardBorder, thickness: 1)),
              ],
            ),
            SizedBox(height: 32.rh),

            // Form – labels above fields, space-y-5
            _labeledField(
              label: 'Email Address',
              controller: _emailController,
              hint: 'name@example.com',
              icon: Icons.mail_outlined,
              keyboardType: TextInputType.emailAddress,
              maxLength: 254,
            ),
            SizedBox(height: 20.rh),
            _labeledField(
              label: 'Password',
              controller: _passwordController,
              hint: '••••••••',
              icon: Icons.lock_outlined,
              obscure: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54,
                  size: 22,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            SizedBox(height: 20.rh),
            _labeledField(
              label: 'Confirm Password',
              controller: _confirmPasswordController,
              hint: '••••••••',
              icon: Icons.lock_reset,
              obscure: _obscureConfirm,
              textInputAction: TextInputAction.done,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54,
                  size: 22,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),

            if (_error != null) ...[
              SizedBox(height: 12.rh),
              Text(
                _error!,
                style: const TextStyle(color: _kRed, fontSize: 13),
              ),
            ],

            SizedBox(height: 24.rh),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _signUpWithEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: _kPrimary.withOpacity(0.25),
                  disabledBackgroundColor: _kPrimary.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_kAuthRadius),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            if (widget.onSignInTap != null) ...[
              SizedBox(height: 32.rh),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(
                      color: muted,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onSignInTap,
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: _kPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.rh),
            ],
          ],
        ),
      ),
    );
  }

  Widget _labeledField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    TextInputAction textInputAction = TextInputAction.next,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLength: maxLength,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 16,
            ),
            prefixIcon: Icon(icon, color: Colors.white54, size: 22),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: _kInputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_kAuthRadius),
              borderSide: BorderSide(color: _kCardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_kAuthRadius),
              borderSide: BorderSide(color: _kCardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_kAuthRadius),
              borderSide: const BorderSide(color: _kPrimary, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.rw,
              vertical: 14.rh,
            ),
          ),
        ),
      ],
    );
  }
}
