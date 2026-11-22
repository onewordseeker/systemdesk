import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/shared_state.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/screens/sd_toolbar.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:get/get.dart';

/// The small pill over the other computer's screen (`.rchip`): how the connection is made, at the lower right. It takes no clicks, so the screen below it
/// stays under the mouse. (The time that is left today is no longer drawn here.)
class SdSessionChips extends StatelessWidget {
  const SdSessionChips({super.key, required this.id, required this.ffi});
  final String id;
  final FFI ffi;

  @override
  Widget build(BuildContext context) {
    final tag = ConnectionTypeState.tag(id);
    final type = Get.isRegistered<ConnectionType>(tag: tag) ? Get.find<ConnectionType>(tag: tag) : null;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(children: [
          if (type != null)
            Positioned(
              right: 16,
              bottom: 60,
              child: Obx(() {
                if (!type.isValid()) return const SizedBox.shrink();
                final direct = type.direct.value == ConnectionType.strDirect;
                final secure = type.secure.value == ConnectionType.strSecure;
                return AnimatedBuilder(
                  animation: ffi.qualityMonitorModel,
                  builder: (context, _) {
                    final delay = ffi.qualityMonitorModel.data.delay;
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
