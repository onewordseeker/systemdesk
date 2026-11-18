import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart' show ColorThemeExtension;
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart' show TabbarTheme;
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_shell.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';

/// The in-session toolbar of the design (`.rtool`, `.tbtn`, `.tsep`, `.rmenu`): a navy bar with a gold edge that floats over the other computer's screen. It
/// is dark in the light and in the dark app alike, as the other computer's picture is what is around it.
class SdToolbar {
  SdToolbar._();

  static const Color barA = Color(0xFF232E47);
  static const Color barB = Color(0xFF141C2E);
  static const Color gold = Color(0xFFF7DB98);
  static const Color ink = Color(0xFFDDE3F0);
  static const Color menuInk = Color(0xFFEEF1F7);
  static const Color menuMut = Color(0xFFA9B3C8);

  /// the menu is one flat colour (a menu panel of Material takes no gradient): the middle of the bar's two
  static const Color panel = Color(0xFF1B2539);

  static const Color edge = Color(0x80D6AE63);
  static const Color hairline = Color(0x1FFFFFFF);
  static const Color hover = Color(0x1AFFFFFF);
  static const Color pressed = Color(0x2EF7DB98);
  static const Color separator = Color(0x24FFFFFF);
  static const Color menuHover = Color(0x14FFFFFF);

  static const double buttonWidth = 42;
  static const double buttonHeight = 40;
  static const double buttonRadius = 12;
  static const double barRadius = 18;

  static const LinearGradient barFill = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [barA, barB]);
  static const LinearGradient endFill =
      LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD9564B), Color(0xFFB8352B)]);

  static const List<BoxShadow> barShadows = [BoxShadow(color: Color(0xB3000000), blurRadius: 40, spreadRadius: -16, offset: Offset(0, 22))];

  /// `.rmenu`: the panel of a menu that opens from a button of the bar
  static MenuStyle get menuStyle => MenuStyle(
        backgroundColor: const MaterialStatePropertyAll(panel),
        surfaceTintColor: const MaterialStatePropertyAll(Colors.transparent),
        shadowColor: const MaterialStatePropertyAll(Color(0xCC000000)),
        elevation: const MaterialStatePropertyAll(10),
        side: const MaterialStatePropertyAll(BorderSide(color: hairline)),
        shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(barRadius))),
        padding: const MaterialStatePropertyAll(EdgeInsets.all(8)),
      );

  static ThemeData? _theme;

  /// The theme of everything inside the bar: the buttons, the menus that open from them and the controls in those menus.
  static ThemeData theme() => _theme ??= _buildTheme();

  static ThemeData _buildTheme() {
    final base = SdLook.dark;
    final text = sdTs(14.5, FontWeight.w400, menuInk);
    return base.copyWith(
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          minimumSize: const MaterialStatePropertyAll(Size(64, 38)),
          padding: const MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
          foregroundColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.disabled) ? const Color(0x66EEF1F7) : menuInk),
          iconColor: const MaterialStatePropertyAll(menuInk),
          backgroundColor: const MaterialStatePropertyAll(Colors.transparent),
          overlayColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.hovered) || s.contains(MaterialState.focused) ? menuHover : null),
          textStyle: MaterialStatePropertyAll(text),
          shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ),
      menuBarTheme: MenuBarThemeData(
        style: MenuStyle(
          backgroundColor: const MaterialStatePropertyAll(Colors.transparent),
          surfaceTintColor: const MaterialStatePropertyAll(Colors.transparent),
          padding: const MaterialStatePropertyAll(EdgeInsets.zero),
          elevation: const MaterialStatePropertyAll(0),
          shape: const MaterialStatePropertyAll(BeveledRectangleBorder()),
        ),
      ),
      menuTheme: MenuThemeData(style: menuStyle),
      dividerTheme: const DividerThemeData(space: 10, thickness: 1, color: hover),
      iconTheme: const IconThemeData(color: ink),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ink, iconColor: ink, splashFactory: NoSplash.splashFactory),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? const Color(0xFFE2AC50) : Colors.transparent),
        checkColor: const MaterialStatePropertyAll(Color(0xFF3A2808)),
        side: const BorderSide(color: Color(0x80FFFFFF), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? const Color(0xFFE2AC50) : const Color(0x99FFFFFF)),
      ),
    );
  }
}

/// The bar above a remote session (`.rtabs`, `.rtab`): dark whatever the app theme is, the open computer a gold pill.
class SdRemoteTabs {
  SdRemoteTabs._();

  static const double height = 40;
  static const Color fill = Color(0xFF161C28);
  static const Color line = Color(0x12FFFFFF);
  static const Color ink = Color(0xFFB6BFD2);
  static const Color led = Color(0xFF2BD37A);

  static ThemeData? _theme;

