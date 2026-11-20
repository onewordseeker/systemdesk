import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/shared_state.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart' show SdPopoverAnchor;
import 'package:flutter_hbb/screens/sd_session_card.dart';
import 'package:flutter_hbb/screens/sd_toolbar.dart';
import 'package:get/get.dart';

/// The button of the toolbar that opens the card of the session (what the old green and red lock icon of the tab said, and more): it shows the app's own facts
/// about the session, nothing new is asked of the other computer.
class SdSessionCardButton extends StatefulWidget {
  const SdSessionCardButton({super.key, required this.id, required this.ffi, required this.dock});
  final String id;
  final FFI ffi;

  /// where the toolbar is docked: 'top', 'bottom', 'left' or 'right' (the card opens towards the inside of the window)
  final String dock;

  @override
  State<SdSessionCardButton> createState() => _SdSessionCardButtonState();
}

class _SdSessionCardButtonState extends State<SdSessionCardButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    late final Alignment target, follower;
    late final Offset offset;
    switch (widget.dock) {
      case 'bottom':
        target = Alignment.topLeft;
        follower = Alignment.bottomLeft;
        offset = const Offset(0, -10);
        break;
      case 'left':
        target = Alignment.topRight;
        follower = Alignment.topLeft;
        offset = const Offset(10, 0);
        break;
      case 'right':
        target = Alignment.topLeft;
        follower = Alignment.topRight;
        offset = const Offset(-10, 0);
        break;
      default:
        target = Alignment.bottomLeft;
        follower = Alignment.topLeft;
        offset = const Offset(0, 10);
    }
    return SdPopoverAnchor(
      targetAnchor: target,
      followerAnchor: follower,
      offset: offset,
      anchorBuilder: (context, toggle, open) => Tooltip(
        message: translate('Session details'),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: toggle,
            child: SdToolFace(icon: SdIcons.shield, on: open, hover: _hover),
          ),
        ),
      ),
      popupBuilder: (context, close) => _BoundCard(id: widget.id, ffi: widget.ffi),
    );
  }
}

class _BoundCard extends StatefulWidget {
  const _BoundCard({required this.id, required this.ffi});
  final String id;
  final FFI ffi;

  @override
  State<_BoundCard> createState() => _BoundCardState();
}

class _BoundCardState extends State<_BoundCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // the delay and the rate change all the time; the rest rarely
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _rx(String tag) => Get.isRegistered<RxString>(tag: tag) ? Get.find<RxString>(tag: tag).value : '';

  @override
  Widget build(BuildContext context) {
    final ffi = widget.ffi;
    final id = widget.id;
    final tag = ConnectionTypeState.tag(id);
    final type = Get.isRegistered<ConnectionType>(tag: tag) ? Get.find<ConnectionType>(tag: tag) : null;
    final known = type != null && type.isValid();
    final q = ffi.qualityMonitorModel.data;
    final pi = ffi.ffiModel.pi;
    final perms = ffi.ffiModel.permissions;
    bool allowed(String k) => perms[k] != false;
    final isFiles = ffi.connType == ConnType.fileTransfer;
    final facts = SdSessionFacts(
      secure: known ? type.secure.value == ConnectionType.strSecure : null,
      direct: known ? type.direct.value == ConnectionType.strDirect : null,
      delay: q.delay,
      fps: q.fps,
      speed: q.speed,
      codec: q.codecFormat,
      encryption: _rx(EncryptionState.tag(id)),
      fingerprint: _rx(FingerprintState.tag(id)),
      name: pi.hostname,
      id: id,
      user: pi.username,
      platform: pi.platform,
      version: pi.version,
      displays: pi.displays.length,
      permissions: [
        if (!isFiles) ...[
          ('Keyboard and mouse', allowed('keyboard')),
          ('Clipboard', allowed('clipboard')),
          ('Sound', allowed('audio')),
          ('Recording', allowed('recording')),
        ],
        ('File transfer', allowed('file')),
        ('Restart the computer', allowed('restart')),
      ],
    );
    return SdSessionCard(facts: facts, tr: translate, onCopyFingerprint: onCopyFingerprint);
  }
}
