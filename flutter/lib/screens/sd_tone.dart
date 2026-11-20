import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The colours of the SystemDesk app design (light and dark): the tokens of the design's style sheet, one for one.
class SdSkin {
  const SdSkin._({
    required this.dark,
    required this.bg,
    required this.bg2,
    required this.bgGlow,
    required this.pa,
    required this.pb,
    required this.hi,
    required this.sh,
    required this.sh2,
    required this.ink,
    required this.mut,
    required this.line,
    required this.ia,
    required this.ib,
    required this.chip,
    required this.goldA,
    required this.goldB,
    required this.goldInk,
    required this.goldRing,
    required this.goldTxt,
    required this.goldSoft,
    required this.navyA,
    required this.navyB,
    required this.navyInk,
    required this.navyMut,
    required this.navyField,
    required this.navyLine,
    required this.ok,
    required this.bad,
    required this.led,
    required this.scrim,
    required this.insetShadow,
    required this.insetLight,
    required this.line2,
    required this.chrome,
  });

  final bool dark;

  /// page: the colour at the end of the gradient, the colour in the middle, the glow in the top left corner
  final Color bg, bg2, bgGlow;

  /// raised surface: top and bottom colour of its gradient, the white edge on top, the shadows
  final Color pa, pb, hi, sh, sh2;
  final Color ink, mut, line;

  /// the stronger line (the edge of a field or a button) and the colour of the bars around the page: title bar, header, side panel, settings menu
  final Color line2, chrome;

  /// inset field: gradient, and the chip (small pill, hover)
  final Color ia, ib, chip;
  final Color goldA, goldB, goldInk, goldRing, goldTxt, goldSoft;
  final Color navyA, navyB, navyInk, navyMut, navyField, navyLine;
  final Color ok, bad, led, scrim;

  /// the dark edge inside an inset field, and its light edge underneath
  final Color insetShadow, insetLight;

  // The flat design: one white page, bars of a warm grey around it, hairlines instead of shadows, and one accent (amber).
  static const SdSkin light = SdSkin._(
    dark: false,
    bg: Color(0xFFFFFFFF),
    bg2: Color(0xFFFFFFFF),
    bgGlow: Color(0xFFFFFFFF),
    pa: Color(0xFFFFFFFF),
    pb: Color(0xFFFFFFFF),
    hi: Color(0x00FFFFFF),
    sh: Color(0x331A1712),
    sh2: Color(0x141A1712),
    ink: Color(0xFF1A1712),
    mut: Color(0xFF5F594E),
    line: Color(0xFFE0DDD5),
    ia: Color(0xFFFFFFFF),
    ib: Color(0xFFFFFFFF),
    chip: Color(0xFFEFEDE8),
    goldA: Color(0xFFF59E0B),
    goldB: Color(0xFFF59E0B),
    goldInk: Color(0xFF1A1712),
    goldRing: Color(0xFFF59E0B),
    goldTxt: Color(0xFF8F5300),
    goldSoft: Color(0xFFFEF3D6),
    navyA: Color(0xFF1A1712),
    navyB: Color(0xFF1A1712),
    navyInk: Color(0xFFFFFFFF),
    navyMut: Color(0xFFCFCBC1),
    navyField: Color(0xFF2A261F),
    navyLine: Color(0x1FFFFFFF),
    ok: Color(0xFF167A4A),
    bad: Color(0xFFB42318),
    led: Color(0xFF2BB673),
    scrim: Color(0x661A1712),
    insetShadow: Color(0x00000000),
    insetLight: Color(0x00FFFFFF),
    line2: Color(0xFFCFCBC1),
    chrome: Color(0xFFF4F3EF),
  );

  static const SdSkin darkTone = SdSkin._(
    dark: true,
    bg: Color(0xFF211E17),
    bg2: Color(0xFF211E17),
    bgGlow: Color(0xFF211E17),
    pa: Color(0xFF211E17),
    pb: Color(0xFF211E17),
    hi: Color(0x00FFFFFF),
    sh: Color(0x99000000),
    sh2: Color(0x59000000),
    ink: Color(0xFFF3EFE6),
    mut: Color(0xFFB4AD9E),
    line: Color(0xFF35312A),
    ia: Color(0xFF211E17),
    ib: Color(0xFF211E17),
    chip: Color(0xFF16140F),
    goldA: Color(0xFFF59E0B),
    goldB: Color(0xFFF59E0B),
    goldInk: Color(0xFF1A1712),
    goldRing: Color(0xFFF59E0B),
    goldTxt: Color(0xFFFBBF4A),
    goldSoft: Color(0xFF3A2A0A),
    navyA: Color(0xFFF3EFE6),
    navyB: Color(0xFFF3EFE6),
    navyInk: Color(0xFF1A1712),
    navyMut: Color(0xFF4B463C),
    navyField: Color(0xFFE6E0D2),
    navyLine: Color(0x1F000000),
    ok: Color(0xFF4BDE8A),
    bad: Color(0xFFFF8F85),
    led: Color(0xFF2BB673),
    scrim: Color(0x9E000000),
    insetShadow: Color(0x00000000),
    insetLight: Color(0x00FFFFFF),
    line2: Color(0xFF4B463C),
    chrome: Color(0xFF1A1812),
  );

