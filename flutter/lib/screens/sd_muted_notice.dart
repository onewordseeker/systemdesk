import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_toolbar.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';

/// "Sound is muted for this computer" with a button to turn it back on, at the top left of the session (below the time that is left). The mute is
/// kept per computer, so a session can start silent without any sign of it; this is that sign. It goes away when the sound is on, or with the
/// cross (the mute was meant), and comes back in the next session if the computer is still muted.
class SdMutedNotice extends StatefulWidget {
  const SdMutedNotice({super.key, required this.ffi});
  final FFI ffi;

  @override
  State<SdMutedNotice> createState() => _SdMutedNoticeState();
}

class _SdMutedNoticeState extends State<SdMutedNotice> {
  static const _option = 'disable-audio';
  Timer? _timer;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _muted {
    final ffi = widget.ffi;
    if (ffi.connType != ConnType.defaultConn) return false;
    if (ffi.ffiModel.permissions['audio'] == false) return false;
    return bind.sessionGetToggleOptionSync(sessionId: ffi.sessionId, arg: _option);
  }

  @override
  Widget build(BuildContext context) {
    if (_closed || !_muted) return const SizedBox.shrink();
    return Positioned(
      left: 16,
      top: 54,
      child: SdMutedNoticeView(
        onUnmute: () async {
          await bind.sessionToggleOption(sessionId: widget.ffi.sessionId, value: _option);
          if (mounted) setState(() {});
        },
        onClose: () => setState(() => _closed = true),
      ),
    );
  }
}

/// The pill itself.
class SdMutedNoticeView extends StatelessWidget {
  const SdMutedNoticeView({super.key, required this.onUnmute, required this.onClose});
  final VoidCallback onUnmute, onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: const ShapeDecoration(
        color: Color(0xD10E1422),
        shape: StadiumBorder(side: BorderSide(color: SdToolbar.hairline)),
      ),
      child: DefaultTextStyle(
        style: sdTs(13, FontWeight.w400, SdToolbar.ink),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SdIcon(SdIcons.speaker, size: 15, color: SdToolbar.gold, stroke: 2),
          const SizedBox(width: 10),
          const Text('Sound is muted for this computer'),
          const SizedBox(width: 10),
          GestureDetector(
            key: const ValueKey('sd-muted-unmute'),
            behavior: HitTestBehavior.opaque,
            onTap: onUnmute,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: SdToolbar.gold, borderRadius: BorderRadius.circular(13)),
                child: Text('Unmute', style: sdTs(12.5, FontWeight.w600, const Color(0xFF0E1422))),
              ),
            ),
          ),
          GestureDetector(
            key: const ValueKey('sd-muted-close'),
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: const SizedBox(width: 28, height: 28, child: Icon(Icons.close, size: 15, color: SdToolbar.ink)),
            ),
          ),
        ]),
      ),
    );
  }
}
