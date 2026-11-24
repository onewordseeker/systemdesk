import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/screens/sd_cm_cards.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_modal.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';

// What the person who connected sees when the other computer ends the connection (new look): "Session Ended" when the host closed a session it had
// accepted, "Connection Rejected" when it said no to the request. They replace the plain "Connection error" box for those cases. The card is drawn from
// plain values (`SdSessionEndCard`), the reasons are told apart by `sdEndKindFor`, and `SdSessionEndDialog` puts the card over the session window.

/// The words the host's side sends as the reason of the close (src/server/connection.rs).
const String kSdClosedByPeer = 'Closed manually by the peer';
const String kSdClosedByAdmin = 'Closed manually by web console';
const String kSdClosedInactive = 'Connection failed due to inactivity';

enum SdEndKind { ended, admin, inactive, rejected }

/// Which card a "Connection Error" box becomes, or null when it stays the plain box. The host sends the same words when it closes a running session
/// and when it declines a request that is still waiting; what tells them apart is whether the request had been accepted ([accepted]).
SdEndKind? sdEndKindFor({required String type, required String title, required String text, required bool accepted}) {
  if (type != 'error' || title != 'Connection Error') return null;
  switch (text) {
    case kSdClosedByPeer:
      return accepted ? SdEndKind.ended : SdEndKind.rejected;
    case kSdClosedByAdmin:
      return SdEndKind.admin;
    case kSdClosedInactive:
      return SdEndKind.inactive;
  }
  return null;
}

/// 00:07:51 (hours, minutes, seconds)
String sdDurationText(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
}

enum SdEndTone { amber, neutral, green, red }

/// One of the three boxes under the header: a round icon, the value, and a small label in capitals.
class SdEndTile {
  const SdEndTile({required this.icon, required this.value, required this.label, this.tone = SdEndTone.neutral});
  final String icon, value, label;
  final SdEndTone tone;
}

/// The whole card, from values with the words already translated.
class SdSessionEndCard extends StatelessWidget {
  const SdSessionEndCard({
    super.key,
    required this.alert,
    required this.name,
    this.who = '',
    required this.state,
    required this.pill,
    required this.tiles,
    required this.note,
    required this.primary,
    this.primaryIcon,
    required this.secondary,
    required this.onPrimary,
    required this.onSecondary,
  });

  /// red (a request that was refused) or calm amber (a session that ended)
  final bool alert;
  final String name, who, state, pill, note, primary, secondary;
  final String? primaryIcon;
  final List<SdEndTile> tiles;
  final VoidCallback? onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final c = SdCmColors.of(context);
    final soft = alert ? c.redSoft : c.amberSoft;
    final ring = alert ? c.redLine : c.amberLine;
    final fg = alert ? c.red : c.amberTxt;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        key: const ValueKey('sd-end-header'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.cardLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            SdCmAvatar(name: name),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(name, key: const ValueKey('sd-end-name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(17, FontWeight.w700, c.ink, lh: 1.2)),
                if (who.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(who, key: const ValueKey('sd-end-who'), maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(12.5, FontWeight.w400, c.sub, figures: true, lh: 1.2)),
                ],
              ]),
            ),
            const SizedBox(width: 10),
            Container(
              key: const ValueKey('sd-end-bubble'),
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: soft,
                border: Border.all(color: ring.withOpacity(0.7)),
                boxShadow: [BoxShadow(color: ring.withOpacity(0.22), spreadRadius: 4)],
              ),
              child: SdIcon(alert ? SdIcons.close : SdIcons.unlink, size: 20, color: fg, stroke: 2),
            ),
          ]),
          const SizedBox(height: 13),
          Container(height: 1, color: c.divider),
          const SizedBox(height: 12),
          Row(children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: alert ? c.red : c.offIcon)),
            const SizedBox(width: 8),
            Expanded(child: Text(state, key: const ValueKey('sd-end-state'), maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(13.5, FontWeight.w500, alert ? c.redTxt : c.sub, lh: 1.2))),
            const SizedBox(width: 8),
            SdCmPill(pill,
                fill: alert ? c.redSoft : c.greenSoft,
                line: alert ? c.redLine : c.greenLine,
                fg: alert ? c.redTxt : c.greenTxt,
                icon: SdIcons.shield,
                fontSize: 11.5,
                weight: FontWeight.w500),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _SdEndTileView(tiles[i])),
        ],
      ]),
      const SizedBox(height: 12),
      Container(
        key: const ValueKey('sd-end-note'),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: alert ? c.redSoft : c.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: alert ? c.redLine : c.cardLine)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: SdIcon(SdIcons.info, size: 15, color: alert ? c.redTxt : c.mut, stroke: 1.9)),
          const SizedBox(width: 8),
          Expanded(child: Text(note, style: sdTs(12.5, FontWeight.w400, alert ? c.redTxt : c.sub, lh: 1.35))),
        ]),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: SdCmButton(key: const ValueKey('sd-end-primary'), label: primary, icon: primaryIcon, kind: SdCmBtnKind.amber, height: 40, onTap: onPrimary)),
        const SizedBox(width: 10),
        Expanded(child: SdCmButton(key: const ValueKey('sd-end-secondary'), label: secondary, kind: SdCmBtnKind.outline, height: 40, onTap: onSecondary)),
      ]),
    ]);
  }
}

