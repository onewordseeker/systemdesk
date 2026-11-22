import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';

/// How round the corners of the host window are (logical pixels).
const double kSdWindowRadius = 14;

/// Rounds the corners of the window itself (Windows): a window with no title bar of its own is a plain rectangle there, so the runner cuts the corners
/// off its shape (`windows/runner`, channel `systemdesk/window_menu`, method `setWindowRound`) and keeps the cut when the window changes size. A Mac window
/// is round already.
class SdWindowShape {
  SdWindowShape._();

  static const _channel = MethodChannel('systemdesk/window_menu');

  /// where a request goes, unless a test brings its own
  @visibleForTesting
  static void Function(double radius)? debugRound;

  static bool get available => debugRound != null || (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows);

  static Future<void> round(double radius) async {
    final test = debugRound;
    if (test != null) {
      test(radius);
      return;
    }
    if (!available) return;
    try {
      await _channel.invokeMethod('setWindowRound', {'radius': radius});
    } catch (_) {
      // an old runner without it: the window stays a rectangle, as before
    }
  }
}

/// The inside of a window whose corners are cut round: the content is clipped to the same corners and a hairline follows them, so the cut edge looks drawn.
class SdRoundedFrame extends StatelessWidget {
  const SdRoundedFrame({super.key, required this.child, this.radius = kSdWindowRadius});
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final line = t.dark ? t.line : const Color(0xFFD5DAE3);
    final shape = BorderRadius.circular(radius);
    return Container(
      key: const ValueKey('sd-rounded-frame'),
      foregroundDecoration: BoxDecoration(borderRadius: shape, border: Border.all(color: line)),
      child: ClipRRect(borderRadius: shape, clipBehavior: Clip.antiAlias, child: child),
    );
  }
}
