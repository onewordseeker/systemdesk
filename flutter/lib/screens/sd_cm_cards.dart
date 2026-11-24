import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';

// The parts of the two host dialogs of the new look: the request ("wants to control this computer", Accept / Dismiss) and the connection that is going
// (who, for how long, the permissions, the recording row, Disconnect). They are drawn from plain values, with the words already translated, and know
// nothing about the connection itself: `server_page.dart` feeds them. The look follows the two design pictures (cool slate neutrals, amber for "on",
// green for "connected", red for "recording" and "disconnect").

/// The colours of the two dialogs. Light: the design pictures. Dark: the neutrals of the app's dark skin, with the same amber, green and red.
class SdCmColors {
  const SdCmColors({
    required this.card,
    required this.cardLine,
    required this.ink,
    required this.sub,
    required this.mut,
    required this.divider,
    required this.avatarA,
    required this.avatarB,
    required this.amber,
    required this.amberSoft,
    required this.amberLine,
    required this.amberTxt,
    required this.offIcon,
    required this.offDot,
    required this.chipFill,
    required this.chipTxt,
    required this.green,
    required this.greenSoft,
    required this.greenLine,
    required this.greenTxt,
    required this.red,
    required this.redSoft,
    required this.redLine,
    required this.redTxt,
  });

  final Color card, cardLine, ink, sub, mut, divider;
  final Color avatarA, avatarB;
  final Color amber, amberSoft, amberLine, amberTxt;
  final Color offIcon, offDot, chipFill, chipTxt;
  final Color green, greenSoft, greenLine, greenTxt;
  final Color red, redSoft, redLine, redTxt;

  static const SdCmColors light = SdCmColors(
    card: Color(0xFFF8F9FB),
    cardLine: Color(0xFFE3E7EE),
    ink: Color(0xFF0F172A),
    sub: Color(0xFF475569),
    mut: Color(0xFF64748B),
    divider: Color(0xFFE5E7EB),
    avatarA: Color(0xFFF5A311),
    avatarB: Color(0xFFE57C09),
    amber: Color(0xFFF59E0B),
    amberSoft: Color(0xFFFFF0CB),
    amberLine: Color(0xFFF0B84A),
    amberTxt: Color(0xFFB26A0A),
    offIcon: Color(0xFF64748B),
    offDot: Color(0xFFC4CBD8),
    chipFill: Color(0xFFF1F4F9),
    chipTxt: Color(0xFF334155),
    green: Color(0xFF1FC289),
    greenSoft: Color(0xFFD6F7E7),
    greenLine: Color(0xFFA9E3C5),
    greenTxt: Color(0xFF0B7A55),
    red: Color(0xFFDC2626),
    redSoft: Color(0xFFFEF1F1),
    redLine: Color(0xFFE8B4B0),
    redTxt: Color(0xFFA32424),
  );

  static const SdCmColors dark = SdCmColors(
    card: Color(0xFF1A1812),
    cardLine: Color(0xFF35312A),
    ink: Color(0xFFF3EFE6),
    sub: Color(0xFFCFCBC1),
    mut: Color(0xFFB4AD9E),
    divider: Color(0xFF35312A),
    avatarA: Color(0xFFF5A311),
    avatarB: Color(0xFFE57C09),
    amber: Color(0xFFF59E0B),
    amberSoft: Color(0xFF3A2A0A),
    amberLine: Color(0xFFB7791F),
    amberTxt: Color(0xFFFBBF4A),
    offIcon: Color(0xFFB4AD9E),
    offDot: Color(0xFF4B463C),
    chipFill: Color(0xFF2A261F),
    chipTxt: Color(0xFFCFCBC1),
    green: Color(0xFF2BB673),
    greenSoft: Color(0xFF10291E),
    greenLine: Color(0xFF1F5C46),
    greenTxt: Color(0xFF4BDE8A),
    red: Color(0xFFDC2626),
    redSoft: Color(0xFF3A1618),
    redLine: Color(0xFF7A2A2D),
    redTxt: Color(0xFFFF8F85),
  );

  static SdCmColors of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// The side margin of everything in the two dialogs.
const double kSdCmSide = 18;

/// The person's picture: an amber square with the first letter in white (their own picture, when they have one, is passed as [child]).
class SdCmAvatar extends StatelessWidget {
  const SdCmAvatar({super.key, required this.name, this.size = 46, this.child});
  final String name;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = SdCmColors.of(context);
    return child ??
        Container(
          key: const ValueKey('sd-cm-avatar'),
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.avatarA, c.avatarB]),
          ),
          child: Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?', style: sdTs(size * 0.48, FontWeight.w600, Colors.white, lh: 1.0)),
        );
  }
}