  static SdSkin of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? darkTone : light;

  /// the card colour as a solid (what the Material theme needs: popup menus and dialogs must not be see-through)
  Color get solid => Color.alphaBlend(pa.withOpacity(1), pb);

  /// raised surface fill, top to bottom
  LinearGradient get raised => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [pa, pb]);
  LinearGradient get inset => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [ia, ib]);
  LinearGradient get gold => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [goldA, goldB]);
  LinearGradient get navy => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [navyA, navyB]);

  /// the shadows around a raised panel (the white edge on top is [SdBox.innerShadows])
  List<BoxShadow> get panelShadows => const [];

  /// a small control (button, chip, icon button): flat, only its hairline
  List<BoxShadow> get smallShadows => const [];

  /// what floats above the page (menus, popovers, dialogs): the one place a shadow is kept
  List<BoxShadow> get floatShadows => [BoxShadow(color: sh, blurRadius: 32, offset: const Offset(0, 12))];

  static const List<FontFeature> figures = [FontFeature.tabularFigures()];
}

/// The text style of the design: [lh] is the CSS line-height as a multiple of the size (the design's root says 1.4), the leading is shared above and below
/// the line as a browser does it.
TextStyle sdTs(double size, FontWeight w, Color c, {double? ls, double? lh, bool figures = false, TextDecoration? decoration}) => TextStyle(
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Roboto'],
      fontSize: size,
      fontWeight: w,
      color: c,
      // set always: Material's text theme would otherwise add its own spacing (+0.25 px a letter) to every text
      letterSpacing: ls ?? 0,
      wordSpacing: 0,
      height: lh ?? 1.4,
      leadingDistribution: TextLeadingDistribution.even,
      fontFeatures: figures ? SdSkin.figures : null,
      decoration: decoration ?? TextDecoration.none,
    );

/// An inner shadow, like the CSS `box-shadow: inset dx dy blur color`.
class SdInner {
  const SdInner(this.dx, this.dy, this.blur, this.color);
  final double dx, dy, blur;
  final Color color;
}

class _InnerPainter extends CustomPainter {
  _InnerPainter(this.radius, this.inset, this.shadows);
  final double radius, inset;
  final List<SdInner> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty) return;
    final rect = Rect.fromLTWH(inset, inset, size.width - 2 * inset, size.height - 2 * inset);
    if (rect.isEmpty) return;
    final r = (radius - inset).clamp(0.0, 1e6);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));
    canvas.save();
    canvas.clipRRect(rrect);
    for (final s in shadows) {
      final path = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(s.blur * 3 + s.dx.abs() + s.dy.abs() + 4))
        ..addRRect(rrect.shift(Offset(s.dx, s.dy)));
      final paint = Paint()..color = s.color;
      if (s.blur > 0) paint.maskFilter = ui.MaskFilter.blur(BlurStyle.normal, s.blur / 2);
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InnerPainter old) => old.radius != radius || old.inset != inset || old.shadows != shadows;
}

/// The one box of the design: a fill (gradient or colour), a border, shadows around it and shadows inside it, rounded corners.
class SdBox extends StatelessWidget {
  const SdBox({
    super.key,
    this.child,
    this.radius = 14,
    this.gradient,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.shadows = const [],
    this.inner = const [],
    this.padding,
    this.width,
    this.height,
    this.alignment,
    this.constraints,
    this.margin,
  });

  final Widget? child;
  final double radius;
  final Gradient? gradient;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow> shadows;
  final List<SdInner> inner;
  final EdgeInsetsGeometry? padding, margin;
  final double? width, height;
  final AlignmentGeometry? alignment;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    Widget box = Container(
      width: width,
      height: height,
      margin: margin,
      constraints: constraints,
      alignment: alignment,
      padding: padding,
      foregroundDecoration: null,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? color : null,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null ? null : Border.all(color: borderColor!, width: borderWidth),
        boxShadow: shadows,
      ),
      child: child,
    );
    if (inner.isNotEmpty) {
      box = CustomPaint(foregroundPainter: _InnerPainter(radius, borderColor == null ? 0 : borderWidth, inner), child: box);
    }
    return box;
  }
}

/// The page behind everything: the design's soft glow in the top left corner on the page colour.
class SdBackdrop extends StatelessWidget {
  const SdBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return CustomPaint(painter: _BackdropPainter(t), child: child);
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.t);
  final SdSkin t;

  @override
  void paint(Canvas canvas, Size size) {
    // the flat design: one plain page colour
    canvas.drawRect(Offset.zero & size, Paint()..color = t.bg);
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.t != t;
}