  /// the dark theme with the tab colours of the design
  static ThemeData theme() => _theme ??= _buildTheme();

  static ThemeData _buildTheme() {
    final base = SdLook.dark;
    final tone = SdSkin.darkTone;
    final colorExt = base.extension<ColorThemeExtension>();
    final tabExt = base.extension<TabbarTheme>();
    return base.copyWith(extensions: <ThemeExtension<dynamic>>[
      if (colorExt != null) colorExt,
      if (tabExt != null)
        tabExt.copyWith(
          selectedTabIconColor: tone.goldInk,
          unSelectedTabIconColor: ink,
          selectedTextColor: tone.goldInk,
          unSelectedTextColor: ink,
          selectedIconColor: tone.goldInk,
          unSelectedIconColor: ink,
          hoverColor: const Color(0x14FFFFFF),
          closeHoverColor: const Color(0x1FFFFFFF),
          selectedTabBackgroundColor: tone.goldB,
        ),
    ]);
  }
}

/// The dark bar itself, with the dark theme for everything on it (the window buttons, the tabs, the plus button).
class SdRemoteBar extends StatelessWidget {
  const SdRemoteBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: SdRemoteTabs.theme(),
      child: SdWinInk(
        color: SdRemoteTabs.ink,
        child: Container(
          height: SdRemoteTabs.height,
          decoration: const BoxDecoration(color: SdRemoteTabs.fill, border: Border(bottom: BorderSide(color: SdRemoteTabs.line))),
          child: child,
        ),
      ),
    );
  }
}

/// `.rtab`: a computer that is open. [child] is what the tab says (the green dot, the name, the time).
class SdRemoteTab extends StatefulWidget {
  const SdRemoteTab({super.key, required this.selected, required this.closable, required this.onTap, required this.onClose, required this.child});
  final bool selected, closable;
  final VoidCallback onTap, onClose;
  final Widget child;

  @override
  State<SdRemoteTab> createState() => _SdRemoteTabState();
}

