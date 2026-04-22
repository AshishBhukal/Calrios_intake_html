import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../services/graph_cache_service.dart';
import '../services/unit_preference_service.dart';
import '../features/extra/constants.dart';

class CaloriesVsGoalChart extends StatefulWidget {
  const CaloriesVsGoalChart({super.key});

  @override
  State<CaloriesVsGoalChart> createState() => _CaloriesVsGoalChartState();
}

class _CaloriesVsGoalChartState extends State<CaloriesVsGoalChart> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<CaloriesData> _caloriesData = [];
  double _calorieGoal = 2000.0;
  bool _isLoading = true;
  String _energyUnit = 'kcal';

  @override
  void initState() {
    super.initState();
    _loadCaloriesData();
    _loadEnergyUnit();
  }

  Future<void> _loadEnergyUnit() async {
    try {
      final unit = await UnitPreferenceService.getEnergyUnit();
      if (mounted) setState(() => _energyUnit = unit);
    } catch (_) {}
  }

  Future<void> _loadCaloriesData() async {
    setState(() => _isLoading = true);
    
    try {
      // Try to load from cache first
      final cachedData = await GraphCacheService.getCachedCaloriesData();
      
      if (cachedData != null) {
        print('📦 Loading calories data from cache');
        _loadFromCachedData(cachedData);
        setState(() => _isLoading = false);
        return;
      }
      
      // Cache miss or expired - fetch from Firebase
      print('🔄 Fetching calories data from Firebase');
      await _fetchFromFirebase();
      
    } catch (e) {
      print('Error loading calories data: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Load data from cached data
  void _loadFromCachedData(Map<String, dynamic> cachedData) {
    final goal = (cachedData['goal'] as num?)?.toDouble() ?? 2000.0;
    final dataList = cachedData['data'] as List<dynamic>;
    
    final List<CaloriesData> caloriesData = dataList.map((item) {
      return CaloriesData(
        date: DateTime.parse(item['date'] as String),
        calories: (item['calories'] as num).toDouble(),
      );
    }).toList();
    
    setState(() {
      _calorieGoal = goal;
      _caloriesData = caloriesData;
    });
  }

  /// Fetch data from Firebase and cache it
  Future<void> _fetchFromFirebase() async {
    // Load user goals
    final userData = await FirebaseService.getUserData();
    if (userData != null && userData['goals'] != null) {
      setState(() {
        _calorieGoal = (userData['goals']['calories'] ?? 2000).toDouble();
      });
    }

    // Load daily totals for the last 30 days
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(Duration(days: 30));
    
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final querySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('daily_totals')
        .where('date', isGreaterThanOrEqualTo: _formatDate(thirtyDaysAgo))
        .where('date', isLessThanOrEqualTo: _formatDate(now))
        .orderBy('date', descending: false)
        .get();

    final List<CaloriesData> caloriesData = [];
    final List<Map<String, dynamic>> cacheData = [];
    
    // Create a map of existing data
    final Map<String, double> existingData = {};
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final date = data['date'] as String;
      final calories = (data['calories'] ?? 0).toDouble();
      existingData[date] = calories;
    }

    // Fill in all 30 days with data or 0
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: 29 - i));
      final dateKey = _formatDate(date);
      final calories = existingData[dateKey] ?? 0.0;
      
      caloriesData.add(CaloriesData(
        date: date,
        calories: calories,
      ));
      
      cacheData.add({
        'date': date.toIso8601String(),
        'calories': calories,
      });
    }

    // Save to cache
    await GraphCacheService.saveCachedCaloriesData(cacheData, _calorieGoal);

    setState(() {
      _caloriesData = caloriesData;
      _isLoading = false;
    });
  }

  /// Refresh data manually (pull-to-refresh)
  Future<void> refreshData() async {
    await GraphCacheService.invalidateCaloriesCache();
    await _loadCaloriesData();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_caloriesData.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Chart
          SizedBox(
            height: 350,
            child: _buildCaloriesChart(),
          ),
          SizedBox(height: 16.rh),
          
          // Insights
          _buildInsights(),
          SizedBox(height: 16.rh),
          
          // Coming Soon Section
          _buildComingSoonSection(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              size: 48,
              color: const Color(0xFF4361ee).withOpacity(0.5),
            ),
            SizedBox(height: 16.rh),
            Text(
              'No Calories Data',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start logging your meals to see your calories vs goal chart',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaloriesChart() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20.r),
        child: Column(
          children: [
            // Chart Header
            Text(
              'Calories vs Goal (Last 30 Days)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16.rh),

            // Chart Container
            Expanded(
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    // Goal line (flat)
                    LineChartBarData(
                      spots: _caloriesData.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), _calorieGoal);
                      }).toList(),
                      isCurved: false,
                      color: Color(0xFF4cc9f0), // Cyan for goal
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                    // Intake line (fluctuating)
                    LineChartBarData(
                      spots: _caloriesData.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.calories);
                      }).toList(),
                      isCurved: true,
                      color: Color(0xFF4361ee), // Blue for intake
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Color(0xFF4361ee),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Color(0xFF4361ee).withOpacity(0.1),
                      ),
                    ),
                  ],
                  minX: 0,
                  maxX: (_caloriesData.length - 1).toDouble(),
                  minY: 0,
                  maxY: _getMaxY(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < _caloriesData.length) {
                            final date = _caloriesData[value.toInt()].date;
                            return Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                '${_getAbbreviatedMonth(date.month)} ${date.day}',
                                style: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            );
                          }
                          return Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Text(
                            value.toStringAsFixed(0),
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: false,
                    horizontalInterval: _getMaxY() / 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.white.withOpacity(0.1),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (List<LineBarSpot> spots) {
                        return spots.map((spot) {
                          if (spot.barIndex == 0) {
                            // Goal line
                            return LineTooltipItem(
                              'Goal: ${spot.y.toStringAsFixed(0)} $_energyUnit',
                              TextStyle(color: Color(0xFF4cc9f0), fontWeight: FontWeight.bold),
                            );
                          } else {
                            // Intake line
                            if (spot.x.toInt() < _caloriesData.length) {
                              final date = _caloriesData[spot.x.toInt()].date;
                              final deficit = _calorieGoal - spot.y;
                              final status = deficit > 0 ? 'Deficit' : 'Surplus';
                              return LineTooltipItem(
                                '${_getAbbreviatedMonth(date.month)} ${date.day}\nIntake: ${spot.y.toStringAsFixed(0)} $_energyUnit\n$status: ${deficit.abs().toStringAsFixed(0)} $_energyUnit',
                                TextStyle(color: Color(0xFF4361ee), fontWeight: FontWeight.bold),
                              );
                            }
                            return LineTooltipItem(
                              'Intake: ${spot.y.toStringAsFixed(0)} $_energyUnit',
                              TextStyle(color: Color(0xFF4361ee), fontWeight: FontWeight.bold),
                            );
                          }
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.rh),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(Color(0xFF4cc9f0), 'Goal'),
                SizedBox(width: 24.rw),
                _buildLegendItem(Color(0xFF4361ee), 'Intake'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildInsights() {
    final surplusDays = _caloriesData.where((data) => data.calories > _calorieGoal).length;
    final deficitDays = _caloriesData.where((data) => data.calories < _calorieGoal).length;
    
    final avgIntake = _caloriesData.map((data) => data.calories).reduce((a, b) => a + b) / _caloriesData.length;
    final avgDeficit = _calorieGoal - avgIntake;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insights',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12.rh),
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  'Surplus Days',
                  surplusDays.toString(),
                  Color(0xFFf72585),
                  Icons.trending_up,
                ),
              ),
              SizedBox(width: 12.rw),
              Expanded(
                child: _buildInsightCard(
                  'Deficit Days',
                  deficitDays.toString(),
                  Color(0xFF38b000),
                  Icons.trending_down,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.rh),
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  'Avg Intake',
                  '${avgIntake.toStringAsFixed(0)} $_energyUnit',
                  Color(0xFF4361ee),
                  Icons.restaurant,
                ),
              ),
              SizedBox(width: 12.rw),
              Expanded(
                child: _buildInsightCard(
                  'Avg ${avgDeficit > 0 ? 'Deficit' : 'Surplus'}',
                  '${avgDeficit.abs().toStringAsFixed(0)} $_energyUnit',
                  avgDeficit > 0 ? Color(0xFF38b000) : Color(0xFFf72585),
                  avgDeficit > 0 ? Icons.remove : Icons.add,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonSection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 12.rh),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF4361ee).withOpacity(0.1),
            Color(0xFF4895ef).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFF4361ee).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF4361ee).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.trending_up_rounded,
              color: Color(0xFF4361ee),
              size: 20,
            ),
          ),
          SizedBox(width: 12.rw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'More Health Analytics Coming Soon',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Sugar tracking, macro trends, and detailed nutrition insights',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white.withOpacity(0.5),
            size: 16,
          ),
        ],
      ),
    );
  }

  double _getMaxY() {
    final maxIntake = _caloriesData.map((data) => data.calories).reduce((a, b) => a > b ? a : b);
    return (maxIntake > _calorieGoal ? maxIntake : _calorieGoal) * 1.1;
  }

  String _getAbbreviatedMonth(int month) {
    return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
  }
}

class CaloriesData {
  final DateTime date;
  final double calories;

  CaloriesData({required this.date, required this.calories});
}

