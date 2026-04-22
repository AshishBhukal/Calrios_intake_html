import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_data.dart';
import 'package:fitness2/onboardingv2/step_04.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/onboardingv2/onboarding_v2_helpers.dart';

// Match step_01 (Personalize Your Experience): same background and continue button
const Color _kPrimary = Color(0xFF1E54FF);
const Color _kBackground = Color(0xFF0B1221);
const Color _kCardBg = Color(0xFF121c36);
const Color _kCardBorder = Color(0x1AFFFFFF);
const double _kCardRadius = 16.0;
const double _kButtonRadius = 16.0;

/// Step 3: "Let's personalize your plan" – gender, age, height, weight.
class OnboardingStep03 extends StatefulWidget {
  final OnboardingV2Data data;

  const OnboardingStep03({super.key, required this.data});

  @override
  State<OnboardingStep03> createState() => _OnboardingStep03State();
}

class _OnboardingStep03State extends State<OnboardingStep03> {
  late String _gender;
  late int _age;
  late bool _isImperial;
  late double _heightCm;
  late double _weightKg;

  static const int _ageMin = 18;
  static const int _ageMax = 100;
  late ScrollController _ageScrollController;

  @override
  void initState() {
    super.initState();
    _gender = widget.data.gender;
    _age = widget.data.age;
    _isImperial = widget.data.isImperial;
    _heightCm = widget.data.heightCm;
    _weightKg = widget.data.weightKg;
    _ageScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollAgeIntoView());
  }

  @override
  void dispose() {
    _ageScrollController.dispose();
    super.dispose();
  }

  void _scrollAgeIntoView() {
    if (!_ageScrollController.hasClients) return;
    const itemWidth = 56.0;
    final offset = (_age - _ageMin) * itemWidth - 80;
    _ageScrollController.jumpTo(offset.clamp(0.0, _ageScrollController.position.maxScrollExtent));
  }

  String get _heightDisplay => _isImperial
      ? "${_heightFeet}' ${_heightInches}\""
      : "${_heightCm.round()}";
  String get _weightDisplay => _isImperial
      ? "${_weightLb}"
      : "${_weightKg.round()}";
  String get _weightUnit => _isImperial ? "lb" : "kg";
  int get _heightFeet => (_heightCm / 30.48).floor();
  int get _heightInches => ((_heightCm / 2.54) - (_heightFeet * 12)).round().clamp(0, 11);
  int get _weightLb => (_weightKg * 2.205).round();

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _kCardBg,
        title: const Text('Personalize your plan', style: TextStyle(color: Colors.white)),
        content: Text(
          "We use your gender, age, height and weight to calculate your daily calorie goal and recommend workout intensity. Tap height or weight cards to edit.",
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: _kPrimary)),
          ),
        ],
      ),
    );
  }

  static const List<String> _imperialHeightLabels = [
    "4' 0\"", "4' 1\"", "4' 2\"", "4' 3\"", "4' 4\"", "4' 5\"", "4' 6\"", "4' 7\"", "4' 8\"", "4' 9\"", "4' 10\"", "4' 11\"",
    "5' 0\"", "5' 1\"", "5' 2\"", "5' 3\"", "5' 4\"", "5' 5\"", "5' 6\"", "5' 7\"", "5' 8\"", "5' 9\"", "5' 10\"", "5' 11\"",
    "6' 0\"", "6' 1\"", "6' 2\"", "6' 3\"", "6' 4\"", "6' 5\"", "6' 6\"", "6' 7\"", "6' 8\"", "6' 9\"", "6' 10\"", "6' 11\"",
    "7' 0\"", "7' 1\"", "7' 2\"", "7' 3\"", "7' 4\"", "7' 5\"", "7' 6\"", "7' 7\"", "7' 8\"", "7' 9\"", "7' 10\"", "7' 11\"",
  ];
  static const int _imperialMinInches = 48;
  static int _heightCmToImperialIndex(double cm) {
    final totalInches = (cm / 2.54).round();
    return (totalInches - _imperialMinInches).clamp(0, _imperialHeightLabels.length - 1);
  }
  static double _imperialIndexToHeightCm(int index) {
    final totalInches = _imperialMinInches + index;
    return totalInches * 2.54;
  }
  static const int _metricMinCm = 100;
  static const int _metricMaxCm = 250;
  static int _heightCmToMetricIndex(double cm) => (cm.round() - _metricMinCm).clamp(0, _metricMaxCm - _metricMinCm);
  static double _metricIndexToHeightCm(int index) => (_metricMinCm + index).toDouble();

  void _showHeightEditor() {
    if (_isImperial) {
      final initialIndex = _heightCmToImperialIndex(_heightCm);
      final scrollController = FixedExtentScrollController(initialItem: initialIndex);
      int selectedIndex = initialIndex;
      showModalBottomSheet(
        context: context,
        backgroundColor: _kCardBg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24.rw, 20.rh, 24.rw, 24.rh),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select height',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Feet and inches',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                    ),
                    SizedBox(height: 16.rh),
                    SizedBox(
                      height: 180,
                      child: CupertinoTheme(
                        data: const CupertinoThemeData(brightness: Brightness.dark),
                        child: CupertinoPicker(
                          itemExtent: 44,
                          scrollController: scrollController,
                          onSelectedItemChanged: (i) => setModalState(() => selectedIndex = i),
                          selectionOverlay: Container(
                            margin: EdgeInsets.symmetric(horizontal: 24.rw),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: _kPrimary.withOpacity(0.3), width: 1.5),
                                bottom: BorderSide(color: _kPrimary.withOpacity(0.3), width: 1.5),
                              ),
                            ),
                          ),
                          children: List.generate(
                            _imperialHeightLabels.length,
                            (i) => Center(
                              child: Text(
                                _imperialHeightLabels[i],
                                style: TextStyle(
                                  color: i == selectedIndex ? Colors.white : Colors.white54,
                                  fontSize: i == selectedIndex ? 22 : 18,
                                  fontWeight: i == selectedIndex ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20.rh),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _heightCm = _imperialIndexToHeightCm(selectedIndex));
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary,
                          padding: EdgeInsets.symmetric(vertical: 14.rh),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ).then((_) => scrollController.dispose());
    } else {
      final initialIndex = _heightCmToMetricIndex(_heightCm);
      final scrollController = FixedExtentScrollController(initialItem: initialIndex);
      int selectedIndex = initialIndex;
      showModalBottomSheet(
        context: context,
        backgroundColor: _kCardBg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24.rw, 20.rh, 24.rw, 24.rh),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select height',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Centimetres',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                    ),
                    SizedBox(height: 16.rh),
                    SizedBox(
                      height: 180,
                      child: CupertinoTheme(
                        data: const CupertinoThemeData(brightness: Brightness.dark),
                        child: CupertinoPicker(
                          itemExtent: 44,
                          scrollController: scrollController,
                          onSelectedItemChanged: (i) => setModalState(() => selectedIndex = i),
                          selectionOverlay: Container(
                            margin: EdgeInsets.symmetric(horizontal: 24.rw),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: _kPrimary.withOpacity(0.3), width: 1.5),
                                bottom: BorderSide(color: _kPrimary.withOpacity(0.3), width: 1.5),
                              ),
                            ),
                          ),
                          children: List.generate(
                            _metricMaxCm - _metricMinCm + 1,
                            (i) {
                              final cm = _metricMinCm + i;
                              return Center(
                                child: Text(
                                  '$cm cm',
                                  style: TextStyle(
                                    color: i == selectedIndex ? Colors.white : Colors.white54,
                                    fontSize: i == selectedIndex ? 22 : 18,
                                    fontWeight: i == selectedIndex ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20.rh),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _heightCm = _metricIndexToHeightCm(selectedIndex));
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary,
                          padding: EdgeInsets.symmetric(vertical: 14.rh),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ).then((_) => scrollController.dispose());
    }
  }

  static const int _weightLbMin = 80;
  static const int _weightLbMax = 400;
  static const int _weightKgMin = 30;
  static const int _weightKgMax = 300;
  static int _weightKgToLbIndex(double kg) => (kg * 2.205).round().clamp(_weightLbMin, _weightLbMax) - _weightLbMin;
  static int _weightKgToKgIndex(double kg) => kg.round().clamp(_weightKgMin, _weightKgMax) - _weightKgMin;
  static double _weightLbIndexToKg(int index) => (_weightLbMin + index) / 2.205;
  static double _weightKgIndexToKg(int index) => (_weightKgMin + index).toDouble();

  void _showWeightEditor() {
    if (_isImperial) {
      final initialIndex = _weightKgToLbIndex(_weightKg);
      final scrollController = FixedExtentScrollController(initialItem: initialIndex);
      int selectedIndex = initialIndex;
      showModalBottomSheet(
        context: context,
        backgroundColor: _kCardBg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24.rw, 20.rh, 24.rw, 24.rh),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select weight',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pounds (lb)',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                    ),
                    SizedBox(height: 16.rh),
                    SizedBox(
                      height: 180,
                      child: CupertinoTheme(
                        data: const CupertinoThemeData(brightness: Brightness.dark),
                        child: CupertinoPicker(
                          itemExtent: 44,
                          scrollController: scrollController,
                          onSelectedItemChanged: (i) => setModalState(() => selectedIndex = i),
                          selectionOverlay: Container(
                            margin: EdgeInsets.symmetric(horizontal: 24.rw),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: _kPrimary.withOpacity(0.3), width: 1.5),
                                bottom: BorderSide(color: _kPrimary.withOpacity(0.3), width: 1.5),
                              ),
                            ),
                          ),
                          children: List.generate(
                            _weightLbMax - _weightLbMin + 1,
                            (i) {
                              final lb = _weightLbMin + i;
                              return Center(
                                child: Text(
                                  '$lb lb',
                                  style: TextStyle(
                                    color: i == selectedIndex ? Colors.white : Colors.white54,
                                    fontSize: i == selectedIndex ? 22 : 18,
                                    fontWeight: i == selectedIndex ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20.rh),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _weightKg = _weightLbIndexToKg(selectedIndex));
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary,
                          padding: EdgeInsets.symmetric(vertical: 14.rh),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ).then((_) => scrollController.dispose());
    } else {
      final initialIndex = _weightKgToKgIndex(_weightKg);
      final scrollController = FixedExtentScrollController(initialItem: initialIndex);
      int selectedIndex = initialIndex;
      showModalBottomSheet(
        context: context,
        backgroundColor: _kCardBg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24.rw, 20.rh, 24.rw, 24.rh),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select weight',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kilograms (kg)',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                    ),
                    SizedBox(height: 16.rh),
                    SizedBox(
                      height: 180,
                      child: CupertinoTheme(
                        data: const CupertinoThemeData(brightness: Brightness.dark),
                        child: CupertinoPicker(
                          itemExtent: 44,
                          scrollController: scrollController,
                          onSelectedItemChanged: (i) => setModalState(() => selectedIndex = i),
                          selectionOverlay: Container(
                            margin: EdgeInsets.symmetric(horizontal: 24.rw),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: _kPrimary.withOpacity(0.3), width: 1.5),
                                bottom: BorderSide(color: _kPrimary.withOpacity(0.3), width: 1.5),
                              ),
                            ),
                          ),
                          children: List.generate(
                            _weightKgMax - _weightKgMin + 1,
                            (i) {
                              final kg = _weightKgMin + i;
                              return Center(
                                child: Text(
                                  '$kg kg',
                                  style: TextStyle(
                                    color: i == selectedIndex ? Colors.white : Colors.white54,
                                    fontSize: i == selectedIndex ? 22 : 18,
                                    fontWeight: i == selectedIndex ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20.rh),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _weightKg = _weightKgIndexToKg(selectedIndex));
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary,
                          padding: EdgeInsets.symmetric(vertical: 14.rh),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ).then((_) => scrollController.dispose());
    }
  }

  void _onContinue() {
    const minHeightCm = 100.0;
    const maxHeightCm = 250.0;
    const minWeightKg = 30.0;
    const maxWeightKg = 300.0;
    if (_heightCm < minHeightCm || _heightCm > maxHeightCm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please set height between ${minHeightCm.round()} and ${maxHeightCm.round()} cm'), backgroundColor: _kPrimary),
      );
      return;
    }
    if (_weightKg < minWeightKg || _weightKg > maxWeightKg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please set weight between ${minWeightKg.round()} and ${maxWeightKg.round()} kg'), backgroundColor: _kPrimary),
      );
      return;
    }
    widget.data.gender = _gender;
    widget.data.age = _age;
    widget.data.isImperial = _isImperial;
    widget.data.heightCm = _heightCm;
    widget.data.weightKg = _weightKg;
    Navigator.push(
      context,
      OnboardingPageRoute(child: OnboardingStep04(data: widget.data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textMuted = Colors.white.withOpacity(0.6);

    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgressBar(currentStep: 3),
            Expanded(
              child: OnboardingScrollBody(
                padding: EdgeInsets.fromLTRB(24.rw, 16.rh, 24.rw, 24.rh),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Back button
              _circleButton(
                icon: Icons.arrow_back,
                surface: _kCardBg,
                onTap: () => Navigator.maybePop(context),
              ),
              SizedBox(height: 16.rh),
              // Title & subtitle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Let's personalize your plan",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We'll use this data to calculate your daily calorie goal and workout intensity.",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.rh),
              // Gender
              _sectionLabel('I identify as...', textMuted),
                    SizedBox(height: 12.rh),
                    Row(
                      children: [
                        _genderChip('female', Icons.female, textMuted),
                        SizedBox(width: 12.rw),
                        _genderChip('male', Icons.male, textMuted),
                        SizedBox(width: 12.rw),
                        _genderChip('other', Icons.transgender, textMuted),
                      ],
                    ),
                    SizedBox(height: 32.rh),
                    // Age
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _sectionLabel('Age', textMuted),
                        Text(
                          '$_age',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _kPrimary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.rh),
                    Container(
                      height: 64,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _kCardBg,
                        borderRadius: BorderRadius.circular(_kCardRadius),
                        border: Border.all(color: _kCardBorder),
                      ),
                      child: ListView.builder(
                        controller: _ageScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 12.rw),
                        itemCount: _ageMax - _ageMin + 1,
                        itemBuilder: (context, index) {
                          final a = _ageMin + index;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _age = a),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _age == a ? const Color(0xFF1e3255) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _age == a
                                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))]
                                      : null,
                                ),
                                child: Text(
                                  '$a',
                                  style: TextStyle(
                                    fontSize: _age == a ? 20 : 18,
                                    fontWeight: _age == a ? FontWeight.bold : FontWeight.w500,
                                    color: _age == a ? _kPrimary : textMuted,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 32.rh),
                    // Units toggle
                    Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: _kCardBg,
                        borderRadius: BorderRadius.circular(_kCardRadius),
                        border: Border.all(color: _kCardBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Measurement Units',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Imperial (ft/lb) vs Metric (cm/kg)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1e3255),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _unitToggle('Imperial', true),
                                _unitToggle('Metric', false),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.rh),
                    // Height & Weight
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _showHeightEditor,
                            child: _metricCard(
                              label: 'Height',
                              value: _heightDisplay,
                              unit: _isImperial ? null : 'cm',
                              textMuted: textMuted,
                            ),
                          ),
                        ),
                        SizedBox(width: 16.rw),
                        Expanded(
                          child: GestureDetector(
                            onTap: _showWeightEditor,
                            child: _metricCard(
                              label: 'Weight',
                              value: _weightDisplay,
                              unit: _weightUnit,
                              textMuted: textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
              SizedBox(height: 24.rh),
            ],
                actionSection: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 18.rh),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_kButtonRadius),
                      ),
                      elevation: 4,
                      shadowColor: _kPrimary.withOpacity(0.3),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _circleButton({
    required IconData icon,
    required Color surface,
    required VoidCallback onTap,
  }) {
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 22, color: Colors.white),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: color,
      ),
    );
  }

  Widget _genderChip(String value, IconData icon, Color textMuted) {
    final selected = _gender == value;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_kCardRadius),
          onTap: () => setState(() => _gender = value),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 16.rh),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(_kCardRadius),
              border: Border.all(
                color: selected ? _kPrimary : _kCardBorder,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: selected ? _kPrimary : null,
                ),
                const SizedBox(height: 4),
                Text(
                  value == 'other' ? 'Other' : value == 'female' ? 'Female' : 'Male',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selected ? _kPrimary : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _unitToggle(String label, bool isImperial) {
    final selected = _isImperial == isImperial;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => _isImperial = isImperial),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0A192F) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: selected ? _kPrimary : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required String? unit,
    required Color textMuted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label, textMuted),
        SizedBox(height: 12.rh),
        Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(_kCardRadius),
            border: Border.all(color: _kCardBorder),
          ),
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _kPrimary,
                    ),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textMuted,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 16.rh),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(7, (i) {
                  final isCenter = i == 3;
                  return Container(
                    width: isCenter ? 4 : 2,
                    height: isCenter ? 24.0 : (8.0 + (i % 3) * 4.0),
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: isCenter ? _kPrimary : textMuted.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
