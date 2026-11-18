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
  });

  final bool dark;

  /// page: the colour at the end of the gradient, the colour in the middle, the glow in the top left corner
  final Color bg, bg2, bgGlow;

  /// raised surface: top and bottom colour of its gradient, the white edge on top, the shadows
  final Color pa, pb, hi, sh, sh2;
  final Color ink, mut, line;

  /// inset field: gradient, and the chip (small pill, hover)
  final Color ia, ib, chip;
  final Color goldA, goldB, goldInk, goldRing, goldTxt, goldSoft;
  final Color navyA, navyB, navyInk, navyMut, navyField, navyLine;
  final Color ok, bad, led, scrim;

  /// the dark edge inside an inset field, and its light edge underneath
  final Color insetShadow, insetLight;

  static const SdSkin light = SdSkin._(
    dark: false,
    bg: Color(0xFFECEAE6),
    bg2: Color(0xFFE2E0DB),
    bgGlow: Color(0xFFF6F5F2),
    pa: Color(0xFFFAF9F7),
    pb: Color(0xFFEEEDEA),
    hi: Color(0xF2FFFFFF),
    sh: Color(0x29342C1E),
    sh2: Color(0x14342C1E),
    ink: Color(0xFF1D2230),
    mut: Color(0xFF5A6070),
    line: Color(0x1A28241C),
    ia: Color(0xFFE6E4E0),
    ib: Color(0xFFF2F1EE),
    chip: Color(0xFFE3E1DD),
    goldA: Color(0xFFF7DB98),
    goldB: Color(0xFFE2AC50),
    goldInk: Color(0xFF3A2808),
    goldRing: Color(0xFFD6AE63),
    goldTxt: Color(0xFF7A520F),
    goldSoft: Color(0xFFF8EBCD),
    navyA: Color(0xFF2A3652),
    navyB: Color(0xFF1A2437),
    navyInk: Color(0xFFEEF1F7),
    navyMut: Color(0xFFA9B3C8),
    navyField: Color(0xFF141D2F),
    navyLine: Color(0x17FFFFFF),
    ok: Color(0xFF17804F),
    bad: Color(0xFFB8352B),
    led: Color(0xFF2BD37A),
    scrim: Color(0x661E1A12),
    insetShadow: Color(0x2628241C),
    insetLight: Color(0xF2FFFFFF),
  );

  static const SdSkin darkTone = SdSkin._(
    dark: true,
    bg: Color(0xFF12151B),
    bg2: Color(0xFF0B0E13),
    bgGlow: Color(0xFF1C2231),
    pa: Color(0xFF232935),
    pb: Color(0xFF1B202A),
    hi: Color(0x12FFFFFF),
    sh: Color(0x8C000000),
    sh2: Color(0x59000000),
    ink: Color(0xFFECEAE4),
    mut: Color(0xFFA7ADBA),
    line: Color(0x17FFFFFF),
    ia: Color(0xFF10141B),
    ib: Color(0xFF171C25),
    chip: Color(0xFF2B313D),
    goldA: Color(0xFFF7DB98),
    goldB: Color(0xFFE2AC50),
    goldInk: Color(0xFF3A2808),
    goldRing: Color(0xFFB98E45),
    goldTxt: Color(0xFFF2CE8A),
    goldSoft: Color(0x29E2AC50),
    navyA: Color(0xFF202C48),
    navyB: Color(0xFF141D33),
    navyInk: Color(0xFFEEF1F7),
    navyMut: Color(0xFFA9B3C8),
    navyField: Color(0xFF0B1220),
    navyLine: Color(0x17FFFFFF),
    ok: Color(0xFF4CCB8E),
    bad: Color(0xFFF2796E),
    led: Color(0xFF2BD37A),
    scrim: Color(0x9E05070B),
    insetShadow: Color(0x8C000000),
    insetLight: Color(0x0AFFFFFF),
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
  List<BoxShadow> get panelShadows => [
        BoxShadow(color: sh, blurRadius: 40, spreadRadius: -22, offset: const Offset(0, 20)),
        BoxShadow(color: sh2, blurRadius: 6, offset: const Offset(0, 2)),
      ];

  /// a small raised control (button, chip, icon button)
  List<BoxShadow> get smallShadows => [BoxShadow(color: sh2, blurRadius: 6, spreadRadius: -2, offset: const Offset(0, 3))];

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
    canvas.drawRect(Offset.zero & size, Paint()..color = t.bg2);
    // radial-gradient(1200px 620px at 18% -6%, glow 0%, bg 58%, bg2 100%) (dark: 1100 x 560 at 18% -8%)
    final w = t.dark ? 1100.0 : 1200.0, h = t.dark ? 560.0 : 620.0;
    final cx = size.width * 0.18, cy = size.height * (t.dark ? -0.08 : -0.06);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(w, h);
    final shader = ui.Gradient.radial(Offset.zero, 1, [t.bgGlow, t.bg, t.bg2], const [0, 0.58, 1]);
    canvas.drawRect(Rect.fromLTWH(-cx / w, -cy / h, size.width / w, size.height / h), Paint()..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.t != t;
}
