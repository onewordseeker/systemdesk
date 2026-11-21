import 'dart:ui';

/// ONE pointer shared by the person at the controlled computer and the controller (new look).
///
/// While the person at the controlled computer moves the mouse, the controller sees THEIR arrow move (drawn from the position the controlled
/// computer sends; our own arrow is hidden) and nothing from the controller reaches that computer. When the controller moves again, the
/// controller's own pointer is first put where that arrow is, so it goes on from there: no jump, no second arrow.

/// Where, in the view (the space of a mouse event's `position`), the remote point ([remoteX], [remoteY]) is. The inverse of
/// `InputModel._handlePointerDevicePos` plus the edges `handlePointerDevicePos` takes off: a pointer put there is sent to the remote computer
/// as that same point.
Offset sdRemoteToView({
  required double remoteX,
  required double remoteY,
  required Rect rect,
  required double scale,
  required bool scrollAuto,
  required double canvasX,
  required double canvasY,
  required double scrollX,
  required double scrollY,
  required Size canvasSize,
  required double leftToEdge,
  required double topToEdge,
}) {
  var x = (remoteX - rect.left) * scale;
  var y = (remoteY - rect.top) * scale;
  if (scrollAuto) {
    x += canvasX;
    y += canvasY;
  } else {
    final imageWidth = rect.width * scale;
    final imageHeight = rect.height * scale;
    x -= imageWidth * scrollX;
    y -= imageHeight * scrollY;
    if (canvasSize.width > imageWidth) x += (canvasSize.width - imageWidth) / 2;
    if (canvasSize.height > imageHeight) {
      y += (canvasSize.height - imageHeight) / 2;
    }
  }
  return Offset(x + leftToEdge, y + topToEdge);
}

/// Where a point of the view is on the screen, in what `mainSetCursorPosition` takes: points on a Mac, pixels on Windows. The same
/// arithmetic the pointer-lock mode uses to find the middle of the picture.
Offset sdViewToScreen({
  required Rect frame,
  required Size viewPhysical,
  required double devicePixelRatio,
  required Offset view,
  required bool isMac,
}) {
  if (isMac) {
    final titleBar = frame.height - viewPhysical.height / devicePixelRatio;
    return Offset(frame.left + view.dx, frame.top + titleBar + view.dy);
  }
  final extraWidth = frame.width - viewPhysical.width;
  final extraHeight = frame.height - viewPhysical.height;
  final borderX = extraWidth > 0 ? extraWidth / 2 : 0.0;
  final borderBottom = borderX;
  final borderTop = extraHeight > borderBottom ? extraHeight - borderBottom : 0.0;
  return Offset(frame.left + borderX + view.dx * devicePixelRatio,
      frame.top + borderTop + view.dy * devicePixelRatio);
}

/// Moves the controller's own pointer to the arrow of the controlled computer, once, when the controller takes the mouse back.
///
/// Events of the pointer are asked [swallows] first: while the move is under way, and for a moment after it (events already on their way
/// from where the pointer was), they must not reach the controlled computer.
class SdSharedPointer {
  SdSharedPointer({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// How long after a move events near where the pointer was are taken for old ones (already on their way when it was moved).
  static const Duration settle = Duration(milliseconds: 160);

  /// How far from where the pointer was put an event is still the pointer going on (never taken for an old one).
  static const double near = 40;

  /// How far from where the pointer was an event can still be one of the old ones. Anything else is the person's own movement and is
  /// never held: a quick flick right after the move must not stutter.
  static const double stale = 120;

  bool _busy = false;
  Offset? _placed;
  Offset? _from;
  DateTime? _placedAt;

  bool get busy => _busy;

  bool swallows(Offset view) {
    if (_busy) return true;
    final at = _placed;
    final from = _from;
    final when = _placedAt;
    if (at == null || from == null || when == null) return false;
    if (_now().difference(when) >= settle) {
      _placed = null;
      _from = null;
      _placedAt = null;
      return false;
    }
    return (view - at).distance > near && (view - from).distance < stale;
  }

  /// Starts putting the pointer where the arrow of the controlled computer is ([hostView], in the view) from where it is now ([from]).
  /// Always true: the event that asked for it is dropped. [placed] runs when the pointer is there, [failed] when it could not be moved
  /// (the events then go on as they were).
  bool start({
    required Offset hostView,
    required Offset from,
    required Future<Offset?> Function(Offset view) screenOf,
    required bool Function(int x, int y) warp,
    required void Function(Offset view) placed,
    required void Function() failed,
  }) {
    if (_busy) return true;
    _busy = true;
    () async {
      var ok = false;
      try {
        final screen = await screenOf(hostView);
        if (screen != null) ok = warp(screen.dx.round(), screen.dy.round());
      } catch (_) {
        ok = false;
      }
      _busy = false;
      if (ok) {
        _placed = hostView;
        _from = from;
        _placedAt = _now();
        placed(hostView);
      } else {
        failed();
      }
    }();
    return true;
  }
}

/// The shared pointer needs the controlled computer to send where its pointer is, which it only does while "Show remote cursor" is on: keep it
/// on in the new look (nothing else shows the pointer of the person at that computer).
Future<void> sdKeepRemoteCursorOn({
  required bool Function() isOn,
  required Future<void> Function() turnOn,
  required void Function(bool on) report,
}) async {
  try {
    if (isOn()) return;
    await turnOn();
    report(isOn());
  } catch (_) {
    // the option stays as it was
  }
}