/// A small rounded label: the profile, "E2E Encrypted", the kind of connection, "Encrypted".
class SdCmPill extends StatelessWidget {
  const SdCmPill(this.text, {super.key, required this.fill, required this.line, required this.fg, this.icon, this.caps = false, this.fontSize = 12, this.weight = FontWeight.w500});
  final String text;
  final Color fill, line, fg;
  final String? icon;
  final bool caps;
  final double fontSize;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999), border: Border.all(color: line)),
      child: Center(
        widthFactor: 1.0,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[SdIcon(icon!, size: fontSize + 1, color: fg, stroke: 2.2), const SizedBox(width: 5)],
          Flexible(child: Text(caps ? text.toUpperCase() : text, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(fontSize, weight, fg, lh: 1.0, ls: caps ? 0.7 : 0))),
        ]),
      ),
    );
  }
}

/// The profile of the connection ("Profile: Default"), in amber.
class SdCmProfilePill extends StatelessWidget {
  const SdCmProfilePill(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = SdCmColors.of(context);
    return SdCmPill(text, fill: c.amberSoft, line: c.amberLine.withOpacity(0.55), fg: c.amberTxt, fontSize: 11, weight: FontWeight.w500);
  }
}

BoxDecoration _cardBox(SdCmColors c) => BoxDecoration(borderRadius: BorderRadius.circular(14), color: c.card, border: Border.all(color: c.cardLine));

/// The name, and under it the ID with the profile beside it. Shared by the request and the connection.
class _SdCmWho extends StatelessWidget {
  const _SdCmWho({required this.name, required this.id, required this.profile});
  final String name, id, profile;

  @override
  Widget build(BuildContext context) {
    final c = SdCmColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(17, FontWeight.w700, c.ink, lh: 1.2)),
        const SizedBox(height: 5),
        Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(id, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(12.5, FontWeight.w400, c.sub, figures: true, lh: 1.2)),
          if (profile.isNotEmpty) SdCmProfilePill(profile),
        ]),
      ],
    );
  }
}

/// A request: who asks, what for, and how it is protected.
class SdCmRequestCard extends StatelessWidget {
  const SdCmRequestCard({super.key, required this.name, required this.id, this.profile = '', required this.what, required this.kind, required this.encrypted, this.avatar});
  final String name, id, profile, what, kind, encrypted;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    final c = SdCmColors.of(context);
    return Container(
      key: const ValueKey('sd-cm-request-card'),
      margin: const EdgeInsets.fromLTRB(kSdCmSide, 20, kSdCmSide, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: _cardBox(c),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SdCmAvatar(name: name, child: avatar),
          const SizedBox(width: 14),
          Expanded(child: _SdCmWho(name: name, id: id, profile: profile)),
        ]),
        const SizedBox(height: 14),
        Text(what, style: sdTs(14, FontWeight.w400, c.sub, lh: 1.25)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          SdCmPill(encrypted, fill: c.greenSoft, line: c.greenLine, fg: c.greenTxt, icon: SdIcons.lock, fontSize: 11.5, weight: FontWeight.w600),
          SdCmPill(kind, fill: c.chipFill, line: c.cardLine, fg: c.chipTxt, caps: true, fontSize: 11, weight: FontWeight.w500),
        ]),
      ]),
    );
  }
}

/// A connection that is going: who, the chat button, and under a thin line how long it has been connected and how it is protected.
class SdCmSessionCard extends StatelessWidget {
  const SdCmSessionCard({
    super.key,
    required this.name,
    required this.id,
    this.profile = '',
    this.avatar,
    this.chat,
    required this.connected,
    required this.stateLabel,
    required this.time,
    required this.pill,
  });
  final String name, id, profile, stateLabel, pill;
  final Widget? avatar;

  /// the chat (or file transfer) button, when the connection has one
  final Widget? chat;
  final bool connected;

  /// the time connected, in the text style it is given (the caller keeps the clock)
  final Widget Function(TextStyle style) time;

  @override
  Widget build(BuildContext context) {
    final c = SdCmColors.of(context);
    final state = connected ? c.greenTxt : c.redTxt;
    return Container(
      key: const ValueKey('sd-cm-session-card'),
      margin: const EdgeInsets.fromLTRB(kSdCmSide, 20, kSdCmSide, 0),
      padding: const EdgeInsets.fromLTRB(14, 16, 12, 14),
      decoration: _cardBox(c),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SdCmAvatar(name: name, child: avatar),
          const SizedBox(width: 14),
          Expanded(child: _SdCmWho(name: name, id: id, profile: profile)),
          if (chat != null) ...[const SizedBox(width: 10), chat!],
        ]),
        const SizedBox(height: 13),
        Container(height: 1, color: c.divider),
        const SizedBox(height: 12),
        Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: connected ? c.green : c.red)),
          const SizedBox(width: 8),
          Text(stateLabel, style: sdTs(13.5, FontWeight.w500, state, lh: 1.2)),
          const SizedBox(width: 6),
          Text(String.fromCharCode(0x00B7), style: sdTs(13.5, FontWeight.w500, state, lh: 1.2)),
          const SizedBox(width: 6),
          time(sdTs(13.5, FontWeight.w400, state, figures: true, lh: 1.2)),
          const SizedBox(width: 8),
          Expanded(child: Align(alignment: Alignment.centerRight, child: SdCmPill(pill, fill: c.greenSoft, line: c.greenLine, fg: c.greenTxt, fontSize: 11.5, weight: FontWeight.w500))),
        ]),
      ]),
    );
  }
}

