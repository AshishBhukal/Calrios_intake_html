import 'package:flutter/material.dart';
import 'package:fitness2/services/speech_to_text_service.dart';

/// Reusable voice input for text fields (AI food description, image clarification, etc.).
/// Use with a [TextEditingController]; tapping the mic starts/stops listening and updates the controller.
mixin VoiceInputMixin<T extends StatefulWidget> on State<T> {
  bool _voiceListening = false;

  bool get isVoiceListening => _voiceListening;

  /// Start or stop voice input; updates [controller] with transcript. Call from mic button.
  Future<void> toggleVoiceInput(TextEditingController controller) async {
    if (SpeechToTextService.isListening) {
      await SpeechToTextService.stopListening();
      if (mounted) setState(() => _voiceListening = false);
      return;
    }

    final didStart = await SpeechToTextService.startListening(
      onPartial: (text) {
        if (mounted) setState(() => controller.text = text);
      },
      onComplete: (text) {
        if (!mounted) return;
        setState(() {
          _voiceListening = false;
          if (text.trim().isNotEmpty) controller.text = text.trim();
        });
      },
    );

    if (mounted) {
      setState(() => _voiceListening = didStart);
      if (!didStart) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone unavailable. Check permission or try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Build a mic icon button for voice input. Use with a [TextEditingController].
  Widget buildVoiceMicButton({
    required TextEditingController controller,
    Color? iconColor,
    Color? listeningColor,
    double iconSize = 24,
  }) {
    final listening = _voiceListening || SpeechToTextService.isListening;
    return _AnimatedMicButton(
      listening: listening,
      onTap: () => toggleVoiceInput(controller),
      iconSize: iconSize,
      iconColor: iconColor ?? Colors.white70,
      listeningColor: listeningColor ?? Colors.red,
    );
  }
}

/// Mic button with a pulsing ring animation when actively listening.
class _AnimatedMicButton extends StatefulWidget {
  final bool listening;
  final VoidCallback onTap;
  final double iconSize;
  final Color iconColor;
  final Color listeningColor;

  const _AnimatedMicButton({
    required this.listening,
    required this.onTap,
    required this.iconSize,
    required this.iconColor,
    required this.listeningColor,
  });

  @override
  State<_AnimatedMicButton> createState() => _AnimatedMicButtonState();
}

class _AnimatedMicButtonState extends State<_AnimatedMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    if (widget.listening) _pulseController.repeat();
  }

  @override
  void didUpdateWidget(_AnimatedMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listening && !oldWidget.listening) {
      _pulseController.repeat();
    } else if (!widget.listening && oldWidget.listening) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.listening ? widget.listeningColor : widget.iconColor;
    final ringSize = widget.iconSize + 20;

    return Semantics(
      label: widget.listening ? 'Microphone on, listening' : 'Microphone',
      button: true,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: ringSize,
          height: ringSize,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (widget.listening)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) => Transform.scale(
                    scale: _pulseScale.value,
                    child: Container(
                      width: widget.iconSize + 8,
                      height: widget.iconSize + 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.listeningColor
                            .withOpacity(_pulseOpacity.value),
                      ),
                    ),
                  ),
                ),
              if (widget.listening)
                Container(
                  width: widget.iconSize + 8,
                  height: widget.iconSize + 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.listeningColor.withOpacity(0.15),
                  ),
                ),
              Icon(
                widget.listening ? Icons.mic : Icons.mic_none_outlined,
                size: widget.iconSize,
                color: color,
              ),
              // Subtle recording indicator dot when mic is active
              if (widget.listening)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.listeningColor,
                      boxShadow: [
                        BoxShadow(
                          color: widget.listeningColor.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ],
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
