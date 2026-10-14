import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/license_service.dart';

/// Counts down to the moment a usage limit closes the connection. The server sends the remaining time with every
/// heartbeat; in between this ticks locally. It only becomes visible in the last `warn_minutes` (set by the admin).
class SessionCountdown extends ChangeNotifier {
  DateTime? _endsAt;
  int _warnSeconds = 0;
  bool _visible = false;
  bool _zeroFired = false;
  Timer? _tick;

  /// Called once when the time is up, so the app asks the server right away instead of waiting for the next heartbeat.
  VoidCallback? onZero;

  bool get visible => _visible;

  int get secondsLeft {
    final end = _endsAt;
    if (end == null) return 0;
    return max(0, (end.difference(DateTime.now()).inMilliseconds / 1000).ceil());
  }

  /// null = no limit on this plan, or the admin switched the warning off.
  void update(SessionCountdownData? data) {
    _tick?.cancel();
    _tick = null;
    if (data == null || data.warnMinutes <= 0) {
      stop();
      return;
    }
    _endsAt = DateTime.now().add(Duration(seconds: data.seconds));
    _warnSeconds = data.warnMinutes * 60;
    _zeroFired = false;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _onTick();
  }

  void stop() {
    _tick?.cancel();
    _tick = null;
    _endsAt = null;
    if (_visible) {
      _visible = false;
      notifyListeners();
    }
  }

  void _onTick() {
    if (_endsAt == null) return;
    final left = secondsLeft;
    final show = left <= _warnSeconds;
    if (show || _visible) {
      _visible = show;
      notifyListeners();
    }
    if (left == 0 && !_zeroFired) {
      _zeroFired = true;
      onZero?.call();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}

/// Small pill that shows how long the session still runs. Mouse and touch go through it to the remote screen.
class SessionCountdownCapsule extends StatelessWidget {
  final SessionCountdown countdown;
  const SessionCountdownCapsule(this.countdown, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: countdown,
      builder: (context, _) {
        if (!countdown.visible) return const SizedBox.shrink();
        final left = countdown.secondsLeft;
        final urgent = left <= 60;
        final background =
            urgent ? const Color(0xFFE5484D) : const Color(0xFFFFB224);
        final ink = urgent ? Colors.white : const Color(0xFF3B2F00);
        final mm = (left ~/ 60).toString().padLeft(2, '0');
        final ss = (left % 60).toString().padLeft(2, '0');
        return IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 2))
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 16, color: ink),
                const SizedBox(width: 6),
                Text(
                  'Session closes in $mm:$ss',
                  style: TextStyle(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