/// The round button on the card that opens the chat (or the file transfer): white, an amber outline of the icon, the unread count on its corner.
class SdCmChatCircle extends StatelessWidget {
  const SdCmChatCircle({super.key, required this.icon, required this.onTap, this.badge, this.tooltip});
  final String icon;
  final VoidCallback onTap;
  final Widget? badge;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = SdCmColors.of(context);
    Widget w = Stack(clipBehavior: Clip.none, children: [
      MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: const ValueKey('sd-cm-chat'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).brightness == Brightness.dark ? c.amberSoft : Colors.white, border: Border.all(color: c.cardLine)),
            child: SdIcon(icon, size: 18, color: c.amberTxt, stroke: 2),
          ),
        ),
      ),
      if (badge != null) Positioned(right: -5, top: -5, child: badge!),
    ]);
    if (tooltip != null) w = Tooltip(message: tooltip!, child: w);
    return w;
  }
}

/// One permission: its icon and name, a dot in the corner that is amber when it is on and grey when it is off.
class SdCmTile {
  const SdCmTile({required this.icon, required this.label, required this.on, required this.tip, this.onTap});
  final String icon, label, tip;
  final bool on;

  /// null: the owner may not change it in this window
  final VoidCallback? onTap;
}

class SdCmTileView extends StatelessWidget {
  const SdCmTileView(this.tile, {super.key});
  final SdCmTile tile;

  @override
  Widget build(BuildContext context) {
    final c = SdCmColors.of(context);
    final on = tile.on;
    final fg = on ? c.amberTxt : c.offIcon;
    return Tooltip(
      message: '${tile.tip}: ${on ? "ON" : "OFF"}',
      waitDuration: Duration.zero,
      child: MouseRegion(
        cursor: tile.onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tile.onTap,
          child: Opacity(
            opacity: tile.onTap == null ? 0.7 : 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: on ? c.amberSoft : c.card,
                border: Border.all(color: on ? c.amberLine : c.cardLine, width: on ? 1.2 : 1),
              ),
              child: Stack(children: [
                Positioned(top: 7, right: 8, child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: on ? c.amber : c.offDot))),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SdIcon(tile.icon, size: 20, color: fg, stroke: 1.8),
                      const SizedBox(height: 6),
                      Text(tile.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: sdTs(11.5, FontWeight.w500, fg, lh: 1.15)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The permissions: a title (with a hint on the right when there is one) over a grid of four tiles a row.
class SdCmTileGrid extends StatelessWidget {
  const SdCmTileGrid({super.key, required this.title, this.hint, required this.tiles});
  final String title;
  final String? hint;
  final List<SdCmTile> tiles;

  static const double tileHeight = 60;
  static const double gap = 10;

  @override
  Widget build(BuildContext context) {
    final c = SdCmColors.of(context);
    return Padding(
      key: const ValueKey('sd-cm-tiles'),
      padding: const EdgeInsets.fromLTRB(kSdCmSide, 22, kSdCmSide, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: sdTs(14.5, FontWeight.w700, c.ink, lh: 1.2)),
          if (hint != null) Text(hint!, style: sdTs(12.5, FontWeight.w400, c.mut, lh: 1.2)),
        ]),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - gap * 3) / 4;
          return Wrap(spacing: gap, runSpacing: gap, children: [for (final t in tiles) SizedBox(width: w, height: tileHeight, child: SdCmTileView(t))]);
        }),
      ]),
    );
  }
}

enum SdCmBtnKind { amber, outline, red, dark }

/// The big buttons: Accept (amber), Dismiss (white, outlined), Disconnect (red), and the dark one for "Accept and elevate".
class SdCmButton extends StatefulWidget {
  const SdCmButton({super.key, required this.label, required this.kind, required this.onTap, this.height = 36, this.tooltip, this.icon});
  final String label;
  final SdCmBtnKind kind;
  final VoidCallback? onTap;
  final double height;
  final String? tooltip;

  /// a small drawing (SdIcons) in front of the words
  final String? icon;

  @override
  State<SdCmButton> createState() => _SdCmButtonState();
}

