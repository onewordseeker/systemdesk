import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:get/get.dart';

/// What the design shows of one saved computer.
class SdPeerData {
  const SdPeerData({required this.id, required this.name, required this.os, required this.online, this.user = '', this.fav = false});

  /// the ID as written in the list (408 118 204)
  final String id;
  final String name;
  final SdOs os;
  final bool online;

  /// the person signed in on that computer, shown where the design shows the delay
  final String user;
  final bool fav;
}

/// How the computers are laid out: a list of rows (the dashboard, and the list view of Devices) or the grid of cards.
enum SdPeerLayout { rows, rowsWithMenu, grid }

/// Set above a peers view to choose the layout of its cards.
class SdPeerStyle extends InheritedWidget {
  const SdPeerStyle({super.key, required this.layout, required super.child});
  final SdPeerLayout layout;

  static SdPeerLayout of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SdPeerStyle>()?.layout ?? SdPeerLayout.rows;

  @override
  bool updateShouldNotify(SdPeerStyle old) => old.layout != layout;
}

/// Tells the rows whether their column is narrow (the delay column is left out). Decided once, above the rows, so that no LayoutBuilder is needed below.
class SdCompact extends InheritedWidget {
  const SdCompact({super.key, required this.narrow, required super.child});
  final bool narrow;

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SdCompact>()?.narrow ?? false;

  @override
  bool updateShouldNotify(SdCompact old) => old.narrow != narrow;
}

/// The online / offline filter of the Devices page (all, online, offline).
final RxString sdPeerFilter = 'all'.obs;

/// The two small facts of a row: the delay column (a dot and the person on that computer) and the tag.
class _Lat extends StatelessWidget {
  const _Lat(this.p);
  final SdPeerData p;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    if (!p.online) return Text('Asleep', style: sdTs(15, FontWeight.w400, t.mut));
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: t.led, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Flexible(child: Text(p.user.isEmpty ? 'Online' : p.user, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(15, FontWeight.w400, t.ink, figures: true))),
    ]);
  }
}

/// `.crow`: one saved computer as a row.
class SdPeerRow extends StatefulWidget {
  const SdPeerRow({super.key, required this.data, this.onConnect, this.onWake, this.onTap, this.moreWrap, this.withMenu = false, this.selected = false, this.connectLabel = 'Connect', this.wakeLabel = 'Wake up'});
  final SdPeerData data;
  final VoidCallback? onConnect, onWake, onTap;

  /// picked in a selection of several computers
  final bool selected;

  /// wraps the menu button so the caller can learn where it was pressed
  final Widget Function(Widget button)? moreWrap;
  final bool withMenu;
  final String connectLabel, wakeLabel;

  @override
  State<SdPeerRow> createState() => _SdPeerRowState();
}

class _SdPeerRowState extends State<SdPeerRow> {
  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final p = widget.data;
    Widget more = const SizedBox.shrink();
    if (widget.withMenu) {
      Widget button = SdBox(
        radius: 8,
        color: t.pa,
        borderColor: t.line2,
        width: 34,
        height: 34,
        alignment: Alignment.center,
        child: SdIcon(SdIcons.dots, size: 18, color: t.ink, fill: true, stroke: 0),
      );
      if (widget.moreWrap != null) button = widget.moreWrap!(button);
      more = Padding(padding: const EdgeInsets.only(left: 16), child: button);
    }
    return Opacity(
      opacity: p.online ? 1 : 0.78,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onConnect,
        onTap: widget.onTap,
        child: Builder(builder: (context) {
          final narrow = SdCompact.of(context);
          return SdBox(
            radius: 12,
            color: widget.selected ? t.goldSoft : t.pa,
            borderColor: widget.selected ? t.goldRing : t.line,
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              SizedBox(width: 34, child: Align(alignment: Alignment.centerLeft, child: SizedBox(width: 30, height: 30, child: Center(child: SdOsIcon(p.os, ink: t.ink))))),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(16, FontWeight.w500, t.ink)),
                    Text(p.id, maxLines: 1, style: sdTs(12.5, FontWeight.w400, t.mut, figures: true)),
                  ]),
                ),
              ),
              if (!narrow) ...[
                const SizedBox(width: 16),
                SizedBox(width: 92, child: _Lat(p)),
              ],
              const SizedBox(width: 16),
              SizedBox(width: 100, child: Align(alignment: Alignment.centerLeft, child: SdTag(p.online ? 'Online' : 'Offline', kind: p.online ? SdTagKind.ok : SdTagKind.plain))),
              const SizedBox(width: 16),
              SizedBox(
                width: widget.withMenu ? 112 : 104,
                child: p.online
                    ? SdButton(label: widget.connectLabel, small: true, onTap: widget.onConnect, width: widget.withMenu ? 112 : 104)
                    : SdButton(label: widget.wakeLabel, small: true, onTap: widget.onWake, width: widget.withMenu ? 112 : 104),
              ),
              more,
            ]),
          );
        }),
      ),
    );
  }
}

