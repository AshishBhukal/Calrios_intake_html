import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitness2/features/user_auth/presentation/widgets/form_container_widget.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/services/firebase_service.dart';
import 'package:fitness2/services/unit_preference_service.dart';
import 'package:fitness2/utils/ios_date_picker_helper.dart';

class PersonalInfoForm extends StatefulWidget {
  // Optional controllers - if not provided, will be created internally
  final TextEditingController? firstNameController;
  final TextEditingController? lastNameController;
  final TextEditingController? genderController;
  final TextEditingController? yearController;
  final TextEditingController? monthController;
  final TextEditingController? dayController;
  final TextEditingController? weightController;
  final TextEditingController? heightController;
  final TextEditingController? activityLevelController;
  final TextEditingController? fitnessGoalController;
  final bool showSaveButton;
  final VoidCallback? onSaveProfile;
  final bool showHeader;
  final bool isEmbedded;
  final bool isStandaloneScreen; // New: if true, shows as full screen with Scaffold

  const PersonalInfoForm({
    super.key,
    this.firstNameController,
    this.lastNameController,
    this.genderController,
    this.yearController,
    this.monthController,
    this.dayController,
    this.weightController,
    this.heightController,
    this.activityLevelController,
    this.fitnessGoalController,
    this.showSaveButton = false,
    this.onSaveProfile,
    this.showHeader = true,
    this.isEmbedded = false,
    this.isStandaloneScreen = false,
  });

  @override
  _PersonalInfoFormState createState() => _PersonalInfoFormState();
}

class _PersonalInfoFormState extends State<PersonalInfoForm> with TickerProviderStateMixin {
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

  final List<String> _weightUnits = ['kg', 'lb'];
  final List<String> _heightUnits = ['cm', 'ft-in']; // Standardized: cm or feet+inches
  final List<String> _distanceUnits = ['km', 'miles', 'm'];
  
  String _selectedWeightUnit = 'kg';
  String _selectedHeightUnit = 'cm';
  String _selectedDistanceUnit = 'km';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Internal controllers (created if not provided)
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
  
  bool _isLoading = false;
  bool _isLoadingData = true; // For initial data load
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Create controllers if not provided
    _firstNameController = widget.firstNameController ?? TextEditingController();
    _lastNameController = widget.lastNameController ?? TextEditingController();
    _genderController = widget.genderController ?? TextEditingController();
    _yearController = widget.yearController ?? TextEditingController();
    _monthController = widget.monthController ?? TextEditingController();
    _dayController = widget.dayController ?? TextEditingController();
    _weightController = widget.weightController ?? TextEditingController();
    _heightController = widget.heightController ?? TextEditingController();
    _activityLevelController = widget.activityLevelController ?? TextEditingController();
    _fitnessGoalController = widget.fitnessGoalController ?? TextEditingController();
    _feetController = TextEditingController();
    _inchesController = TextEditingController();
    
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
    
    // Only fetch data if standalone screen or if controllers were not provided
    if (widget.isStandaloneScreen || widget.firstNameController == null) {
      _fetchUserData();
    } else {
      _isLoadingData = false;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    // Only dispose controllers if we created them
    if (widget.firstNameController == null) {
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
    }
    // Always dispose ft-in controllers (we always create them)
    _feetController.dispose();
    _inchesController.dispose();
    super.dispose();
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
          // Handle activity level with fallback for old data
          String activityLevel = userData['activityLevel'] ?? '';
          if (activityLevel.isNotEmpty && !_activityLevels.contains(activityLevel)) {
            // Map old values to new ones or use a default
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
              activityLevel = 'Moderately Active'; // Default fallback
            }
          }
          _activityLevelController.text = activityLevel;
          // Handle fitness goal with fallback for old data
          String fitnessGoal = userData['fitnessGoal'] ?? '';
          if (fitnessGoal.isNotEmpty && !_fitnessGoals.contains(fitnessGoal)) {
            // Map old values to new ones or use a default
            if (fitnessGoal.toLowerCase().contains('muscle') || fitnessGoal.toLowerCase().contains('mass')) {
              fitnessGoal = 'Build Muscle';
            } else if (fitnessGoal.toLowerCase().contains('lose') || fitnessGoal.toLowerCase().contains('weight loss')) {
              fitnessGoal = 'Lose Weight';
            } else if (fitnessGoal.toLowerCase().contains('gain') || fitnessGoal.toLowerCase().contains('weight gain')) {
              fitnessGoal = 'Gain Weight';
            } else {
              fitnessGoal = 'General Fitness'; // Default fallback
            }
          }
          _fitnessGoalController.text = fitnessGoal;
          _selectedWeightUnit = userData['weightUnit'] ?? 'kg';
          // Normalize legacy height units to standardized format
          String heightUnit = userData['heightUnit'] ?? 'cm';
          if (heightUnit == 'in' || heightUnit == 'ft' || heightUnit == 'inches' || heightUnit == 'feet') {
            heightUnit = 'ft-in';
          }
          _selectedHeightUnit = heightUnit;
          _selectedDistanceUnit = userData['distanceUnit'] ?? 'km';
          
