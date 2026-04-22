import 'package:flutter/material.dart';
import 'package:fitness2/services/unit_preference_service.dart';
import 'package:fitness2/features/extra/constants.dart';

class UnitSettingsPage extends StatefulWidget {
  const UnitSettingsPage({super.key});

  @override
  State<UnitSettingsPage> createState() => _UnitSettingsPageState();
}

class _UnitSettingsPageState extends State<UnitSettingsPage> {
  String _selectedWeightUnit = 'kg';
  String _selectedHeightUnit = 'cm';
  String _selectedDistanceUnit = 'km';
  String _selectedEnergyUnit = 'kcal';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;

  // Track original values to detect changes
  late String _originalWeight;
  late String _originalHeight;
  late String _originalDistance;
  late String _originalEnergy;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    try {
      final preferences = await UnitPreferenceService.getUserUnitPreferences();
      if (mounted) {
        // Normalize legacy height units to new format
        String heightUnit = preferences['height']!;
        if (heightUnit == 'in' || heightUnit == 'ft' || heightUnit == 'inches' || heightUnit == 'feet') {
          heightUnit = 'ft-in';
        }

        setState(() {
          _selectedWeightUnit = preferences['weight']!;
          _selectedHeightUnit = heightUnit;
          _selectedDistanceUnit = preferences['distance']!;
          _selectedEnergyUnit = preferences['energy']!;
          _originalWeight = _selectedWeightUnit;
          _originalHeight = _selectedHeightUnit;
          _originalDistance = _selectedDistanceUnit;
          _originalEnergy = _selectedEnergyUnit;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading preferences: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _checkForChanges() {
    setState(() {
      _hasChanges = _selectedWeightUnit != _originalWeight ||
          _selectedHeightUnit != _originalHeight ||
          _selectedDistanceUnit != _originalDistance ||
          _selectedEnergyUnit != _originalEnergy;
    });
  }

  Future<void> _savePreferences() async {
    if (!_hasChanges) return;
    setState(() => _isSaving = true);

    try {
      await UnitPreferenceService.saveUserUnitPreferences({
        'weight': _selectedWeightUnit,
        'height': _selectedHeightUnit,
        'distance': _selectedDistanceUnit,
        'energy': _selectedEnergyUnit,
      });

      if (mounted) {
        _originalWeight = _selectedWeightUnit;
        _originalHeight = _selectedHeightUnit;
        _originalDistance = _selectedDistanceUnit;
        _originalEnergy = _selectedEnergyUnit;
        _hasChanges = false;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Preferences saved!', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: DesignSystem.success,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16.r),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Failed to save. Please try again.'),
              ],
            ),
            backgroundColor: DesignSystem.danger,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16.r),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _applyPreset(Map<String, String> preset) {
    setState(() {
      _selectedWeightUnit = preset['weight']!;
      _selectedHeightUnit = preset['height']!;
      _selectedDistanceUnit = preset['distance']!;
      _selectedEnergyUnit = preset['energy']!;
    });
    _checkForChanges();
  }

  bool get _isMetricPreset =>
      _selectedWeightUnit == 'kg' &&
      _selectedHeightUnit == 'cm' &&
      _selectedDistanceUnit == 'km' &&
      _selectedEnergyUnit == 'kcal';

  bool get _isImperialPreset =>
      _selectedWeightUnit == 'lb' &&
      _selectedHeightUnit == 'ft-in' &&
      _selectedDistanceUnit == 'miles' &&
      _selectedEnergyUnit == 'cal';

  // Colors
  static const Color _glassBg = Color.fromRGBO(255, 255, 255, 0.06);
  static const Color _glassBorder = Color.fromRGBO(255, 255, 255, 0.12);
  static const Color _inputBg = Color.fromRGBO(255, 255, 255, 0.04);
  static const Color _inputBorder = Color.fromRGBO(255, 255, 255, 0.08);
  static const Color _primary = Color(0xFF4361EE);
  static const Color _primaryLight = Color(0xFF4895EF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Unit Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background_1.png'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 12.rh),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          const Text(
                            'Unit Preferences',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Customize how your fitness data is displayed.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 20.rh),

                          // Quick Preset Buttons
                          _buildPresetSection(),
                          SizedBox(height: 20.rh),

                          // Individual Unit Settings
                          Container(
                            padding: EdgeInsets.all(20.r),
                            decoration: BoxDecoration(
                              color: _glassBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _glassBorder, width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.tune_rounded, color: _primaryLight, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Individual Settings',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Mix and match units to your preference.',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 20.rh),
                                _buildSegmentedUnit(
                                  icon: Icons.fitness_center_rounded,
                                  label: 'Weight',
                                  value: _selectedWeightUnit,
                                  options: UnitOptions.weightUnits,
                                  labels: UnitOptions.weightUnitLabels,
                                  onChanged: (v) {
                                    setState(() => _selectedWeightUnit = v);
                                    _checkForChanges();
                                  },
                                ),
                                SizedBox(height: 16.rh),
                                _buildSegmentedUnit(
                                  icon: Icons.height_rounded,
                                  label: 'Height',
                                  value: _selectedHeightUnit,
                                  options: UnitOptions.heightUnits,
                                  labels: UnitOptions.heightUnitLabels,
                                  onChanged: (v) {
                                    setState(() => _selectedHeightUnit = v);
                                    _checkForChanges();
                                  },
                                ),
                                SizedBox(height: 16.rh),
                                _buildSegmentedUnit(
                                  icon: Icons.directions_run_rounded,
                                  label: 'Distance',
                                  value: _selectedDistanceUnit,
                                  options: UnitOptions.distanceUnits,
                                  labels: UnitOptions.distanceUnitLabels,
                                  onChanged: (v) {
                                    setState(() => _selectedDistanceUnit = v);
                                    _checkForChanges();
                                  },
                                ),
                                SizedBox(height: 16.rh),
                                _buildSegmentedUnit(
                                  icon: Icons.local_fire_department_rounded,
                                  label: 'Energy',
                                  value: _selectedEnergyUnit,
                                  options: UnitOptions.energyUnits,
                                  labels: UnitOptions.energyUnitLabels,
                                  onChanged: (v) {
                                    setState(() => _selectedEnergyUnit = v);
                                    _checkForChanges();
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16.rh),

                          // Info box
                          Container(
                            padding: EdgeInsets.all(14.r),
                            decoration: BoxDecoration(
                              color: _primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _primary.withOpacity(0.15), width: 1),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline_rounded, color: _primaryLight, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'All stored data stays in standard units (kg, cm, km). Only the display changes. You can mix units freely — e.g. weight in kg with distance in miles.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.55),
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 100), // space for button
                        ],
                      ),
                    ),
                  ),

                  // Save Button (fixed at bottom)
                  if (_hasChanges)
                    Container(
                      padding: EdgeInsets.fromLTRB(16.rw, 12.rh, 16.rw, 24.rh),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF0A192F).withOpacity(0.95),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isSaving ? null : _savePreferences,
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: double.infinity,
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_primary, Color(0xFF6E85F3)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primary.withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.save_rounded, color: Colors.white, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Save Preferences',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
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

  Widget _buildPresetSection() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: _glassBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _glassBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: Colors.amber.shade400, size: 20),
              const SizedBox(width: 8),
              Text(
                'Quick Presets',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.rh),
          Row(
            children: [
              Expanded(
                child: _buildPresetButton(
                  label: 'Metric',
                  subtitle: 'kg · cm · km · kcal',
                  isSelected: _isMetricPreset,
                  onTap: () => _applyPreset(UnitPreferenceService.metricPreset),
                ),
              ),
              SizedBox(width: 12.rw),
              Expanded(
                child: _buildPresetButton(
                  label: 'Imperial',
                  subtitle: 'lb · ft/in · mi · cal',
                  isSelected: _isImperialPreset,
                  onTap: () => _applyPreset(UnitPreferenceService.imperialPreset),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton({
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 14.rh, horizontal: 14.rw),
        decoration: BoxDecoration(
          color: isSelected ? _primary.withOpacity(0.15) : _inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primary.withOpacity(0.6) : _inputBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(Icons.check_circle_rounded, color: _primaryLight, size: 16),
                  ),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? _primaryLight.withOpacity(0.8) : Colors.white.withOpacity(0.35),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedUnit({
    required IconData icon,
    required String label,
    required String value,
    required List<String> options,
    required Map<String, String> labels,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _inputBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _primaryLight.withOpacity(0.8), size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: options.map((option) {
                final isSelected = value == option;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(option),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? _primary.withOpacity(0.25) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? _primary.withOpacity(0.5) : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _getShortLabel(option, labels),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.45),
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Get short display label for segmented buttons
  String _getShortLabel(String value, Map<String, String> labels) {
    switch (value) {
      case 'kg':
        return 'kg';
      case 'lb':
        return 'lb';
      case 'cm':
        return 'cm';
      case 'ft-in':
        return 'ft/in';
      case 'km':
        return 'km';
      case 'miles':
        return 'miles';
      case 'm':
        return 'm';
      case 'kcal':
        return 'kcal';
      case 'cal':
        return 'cal';
      default:
        return labels[value] ?? value;
    }
  }
}
