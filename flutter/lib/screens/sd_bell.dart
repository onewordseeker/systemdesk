import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:flutter_hbb/services/app_inbox.dart';
import 'package:get/get.dart';

/// The words of the bell, so the caller can pass the translated ones.
class SdBellText {
  const SdBellText({
    this.title = 'Notifications',
    this.clear = 'Clear all',
    this.empty = 'You are all caught up',
    this.emptyHint = 'Announcements from SystemDesk appear here.',
  });
  final String title, clear, empty, emptyHint;
}

/// The bell of the header: the announcements the administrators send (console > Messages) land here as notifications instead of dialogs. A dot shows that
/// something is unread; the bell opens the list under the header. A critical announcement opens the list by itself.
class SdBell extends StatefulWidget {
  const SdBell({super.key, required this.link, this.inbox, this.text = const SdBellText()});

  /// the header's tools (bell and avatar): the list opens under them, at their right edge
  final LayerLink link;
  final AppInbox? inbox;
  final SdBellText text;

  @override
  State<SdBell> createState() => _SdBellState();
}

class _SdBellState extends State<SdBell> {
  OverlayEntry? _entry;
  Worker? _openWatch;

  AppInbox get _inbox => widget.inbox ?? AppInbox.instance;

  @override
  void initState() {
    super.initState();
    _openWatch = ever(_inbox.openRequest, (_) {
      if (mounted && _entry == null) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _open() : null);
    });
  }

  @override
  void dispose() {
    _openWatch?.dispose();
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  void _toggle() => _entry == null ? _open() : _close();

  void _open() {
    if (_entry != null) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    // what was unread when the list was opened stays marked while it is open
    final unread = {for (final i in _inbox.items) if (!_inbox.isRead(i.message.id)) i.message.id};
    _inbox.markAllRead();
    _entry = OverlayEntry(
      builder: (ctx) => Stack(children: [
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _close)),
        CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 10),
          child: Align(
            alignment: Alignment.topRight,
            child: Obx(() => SdNotificationPanel(
                  items: _inbox.items.toList(),
                  unread: unread,
                  text: widget.text,
                  onClear: () {
                    _inbox.clear();
                    _close();
                  },
                )),
          ),
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
  }

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return Obx(() => SdRoundButton(
          tooltip: widget.text.title,
          dot: _inbox.unread.value > 0,
          onTap: _toggle,
          child: SdIcon(SdIcons.bell, size: 19, color: t.ink),
        ));
  }
}

/// `.pop.notif`: a header, then one row per notification (newest first), or a quiet message when there is none.
class SdNotificationPanel extends StatefulWidget {
  const SdNotificationPanel({super.key, required this.items, this.unread = const {}, this.text = const SdBellText(), this.onClear, this.now});
  final List<InboxItem> items;

  /// ids drawn as new
  final Set<String> unread;
  final SdBellText text;
  final VoidCallback? onClear;

  /// "now" for the times in the rows (tests pin it)
  final DateTime? now;

  @override
  State<SdNotificationPanel> createState() => _SdNotificationPanelState();
}

class _SdNotificationPanelState extends State<SdNotificationPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 240))..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final now = widget.now ?? DateTime.now();
    final screenH = MediaQuery.maybeOf(context)?.size.height ?? 720;
    final curve = CurvedAnimation(parent: _in, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.97, end: 1).animate(curve),
        alignment: Alignment.topRight,
        child: Material(
          type: MaterialType.transparency,
          child: SdBox(
            radius: 14,
            color: t.pa,
            borderColor: t.line2,
            width: 392,
            constraints: BoxConstraints(maxHeight: math.max(180, math.min(580, screenH - 150))),
            shadows: t.floatShadows,
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 0, 10),
                child: Row(children: [
                  Expanded(child: Text(widget.text.title, style: sdTs(17, FontWeight.w600, t.ink))),
                  if (widget.items.isNotEmpty && widget.onClear != null) SdLink(widget.text.clear, onTap: widget.onClear),
                ]),
              ),
              if (widget.items.isEmpty)
                _empty(t)
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: widget.items.length,
                    itemBuilder: (_, i) => _Row(item: widget.items[i], fresh: widget.unread.contains(widget.items[i].message.id), now: now),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _empty(SdSkin t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 26, 16, 30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SdRoundButton(size: 52, child: SdIcon(SdIcons.bell, size: 22, color: t.ink)),
          const SizedBox(height: 6),
          Text(widget.text.empty, textAlign: TextAlign.center, style: sdTs(16, FontWeight.w600, t.ink)),
          const SizedBox(height: 6),
          Text(widget.text.emptyHint, textAlign: TextAlign.center, style: sdTs(13.5, FontWeight.w400, t.mut)),
        ]),
      );
}

class _Row extends StatefulWidget {
  const _Row({required this.item, required this.fresh, required this.now});
  final InboxItem item;
  final bool fresh;
  final DateTime now;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final m = widget.item.message;
    final (icon, bg, fg) = _kind(t, m.severity);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(color: _hover ? t.chip : Colors.transparent, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
            child: SdIcon(icon, size: 19, color: fg, stroke: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.title, style: sdTs(14.5, FontWeight.w600, t.ink)),
              const SizedBox(height: 2),
              Text(m.body, style: sdTs(13, FontWeight.w400, t.mut)),
            ]),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(timeAgo(widget.item.at, widget.now), style: sdTs(12, FontWeight.w400, t.mut)),
            if (widget.fresh) Padding(padding: const EdgeInsets.only(top: 8), child: Container(width: 8, height: 8, decoration: BoxDecoration(color: t.goldB, shape: BoxShape.circle))),
          ]),
        ]),
      ),
    );
  }

  /// icon, tile colour, icon colour (the design's tiles: soft gold, red 14 %, green 14 %)
  (String, Color, Color) _kind(SdSkin t, String severity) {
    switch (severity) {
      case 'critical':
        return (SdIcons.alertCircle, const Color(0x24B8352B), t.bad);
      case 'warning':
        return (SdIcons.alertTriangle, t.goldSoft, t.goldTxt);
      case 'success':
        return (SdIcons.checkCircle, const Color(0x2417804F), t.ok);
      default:
        return (SdIcons.info, t.goldSoft, t.goldTxt);
    }
  }
}
