import 'package:flutter/material.dart';
import '../services/calorie_reaction_service.dart';
import '../features/extra/constants.dart';

/// Widget that shows a popup with emoji options for reacting
class EmojiReactionPicker extends StatefulWidget {
  final String? currentEmoji;
  final Function(String emoji) onEmojiSelected;
  final VoidCallback onDismiss;

  const EmojiReactionPicker({
    super.key,
    this.currentEmoji,
    required this.onEmojiSelected,
    required this.onDismiss,
  });

  @override
  State<EmojiReactionPicker> createState() => _EmojiReactionPickerState();
}

class _EmojiReactionPickerState extends State<EmojiReactionPicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectEmoji(String emoji) {
    widget.onEmojiSelected(emoji);
  }

  void _showCustomEmojiDialog() {
    showDialog(
      context: context,
      builder: (context) => CustomEmojiDialog(
        onEmojiSelected: (emoji) {
          widget.onEmojiSelected(emoji);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: Alignment.topRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1e293b).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preset emojis
              ...CalorieReactionService.presetEmojis.map((emoji) {
                final isSelected = widget.currentEmoji == emoji;
                return Semantics(
                  label: 'React with $emoji',
                  button: true,
                  selected: isSelected,
                  child: GestureDetector(
                    onTap: () => _selectEmoji(emoji),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF3b82f6)
                                .withValues(alpha: 0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              }),
              // Plus button for custom emoji
              Semantics(
                label: 'Add custom emoji',
                button: true,
                child: GestureDetector(
                  onTap: _showCustomEmojiDialog,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white54,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog for entering a custom emoji
class CustomEmojiDialog extends StatefulWidget {
  final Function(String emoji) onEmojiSelected;

  const CustomEmojiDialog({
    super.key,
    required this.onEmojiSelected,
  });

  @override
  State<CustomEmojiDialog> createState() => _CustomEmojiDialogState();
}

class _CustomEmojiDialogState extends State<CustomEmojiDialog> {
  final TextEditingController _controller = TextEditingController();
  final CalorieReactionService _reactionService = CalorieReactionService();
  String? _errorMessage;
  bool _isValidating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    final emoji = _controller.text.trim();

    if (emoji.isEmpty) {
      setState(() => _errorMessage = 'Please enter an emoji');
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    if (_reactionService.isValidEmoji(emoji)) {
      Navigator.of(context).pop();
      widget.onEmojiSelected(emoji);
    } else {
      setState(() {
        _isValidating = false;
        _errorMessage = 'Unsupported emoji. Please choose a different one.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1e293b),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Custom Emoji',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a single emoji to react with',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            SizedBox(height: 20.rh),
            TextField(
              controller: _controller,
              autofocus: true,
              textAlign: TextAlign.center,
              maxLength: 2, // Most emojis are 1-2 chars
              style: const TextStyle(
                fontSize: 32,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                counterText: '', // Hide character counter
                hintText: '\u{1F60A}',
                hintStyle: TextStyle(
                  fontSize: 32,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _errorMessage != null
                        ? Colors.red.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _errorMessage != null
                        ? Colors.red.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _errorMessage != null
                        ? Colors.red
                        : const Color(0xFF3b82f6),
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.rw,
                  vertical: 16.rh,
                ),
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
              onSubmitted: (_) => _validateAndSubmit(),
            ),
            if (_errorMessage != null) ...[
              SizedBox(height: 12.rh),
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 24.rh),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 12.rw),
                ElevatedButton(
                  onPressed:
                      _isValidating ? null : _validateAndSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3b82f6),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.rw,
                      vertical: 12.rh,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isValidating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Add',
                          style:
                              TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
