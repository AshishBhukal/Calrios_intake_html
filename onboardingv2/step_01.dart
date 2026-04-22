import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fitness2/onboardingv2/onboarding_v2_data.dart';
import 'package:fitness2/onboardingv2/step_02.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_helpers.dart';

// Onboarding v2 design: align with onv2 reference (glass cards, consistent spacing)
const Color _kOnv2Background = Color(0xFF0B1221);
const Color _kOnv2Primary = Color(0xFF1E54FF);
const Color _kMuted = Color(0xFF94A3B8);
const double _kInputRadius = 12.0;
const double _kButtonRadius = 14.0;

/// Step 1: Personalize Your experience – profile picture, first name, last name, username.
class OnboardingStep01 extends StatefulWidget {
  /// If true, user is already authenticated (resuming incomplete onboarding).
  final bool isAlreadyAuthenticated;
  final String? prefilledEmail;
  final bool isGoogleSignIn;

  const OnboardingStep01({
    super.key,
    this.isAlreadyAuthenticated = false,
    this.prefilledEmail,
    this.isGoogleSignIn = false,
  });

  @override
  State<OnboardingStep01> createState() => _OnboardingStep01State();
}

enum _UsernameStatus { idle, checking, available, taken, invalid }

class _OnboardingStep01State extends State<OnboardingStep01> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _imagePicker = ImagePicker();

  File? _profileImage;
  _UsernameStatus _usernameStatus = _UsernameStatus.idle;
  Timer? _debounce;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Profile picture ──────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF161E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.rh),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20.rh),
              const Text(
                'Choose Photo',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16.rh),
              ListTile(
                leading:
                    const Icon(Icons.camera_alt, color: _kOnv2Primary, size: 28),
                title: const Text('Take a photo',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library,
                    color: _kOnv2Primary, size: 28),
                title: const Text('Choose from gallery',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              if (_profileImage != null)
                ListTile(
                  leading:
                      const Icon(Icons.delete, color: DesignSystem.danger, size: 28),
                  title: const Text('Remove photo',
                      style: TextStyle(color: DesignSystem.danger, fontSize: 16)),
                  onTap: () {
                    setState(() => _profileImage = null);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked != null) {
        final file = File(picked.path);
        final sizeBytes = await file.length();
        if (sizeBytes > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Image is too large. Please choose one under 5 MB.'),
                  backgroundColor: DesignSystem.danger),
            );
          }
          return;
        }
        setState(() => _profileImage = file);
      }
    } catch (e) {
      debugPrint('Image pick failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not pick image. Please try again.'),
              backgroundColor: DesignSystem.danger),
        );
      }
    }
  }

  // ── Username availability ─────────────────────────────────────────────

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');

    if (trimmed.isEmpty) {
      setState(() => _usernameStatus = _UsernameStatus.idle);
      return;
    }
    if (trimmed.length < 3 || trimmed.length > OnboardingV2Data.maxUsernameLength) {
      setState(() => _usernameStatus = _UsernameStatus.invalid);
      return;
    }

    setState(() => _usernameStatus = _UsernameStatus.checking);

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable('checkUsernameAvailability')
            .call({'username': trimmed});
        if (!mounted) return;
        final available = result.data['available'] as bool? ?? false;
        setState(() {
          _usernameStatus =
              available ? _UsernameStatus.available : _UsernameStatus.taken;
        });
      } catch (e) {
        if (!mounted) return;
        // On error default to idle so user isn't blocked during network issues.
        setState(() => _usernameStatus = _UsernameStatus.idle);
      }
    });
  }

  // ── Continue ──────────────────────────────────────────────────────────

  void _onContinue() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final username =
        _usernameController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');

    if (firstName.isEmpty) {
      _showError('Please enter your first name');
      return;
    }
    if (username.isEmpty || username.length < 3) {
      _showError('Please choose a username (at least 3 characters)');
      return;
    }
    if (_usernameStatus == _UsernameStatus.taken) {
      _showError('That username is taken. Please choose another.');
      return;
    }
    if (_usernameStatus == _UsernameStatus.invalid) {
      _showError('Username must be at least 3 characters (letters, numbers, underscores)');
      return;
    }
    if (_usernameStatus == _UsernameStatus.checking) {
      _showError('Please wait while we check username availability');
      return;
    }

    final data = OnboardingV2Data(
      firstName: firstName,
      lastName: lastName,
      username: username,
      profileImageFile: _profileImage,
      isAlreadyAuthenticated: widget.isAlreadyAuthenticated,
      prefilledEmail: widget.prefilledEmail,
      isGoogleSignIn: widget.isGoogleSignIn,
    );

    Navigator.push(
      context,
      OnboardingPageRoute(child: OnboardingStep02(data: data)),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: DesignSystem.danger),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kOnv2Background,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgressBar(currentStep: 1),
            Expanded(
              child: OnboardingScrollBody(
                padding: EdgeInsets.fromLTRB(24.rw, 28.rh, 24.rw, 24.rh),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Header — clear hierarchy (onv2 style)
              const Text(
                'Personalize Your Experience',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.6,
                  height: 1.25,
                ),
              ),
              SizedBox(height: 10.rh),
              Text(
                'Tell us a bit about yourself to get started on your fitness journey.',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),

              // Profile picture
              SizedBox(height: 32.rh),
              Center(child: _buildProfilePicture()),
              SizedBox(height: 10.rh),
              Center(
                child: Text(
                  'Optional',
                  style: TextStyle(color: _kMuted.withOpacity(0.8), fontSize: 12),
                ),
              ),

              // Form fields — consistent vertical rhythm
              SizedBox(height: 28.rh),
              _labeledInput(
                label: 'First Name *',
                controller: _firstNameController,
                hint: 'Enter your first name',
                textInputAction: TextInputAction.next,
                maxLength: OnboardingV2Data.maxNameLength,
              ),
              SizedBox(height: 20.rh),
              _labeledInput(
                label: 'Last Name',
                controller: _lastNameController,
                hint: 'Enter your last name',
                textInputAction: TextInputAction.next,
                maxLength: OnboardingV2Data.maxNameLength,
              ),
              SizedBox(height: 20.rh),
              _usernameSection(),

              SizedBox(height: 24.rh),
            ],
                actionSection: _continueButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePicture() {
    const double size = 100;
    return GestureDetector(
      onTap: _pickImage,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: DesignSystem.cardBg,
                shape: BoxShape.circle,
                border: Border.all(
                    color: DesignSystem.glassBorder,
                    width: 1.5,
                    strokeAlign: BorderSide.strokeAlignInside),
                image: _profileImage != null
                    ? DecorationImage(
                        image: FileImage(_profileImage!), fit: BoxFit.cover)
                    : null,
              ),
              child: _profileImage == null
                  ? Icon(Icons.add_a_photo, size: 40, color: _kMuted.withOpacity(0.6))
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _kOnv2Primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kOnv2Background, width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: _kOnv2Primary.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: const Icon(Icons.edit, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _labeledInput({
    required String label,
    required TextEditingController controller,
    required String hint,
    required TextInputAction textInputAction,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextField(
          controller: controller,
          textInputAction: textInputAction,
          maxLength: maxLength,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _kMuted.withOpacity(0.7), fontSize: 16),
            counterText: '',
            filled: true,
            fillColor: DesignSystem.cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_kInputRadius),
              borderSide: const BorderSide(color: DesignSystem.glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_kInputRadius),
              borderSide: const BorderSide(color: DesignSystem.glassBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_kInputRadius),
              borderSide: BorderSide(color: _kOnv2Primary, width: 2),
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 20.rw, vertical: 18.rh),
          ),
        ),
      ],
    );
  }

  Widget _usernameSection() {
    Color borderColor;
    Widget? suffixIcon;
    String? helperText;
    Color helperColor = DesignSystem.success;

    switch (_usernameStatus) {
      case _UsernameStatus.idle:
        borderColor = DesignSystem.glassBorder;
        break;
      case _UsernameStatus.checking:
        borderColor = DesignSystem.glassBorder;
        suffixIcon = Padding(
          padding: EdgeInsets.only(right: 16.rw),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: _kOnv2Primary),
          ),
        );
        helperText = 'Checking availability...';
        helperColor = _kMuted;
        break;
      case _UsernameStatus.available:
        borderColor = DesignSystem.success.withOpacity(0.6);
        suffixIcon = Padding(
          padding: EdgeInsets.only(right: 16.rw),
          child: const Icon(Icons.check_circle, color: DesignSystem.success, size: 24),
        );
        helperText = 'Username available';
        helperColor = DesignSystem.success;
        break;
      case _UsernameStatus.taken:
        borderColor = DesignSystem.danger.withOpacity(0.6);
        suffixIcon = Padding(
          padding: EdgeInsets.only(right: 16.rw),
          child: const Icon(Icons.cancel, color: DesignSystem.danger, size: 24),
        );
        helperText = 'Username already taken';
        helperColor = DesignSystem.danger;
        break;
      case _UsernameStatus.invalid:
        borderColor = DesignSystem.danger.withOpacity(0.6);
        helperText = 'At least 3 characters (letters, numbers, underscores)';
        helperColor = DesignSystem.danger;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Choose a Username *',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextField(
          controller: _usernameController,
          textInputAction: TextInputAction.done,
          maxLength: OnboardingV2Data.maxUsernameLength,
          onChanged: _onUsernameChanged,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'e.g. alex_fitness',
            counterText: '',
            hintStyle: TextStyle(color: _kMuted.withOpacity(0.7), fontSize: 16),
            filled: true,
            fillColor: DesignSystem.cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_kInputRadius),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_kInputRadius),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_kInputRadius),
              borderSide: BorderSide(
                  color: _usernameStatus == _UsernameStatus.taken
                      ? DesignSystem.danger
                      : _usernameStatus == _UsernameStatus.available
                          ? DesignSystem.success
                          : _kOnv2Primary,
                  width: 2),
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 20.rw, vertical: 18.rh),
            suffixIcon: suffixIcon,
          ),
        ),
        if (helperText != null) ...[
          SizedBox(height: 8.rh),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                if (_usernameStatus != _UsernameStatus.checking)
                  Container(
                    width: 6,
                    height: 6,
                    decoration:
                        BoxDecoration(color: helperColor, shape: BoxShape.circle),
                  ),
                if (_usernameStatus != _UsernameStatus.checking)
                  const SizedBox(width: 6),
                Text(
                  helperText,
                  style: TextStyle(
                      color: helperColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Standardised Continue button used across all onboarding steps.
  Widget _continueButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _onContinue,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kOnv2Primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 18.rh),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_kButtonRadius)),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}
