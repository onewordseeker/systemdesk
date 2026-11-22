import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/shared_state.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

/// The small pictures of the computers on the cards of the Devices page.
///
/// While someone controls a computer, the app asks it for a screenshot a few seconds after the session started and every few minutes (the same request
/// as the "Take screenshot" button, without its dialog), the core shrinks it and keeps it in one small file per computer, and the cards show the last one.
/// The pictures stay on this computer; they can be switched off and deleted in Settings. A black screen is not kept, and nothing is asked of a computer
/// while its privacy mode is on.
class SdThumbs {
  SdThumbs._();

  /// the local option that switches the pictures off ("Y" = off): they are on until someone switches them off
  static const hideOption = 'sd-hide-pictures';
  static const _dirKey = 'sd-thumbs-dir';
  static const _clearKey = 'sd-thumbs-clear';

  static const Duration firstAfter = Duration(seconds: 6);
  static const Duration every = Duration(minutes: 5);

  /// how long an answer to our request is waited for: later than that, a screenshot is the person's own
  static const Duration waitFor = Duration(seconds: 20);

  /// raised whenever a picture was saved or deleted: the cards that show one look at their file again
  static final ValueNotifier<int> changed = ValueNotifier<int>(0);

  // what the helpers use from the app; a test brings its own
  @visibleForTesting
  static bool Function()? debugEnabled;
  @visibleForTesting
  static String? debugDir;
  @visibleForTesting
  static void Function(SessionID session, int display)? debugTake;
  @visibleForTesting
  static Future<String> Function(SessionID session, String action)? debugHandle;

  static String? _dir;

  static bool get enabled => debugEnabled?.call() ?? bind.mainGetLocalOption(key: hideOption) != 'Y';

  static String get dir => debugDir ?? (_dir ??= bind.mainGetOptionSync(key: _dirKey));

  /// the file of a computer's picture (it may not exist); null for an ID that cannot name a file
  static String? pathFor(String peerId) {
    final name = peerId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    if (name.isEmpty || name.length > 64 || dir.isEmpty) return null;
    return '$dir${Platform.pathSeparator}$name.jpg';
  }

  /// the picture of a computer, when there is one and pictures are on
  static File? fileFor(String peerId) {
    if (!enabled) return null;
    final p = pathFor(peerId);
    if (p == null) return null;
    final f = File(p);
    return f.existsSync() ? f : null;
  }

  // ---- the schedule of a session ----

  static final Map<SessionID, Timer> _first = {};
  static final Map<SessionID, Timer> _again = {};
  static final Map<SessionID, Timer> _waiting = {};

  /// A session on a computer started (its host accepted): pictures are taken a few seconds from now, and again every few minutes while it lasts.
  static void begin(FFI? ffi) {
    if (ffi == null || !isDesktop || ffi.connType != ConnType.defaultConn || !enabled) return;
    final id = ffi.sessionId;
    end(id);
    _first[id] = Timer(firstAfter, () => _capture(ffi));
    _again[id] = Timer.periodic(every, (_) => _capture(ffi));
  }

  static void end(SessionID id) {
    _first.remove(id)?.cancel();
    _again.remove(id)?.cancel();
    _waiting.remove(id)?.cancel();
  }

  static void _capture(FFI ffi) {
    final id = ffi.sessionId;
    if (ffi.closed || !enabled) {
      end(id);
      return;
    }
    // the person is taking a screenshot of their own, or one of ours is still on its way
    if (ffi.ffiModel.timerScreenshot != null || _waiting.containsKey(id)) return;
    // privacy mode: the screen of that computer is hidden from whoever sits at it, and is not something to keep
    final privacy = PrivacyModeState.tag(ffi.id);
    if (Get.isRegistered<RxString>(tag: privacy) && Get.find<RxString>(tag: privacy).value.isNotEmpty) return;
    final display = ffi.ffiModel.pi.currentDisplay;
    // the merged view of all screens cannot be asked for
    if (display == kAllDisplayValue) return;
    if (debugTake == null && 'true' != bind.sessionGetCommonSync(sessionId: id, key: 'is_screenshot_supported', param: '')) return;
    request(id, display);
  }

  /// Asks the computer for a screenshot to keep as its picture.
  static void request(SessionID id, int display) {
    _waiting[id]?.cancel();
    _waiting[id] = Timer(waitFor, () => _waiting.remove(id));
    (debugTake ?? (s, d) => bind.sessionTakeScreenshot(sessionId: s, display: d))(id, display);
  }

  /// A screenshot came in: when it is the answer to our request it is kept as the picture of [peerId] and this answers true (the person is not asked
  /// anything); otherwise false, and the screenshot is the person's own.
  static bool consume(SessionID id, String peerId, String error) {
    final waiting = _waiting.remove(id);
    if (waiting == null) return false;
    waiting.cancel();
    unawaited(_keep(id, peerId, error));
    return true;
  }

  static Future<void> _keep(SessionID id, String peerId, String error) async {
    final handle = debugHandle ?? (s, a) => bind.sessionHandleScreenshot(sessionId: s, action: a);
    if (error.isNotEmpty) return;
    final failed = await handle(id, '3:$peerId');
    if (failed.isEmpty) {
      final p = pathFor(peerId);
      if (p != null) {
        if (!kIsWeb && debugDir == null) FileImage(File(p)).evict();
        changed.value++;
      }
    } else {
      // a black screen, or a picture that could not be kept: the screenshot is let go
      await handle(id, '2');
    }
  }

  /// Deletes every picture (Settings).
  static Future<void> clear() async {
    if (debugDir == null) bind.mainGetOptionSync(key: _clearKey);
    PaintingBinding.instance.imageCache.clear();
    changed.value++;
  }
}