/// `.dcard`: one saved computer as a card of the grid.
class SdPeerCard extends StatelessWidget {
  const SdPeerCard({
    super.key,
    required this.data,
    this.onConnect,
    this.onWake,
    this.onFiles,
    this.onFav,
    this.onTap,
    this.selected = false,
    this.moreWrap,
    this.connectLabel = 'Connect',
    this.wakeLabel = 'Wake up',
  });
  final SdPeerData data;
  final VoidCallback? onConnect, onWake, onFiles, onFav, onTap;

  /// picked in a selection of several computers
  final bool selected;
  final Widget Function(Widget button)? moreWrap;
  final String connectLabel, wakeLabel;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final p = data;
    Widget more = SdBox(
      radius: 8,
      color: t.pa,
      borderColor: t.line2,
      width: 34,
      height: 34,
      alignment: Alignment.center,
      child: SdIcon(SdIcons.dots, size: 18, color: t.ink, fill: true, stroke: 0),
    );
    if (moreWrap != null) more = moreWrap!(more);
    return Opacity(
      opacity: p.online ? 1 : 0.78,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: onConnect,
        onTap: onTap,
        child: SdBox(
          radius: 12,
          color: selected ? t.goldSoft : t.pa,
          borderColor: selected ? t.goldRing : t.line,
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              SdBox(radius: 10, color: t.chip, width: 48, height: 48, child: Center(child: SdOsIcon(p.os, ink: t.ink))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(17, FontWeight.w500, t.ink)),
                  Text(p.id, maxLines: 1, style: sdTs(12.5, FontWeight.w400, t.mut, figures: true)),
                ]),
              ),
              const SizedBox(width: 14),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onFav,
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: Center(child: SdIcon(SdIcons.star, size: 19, color: p.fav ? t.goldB : t.mut, stroke: 1.8, fill: p.fav)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              SdTag(p.online ? 'Online' : 'Offline', kind: p.online ? SdTagKind.ok : SdTagKind.plain),
              const SizedBox(width: 10),
              if (p.online)
                Flexible(child: _Lat(p))
              else
                Flexible(child: Text('Asleep or switched off', maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(14, FontWeight.w400, t.mut))),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: p.online
                    ? SdButton(label: connectLabel, small: true, kind: SdBtnKind.gold, block: true, onTap: onConnect)
                    : SdButton(label: wakeLabel, small: true, block: true, onTap: onWake),
              ),
              const SizedBox(width: 10),
              SdButton(small: true, width: 44, padding: EdgeInsets.zero, onTap: onFiles, tooltip: null, child: SdIcon(SdIcons.folder, size: 17, color: t.ink)),
              const SizedBox(width: 10),
              more,
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Lays the computers out: rows with a gap of 10, or three cards to a line with a gap of 20 (two under 980 px, one under 640 px).
class SdPeersLayout extends StatelessWidget {
  const SdPeersLayout({super.key, required this.layout, required this.children});
  final SdPeerLayout layout;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (layout != SdPeerLayout.grid) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 10), children[i]],
      ]);
    }
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 980 ? 3 : (c.maxWidth >= 640 ? 2 : 1);
      final w = (c.maxWidth - 20.0 * (cols - 1)) / cols;
      return Wrap(spacing: 20, runSpacing: 20, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
    });
  }
}
