import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/unit_preference_service.dart';
import '../features/extra/constants.dart';

// Design system from polished theme (macro_goals_settings)
const Color _kPrimary = Color(0xFF489cef);
const Color _kGlassBg = Color(0x0DFFFFFF);
const Color _kGlassBorder = Color(0x1FFFFFFF);
const Color _kSlate400 = Color(0xFF94a3b8);

class CaloriesSettingsScreen extends StatefulWidget {
  const CaloriesSettingsScreen({super.key});

  @override
  State<CaloriesSettingsScreen> createState() => _CaloriesSettingsScreenState();
}

class _CaloriesSettingsScreenState extends State<CaloriesSettingsScreen> {
  // Macro goals
  Map<String, dynamic> goals = {
    'calories': 2000,
    'protein': 110,
    'carbs': 50,
    'fat': 22,
    'fiber': 25,
  };

  String _energyUnit = 'kcal';

  // Calorie behavior settings
  bool _caloriesRollIn = true;
  bool _deductCaloriesOut = true;

  @override
  void initState() {
    super.initState();
    _loadEnergyUnit();
    _loadMacroGoals();
    _loadCalorieBehaviorSettings();
  }

  Future<void> _loadEnergyUnit() async {
    try {
      final unit = await UnitPreferenceService.getEnergyUnit();
      if (mounted) setState(() => _energyUnit = unit);
    } catch (_) {}
  }

  Future<void> _loadMacroGoals() async {
    try {
      final userData = await FirebaseService.getUserData();
      if (userData != null && userData['goals'] != null) {
        setState(() {
          goals = Map<String, dynamic>.from(userData['goals']);
        });
      }
    } catch (e) {
      debugPrint('Error loading macro goals: $e');
    }
  }

  Future<void> _saveMacroGoals() async {
    try {
      await FirebaseService.saveMacroGoals(goals);
    } catch (e) {
      debugPrint('Error saving macro goals: $e');
    }
  }

  Future<void> _loadCalorieBehaviorSettings() async {
    try {
      final userData = await FirebaseService.getUserData();
      if (userData != null && mounted) {
        setState(() {
          _caloriesRollIn = userData['caloriesRollIn'] ?? true;
          _deductCaloriesOut = userData['deductCaloriesOut'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error loading calorie behavior settings: $e');
    }
  }

  Future<void> _saveCalorieBehaviorSettings() async {
    try {
      await FirebaseService.saveCalorieBehaviorSettings(
        caloriesRollIn: _caloriesRollIn,
        deductCaloriesOut: _deductCaloriesOut,
      );
    } catch (e) {
      debugPrint('Error saving calorie behavior settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A192F), Colors.black],
          ),
        ),
        child: Column(
          children: [
            // Header – glass bar, centered title (polished theme)
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16.rh,
                left: 12.rw,
                right: 12.rw,
                bottom: 12.rh,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kGlassBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kGlassBorder, width: 1),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Calories Settings',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.25,
                            ),
                          ),
                        ),
                        SizedBox(width: 36.rw),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 12.rw),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMacroGoalsSection(),
                    SizedBox(height: 24.rh),
                    _buildCalorieBehaviorSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassBox({
    required Widget child,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _kGlassBg,
            borderRadius: borderRadius ?? BorderRadius.circular(10),
            border: Border.all(color: _kGlassBorder, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildMacroGoalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Macro Goals',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.25,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: [
            _buildGoalCard('calories', 'Calories', null, Icons.local_fire_department),
            _buildGoalCard('protein', 'Protein', 'g', Icons.restaurant),
            _buildGoalCard('carbs', 'Carbs', 'g', Icons.bakery_dining),
            _buildGoalCard('fat', 'Fat', 'g', Icons.water_drop),
          ],
        ),
      ],
    );
  }

  Widget _buildGoalCard(String key, String name, String? unit, IconData icon) {
    final value = (goals[key] as num?)?.toInt() ?? 0;
    final displayValue = key == 'calories'
        ? value.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          )
        : '$value$unit';

    return GestureDetector(
      onTap: () => _showEditGoalDialog(
        context,
        key,
        name,
        key == 'calories' ? _energyUnit : (unit ?? 'g'),
      ),
      child: _buildGlassBox(
        padding: EdgeInsets.all(12.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: _kPrimary, size: 18),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayValue,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _kSlate400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieBehaviorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Calorie Behavior',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.25,
            ),
          ),
        ),
        // Calories Roll-In toggle
        _buildGlassBox(
          padding: EdgeInsets.all(14.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Calories Roll-In',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'If you don\'t reach your goal, up to 200 extra cal are added to the next day.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _kSlate400,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.rw),
                  Switch.adaptive(
                    value: _caloriesRollIn,
                    activeColor: _kPrimary,
                    onChanged: (value) {
                      setState(() => _caloriesRollIn = value);
                      _saveCalorieBehaviorSettings();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 12.rh),
        // Deduct Calories Out toggle
        _buildGlassBox(
          padding: EdgeInsets.all(14.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Deduct Calories Out',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Subtract burned calories from your intake. e.g. ate 500, burned 200 → shows 300.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _kSlate400,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.rw),
                  Switch.adaptive(
                    value: _deductCaloriesOut,
                    activeColor: _kPrimary,
                    onChanged: (value) {
                      setState(() => _deductCaloriesOut = value);
                      _saveCalorieBehaviorSettings();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 24.rh),
      ],
    );
  }

  void _showEditGoalDialog(BuildContext context, String key, String name, String unit) {
    final TextEditingController goalController = TextEditingController();
    goalController.text = ((goals[key] as num?)?.toInt() ?? 0).toString();

    // Max reasonable values for each macro type
    final int maxValue = key == 'calories' ? 10000 : 1000;
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
          ),
          child: AlertDialog(
            backgroundColor: const Color(0xFF0A192F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Edit $name Goal',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            content: SingleChildScrollView(
              child: TextField(
                controller: goalController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter $name goal (max $maxValue)',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _kPrimary, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 12.rh),
                ),
              ),
            ),
            contentPadding: EdgeInsets.only(
              left: 24.rw,
              right: 24.rw,
              top: 20.rh,
              bottom: 20.rh,
            ),
            actionsPadding: EdgeInsets.only(
              left: 24.rw,
              right: 24.rw,
              bottom: 16.rh,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final goal = int.tryParse(goalController.text);
                  if (goal != null && goal > 0 && goal <= maxValue) {
                    setState(() {
                      goals[key] = goal;
                    });
                    _saveMacroGoals();
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$name goal updated to $goal $unit'),
                        backgroundColor: const Color(0xFF10B981),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a value between 1 and $maxValue'),
                        backgroundColor: Colors.orange,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }
}