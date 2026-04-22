import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../features/extra/constants.dart';
import '../services/unit_preference_service.dart';

class NutritionHistoryScreen extends StatefulWidget {
  const NutritionHistoryScreen({super.key});

  @override
  State<NutritionHistoryScreen> createState() => _NutritionHistoryScreenState();
}

class _NutritionHistoryScreenState extends State<NutritionHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  DateTime _focusedDate = DateTime.now();
  DateTime? _selectedDate;
  Map<DateTime, Map<String, dynamic>> _nutritionData = {};
  bool _isLoading = true;
  String _energyUnit = 'kcal';
  
  // Goals (can be made configurable later)
  final Map<String, double> _goals = {
    'calories': 2500.0,
    'protein': 150.0,
    'carbs': 250.0,
    'fat': 80.0,
    'fiber': 25.0,
  };

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadNutritionData();
    _loadEnergyUnit();
  }

  Future<void> _loadEnergyUnit() async {
    try {
      final unit = await UnitPreferenceService.getEnergyUnit();
      if (mounted) setState(() => _energyUnit = unit);
    } catch (_) {}
  }

  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan.txt ID f_7a8b9c
  Future<void> _loadNutritionData() async {
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

      // Load daily totals for the month
      final dailyTotalsQuery = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('daily_totals')
          .where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(firstDayOfMonth))
          .where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(lastDayOfMonth))
          .get();

      // Load food log entries for the month
      final foodLogQuery = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('food_log')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(lastDayOfMonth))
          .orderBy('timestamp', descending: true)
          .get();

      // Load water intake for the month
      final waterQuery = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('water_intake')
          .where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(firstDayOfMonth))
          .where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(lastDayOfMonth))
          .get();

      final Map<DateTime, Map<String, dynamic>> nutritionData = {};
      
      // Process daily totals
      for (var doc in dailyTotalsQuery.docs) {
        final data = doc.data();
        final date = DateTime.parse(data['date']);
        
        nutritionData[date] = {
          'dailyTotals': data,
          'foodLog': [],
          'waterIntake': 0.0,
          'waterGoal': 2000.0,
        };
      }

      // Process food log entries
      for (var doc in foodLogQuery.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
        
        if (!nutritionData.containsKey(date)) {
          nutritionData[date] = {
            'dailyTotals': {
              'calories': 0,
              'protein': 0.0,
              'carbs': 0.0,
              'fat': 0.0,
              'fiber': 0.0,
            },
            'foodLog': [],
            'waterIntake': 0.0,
            'waterGoal': 2000.0,
          };
        }
        
        nutritionData[date]!['foodLog'].add(data);
      }

      // Process water intake
      for (var doc in waterQuery.docs) {
        final data = doc.data();
        final date = DateTime.parse(data['date']);
        
        if (!nutritionData.containsKey(date)) {
          nutritionData[date] = {
            'dailyTotals': {
              'calories': 0,
              'protein': 0.0,
              'carbs': 0.0,
              'fat': 0.0,
              'fiber': 0.0,
            },
            'foodLog': [],
            'waterIntake': 0.0,
            'waterGoal': 2000.0,
          };
        }
        
        nutritionData[date]!['waterIntake'] = data['waterIntake'] ?? 0.0;
        nutritionData[date]!['waterGoal'] = data['waterGoal'] ?? 2000.0;
      }

      setState(() {
        _nutritionData = nutritionData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading nutrition data: $e');
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
    _loadNutritionData();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _hasDataOnDate(DateTime date) {
    return _nutritionData.keys.any((key) => _isSameDay(key, date));
  }

  Map<String, dynamic>? _getDataForDate(DateTime date) {
    return _nutritionData.entries
        .where((entry) => _isSameDay(entry.key, date))
        .map((entry) => entry.value)
        .firstOrNull;
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: EdgeInsets.all(12.r),
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
                  const SizedBox(width: 8),
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
          SizedBox(height: 12.rh),
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
              padding: const EdgeInsets.symmetric(vertical: 6),
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
        const SizedBox(height: 6),
        ...List.generate((daysInMonth + firstWeekday + 6) ~/ 7, (weekIndex) {
          return Row(
            children: List.generate(7, (dayIndex) {
              final dayNumber = weekIndex * 7 + dayIndex - firstWeekday + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return Expanded(child: Container(height: 36));
              }

              final date = DateTime(_focusedDate.year, _focusedDate.month, dayNumber);
              final isSelected = _selectedDate != null && _isSameDay(date, _selectedDate!);
              final hasData = _hasDataOnDate(date);
              
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onDateSelected(date),
                  child: Container(
                    height: 36,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? const Color(0xFF4361ee) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
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
                        if (hasData && !isSelected)
                          Positioned(
                            bottom: 4,
                            child: Container(
                              width: 4,
                              height: 4,
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

  Widget _buildNutritionSection() {
    final data = _selectedDate != null ? _getDataForDate(_selectedDate!) : null;
    final dateStr = _selectedDate != null 
        ? DateFormat('MMMM d, yyyy').format(_selectedDate!)
        : DateFormat('MMMM d, yyyy').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nutrition History',
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
        // Content
        if (data == null)
          _buildEmptyState()
        else
          Column(
            children: [
              _buildStatsGrid(data),
              SizedBox(height: 12.rh),
              _buildFoodLog(data),
              SizedBox(height: 12.rh),
              _buildWaterSection(data),
            ],
          ),
      ],
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic>? data) {
    if (data == null) {
      return _buildEmptyState();
    }

    final dailyTotals = data['dailyTotals'] as Map<String, dynamic>;
    final calories = (dailyTotals['calories'] ?? 0).toDouble();
    final protein = (dailyTotals['protein'] ?? 0).toDouble();
    final carbs = (dailyTotals['carbs'] ?? 0).toDouble();
    final fat = (dailyTotals['fat'] ?? 0).toDouble();

    return Row(
      children: [
        Expanded(child: _buildStatCard('🔥', 'CAL', calories.toInt(), _goals['calories']!.toInt(), _energyUnit)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard('💪', 'PRO', protein.toInt(), _goals['protein']!.toInt(), 'g')),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard('🍞', 'CARB', carbs.toInt(), _goals['carbs']!.toInt(), 'g')),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard('🥑', 'FAT', fat.toInt(), _goals['fat']!.toInt(), 'g')),
      ],
    );
  }

  Widget _buildStatCard(String icon, String label, int current, int goal, String unit) {
    final percentage = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '$current',
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
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4361ee)),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildFoodLog(Map<String, dynamic>? data) {
    if (data == null) {
      return _buildEmptyState();
    }

    final foodLog = data['foodLog'] as List<dynamic>;
    
    if (foodLog.isEmpty) {
      return _buildEmptyState();
    }

    // Show all food in a single "Food Log" section
    return _buildFoodLogCard(foodLog);
  }

  Widget _buildFoodLogCard(List<dynamic> foodLog) {
    // Calculate total nutrition for all food
    int totalCalories = 0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;

    for (final foodEntry in foodLog) {
      final food = foodEntry['food'] as Map<String, dynamic>;
      totalCalories += (food['calories'] ?? 0) as int;
      totalProtein += (food['protein'] ?? 0.0).toDouble();
      totalCarbs += (food['carbs'] ?? 0.0).toDouble();
      totalFat += (food['fat'] ?? 0.0).toDouble();
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.rh),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food log header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Food Log',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4361ee).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalCalories cal',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4895ef),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Nutrition stats
            Row(
              children: [
                Expanded(child: _buildNutritionStat('${totalProtein.toInt()}g', 'P')),
                const SizedBox(width: 6),
                Expanded(child: _buildNutritionStat('${totalCarbs.toInt()}g', 'C')),
                const SizedBox(width: 6),
                Expanded(child: _buildNutritionStat('${totalFat.toInt()}g', 'F')),
                const SizedBox(width: 6),
                Expanded(child: _buildNutritionStat('${foodLog.length}', 'Items')),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Food items
            ...foodLog.map((foodEntry) => _buildFoodItem(foodEntry)),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4361ee),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItem(Map<String, dynamic> foodEntry) {
    final food = foodEntry['food'] as Map<String, dynamic>;
    final name = food['name'] ?? 'Unknown Food';
    final icon = food['icon'] ?? '🍽️';
    final calories = food['calories'] ?? 0;
    final protein = food['protein'] ?? 0.0;
    final carbs = food['carbs'] ?? 0.0;
    final fat = food['fat'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF4361ee).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                icon,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$calories cal',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          _buildCompactNutritionDetails(protein, carbs, fat),
        ],
      ),
    );
  }

  Widget _buildCompactNutritionDetails(double protein, double carbs, double fat) {
    return Row(
      children: [
        _buildCompactNutritionItem('${protein.toInt()}g', 'P'),
        const SizedBox(width: 6),
        _buildCompactNutritionItem('${carbs.toInt()}g', 'C'),
        const SizedBox(width: 6),
        _buildCompactNutritionItem('${fat.toInt()}g', 'F'),
      ],
    );
  }

  Widget _buildCompactNutritionItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }


  Widget _buildWaterSection(Map<String, dynamic>? data) {
    if (data == null) {
      return _buildEmptyState();
    }

    final waterIntake = (data['waterIntake'] ?? 0.0).toDouble();
    final waterGoal = (data['waterGoal'] ?? 2000.0).toDouble();
    final percentage = waterGoal > 0 ? (waterIntake / waterGoal).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 12.rh),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Water header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Water Intake',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4cc9f0).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(percentage * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4cc9f0),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Water stats
            Row(
              children: [
                Expanded(child: _buildWaterStat('${(waterIntake / 1000).toStringAsFixed(1)}L', 'Consumed')),
                const SizedBox(width: 6),
                Expanded(child: _buildWaterStat('${(waterGoal / 1000).toStringAsFixed(1)}L', 'Goal')),
                const SizedBox(width: 6),
                Expanded(child: _buildWaterStat('${(waterIntake / 250).toInt()}', 'Glasses')),
                const SizedBox(width: 6),
                Expanded(child: _buildWaterStat('${((waterGoal - waterIntake) / 1000).toStringAsFixed(1)}L', 'Remaining')),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Water progress bar
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4cc9f0)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4cc9f0),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20.rh, horizontal: 20.rw),
      child: Column(
        children: [
          Icon(
            Icons.restaurant_outlined,
            size: 40,
            color: Colors.white.withOpacity(0.3),
          ),
          SizedBox(height: 12.rh),
          Text(
            'No nutrition data for this day',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start logging your meals to see them here',
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
          'Nutrition History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 12.rh),
                child: Column(
                  children: [
                    _buildCalendarHeader(),
                    SizedBox(height: 12.rh),
                    _buildNutritionSection(),
                  ],
                ),
              ),
      ),
    );
  }
}

