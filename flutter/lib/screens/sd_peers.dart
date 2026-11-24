import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:get/get.dart';

/// What the design shows of one saved computer.
class SdPeerData {
  const SdPeerData({required this.id, required this.name, required this.os, required this.online, this.user = '', this.fav = false, this.thumb = ''});

  /// the ID as written in the list (408 118 204)
  final String id;
  final String name;
  final SdOs os;
  final bool online;

  /// the file of the picture of that computer (its desktop background, kept when it was last controlled from here), or empty when there is none
  final String thumb;

  /// the person signed in on that computer, shown where the design shows the delay
  final String user;
  final bool fav;
}

/// How the computers are laid out: a list of rows (the dashboard, and the list view of Devices), the grid of cards, or the grid of pictures (each card is
/// the desktop background of that computer).
enum SdPeerLayout { rows, rowsWithMenu, grid, pictures }

/// The least width of a computer's card in the grid: the grid has as many columns as fit at this width.
const double kSdCardMinWidth = 250;

/// The same for a card with a picture.
const double kSdPictureMinWidth = 230;

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

/// Keeps the star of a card in step with the list of favourites. It listens to [listenable] (the list), so a change of the list shows on the card at once,
/// without waiting for the page to be built again. A press shows its result on the star straight away ([builder]'s `pressed`); the list confirms it a moment
/// later, and when it does not within [pendingFor] the star goes back to what the list says.
class SdFavFollower extends StatefulWidget {
  const SdFavFollower({super.key, required this.listenable, required this.stored, required this.builder, this.pendingFor = const Duration(seconds: 3)});
  final Listenable listenable;

  /// is this computer in the list of favourites now
  final bool Function() stored;
  final Widget Function(BuildContext context, bool fav, void Function(bool next) pressed) builder;
  final Duration pendingFor;

  @override
  State<SdFavFollower> createState() => _SdFavFollowerState();
}

class _SdFavFollowerState extends State<SdFavFollower> {
  bool? _pending;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _pressed(bool next) {
    setState(() => _pending = next);
    _timer?.cancel();
    _timer = Timer(widget.pendingFor, () {
      if (mounted) setState(() => _pending = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.listenable,
      builder: (context, _) {
        final stored = widget.stored();
        // the list agrees with the press: from now on it is the list that counts
        if (_pending != null && _pending == stored) _pending = null;
        return widget.builder(context, _pending ?? stored, _pressed);
      },
    );
  }
}

/// The height of the photo across the top of a card of the grid.
const double kSdCardBannerHeight = 88;

const ColorFilter _kSdGrey = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

/// `.dcard`: one saved computer as a card of the grid (the Dashboard and the cards of Devices). Across the top of the card is the photo of that computer, or,
/// when it has none yet, the logo of its system on a plain ground, so every card is as high as the next. The logo of the system is a small badge on the photo.
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
    this.repaint,
  });
  final SdPeerData data;
  final VoidCallback? onConnect, onWake, onFiles, onFav, onTap;

  /// picked in a selection of several computers
  final bool selected;
  final Widget Function(Widget button)? moreWrap;
  final String connectLabel, wakeLabel;

  /// changes when a picture was saved: the card reads its file again
  final ValueListenable<int>? repaint;

  /// The photo (or the logo on a plain ground), the badge of the system on a photo, and the star at the top right.
  Widget _banner(SdSkin t) {
    final p = data;
    final hasPhoto = p.thumb.isNotEmpty;
    Widget placeholder() => ColoredBox(color: t.chip, child: Center(child: SdOsIcon(p.os, size: 38, ink: t.mut)));
    Widget image(int version) => SizedBox.expand(
          key: const ValueKey('sd-card-photo'),
          child: Image.file(
            File(p.thumb),
            key: ValueKey('${p.thumb}#$version'),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => placeholder(),
          ),
        );
    Widget picture = !hasPhoto ? placeholder() : (repaint == null ? image(0) : ValueListenableBuilder<int>(valueListenable: repaint!, builder: (_, v, __) => image(v)));
    // a computer that is off is shown in grey, like the card of the pictures view
    if (!p.online && hasPhoto) picture = ColorFiltered(colorFilter: _kSdGrey, child: picture);
    final star = SdIcon(SdIcons.star, size: 19, color: p.fav ? t.goldB : (hasPhoto ? Colors.white : t.mut), stroke: 1.8, fill: p.fav);
    return SizedBox(
      key: const ValueKey('sd-card-banner'),
      height: kSdCardBannerHeight,
      child: Stack(fit: StackFit.expand, children: [
        picture,
        if (hasPhoto)
          Positioned(
            left: 12,
            bottom: 10,
            child: Container(
              key: const ValueKey('sd-card-badge'),
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: t.pa, borderRadius: BorderRadius.circular(8)),
              child: Center(child: SdOsIcon(p.os, size: 17, ink: t.ink)),
            ),
          ),
        Positioned(
          right: 6,
          top: 6,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              key: const ValueKey('sd-card-fav'),
              behavior: HitTestBehavior.opaque,
              onTap: onFav,
              // on a photo the star sits on a soft dark disc, so it shows on a light picture too
              child: Container(
                width: 30,
                height: 30,
                decoration: hasPhoto ? const BoxDecoration(color: Color(0x59000000), shape: BoxShape.circle) : null,
                child: Center(child: star),
              ),
            ),
          ),
        ),
      ]),
    );
  }

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
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // the card has a 1 pixel border: the photo is rounded one pixel less
            ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(11)), child: _banner(t)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(17, FontWeight.w500, t.ink)),
                Text(p.id, maxLines: 1, style: sdTs(12.5, FontWeight.w400, t.mut, figures: true)),
                const SizedBox(height: 12),
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
          ]),
        ),
      ),
    );
  }
}

