import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/model.dart';

/// The red of the recording dot.
const Color kSdRecRed = Color(0xFFE5322D);

/// The size of the dot.
const double kSdRecDotSize = 12;

/// A red dot that blinks while a recording runs, the way the recording light of a security camera does: lit, then dark, then lit again, over and over.
/// Each side of a session sees it only for its own recording: the person controlling sees it while they record, the owner of the computer sees it while
/// they record; when both record, each of them sees this one dot (there is no second one). It is drawn inside the window, not in the tray.
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

/// Where the dot goes, from the top of the window's page: directly under the maximize button of the window. On a Mac that is the green button at the top
/// LEFT (centre 53 from the left edge); on Windows and Linux it is the maximize button at the top RIGHT (centre 70 from the right edge: close, then
/// maximize). [mac] is for tests; the app uses the system it runs on.
({double top, double? left, double? right}) sdRecDotSpot({bool? mac, double size = kSdRecDotSize, double top = 9}) {
  final isMac = mac ?? isMacOS;
  return isMac ? (top: top, left: 53 - size / 2, right: null) : (top: top, left: null, right: 70 - size / 2);
}

/// [SdRecDot] placed under the maximize button of the window; a child of a Stack. It takes no clicks.
class SdRecDotPlaced extends StatelessWidget {
  const SdRecDotPlaced({super.key, this.top = 9, this.mac});
  final double top;
  final bool? mac;

  @override
  Widget build(BuildContext context) {
    final s = sdRecDotSpot(mac: mac, top: top);
    return Positioned(top: s.top, left: s.left, right: s.right, child: const IgnorePointer(child: SdRecDot()));
  }
}

/// In a session: the dot while the person who controls is recording this session.
class SdSessionRecDot extends StatelessWidget {
  const SdSessionRecDot({super.key, required this.ffi});
  final FFI ffi;

  @override
  Widget build(BuildContext context) {
    // the Positioned has to be a direct child of the Stack, so it is always there and only what is inside it comes and goes
    final s = sdRecDotSpot();
    return Positioned(
      top: s.top,
      left: s.left,
      right: s.right,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: ffi.recordingModel,
          builder: (context, _) => ffi.recordingModel.start ? const SdRecDot() : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
