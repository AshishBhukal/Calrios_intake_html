import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../features/extra/constants.dart';
import 'nutrition_history.dart';
import '../services/unit_preference_service.dart';

class HistoryScreen extends StatefulWidget {
  final DateTime? initialDate;
  
  const HistoryScreen({super.key, this.initialDate});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  DateTime _focusedDate = DateTime.now();
  DateTime? _selectedDate;
  Map<DateTime, List<Map<String, dynamic>>> _workoutData = {};
  bool _isLoading = true;
  final Map<String, bool> _expandedWorkouts = {};
  
  late TabController _tabController;
  
  // Unit preferences
  String _userWeightUnit = 'kg';
  bool _isLoadingUnits = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _selectedDate = widget.initialDate ?? DateTime.now();
    _focusedDate = widget.initialDate ?? DateTime.now();
    _loadUserUnitPreferences();
    _loadWorkoutData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Load user unit preferences
  Future<void> _loadUserUnitPreferences() async {
    try {
      final weightUnit = await UnitPreferenceService.getWeightUnit();
      if (mounted) {
        setState(() {
          _userWeightUnit = weightUnit;
          _isLoadingUnits = false;
        });
      }
    } catch (e) {
      print('Error loading unit preferences: $e');
      if (mounted) {
        setState(() {
          _isLoadingUnits = false;
        });
      }
    }
  }

  Future<void> _loadWorkoutData() async {
    setState(() => _isLoading = true);
    
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Get the first day of the current month
      final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
      // Get the last day of the current month
      final lastDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 0);

