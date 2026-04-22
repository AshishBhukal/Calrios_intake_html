import 'package:flutter/material.dart';
import 'package:fitness2/services/calorie_reaction_service.dart';

/// Badge widget that shows grouped emoji reactions received.
///
/// Displays up to 4 most-popular emoji reactions with counts,
/// plus a "+N" overflow indicator for the rest.
class ReactionsReceivedBadge extends StatelessWidget {
  final List<CalorieReaction> reactions;
  final VoidCallback onTap;

  const ReactionsReceivedBadge({
    super.key,
    required this.reactions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final groupedReactions =
        CalorieReactionService.groupReactionsByEmoji(reactions);

    // Sort by count (descending) and take top 4
    final sortedEntries = groupedReactions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final displayEntries = sortedEntries.take(4).toList();
    final remainingCount = sortedEntries.length > 4
        ? sortedEntries.skip(4).fold<int>(0, (sum, e) => sum + e.value)
        : 0;

    return Semantics(
      label: '${reactions.length} reactions received. Tap to see details.',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0f172a).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...displayEntries.map((entry) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${entry.value}',
                          style: TextStyle(
                            color:
                                Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )),
              if (remainingCount > 0)
                Text(
                  '+$remainingCount',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
