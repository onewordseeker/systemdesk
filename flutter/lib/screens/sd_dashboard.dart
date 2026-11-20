import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_peers.dart' show SdCompact;
import 'package:flutter_hbb/screens/sd_tone.dart';

/// Below this width of the page the two columns are stacked and the page scrolls as a whole.
const double kSdDashboardSplit = 800;

/// The width of the "This computer" panel.
const double kSdAsideWidth = 330;

/// The state of the connection service, as the status line of the left panel says it.
enum SdServiceStatus { ready, connecting, notReady, stopped }

/// How a session is started from the address bar of the toolbar.
enum SdLaunch { remote, files, camera, terminal, tunnel }

/// One line of "Today": the text ("18 of 60 min") and how full the bar is (0 to 1). null: nothing to show yet.
class SdUsage {
  const SdUsage(this.text, this.fraction);
  final String text;
  final double fraction;
}

/// The Dashboard: the "This computer" panel flush at the left (status, ID, one-time password, unattended access, permissions, today's time) and the lists of
/// computers at the right (tabs, their tools, the cards or rows). It draws and nothing else: what it shows and what its buttons do come in as values and
/// callbacks, so the real page ([SdDashboard]) and the test pictures use the same widget. Starting a session is the address bar of the toolbar.
class SdDashboardView extends StatefulWidget {
  const SdDashboardView({
    super.key,
    required this.id,
    required this.password,
    this.passwordShown = true,
    required this.unattended,
    this.onUnattended,
    required this.access,
    this.onAccess,
    this.accessLocked = false,
    this.usage,
    required this.service,
    this.onStartService,
    this.onCopyId,
    this.onShare,
    this.onCopyPassword,
    this.onNewPassword,
    this.onPasswordSettings,
    required this.tabs,
    this.tools,
    required this.body,
    this.tr = _same,
  });

  /// "408 241 669"
  final String id;
  final String password;

  /// false: the one-time password is not in use (the line shows a dash and its buttons are off)
  final bool passwordShown;
  final bool unattended;
  final ValueChanged<bool>? onUnattended;

  /// 'full', 'view' or 'custom'
  final String access;
  final ValueChanged<String>? onAccess;
  final bool accessLocked;
  final SdUsage? usage;
  final SdServiceStatus service;
  final VoidCallback? onStartService, onCopyId, onShare, onCopyPassword, onNewPassword, onPasswordSettings;

  /// the lists of computers: the tabs (they get the width they are given), the tools at their right, and the open list
  final Widget tabs, body;
  final Widget? tools;
  final String Function(String) tr;

  static String _same(String s) => s;

  @override
  State<SdDashboardView> createState() => _SdDashboardViewState();
}

class _SdDashboardViewState extends State<SdDashboardView> {
  final _selectKey = GlobalKey();

