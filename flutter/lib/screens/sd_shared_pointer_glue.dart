import 'dart:ui' as ui;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/shared_state.dart';
import 'package:flutter_hbb/main.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_shared_pointer.dart';
import 'package:get/get.dart';

/// Where a point of this window's view is on the screen (null when the window cannot be asked).
Future<Offset?> sdScreenOfView(Offset view) async {
  final windowId = kWindowId;
  if (windowId == null) return null;
  final views = ui.PlatformDispatcher.instance.views;
  if (views.isEmpty) return null;
  final flutterView = views.first;
  final frame = await WindowController.fromWindowId(windowId).getFrame();
  if (frame.width <= 0 || frame.height <= 0) return null;
  return sdViewToScreen(
    frame: frame,
    viewPhysical: flutterView.physicalSize,
    devicePixelRatio: flutterView.devicePixelRatio,
    view: view,
    isMac: isMacOS,
  );
}

bool sdWarpPointer(int x, int y) {
  final ok = bind.mainSetCursorPosition(x: x, y: y);
  if (ok && isMacOS) {
    // after a warp a Mac ignores the mouse for a quarter of a second unless the mouse and the pointer are tied together again
    bind.mainClipCursor(left: 0, top: 0, right: 0, bottom: 0, enable: false);
  }
  return ok;
}

/// The controller takes the mouse back after the person at the controlled computer used it: put the controller's pointer where that
/// person's arrow is. True when a move was started (the event that asked is dropped); false = nothing to align, carry on as before.
bool sdTakeOverFromHost(
  FFI ffi,
  SdSharedPointer pointer, {
  required Offset from,
  required void Function(Offset view) placed,
  required void Function() failed,
}) {
  if (!SdLook.enabled || !(isMacOS || isWindows)) return false;
  final rect = ffi.ffiModel.rect;
  final host = ffi.cursorModel.offset;
  if (rect == null || host.dx <= -9999 || host.dy <= -9999) return false;
  try {
    if (!RemoteCursorMovedState.find(ffi.id).value) return false;
  } catch (_) {
    return false;
  }
  final canvas = ffi.canvasModel;
  final view = sdRemoteToView(
    remoteX: host.dx,
    remoteY: host.dy,
    rect: rect,
    scale: canvas.scale,
    scrollAuto: canvas.scrollStyle == ScrollStyle.scrollauto,
    canvasX: canvas.x,
    canvasY: canvas.y,
    scrollX: canvas.scrollX,
    scrollY: canvas.scrollY,
    canvasSize: canvas.size,
    leftToEdge: CanvasModel.leftToEdge,
    topToEdge: CanvasModel.topToEdge,
  );
  // an arrow that is not on the picture (another screen, scrolled away) has nothing to align to
  final shown = Rect.fromLTWH(CanvasModel.leftToEdge, CanvasModel.topToEdge,
      canvas.size.width, canvas.size.height);
  if (!shown.contains(view)) return false;
  return pointer.start(
    hostView: view,
    from: from,
    screenOf: sdScreenOfView,
    warp: sdWarpPointer,
    placed: placed,
    failed: failed,
  );
}

/// New look: keep "Show remote cursor" on for this session (see [sdKeepRemoteCursorOn]).
Future<void> sdKeepRemoteCursorOnFor(SessionID sessionId, RxBool state) {
  const option = 'show-remote-cursor';
  return sdKeepRemoteCursorOn(
    isOn: () => bind.sessionGetToggleOptionSync(sessionId: sessionId, arg: option),
    turnOn: () => bind.sessionToggleOption(sessionId: sessionId, value: option),
    report: (on) => state.value = on,
  );
}
