import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';

/// A computer connected right now (to this one, or from this one).
class SdLiveRow {
  const SdLiveRow({required this.name, required this.sub, required this.incoming, required this.time, required this.button, this.onTap, this.danger = false});
  final String name, sub, time, button;
  final bool incoming, danger;
  final VoidCallback? onTap;
}

/// A finished session of the history.
class SdHistoryRow {
  const SdHistoryRow({required this.name, required this.id, required this.incoming, required this.when, required this.duration, required this.kind});
  final String name, id, when, duration, kind;
  final bool incoming;
}

/// One bar of "Last 7 days".
class SdDayBar {
  const SdDayBar(this.label, this.minutes, {this.today = false});
  final String label;
  final double minutes;
  final bool today;
}

/// The Sessions page of the design. It only draws; [SdSessions] fills it from the account and the log of this computer.
class SdSessionsView extends StatelessWidget {
  const SdSessionsView({
    super.key,
    required this.big,
    required this.small,
    required this.fraction,
    required this.facts,
    required this.days,
    required this.live,
    required this.history,
    required this.filter,
    required this.onFilter,
    this.onPlans,
    this.tr = _same,
  });

  /// the number in the ring and the words under it
  final String big, small;
  final double fraction;

  /// label and value rows under the ring
  final List<(String, String)> facts;
  final List<SdDayBar> days;
  final List<SdLiveRow> live;
  final List<SdHistoryRow> history;

  /// 'all', 'out' or 'in'
  final String filter;
  final ValueChanged<String> onFilter;
  final VoidCallback? onPlans;
  final String Function(String) tr;