class _SdEndTileView extends StatelessWidget {
  const _SdEndTileView(this.tile);
  final SdEndTile tile;

  @override
  Widget build(BuildContext context) {
    final c = SdCmColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final Color fill, line, circle, value, icon;
    switch (tile.tone) {
      case SdEndTone.amber:
        fill = c.amberSoft;
        line = c.amberLine;
        circle = c.amber;
        value = c.amberTxt;
        icon = Colors.white;
        break;
      case SdEndTone.green:
        fill = c.greenSoft;
        line = c.greenLine;
        circle = c.green;
        value = c.greenTxt;
        icon = Colors.white;
        break;
      case SdEndTone.red:
        fill = c.redSoft;
        line = c.redLine;
        circle = c.red;
        value = c.redTxt;
        icon = Colors.white;
        break;
      case SdEndTone.neutral:
        fill = c.card;
        line = c.cardLine;
        circle = dark ? c.offDot : c.offIcon;
        value = c.ink;
        icon = dark ? c.ink : Colors.white;
        break;
    }
    return Container(
      key: ValueKey('sd-end-tile-${tile.label}'),
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(14), border: Border.all(color: line, width: tile.tone == SdEndTone.neutral ? 1 : 1.2)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: circle), child: SdIcon(tile.icon, size: 17, color: icon, stroke: 2)),
        const SizedBox(height: 8),
        FittedBox(fit: BoxFit.scaleDown, child: Text(tile.value, maxLines: 1, style: sdTs(15, FontWeight.w700, value, figures: true, lh: 1.15))),
        const SizedBox(height: 3),
        Text(tile.label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(10.5, FontWeight.w500, c.mut, lh: 1.1, ls: 0.6)),
      ]),
    );
  }
}

/// The card for one reason, over the session window. [name] / [who] say which computer (its name and the OS user or ID), [peerId] is its ID as it is
/// written in the lists ("408 241 669"), [duration] how long the session ran (none when it is not known). [onReconnect] is the amber button (Reconnect, or
/// Retry Request for a refused request); [onClose] closes the session window.
class SdSessionEndDialog extends StatelessWidget {
  const SdSessionEndDialog({
    super.key,
    required this.kind,
    required this.name,
    this.who = '',
    required this.peerId,
    this.duration,
    this.onReconnect,
    required this.onClose,
    this.tr = _same,
  });

  final SdEndKind kind;
  final String name, who, peerId;
  final Duration? duration;
  final VoidCallback? onReconnect;
  final VoidCallback onClose;
  final String Function(String) tr;

  static String _same(String s) => s;

  String get _who => name.isNotEmpty ? name : (who.isNotEmpty ? who : peerId);