class _SdCmButtonState extends State<SdCmButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = SdCmColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    Color fill, line, fg;
    switch (widget.kind) {
      case SdCmBtnKind.amber:
        fill = c.amber;
        line = c.amber;
        fg = Colors.white;
        break;
      case SdCmBtnKind.red:
        fill = c.red;
        line = c.red;
        fg = Colors.white;
        break;
      case SdCmBtnKind.dark:
        fill = dark ? const Color(0xFFF3EFE6) : const Color(0xFF0F172A);
        line = fill;
        fg = dark ? const Color(0xFF1A1712) : Colors.white;
        break;
      case SdCmBtnKind.outline:
        fill = dark ? c.card : Colors.white;
        line = c.cardLine;
        fg = c.ink;
        break;
    }
    final enabled = widget.onTap != null;
    Widget box = Container(
      height: widget.height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(9), border: Border.all(color: line)),
      child: widget.icon == null
          ? Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(14, FontWeight.w600, fg, lh: 1.2))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              SdIcon(widget.icon!, size: 16, color: fg, stroke: 2),
              const SizedBox(width: 8),
              Flexible(child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(14, FontWeight.w600, fg, lh: 1.2))),
            ]),
    );
    if (_hover && enabled) {
      box = Stack(children: [
        box,
        Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(color: widget.kind == SdCmBtnKind.outline ? const Color(0x0F0F172A) : const Color(0x14000000), borderRadius: BorderRadius.circular(10))))),
      ]);
    }
    Widget w = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: Opacity(opacity: enabled ? 1 : 0.55, child: box)),
    );
    if (widget.tooltip != null) w = Tooltip(message: widget.tooltip!, child: w);
    return w;
  }
}

/// The row of the owner's own recording of the session. Recording: pale red, "Recording session", the way to the folder and Stop. Not recording: a
/// plain row with Record. With "record every session" on in the settings there is nothing to press, only the way to the folder.
class SdCmRecordRow extends StatelessWidget {
  const SdCmRecordRow({
    super.key,
    required this.recording,
    this.always = false,
    this.dir = '',
    required this.onToggle,
    required this.onOpenFolder,
    required this.labels,
  });
  final bool recording, always;

  /// where the file goes (shown as a tip over the row)
  final String dir;
  final VoidCallback onToggle, onOpenFolder;

  /// the words: [recordingNow], [idle], [stop], [record], [openFolder], [everySession]
  final SdCmRecordLabels labels;

  @override
  Widget build(BuildContext context) {
    final c = SdCmColors.of(context);
    final fg = recording ? c.redTxt : c.ink;
    final row = Container(
      key: const ValueKey('sd-cm-record-row'),
      height: 40,
      margin: const EdgeInsets.fromLTRB(kSdCmSide, 12, kSdCmSide, 0),
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
      decoration: BoxDecoration(
        color: recording ? c.redSoft : c.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: recording ? c.redLine : c.cardLine),
      ),
      child: Row(children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: recording ? const Color(0xFFE5484D) : c.offDot,
            boxShadow: recording ? [BoxShadow(color: const Color(0xFFE5484D).withOpacity(0.25), spreadRadius: 3)] : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(recording ? (always ? labels.everySession : labels.recordingNow) : labels.idle, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(13.5, FontWeight.w400, fg, lh: 1.2)),
        ),
        if (recording) ...[
          const SizedBox(width: 8),
          GestureDetector(
            key: const ValueKey('sd-host-record-folder'),
            behavior: HitTestBehavior.opaque,
            onTap: onOpenFolder,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(labels.openFolder, style: sdTs(12.5, FontWeight.w500, c.redTxt, lh: 1.2, decoration: TextDecoration.underline)),
            ),
          ),
        ],
        if (!always) ...[
          const SizedBox(width: 10),
          GestureDetector(
            key: const ValueKey('sd-host-record-toggle'),
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: recording ? c.red : c.amberSoft,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: recording ? c.red : c.amberLine),
                ),
                child: Text(recording ? labels.stop : labels.record, style: sdTs(12, FontWeight.w600, recording ? Colors.white : c.amberTxt, lh: 1.0)),
              ),
            ),
          ),
        ],
      ]),
    );
    return recording && dir.isNotEmpty ? Tooltip(message: '${labels.savedIn} $dir', child: row) : row;
  }
}

/// The words of [SdCmRecordRow].
class SdCmRecordLabels {
  const SdCmRecordLabels({
    this.recordingNow = 'Recording session',
    this.idle = 'Record this session',
    this.stop = 'Stop',
    this.record = 'Record',
    this.openFolder = 'Open folder',
    this.everySession = 'Recording every session',
    this.savedIn = 'Saved in',
  });
  final String recordingNow, idle, stop, record, openFolder, everySession, savedIn;
}

