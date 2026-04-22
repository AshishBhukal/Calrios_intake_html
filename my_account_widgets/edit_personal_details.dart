import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/services/firebase_service.dart';
import 'package:fitness2/services/unit_preference_service.dart';
import 'package:fitness2/utils/ios_date_picker_helper.dart';

class EditPersonalDetails extends StatefulWidget {
  const EditPersonalDetails({super.key});

  @override
  _EditPersonalDetailsState createState() => _EditPersonalDetailsState();
}

class _EditPersonalDetailsState extends State<EditPersonalDetails> with TickerProviderStateMixin {
  // Dropdown option lists
  final List<String> _genders = ['Male', 'Female'];
  final List<String> _activityLevels = [
    'Sedentary',
    'Lightly Active',
    'Moderately Active',
    'Very Active',
    'Extremely Active'
  ];
  final List<String> _fitnessGoals = [
    'Lose Weight',
    'Gain Weight',
    'Maintain Weight',
    'Build Muscle',
    'Increase Lean Muscle Mass',
    'Improve Endurance',
    'General Fitness'
  ];
  // Display units for weight/height (from UnitPreferenceService; read-only on this screen)
  String _displayWeightUnit = 'kg';
  String _displayHeightUnit = 'cm';

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Text editing controllers (10 total + 2 for ft-in height)
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _genderController;
  late TextEditingController _yearController;
  late TextEditingController _monthController;
  late TextEditingController _dayController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _activityLevelController;
  late TextEditingController _fitnessGoalController;
  // Additional controllers for ft-in height input
  late TextEditingController _feetController;
  late TextEditingController _inchesController;
  
  // Loading and animation states
  bool _isLoading = false;
  bool _isLoadingData = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  
  // Months list for date formatting
  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize all controllers
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _genderController = TextEditingController();
    _yearController = TextEditingController();
    _monthController = TextEditingController();
    _dayController = TextEditingController();
    _weightController = TextEditingController();
    _heightController = TextEditingController();
    _activityLevelController = TextEditingController();
    _fitnessGoalController = TextEditingController();
    _feetController = TextEditingController();
    _inchesController = TextEditingController();
    
    // Setup animation
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
    
