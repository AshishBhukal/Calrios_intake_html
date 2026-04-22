import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fitness2/services/unit_preference_service.dart'
    show UnitPreferenceService, UnitConverter;
import 'package:fitness2/services/social_calculator_service.dart';
import 'package:fitness2/features/extra/constants.dart';

class FriendActivityItem {
  final String name;
  final String profileImageUrl;
  final String subtitle;
  final bool isIncreased;
  final int reps;
  final double weight;
  final String weightFormatted;

  const FriendActivityItem({
    required this.name,
    required this.profileImageUrl,
    required this.subtitle,
    required this.isIncreased,
    required this.reps,
    required this.weight,
    required this.weightFormatted,
  });
}

class ExerciseDeepDiveScreen extends StatefulWidget {
  final String exerciseName;
  final String exerciseId;
  final String userId;

  const ExerciseDeepDiveScreen({
    super.key,
    required this.exerciseName,
    required this.exerciseId,
    required this.userId,
  });

  @override
  State<ExerciseDeepDiveScreen> createState() => _ExerciseDeepDiveScreenState();
}

class _ExerciseDeepDiveScreenState extends State<ExerciseDeepDiveScreen> {
  final SocialCalculatorService _socialService = SocialCalculatorService();
  List<FriendActivityItem> _items = [];
  bool _loading = true;
  String _weightUnit = 'kg';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _weightUnit = await UnitPreferenceService.getWeightUnit();
    final items = await _fetchFriendActivityItems();
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<List<FriendActivityItem>> _fetchFriendActivityItems() async {
    final firestore = FirebaseFirestore.instance;
    final friendIds = await _socialService.fetchFriendList(widget.userId);
    final allowedIds = {...friendIds, widget.userId};

    final now = DateTime.now();
    final currentKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final prev = DateTime(now.year, now.month - 1);
    final previousKey =
        '${prev.year}-${prev.month.toString().padLeft(2, '0')}';

    final currentPath =
        'friendsLeaderboard/${widget.exerciseId}/months/$currentKey/users';
    final previousPath =
        'friendsLeaderboard/${widget.exerciseId}/months/$previousKey/users';

    Map<String, double> previousWeightByUser = {};
    try {
      for (final uid in allowedIds) {
        final doc = await firestore.doc('$previousPath/$uid').get();
        if (doc.exists) {
          final w = (doc.data()?['weight'] ?? 0.0).toDouble();
          if (w > (previousWeightByUser[uid] ?? 0)) {
            previousWeightByUser[uid] = w;
          }
        }
      }
    } catch (_) {}

    List<FriendActivityItem> items = [];
    try {
      for (final uid in allowedIds) {
        final doc = await firestore.doc('$currentPath/$uid').get();
        if (!doc.exists) continue;
        final data = doc.data()!;
        final maxWeight = (data['weight'] ?? 0.0).toDouble();
        final reps = data['reps'] ?? 0;
        final firstName = data['firstName'] ?? '';
        final lastName = data['lastName'] ?? '';
        final userName = data['userName'] ?? '';
        final name = '$firstName $lastName'.trim().isNotEmpty
            ? '$firstName $lastName'.trim()
            : (userName.isNotEmpty ? '@$userName' : 'Unknown');
        final profileImageUrl = data['profileImageUrl'] ?? '';
        final timestamp = data['timestamp'];
        final String subtitle = _formatDateSubtitle(timestamp, currentKey);
        final prevWeight = previousWeightByUser[uid];
        final isIncreased = prevWeight == null || maxWeight > prevWeight;
        final converted =
            UnitConverter.convertWeightFromKg(maxWeight, _weightUnit);
        final weightFormatted =
            UnitConverter.formatWeight(converted, _weightUnit);
        items.add(FriendActivityItem(
          name: name,
          profileImageUrl: profileImageUrl,
          subtitle: subtitle,
          isIncreased: isIncreased,
          reps: reps,
          weight: maxWeight,
          weightFormatted: weightFormatted,
        ));
      }
      items.sort((a, b) => b.weight.compareTo(a.weight));
    } catch (e) {
      debugPrint('Deep dive: error fetching leaderboard $e');
    }
    return items;
  }

  static String _formatDateSubtitle(dynamic timestamp, String monthKey) {
    if (timestamp != null && timestamp is Timestamp) {
      final date = timestamp.toDate();
      return DateFormat.MMMd().format(date);
    }
    final parts = monthKey.split('-');
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year != null && month != null && month >= 1 && month <= 12) {
        final date = DateTime(year, month);
        return DateFormat.yMMM().format(date);
      }
    }
    return monthKey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignSystem.background,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background_1.png'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.exerciseName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'DEEP DIVE ANALYSIS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: DesignSystem.primary.withValues(alpha: 0.9),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildFriendActivityHeader()),
                  if (_items.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24.r),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.fitness_center_rounded,
                                size: 48,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              SizedBox(height: 16.rh),
                              Text(
                                'No friend activity this month',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildFriendCard(_items[index], index),
                        childCount: _items.length,
                      ),
                    ),
                  SliverToBoxAdapter(child: SizedBox(height: 100.rh)),
                ],
              ),
      ),
        ),
      ),
    );
  }

  Widget _buildFriendActivityHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.rw, 24.rh, 16.rw, 12.rh),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: DesignSystem.primary, size: 22),
          SizedBox(width: 8.rw),
          const Text(
            'Leaderboard',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Text(
            '${_items.length} participants',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.white.withValues(alpha: 0.4);
    }
  }

  Widget _buildFriendCard(FriendActivityItem item, int index) {
    final badgeColor = item.isIncreased ? DesignSystem.primary : Colors.red;
    final badgeLabel = item.isIncreased ? 'Increased' : 'Decreased';
    final rank = index + 1;
    final isTopThree = rank <= 3;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.rw, 0, 16.rw, 16.rh),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: DesignSystem.darkCard,
          border: Border.all(
            color: isTopThree
                ? _rankColor(rank).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: isTopThree ? 18 : 15,
                      fontWeight: FontWeight.w900,
                      color: _rankColor(rank),
                    ),
                  ),
                ),
                SizedBox(width: 8.rw),
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      DesignSystem.primary.withValues(alpha: 0.15),
                  child: item.profileImageUrl.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: item.profileImageUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _avatarInitial(item.name),
                          ),
                        )
                      : _avatarInitial(item.name),
                ),
                SizedBox(width: 12.rw),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (item.subtitle.isNotEmpty)
                        Text(
                          item.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      badgeLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      item.weightFormatted,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16.rh),
            Container(
              padding: EdgeInsets.symmetric(vertical: 12.rh),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: DesignSystem.borderDark),
                  bottom: BorderSide(color: DesignSystem.borderDark),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'REPS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.reps}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: DesignSystem.borderDark,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'WEIGHT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.weightFormatted,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: DesignSystem.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarInitial(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Text(
      initial,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }
}
