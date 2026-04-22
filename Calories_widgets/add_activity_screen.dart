import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity_record.dart';
import '../services/activity_service.dart';
import '../services/health_service.dart';
import '../services/unit_preference_service.dart';
import '../features/extra/constants.dart';

class AddActivityScreen extends StatefulWidget {
  const AddActivityScreen({super.key});

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Manual log state
  ActivityType _selectedType = ActivityType.running;
  int _durationMinutes = 30;
  double _distanceKm = 0;
  double _intensity = 0.5; // 0.0-1.0
  double _estimatedCalories = 0;
  bool _isSaving = false;
  String _distanceUnit = 'km';
  String _energyUnit = 'kcal';

  // Watch sync state
  bool _isSyncing = false;
  List<ActivityRecord> _syncedActivities = [];
  final Set<String> _selectedSyncIds = {};
  bool _syncDone = false;

  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _durationController.text = '30';
    _distanceController.text = '0.00';
    _loadPreferences();
    _updateEstimatedCalories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final results = await Future.wait([
      UnitPreferenceService.getDistanceUnit(),
      UnitPreferenceService.getEnergyUnit(),
    ]);
    if (mounted) {
      setState(() {
        _distanceUnit = results[0];
        _energyUnit = results[1];
      });
    }
  }

  Future<void> _updateEstimatedCalories() async {
    final cal = await ActivityService.estimateCalories(
      type: _selectedType,
      durationMinutes: _durationMinutes,
      intensity: _intensity,
    );
    if (mounted) {
      setState(() => _estimatedCalories = cal);
    }
  }

  Future<void> _saveActivity() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final startTime = now.subtract(Duration(minutes: _durationMinutes));

      // Convert distance to meters
      double? distanceMeters;
      if (_selectedType.hasDistance && _distanceKm > 0) {
        final km = UnitConverter.convertDistanceToKm(_distanceKm, _distanceUnit);
        distanceMeters = km * 1000;
      }

      final activity = ActivityRecord(
        id: '${now.millisecondsSinceEpoch}_${_selectedType.name}_manual',
        type: _selectedType,
        caloriesBurned: _estimatedCalories,
        distanceMeters: distanceMeters,
        durationMinutes: _durationMinutes,
        startTime: startTime,
        endTime: now,
        source: ActivitySource.manual,
        intensity: _intensity,
        createdAt: now,
      );

      await ActivityService.saveActivity(activity);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving activity: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _performWatchSync() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _syncedActivities = [];
      _selectedSyncIds.clear();
      _syncDone = false;
    });

    try {
      final available = await HealthService.isAvailable();
      if (!available) {
        if (mounted) {
          _showMessage('Health platform not available on this device.');
        }
        return;
      }

      final hasPerms = await HealthService.hasPermissions();
      if (!hasPerms) {
        final granted = await HealthService.requestPermissions();
        if (!granted) {
          if (mounted) {
            _showMessage('Health permissions are required to sync.');
          }
          return;
        }
      }

      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 7));
      final workouts = await HealthService.fetchWorkouts(from: from, to: now);

      if (mounted) {
        setState(() {
          _syncedActivities = workouts;
          _selectedSyncIds.addAll(workouts.map((w) => w.id));
          _syncDone = true;
        });
      }

      if (workouts.isEmpty && mounted) {
        _showMessage('No new workouts found in the last 7 days.');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Sync error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _importSelected() async {
    final selected = _syncedActivities
        .where((a) => _selectedSyncIds.contains(a.id))
        .toList();

    if (selected.isEmpty) {
      _showMessage('No activities selected.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final count = await ActivityService.saveActivitiesFromSync(selected);
      if (mounted) {
        _showMessage('Imported $count new activities.');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Import error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  String _intensityLabel() {
    if (_intensity < 0.33) return 'Low Intensity';
    if (_intensity < 0.66) return 'Moderate';
    return 'High Intensity';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Add Activity',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildSegmentedControl(),
            SizedBox(height: 20.rh),
            Expanded(
              child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildManualLogTab(),
                _buildWatchSyncTab(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  // ============================================================================
  // SEGMENTED CONTROL
  // ============================================================================

  Widget _buildSegmentedControl() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.rw),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            _buildSegmentButton('Manual Log', 0),
            _buildSegmentButton('Watch Sync', 1),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton(String label, int index) {
    final isSelected = _tabController.index == index;
    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        selected: isSelected,
        child: GestureDetector(
          onTap: () => _tabController.animateTo(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.45),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
      ),
    );
  }

  // ============================================================================
  // MANUAL LOG TAB
  // ============================================================================

  Widget _buildManualLogTab() {
    return ListView(
      padding: EdgeInsets.fromLTRB(20.rw, 0, 20.rw, 32.rh),
      children: [
        _buildSectionLabel('SELECT ACTIVITY'),
        SizedBox(height: 12.rh),
        _buildActivityTypeGrid(),
        SizedBox(height: 28.rh),
        _buildSectionLabel('DETAILS'),
        SizedBox(height: 12.rh),
        _buildDetailsRow(),
        SizedBox(height: 24.rh),
        _buildIntensitySlider(),
        SizedBox(height: 28.rh),
        _buildEstimatedBurnCard(),
        SizedBox(height: 32.rh),
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: const Color(0xFF4895ef).withOpacity(0.8),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        fontFamily: 'Inter',
      ),
    );
  }

  Widget _buildActivityTypeGrid() {
    final types = [
      ActivityType.running,
      ActivityType.cycling,
      ActivityType.walking,
      ActivityType.strength,
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12.rw,
      mainAxisSpacing: 12.rh,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: types.map((type) {
        final isSelected = _selectedType == type;
        return Semantics(
          label: type.displayName,
          button: true,
          selected: isSelected,
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedType = type);
              _updateEstimatedCalories();
            },
            child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF121c36),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4895ef)
                    : Colors.white.withOpacity(0.06),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getIcon(type),
                  color: isSelected
                      ? const Color(0xFF4cc9f0)
                      : Colors.white.withOpacity(0.4),
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  type.displayName,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailsRow() {
    return Row(
      children: [
        Expanded(child: _buildDurationInput()),
        SizedBox(width: 12.rw),
        Expanded(child: _buildDistanceInput()),
      ],
    );
  }

  Widget _buildDurationInput() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFF121c36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Duration',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    final mins = int.tryParse(val) ?? 0;
                    _durationMinutes = mins.clamp(0, 600);
                    _updateEstimatedCalories();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'min',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceInput() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFF121c36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distance',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _distanceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    _distanceKm = double.tryParse(val) ?? 0;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _distanceUnit,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntensitySlider() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Intensity',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
                fontFamily: 'Inter',
              ),
            ),
            Text(
              _intensityLabel(),
              style: const TextStyle(
                color: Color(0xFF4cc9f0),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFF4895ef),
            inactiveTrackColor: Colors.white.withOpacity(0.08),
            thumbColor: const Color(0xFF4cc9f0),
            overlayColor: const Color(0xFF4895ef).withOpacity(0.15),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: _intensity,
            onChanged: (val) {
              setState(() => _intensity = val);
              _updateEstimatedCalories();
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('LOW',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.25),
                    fontSize: 10,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600)),
            Text('MODERATE',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.25),
                    fontSize: 10,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600)),
            Text('PEAK',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.25),
                    fontSize: 10,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildEstimatedBurnCard() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.rw, vertical: 16.rh),
      decoration: BoxDecoration(
        color: const Color(0xFF4361EE).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4361EE).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF4361EE).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_fire_department,
              color: Color(0xFF4cc9f0),
              size: 22,
            ),
          ),
          SizedBox(width: 14.rw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ESTIMATED BURN',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_estimatedCalories.toInt()} $_energyUnit',
                  style: const TextStyle(
                    color: Color(0xFF4cc9f0),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Calculated using MET formula with your weight and activity intensity.',
            child: Icon(
              Icons.info_outline,
              color: Colors.white.withOpacity(0.25),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Semantics(
      label: 'Save activity',
      button: true,
      child: GestureDetector(
        onTap: _isSaving ? null : _saveActivity,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16.rh),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4895ef), Color(0xFF4cc9f0)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4895ef).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSaving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              else
                const Icon(Icons.check_circle, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                _isSaving ? 'Saving...' : 'Save Activity',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // WATCH SYNC TAB
  // ============================================================================

  Widget _buildWatchSyncTab() {
    return ListView(
      padding: EdgeInsets.fromLTRB(20.rw, 0, 20.rw, 32.rh),
      children: [
        _buildHealthPlatformStatus(),
        SizedBox(height: 20.rh),
        _buildSyncNowButton(),
        SizedBox(height: 24.rh),
        if (_syncDone && _syncedActivities.isNotEmpty) ...[
          _buildSectionLabel('FOUND ACTIVITIES'),
        SizedBox(height: 12.rh),
        ..._syncedActivities.map(_buildSyncActivityItem),
          SizedBox(height: 24.rh),
          _buildImportButton(),
        ] else if (_syncDone && _syncedActivities.isEmpty) ...[
          _buildNoActivitiesFound(),
        ],
      ],
    );
  }

  Widget _buildHealthPlatformStatus() {
    final platform = HealthService.getConnectedPlatform();
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFF121c36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: platform != null
                  ? const Color(0xFF4361EE).withOpacity(0.12)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              platform != null ? Icons.watch : Icons.watch_off,
              color: platform != null
                  ? const Color(0xFF4895ef)
                  : Colors.white.withOpacity(0.3),
              size: 24,
            ),
          ),
          SizedBox(width: 14.rw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  platform ?? 'No Health Platform',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  platform != null
                      ? 'Ready to sync workouts'
                      : 'Install Health Connect or use Apple Health',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: platform != null
                  ? const Color(0xFF4cc9f0)
                  : Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncNowButton() {
    return Semantics(
      label: 'Sync from watch',
      button: true,
      child: GestureDetector(
        onTap: _isSyncing ? null : _performWatchSync,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.rh),
          decoration: BoxDecoration(
            color: const Color(0xFF4361EE).withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF4361EE).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSyncing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF4895ef)),
                )
              else
                const Icon(Icons.sync, color: Color(0xFF4895ef), size: 20),
              const SizedBox(width: 8),
              Text(
                _isSyncing ? 'Scanning...' : 'Sync Now (Last 7 Days)',
                style: const TextStyle(
                  color: Color(0xFF4895ef),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncActivityItem(ActivityRecord activity) {
    final isSelected = _selectedSyncIds.contains(activity.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        label: '${activity.type.displayName} activity',
        selected: isSelected,
        child: GestureDetector(
          onTap: () {
          setState(() {
            if (isSelected) {
              _selectedSyncIds.remove(activity.id);
            } else {
              _selectedSyncIds.add(activity.id);
            }
          });
        },
        child: Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: const Color(0xFF121c36),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF4895ef).withOpacity(0.5)
                  : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              // Checkbox
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4361EE)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF4895ef)
                        : Colors.white.withOpacity(0.2),
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
              SizedBox(width: 12.rw),
              Icon(
                _getIcon(activity.type),
                color: const Color(0xFF4895ef),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.type.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                    Text(
                      '${activity.durationMinutes} min  ·  '
                      '${activity.caloriesBurned.toInt()} $_energyUnit',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                DateFormat('MMM d, h:mm a').format(activity.startTime),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 11,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildImportButton() {
    final count = _selectedSyncIds.length;
    return Semantics(
      label: 'Import $count selected activities',
      button: true,
      child: GestureDetector(
        onTap: _isSaving ? null : _importSelected,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16.rh),
          decoration: BoxDecoration(
            gradient: count > 0
                ? const LinearGradient(
                    colors: [Color(0xFF4895ef), Color(0xFF4cc9f0)])
                : null,
            color: count == 0 ? Colors.white.withOpacity(0.05) : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSaving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              else
                const Icon(Icons.download, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                _isSaving
                    ? 'Importing...'
                    : 'Import Selected ($count)',
                style: TextStyle(
                  color: count > 0
                      ? Colors.white
                      : Colors.white.withOpacity(0.3),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoActivitiesFound() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 40.rh),
      child: Column(
        children: [
          Icon(Icons.search_off,
              size: 48, color: Colors.white.withOpacity(0.2)),
          SizedBox(height: 12.rh),
          Text(
            'No workouts found in the last 7 days',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  IconData _getIcon(ActivityType type) {
    switch (type) {
      case ActivityType.running:
        return Icons.directions_run;
      case ActivityType.cycling:
        return Icons.directions_bike;
      case ActivityType.walking:
        return Icons.directions_walk;
      case ActivityType.strength:
        return Icons.fitness_center;
      case ActivityType.yoga:
        return Icons.self_improvement;
      case ActivityType.swimming:
        return Icons.pool;
      case ActivityType.other:
        return Icons.sports;
    }
  }
}