    // Fetch user data (will be implemented in Phase 3)
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoadingData = true;
    });
    
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userData = await _firestore.collection('users').doc(user.uid).get();
      if (userData.exists) {
        setState(() {
          _firstNameController.text = userData['firstName'] ?? '';
          _lastNameController.text = userData['lastName'] ?? '';
          _genderController.text = userData['gender'] ?? '';
          _yearController.text = userData['dob']?['year'] ?? '';
          _monthController.text = userData['dob']?['month'] ?? '';
          _dayController.text = userData['dob']?['day'] ?? '';
          // Weight and height are converted below after loading unit preferences
          
          // Handle activity level with fallback
          String activityLevel = userData['activityLevel'] ?? '';
          if (activityLevel.isNotEmpty && !_activityLevels.contains(activityLevel)) {
            if (activityLevel.toLowerCase().contains('sedentary') || activityLevel.toLowerCase().contains('inactive')) {
              activityLevel = 'Sedentary';
            } else if (activityLevel.toLowerCase().contains('light') || activityLevel.toLowerCase().contains('low')) {
              activityLevel = 'Lightly Active';
            } else if (activityLevel.toLowerCase().contains('moderate') || activityLevel.toLowerCase().contains('medium')) {
              activityLevel = 'Moderately Active';
            } else if (activityLevel.toLowerCase().contains('very') || activityLevel.toLowerCase().contains('high')) {
              activityLevel = 'Very Active';
            } else if (activityLevel.toLowerCase().contains('extreme') || activityLevel.toLowerCase().contains('very high')) {
              activityLevel = 'Extremely Active';
            } else {
              activityLevel = 'Moderately Active';
            }
          }
          _activityLevelController.text = activityLevel;
          
          // Handle fitness goal with fallback
          String fitnessGoal = userData['fitnessGoal'] ?? '';
          if (fitnessGoal.isNotEmpty && !_fitnessGoals.contains(fitnessGoal)) {
            if (fitnessGoal.toLowerCase().contains('muscle') || fitnessGoal.toLowerCase().contains('mass')) {
              fitnessGoal = 'Build Muscle';
            } else if (fitnessGoal.toLowerCase().contains('lose') || fitnessGoal.toLowerCase().contains('weight loss')) {
              fitnessGoal = 'Lose Weight';
            } else if (fitnessGoal.toLowerCase().contains('gain') || fitnessGoal.toLowerCase().contains('weight gain')) {
              fitnessGoal = 'Gain Weight';
            } else {
              fitnessGoal = 'General Fitness';
            }
          }
          _fitnessGoalController.text = fitnessGoal;

          // Display units from Firebase (managed in Unit Settings; read-only here)
          _displayWeightUnit = userData['weightUnit']?.toString() ?? 'kg';
          String heightUnit = userData['heightUnit']?.toString() ?? 'cm';
          if (heightUnit == 'in' || heightUnit == 'ft' || heightUnit == 'inches' || heightUnit == 'feet') {
            heightUnit = 'ft-in';
          }
          _displayHeightUnit = heightUnit;

          // Convert stored canonical values (kg, cm) to user's display units
          double storedHeight = (userData['height'] as num?)?.toDouble() ?? 0.0;
          if (_displayHeightUnit == 'ft-in') {
            double totalInches = UnitConverter.convertHeightFromCm(storedHeight, 'ft-in');
            int feet = totalInches.round() ~/ 12;
            int inches = totalInches.round() % 12;
            _feetController.text = feet.toString();
            _inchesController.text = inches.toString();
            _heightController.text = totalInches.toStringAsFixed(0);
          } else {
            _heightController.text = storedHeight.toStringAsFixed(1);
          }

          double storedWeight = (userData['weight'] as num?)?.toDouble() ?? 0.0;
          double displayWeight = UnitConverter.convertWeightFromKg(storedWeight, _displayWeightUnit);
          _weightController.text = displayWeight.toStringAsFixed(1);
          
          _isLoadingData = false;
        });
      } else {
        setState(() {
          _isLoadingData = false;
        });
      }
    } else {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  double _convertToKg(double weight, String unit) {
    return UnitConverter.convertWeightToKg(weight, unit);
  }

  double _convertToCm(double height, String unit) {
    return UnitConverter.convertHeightToCm(height, unit);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showPlatformDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      primaryColor: DesignSystem.primaryLight,
      backgroundColor: DesignSystem.darkCard,
      textColor: DesignSystem.light,
    );
    if (picked != null) {
      setState(() {
        _yearController.text = picked.year.toString();
        _monthController.text = _months[picked.month - 1];
        _dayController.text = picked.day.toString();
      });
    }
  }

  Future<void> _saveUserData() async {
    setState(() {
      _isLoading = true;
    });

    User? user = _auth.currentUser;
    if (user != null) {
      double weight = double.tryParse(_weightController.text) ?? 0.0;
      double weightInKg = _convertToKg(weight, _displayWeightUnit);
      double height = double.tryParse(_heightController.text) ?? 0.0;
      double heightInCm = _convertToCm(height, _displayHeightUnit);

      // Update only account-detail fields; use server timestamp for consistency
      final updateData = <String, dynamic>{
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'gender': _genderController.text.trim(),
        'dob': {
          'year': _yearController.text.trim(),
          'month': _monthController.text.trim(),
          'day': _dayController.text.trim(),
        },
        'weight': weightInKg,
        'height': heightInCm,
        'activityLevel': _activityLevelController.text.trim(),
        'fitnessGoal': _fitnessGoalController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _firestore.collection('users').doc(user.uid).set(
        updateData,
        SetOptions(merge: true),
      );
      FirebaseService.invalidateUserDocumentCache();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: DesignSystem.light),
              const SizedBox(width: DesignSystem.spacing8),
              const Text('Profile updated successfully!'),
            ],
          ),
          backgroundColor: DesignSystem.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
          ),
        ),
      );

      Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_rounded, color: DesignSystem.light),
              const SizedBox(width: DesignSystem.spacing8),
              const Text('You must be logged in to save your profile.'),
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

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _genderController.dispose();
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _activityLevelController.dispose();
    _fitnessGoalController.dispose();
    _feetController.dispose();
    _inchesController.dispose();
    super.dispose();
  }

  // Helper UI Builders
  Widget _buildGradientText(String text, TextStyle baseStyle) {
    return ShaderMask(
      shaderCallback: (bounds) => DesignSystem.textGradient.createShader(bounds),
      child: Text(
        text,
        style: baseStyle.copyWith(color: Colors.white),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.chevron_left_rounded,
          color: DesignSystem.light,
          size: 28,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Edit Personal Details',
        style: DesignSystem.titleMedium.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: true,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: DesignSystem.spacing24.rh),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGradientText(
            'Account Details',
            DesignSystem.headlineLarge.copyWith(fontSize: 30),
          ),
          const SizedBox(height: DesignSystem.spacing4),
          Text(
            'Keep your information up to date for better accuracy.',
            style: DesignSystem.labelMedium.copyWith(
              color: DesignSystem.mediumGray,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              color: DesignSystem.light,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: DesignSystem.spacing16.rh),
          const Text(
            'Loading your profile...',
            style: DesignSystem.labelMedium,
          ),
        ],
      ),
    );
  }

  // Form Builders – polished card: 16px radius, glass, uppercase section headers
  static const double _polishedCardRadius = 16.0;

  Widget _buildFormCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: DesignSystem.spacing20.rh),
      decoration: BoxDecoration(
        color: DesignSystem.glassBg,
        borderRadius: BorderRadius.circular(_polishedCardRadius),
        border: Border.all(color: DesignSystem.glassBorder, width: 1),
        boxShadow: DesignSystem.glowShadow,
      ),
      child: Padding(
        padding: EdgeInsets.all(DesignSystem.spacing20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: DesignSystem.primaryLight,
                  size: 20,
                ),
                const SizedBox(width: DesignSystem.spacing8),
                Text(
                  title,
                  style: DesignSystem.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            SizedBox(height: DesignSystem.spacing16.rh),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildFormGroup({
    required String label,
    required Widget child,
    EdgeInsets? padding,
    bool smallUppercaseLabel = false,
  }) {
    return Padding(
      padding: padding ?? EdgeInsets.only(bottom: DesignSystem.spacing16.rh),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label,
              style: DesignSystem.labelMedium.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: smallUppercaseLabel ? 10 : 12,
                color: DesignSystem.mediumGray,
                letterSpacing: smallUppercaseLabel ? 0.5 : null,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildTextFieldWithFocus({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    bool readOnly = false,
    Function(String)? onChanged,
  }) {
    return _TextFieldWithFocus(
      controller: controller,
      hintText: hintText,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownField({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required String hintText,
  }) {
    return _DropdownFieldWithFocus(
      value: value,
      items: items,
      onChanged: onChanged,
      hintText: hintText,
    );
  }

  @override
  Widget build(BuildContext context) {
    // If loading, show loading state
    if (_isLoadingData) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildModernAppBar(),
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background_1.png'),
              fit: BoxFit.cover,
              opacity: 0.3,
            ),
          ),
          child: SafeArea(
            child: _buildLoadingState(),
          ),
        ),
      );
    }

    // Main content – 4 sections matching redesign
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildModernAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background_1.png'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: SafeArea(
          top: false,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width > 600
                      ? DesignSystem.spacing20
                      : DesignSystem.spacing16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: DesignSystem.spacing32.rh),
                    _buildPageHeader(),
                    SizedBox(height: DesignSystem.spacing24.rh),

                    // 1. BASIC INFORMATION
                    _buildFormCard(
                      title: 'BASIC INFORMATION',
                      icon: Icons.person_rounded,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildFormGroup(
                                label: 'First Name',
                                child: _buildTextFieldWithFocus(
                                  controller: _firstNameController,
                                  hintText: 'Enter your first name',
                                ),
                              ),
                            ),
                            SizedBox(width: DesignSystem.spacing16.rw),
                            Expanded(
                              child: _buildFormGroup(
                                label: 'Last Name',
                                child: _buildTextFieldWithFocus(
                                  controller: _lastNameController,
                                  hintText: 'Enter your last name',
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: DesignSystem.spacing16.rh),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildFormGroup(
                                label: 'Gender',
                                child: _buildDropdownField(
                                  value: _genderController.text,
                                  items: _genders,
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _genderController.text = newValue ?? '';
                                    });
                                  },
                                  hintText: 'Select gender',
                                ),
                              ),
                            ),
                            SizedBox(width: DesignSystem.spacing16.rw),
                            Expanded(
                              child: _buildFormGroup(
                                label: 'Date of Birth',
                                child: GestureDetector(
                                  onTap: () => _selectDate(context),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: DesignSystem.spacing16.rw,
                                      vertical: DesignSystem.spacing12.rh,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          color: DesignSystem.mediumGray,
                                          size: 20,
                                        ),
                                        SizedBox(width: DesignSystem.spacing12.rw),
                                        Expanded(
                                          child: Text(
                                            _dayController.text.isEmpty
                                                ? 'Select date'
                                                : '${_dayController.text} ${_monthController.text} ${_yearController.text}',
                                            style: _dayController.text.isEmpty
                                                ? DesignSystem.labelMedium.copyWith(
                                                    color: Colors.white.withOpacity(0.5),
                                                  )
                                                : DesignSystem.bodyMedium.copyWith(color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // 2. PHYSICAL METRICS (stored in kg, cm in Firebase; displayed in user's unit preference)
                    _buildFormCard(
                      title: 'PHYSICAL METRICS',
                      icon: Icons.monitor_weight_rounded,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildFormGroup(
                                label: 'Body Weight ($_displayWeightUnit)',
                                child: _buildTextFieldWithFocus(
                                  controller: _weightController,
                                  hintText: '0.0',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                            ),
                            SizedBox(width: DesignSystem.spacing16.rw),
                            Expanded(
                              child: _buildFormGroup(
                                label: _displayHeightUnit == 'ft-in' ? 'Height (ft-in)' : 'Height ($_displayHeightUnit)',
                                child: _displayHeightUnit == 'ft-in'
                                    ? Row(
                                        children: [
                                          Expanded(
                                            child: _buildTextFieldWithFocus(
                                              controller: _feetController,
                                              hintText: 'ft',
                                              keyboardType: TextInputType.number,
                                              onChanged: (value) {
                                                int feet = int.tryParse(value) ?? 0;
                                                int inches = int.tryParse(_inchesController.text) ?? 0;
                                                _heightController.text = (feet * 12 + inches).toString();
                                              },
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            child: Text("'", style: TextStyle(color: Colors.white, fontSize: 18)),
                                          ),
                                          Expanded(
                                            child: _buildTextFieldWithFocus(
                                              controller: _inchesController,
                                              hintText: 'in',
                                              keyboardType: TextInputType.number,
                                              onChanged: (value) {
                                                int feet = int.tryParse(_feetController.text) ?? 0;
                                                int inches = int.tryParse(value) ?? 0;
                                                _heightController.text = (feet * 12 + inches).toString();
                                              },
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4),
                                            child: Text('"', style: TextStyle(color: Colors.white, fontSize: 18)),
                                          ),
                                        ],
                                      )
                                    : _buildTextFieldWithFocus(
                                        controller: _heightController,
                                        hintText: '0.0',
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // 3. PREFERENCES & GOALS
                    _buildFormCard(
                      title: 'PREFERENCES & GOALS',
                      icon: Icons.settings_rounded,
                      children: [
                        _buildFormGroup(
                          label: 'Activity Level',
                          child: _buildDropdownField(
                            value: _activityLevelController.text,
                            items: _activityLevels,
                            onChanged: (String? newValue) {
                              setState(() {
                                _activityLevelController.text = newValue ?? '';
                              });
                            },
                            hintText: 'Select activity level',
                          ),
                        ),
                        _buildFormGroup(
                          label: 'Fitness Goal',
                          child: _buildDropdownField(
                            value: _fitnessGoalController.text,
                            items: _fitnessGoals,
                            onChanged: (String? newValue) {
                              setState(() {
                                _fitnessGoalController.text = newValue ?? '';
                              });
                            },
                            hintText: 'Select fitness goal',
                          ),
                        ),
                      ],
                    ),

                    // Save Profile button – polished style
                    Container(
                      margin: EdgeInsets.only(
                        top: DesignSystem.spacing8,
                        bottom: DesignSystem.spacing32.rh,
                      ),
                      decoration: BoxDecoration(
                        gradient: DesignSystem.primaryGradient,
                        borderRadius: BorderRadius.circular(_polishedCardRadius),
                        boxShadow: [
                          ...DesignSystem.buttonShadow,
                          BoxShadow(
                            color: DesignSystem.primaryLight.withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(_polishedCardRadius),
                          onTap: _isLoading
                              ? null
                              : () {
                                  _saveUserData();
                                },
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: DesignSystem.spacing16.rh,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isLoading)
                                  const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: DesignSystem.light,
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.save_rounded,
                                    color: DesignSystem.light,
                                    size: 22,
                                  ),
                                SizedBox(width: DesignSystem.spacing12.rw),
                                Text(
                                  _isLoading ? 'Saving...' : 'Save Profile',
                                  style: DesignSystem.labelLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Separate stateful widget for dropdown with focus tracking
class _DropdownFieldWithFocus extends StatefulWidget {
  final String value;
  final List<String> items;
  final Function(String?) onChanged;
  final String hintText;

  const _DropdownFieldWithFocus({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hintText,
  });

  @override
  _DropdownFieldWithFocusState createState() => _DropdownFieldWithFocusState();
}

class _DropdownFieldWithFocusState extends State<_DropdownFieldWithFocus> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: _isFocused 
              ? DesignSystem.glassBg.withOpacity(0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
          border: _isFocused 
              ? Border.all(
                  color: DesignSystem.primaryLight,
                  width: 2.0,
                )
              : null,
          boxShadow: _isFocused 
              ? [
                  BoxShadow(
                    color: DesignSystem.primaryLight.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
          child: DropdownButtonFormField<String>(
            value: widget.value.isEmpty ? null : widget.value,
            isExpanded: true,
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: DesignSystem.spacing12.rw,
                vertical: DesignSystem.spacing12.rh,
              ),
              hintText: widget.hintText,
              hintStyle: DesignSystem.labelMedium.copyWith(
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            dropdownColor: DesignSystem.darkCard,
            style: DesignSystem.bodyMedium.copyWith(color: Colors.white),
            items: widget.items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: DesignSystem.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: widget.onChanged,
            onTap: () {
              setState(() {
                _isFocused = true;
              });
            },
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _isFocused 
                  ? DesignSystem.primaryLight
                  : DesignSystem.mediumGray,
            ),
          ),
        ),
      ),
    );
  }
}

// Separate stateful widget for text field with focus tracking
class _TextFieldWithFocus extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool readOnly;
  final Function(String)? onChanged;

  const _TextFieldWithFocus({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  _TextFieldWithFocusState createState() => _TextFieldWithFocusState();
}

class _TextFieldWithFocusState extends State<_TextFieldWithFocus> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: _isFocused 
              ? DesignSystem.glassBg.withOpacity(0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
          border: _isFocused 
              ? Border.all(
                  color: DesignSystem.primaryLight,
                  width: 2.0,
                )
              : null,
          boxShadow: _isFocused 
              ? [
                  BoxShadow(
                    color: DesignSystem.primaryLight.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
          child: ClipRRect(
          borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
          child: TextField(
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            readOnly: widget.readOnly,
            onChanged: widget.onChanged,
            style: DesignSystem.bodyMedium.copyWith(
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: DesignSystem.labelMedium.copyWith(
                color: Colors.white.withOpacity(0.5),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: DesignSystem.spacing16.rw,
                vertical: DesignSystem.spacing12.rh,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

