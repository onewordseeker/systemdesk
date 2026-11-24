import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';

/// The small pictures of the computers on the cards (the Dashboard and Devices).
///
/// The picture of a computer is its desktop background (its wallpaper), never a screenshot. While someone controls a computer that says it can give its
/// background (`sd_wallpaper` in its platform additions), the app asks for it a few seconds after the session started and again every half hour (it may
/// change). The request is the one of a screenshot for a display that no computer has ([wallpaperDisplay]); the computer answers with a small picture, the core
/// shrinks it further and keeps it in one small file per computer, and the cards show the last one. A computer that cannot answer (an older version, Linux,
/// Android) has no picture: its card shows the logo of its system. The pictures stay on this computer; they can be switched off and deleted in Settings.
class SdThumbs {
  SdThumbs._();

  /// the local option that switches the pictures off ("Y" = off): they are on until someone switches them off
  static const hideOption = 'sd-hide-pictures';
  static const _dirKey = 'sd-thumbs-dir';
  static const _clearKey = 'sd-thumbs-clear';

  /// set to "Y" once the pictures that were screenshots (from before they were backgrounds) have been deleted
  static const _wallpaperKey = 'sd-thumbs-wallpaper';

  /// The "display" a screenshot request names to ask for the wallpaper instead of a screenshot: the same number as `REQUEST_DISPLAY` in `src/sd_wallpaper.rs`.
  static const int wallpaperDisplay = 9999;

  static const Duration firstAfter = Duration(seconds: 3);
  static const Duration every = Duration(minutes: 30);

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
  @visibleForTesting
  static String Function(String key)? debugGetOption;
  @visibleForTesting
  static Future<void> Function(String key, String value)? debugSetOption;

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

  /// Whether a computer, by its platform additions (what it told the app when the session started), can give its wallpaper.
  static bool hostGivesWallpaper(Map<String, dynamic> platformAdditions) => platformAdditions['sd_wallpaper'] == true;

  /// A session on a computer started (its host accepted): its wallpaper is asked for a few seconds from now, and again every half hour while it lasts.
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
    // the person is taking a screenshot of their own, or our request is still on its way
    if (ffi.ffiModel.timerScreenshot != null || _waiting.containsKey(id)) return;
    // only a computer that says it can give its wallpaper is asked: a screenshot is never taken for a card
    if (debugTake == null && !hostGivesWallpaper(ffi.ffiModel.pi.platformAdditions)) return;
    request(id, wallpaperDisplay);
  }

  /// Asks the computer for a picture to keep (for its wallpaper, with [wallpaperDisplay]).
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

  /// The pictures made before they were wallpapers are screenshots: they are deleted once (when this version starts for the first time), so that every picture
  /// on a card is a background.
  static Future<void> migrateToWallpapers() async {
    final get = debugGetOption ?? (k) => bind.mainGetLocalOption(key: k);
    final set = debugSetOption ?? (k, v) => bind.mainSetLocalOption(key: k, value: v);
    if (get(_wallpaperKey) == 'Y') return;
    await clear();
    await set(_wallpaperKey, 'Y');
  }
}
