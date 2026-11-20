import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';

/// The controls of the app design, measured from its style sheet. Every size, colour, corner and shadow below is a number of that sheet.

/// `.panel`: the raised panel the page is built from.
class SdPanel extends StatelessWidget {
  const SdPanel({super.key, this.child, this.padding, this.radius = 12, this.width, this.height, this.margin});
  final Widget? child;
  final EdgeInsetsGeometry? padding, margin;
  final double radius;
  final double? width, height;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return SdBox(
      radius: radius,
      color: t.pa,
      borderColor: t.line,
      padding: padding,
      width: width,
      height: height,
      margin: margin,
      child: child,
    );
  }
}

/// `.navy`: the dark blue panel (Quick Connect, Active now).
class SdNavyPanel extends StatelessWidget {
  const SdNavyPanel({super.key, this.child, this.padding, this.radius = 12});
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return SdBox(radius: radius, color: t.navyA, padding: padding, child: child);
  }
}

/// `.inset` (and `.ring` with [ring]): a field pressed into the page.
class SdInset extends StatelessWidget {
  const SdInset({super.key, this.child, this.radius = 10, this.ring = false, this.padding, this.width, this.height, this.constraints});
  final Widget? child;
  final double radius;
  final bool ring;
  final EdgeInsetsGeometry? padding;
  final double? width, height;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return SdBox(
      radius: radius,
      color: t.ia,
      borderColor: ring ? t.goldRing : t.line2,
      borderWidth: ring ? 1.5 : 1,
      padding: padding,
      width: width,
      height: height,
      constraints: constraints,
      child: child,
    );
  }
}

enum SdBtnKind { plain, gold, navy, bad }

/// `.btn`, `.btn-gold`, `.btn-navy`, `.btn-bad` (size 44 high) and `.btn-sm` (34 high), `.btn-ico` (56 x 40).
class SdButton extends StatefulWidget {
  const SdButton({
    super.key,
    this.label,
    this.child,
    this.icon,
    this.onTap,
    this.kind = SdBtnKind.plain,
    this.small = false,
    this.block = false,
    this.width,
    this.height,
    this.padding,
    this.fontSize,
    this.tooltip,
    this.busy = false,
  });
  final String? label;
  final Widget? child;
  final String? icon;
  final VoidCallback? onTap;
  final SdBtnKind kind;
  final bool small, block, busy;
  final double? width, height, fontSize;
  final EdgeInsetsGeometry? padding;
  final String? tooltip;

  @override
  State<SdButton> createState() => _SdButtonState();
}

class _SdButtonState extends State<SdButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final k = widget.kind;
    final enabled = widget.onTap != null && !widget.busy;
    // flat: a fill and a hairline, the accent for the main action, solid red for the one that ends something
    Color fill, border, fg;
    switch (k) {
      case SdBtnKind.gold:
        fill = t.goldB;
        border = t.goldB;
        fg = t.goldInk;
        break;
      case SdBtnKind.navy:
        fill = t.navyA;
        border = t.navyA;
        fg = t.navyInk;
        break;
      case SdBtnKind.bad:
        fill = const Color(0xFFB42318);
        border = const Color(0xFFB42318);
        fg = Colors.white;
        break;
      case SdBtnKind.plain:
        fill = t.pa;
        border = t.line2;
        fg = t.ink;
        break;
    }
    final List<BoxShadow> shadows = const [];
    final small = widget.small;
    final h = widget.height ?? (small ? 34.0 : 44.0);
    final r = small ? 8.0 : 10.0;
    final fs = widget.fontSize ?? (small ? 13.5 : 15.0);
    Widget content = widget.child ??
        Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          if (widget.busy)
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
          else ...[
            if (widget.icon != null) ...[SdIcon(widget.icon!, size: small ? 16 : 18, color: fg), const SizedBox(width: 8)],
            if (widget.label != null) Flexible(child: Text(widget.label!, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(fs, FontWeight.w500, fg))),
          ],
        ]);
    Widget box = SdBox(
      radius: r,
      color: fill,
      borderColor: border,
      shadows: shadows,
      height: h,
      width: widget.width,
      padding: widget.padding ?? EdgeInsets.symmetric(horizontal: small ? 14 : 20),
      alignment: Alignment.center,
      child: content,
    );
    if (_hover && enabled) {
      // a plain button takes the sunken colour, a filled one gets a little darker
      final over = k == SdBtnKind.plain ? t.chip.withOpacity(0.7) : const Color(0x14000000);
      box = Stack(children: [box, Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(color: over, borderRadius: BorderRadius.circular(r)))))]);
    }
    Widget w = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? widget.onTap : null,
        child: Opacity(opacity: widget.onTap == null && !widget.busy ? 0.55 : 1, child: box),
      ),
    );
    if (widget.block) w = SizedBox(width: double.infinity, child: w);
    if (widget.tooltip != null) w = Tooltip(message: widget.tooltip!, waitDuration: const Duration(milliseconds: 700), child: w);
    return w;
  }
}

