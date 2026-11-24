import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

// The host window ("connection manager") in the new look.
//  - A request for access is a card in the middle of the screen, placed before the window is shown, so it appears there and does not slide in.
//  - Once the request is accepted the window becomes a small one docked at the bottom right, near the clock, and stays while the connection is
//    active, with the time, the chat and the permissions. A chat opens beside it; the window grows to the left and up.

/// The window of a request, and the small docked window of a connection that is going (with its chat closed and open).
// 420 x 500: the request card (who, what, the two labels), the permissions and Accept / Dismiss, with "Accept and elevate" above them, all show
// The height is the least: the window grows with what it shows (see sdFitCmWindow), the width stays.
const Size kSdCmRequestSize = Size(420, 500);
// 490 high: the card with the profile and the time, the permissions, the recording row and Disconnect all show; "Elevate" or a voice call make it higher
const Size kSdCmCompactSize = Size(400, 490);
const Size kSdCmCompactChatSize = Size(800, 520);

/// The gap between the docked window and the corner of the screen it sits in.
const double kSdCmDockMargin = 12;

/// True while every connection of this computer is accepted (and there is one): the window is then the small docked one.
bool sdCmCompact = false;

/// Whether the window is the small docked one, given whether each connection is accepted yet.
bool sdCmShouldBeCompact(Iterable<bool> accepted) => accepted.isNotEmpty && accepted.every((a) => a);

/// Where the window sits: a request in the middle of the screen, a connection at the bottom right.
Alignment get sdCmAlignment => sdCmCompact ? Alignment.bottomRight : Alignment.center;

/// How big the window is now, with the chat closed or open.
Size sdCmSize({required bool chatOpen}) => sdCmCompact ? (chatOpen ? kSdCmCompactChatSize : kSdCmCompactSize) : kSdCmRequestSize;

/// [top] at the top, [bottom] pinned at the bottom of the space it is given; when the two do not fit it scrolls instead of overflowing (the
/// "bottom overflowed by 1 pixel" stripe of a window a little too low). The host card of both windows is built with it.
///
/// [onNeed], when given, is told after every layout how much room [top] and [bottom] need together and how much room they were given, so the window
/// can be made as high as its content (see [sdFitCmWindow]); the scrolling is then only what is left when the screen is too small.
class SdPinnedBottomScroll extends StatefulWidget {
  const SdPinnedBottomScroll({super.key, required this.top, required this.bottom, this.onNeed});
  final Widget top, bottom;
  final void Function(double need, double room)? onNeed;

  @override
  State<SdPinnedBottomScroll> createState() => _SdPinnedBottomScrollState();
}

class _SdPinnedBottomScrollState extends State<SdPinnedBottomScroll> {
  final _top = GlobalKey();
  final _bottom = GlobalKey();
  double _room = 0;
  bool _queued = false;

  void _report() {
    if (widget.onNeed == null || _queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted) return;
      final t = _top.currentContext?.size?.height;
      final b = _bottom.currentContext?.size?.height;
      if (t == null || b == null) return;
      widget.onNeed?.call(t + b, _room);
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _report();
        return false;
      },
      child: LayoutBuilder(
        builder: (context, c) {
          _room = c.hasBoundedHeight ? c.maxHeight : 0;
          _report();
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.hasBoundedHeight ? c.maxHeight : 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizeChangedLayoutNotifier(key: _top, child: widget.top),
                  SizeChangedLayoutNotifier(key: _bottom, child: widget.bottom),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// What the screen takes from a window's height: the taskbar and the gap to the corner the docked window sits in.
const double kSdCmScreenReserve = 96;

/// How high the window has to be for what it shows, or null when it is high enough (and not too high) already: the height it has now, less the room the
/// card was given, plus the room the card needs. Never lower than [minHeight] (the size it is made at), never higher than [maxHeight] (the screen; the card
/// scrolls beyond that).
double? sdCmFitHeight({
  required double windowHeight,
  required double room,
  required double need,
  required double minHeight,
  required double maxHeight,
}) {
  final top = maxHeight < minHeight ? minHeight : maxHeight;
  final target = (windowHeight - room + need).clamp(minHeight, top).toDouble();
  return (target - windowHeight).abs() < 1.5 ? null : target.ceilToDouble();
}

({double need, double room, double minHeight})? _fitPending;
bool _fitRunning = false;

/// The card of the window says how much room it needs: the window is made as high as that, keeping its corner (the docked window grows upwards, the
/// request around its middle). Calls that come in while it works are answered by the last one.
Future<void> sdFitCmWindow({required double need, required double room, required double minHeight}) async {
  _fitPending = (need: need, room: room, minHeight: minHeight);
  if (_fitRunning) return;
  _fitRunning = true;
  try {
    while (_fitPending != null) {
      final p = _fitPending!;
      _fitPending = null;
      if (await windowManager.isMinimized()) continue;
      final size = await windowManager.getSize();
      final view = ui.PlatformDispatcher.instance.views.first;
      final screen = view.display.size.height / view.display.devicePixelRatio;
      final h = sdCmFitHeight(windowHeight: size.height, room: p.room, need: p.need, minHeight: p.minHeight, maxHeight: screen - kSdCmScreenReserve);
      if (h != null) await sdPlaceCmWindow(Size(size.width, h));
    }
  } catch (e) {
    debugPrint('Could not fit the host window to its content: $e');
  } finally {
    _fitRunning = false;
  }
}

/// Sets size and place of the window in one go: the docked window keeps a small gap to the screen's corner (the clock sits just below it).
Future<void> sdPlaceCmWindow(Size size) async {
  await windowManager.setSizeAlignment(size, sdCmAlignment);
  if (sdCmCompact) {
    final p = await windowManager.getPosition();
    await windowManager.setPosition(p + const Offset(-kSdCmDockMargin, -kSdCmDockMargin));
  }
}

/// The connections changed: become the request card or the small docked window. The window is made invisible while it moves, so it never slides
/// across the screen. [chatOpen]: the chat is open beside the connection.
Future<void> sdSwitchCmMode(bool compact, {bool chatOpen = false}) async {
  if (compact == sdCmCompact) return;
  sdCmCompact = compact;
  final shown = await windowManager.getOpacity() != 0;
  if (shown) await windowManager.setOpacity(0);
  await sdPlaceCmWindow(sdCmSize(chatOpen: chatOpen && compact));
  if (shown) await windowManager.setOpacity(1);
}