class _SdRemoteTabState extends State<SdRemoteTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tone = SdSkin.darkTone;
    final on = widget.selected;
    final fg = on ? tone.goldInk : SdRemoteTabs.ink;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: on ? tone.gold : null,
                color: !on && _hover ? const Color(0x14FFFFFF) : null,
                borderRadius: BorderRadius.circular(9),
              ),
              child: DefaultTextStyle(
                style: sdTs(13, on ? FontWeight.w600 : FontWeight.w400, fg),
                child: IconTheme(
                  data: IconThemeData(color: fg),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    widget.child,
                    if (widget.closable) ...[
                      const SizedBox(width: 8),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onClose,
                          child: SizedBox(
                            width: 12,
                            height: 28,
                            child: Center(child: CustomPaint(size: const Size(12, 12), painter: _TabX(fg))),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// the cross that closes a tab (`M2 2l8 8M10 2l-8 8` in a 12 px box, 1.5 px thick)
class _TabX extends CustomPainter {
  const _TabX(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(2, 2), const Offset(10, 10), p);
    canvas.drawLine(const Offset(10, 2), const Offset(2, 10), p);
  }

  @override
  bool shouldRepaint(_TabX old) => old.color != color;
}

/// What a tab of an open computer says: the green dot (its tooltip tells how the connection is made), the name, the time that has passed.
Widget sdRemoteTabContent({required String tabKey, required Widget label, required Widget unread, required String tooltip}) {
  return Row(mainAxisSize: MainAxisSize.min, children: [
    Tooltip(message: tooltip, child: const SdTabLed()),
    const SizedBox(width: 8),
    label,
    unread,
    const SizedBox(width: 8),
    SdTabClock(tabKey: tabKey),
  ]);
}

/// The four squares at the left end of the bar: it stands where the logo of the other windows is.
class SdTabGrid extends StatelessWidget {
  const SdTabGrid({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 19,
        child: Transform.translate(
          offset: const Offset(7, 0),
          child: const Align(alignment: Alignment.centerLeft, child: SdIcon(SdIcons.tiles, size: 14, color: SdRemoteTabs.ink, stroke: 2)),
        ),
      );
}

/// The green dot in front of the name of a computer that is connected (`.led`, 9 px, without the glow).
class SdTabLed extends StatelessWidget {
  const SdTabLed({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(width: 9, height: 9, decoration: const BoxDecoration(shape: BoxShape.circle, color: SdRemoteTabs.led));
}

/// 12 minutes 48 seconds -> 12:48, an hour and two minutes and three seconds -> 1:02:03
String sdTabTime(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(d.inMinutes)}:${two(s)}';
}

/// How long a tab has been open (`12:48`): counted from when the tab first showed it, so it keeps counting when the tab is built again.
class SdTabClock extends StatefulWidget {
  const SdTabClock({super.key, required this.tabKey});
  final String tabKey;

  static final Map<String, DateTime> _since = {};

  /// a test says since when a tab is open
  @visibleForTesting
  static void debugSince(String tabKey, DateTime since) => _since[tabKey] = since;

  @override
  State<SdTabClock> createState() => _SdTabClockState();
}

class _SdTabClockState extends State<SdTabClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    SdTabClock._since.putIfAbsent(widget.tabKey, DateTime.now);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
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
    final since = SdTabClock._since[widget.tabKey] ?? DateTime.now();
    return Opacity(
      opacity: 0.75,
      child: Text(sdTabTime(DateTime.now().difference(since)), style: sdTs(13, FontWeight.w500, DefaultTextStyle.of(context).style.color ?? SdRemoteTabs.ink, figures: true)),
    );
  }
}

/// The plus after the tabs: open another computer.
class SdTabAdd extends StatefulWidget {
  const SdTabAdd({super.key, required this.onTap, this.tooltip = ''});
  final VoidCallback onTap;
  final String tooltip;

  @override
  State<SdTabAdd> createState() => _SdTabAddState();
}

class _SdTabAddState extends State<SdTabAdd> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(seconds: 1),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Container(
              width: 30,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _hover ? SdToolbar.hover : Colors.transparent, borderRadius: BorderRadius.circular(SdToolbar.buttonRadius)),
              child: const SdIcon(SdIcons.plus, size: 16, color: SdToolbar.ink, stroke: 2.2),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.tbtn` (and `.tbtn.end` when [label] is given): what a button of the bar looks like. It has no behaviour of its own; the button that shows it passes
/// [hover] and [on] (`aria-pressed`: the menu is open, the sound is on, the pin is pinned).
class SdToolFace extends StatelessWidget {
  const SdToolFace({super.key, this.icon, this.child, this.on = false, this.hover = false, this.label, this.width, this.dim = false});

  /// the body of one of [SdIcons], or [child] for a picture the toolbar already draws itself
  final String? icon;
  final Widget? child;
  final bool on, hover, dim;

  /// the red End button: its icon is [icon] and its text is this
  final String? label;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final end = label != null;
    if (end) {
      return Container(
        height: SdToolbar.buttonHeight,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(gradient: SdToolbar.endFill, borderRadius: BorderRadius.circular(SdToolbar.buttonRadius)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) SdIcon(icon!, size: 17, color: Colors.white, stroke: 2.2),
          const SizedBox(width: 6),
          Text(label!, maxLines: 1, style: sdTs(13.5, FontWeight.w600, Colors.white)),
        ]),
      );
    }
    final fg = on ? SdToolbar.gold : SdToolbar.ink;
    final bg = on ? SdToolbar.pressed : (hover ? SdToolbar.hover : Colors.transparent);
    return Container(
      width: width ?? SdToolbar.buttonWidth,
      height: SdToolbar.buttonHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(SdToolbar.buttonRadius)),
      child: Opacity(
        opacity: dim ? 0.5 : 1,
        child: child ?? (icon == null ? null : SdIcon(icon!, size: 19, color: fg, stroke: 1.9)),
      ),
    );
  }
}

/// `.tsep`: the thin line between two groups of buttons
class SdToolSep extends StatelessWidget {
  const SdToolSep({super.key, this.horizontal = true});

  /// true: the bar lies along the top or bottom edge, so the line stands upright
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    return horizontal
        ? Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 6), color: SdToolbar.separator)
        : Container(width: 22, height: 1, margin: const EdgeInsets.symmetric(vertical: 6), color: SdToolbar.separator);
  }
}

/// `.rtool`: the bar itself
class SdToolbarFrame extends StatelessWidget {
  const SdToolbarFrame({super.key, required this.child, this.horizontal = true});
  final Widget child;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    return SdBox(
      radius: SdToolbar.barRadius,
      gradient: SdToolbar.barFill,
      borderColor: SdToolbar.edge,
      shadows: SdToolbar.barShadows,
      inner: const [SdInner(0, 1, 0, Color(0x1AFFFFFF))],
      padding: horizontal ? const EdgeInsets.symmetric(vertical: 4) : const EdgeInsets.symmetric(horizontal: 4),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// The small handle that hangs off the bar (move, full screen, hide): the same navy and gold edge as the bar.
class SdToolbarHandle extends StatelessWidget {
  const SdToolbarHandle({super.key, required this.child, required this.borderRadius});
  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: SdToolbar.barFill,
        borderRadius: borderRadius,
        border: Border.all(color: SdToolbar.edge),
        boxShadow: SdToolbar.barShadows,
      ),
      child: Theme(
        data: SdToolbar.theme(),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}