/// `.btn.btn-ico`: a square icon button (56 x 40, or [width] x [height]).
class SdIconButton extends StatelessWidget {
  const SdIconButton({super.key, required this.icon, this.onTap, this.tooltip, this.width = 56, this.height = 40, this.small = false});
  final String icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double width, height;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return SdButton(
      onTap: onTap,
      tooltip: tooltip,
      width: width,
      height: height,
      small: small,
      padding: EdgeInsets.zero,
      child: SdIcon(icon, size: 19, color: t.ink, stroke: 1.8),
    );
  }
}

/// `.onoff`: the ON | OFF toggle.
class SdOnOff extends StatelessWidget {
  const SdOnOff({super.key, required this.value, this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    // a switch: the amber track with the knob at the right when it is on, a grey track with the knob at the left when it is off
    return Opacity(
      opacity: onChanged == null ? 0.6 : 1,
      child: MouseRegion(
        cursor: onChanged == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onChanged == null ? null : () => onChanged!(!value),
          child: Semantics(
            toggled: value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 38,
              height: 22,
              decoration: BoxDecoration(color: value ? t.goldB : t.line2, borderRadius: BorderRadius.circular(11)),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 140),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x4D000000), blurRadius: 2, offset: Offset(0, 1))]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum SdTagKind { plain, ok, gold, bad }

/// `.tag`: a small upper-case pill (ONLINE, REMOTE CONTROL).
class SdTag extends StatelessWidget {
  const SdTag(this.label, {super.key, this.kind = SdTagKind.plain, this.onNavy = false});
  final String label;
  final SdTagKind kind;
  final bool onNavy;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    Color bg = onNavy ? const Color(0x1AFFFFFF) : t.chip;
    Color fg = onNavy ? const Color(0xFFD9E0EF) : t.mut;
    if (kind == SdTagKind.ok) fg = t.ok;
    if (kind == SdTagKind.bad) fg = t.bad;
    if (kind == SdTagKind.gold) {
      bg = t.goldSoft;
      fg = t.goldTxt;
    }
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label.toUpperCase(), maxLines: 1, style: sdTs(11, FontWeight.w600, fg, ls: 0.77, lh: 1.0)),
    );
  }
}

/// `.led`: the green dot of "Ready".
class SdLed extends StatelessWidget {
  const SdLed({super.key, this.size = 12, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final c = color ?? t.led;
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: c));
  }
}

/// `.meter`: the thin bar (today's minutes). [value] 0..1.
class SdMeter extends StatelessWidget {
  const SdMeter({super.key, required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return SdBox(
      radius: 99,
      color: t.line,
      height: 6,
      child: LayoutBuilder(
        builder: (_, c) => Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: c.maxWidth * value.clamp(0.0, 1.0),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), color: t.goldB),
          ),
        ),
      ),
    );
  }
}

/// `.seg`: the segmented tabs (Recent / Favorites / ...).
class SdSeg<T> extends StatelessWidget {
  const SdSeg({super.key, required this.items, required this.value, required this.onChanged, this.itemPadding = 14, this.icons = false});
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;
  final double itemPadding;
  final bool icons;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return SdBox(
      radius: 10,
      color: t.chip,
      borderColor: t.line,
      padding: const EdgeInsets.all(3),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          _SegItem(
            selected: items[i].$1 == value,
            padding: itemPadding,
            onTap: () => onChanged(items[i].$1),
            label: icons ? null : items[i].$2,
            icon: icons ? items[i].$2 : null,
            semantic: items[i].$2,
          ),
        ],
      ]),
    );
  }
}

