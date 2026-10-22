import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/services/wake_on_lan.dart';

/// Wake on LAN for one computer: asks for its MAC address (offering the ones it knows), sends the wake-up signal and says what happened.
/// It only works from a computer on the same network as the sleeping one, and the sleeping one must have Wake on LAN switched on.
void showWakeOnLanDialog(OverlayDialogManager dialogManager, String peerId) {
  final id = wolPeerId(peerId);
  final mac = TextEditingController();
  var known = <String>[];
  var sending = false;
  WakeOnLanResult? result;
  void Function(VoidCallback)? redraw;
  var closed = false;
  void paint() {
    if (!closed) redraw?.call(() {});
  }

  WakeOnLan.candidates(id).then((list) {
    known = list;
    if (mac.text.isEmpty && list.isNotEmpty) mac.text = list.first;
    paint();
  });

  Future<void> wake() async {
    final m = normalizeMac(mac.text);
    if (m == null) {
      result = const WakeOnLanResult(
          false, 'That is not a MAC address. It looks like AA:BB:CC:DD:EE:FF.');
      paint();
      return;
    }
    sending = true;
    result = null;
    paint();
    await WakeOnLan.saveMac(id, m);
    result = await WakeOnLan.send(m);
    sending = false;
    paint();
  }

  dialogManager.show((setState, close, context) {
    redraw = setState;
    final r = result;
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
          TextField(
            controller: mac,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'MAC address of the other computer',
              hintText: 'AA:BB:CC:DD:EE:FF',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => sending ? null : wake(),
          ),
          if (known.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final m in known)
                ActionChip(label: Text(m), onPressed: () => setState(() => mac.text = m)),
            ]),
          ] else if (known.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Find it in the other computer\'s network settings (it is also shown in the SystemDesk console once that computer is signed in). It is saved for this computer.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
          ],
          if (sending) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
          ],
          if (r != null) ...[
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(r.ok ? Icons.check_circle : Icons.error,
                  size: 20, color: r.ok ? const Color(0xFF32bea6) : const Color(0xFFE04F5F)),
              const SizedBox(width: 8),
              Expanded(child: Text(r.message, style: const TextStyle(fontSize: 13.5))),
            ]),
          ],
        ],
      ),
      actions: [
        dialogButton('Close', onPressed: close, isOutline: true),
        dialogButton('Wake up', onPressed: sending ? null : wake),
      ],
      onSubmit: sending ? null : wake,
      onCancel: close,
    );
  }, tag: 'wake-on-lan-$id').whenComplete(() {
    closed = true;
    mac.dispose();
  });
}
