import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/features/ui/glassmorphism_widget.dart';
import 'package:fitness2/user_identification/login_page.dart';

/// Firestore user document uses [userName] (camelCase); this file reads/writes that field.

class AccountInfoScreen extends StatefulWidget {
  final Function(String) onProfilePictureUpdated;
  
  const AccountInfoScreen({
    super.key,
    required this.onProfilePictureUpdated,
  });

  @override
  _AccountInfoScreenState createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  User? _user;
  String _username = '';
  String _profileImageUrl = '';
  bool _isLoading = true;
  bool _isUploading = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
    _user = _auth.currentUser;
    if (_user != null) {
      _userDocSubscription = _firestore
          .collection('users')
          .doc(_user!.uid)
          .snapshots()
          .listen(_onUserDocumentUpdate);
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onUserDocumentUpdate(DocumentSnapshot doc) {
    if (!mounted) return;
    if (!doc.exists || doc.data() == null) {
      setState(() => _isLoading = false);
      return;
    }
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _username = _displayNameFromUserData(data);
      _profileImageUrl = (data['profileImageUrl'] ?? '').toString().trim();
      if (_usernameController.text != _username) {
        _usernameController.text = _username;
      }
      _isLoading = false;
    });
  }

  /// Resolve display name: Firestore uses [userName]; fallback to [username], then firstName+lastName, then email local part.
  String _displayNameFromUserData(Map<String, dynamic> data) {
    final userName = (data['userName'] ?? data['username'] ?? '').toString().trim();
    if (userName.isNotEmpty) return userName;
    final first = (data['firstName'] ?? '').toString().trim();
    final last = (data['lastName'] ?? '').toString().trim();
    final fullName = '$first $last'.trim();
    if (fullName.isNotEmpty) return fullName;
    final email = _user?.email ?? '';
    if (email.isNotEmpty) {
      final at = email.indexOf('@');
      if (at > 0) return email.substring(0, at);
    }
    return 'No username set';
  }

  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan_clean.txt ID f_2f3g4h
  Future<void> _updateProfilePicture() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isUploading = true);
      
      // Upload to Firebase Storage
      final ref = _storage.ref().child('profile_pictures/${_user!.uid}.jpg');
      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();

      await _firestore.collection('users').doc(_user!.uid).update({
        'profileImageUrl': url,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      setState(() {
        _profileImageUrl = url;
        _isUploading = false;
      });
      
      widget.onProfilePictureUpdated(url);
      
      _showSuccessSnackBar('Profile picture updated successfully!');
    } catch (e) {
      setState(() => _isUploading = false);
      _showErrorSnackBar('Failed to update profile picture. Please try again.');
    }
  }

  Future<void> _updateUsername() async {
    try {
      final newUsername = _usernameController.text.trim();
      if (newUsername.isEmpty) return;

      await _firestore.collection('users').doc(_user!.uid).update({
        'userName': newUsername,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      setState(() => _username = newUsername);
      _showSuccessSnackBar('Username updated successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to update username. Please try again.');
    }
  }

  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan_clean.txt ID f_4h5i6j
  Future<void> _changePassword() async {
    try {
      if (_passwordController.text != _confirmPasswordController.text) {
        _showErrorSnackBar('Passwords do not match!');
        return;
      }

      if (_passwordController.text.length < 6) {
        _showErrorSnackBar('Password must be at least 6 characters long');
        return;
      }

      await _user!.updatePassword(_passwordController.text);
      _showSuccessSnackBar('Password updated successfully!');
      _passwordController.clear();
      _confirmPasswordController.clear();
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Password is too weak. Please use a stronger password (at least 6 characters).';
          break;
        case 'requires-recent-login':
          errorMessage = 'For security, please sign out and sign in again before changing your password.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection and try again.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later.';
          break;
        default:
          errorMessage = 'Unable to change password. Please try again.';
      }
      _showErrorSnackBar(errorMessage);
    } catch (e) {
      _showErrorSnackBar('Unable to change password. Please try again.');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: DesignSystem.light),
            const SizedBox(width: DesignSystem.spacing8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: DesignSystem.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_rounded, color: DesignSystem.light),
            const SizedBox(width: DesignSystem.spacing8),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: DesignSystem.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      decoration: BoxDecoration(
        color: DesignSystem.dark.withOpacity(0.6),
        border: Border(
          bottom: BorderSide(
            color: DesignSystem.glassBorder,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: DesignSystem.spacing24.rw,
            vertical: DesignSystem.spacing16.rh,
          ),
          child: Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: DesignSystem.light,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  'Account Info',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: DesignSystem.light,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DesignSystem.spacing24.rw,
        vertical: DesignSystem.spacing32.rh,
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(
                    color: DesignSystem.primary.withOpacity(0.4),
                    width: 3,
                  ),
                  boxShadow: DesignSystem.glowShadow,
                ),
                child: ClipOval(
                  child: _profileImageUrl.isNotEmpty
                      ? Image.network(
                          _profileImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar();
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: DesignSystem.primary,
                                strokeWidth: 2,
                              ),
                            );
                          },
                        )
                      : _buildDefaultAvatar(),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _updateProfilePicture,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: DesignSystem.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: DesignSystem.dark,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _isUploading
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                color: DesignSystem.light,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.edit_rounded,
                              color: DesignSystem.light,
                              size: 18,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: DesignSystem.spacing16.rh),
          Text(
            _username,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: DesignSystem.light,
            ),
          ),
          const SizedBox(height: DesignSystem.spacing4),
          Text(
            _user?.email ?? 'No email',
            textAlign: TextAlign.center,
            style: DesignSystem.bodyMedium.copyWith(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: DesignSystem.light,
        size: 48,
      ),
    );
  }

  static const double _cardRadiusLarge = 16.0;

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onEdit,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: DesignSystem.spacing16.rh),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(_cardRadiusLarge),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Padding(
        padding: EdgeInsets.all(DesignSystem.spacing20.r),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: DesignSystem.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: DesignSystem.primary,
                size: 24,
              ),
            ),
            SizedBox(width: DesignSystem.spacing16.rw),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: DesignSystem.labelSmall.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.7),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: DesignSystem.spacing4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: DesignSystem.light,
                    ),
                  ),
                ],
              ),
            ),
            if (onEdit != null)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(DesignSystem.spacing8),
                    child: Icon(
                      Icons.edit_rounded,
                      color: Colors.white.withOpacity(0.4),
                      size: 22,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildModernDialog({
    required String title,
    required Widget content,
    required VoidCallback onSave,
    required VoidCallback onCancel,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Builder(
        builder: (dialogContext) {
          final keyboardHeight = MediaQuery.of(dialogContext).viewInsets.bottom;
          final screenHeight = MediaQuery.of(dialogContext).size.height;
          
          return GlassmorphismWidget(
            blurIntensity: 18.0,
            opacity: 0.25,
            borderRadius: 20.0,
            borderWidth: 1.5,
            borderColor: const Color(0x500A1A2F),
            backgroundColor: const Color(0x250A1A2F),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: screenHeight * 0.7 - keyboardHeight,
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: DesignSystem.spacing24.rw,
                  right: DesignSystem.spacing24.rw,
                  top: DesignSystem.spacing24.rh,
                  bottom: DesignSystem.spacing24.rh + keyboardHeight,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: DesignSystem.titleMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: onCancel,
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.white.withOpacity(0.7),
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: DesignSystem.spacing20.rh),
                      content,
                      SizedBox(height: DesignSystem.spacing24.rh),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: onCancel,
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              padding: EdgeInsets.symmetric(
                                horizontal: DesignSystem.spacing20.rw,
                                vertical: DesignSystem.spacing12.rh,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: DesignSystem.labelMedium.copyWith(
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ),
                          SizedBox(width: DesignSystem.spacing12.rw),
                          ElevatedButton(
                            onPressed: onSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4361ee),
                              padding: EdgeInsets.symmetric(
                                horizontal: DesignSystem.spacing20.rw,
                                vertical: DesignSystem.spacing12.rh,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
                              ),
                            ),
                            child: Text(
                              'Save',
                              style: DesignSystem.labelMedium.copyWith(
                                color: DesignSystem.light,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: DesignSystem.labelSmall.copyWith(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: DesignSystem.spacing8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: DesignSystem.bodyMedium.copyWith(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: DesignSystem.labelMedium.copyWith(
              color: Colors.white.withOpacity(0.5),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: DesignSystem.spacing16.rw,
              vertical: DesignSystem.spacing12.rh,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showUsernameDialog() async {
    return showDialog(
      context: context,
      builder: (context) => _buildModernDialog(
        title: 'Edit Username',
        content: _buildInputField(
          controller: _usernameController,
          label: 'New Username',
          hintText: 'Enter your new username',
        ),
        onSave: () {
          _updateUsername();
          Navigator.pop(context);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _showPasswordDialog() async {
    return showDialog(
      context: context,
      builder: (context) => _buildModernDialog(
        title: 'Change Password',
        content: Column(
          children: [
            _buildInputField(
              controller: _passwordController,
              label: 'New Password',
              hintText: 'Enter your new password',
              obscureText: true,
            ),
            SizedBox(height: DesignSystem.spacing16.rh),
            _buildInputField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              hintText: 'Confirm your new password',
              obscureText: true,
            ),
          ],
        ),
        onSave: () {
          _changePassword();
          Navigator.pop(context);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  void _showSignOutConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassmorphismWidget(
          blurIntensity: 18.0,
          opacity: 0.25,
          borderRadius: 20.0,
          borderWidth: 1.5,
          borderColor: const Color(0x500A1A2F),
          backgroundColor: const Color(0x250A1A2F),
          child: Padding(
            padding: EdgeInsets.all(DesignSystem.spacing24.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: DesignSystem.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 30,
                    color: DesignSystem.danger,
                  ),
                ),
                SizedBox(height: DesignSystem.spacing20.rh),
                const Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: DesignSystem.light,
                  ),
                ),
                SizedBox(height: DesignSystem.spacing12.rh),
                Text(
                  'Are you sure you want to sign out?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
                SizedBox(height: DesignSystem.spacing24.rh),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          padding: EdgeInsets.symmetric(vertical: 14.rh),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: DesignSystem.spacing12.rw),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          try {
                            await _auth.signOut();
                            if (context.mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => LoginPage()),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              _showErrorSnackBar('Failed to sign out. Please try again.');
                            }
                          }
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: DesignSystem.danger.withOpacity(0.2),
                          padding: EdgeInsets.symmetric(vertical: 14.rh),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
                          ),
                        ),
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(
                            color: DesignSystem.danger,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogOutButton() {
    return Padding(
      padding: EdgeInsets.only(top: DesignSystem.spacing32.rh),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showSignOutConfirmation,
            borderRadius: BorderRadius.circular(_cardRadiusLarge),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: DesignSystem.spacing16.rh),
              decoration: BoxDecoration(
                color: DesignSystem.danger.withOpacity(0.05),
                borderRadius: BorderRadius.circular(_cardRadiusLarge),
                border: Border.all(
                  color: DesignSystem.danger.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Center(
                child: Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: DesignSystem.danger,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignSystem.dark,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background_1.png'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: DesignSystem.primary,
                        strokeWidth: 4,
                      ),
                    ),
                    SizedBox(height: DesignSystem.spacing16.rh),
                    const Text(
                      'Loading your account...',
                      style: DesignSystem.labelMedium,
                    ),
                  ],
                ),
              )
            : FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    _buildModernAppBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Column(
                            children: [
                              _buildProfileSection(),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: DesignSystem.spacing16.rw,
                                ),
                                child: Column(
                                  children: [
                                    _buildInfoCard(
                                      icon: Icons.person_rounded,
                                      title: 'Username',
                                      value: _username,
                                      onEdit: _showUsernameDialog,
                                    ),
                                    _buildInfoCard(
                                      icon: Icons.email_rounded,
                                      title: 'Email',
                                      value: _user?.email ?? 'No email',
                                    ),
                                    _buildInfoCard(
                                      icon: Icons.lock_rounded,
                                      title: 'Password',
                                      value: '••••••••',
                                      onEdit: _showPasswordDialog,
                                    ),
                                    _buildLogOutButton(),
                                  ],
                                ),
                              ),
                              SizedBox(height: DesignSystem.spacing32.rh),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}