class _SegItem extends StatefulWidget {
  const _SegItem({required this.selected, required this.onTap, required this.padding, this.label, this.icon, this.semantic});
  final bool selected;
  final VoidCallback onTap;
  final double padding;
  final String? label, icon, semantic;

  @override
  State<_SegItem> createState() => _SegItemState();
}

class _SegItemState extends State<_SegItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final on = widget.selected;
    final fg = on ? t.ink : (_hover ? t.ink : t.mut);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Semantics(
          button: true,
          selected: on,
          label: widget.semantic,
          child: SdBox(
            radius: 7,
            color: on ? t.pa : null,
            shadows: on ? [BoxShadow(color: t.sh2, blurRadius: 3, offset: const Offset(0, 1))] : const [],
            height: 30,
            padding: EdgeInsets.symmetric(horizontal: widget.padding),
            alignment: Alignment.center,
            child: widget.icon != null
                ? SdIcon(widget.icon!, size: 17, color: fg, stroke: 2)
                : Text(widget.label ?? '', maxLines: 1, style: sdTs(14, on ? FontWeight.w500 : FontWeight.w400, fg)),
          ),
        ),
      ),
    );
  }
}

/// `.sel`: a select button (44 high); the list under it is [SdMenu].
class SdSelect extends StatelessWidget {
  const SdSelect({super.key, required this.label, this.onTap, this.small = false, this.expanded = false});
  final String label;
  final VoidCallback? onTap;
  final bool small, expanded;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SdBox(
          radius: 8,
          color: t.pa,
          borderColor: t.line2,
          height: small ? 34 : 40,
          constraints: small ? const BoxConstraints(minWidth: 150) : null,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(mainAxisSize: small ? MainAxisSize.min : MainAxisSize.max, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(small ? 14 : 15, FontWeight.w400, t.ink))),
            const SizedBox(width: 10),
            SdIcon(SdIcons.chevronDown, size: small ? 16 : 18, color: t.ink, stroke: 2),
          ]),
        ),
      ),
    );
  }
}

/// `.menu`: the list of a select or of a context menu.
class SdMenu extends StatelessWidget {
  const SdMenu({super.key, required this.children, this.width, this.shadow = false});
  final List<Widget> children;
  final double? width;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return SdBox(
      radius: 12,
      color: t.pa,
      borderColor: t.line2,
      width: width,
      shadows: t.floatShadows,
      padding: const EdgeInsets.all(6),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 2), children[i]],
      ]),
    );
  }
}

/// `.menu button`: one line of a menu (36 high).
class SdMenuItem extends StatefulWidget {
  const SdMenuItem({super.key, required this.label, this.icon, this.selected = false, this.onTap, this.danger = false, this.trailingCheck = false});
  final String label;
  final String? icon;
  final bool selected, danger, trailingCheck;
  final VoidCallback? onTap;

  @override
  State<SdMenuItem> createState() => _SdMenuItemState();
}

class _SdMenuItemState extends State<SdMenuItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final fg = widget.danger ? t.bad : t.ink;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: widget.selected || _hover ? t.chip : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            if (widget.icon != null) ...[SdIcon(widget.icon!, size: 17, color: fg, stroke: 1.9), const SizedBox(width: 10)],
            Expanded(child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(15, widget.selected ? FontWeight.w500 : FontWeight.w400, fg))),
            if (widget.trailingCheck) SdIcon(SdIcons.check, size: 17, color: t.goldTxt, stroke: 2.4),
          ]),
        ),
      ),
    );
  }
}

/// `.hr`: the hairline with its white edge underneath.
class SdHr extends StatelessWidget {
  const SdHr({super.key, this.margin = EdgeInsets.zero});
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return Padding(padding: margin, child: Container(height: 1, color: t.line));
  }
}

