import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_modal.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';

/// What a person sees when the computer they connect to is offline: what happened, what to check, and three ways on: Power on (wake it over the network),
/// Retry (connect again) and Cancel (close the session). It takes the place of the plain "Connection error" box for that one case.
class SdOfflineDialog extends StatelessWidget {
  const SdOfflineDialog({super.key, required this.peerId, this.onPowerOn, this.onRetry, required this.onCancel, this.tr = _same});

  /// the other computer's ID, as it is written in the lists ("459 591")
  final String peerId;
  final VoidCallback? onPowerOn, onRetry;
  final VoidCallback onCancel;
  final String Function(String) tr;

  static String _same(String s) => s;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return SdModal(
      maxWidth: 460,
      onSubmit: onRetry,
      onCancel: onCancel,
      content: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(clipBehavior: Clip.none, children: [
            SdBox(radius: 14, color: t.chip, width: 52, height: 52, alignment: Alignment.center, child: SdIcon(SdIcons.monitor, size: 26, color: t.mut, stroke: 1.8)),
            Positioned(right: -3, bottom: -3, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: t.bad, shape: BoxShape.circle, border: Border.all(color: t.pa, width: 3)))),
          ]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('SystemDesk Offline'), style: sdTs(20, FontWeight.w600, t.ink, lh: 1.25)),
              const SizedBox(height: 4),
              Text(tr('This desk is not available'), style: sdTs(15, FontWeight.w500, t.bad, lh: 1.3)),
              if (peerId.isNotEmpty) ...[
                const SizedBox(height: 10),
                // a Row, so the tag is as wide as its words
                Row(children: [SdTag('ID $peerId')]),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Text(tr('Please make sure that SystemDesk is running on the remote device and it is connected to the internet.'), style: sdTs(14.5, FontWeight.w400, t.mut, lh: 1.5)),
      ]),
      // one Row: a button is as wide as its words (alone in a Wrap it would take the whole line)
      actions: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (onPowerOn != null) ...[SdButton(icon: SdIcons.power, label: tr('Power on'), onTap: onPowerOn), const SizedBox(width: 10)],
          if (onRetry != null) ...[SdButton(kind: SdBtnKind.gold, icon: SdIcons.refresh, label: tr('Retry'), onTap: onRetry), const SizedBox(width: 10)],
          SdButton(label: tr('Cancel'), onTap: onCancel),
        ]),
      ],
    );
  }
}

/// Shows the offline box over the session. [onPowerOn] / [onRetry] are left out when the session cannot do them.
Future<void> showSdOfflineDialog(
  OverlayDialogManager dialogManager, {
  required String peerId,
  required String tag,
  VoidCallback? onPowerOn,
  VoidCallback? onRetry,
  required VoidCallback onCancel,
}) {
  return dialogManager.show<void>(
    (setState, close, context) => SdOfflineDialog(
      peerId: peerId,
      tr: translate,
      onPowerOn: onPowerOn,
      onRetry: onRetry == null
          ? null
          : () {
              close();
              onRetry();
            },
      onCancel: () {
        close();
        onCancel();
      },
    ),
    tag: tag,
    forceGlobal: true,
  );
}
