import 'package:flutter/material.dart';
import 'package:fitness2/services/unit_preference_service.dart';
import 'package:fitness2/services/notification_service.dart';
import 'package:fitness2/features/extra/constants.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedWeightUnit = 'kg';
  String _selectedHeightUnit = 'cm';
  String _selectedDistanceUnit = 'km';
  bool _workoutReminderEnabled = false;
  int _workoutReminderHour = 9;
  int _workoutReminderMinute = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    try {
      final results = await Future.wait([
        UnitPreferenceService.getUserUnitPreferences(),
        NotificationService.getWorkoutReminderPrefs(),
      ]);
      final unitPrefs = results[0] as Map<String, String>;
      final notifPrefs = results[1] as ({bool enabled, int hour, int minute});
      if (mounted) {
        setState(() {
          _selectedWeightUnit = unitPrefs['weight']!;
          _selectedHeightUnit = unitPrefs['height']!;
          _selectedDistanceUnit = unitPrefs['distance']!;
          _workoutReminderEnabled = notifPrefs.enabled;
          _workoutReminderHour = notifPrefs.hour;
          _workoutReminderMinute = notifPrefs.minute;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading preferences: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePreferences() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await UnitPreferenceService.saveUserUnitPreferences({
        'weight': _selectedWeightUnit,
        'height': _selectedHeightUnit,
        'distance': _selectedDistanceUnit,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: DesignSystem.light),
                const SizedBox(width: DesignSystem.spacing8),
                const Text('Settings saved successfully!'),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: DesignSystem.light),
                const SizedBox(width: DesignSystem.spacing8),
                Text('Failed to save settings. Please try again.'),
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
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildDropdownField({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required String label,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: DesignSystem.spacing20.rh),
      decoration: DesignSystem.glassCard,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignSystem.cardRadius),
          gradient: DesignSystem.cardGradient,
        ),
        child: Padding(
          padding: EdgeInsets.all(DesignSystem.spacing24.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.straighten_rounded,
                    color: DesignSystem.primaryLight,
                    size: 24,
                  ),
                  const SizedBox(width: DesignSystem.spacing8),
                  Text(
                    label,
                    style: DesignSystem.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: DesignSystem.spacing16.rh),
              DropdownButtonFormField<String>(
                initialValue: value,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: DesignSystem.spacing16.rw,
                    vertical: DesignSystem.spacing12.rh,
                  ),
                ),
                dropdownColor: DesignSystem.darkCard,
                style: DesignSystem.bodyMedium.copyWith(color: Colors.white),
                items: items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      UnitOptions.weightUnitLabels[item] ?? 
                      UnitOptions.heightUnitLabels[item] ?? 
                      UnitOptions.distanceUnitLabels[item] ?? 
                      item,
                      style: DesignSystem.bodyMedium,
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: DesignSystem.mediumGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: DesignSystem.backgroundGradient,
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.all(DesignSystem.spacing20.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          SizedBox(width: DesignSystem.spacing16.rw),
                          Expanded(
                            child: ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFF4895ef), Color(0xFF4cc9f0)],
                              ).createShader(bounds),
                              child: const Text(
                                'Unit Preferences',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: DesignSystem.spacing32.rh),

                      // Description
                      Text(
                        'Choose your preferred units for weight, height, and distance measurements throughout the app.',
                        style: DesignSystem.labelMedium.copyWith(
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: DesignSystem.spacing32.rh),

                      // Weight Unit
                      _buildDropdownField(
                        value: _selectedWeightUnit,
                        items: UnitOptions.weightUnits,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedWeightUnit = newValue!;
                          });
                        },
                        label: 'Weight Unit',
                      ),

                      // Height Unit
                      _buildDropdownField(
                        value: _selectedHeightUnit,
                        items: UnitOptions.heightUnits,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedHeightUnit = newValue!;
                          });
                        },
                        label: 'Height Unit',
                      ),

                      // Distance Unit
                      _buildDropdownField(
                        value: _selectedDistanceUnit,
                        items: UnitOptions.distanceUnits,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedDistanceUnit = newValue!;
                          });
                        },
                        label: 'Distance Unit',
                      ),

                      SizedBox(height: DesignSystem.spacing24.rh),
                      Text(
                        'Notifications',
                        style: DesignSystem.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: DesignSystem.spacing12.rh),
                      Container(
                        margin: EdgeInsets.only(bottom: DesignSystem.spacing20.rh),
                        decoration: DesignSystem.glassCard,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(DesignSystem.cardRadius),
                            gradient: DesignSystem.cardGradient,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(DesignSystem.spacing24.r),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.notifications_active_rounded,
                                      color: DesignSystem.primaryLight,
                                      size: 24,
                                    ),
                                    const SizedBox(width: DesignSystem.spacing8),
                                    Expanded(
                                      child: Text(
                                        'Workout reminder',
                                        style: DesignSystem.titleMedium.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value: _workoutReminderEnabled,
                                      onChanged: (bool value) async {
                                        if (value) {
                                          final granted = await NotificationService.requestPermission();
                                          if (!granted && mounted) return;
                                        }
                                        setState(() => _workoutReminderEnabled = value);
                                        await NotificationService.saveWorkoutReminderPrefs(
                                          enabled: value,
                                          hour: _workoutReminderHour,
                                          minute: _workoutReminderMinute,
                                        );
                                      },
                                      activeColor: DesignSystem.primaryLight,
                                    ),
                                  ],
                                ),
                                if (_workoutReminderEnabled) ...[
                                  SizedBox(height: DesignSystem.spacing16.rh),
                                  Text(
                                    'Daily reminder at',
                                    style: DesignSystem.bodyMedium.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: DesignSystem.spacing8),
                                  InkWell(
                                    onTap: () async {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay(
                                          hour: _workoutReminderHour,
                                          minute: _workoutReminderMinute,
                                        ),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme: const ColorScheme.dark(
                                                primary: Color(0xFF4895ef),
                                                surface: Color(0xFF1E293B),
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (time != null && mounted) {
                                        setState(() {
                                          _workoutReminderHour = time.hour;
                                          _workoutReminderMinute = time.minute;
                                        });
                                        await NotificationService.saveWorkoutReminderPrefs(
                                          enabled: true,
                                          hour: time.hour,
                                          minute: time.minute,
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: DesignSystem.spacing12.rh,
                                        horizontal: DesignSystem.spacing16.rw,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
                                      ),
                                      child: Text(
                                        '${_workoutReminderHour.toString().padLeft(2, '0')}:${_workoutReminderMinute.toString().padLeft(2, '0')}',
                                        style: DesignSystem.bodyLarge.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: DesignSystem.spacing32.rh),

                      // Save Button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: DesignSystem.primaryButton,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(DesignSystem.buttonRadius),
                            onTap: _isSaving ? null : _savePreferences,
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: DesignSystem.spacing32.rw,
                                vertical: DesignSystem.spacing16.rh,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isSaving)
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
                                    _isSaving ? 'Saving...' : 'Save Settings',
                                    style: DesignSystem.labelLarge,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: DesignSystem.spacing32.rh),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
