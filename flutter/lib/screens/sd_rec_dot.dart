import 'package:flutter/material.dart';

/// The red of the recording dot.
const Color kSdRecRed = Color(0xFFE5322D);

/// The size of the dot.
const double kSdRecDotSize = 12;

/// A red dot that blinks while a recording runs, the way the recording light of a security camera does: lit, then dark, then lit again, over and over.
/// It is the dot inside the REC tag (sd_rec_tag.dart): the host window's title bar and the tab of a session that the person controlling records. Each side
/// sees the tag only for its own recording.
class SdRecDot extends StatefulWidget {
  const SdRecDot({super.key, this.size = kSdRecDotSize});
  final double size;

  @override
  State<SdRecDot> createState() => _SdRecDotState();
}

class _SdRecDotState extends State<SdRecDot> with SingleTickerProviderStateMixin {
  /// one blink: lit for most of a second, then dark for a little less than half of one
  static const _period = Duration(milliseconds: 1300);

  late final AnimationController _blink = AnimationController(vsync: this, duration: _period)..repeat();

  /// lit (hold) -> quick fade out -> dark (hold) -> quick fade in
  static final Animatable<double> _light = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 52),
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0.06).chain(CurveTween(curve: Curves.easeIn)), weight: 8),
    TweenSequenceItem(tween: ConstantTween<double>(0.06), weight: 32),
    TweenSequenceItem(tween: Tween<double>(begin: 0.06, end: 1).chain(CurveTween(curve: Curves.easeOut)), weight: 8),
  ]);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Recording',
      child: FadeTransition(
        opacity: _blink.drive(_light),
        child: Container(
          key: const ValueKey('sd-rec-dot'),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kSdRecRed,
            // a thin light edge and a glow, so it shows on a white screen and on a black one
            border: Border.all(color: Colors.white.withOpacity(0.85), width: 1),
            boxShadow: [BoxShadow(color: kSdRecRed.withOpacity(0.6), blurRadius: 7, spreadRadius: 1)],
          ),
        ),
      ),
    );
  }
}
