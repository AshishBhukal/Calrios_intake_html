import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/calorie_reaction_service.dart';
import '../features/extra/constants.dart';

/// Bottom sheet that shows who reacted with what emoji
class ReactionsDetailSheet extends StatelessWidget {
  final List<CalorieReaction> reactions;

  const ReactionsDetailSheet({
    super.key,
    required this.reactions,
  });

  static Future<void> show(
      BuildContext context, List<CalorieReaction> reactions) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ReactionsDetailSheet(reactions: reactions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.6;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Color(0xFF1e293b),
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: EdgeInsets.only(top: 12.rh),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(24.rw, 20.rh, 24.rw, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Who Cheered You',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Semantics(
                  label: 'Close',
                  button: true,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Reactions list
          if (reactions.isEmpty)
            _buildEmptyState()
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: reactions.length,
                itemBuilder: (context, index) {
                  return _ReactionRow(reaction: reactions[index]);
                },
              ),
            ),
          // Safe area padding
          SizedBox(
              height: MediaQuery.of(context).padding.bottom + 16.rh),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.all(48.r),
      child: Column(
        children: [
          Icon(
            Icons.favorite_border,
            size: 48,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          SizedBox(height: 16.rh),
          Text(
            'No cheers yet!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep tracking and your friends will cheer you on',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ReactionRow extends StatelessWidget {
  final CalorieReaction reaction;

  const _ReactionRow({required this.reaction});

  @override
  Widget build(BuildContext context) {
    final fullName =
        '${reaction.fromUserFirstName} ${reaction.fromUserLastName}'
            .trim();
    final displayName =
        fullName.isNotEmpty ? fullName : 'Unknown User';

    return Semantics(
      label: '$displayName reacted with ${reaction.emoji}',
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: 24.rw, vertical: 12.rh),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF334155),
              ),
              child: ClipOval(
                child: reaction.fromUserProfileUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: reaction.fromUserProfileUrl,
                        fit: BoxFit.cover,
                        width: 44,
                        height: 44,
                        errorWidget: (_, __, ___) => _buildInitials(),
                      )
                    : _buildInitials(),
              ),
            ),
            SizedBox(width: 12.rw),
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _formatTimestamp(reaction.timestamp),
                    style: TextStyle(
                      color:
                          Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Emoji
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                reaction.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitials() {
    final initials =
        '${reaction.fromUserFirstName.isNotEmpty ? reaction.fromUserFirstName[0] : ''}'
                '${reaction.fromUserLastName.isNotEmpty ? reaction.fromUserLastName[0] : ''}'
            .toUpperCase();
    return Center(
      child: Text(
        initials.isNotEmpty ? initials : '?',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