/// A computer as a picture: its desktop background fills the card, its name and ID are at the bottom, the green or red dot at the top left says whether it
/// is online, and the star is at the top right. A computer that was never controlled from here has no picture yet: its card shows the logo of its system.
/// Pointing at a card shows what can be done with it (connect or wake it, its files). An offline computer is shown in grey.
class SdPeerPictureCard extends StatefulWidget {
  const SdPeerPictureCard({
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
    this.repaint,
  });
  final SdPeerData data;
  final VoidCallback? onConnect, onWake, onFiles, onFav, onTap;

  /// picked in a selection of several computers
  final bool selected;
  final Widget Function(Widget button)? moreWrap;
  final String connectLabel, wakeLabel;

  /// changes when a picture was saved: the card reads its file again
  final ValueListenable<int>? repaint;

  @override
  State<SdPeerPictureCard> createState() => _SdPeerPictureCardState();
}

class _SdPeerPictureCardState extends State<SdPeerPictureCard> {
  bool _hover = false;

  static const _grey = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final p = widget.data;
    Widget placeholder() => ColoredBox(color: t.chip, child: Center(child: SdOsIcon(p.os, size: 46, ink: t.mut)));
    Widget image(int version) => Image.file(
          File(p.thumb),
          key: ValueKey('${p.thumb}#$version'),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => placeholder(),
        );
    Widget picture = p.thumb.isEmpty
        ? placeholder()
        : (widget.repaint == null ? image(0) : ValueListenableBuilder<int>(valueListenable: widget.repaint!, builder: (_, v, __) => image(v)));
    if (!p.online) picture = ColorFiltered(colorFilter: _grey, child: picture);

    Widget more = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: const Color(0x73000000), borderRadius: BorderRadius.circular(8)),
      child: Center(child: SdIcon(SdIcons.dots, size: 18, color: Colors.white, fill: true, stroke: 0)),
    );
    if (widget.moreWrap != null) more = widget.moreWrap!(more);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        key: const ValueKey('sd-picture-card'),
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onConnect,
        onTap: widget.onTap,
        child: AspectRatio(
          aspectRatio: 1.6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.selected ? t.goldRing : t.line, width: widget.selected ? 2 : 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(fit: StackFit.expand, children: [
                picture,
                if (!p.online) const ColoredBox(color: Color(0x59000000)),
                // the bottom: a dark fade, so the name and the ID read on any picture
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 78,
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xCC000000)])),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 54,
                  bottom: 11,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(14.5, FontWeight.w600, Colors.white)),
                    Text(p.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(12, FontWeight.w400, const Color(0xCCFFFFFF), figures: true)),
                  ]),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    key: const ValueKey('sd-picture-led'),
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: p.online ? t.led : t.bad, border: Border.all(color: Colors.white, width: 1.5)),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      key: const ValueKey('sd-picture-fav'),
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onFav,
                      child: SizedBox(width: 32, height: 32, child: Center(child: SdIcon(SdIcons.star, size: 19, color: p.fav ? t.goldB : Colors.white, stroke: 1.8, fill: p.fav))),
                    ),
                  ),
                ),
                Positioned(right: 8, bottom: 8, child: more),
                if (_hover)
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0x59000000),
                      child: Center(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          p.online
                              ? SdButton(key: const ValueKey('sd-picture-connect'), label: widget.connectLabel, small: true, kind: SdBtnKind.gold, onTap: widget.onConnect)
                              : SdButton(key: const ValueKey('sd-picture-wake'), label: widget.wakeLabel, small: true, onTap: widget.onWake),
                          const SizedBox(width: 10),
                          SdButton(key: const ValueKey('sd-picture-files'), small: true, width: 44, padding: EdgeInsets.zero, onTap: widget.onFiles, child: SdIcon(SdIcons.folder, size: 17, color: t.ink)),
                        ]),
                      ),
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

/// Lays the computers out: rows with a gap of 10, or three cards to a line with a gap of 20 (two under 980 px, one under 640 px).
class SdPeersLayout extends StatelessWidget {
  const SdPeersLayout({super.key, required this.layout, required this.children});
  final SdPeerLayout layout;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (layout == SdPeerLayout.pictures) {
      return LayoutBuilder(builder: (context, c) {
        // more, smaller cards than the grid: as many columns as fit at the least width of a picture (at most five)
        final cols = ((c.maxWidth + 16) / (kSdPictureMinWidth + 16)).floor().clamp(1, 5);
        final w = (c.maxWidth - 16.0 * (cols - 1)) / cols;
        return Wrap(spacing: 16, runSpacing: 16, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
      });
    }
    if (layout != SdPeerLayout.grid) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 10), children[i]],
      ]);
    }
    return LayoutBuilder(builder: (context, c) {
      // as many columns as fit at a card's least width (at most three): a restored window keeps the look of a maximised one, with fewer columns
      final cols = ((c.maxWidth + 20) / (kSdCardMinWidth + 20)).floor().clamp(1, 3);
      final w = (c.maxWidth - 20.0 * (cols - 1)) / cols;
      return Wrap(spacing: 20, runSpacing: 20, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
    });
  }
}
