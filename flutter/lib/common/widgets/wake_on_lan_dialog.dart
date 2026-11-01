import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/services/wake_on_lan.dart';

/// Wake on LAN for one computer: looks its network address up in the SystemDesk account (nobody types one), sends the wake-up signal at
/// once and says what happened. It only works from a computer on the same network as the sleeping one, and the sleeping one must have
/// Wake on LAN switched on.
void showWakeOnLanDialog(OverlayDialogManager dialogManager, String peerId) {
  final id = wolPeerId(peerId);
  WakeOnLanOutcome? outcome; // null while it works
  void Function(VoidCallback)? redraw;
  var closed = false;
  void paint() {
    if (!closed) redraw?.call(() {});
  }

  Future<void> run() async {
    outcome = null;
    paint();
    outcome = await WakeOnLan.wake(id);
    paint();
  }

  run();

  dialogManager.show((setState, close, context) {
    redraw = setState;
    final r = outcome;
    return CustomAlertDialog(
      title: Row(children: [
        const Icon(Icons.power_settings_new, size: 26),
        const SizedBox(width: 10),
        Flexible(child: Text(translate('Wake on LAN'))),
      ]),
      contentBoxConstraints: const BoxConstraints(maxWidth: 440),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wakes the computer $id when it is asleep or switched off. It works when this computer is on the same network as the other one, and Wake on LAN is switched on in the other computer\'s settings.',
            style: const TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: 16),
          if (r == null) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
            const Text('Looking up its network address in your account and sending the wake-up signal…',
                style: TextStyle(fontSize: 13.5)),
          ] else
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(r.ok ? Icons.check_circle : Icons.error,
                  size: 20, color: r.ok ? const Color(0xFF32bea6) : const Color(0xFFE04F5F)),
              const SizedBox(width: 8),
              Expanded(child: Text(r.message, style: const TextStyle(fontSize: 13.5))),
            ]),
        ],
      ),
      actions: [
        dialogButton('Close', onPressed: close, isOutline: true),
        if (r != null && !r.ok) dialogButton('Try again', onPressed: run),
      ],
      onSubmit: r == null ? null : (r.ok ? close : run),
      onCancel: close,
    );
  }, tag: 'wake-on-lan-$id').whenComplete(() {
    closed = true;
  });
}
