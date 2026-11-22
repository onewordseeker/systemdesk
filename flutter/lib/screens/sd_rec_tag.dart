import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/screens/sd_rec_dot.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

// While a session is recorded, the title bar of the window says so: a blinking red dot, "REC" and how long the recording has run, in a small pill. The
// taskbar button (Windows) or the Dock icon (Mac) shows a red mark too, so a window that is minimized still tells.

/// How long a recording has run: 00:12, then 1:02:03 after the first hour.
String sdRecClock(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  String two(int v) => v.toString().padLeft(2, '0');
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
}

/// The pill: dot, "REC", the time. [since] is when the recording began.
class SdRecTag extends StatefulWidget {
  const SdRecTag({super.key, required this.since, this.height = 22});
  final DateTime since;
  final double height;

  /// the clock the pill reads, unless a test brings its own
  @visibleForTesting
  static DateTime Function()? debugNow;

  @override
  State<SdRecTag> createState() => _SdRecTagState();
}

class _SdRecTagState extends State<SdRecTag> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark ? const Color(0xFF3A1D1B) : const Color(0xFFFDECEA);
    final line = dark ? const Color(0xFF8F2E29) : const Color(0xFFF2B8B2);
    final fg = dark ? const Color(0xFFFF8A83) : const Color(0xFFD92D20);
    final now = (SdRecTag.debugNow ?? DateTime.now)();
    return Semantics(
      label: 'Recording',
      child: Container(
        key: const ValueKey('sd-rec-tag'),
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999), border: Border.all(color: line)),
        child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
          const SizedBox(width: 12, height: 12, child: Center(child: SdRecDot(size: 8))),
          const SizedBox(width: 6),
          Text('REC', style: sdTs(11.5, FontWeight.w700, fg, lh: 1.0, ls: 0.7)),
          const SizedBox(width: 6),
          Text(sdRecClock(now.difference(widget.since)), key: const ValueKey('sd-rec-time'), style: sdTs(11.5, FontWeight.w600, fg, lh: 1.0, figures: true)),
        ]),
      ),
    );
  }
}

/// The red mark on the taskbar button (Windows) or the Dock icon (Mac) of this window.
class SdRecBadge {
  SdRecBadge._();

  static const _channel = MethodChannel('systemdesk/window_menu');

  /// where a request goes, unless a test brings its own
  @visibleForTesting
  static void Function(bool on)? debugSet;

  static final Set<Object> _holders = {};

  /// [holder] needs the mark. It stays on while anyone does: several tabs of one window can record at once, and the first to finish must not take it off.
  static void acquire(Object holder) {
    final none = _holders.isEmpty;
    _holders.add(holder);
    if (none) set(true);
  }

  static void release(Object holder) {
    if (_holders.remove(holder) && _holders.isEmpty) set(false);
  }

  @visibleForTesting
  static void debugReset() => _holders.clear();

  static Future<void> set(bool on) async {
    final test = debugSet;
    if (test != null) {
      test(on);
      return;
    }
    if (kIsWeb) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        // 0 when the mark was put on (or taken off); otherwise the error of the system, which is logged
        final code = await _channel.invokeMethod<int>('setRecordingBadge', {'on': on});
        if (code != null && code != 0) debugPrint('recording mark on the taskbar button: error 0x${code.toUnsigned(32).toRadixString(16)}');
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        await windowManager.setBadgeLabel(on ? 'REC' : '');
      }
    } catch (_) {
      // an old runner without the badge: nothing happens
    }
  }
}

/// The place in the title bar for the tag: empty while nothing is recorded. It also puts the red mark on the taskbar button or Dock icon when a recording
/// starts and takes it off when it ends (or when the window closes).
class SdRecTagSlot extends StatefulWidget {
  const SdRecTagSlot({super.key, required this.recording, required this.since});
  final bool recording;

  /// asked only while recording
  final DateTime Function() since;

  @override
  State<SdRecTagSlot> createState() => _SdRecTagSlotState();
}

class _SdRecTagSlotState extends State<SdRecTagSlot> {
  bool _marked = false;

  void _sync() {
    if (widget.recording == _marked) return;
    _marked = widget.recording;
    final on = _marked;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (on) {
        SdRecBadge.acquire(this);
      } else {
        SdRecBadge.release(this);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SdRecTagSlot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    SdRecBadge.release(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.recording) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: SdRecTag(since: widget.since()));
  }
}

/// The tag of the host window: it shows while the owner of this computer records the session (the Record button, or "record every session").
class SdHostRecTag extends StatelessWidget {
  const SdHostRecTag({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<ServerModel>(context);
    return SdRecTagSlot(recording: model.sdHostRecordingNow, since: () => model.sdHostRecordSince);
  }
}

/// What the tag of a tab needs from the recording of its session.
typedef SdRecFeed = ({Listenable changes, bool Function() recording, DateTime Function() since});

SdRecFeed? _sessionRecFeed(String tabKey) {
  if (!Get.isRegistered<FFI>(tag: tabKey)) return null;
  final model = Get.find<FFI>(tag: tabKey).recordingModel;
  return (changes: model, recording: () => model.start, since: () => model.sdSince);
}

/// The tag inside the tab of a computer that the person who controls is recording: the same pill as the host's, with the time. Only the tab of the
/// session that is recorded shows it. While it shows, the taskbar button (Windows) or the Dock icon (Mac) of the window carries the red mark.
class SdTabRecTag extends StatefulWidget {
  const SdTabRecTag({super.key, required this.tabKey, this.find});
  final String tabKey;

  /// finds the recording of this tab's session; a test brings its own
  final SdRecFeed? Function(String tabKey)? find;

  @override
  State<SdTabRecTag> createState() => _SdTabRecTagState();
}

class _SdTabRecTagState extends State<SdTabRecTag> {
  SdRecFeed? _feed;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _attach();
    // the session of a tab is made a moment after the tab: look again until it is there
    if (_feed == null) {
      _poll = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _attach();
        if (_feed != null) {
          _poll?.cancel();
          if (mounted) setState(() {});
        }
      });
    }
  }

  void _attach() {
    if (_feed != null) return;
    final feed = (widget.find ?? _sessionRecFeed)(widget.tabKey);
    if (feed == null) return;
    _feed = feed;
    feed.changes.addListener(_changed);
    _markTaskbar();
  }

  void _markTaskbar() {
    final feed = _feed;
    if (feed == null) return;
    if (feed.recording()) {
      SdRecBadge.acquire(this);
    } else {
      SdRecBadge.release(this);
    }
  }

  void _changed() {
    _markTaskbar();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _poll?.cancel();
    _feed?.changes.removeListener(_changed);
    SdRecBadge.release(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    if (feed == null || !feed.recording()) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(left: 8), child: SdRecTag(since: feed.since(), height: 20));
  }
}