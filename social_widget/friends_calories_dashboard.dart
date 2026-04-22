import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/social_calculator_service.dart';
import '../services/calorie_reaction_service.dart';
import '../features/extra/constants.dart';
import '../my_account_widgets/add_friends.dart';
import 'friend_calorie_card.dart';
import 'reactions_received_badge.dart';
import 'reactions_detail_sheet.dart';

class FriendsCaloriesDashboard extends StatefulWidget {
  const FriendsCaloriesDashboard({super.key});

  @override
  State<FriendsCaloriesDashboard> createState() =>
      _FriendsCaloriesDashboardState();
}

class _FriendsCaloriesDashboardState extends State<FriendsCaloriesDashboard> {
  final SocialCalculatorService _calculatorService =
      SocialCalculatorService();
  final CalorieReactionService _reactionService = CalorieReactionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _selectedWeek = 'current';
  List<FriendWeeklyData> _friendsData = [];
  WeeklySummary? _userWeeklySummary;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  // Reactions data
  List<CalorieReaction> _receivedReactions = [];
  Map<String, String> _givenReactions = {}; // userId -> emoji

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _currentWeekKey {
    final now = DateTime.now();
    if (_selectedWeek == 'last') {
      return _calculatorService
          .getWeekKey(now.subtract(const Duration(days: 7)));
    }
    return _calculatorService.getWeekKey(now);
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final weekKey = _currentWeekKey;
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Load friends data, user summary, and reactions in parallel
      final results = await Future.wait([
        _calculatorService.getFriendsWeeklyData(weekKey),
        _calculatorService.getUserWeeklyAverage(userId, weekKey),
        _reactionService.getReceivedReactions(userId, weekKey),
        _reactionService.getAllGivenReactions(weekKey),
      ]);

      if (!mounted) return;

      setState(() {
        _friendsData = results[0] as List<FriendWeeklyData>;
        _userWeeklySummary = results[1] as WeeklySummary;
        _receivedReactions = results[2] as List<CalorieReaction>;
        _givenReactions = results[3] as Map<String, String>;
        _isLoading = false;
        _hasError = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('Error loading friends calories data: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load data. Please try again.';
      });
    }
  }

  void _onReactionChanged(String friendId, String emoji) {
    setState(() {
      _givenReactions[friendId] = emoji;
    });
  }

  void _showReactionsDetail() {
    ReactionsDetailSheet.show(context, _receivedReactions);
  }