/// `.pill-gold`: the plan pill and its like (a star, a text).
class SdGoldPill extends StatelessWidget {
  const SdGoldPill({super.key, required this.label, this.onTap, this.star = true, this.maxWidth = 330});
  final String label;
  final VoidCallback? onTap;
  final bool star;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 34,
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: t.pa, border: Border.all(color: t.line2)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (star) ...[
              SdIcon(SdIcons.star, size: 15, color: t.goldB, stroke: 1.5, fill: true),
              const SizedBox(width: 7),
            ],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(13.5, FontWeight.w500, t.ink))),
          ]),
        ),
      ),
    );
  }
}

/// `.ibtn`: the round icon button of the header (the bell).
class SdRoundButton extends StatefulWidget {
  const SdRoundButton({super.key, required this.child, this.onTap, this.tooltip, this.dot = false, this.size = 42});
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool dot;
  final double size;

  @override
  State<SdRoundButton> createState() => _SdRoundButtonState();
}

class _SdRoundButtonState extends State<SdRoundButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    Widget w = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(clipBehavior: Clip.none, children: [
            SdBox(
              radius: 10,
              color: _hover ? t.chip : null,
              width: widget.size,
              height: widget.size,
              alignment: Alignment.center,
              child: widget.child,
            ),
            if (widget.dot)
              Positioned(
                top: 7,
                right: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: t.goldB, shape: BoxShape.circle, border: Border.all(color: t.chrome, width: 2)),
                ),
              ),
          ]),
        ),
      ),
    );
    if (widget.tooltip != null) w = Tooltip(message: widget.tooltip!, waitDuration: const Duration(milliseconds: 700), child: w);
    return w;
  }
}

/// One text tab: ink and a 2 px amber line when open, muted when not (the tabs of the lists of computers).
class SdTextTab extends StatefulWidget {
  const SdTextTab({super.key, required this.label, required this.selected, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<SdTextTab> createState() => _SdTextTabState();
}

class _SdTextTabState extends State<SdTextTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final on = widget.selected;
    return MouseRegion(
      cursor: widget.onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Semantics(
          button: true,
          selected: on,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 2, color: on ? t.goldB : Colors.transparent))),
            alignment: Alignment.center,
            child: Text(widget.label, maxLines: 1, style: sdTs(14.5, on ? FontWeight.w600 : FontWeight.w400, on || _hover ? t.ink : t.mut)),
          ),
        ),
      ),
    );
  }
}

/// A small flat icon button (32 x 32): the tools of a list, the copy and refresh buttons of the "This computer" panel. [active] puts the amber wash behind it.
class SdToolButton extends StatefulWidget {
  const SdToolButton({super.key, required this.icon, this.tooltip, this.onTap, this.active = false, this.color});
  final String icon;
  final String? tooltip;
  final VoidCallback? onTap;
  final bool active;
  final Color? color;

  @override
  State<SdToolButton> createState() => _SdToolButtonState();
}

class _SdToolButtonState extends State<SdToolButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final on = widget.active;
    Widget w = MouseRegion(
      cursor: widget.onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Opacity(
          opacity: widget.onTap == null ? 0.45 : 1,
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: on ? t.goldSoft : (_hover && widget.onTap != null ? t.chip : Colors.transparent), borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: SdIcon(widget.icon, size: 18, color: widget.color ?? (on ? t.goldTxt : t.mut), stroke: 1.9),
          ),
        ),
      ),
    );
    if (widget.tooltip != null) w = Tooltip(message: widget.tooltip!, waitDuration: const Duration(milliseconds: 600), child: w);
    return w;
  }
}

/// `.avatar`: the round navy button with the person's initials.
class SdAvatar extends StatelessWidget {
  const SdAvatar({super.key, required this.initials, this.onTap, this.size = 42, this.tooltip});
  final String initials;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    Widget w = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: t.goldSoft),
          child: initials.isEmpty
              ? SdIcon(SdIcons.user, size: 19, color: t.goldTxt, stroke: 1.9)
              : Text(initials, style: sdTs(14, FontWeight.w600, t.goldTxt, lh: 1.0)),
        ),
      ),
    );
    if (tooltip != null) w = Tooltip(message: tooltip!, waitDuration: const Duration(milliseconds: 700), child: w);
    return w;
  }
}

