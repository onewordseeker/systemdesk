import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

// The host window ("connection manager") in the new look.
//  - A request for access is a card in the middle of the screen, placed before the window is shown, so it appears there and does not slide in.
//  - Once the request is accepted the window becomes a small one docked at the bottom right, near the clock, and stays while the connection is
//    active, with the time, the chat and the permissions. A chat opens beside it; the window grows to the left and up.

/// The window of a request, and the small docked window of a connection that is going (with its chat closed and open).
// 420 x 590: the request card with the profile under the ID, the permissions and Accept / Dismiss all show (at 440 x 620 the buttons were cut)
const Size kSdCmRequestSize = Size(420, 590);
// 430 high: the card with the permission profile under the ID, the permissions, Elevate and Disconnect all show (at 340 the Disconnect button was cut)
const Size kSdCmCompactSize = Size(400, 430);
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
class SdPinnedBottomScroll extends StatelessWidget {
  const SdPinnedBottomScroll({super.key, required this.top, required this.bottom});
  final Widget top, bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.hasBoundedHeight ? c.maxHeight : 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [top, bottom],
          ),
        ),
      ),
    );
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