  void _onWeekChanged(String? value) {
    if (value != null && value != _selectedWeek) {
      setState(() => _selectedWeek = value);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      return const Center(
        child: Text(
          'User not logged in',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    if (_isLoading) {
      return _buildLoadingSkeleton();
    }

    if (_hasError) {
      return _buildErrorView();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF4361ee),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.rw),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildWeekSelector(),
            SizedBox(height: 16.rh),
            if (_userWeeklySummary != null) _buildUserHeroCard(),
            SizedBox(height: 40.rh),
            const Text(
              'Friends Activity',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 16.rh),
            ..._buildFriendsList(userId),
            SizedBox(height: 100.rh),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.0.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16.rh),
            Text(
              _errorMessage ?? 'Something went wrong',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.rh),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4361ee),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: 24.rw,
                  vertical: 12.rh,
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekSelector() {
    final weekKey = _currentWeekKey;
    final start = _calculatorService.getWeekStartDate(weekKey);
    final end = _calculatorService.getWeekEndDate(weekKey);
    final rangeText =
        '${DateFormat.MMM().format(start)} ${start.day} - ${end.day}';
    final label =
        _selectedWeek == 'current' ? 'This Week' : 'Last Week';

    return Semantics(
      label: '$label, $rangeText. Tap to change week.',
      button: true,
      child: GestureDetector(
        onTap: () => _showWeekDropdown(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label ($rangeText)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              color: Colors.white.withValues(alpha: 0.7),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showWeekDropdown(BuildContext context) {
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.rh),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Current Week',
                    style: TextStyle(color: Colors.white)),
                trailing: _selectedWeek == 'current'
                    ? const Icon(Icons.check, color: Color(0xFF3b82f6))
                    : null,
                onTap: () => Navigator.pop(context, 'current'),
              ),
              ListTile(
                title: const Text('Last Week',
                    style: TextStyle(color: Colors.white)),
                trailing: _selectedWeek == 'last'
                    ? const Icon(Icons.check, color: Color(0xFF3b82f6))
                    : null,
                onTap: () => Navigator.pop(context, 'last'),
              ),
            ],
          ),
        ),
      ),
    ).then((value) {
      if (value != null) _onWeekChanged(value);
    });
  }

  Widget _buildUserHeroCard() {
    if (_userWeeklySummary == null) return const SizedBox.shrink();

    final avgCalories = _userWeeklySummary!.avgCalories.round();
    final daysLogged = _userWeeklySummary!.daysLogged;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3b82f6), Color(0xFF22d3ee)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3b82f6).withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Decorative flame icon
              Positioned(
                top: -8,
                right: -8,
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: 0.2,
                    child: const Icon(
                      Icons.local_fire_department,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR WEEKLY AVERAGE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        NumberFormat('#,###').format(avgCalories),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'cal/day',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.rh),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12.rw),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CONSISTENCY',
                            style: TextStyle(
                              color:
                                  Colors.white.withValues(alpha: 0.75),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            '$daysLogged/7 Days Logged',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        // Reactions badge
        if (_receivedReactions.isNotEmpty)
          Positioned(
            bottom: -12,
            right: 16,
            child: ReactionsReceivedBadge(
              reactions: _receivedReactions,
              onTap: _showReactionsDetail,
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(32.r),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          SizedBox(height: 16.rh),
          Text(
            'No Friends Yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add friends to see their calorie progress',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.rh),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddFriendScreen(
                    onChanged: () {},
                  ),
                ),
              );
              _loadData();
            },
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Add Friends'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4361ee),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                  horizontal: 24.rw, vertical: 12.rh),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFriendsList(String? userId) {
    if (userId == null) return [];
    final friendsOnly =
        _friendsData.where((f) => f.userId != userId).toList();
    if (friendsOnly.isEmpty) return [_buildEmptyState()];
    return friendsOnly.asMap().entries.map((entry) {
      final index = entry.key;
      final friend = entry.value;
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 300 + (index * 50)),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: FriendCalorieCard(
          friendData: friend,
          isCurrentUser: false,
          weekKey: _currentWeekKey,
          currentReactionEmoji: _givenReactions[friend.userId],
          onReactionChanged: (emoji) =>
              _onReactionChanged(friend.userId, emoji),
        ),
      );
    }).toList();
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.rw),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildSkeletonBox(width: 180, height: 24),
          SizedBox(height: 16.rh),
          // User Hero Card Skeleton
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkeletonBox(width: 150, height: 20),
                SizedBox(height: 16.rh),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSkeletonBox(width: 80, height: 32),
                        const SizedBox(height: 8),
                        _buildSkeletonBox(width: 60, height: 16),
                      ],
                    ),
                    _buildSkeletonBox(width: 80, height: 40),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24.rh),
          _buildSkeletonBox(width: 120, height: 20),
          SizedBox(height: 16.rh),
          ...List.generate(3, (_) => _buildFriendCardSkeleton()),
          SizedBox(height: 100.rh),
        ],
      ),
    );
  }

  Widget _buildSkeletonBox({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildFriendCardSkeleton() {
    return Container(
      margin: EdgeInsets.only(bottom: 16.rh),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 12.rw),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSkeletonBox(width: 120, height: 16),
                      const SizedBox(height: 6),
                      _buildSkeletonBox(width: 60, height: 12),
                    ],
                  ),
                ],
              ),
              _buildSkeletonBox(width: 80, height: 32),
            ],
          ),
          SizedBox(height: 20.rh),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSkeletonBox(width: 100, height: 14),
              _buildSkeletonBox(width: 80, height: 12),
            ],
          ),
          SizedBox(height: 12.rh),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}