/// `.ptile`: a permission of the approval window as a tile (84 high): pressed in gold ring when it is on, sunk and grey when it is off.
class SdPermTile extends StatelessWidget {
  const SdPermTile({super.key, required this.icon, required this.label, required this.on, this.onTap});
  final String icon, label;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    // on: the amber wash with an amber edge; off: a plain outline. The difference is the fill, not only the colour.
    final fg = on ? t.goldTxt : t.mut;
    return MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.7 : 1,
          child: SdBox(
            radius: 12,
            color: on ? t.goldSoft : t.pa,
            borderColor: on ? t.goldRing.withOpacity(0.55) : t.line,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SdIcon(icon, size: 22, color: fg, stroke: 1.8),
              const SizedBox(height: 7),
              Text(label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: sdTs(12, FontWeight.w500, fg, lh: 1.15)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A popover under (or beside) its anchor, in the overlay so it can reach outside the anchor's box and take clicks there; a click elsewhere closes it.
class SdPopoverAnchor extends StatefulWidget {
  const SdPopoverAnchor({
    super.key,
    required this.anchorBuilder,
    required this.popupBuilder,
    this.targetAnchor = Alignment.bottomRight,
    this.followerAnchor = Alignment.topRight,
    this.offset = const Offset(0, 8),
    this.onClosed,
  });

  /// builds the anchor; call `toggle` to open or close, `open` tells whether it is open
  final Widget Function(BuildContext context, VoidCallback toggle, bool open) anchorBuilder;
  final Widget Function(BuildContext context, VoidCallback close) popupBuilder;
  final Alignment targetAnchor, followerAnchor;
  final Offset offset;
  final VoidCallback? onClosed;

  @override
  State<SdPopoverAnchor> createState() => _SdPopoverAnchorState();
}

class _SdPopoverAnchorState extends State<SdPopoverAnchor> {
  final _link = LayerLink();
  OverlayEntry? _entry;

  bool get _open => _entry != null;

  void _toggle() => _open ? _close() : _show();

  void _show() {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null || _open) return;
    _entry = OverlayEntry(
      builder: (ctx) => Stack(children: [
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _close)),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: widget.targetAnchor,
          followerAnchor: widget.followerAnchor,
          offset: widget.offset,
          // sized to the popup (an Align without factors fills the whole overlay, and the follower anchor would then be the overlay's edge, not the popup's)
          child: Align(alignment: Alignment.topLeft, widthFactor: 1, heightFactor: 1, child: Material(type: MaterialType.transparency, child: widget.popupBuilder(ctx, _close))),
        ),
      ]),
    );
    overlay.insert(_entry!);
    setState(() {});
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
    widget.onClosed?.call();
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(link: _link, child: widget.anchorBuilder(context, _toggle, _open));
}

/// `.toast`: the dark pill at the bottom of the window ("ID copied").
class SdToast {
  SdToast._();
  static OverlayEntry? _entry;

  static void show(BuildContext context, String message) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _entry?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(builder: (ctx) => _ToastView(message: message, onDone: () {
          if (_entry == entry) _entry = null;
          entry.remove();
        }));
    _entry = entry;
    overlay.insert(entry);
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({required this.message, required this.onDone});
  final String message;
  final VoidCallback onDone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2400), () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 26,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: SdBox(
                radius: 999,
                color: const Color(0xFF1A1712),
                shadows: SdSkin.of(context).floatShadows,
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const SdIcon(SdIcons.check, size: 18, color: Color(0xFFFBBF4A), stroke: 2.2),
                  const SizedBox(width: 10),
                  Text(widget.message, style: sdTs(14.5, FontWeight.w400, const Color(0xFFF3EFE6))),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.link`: a gold text button (Clear all, Continue as guest).
class SdLink extends StatelessWidget {
  const SdLink(this.label, {super.key, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Text(label, style: sdTs(13.5, FontWeight.w600, t.goldTxt))),
      ),
    );
  }
}