          // Convert stored height (cm) to user's preferred display unit
          double storedHeight = (userData['height'] as num?)?.toDouble() ?? 0.0;
          if (_selectedHeightUnit == 'ft-in') {
            // Convert cm to total inches, then split into feet and inches
            double totalInches = UnitConverter.convertHeightFromCm(storedHeight, 'ft-in');
            int feet = totalInches.round() ~/ 12;
            int inches = totalInches.round() % 12;
            _feetController.text = feet.toString();
            _inchesController.text = inches.toString();
            _heightController.text = totalInches.toStringAsFixed(0);
          } else {
            _heightController.text = storedHeight.toStringAsFixed(1);
          }
          
          // Convert stored weight (kg) to user's preferred display unit
          double storedWeight = (userData['weight'] as num?)?.toDouble() ?? 0.0;
          double displayWeight = UnitConverter.convertWeightFromKg(storedWeight, _selectedWeightUnit);
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

  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan_features.txt ID f_9i0j1k_features
  Future<void> _saveUserData() async {
    setState(() {
      _isLoading = true;
    });

    User? user = _auth.currentUser;
    if (user != null) {
      double weight = double.tryParse(_weightController.text) ?? 0.0;
      double weightInKg = _convertToKg(weight, _selectedWeightUnit);
      double height = double.tryParse(_heightController.text) ?? 0.0;
      double heightInCm = _convertToCm(height, _selectedHeightUnit);

      await _firestore.collection('users').doc(user.uid).set({
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'gender': _genderController.text,
        'dob': {
          'year': _yearController.text,
          'month': _monthController.text,
          'day': _dayController.text,
        },
        'weight': weightInKg,
        'height': heightInCm,
        'activityLevel': _activityLevelController.text,
        'fitnessGoal': _fitnessGoalController.text,
        'weightUnit': _selectedWeightUnit,
        'heightUnit': _selectedHeightUnit,
        'distanceUnit': _selectedDistanceUnit,
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));
      FirebaseService.invalidateUserDocumentCache();

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
      
      // If standalone screen, pop after save
      if (widget.isStandaloneScreen) {
        Navigator.pop(context);
      }
    } else {
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

    setState(() {
      _isLoading = false;
    });
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

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  Widget _buildFormCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    
    // For embedded or regular mode, use the original card styling
    return Container(
      margin: EdgeInsets.only(bottom: widget.isEmbedded ? DesignSystem.spacing16.rh : DesignSystem.spacing20.rh),
      decoration: widget.isEmbedded 
          ? BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(DesignSystem.cardRadius),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            )
          : DesignSystem.glassCard,
      child: Container(
        decoration: widget.isEmbedded 
            ? null 
            : BoxDecoration(
                borderRadius: BorderRadius.circular(DesignSystem.cardRadius),
                gradient: DesignSystem.cardGradient,
              ),
        child: Padding(
          padding: EdgeInsets.all(widget.isEmbedded ? DesignSystem.spacing16.r : DesignSystem.spacing24.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: DesignSystem.primaryLight,
                    size: 24,
                  ),
                  const SizedBox(width: DesignSystem.spacing8),
                  Text(
                    title,
                    style: DesignSystem.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: widget.isEmbedded ? DesignSystem.spacing16.rh : DesignSystem.spacing20.rh),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormGroup({
    required String label,
    required Widget child,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: widget.isEmbedded ? DesignSystem.spacing16.rh : DesignSystem.spacing20.rh,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DesignSystem.labelMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: DesignSystem.spacing8),
          child,
        ],
      ),
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
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
        ),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: DesignSystem.light,
          size: 28,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Edit Personal Details',
        style: DesignSystem.titleMedium.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: false,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: DesignSystem.spacing32.rh),
      child: Column(
        children: [
          _buildGradientText(
            'Account Details',
            DesignSystem.headlineLarge,
          ),
          const SizedBox(height: DesignSystem.spacing8),
          Text(
            'Update your personal information',
            style: DesignSystem.labelMedium,
            textAlign: TextAlign.center,
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

  @override
  Widget build(BuildContext context) {
    // If standalone screen and loading, show loading state
    if (widget.isStandaloneScreen && _isLoadingData) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: true,
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

    Widget content = Column(
      children: [
        // Conditional Header
        if (widget.showHeader) ...[
          SizedBox(height: widget.isEmbedded ? DesignSystem.spacing16.rh : DesignSystem.spacing32.rh),
          _buildGradientText(
            'Personal Information',
            DesignSystem.headlineLarge,
          ),
          const SizedBox(height: DesignSystem.spacing8),
          Text(
            'Complete your profile to get started',
            style: DesignSystem.labelMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: widget.isEmbedded ? DesignSystem.spacing16.rh : DesignSystem.spacing32.rh),
        ],

        // Basic Information Card
        _buildFormCard(
          title: 'Basic Information',
          icon: Icons.person_rounded,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildFormGroup(
                    label: 'First Name',
                    child: FormContainerWidget(
                      controller: _firstNameController,
                      hintText: 'Enter your first name',
                      hintStyle: DesignSystem.labelMedium,
                      textStyle: DesignSystem.bodyMedium,
                    ),
                  ),
                ),
                SizedBox(width: DesignSystem.spacing16.rw),
                Expanded(
                  child: _buildFormGroup(
                    label: 'Last Name',
                    child: FormContainerWidget(
                      controller: _lastNameController,
                      hintText: 'Enter your last name',
                      hintStyle: DesignSystem.labelMedium,
                      textStyle: DesignSystem.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Gender Card
        _buildFormCard(
          title: 'Gender',
          icon: Icons.wc_rounded,
          children: [
            _buildFormGroup(
              label: 'Select Gender',
              child: _buildDropdownField(
                value: _genderController.text,
                items: _genders,
                onChanged: (String? newValue) {
                  setState(() {
                    _genderController.text = newValue!;
                  });
                },
                hintText: 'Select your gender',
              ),
            ),
          ],
        ),

        // Date of Birth Card
        _buildFormCard(
          title: 'Date of Birth',
          icon: Icons.cake_rounded,
          children: [
            _buildFormGroup(
              label: 'Select Date',
                child: GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: FormContainerWidget(
                    controller: TextEditingController(
                      text: "${_dayController.text} ${_monthController.text} ${_yearController.text}",
                    ),
                    hintText: 'Select Date',
                    hintStyle: DesignSystem.labelMedium,
                    textStyle: DesignSystem.bodyMedium,
                    readOnly: true,
                    prefixIcon: Icon(
                      Icons.calendar_today_rounded,
                      color: DesignSystem.mediumGray,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Weight Card
        _buildFormCard(
          title: 'Body Weight',
          icon: Icons.fitness_center_rounded,
          children: [
            _buildFormGroup(
              label: 'Enter Your Weight',
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: FormContainerWidget(
                      controller: _weightController,
                      hintText: '0.0',
                      hintStyle: DesignSystem.labelMedium,
                      textStyle: DesignSystem.bodyMedium,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  SizedBox(width: DesignSystem.spacing12.rw),
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedWeightUnit,
                        items: _weightUnits.map((String unit) {
                          return DropdownMenuItem<String>(
                            value: unit,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: DesignSystem.spacing12.rw,
                              ),
                              child: Text(
                                unit,
                                style: DesignSystem.bodyMedium.copyWith(color: Colors.white),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedWeightUnit = newValue!;
                          });
                        },
                        dropdownColor: DesignSystem.darkCard,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: DesignSystem.mediumGray,
                        ),
                        underline: Container(),
                        isExpanded: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Unit Preferences Card
        _buildFormCard(
          title: 'Unit Preferences',
          icon: Icons.straighten_rounded,
          children: [
            _buildFormGroup(
              label: 'Weight Unit',
              child: _buildDropdownField(
                value: _selectedWeightUnit,
                items: _weightUnits,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedWeightUnit = newValue!;
                  });
                },
                hintText: 'Select weight unit',
              ),
            ),
            _buildFormGroup(
              label: 'Height Unit',
              child: _buildDropdownField(
                value: _selectedHeightUnit,
                items: _heightUnits,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedHeightUnit = newValue!;
                  });
                },
                hintText: 'Select height unit',
              ),
            ),
            _buildFormGroup(
              label: 'Distance Unit',
              child: _buildDropdownField(
                value: _selectedDistanceUnit,
                items: _distanceUnits,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedDistanceUnit = newValue!;
                  });
                },
                hintText: 'Select distance unit',
              ),
            ),
          ],
        ),

        // Height Card
        _buildFormCard(
          title: 'Height',
          icon: Icons.height_rounded,
          children: [
            _buildFormGroup(
              label: 'Enter Your Height',
              child: _selectedHeightUnit == 'ft-in'
                  ? Row(
                      children: [
                        // Feet input
                        Expanded(
                          flex: 2,
                          child: FormContainerWidget(
                            controller: _feetController,
                            hintText: 'ft',
                            hintStyle: DesignSystem.labelMedium,
                            textStyle: DesignSystem.bodyMedium,
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
                        // Inches input
                        Expanded(
                          flex: 2,
                          child: FormContainerWidget(
                            controller: _inchesController,
                            hintText: 'in',
                            hintStyle: DesignSystem.labelMedium,
                            textStyle: DesignSystem.bodyMedium,
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
                        SizedBox(width: DesignSystem.spacing12.rw),
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedHeightUnit,
                              items: _heightUnits.map((String unit) {
                                return DropdownMenuItem<String>(
                                  value: unit,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: DesignSystem.spacing12.rw,
                                    ),
                                    child: Text(
                                      unit,
                                      style: DesignSystem.bodyMedium.copyWith(color: Colors.white),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedHeightUnit = newValue!;
                                  // Convert when switching units
                                  if (newValue == 'cm') {
                                    int totalInches = int.tryParse(_heightController.text) ?? 0;
                                    double cm = totalInches * 2.54;
                                    _heightController.text = cm.toStringAsFixed(1);
                                  }
                                });
                              },
                              dropdownColor: DesignSystem.darkCard,
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: DesignSystem.mediumGray,
                              ),
                              underline: Container(),
                              isExpanded: true,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: FormContainerWidget(
                            controller: _heightController,
                            hintText: '0.0',
                            hintStyle: DesignSystem.labelMedium,
                            textStyle: DesignSystem.bodyMedium,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        SizedBox(width: DesignSystem.spacing12.rw),
                        Expanded(
                          flex: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedHeightUnit,
                              items: _heightUnits.map((String unit) {
                                return DropdownMenuItem<String>(
                                  value: unit,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: DesignSystem.spacing12.rw,
                                    ),
                                    child: Text(
                                      unit,
                                      style: DesignSystem.bodyMedium.copyWith(color: Colors.white),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedHeightUnit = newValue!;
                                  // Convert when switching units
                                  if (newValue == 'ft-in') {
                                    double cm = double.tryParse(_heightController.text) ?? 0;
                                    double totalInches = cm / 2.54;
                                    int feet = totalInches.round() ~/ 12;
                                    int inches = totalInches.round() % 12;
                                    _feetController.text = feet.toString();
                                    _inchesController.text = inches.toString();
                                    _heightController.text = totalInches.toStringAsFixed(0);
                                  }
                                });
                              },
                              dropdownColor: DesignSystem.darkCard,
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: DesignSystem.mediumGray,
                              ),
                              underline: Container(),
                              isExpanded: true,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),

        // Activity Level Card
        _buildFormCard(
          title: 'Activity Level',
          icon: Icons.directions_run_rounded,
          children: [
            _buildFormGroup(
              label: 'Select Activity Level',
              child: _buildDropdownField(
                value: _activityLevelController.text,
                items: _activityLevels,
                onChanged: (String? newValue) {
                  setState(() {
                    _activityLevelController.text = newValue!;
                  });
                },
                hintText: 'Select your activity level',
              ),
            ),
          ],
        ),

        // Fitness Goals Card
        _buildFormCard(
          title: 'Fitness Goals',
          icon: Icons.flag_rounded,
          children: [
            _buildFormGroup(
              label: 'Select Fitness Goal',
              child: _buildDropdownField(
                value: _fitnessGoalController.text,
                items: _fitnessGoals,
                onChanged: (String? newValue) {
                  setState(() {
                    _fitnessGoalController.text = newValue!;
                  });
                },
                hintText: 'Select your fitness goal',
              ),
            ),
          ],
        ),

        if (widget.showSaveButton) SizedBox(height: widget.isEmbedded ? DesignSystem.spacing16.rh : DesignSystem.spacing20.rh),

        // Save Button
        if (widget.showSaveButton)
          AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: DesignSystem.primaryButton,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(DesignSystem.buttonRadius),
                  onTap: _isLoading ? null : () {
                    if (widget.onSaveProfile != null) {
                      widget.onSaveProfile!();
                    } else {
                      _saveUserData();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: DesignSystem.spacing32.rw,
                      vertical: DesignSystem.spacing16.rh,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isLoading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: DesignSystem.light,
                              strokeWidth: 2,
                            ),
                          )
                        else
                          const Icon(
                            Icons.save_rounded,
                            color: DesignSystem.light,
                            size: 20,
                          ),
                        const SizedBox(width: DesignSystem.spacing8),
                        Text(
                          _isLoading ? 'Saving...' : 'Save Profile',
                          style: DesignSystem.labelLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

        SizedBox(height: widget.isEmbedded ? DesignSystem.spacing16.rh : DesignSystem.spacing32.rh),
      ],
    );

    // Wrap with appropriate container based on embedded/standalone state
    if (widget.isStandaloneScreen) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: true,
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
            top: false, // Allow content behind Dynamic Island
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width > 600 
                        ? DesignSystem.spacing20.rw 
                        : DesignSystem.spacing12.rw,
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: DesignSystem.spacing16.rh),
                      _buildPageHeader(),
                      SizedBox(height: DesignSystem.spacing24.rh),
                      Container(
                        decoration: DesignSystem.glassCard,
                        child: Padding(
                          padding: EdgeInsets.all(DesignSystem.spacing24.r),
                          child: content,
                        ),
                      ),
                      SizedBox(height: DesignSystem.spacing32.rh),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else if (widget.isEmbedded) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: content,
      );
    } else {
      return Container(
        decoration: const BoxDecoration(
          gradient: DesignSystem.backgroundGradient,
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              left: DesignSystem.spacing20.rw,
              right: DesignSystem.spacing20.rw,
              top: DesignSystem.spacing20.rh,
              bottom: DesignSystem.spacing20.rh + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: content,
          ),
        ),
      );
    }
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
        child: DropdownButtonFormField<String>(
          value: widget.value.isEmpty ? null : widget.value,
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: DesignSystem.spacing16.rw,
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
    );
  }
}