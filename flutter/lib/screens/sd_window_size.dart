import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Alignment;
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart' as window_size;

import '../common.dart';
import '../models/platform_model.dart';
import '../utils/multi_window_manager.dart';
import 'sd_look.dart';

/// The size the main window starts with in the new design (logical pixels). It is made for the whole dashboard: the connect box complete, the plan, the tabs of the
/// lists, both columns. The 800 x 600 of the native window cut them (the box said "search comput...", the plan was gone, five tabs were folded into "More", the left
/// panel ran out at the bottom). 1015 x 801 is the size the owner set by hand on 2026-11-22 and found every option clear in (Settings included).
const Size kSdMainWindowSize = Size(1015, 801);

/// What the native window opens with.
const Size kSdMainWindowOldSize = Size(800, 600);

/// The smallest the main window can be made (logical pixels, as the window manager counts them: on Windows the window with its invisible frame, so the visible
/// part is 16 across and 8 down less). It can be made bigger and maximised, never smaller. The owner chose it on 2026-11-24, at the size the window was then.
const Size kSdMainWindowMinSize = Size(1146, 848);

/// The least the main window can be on a screen whose usable part is [usable]: [kSdMainWindowMinSize], or all of the screen when that is smaller (a lock the
/// screen cannot hold would put part of the window out of reach).
Size sdMainWindowMinFor(Size usable) => Size(min(kSdMainWindowMinSize.width, usable.width), min(kSdMainWindowMinSize.height, usable.height));

/// The room that stays round the window on a small screen.
const double _kMargin = 24;

/// Set (to this value) once the window has had its size looked at: from then on the size is the person's own.
const String _kDone = 'v1';
const String _kDoneKey = 'sd-main-size';

/// The size to open with on a screen whose usable part (without the taskbar or the menu bar) is [usable]: [kSdMainWindowSize], or what fits when the screen is smaller.
Size sdMainWindowSizeFor(Size usable) {
  final w = min(kSdMainWindowSize.width, usable.width - 2 * _kMargin);
  final h = min(kSdMainWindowSize.height, usable.height - 2 * _kMargin);
  return Size(
    max(w, min(kSdMainWindowOldSize.width, usable.width)),
    max(h, min(kSdMainWindowOldSize.height, usable.height)),
  );
}

/// The size to give the main window when it starts, or null to leave it as it is. The window is made as big as [target] once: on the first start, and for a
/// window that was saved smaller (every earlier start saved the 800 x 600, or a little more; a window that is that small cuts the dashboard). A window that is
/// big enough stays, so does one that is maximised or full screen, and once it has been looked at ([done]) the size is the person's own for good.
Size? sdWindowSizeAtStart({
  required bool done,
  required bool saved,
  bool? maximized,
  bool? fullscreen,
  double? width,
  double? height,
  required Size target,
}) {
  if (done) return null;
  if (!saved) return target;
  if (maximized == true || fullscreen == true) return null;
  if (width == null || height == null) return target;
  if (width >= target.width - 1 && height >= target.height - 1) return null;
  return Size(max(width, target.width), max(height, target.height));
}

/// Called once at the start of the main window, after its size was looked at and before it is shown (new design only): the window cannot be made smaller than
/// [sdMainWindowMinFor] its screen, and one that was saved smaller than that is made as big as it.
Future<void> sdLockMainWindowMinimum() async {
  if (!SdLook.enabled || bind.isIncomingOnly()) return;
  try {
    final screen = (await window_size.getWindowInfo()).screen;
    final scale = isWindows ? (screen?.scaleFactor ?? 1.0) : 1.0;
    final usable = screen == null ? kSdMainWindowMinSize : Size(screen.visibleFrame.width / scale, screen.visibleFrame.height / scale);
    final least = sdMainWindowMinFor(usable);
    await windowManager.setMinimumSize(least);
    final now = await windowManager.getSize();
    if (now.width < least.width - 1 || now.height < least.height - 1) {
      await windowManager.setSize(Size(max(now.width, least.width), max(now.height, least.height)));
    }
  } catch (e) {
    debugPrint('Cannot lock the minimum size of the main window: $e');
  }
}

/// Called once at the start of the main window, after its saved frame was restored and before it is shown (new design only).
Future<void> sdSizeMainWindow() async {
  if (!SdLook.enabled || bind.isIncomingOnly()) return;
  try {
    final window = await window_size.getWindowInfo();
    final screen = window.screen;
    // what is saved is in the pixels the window manager uses: on Windows the real ones, so the screen's scale has to come off
    final scale = isWindows ? (screen?.scaleFactor ?? 1.0) : 1.0;
    final saved = LastWindowPosition.loadFromString(bind.getLocalFlutterOption(k: windowFramePrefix + WindowType.Main.name));
    final usable = screen == null ? kSdMainWindowSize : Size(screen.visibleFrame.width / scale, screen.visibleFrame.height / scale);
    final size = sdWindowSizeAtStart(
      done: bind.mainGetLocalOption(key: _kDoneKey) == _kDone,
      saved: saved != null,
      maximized: saved?.isMaximized,
      fullscreen: saved?.isFullscreen,
      width: saved?.width == null ? null : saved!.width! / scale,
      height: saved?.height == null ? null : saved!.height! / scale,
      target: sdMainWindowSizeFor(usable),
    );
    if (size != null) {
      await windowManager.setSizeAlignment(size, Alignment.center);
    }
    // a window that starts maximised is looked at again when it does not
    if (saved?.isMaximized != true && saved?.isFullscreen != true) {
      await bind.mainSetLocalOption(key: _kDoneKey, value: _kDone);
    }
  } catch (e) {
    debugPrint('Cannot set the size of the main window: $e');
  }
}
