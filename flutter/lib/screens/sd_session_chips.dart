import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/shared_state.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_toolbar.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:flutter_hbb/services/time_left.dart';
import 'package:get/get.dart';

/// The two small pills over the other computer's screen (`.rchip`): the time that is left today at the top left (on the top border of the session), how the
/// connection is made at the lower right. They take no clicks, so the screen below them stays under the mouse.
class SdSessionChips extends StatefulWidget {
  const SdSessionChips({super.key, required this.id, required this.ffi});
  final String id;
  final FFI ffi;

  @override
  State<SdSessionChips> createState() => _SdSessionChipsState();
}

class _SdSessionChipsState extends State<SdSessionChips> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
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
    final left = SdTimeLeft.minutesLeft();
    final tag = ConnectionTypeState.tag(widget.id);
    final type = Get.isRegistered<ConnectionType>(tag: tag) ? Get.find<ConnectionType>(tag: tag) : null;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(children: [
          if (left != null)
            Positioned(
              left: 16,
              top: 10,
              child: SdChip(children: [
                const SdIcon(SdIcons.clock, size: 15, color: SdToolbar.gold, stroke: 2),
                const Text('Time left today'),
                Text('$left min', style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: SdSkin.figures)),
              ]),
            ),
          if (type != null)
            Positioned(
              right: 16,
              bottom: 60,
              child: Obx(() {
                if (!type.isValid()) return const SizedBox.shrink();
                final direct = type.direct.value == ConnectionType.strDirect;
                final secure = type.secure.value == ConnectionType.strSecure;
                return AnimatedBuilder(
                  animation: widget.ffi.qualityMonitorModel,
                  builder: (context, _) {
                    final delay = widget.ffi.qualityMonitorModel.data.delay;
                    final timed = delay != null && delay.isNotEmpty;
                    return SdChip(children: [
                      Container(width: 9, height: 9, decoration: const BoxDecoration(shape: BoxShape.circle, color: SdRemoteTabs.led)),
                      Text(direct ? (timed ? 'Direct ·' : 'Direct') : (timed ? 'Relay ·' : 'Relay')),
                      if (timed) Text('$delay ms', style: const TextStyle(fontFeatures: SdSkin.figures)),
                      Text(secure ? '· Encrypted' : '· Not encrypted'),
                    ]);
                  },
                );
              }),
            ),
        ]),
      ),
    );
  }
}

class SdChip extends StatelessWidget {
  const SdChip({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: ShapeDecoration(
        color: const Color(0xD10E1422),
        shape: const StadiumBorder(side: BorderSide(color: SdToolbar.hairline)),
      ),
      child: DefaultTextStyle(
        style: sdTs(13, FontWeight.w400, SdToolbar.ink),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 10), children[i]],
        ]),
      ),
    );
  }
}