  String _t(String s) => widget.tr(s);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final stacked = c.maxWidth < kSdDashboardSplit;
      // the rows drop their delay column when the list is narrow
      final mainWidth = stacked ? c.maxWidth : c.maxWidth - kSdAsideWidth;
      final narrow = mainWidth - 48 < 560;
      if (stacked) {
        return SdCompact(narrow: narrow, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_aside(context, stacked: true), _main(context, mainWidth)]));
      }
      // the window gives the page its height: nothing scrolls but the left panel (when the window is very low) and the list of computers
      if (c.hasBoundedHeight) {
        return SdCompact(
          narrow: narrow,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: kSdAsideWidth, child: _aside(context, stacked: false, scroll: true)),
            Expanded(child: _main(context, mainWidth, scroll: true)),
          ]),
        );
      }
      // no height given (the page scrolls as a whole): each column is as high as it is
      return SdCompact(
        narrow: narrow,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: kSdAsideWidth, child: _aside(context, stacked: false)),
          Expanded(child: _main(context, mainWidth)),
        ]),
      );
    });
  }

  // ---------------------------------------------------------------- This computer

  Widget _aside(BuildContext context, {required bool stacked, bool scroll = false}) {
    final t = SdSkin.of(context);
    final children = <Widget>[
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_t('This computer'), style: sdTs(17, FontWeight.w600, t.ink)),
        const SizedBox(height: 6),
        _status(t),
      ]),
      _idBlock(t),
      _passwordBlock(t),
      const SdHr(),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(_t('Unattended Access'), style: sdTs(15, FontWeight.w400, t.ink))),
        const SizedBox(width: 12),
        SdOnOff(value: widget.unattended, onChanged: widget.onUnattended),
      ]),
      _permissions(t),
      const SdHr(),
      _usage(t),
      SdButton(icon: SdIcons.link, label: _t('Copy invite message'), block: true, small: true, onTap: widget.onShare),
    ];
    final column = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 18), children[i]],
    ]);
    final decoration = BoxDecoration(color: t.chrome, border: Border(right: stacked ? BorderSide.none : BorderSide(color: t.line), bottom: stacked ? BorderSide(color: t.line) : BorderSide.none));
    if (!scroll) return DecoratedBox(decoration: decoration, child: Padding(padding: const EdgeInsets.all(22), child: column));
    // in the height the window gives: a window too low for the panel scrolls it
    return DecoratedBox(
      decoration: decoration,
      child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: column),
    );
  }

  Widget _idBlock(SdSkin t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_t('SystemDesk ID'), style: sdTs(12.5, FontWeight.w500, t.mut)),
      const SizedBox(height: 4),
      Row(children: [
        // the whole ID is always shown: a long one is made smaller instead of being cut
        Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(widget.id, maxLines: 1, style: sdTs(28, FontWeight.w600, t.ink, ls: 0.3, lh: 1.2, figures: true)))),
        const SizedBox(width: 8),
        SdToolButton(icon: SdIcons.copy, tooltip: _t('Copy'), onTap: widget.onCopyId),
      ]),
    ]);
  }

  Widget _passwordBlock(SdSkin t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_t('One-time password'), style: sdTs(12.5, FontWeight.w500, t.mut)),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(child: Text(widget.passwordShown ? widget.password : '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(18, FontWeight.w600, t.ink, ls: 0.9, figures: true))),
        SdToolButton(icon: SdIcons.copy, tooltip: _t('Copy'), onTap: widget.passwordShown ? widget.onCopyPassword : null),
        SdToolButton(icon: SdIcons.refresh, tooltip: _t('Refresh Password'), onTap: widget.passwordShown ? widget.onNewPassword : null),
        SdToolButton(icon: SdIcons.gear, tooltip: _t('Settings'), onTap: widget.onPasswordSettings),
      ]),
    ]);
  }

  Widget _permissions(SdSkin t) {
    final labels = {'full': 'Full Access', 'view': 'View Only', 'custom': 'Custom'};
    final select = SdSelect(label: _t(labels[widget.access] ?? 'Custom'), onTap: null);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_t('Permissions'), style: sdTs(12.5, FontWeight.w500, t.mut)),
      const SizedBox(height: 6),
      if (widget.accessLocked)
        Opacity(opacity: 0.6, child: select)
      else
        SdPopoverAnchor(
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          anchorBuilder: (context, toggle, open) => SdSelect(
            key: _selectKey,
            label: _t(labels[widget.access] ?? 'Custom'),
            onTap: toggle,
          ),
          // as wide as the select it opens from
          popupBuilder: (context, close) => SdMenu(width: (_selectKey.currentContext?.size?.width ?? kSdAsideWidth - 44), children: [
            for (final e in labels.entries)
              SdMenuItem(
                label: _t(e.value),
                selected: widget.access == e.key,
                trailingCheck: widget.access == e.key,
                onTap: () {
                  close();
                  widget.onAccess?.call(e.key);
                },
              ),
          ]),
        ),
    ]);
  }

  Widget _usage(SdSkin t) {
    final u = widget.usage;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(_t('Today'), style: sdTs(14, FontWeight.w500, t.ink)),
        Flexible(child: Text(u?.text ?? _t('Sign in to see your usage'), maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(13.5, FontWeight.w400, t.mut, figures: true))),
      ]),
      const SizedBox(height: 8),
      SdMeter(value: u?.fraction ?? 0),
    ]);
  }

  Widget _status(SdSkin t) {
    String label;
    Color color;
    Color? led;
    switch (widget.service) {
      case SdServiceStatus.ready:
        label = _t('Ready (Encrypted)');
        color = t.ok;
        break;
      case SdServiceStatus.connecting:
        label = _t('Connecting...');
        color = t.goldTxt;
        led = t.goldB;
        break;
      case SdServiceStatus.notReady:
        label = _t('Not ready');
        color = t.bad;
        led = t.bad;
        break;
      case SdServiceStatus.stopped:
        label = _t('Service is not running');
        color = t.bad;
        led = t.bad;
        break;
    }
    final line = Row(children: [
      SdLed(size: 9, color: led),
      const SizedBox(width: 8),
      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(13.5, FontWeight.w500, color))),
    ]);
    // the way to start it is under the line, so neither it nor the words are cut
    if (widget.service == SdServiceStatus.stopped && widget.onStartService != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        line,
        const SizedBox(height: 4),
        Align(alignment: Alignment.centerLeft, child: Transform.translate(offset: const Offset(-8, 0), child: SdLink(_t('Start service'), onTap: widget.onStartService))),
      ]);
    }
    return line;
  }

  // ---------------------------------------------------------------- the lists of computers

  Widget _main(BuildContext context, double width, {bool scroll = false}) {
    final t = SdSkin.of(context);
    // tabs and tools on one line when there is room for both, else the tools under the tabs
    final oneLine = width >= 780;
    final header = DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: oneLine
            ? Row(children: [Expanded(child: widget.tabs), const SizedBox(width: 12), if (widget.tools != null) widget.tools!])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                widget.tabs,
                if (widget.tools != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Align(alignment: Alignment.centerRight, child: widget.tools!)),
              ]),
      ),
    );
    const pad = EdgeInsets.fromLTRB(24, 20, 24, 28);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      if (scroll)
        // the tabs stay where they are; the list of computers scrolls in the rest of the height
        Expanded(child: SingleChildScrollView(padding: pad, child: widget.body))
      else
        Padding(padding: pad, child: widget.body),
    ]);
  }
}

/// Puts text on the clipboard and tells so, the way the dashboard's copy buttons do.
Future<void> sdCopy(BuildContext context, String text, String message) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) SdToast.show(context, message);
}