  String _note(String sentence) => tr(sentence).replaceFirst('{}', _who);

  @override
  Widget build(BuildContext context) {
    final rejected = kind == SdEndKind.rejected;
    final time = duration == null ? '--:--:--' : sdDurationText(duration!);
    final idTile = SdEndTile(icon: SdIcons.monitor, value: peerId, label: tr(rejected ? 'Target ID' : 'SystemDesk ID'));
    final List<SdEndTile> tiles;
    final String state, note, pill;
    switch (kind) {
      case SdEndKind.rejected:
        state = tr('Connection rejected by remote host');
        pill = tr('Access Denied');
        note = tr('The remote host declined the connection request. You can retry or check your access credentials.');
        tiles = [
          idTile,
          SdEndTile(icon: SdIcons.alertCircle, value: tr('Rejected'), label: tr('Status'), tone: SdEndTone.red),
          SdEndTile(icon: SdIcons.unlink, value: tr('Declined'), label: tr('Permission')),
        ];
        break;
      case SdEndKind.admin:
        state = tr('Ended by an administrator');
        pill = tr('E2E Encrypted');
        note = tr('An administrator closed this session from the web console. Click Reconnect to start a new request.');
        tiles = [
          SdEndTile(icon: SdIcons.clock, value: time, label: tr('Duration'), tone: SdEndTone.amber),
          idTile,
          SdEndTile(icon: SdIcons.user, value: tr('By Admin'), label: tr('Connection'), tone: SdEndTone.amber),
        ];
        break;
      case SdEndKind.inactive:
        state = tr('Ended due to inactivity');
        pill = tr('E2E Encrypted');
        note = tr('The connection was closed because nothing was received for too long. Click Reconnect to start a new request.');
        tiles = [
          SdEndTile(icon: SdIcons.clock, value: time, label: tr('Duration'), tone: SdEndTone.amber),
          idTile,
          SdEndTile(icon: SdIcons.alertCircle, value: tr('Timed Out'), label: tr('Connection'), tone: SdEndTone.amber),
        ];
        break;
      case SdEndKind.ended:
        state = tr('Ended by remote host');
        pill = tr('E2E Encrypted');
        note = _note('{} closed the remote session. Click Reconnect to start a new request.');
        tiles = [
          SdEndTile(icon: SdIcons.clock, value: time, label: tr('Duration'), tone: SdEndTone.amber),
          idTile,
          SdEndTile(icon: SdIcons.shield, value: tr('Clean Exit'), label: tr('Connection'), tone: SdEndTone.green),
        ];
        break;
    }
    return SdModal(
      opaqueBackdrop: true,
      maxWidth: 520,
      onSubmit: onReconnect ?? onClose,
      onCancel: onClose,
      content: SdSessionEndCard(
        alert: rejected,
        name: _who,
        who: name.isNotEmpty ? who : '',
        state: state,
        pill: pill,
        tiles: tiles,
        note: note,
        primary: tr(rejected ? 'Retry Request' : 'Reconnect'),
        primaryIcon: SdIcons.refresh,
        secondary: tr('Close'),
        onPrimary: onReconnect,
        onSecondary: onClose,
      ),
    );
  }
}

/// Shows the card over the session. [onReconnect] and [onClose] are run after the card is gone.
Future<void> showSdSessionEndDialog(
  OverlayDialogManager dialogManager, {
  required SdEndKind kind,
  required String name,
  String who = '',
  required String peerId,
  Duration? duration,
  required String tag,
  VoidCallback? onReconnect,
  required VoidCallback onClose,
}) {
  return dialogManager.show<void>(
    (setState, close, context) => SdSessionEndDialog(
      kind: kind,
      name: name,
      who: who,
      peerId: peerId,
      duration: duration,
      tr: translate,
      onReconnect: onReconnect == null
          ? null
          : () {
              close();
              onReconnect();
            },
      onClose: () {
        close();
        onClose();
      },
    ),
    tag: tag,
    forceGlobal: true,
  );
}