  static String _same(String s) => s;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: LayoutBuilder(builder: (context, c) {
        final stacked = c.maxWidth < 980;
        final left = _use(context, stacked);
        final right = _right(context);
        if (stacked) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 28), right]);
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [SizedBox(width: 344, child: left), const SizedBox(width: 28), Expanded(child: right)]),
        );
      }),
    );
  }

  Widget _use(BuildContext context, bool stacked) {
    final t = SdSkin.of(context);
    final maxMin = days.fold<double>(0, (m, d) => math.max(m, d.minutes));
    final children = <Widget>[
      Text(tr('Today'), style: sdTs(20, FontWeight.w500, t.ink, ls: -0.2)),
      Center(child: Padding(padding: const EdgeInsets.only(top: 4), child: _Ring(big: big, small: small, fraction: fraction))),
      Column(children: [
        for (final f in facts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(child: Text(tr(f.$1), style: sdTs(14.5, FontWeight.w400, t.mut))),
              const SizedBox(width: 12),
              Flexible(child: Text(f.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(14.5, FontWeight.w500, t.ink, figures: true))),
            ]),
          ),
      ]),
      const SdHr(),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(tr('Last 7 days'), style: sdTs(14.5, FontWeight.w400, t.ink)),
          Text(tr('minutes'), style: sdTs(14.5, FontWeight.w400, t.mut)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < days.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: Tooltip(
                  message: '${days[i].minutes.round()} ${tr('min')}',
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Container(
                      height: math.max(6, maxMin <= 0 ? 6 : (days[i].minutes / maxMin) * 66 + 6),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8), bottomLeft: Radius.circular(4), bottomRight: Radius.circular(4)),
                        color: days[i].today ? null : t.chip,
                        gradient: days[i].today ? t.gold : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(days[i].label, style: sdTs(11.5, FontWeight.w400, t.mut, lh: 1.1)),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ]),
      if (!stacked) const Expanded(child: SizedBox()),
      SdButton(kind: SdBtnKind.gold, block: true, label: tr('See plans'), onTap: onPlans),
    ];
    return SdPanel(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0 && children[i - 1] is! Expanded) const SizedBox(height: 16), children[i]],
      ]),
    );
  }

  Widget _right(BuildContext context) {
    final t = SdSkin.of(context);
    final rows = history.where((h) => filter == 'all' || (filter == 'out' ? !h.incoming : h.incoming)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SdNavyPanel(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text(tr('Active now'), style: sdTs(20, FontWeight.w500, t.navyInk, ls: -0.2)),
            const SizedBox(width: 12),
            SdTag('${live.length} ${live.length == 1 ? tr('session') : tr('sessions')}', onNavy: true),
          ]),
          const SizedBox(height: 12),
          if (live.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(tr('Nobody is connected to this computer, and you are not connected to another one.'), style: sdTs(14, FontWeight.w400, t.navyMut)),
            ),
          for (var i = 0; i < live.length; i++) ...[if (i > 0) const SizedBox(height: 12), _liveRow(t, live[i])],
        ]),
      ),
      const SizedBox(height: 26),
      Row(children: [
        Text(tr('History'), style: sdTs(20, FontWeight.w500, t.ink, ls: -0.2)),
        const Spacer(),
        SdSeg<String>(items: [('all', tr('All')), ('out', tr('Outgoing')), ('in', tr('Incoming'))], value: filter, onChanged: onFilter),
      ]),
      const SizedBox(height: 14),
      if (rows.isEmpty)
        SdPanel(padding: const EdgeInsets.fromLTRB(16, 26, 16, 30), child: Center(child: Text(tr('Sessions you start or receive on this computer are listed here.'), textAlign: TextAlign.center, style: sdTs(14, FontWeight.w400, t.mut)))),
      for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 10), _historyRow(t, rows[i])],
    ]);
  }

  Widget _liveRow(SdSkin t, SdLiveRow r) {
    return SdBox(
      radius: 14,
      color: const Color(0x0FFFFFFF),
      borderColor: t.navyLine,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0x24F6D993), borderRadius: BorderRadius.circular(13)),
          child: SdIcon(r.incoming ? SdIcons.arrowDownLeft : SdIcons.arrowUpRight, size: 19, color: const Color(0xFFF2CE8A), stroke: 2),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(15.5, FontWeight.w500, t.navyInk)),
            Text(r.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(12.5, FontWeight.w400, t.navyMut)),
          ]),
        ),
        const SizedBox(width: 14),
        Text(r.time, style: sdTs(14, FontWeight.w500, t.navyInk, figures: true)),
        if (r.button.isNotEmpty) ...[
          const SizedBox(width: 14),
          SdButton(small: true, kind: r.danger ? SdBtnKind.bad : SdBtnKind.plain, label: r.button, onTap: r.onTap),
        ],
      ]),
    );
  }

  Widget _historyRow(SdSkin t, SdHistoryRow r) {
    return SdBox(
      radius: 12,
      color: t.pa,
      borderColor: t.line,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: t.chip, borderRadius: BorderRadius.circular(12)),
          child: SdIcon(r.incoming ? SdIcons.arrowDownLeft : SdIcons.arrowUpRight, size: 18, color: t.ink, stroke: 2),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(16, FontWeight.w500, t.ink)),
              Text(r.id, style: sdTs(12.5, FontWeight.w400, t.mut, figures: true)),
            ]),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(width: 130, child: Text(r.when, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(14, FontWeight.w400, t.mut))),
        const SizedBox(width: 16),
        SizedBox(width: 96, child: Text(r.duration, style: sdTs(14, FontWeight.w500, t.ink, figures: true))),
        const SizedBox(width: 16),
        SizedBox(width: 150, child: Align(alignment: Alignment.centerLeft, child: SdTag(r.kind))),
      ]),
    );
  }
}

/// `.ringw`: today's minutes as a ring (176 px, a track of 14 px, the gold arc starts at the top).
class _Ring extends StatelessWidget {
  const _Ring({required this.big, required this.small, required this.fraction});
  final String big, small;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return SizedBox(
      width: 176,
      height: 176,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: const Size(176, 176), painter: _RingPainter(t, fraction)),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(big, style: sdTs(38, FontWeight.w600, t.ink, ls: -0.76, lh: 1.0, figures: true)),
          const SizedBox(height: 4),
          Text(small, style: sdTs(13, FontWeight.w400, t.mut)),
        ]),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t, this.fraction);
  final SdSkin t;
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..color = t.chip;
    canvas.drawCircle(c, 74, track);
    final f = fraction.clamp(0.0, 1.0);
    if (f <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [t.goldA, t.goldB]).createShader(Rect.fromCircle(center: c, radius: 74));
    canvas.drawArc(Rect.fromCircle(center: c, radius: 74), -math.pi / 2, 2 * math.pi * f, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.t != t;
}
