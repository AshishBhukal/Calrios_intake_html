import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/social_calculator_service.dart';
import '../services/calorie_reaction_service.dart';
import '../features/extra/constants.dart';
import 'emoji_reaction_picker.dart';

class FriendCalorieCard extends StatefulWidget {
  final FriendWeeklyData friendData;
  final bool isCurrentUser;
  final String? currentReactionEmoji;
  final String weekKey;
  final Function(String emoji)? onReactionChanged;

  const FriendCalorieCard({
    super.key,
    required this.friendData,
    this.isCurrentUser = false,
    this.currentReactionEmoji,
    required this.weekKey,
    this.onReactionChanged,
  });

  @override
  State<FriendCalorieCard> createState() => _FriendCalorieCardState();
}

class _FriendCalorieCardState extends State<FriendCalorieCard> {
  final CalorieReactionService _reactionService = CalorieReactionService();
  String? _selectedEmoji;
  bool _showPicker = false;
  bool _isLoading = false;
  final GlobalKey _cheerButtonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _selectedEmoji = widget.currentReactionEmoji;
  }

  @override
  void didUpdateWidget(FriendCalorieCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentReactionEmoji != oldWidget.currentReactionEmoji) {
      _selectedEmoji = widget.currentReactionEmoji;
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  String _getTimeAgo(DateTime lastActivity) {
    final difference = DateTime.now().difference(lastActivity);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  double _getProgressPercentage() {
    final avgCalories = widget.friendData.weeklySummary.avgCalories;
    final dailyGoal = widget.friendData.dailyGoal;

    if (dailyGoal == 0) return 0.0;
    return (avgCalories / dailyGoal).clamp(0.0, 1.0);
  }

  void _showEmojiPicker() {
    if (_isLoading) return; // Guard against taps while loading
    if (_showPicker) {
      _removeOverlay();
      return;
    }

    final RenderBox? renderBox =
        _cheerButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Tap anywhere to dismiss
            Positioned.fill(
              child: GestureDetector(
                onTap: _removeOverlay,
                behavior: HitTestBehavior.opaque,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            // Emoji picker positioned below the button
            Positioned(
              right: MediaQuery.of(context).size.width -
                  position.dx -
                  size.width,
              top: position.dy + size.height + 8,
              child: EmojiReactionPicker(
                currentEmoji: _selectedEmoji,
                onEmojiSelected: _handleEmojiSelected,
                onDismiss: _removeOverlay,
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _showPicker = true);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _showPicker = false);
    }
  }

  Future<void> _handleEmojiSelected(String emoji) async {
    _removeOverlay();

    // Prevent duplicate calls if already loading
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final success = await _reactionService.addOrUpdateReaction(
      toUserId: widget.friendData.userId,
      emoji: emoji,
      weekKey: widget.weekKey,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (success) {
          _selectedEmoji = emoji;
        }
      });

      if (success) {
        widget.onReactionChanged?.call(emoji);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _getProgressPercentage();
    final timeAgo = _getTimeAgo(widget.friendData.lastActivity);

    const primaryBlue = Color(0xFF3b82f6);
    const backgroundDark = Color(0xFF0a0e1a);

    return Semantics(
      label:
          '${widget.friendData.firstName} ${widget.friendData.lastName}, '
          '${(progress * 100).round()}% of daily goal',
      child: Container(
        margin: EdgeInsets.only(bottom: 16.rh),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.isCurrentUser
                ? primaryBlue.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Profile + Name + Time + Cheer Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildProfilePicture(backgroundDark),
                      SizedBox(width: 12.rw),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.friendData.firstName} ${widget.friendData.lastName}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Active $timeAgo',
                              style: TextStyle(
                                color:
                                    Colors.white.withValues(alpha: 0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Cheer/Reaction Button
                if (!widget.isCurrentUser)
                  _buildCheerButton(primaryBlue),
              ],
            ),
            SizedBox(height: 20.rh),
            // Daily Goal Progress
            _buildProgressSection(progress, primaryBlue),
            // Streak (if available)
            if (widget.friendData.weeklySummary.streak > 0) ...[
              SizedBox(height: 12.rh),
              _buildStreakRow(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePicture(Color backgroundDark) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF1e293b),
          ),
          child: ClipOval(
            child: widget.friendData.profileImageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: widget.friendData.profileImageUrl,
                    fit: BoxFit.cover,
                    width: 48,
                    height: 48,
                    errorWidget: (_, __, ___) => _buildInitialsAvatar(),
                    placeholder: (_, __) => Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  )
                : _buildInitialsAvatar(),
          ),
        ),
        if (widget.friendData.isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF22c55e),
                shape: BoxShape.circle,
                border: Border.all(
                  color: backgroundDark,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCheerButton(Color primaryBlue) {
    return Semantics(
      label: _selectedEmoji != null
          ? 'Change reaction, current: $_selectedEmoji'
          : 'Send cheer',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: _cheerButtonKey,
          onTap: _isLoading ? null : _showEmojiPicker,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: _selectedEmoji != null ? 12.rw : 16.rw,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: _selectedEmoji != null
                  ? primaryBlue.withValues(alpha: 0.15)
                  : primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: _selectedEmoji != null
                  ? Border.all(
                      color: primaryBlue.withValues(alpha: 0.3))
                  : null,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF3b82f6),
                    ),
                  )
                : _selectedEmoji != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedEmoji!,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.expand_more,
                            color:
                                primaryBlue.withValues(alpha: 0.7),
                            size: 16,
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            color: primaryBlue,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Cheer',
                            style: TextStyle(
                              color: primaryBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(double progress, Color primaryBlue) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Daily Goal Progress',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                color: progress >= 1.0
                    ? const Color(0xFF22d3ee)
                    : primaryBlue,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Progress Bar
        LayoutBuilder(
          builder: (context, constraints) {
            final width =
                constraints.maxWidth * progress.clamp(0.0, 1.0);
            return Container(
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF1e293b),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: width,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: progress >= 1.0
                        ? const LinearGradient(
                            colors: [
                              Color(0xFF3b82f6),
                              Color(0xFF22d3ee),
                            ],
                          )
                        : null,
                    color: progress >= 1.0 ? null : primaryBlue,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: (progress >= 1.0
                                ? const Color(0xFF22d3ee)
                                : primaryBlue)
                            .withValues(alpha: 0.4),
                        blurRadius: progress >= 1.0 ? 12 : 8,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStreakRow() {
    return Row(
      children: [
        const Icon(
          Icons.local_fire_department,
          color: Color(0xFFFF6B6B),
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          'Streak: ${widget.friendData.weeklySummary.streak} days',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildInitialsAvatar() {
    final initials =
        '${widget.friendData.firstName.isNotEmpty ? widget.friendData.firstName[0] : ''}'
        '${widget.friendData.lastName.isNotEmpty ? widget.friendData.lastName[0] : ''}';
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
