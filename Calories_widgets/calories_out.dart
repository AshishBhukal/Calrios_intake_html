import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/activity_record.dart';
import '../services/activity_service.dart';
import '../services/health_service.dart';
import '../services/unit_preference_service.dart';
import 'add_activity_screen.dart';
import 'watch_setup_screen.dart';
import '../features/extra/constants.dart';

class CaloriesOutScreen extends StatefulWidget {
  const CaloriesOutScreen({super.key});

  @override
  State<CaloriesOutScreen> createState() => CaloriesOutScreenState();
}

class CaloriesOutScreenState extends State<CaloriesOutScreen> {
  List<ActivityRecord> _activities = [];
  WeeklySummary? _weeklySummary;
  DateTime? _lastSyncTime;
  bool _isLoading = true;
  bool _isSyncing = false;
  String _distanceUnit = 'km';
  String _energyUnit = 'kcal';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        ActivityService.getActivities(days: 30),
        ActivityService.getWeeklySummary(),
        HealthService.getLastSyncTime(),
        UnitPreferenceService.getDistanceUnit(),
        UnitPreferenceService.getEnergyUnit(),
      ]);

      if (!mounted) return;
      setState(() {
        _activities = results[0] as List<ActivityRecord>;
        _weeklySummary = results[1] as WeeklySummary;
        _lastSyncTime = results[2] as DateTime?;
        _distanceUnit = results[3] as String;
        _energyUnit = results[4] as String;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Error loading activity data: $e');
    }
  }

  Future<void> _syncFromWatch() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final count = await ActivityService.syncFromWatch(days: 7);
      if (!mounted) return;

      if (count > 0) {
        _showSnackBar('Synced $count new activities');
        await _loadData();
      } else {
        _showSnackBar('No new activities found');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Sync failed. Check your health app connection.');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  Future<void> _openAddActivity() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AddActivityScreen(),
        fullscreenDialog: true,
      ),
    );
    if (result == true) {
      await _loadData();
    }
  }

  void _openWatchSetup() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WatchSetupScreen()),
    );
  }

  String _formatLastSync() {
    if (_lastSyncTime == null) return 'Never synced';
    final diff = DateTime.now().difference(_lastSyncTime!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(_lastSyncTime!);
  }

  String _formatDistance(double? meters) {
    if (meters == null) return '--';
    final km = meters / 1000;
    final converted = UnitConverter.convertDistanceFromKm(km, _distanceUnit);
    return '${converted.toStringAsFixed(2)} $_distanceUnit';
  }

  String _formatCalories(double cal) {
    return cal.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4895ef)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF4361EE),
      backgroundColor: const Color(0xFF121c36),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16.rw, 0, 16.rw, 100.rh),
        children: [
          _buildSyncButton(),
          const SizedBox(height: 6),
          _buildLastSyncText(),
          SizedBox(height: 20.rh),
          _buildWeeklySummaryCard(),
          SizedBox(height: 24.rh),
          _buildRecentActivitiesHeader(),
          SizedBox(height: 12.rh),
          if (_activities.isEmpty)
            _buildEmptyState()
          else
            ..._activities.take(10).map(_buildActivityCard),
        ],
      ),
    );
  }

  // ============================================================================
  // SYNC BUTTON
  // ============================================================================

  Widget _buildSyncButton() {
    return Semantics(
      label: 'Sync from watch',
      button: true,
      child: GestureDetector(
        onTap: _isSyncing ? null : _syncFromWatch,
        child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.rh),
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
            if (_isSyncing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.sync, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              _isSyncing ? 'Syncing...' : 'Sync from Watch',
              style: const TextStyle(
                color: Colors.white,
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

  Widget _buildLastSyncText() {
    return Center(
      child: Text(
        'LAST SYNCED: ${_formatLastSync().toUpperCase()}',
        style: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  // ============================================================================
  // WEEKLY SUMMARY CARD
  // ============================================================================

  Widget _buildWeeklySummaryCard() {
    final summary = _weeklySummary;
    final totalCal = summary?.totalCalories ?? 0;
    final percentChange = summary?.percentChange;

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF121c36),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Burned (Week)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
              ),
              if (percentChange != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: percentChange >= 0
                        ? const Color(0xFF4895ef).withOpacity(0.15)
                        : Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: percentChange >= 0
                          ? const Color(0xFF4895ef).withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '${percentChange >= 0 ? '+' : ''}${percentChange.toStringAsFixed(0)}% vs last week',
                    style: TextStyle(
                      color: percentChange >= 0
                          ? const Color(0xFF4cc9f0)
                          : Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCalories(totalCal),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _energyUnit,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 16,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.rh),
          SizedBox(
            height: 100,
            child: _buildWeeklyBarChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyBarChart() {
    final dailyCal = _weeklySummary?.dailyCalories ?? {};
    final maxVal = dailyCal.values.fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = maxVal > 0 ? maxVal * 1.3 : 500.0;
    final dayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final today = DateTime.now().weekday; // 1=Mon, 7=Sun

    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= 7) return const SizedBox.shrink();
                final isToday = idx + 1 == today;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    dayLabels[idx],
                    style: TextStyle(
                      color: isToday
                          ? const Color(0xFF4cc9f0)
                          : Colors.white.withOpacity(0.35),
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: List.generate(7, (i) {
          final weekday = i + 1;
          final cal = dailyCal[weekday] ?? 0;
          final isToday = weekday == today;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: cal > 0 ? cal : maxY * 0.02, // minimum bar height
                width: 22,
                borderRadius: BorderRadius.circular(6),
                gradient: isToday
                    ? const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xFF4361EE), Color(0xFF4cc9f0)],
                      )
                    : LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          const Color(0xFF4361EE).withOpacity(cal > 0 ? 0.4 : 0.1),
                          const Color(0xFF4895ef).withOpacity(cal > 0 ? 0.6 : 0.15),
                        ],
                      ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ============================================================================
  // RECENT ACTIVITIES
  // ============================================================================

  Widget _buildRecentActivitiesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Recent Activities',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
        Row(
          children: [
            Semantics(
              label: 'Watch setup',
              button: true,
              child: GestureDetector(
                onTap: _openWatchSetup,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.watch,
                    color: Colors.white.withOpacity(0.5),
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: 'Add activity',
              button: true,
              child: GestureDetector(
                onTap: _openAddActivity,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4361EE).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF4361EE).withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, color: Color(0xFF4895ef), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Add',
                        style: TextStyle(
                          color: Color(0xFF4895ef),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityCard(ActivityRecord activity) {
    final icon = _getActivityIcon(activity.type);
    final iconColor = _getActivityColor(activity.type);
    final timeStr = _formatActivityTime(activity.startTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFF121c36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          SizedBox(width: 14.rw),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        activity.type.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 11,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatChip(
                      'DISTANCE',
                      _formatDistance(activity.distanceMeters),
                    ),
                    SizedBox(width: 16.rw),
                    _buildStatChip(
                      'DURATION',
                      '${activity.durationMinutes} min',
                    ),
                    SizedBox(width: 16.rw),
                    _buildStatChip(
                      'BURNED',
                      '${_formatCalories(activity.caloriesBurned)} $_energyUnit',
                      highlight: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              color: Colors.white.withOpacity(0.2), size: 20),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: highlight ? const Color(0xFF4cc9f0) : Colors.white.withOpacity(0.8),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // EMPTY STATE
  // ============================================================================

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 48.rh, horizontal: 24.rw),
      child: Column(
        children: [
          Icon(
            Icons.directions_run,
            size: 64,
            color: const Color(0xFF4895ef).withOpacity(0.3),
          ),
          SizedBox(height: 16.rh),
          const Text(
            'No activities yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sync from your watch or add an activity manually to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 14,
              fontFamily: 'Inter',
              height: 1.5,
            ),
          ),
          SizedBox(height: 24.rh),
          Semantics(
            label: 'Add activity',
            button: true,
            child: GestureDetector(
              onTap: _openAddActivity,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24.rw, vertical: 12.rh),
                decoration: BoxDecoration(
                  color: const Color(0xFF4361EE).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4361EE).withOpacity(0.3),
                  ),
                ),
                child: const Text(
                  'Add Activity',
                  style: TextStyle(
                    color: Color(0xFF4895ef),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  IconData _getActivityIcon(ActivityType type) {
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

  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.running:
        return const Color(0xFFFF8C42); // orange
      case ActivityType.cycling:
        return const Color(0xFF4895ef); // blue
      case ActivityType.walking:
        return const Color(0xFF50C878); // green
      case ActivityType.strength:
        return const Color(0xFFE74C3C); // red
      case ActivityType.yoga:
        return const Color(0xFF9B59B6); // purple
      case ActivityType.swimming:
        return const Color(0xFF1ABC9C); // teal
      case ActivityType.other:
        return const Color(0xFF95A5A6); // grey
    }
  }

  String _formatActivityTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final actDate = DateTime(time.year, time.month, time.day);
    final diff = today.difference(actDate).inDays;

    final timeStr = DateFormat('h:mm a').format(time);
    if (diff == 0) return 'TODAY, $timeStr';
    if (diff == 1) return 'YESTERDAY, $timeStr';
    if (diff < 7) return '${diff}D AGO, $timeStr';
    return DateFormat('MMM d').format(time).toUpperCase();
  }
}