      final querySnapshot = await _firestore
          .collection('workouts')
          .where('userId', isEqualTo: user.uid)
          .where('workoutStartTime', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth))
          .where('workoutStartTime', isLessThanOrEqualTo: Timestamp.fromDate(lastDayOfMonth))
          .orderBy('workoutStartTime', descending: true)
          .get();

      final Map<DateTime, List<Map<String, dynamic>>> workoutData = {};
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final totalVolume = (data['totalVolume'] as num?)?.toDouble() ?? 0;
        if (totalVolume <= 0) continue;
        
        final workoutStartTime = (data['workoutStartTime'] as Timestamp).toDate();
        final date = DateTime(workoutStartTime.year, workoutStartTime.month, workoutStartTime.day);
        
        if (!workoutData.containsKey(date)) {
          workoutData[date] = [];
        }
        workoutData[date]!.add(data);
      }

      setState(() {
        _workoutData = workoutData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading workout data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onDateSelected(DateTime selectedDate) {
    setState(() {
      _selectedDate = selectedDate;
    });
  }

  void _onPageChanged(DateTime focusedDate) {
    setState(() {
      _focusedDate = focusedDate;
    });
    _loadWorkoutData();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _hasWorkoutOnDate(DateTime date) {
    return _workoutData.keys.any((key) => _isSameDay(key, date));
  }

  List<Map<String, dynamic>> _getWorkoutsForDate(DateTime date) {
    return _workoutData.entries
        .where((entry) => _isSameDay(entry.key, date))
        .expand((entry) => entry.value)
        .toList();
  }

  void _toggleWorkoutExpansion(String workoutId) {
    setState(() {
      _expandedWorkouts[workoutId] = !(_expandedWorkouts[workoutId] ?? false);
    });
  }

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 16.rh),
      child: Column(
        children: [
          // Calendar skeleton
          Container(
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ),
          SizedBox(height: 20.rh),
          // Workout cards skeleton
          ...List.generate(3, (index) => Container(
            margin: EdgeInsets.only(bottom: 12.rh),
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Container(
                  height: 20,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 16,
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          // Month/Year and Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_focusedDate),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  _buildNavButton(
                    icon: Icons.chevron_left_rounded,
                    onPressed: () {
                      final previousMonth = DateTime(_focusedDate.year, _focusedDate.month - 1);
                      _onPageChanged(previousMonth);
                    },
                  ),
                  SizedBox(width: 12.rw),
                  _buildNavButton(
                    icon: Icons.chevron_right_rounded,
                    onPressed: () {
                      final nextMonth = DateTime(_focusedDate.year, _focusedDate.month + 1);
                      _onPageChanged(nextMonth);
                    },
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.rh),
          // Calendar Grid
          _buildCalendarGrid(),
        ],
      ),
    );
  }

  Widget _buildNavButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final lastDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 0);
    // Convert ISO weekday (Mon=1..Sun=7) to Sunday-start index (Sun=0..Sat=6)
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    final dayHeaders = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    
    return Column(
      children: [
        Row(
          children: dayHeaders.map((day) => Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: 8),
        ...List.generate((daysInMonth + firstWeekday + 6) ~/ 7, (weekIndex) {
          return Row(
            children: List.generate(7, (dayIndex) {
              final dayNumber = weekIndex * 7 + dayIndex - firstWeekday + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return Expanded(child: Container(height: 40));
              }

              final date = DateTime(_focusedDate.year, _focusedDate.month, dayNumber);
              final isSelected = _selectedDate != null && _isSameDay(date, _selectedDate!);
              final hasWorkout = _hasWorkoutOnDate(date);
              
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onDateSelected(date),
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? const Color(0xFF4361ee) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          dayNumber.toString(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        if (hasWorkout && !isSelected)
                          Positioned(
                            bottom: 6,
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF38b000),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ],
    );
  }

  Widget _buildWorkoutSection() {
    final workouts = _selectedDate != null ? _getWorkoutsForDate(_selectedDate!) : [];
    final dateStr = _selectedDate != null 
        ? DateFormat('MMMM d, yyyy').format(_selectedDate!)
        : DateFormat('MMMM d, yyyy').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 16.rh),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Workout History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Workout list
        if (workouts.isEmpty)
          _buildEmptyState()
        else
          ...workouts.map((workout) => _buildWorkoutCard(workout)),
      ],
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    final workoutId = workout['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    // Calculate workout stats
    final exercises = workout['exercises'] as List<dynamic>? ?? [];
    final exerciseCount = exercises.length;
    
    // Calculate duration
    final workoutStartTime = (workout['workoutStartTime'] as Timestamp).toDate();
    final workoutEndTime = (workout['workoutEndTime'] as Timestamp).toDate();
    final duration = workoutEndTime.difference(workoutStartTime);
    final durationText = duration.inMinutes > 0 
        ? '${duration.inMinutes}m ${duration.inSeconds % 60}s'
        : '${duration.inSeconds}s';
    
    // Calculate total workout timing
    final totalNormalTime = workout['totalNormalTime'] ?? 0;
    final totalRestTime = workout['totalRestTime'] ?? 0;
    final totalPauseTime = workout['totalPauseTime'] ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: 16.rh),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleWorkoutExpansion(workoutId),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Workout header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('MMMM d, yyyy').format(workoutStartTime),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$exerciseCount exercises',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4361ee).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        durationText,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4895ef),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16.rh),
                
                // Workout stats
                Row(
                  children: [
                    Expanded(child: _buildStatCard(_formatVolume(workout['totalVolume']?.toDouble() ?? 0.0), 'Volume')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard('${workout['totalSets'] ?? 0}', 'Sets')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard('${workout['totalReps'] ?? 0}', 'Reps')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard('$exerciseCount', 'Exercises')),
                  ],
                ),
                
                SizedBox(height: 12.rh),
                
                // Workout timing stats
                Row(
                  children: [
                    Expanded(child: _buildTimingStat(Icons.timer, _formatTime(totalNormalTime), 'Work')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTimingStat(Icons.bedtime, _formatTime(totalRestTime), 'Rest')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTimingStat(Icons.pause, _formatTime(totalPauseTime), 'Pause')),
                  ],
                ),
                
                // Exercises list (always shown)
                if (exercises.isNotEmpty) ...[
                  SizedBox(height: 16.rh),
                  ...exercises.map((exercise) => _buildExerciseItem(exercise)),
                ],
                
                // Workout notes (if available)
                if (workout['workoutNotes'] != null && workout['workoutNotes'].toString().isNotEmpty) ...[
                  SizedBox(height: 16.rh),
                  Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.note_alt_outlined,
                              size: 16,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Workout Notes',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          workout['workoutNotes'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4361ee),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimingStat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFF4cc9f0),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4cc9f0),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseItem(Map<String, dynamic> exercise) {
    final name = exercise['name'] ?? 'Unknown Exercise';
    final muscle = exercise['muscle'] ?? 'Unknown';
    final sets = exercise['sets'] as List<dynamic>? ?? [];
    final notes = exercise['notes'] ?? '';
    final supersetId = exercise['supersetId'];
    final isSuperset = supersetId != null;
    
    // Calculate exercise stats
    
    // Calculate timing
    final normalTime = exercise['normalTime'] ?? 0;
    final restTime = exercise['restTime'] ?? 0;
    final pauseTime = exercise['pauseTime'] ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12.rh),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSuperset 
                      ? const Color(0xFFFF6B6B).withOpacity(0.2)
                      : const Color(0xFF4361ee).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    exercise['icon'] ?? '🏋️',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              SizedBox(width: 12.rw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (isSuperset)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B6B).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Superset',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFFF6B6B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      muscle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Exercise stats
          Row(
            children: [
              _buildExerciseStat(Icons.timer, _formatTime(normalTime), 'Work'),
              SizedBox(width: 12.rw),
              _buildExerciseStat(Icons.bedtime, _formatTime(restTime), 'Rest'),
              SizedBox(width: 12.rw),
              _buildExerciseStat(Icons.pause, _formatTime(pauseTime), 'Pause'),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Sets grid
          if (sets.isNotEmpty) ...[
            Text(
              'Sets',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: sets.asMap().entries.map((entry) {
                final index = entry.key;
                final set = entry.value;
                return _buildSetItem(set, index);
              }).toList(),
            ),
          ],
          
          // Notes
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                notes,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: const Color(0xFF4cc9f0),
        ),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildSetItem(Map<String, dynamic> set, int index) {
    // Get weight in kg from Firebase (standard unit) and convert to user's preferred unit
    final weightInKg = set['weight'] ?? 0.0;
    final weight = UnitConverter.convertWeightFromKg(weightInKg, _userWeightUnit);
    final reps = set['reps'] ?? 0;
    final setType = set['setType'] ?? 'normal';
    
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _getSetTypeColor(setType).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: _getSetTypeColor(setType),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getSetTypeLabel(setType),
              style: const TextStyle(
                fontSize: 8,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            UnitConverter.formatWeight(weight, _userWeightUnit),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Text(
            '$reps reps',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSetTypeColor(String setType) {
    switch (setType) {
      case 'warmup':
        return const Color(0xFFFFA726);
      case 'failure':
        return const Color(0xFFFF6B6B);
      case 'dropset':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF4361ee);
    }
  }

  String _getSetTypeLabel(String setType) {
    switch (setType) {
      case 'warmup':
        return 'W';
      case 'failure':
        return 'F';
      case 'dropset':
        return 'D';
      default:
        return 'N';
    }
  }

  String _formatVolume(double volume) {
    if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}k';
    }
    return volume.toInt().toString();
  }

  String _formatTime(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 40.rh, horizontal: 20.rw),
      child: Column(
        children: [
          Icon(
            Icons.fitness_center_outlined,
            size: 48,
            color: Colors.white.withOpacity(0.3),
          ),
          SizedBox(height: 16.rh),
          Text(
            'No workouts on this day',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start logging your workouts to see them here',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4361ee),
          labelColor: const Color(0xFF4361ee),
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 16,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.fitness_center, size: 20),
              text: 'Workouts',
            ),
            Tab(
              icon: Icon(Icons.restaurant, size: 20),
              text: 'Nutrition',
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background_1.png'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            // Workout History Tab
            _isLoading
                ? _buildSkeletonLoader()
                : SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 16.rh),
                    child: Column(
                      children: [
                        _buildCalendarHeader(),
                        SizedBox(height: 20.rh),
                        _buildWorkoutSection(),
                      ],
                    ),
                  ),
            // Nutrition History Tab
            NutritionHistoryScreen(),
          ],
        ),
      ),
    );
  }
} 