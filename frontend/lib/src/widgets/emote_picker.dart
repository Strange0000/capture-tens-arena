import 'package:flutter/material.dart';

import '../services/audio_service.dart';

class EmoteData {
  const EmoteData(this.code, this.emoji, this.label);
  final String code;
  final String emoji;
  final String label;
}

const emotes = [
  EmoteData('nice', '👏', 'Nice!'),
  EmoteData('gg', '🤝', 'GG'),
  EmoteData('oops', '😬', 'Oops'),
  EmoteData('wow', '😲', 'Wow!'),
  EmoteData('hurry', '⏰', 'Hurry!'),
  EmoteData('angry', '😤', 'Grr'),
];

/// Floating emote picker that appears above a button.
class EmotePicker extends StatefulWidget {
  const EmotePicker({super.key, required this.onEmote});
  final void Function(String emoteCode) onEmote;

  @override
  State<EmotePicker> createState() => _EmotePickerState();
}

class _EmotePickerState extends State<EmotePicker>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  void _selectEmote(String code) {
    AudioService.instance.hapticLight();
    AudioService.instance.playEmote();
    widget.onEmote(code);
    _toggle();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Emote panel
        if (_open)
          FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF101826).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF48E5C2).withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: emotes.map((e) {
                    return Tooltip(
                      message: e.label,
                      child: InkWell(
                        onTap: () => _selectEmote(e.code),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: Text(e.emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        // Toggle button
        GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _open
                  ? const Color(0xFF48E5C2).withOpacity(0.2)
                  : const Color(0xFF101826).withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _open
                    ? const Color(0xFF48E5C2).withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
              ),
            ),
            child: Icon(
              _open ? Icons.close : Icons.emoji_emotions_outlined,
              color: _open ? const Color(0xFF48E5C2) : Colors.white54,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

/// Floating emote display that appears above a player's seat.
class FloatingEmote extends StatefulWidget {
  const FloatingEmote({super.key, required this.emoji, required this.onDone});
  final String emoji;
  final VoidCallback onDone;

  @override
  State<FloatingEmote> createState() => _FloatingEmoteState();
}

class _FloatingEmoteState extends State<FloatingEmote>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3).chain(CurveTween(curve: Curves.easeOutBack)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 20),
    ]).animate(_ctrl);

    _fade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_ctrl);

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: const Offset(0, -0.5),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF101826).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF48E5C2).withOpacity(0.3)),
                ),
                child: Text(widget.emoji, style: const TextStyle(fontSize: 32)),
              ),
            ),
          ),
        );
      },
    );
  }
}
