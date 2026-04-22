import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/unit_preference_service.dart';
import '../services/graph_cache_service.dart';
import '../features/extra/constants.dart';

class ExerciseProgressionGraph extends StatefulWidget {
  const ExerciseProgressionGraph({super.key});

  @override
  State<ExerciseProgressionGraph> createState() => _ExerciseProgressionGraphState();
}

class _ExerciseProgressionGraphState extends State<ExerciseProgressionGraph> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Map<String, List<OneRepMaxData>> _exerciseData = {};
  List<String> _exerciseNames = [];
  String? _selectedExercise;
  bool _isLoading = true;
  
  // Unit preferences
  String _userWeightUnit = 'kg';
  bool _isLoadingUnits = true;

  // Time range selection
  int _selectedRangeIndex = 1; // Default to 30D
  static const List<String> _rangeLabels = ['7D', '30D', '90D', 'All'];
  static const List<int> _rangeDays = [7, 30, 90, -1]; // -1 = all

  @override
  void initState() {
    super.initState();
    _loadUserUnitPreferences();
    _loadExerciseData();
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

  Future<void> _loadExerciseData() async {
    setState(() => _isLoading = true);
    
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Try to load from cache first
      final cachedData = await GraphCacheService.getCachedExerciseData();
      
      if (cachedData != null) {
        _loadFromCachedData(cachedData);
        setState(() => _isLoading = false);
        return;
      }
      
      // Cache miss or expired - fetch from Firebase
      await _fetchFromFirebase();
      
    } catch (e) {
      print('Error loading exercise data: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Load data from cached data
  void _loadFromCachedData(Map<String, List<Map<String, dynamic>>> cachedData) {
    final Map<String, List<OneRepMaxData>> exerciseData = {};
    
    for (var entry in cachedData.entries) {
      final exerciseName = entry.key;
      final dataList = entry.value;
      
      exerciseData[exerciseName] = dataList.map((item) {
        return OneRepMaxData(
          date: DateTime.parse(item['date'] as String),
          oneRepMax: (item['oneRepMax'] as num).toDouble(),
        );
      }).toList();
    }
    
    // Sort exercise names alphabetically
    final exerciseNames = exerciseData.keys.toList()..sort();
    
    setState(() {
      _exerciseData = exerciseData;
      _exerciseNames = exerciseNames;
      _selectedExercise = exerciseNames.isNotEmpty ? exerciseNames.first : null;
    });
  }

  /// Fetch data from Firebase and cache it
  Future<void> _fetchFromFirebase() async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Load workouts from last 90 days to support all time ranges
    final now = DateTime.now();
    final ninetyDaysAgo = now.subtract(const Duration(days: 89));
    
    final querySnapshot = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: userId)
        .where('workoutStartTime', isGreaterThanOrEqualTo: Timestamp.fromDate(ninetyDaysAgo))
        .orderBy('workoutStartTime', descending: false)
        .get();

    // Map to store max 1RM per exercise per day
    final Map<String, Map<String, double>> exerciseDailyMaxes = {};
    
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final workoutTime = (data['workoutStartTime'] as Timestamp).toDate();
      final dateKey = _formatDate(workoutTime);
      final exercises = data['exercises'] as List<dynamic>? ?? [];
      
      for (var exercise in exercises) {
        final exerciseName = exercise['name'] as String? ?? '';
        if (exerciseName.isEmpty) continue;
        
        final sets = exercise['sets'] as List<dynamic>? ?? [];
        double highestOneRepMax = 0.0;
        
        // Calculate 1RM for each set and find the highest for this session
        for (var set in sets) {
          final weight = (set['weight'] ?? 0.0).toDouble();
          final reps = set['reps'] as int? ?? 0;
          
          // Only calculate for meaningful sets (reps <= 10)
          if (weight > 0 && reps > 0 && reps <= 10) {
            // Brzycki formula: 1RM = weight / (1.0278 - 0.0278 × reps)
            final oneRepMax = weight / (1.0278 - 0.0278 * reps);
            if (oneRepMax > highestOneRepMax) {
              highestOneRepMax = oneRepMax;
            }
          }
        }
        
        // Store the max 1RM for this exercise on this day
        if (highestOneRepMax > 0) {
          if (!exerciseDailyMaxes.containsKey(exerciseName)) {
            exerciseDailyMaxes[exerciseName] = {};
          }
          
          // Keep only the highest 1RM for this day
          if (!exerciseDailyMaxes[exerciseName]!.containsKey(dateKey) ||
              exerciseDailyMaxes[exerciseName]![dateKey]! < highestOneRepMax) {
            exerciseDailyMaxes[exerciseName]![dateKey] = highestOneRepMax;
          }
        }
      }
    }

    // Convert to list format with dates
    final Map<String, List<OneRepMaxData>> exerciseData = {};
    final Map<String, List<Map<String, dynamic>>> cacheData = {};
    
    for (var exerciseEntry in exerciseDailyMaxes.entries) {
      final exerciseName = exerciseEntry.key;
      final dailyMaxes = exerciseEntry.value;
      
      exerciseData[exerciseName] = [];
      cacheData[exerciseName] = [];
      
      // Sort by date and convert to OneRepMaxData objects
      final sortedDates = dailyMaxes.keys.toList()..sort();
      for (var dateKey in sortedDates) {
        final date = DateTime.parse(dateKey);
        final oneRepMax = dailyMaxes[dateKey]!;
        
        exerciseData[exerciseName]!.add(OneRepMaxData(
          date: date,
          oneRepMax: oneRepMax,
        ));
        
        cacheData[exerciseName]!.add({
          'date': date.toIso8601String(),
          'oneRepMax': oneRepMax,
        });
      }
    }

    // Save to cache
    await GraphCacheService.saveCachedExerciseData(cacheData);

    // Sort exercise names alphabetically
    final exerciseNames = exerciseData.keys.toList()..sort();

    setState(() {
      _exerciseData = exerciseData;
      _exerciseNames = exerciseNames;
      _selectedExercise = exerciseNames.isNotEmpty ? exerciseNames.first : null;
      _isLoading = false;
    });
  }

  /// Refresh data manually (pull-to-refresh)
  Future<void> refreshData() async {
    await GraphCacheService.invalidateExerciseCache();
    await _loadExerciseData();
  }

  /// Filter data based on selected time range
  List<OneRepMaxData> _getFilteredData() {
    if (_selectedExercise == null) return [];
    final allData = _exerciseData[_selectedExercise!] ?? [];
    if (allData.isEmpty) return [];

    final days = _rangeDays[_selectedRangeIndex];
    if (days == -1) return allData; // "All" - return everything

    final cutoff = DateTime.now().subtract(Duration(days: days));
    return allData.where((d) => d.date.isAfter(cutoff) || d.date.isAtSameMomentAs(cutoff)).toList();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Convert kg to lbs
  double _kgToLbs(double kg) {
    return kg * 2.20462;
  }

  /// Convert weight to user's preferred unit
  double _convertToUserUnit(double weightInKg) {
    if (_userWeightUnit == 'lbs' || _userWeightUnit == 'lb') {
      return _kgToLbs(weightInKg);
    }
    return weightInKg;
  }

  /// Get the unit symbol for display
  String _getWeightUnitSymbol() {
    if (_userWeightUnit == 'lbs' || _userWeightUnit == 'lb') {
      return 'lbs';
    }
    return 'kg';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isLoadingUnits) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_exerciseNames.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildExerciseSelector(),
          SizedBox(height: 16.rh),
          SizedBox(
            height: 380,
            child: _buildProgressionChart(),
          ),
          SizedBox(height: 16.rh),
          _buildInsights(),
          SizedBox(height: 16.rh),
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
              Icons.fitness_center_rounded,
              size: 48,
              color: const Color(0xFF4361ee).withOpacity(0.5),
            ),
            SizedBox(height: 16.rh),
            const Text(
              'No Exercise Data',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start logging workouts to see your\n1RM progression charts',
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

  Widget _buildExerciseSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.rw, vertical: 16.rh),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedExercise,
          isExpanded: true,
          dropdownColor: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(16),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          icon: const Icon(Icons.expand_more, color: Color(0xFF94a3b8), size: 24),
          selectedItemBuilder: (context) {
            return _exerciseNames.map((name) => _buildSelectorContent(name)).toList();
          },
          items: _exerciseNames.map((exercise) {
            return DropdownMenuItem<String>(
              value: exercise,
              child: Text(exercise),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedExercise = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildSelectorContent(String exerciseName) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.fitness_center, color: Color(0xFF60a5fa), size: 22),
        ),
        SizedBox(width: 12.rw),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tracking Exercise',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              Text(
                exerciseName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Time range selector pills
  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_rangeLabels.length, (index) {
          final isSelected = _selectedRangeIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedRangeIndex = index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 14.rw, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4361ee) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _rangeLabels[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildProgressionChart() {
    final data = _getFilteredData();

    if (data.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart_rounded, size: 40, color: Colors.white.withOpacity(0.3)),
              SizedBox(height: 12.rh),
              Text(
                'No data for this time range',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Date-based X-axis: use days offset from the first data point
    final firstDate = data.first.date;
    final lastDate = data.last.date;
    final totalDaySpan = lastDate.difference(firstDate).inDays.toDouble();

    // For single data point, we still want to show it nicely
    final isSinglePoint = data.length == 1;

    // Build spots using actual date positions
    final spots = data.map((d) {
      final dayOffset = d.date.difference(firstDate).inDays.toDouble();
      return FlSpot(dayOffset, _convertToUserUnit(d.oneRepMax));
    }).toList();

    final minY = _getMinY(data);
    final maxY = _getMaxY(data);
    final yRange = maxY - minY;
    final gridInterval = yRange > 0 ? yRange / 5 : 10.0;

    // Personal best value
    final personalBest = _convertToUserUnit(
      data.map((d) => d.oneRepMax).reduce((a, b) => a > b ? a : b),
    );

    // Chart X bounds
    final chartMinX = isSinglePoint ? -1.0 : 0.0;
    final chartMaxX = isSinglePoint ? 1.0 : (totalDaySpan == 0 ? 1.0 : totalDaySpan);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.rw, 16.rh, 16.rw, 12.rh),
        child: Column(
          children: [
            // Header row: title + time range selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    '1RM Progression',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildTimeRangeSelector(),
              ],
            ),
            SizedBox(height: 14.rh),

            // Chart
            Expanded(
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    // Personal best reference line (dashed)
                    if (!isSinglePoint)
                      LineChartBarData(
                        spots: [
                          FlSpot(chartMinX, personalBest),
                          FlSpot(chartMaxX, personalBest),
                        ],
                        isCurved: false,
                        color: const Color(0xFFf72585).withOpacity(0.4),
                        barWidth: 1,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                        dashArray: [6, 4],
                      ),
                    // Main 1RM line
                    LineChartBarData(
                      spots: spots,
                      isCurved: data.length > 2,
                      curveSmoothness: 0.25,
                      color: const Color(0xFF4361ee),
                      barWidth: 3.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final isLast = index == data.length - 1;
                          return FlDotCirclePainter(
                            radius: isLast ? 6 : 4,
                            color: const Color(0xFF4361ee),
                            strokeWidth: isLast ? 3 : 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4361ee).withOpacity(0.25),
                            const Color(0xFF4361ee).withOpacity(0.02),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  minX: chartMinX,
                  maxX: chartMaxX,
                  minY: minY,
                  maxY: maxY,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: _getBottomInterval(totalDaySpan, isSinglePoint),
                        getTitlesWidget: (value, meta) {
                          return _buildBottomTitle(value, data, firstDate, isSinglePoint, chartMinX, chartMaxX);
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: gridInterval,
                        getTitlesWidget: (value, meta) {
                          // Skip labels at the very edges to avoid clipping
                          if (value == minY || value == maxY) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              value.toStringAsFixed(0),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: false,
                    horizontalInterval: gridInterval,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.white.withOpacity(0.06),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipRoundedRadius: 12,
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (List<LineBarSpot> spots) {
                        return spots.map((spot) {
                          // Skip the PB reference line tooltip
                          if (!isSinglePoint && spot.barIndex == 0) return null;

                          // Find the matching data point by day offset
                          final dayOffset = spot.x;
                          OneRepMaxData? matchedData;
                          int matchedIndex = -1;
                          for (int i = 0; i < data.length; i++) {
                            final d = data[i];
                            if (d.date.difference(firstDate).inDays.toDouble() == dayOffset) {
                              matchedData = d;
                              matchedIndex = i;
                              break;
                            }
                          }

                          if (matchedData == null) return null;

                          final date = matchedData.date;
                          final value = spot.y;
                          final unit = _getWeightUnitSymbol();

                          // Calculate change from previous session
                          String changeText = '';
                          if (matchedIndex > 0) {
                            final prevValue = _convertToUserUnit(data[matchedIndex - 1].oneRepMax);
                            final diff = value - prevValue;
                            if (diff != 0) {
                              final sign = diff > 0 ? '+' : '';
                              changeText = '\n$sign${diff.toStringAsFixed(1)} $unit';
                            }
                          }

                          return LineTooltipItem(
                            '${_getAbbreviatedMonth(date.month)} ${date.day}\n${value.toStringAsFixed(1)} $unit$changeText',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              height: 1.4,
                            ),
                            children: changeText.isNotEmpty
                                ? [
                                    TextSpan(
                                      text: '',
                                      style: TextStyle(
                                        color: changeText.contains('+')
                                            ? const Color(0xFF4ade80)
                                            : const Color(0xFFf87171),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ]
                                : null,
                          );
                        }).toList();
                      },
                    ),
                    getTouchedSpotIndicator: (barData, spotIndexes) {
                      return spotIndexes.map((index) {
                        return TouchedSpotIndicatorData(
                          FlLine(
                            color: const Color(0xFF4361ee).withOpacity(0.3),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ),
                          FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 7,
                                color: const Color(0xFF4361ee),
                                strokeWidth: 3,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Legend row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(const Color(0xFF4361ee), '1RM'),
                if (!isSinglePoint) ...[
                  SizedBox(width: 20.rw),
                  _buildLegendItem(const Color(0xFFf72585).withOpacity(0.6), 'Personal Best'),
                ],
              ],
            ),

            // Single data point hint
            if (isSinglePoint) ...[
              const SizedBox(height: 8),
              Text(
                'Log more sessions to see your progression trend',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Calculate bottom axis interval based on total day span
  double _getBottomInterval(double totalDaySpan, bool isSinglePoint) {
    if (isSinglePoint) return 1;
    if (totalDaySpan <= 0) return 1;
    if (totalDaySpan <= 7) return 1;
    if (totalDaySpan <= 14) return 2;
    if (totalDaySpan <= 30) return 5;
    if (totalDaySpan <= 60) return 10;
    return 15;
  }

  /// Build bottom axis title widget
  Widget _buildBottomTitle(double value, List<OneRepMaxData> data, DateTime firstDate, bool isSinglePoint, double minX, double maxX) {
    if (isSinglePoint) {
      if (value == 0) {
        final date = data.first.date;
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${_getAbbreviatedMonth(date.month)} ${date.day}',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    // Only show labels at exact interval points, skip edges that clip
    if (value < minX || value > maxX) return const SizedBox.shrink();

    final date = firstDate.add(Duration(days: value.round()));
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '${_getAbbreviatedMonth(date.month)} ${date.day}',
        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildInsights() {
    if (_selectedExercise == null) return const SizedBox.shrink();

    final data = _getFilteredData();
    if (data.isEmpty) return const SizedBox.shrink();

    final currentMax = _convertToUserUnit(data.last.oneRepMax);
    final startMax = _convertToUserUnit(data.first.oneRepMax);
    final improvementPercent = startMax > 0 ? ((currentMax - startMax) / startMax) * 100 : 0.0;
    final allTimeMax = _convertToUserUnit(data.map((d) => d.oneRepMax).reduce((a, b) => a > b ? a : b));
    final unit = _getWeightUnitSymbol();

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
          const Text(
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
                  'Current 1RM',
                  '${currentMax.toStringAsFixed(0)} $unit',
                  const Color(0xFF4361ee),
                  Icons.fitness_center,
                ),
              ),
              SizedBox(width: 12.rw),
              Expanded(
                child: _buildInsightCard(
                  'Personal Best',
                  '${allTimeMax.toStringAsFixed(0)} $unit',
                  const Color(0xFFf72585),
                  Icons.emoji_events_rounded,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.rh),
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  'Progress',
                  '${improvementPercent >= 0 ? '+' : ''}${improvementPercent.toStringAsFixed(0)}%',
                  improvementPercent >= 0 ? const Color(0xFF38b000) : const Color(0xFFf72585),
                  improvementPercent >= 0 ? Icons.trending_up : Icons.trending_down,
                ),
              ),
              SizedBox(width: 12.rw),
              Expanded(
                child: _buildInsightCard(
                  'Sessions',
                  '${data.length}',
                  const Color(0xFF4cc9f0),
                  Icons.calendar_today,
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
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
            const Color(0xFF4361ee).withOpacity(0.1),
            const Color(0xFF4895ef).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4361ee).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4361ee).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
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
                const Text(
                  'More Analytics Coming Soon',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Volume tracking, rep trends, and detailed exercise comparisons',
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

  double _getMinY(List<OneRepMaxData> data) {
    final minValue = data.map((d) => _convertToUserUnit(d.oneRepMax)).reduce((a, b) => a < b ? a : b);
    final maxValue = data.map((d) => _convertToUserUnit(d.oneRepMax)).reduce((a, b) => a > b ? a : b);
    // If all values are the same, provide reasonable padding
    if (minValue == maxValue) {
      return (minValue - 10).clamp(0, double.infinity).floorToDouble();
    }
    return (minValue * 0.9).floorToDouble();
  }

  double _getMaxY(List<OneRepMaxData> data) {
    final minValue = data.map((d) => _convertToUserUnit(d.oneRepMax)).reduce((a, b) => a < b ? a : b);
    final maxValue = data.map((d) => _convertToUserUnit(d.oneRepMax)).reduce((a, b) => a > b ? a : b);
    // If all values are the same, provide reasonable padding
    if (minValue == maxValue) {
      return (maxValue + 10).ceilToDouble();
    }
    return (maxValue * 1.1).ceilToDouble();
  }

  String _getAbbreviatedMonth(int month) {
    return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
  }
}

class OneRepMaxData {
  final DateTime date;
  final double oneRepMax;

  OneRepMaxData({required this.date, required this.oneRepMax});
}
