import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_peers.dart' show SdCompact;
import 'package:flutter_hbb/screens/sd_tone.dart';

/// The state of the connection service, as the last line of the left panel says it.
enum SdServiceStatus { ready, connecting, notReady, stopped }

/// How a session is started from Quick Connect.
enum SdLaunch { remote, files, camera, terminal, tunnel }

/// One line of "Today": the text ("18 of 60 min") and how full the bar is (0 to 1). null: nothing to show yet.
class SdUsage {
  const SdUsage(this.text, this.fraction);
  final String text;
  final double fraction;
}

/// The Dashboard of the design: the Local Machine panel at the left, Quick Connect and the Saved Computers at the right. It draws and nothing else: what it
/// shows and what its buttons do come in as values and callbacks, so the real page ([SdDashboard]) and the test pictures use the same widget.
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
    required this.query,
    this.onQuery,
    this.onSubmit,
    this.onLaunch,
    required this.tabs,
    required this.body,
    this.tr = _same,
    this.permOpen = true,
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
  final VoidCallback? onStartService, onCopyId, onShare, onCopyPassword, onNewPassword, onPasswordSettings, onSubmit;
  final TextEditingController query;
  final ValueChanged<String>? onQuery;
  final ValueChanged<SdLaunch>? onLaunch;

  /// the lists of computers: the tabs and the open list
  final Widget tabs, body;
  final String Function(String) tr;

  /// the list of permissions starts open, as the design shows it
  final bool permOpen;

  static String _same(String s) => s;

  @override
  State<SdDashboardView> createState() => _SdDashboardViewState();
}

class _SdDashboardViewState extends State<SdDashboardView> {
  late bool _permOpen = widget.permOpen;

  String _t(String s) => widget.tr(s);

  List<Widget> _spaced(List<Widget> cs, double gap) => [
        for (var i = 0; i < cs.length; i++) ...[if (i > 0) SizedBox(height: gap), cs[i]],
      ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: LayoutBuilder(builder: (context, c) {
        final stacked = c.maxWidth < 980;
        // the right column is what is left of the page after the left panel and the gap; the rows drop their delay column when it is narrow
        final rightWidth = stacked ? c.maxWidth : c.maxWidth - 344 - 28;
        if (stacked) {
          return SdCompact(narrow: rightWidth < 560, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_local(context, stacked: true), const SizedBox(height: 28), _right(context, rightWidth < 720)]));
        }
        return SdCompact(
          narrow: rightWidth < 560,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(width: 344, child: _local(context, stacked: false)),
              const SizedBox(width: 28),
              Expanded(child: _right(context, rightWidth < 720)),
            ]),
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------------- Local Machine

  Widget _local(BuildContext context, {required bool stacked}) {
    final t = SdSkin.of(context);
    final accessLabel = {'full': 'Full Access', 'view': 'View Only', 'custom': 'Custom'};
    final perms = [('full', 'Full Access'), ('view', 'View Only'), ('custom', 'Custom')];
    final children = <Widget>[
      Text(_t('Local Machine'), style: sdTs(20, FontWeight.w500, t.ink, ls: -0.2)),
      _idBox(t),
      SdButton(
        kind: SdBtnKind.navy,
        block: true,
        height: 48,
        fontSize: 16,
        icon: SdIcons.link,
        label: _t('Share Invite Link'),
        onTap: widget.onShare,
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Text(_t('Temp Password:'), style: sdTs(16, FontWeight.w400, t.ink)),
          const SizedBox(width: 8),
          Flexible(child: Text(widget.passwordShown ? widget.password : '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(16, FontWeight.w600, t.ink, ls: 0.64))),
        ]),
      ),
      Row(children: [
        SdIconButton(icon: SdIcons.copy, tooltip: _t('Copy'), onTap: widget.passwordShown ? widget.onCopyPassword : null),
        const SizedBox(width: 10),
        SdIconButton(icon: SdIcons.refresh, tooltip: _t('Refresh Password'), onTap: widget.passwordShown ? widget.onNewPassword : null),
        const SizedBox(width: 10),
        SdIconButton(icon: SdIcons.gear, tooltip: _t('Settings'), onTap: widget.onPasswordSettings),
      ]),
      const SdHr(margin: EdgeInsets.symmetric(vertical: 4)),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(_t('Unattended Access'), style: sdTs(15.5, FontWeight.w400, t.ink))),
        const SizedBox(width: 12),
        SdOnOff(value: widget.unattended, onChanged: widget.onUnattended),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SdSelect(label: _t('Security & Permissions'), onTap: widget.accessLocked ? null : () => setState(() => _permOpen = !_permOpen)),
        if (_permOpen && !widget.accessLocked) ...[
          const SizedBox(height: 6),
          SdMenu(children: [
            for (final p in perms)
              SdMenuItem(
                label: accessLabel[p.$1]!,
                selected: widget.access == p.$1,
                onTap: () {
                  widget.onAccess?.call(p.$1);
                  setState(() => _permOpen = false);
                },
              ),
          ]),
        ],
      ]),
      const SdHr(margin: EdgeInsets.symmetric(vertical: 2)),
      _usage(t),
      // the status line sits at the bottom of the panel (margin-top: auto in the design)
      if (!stacked) const Expanded(child: SizedBox()),
      _status(t),
    ];
    return SdPanel(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0 && children[i - 1] is! Expanded) const SizedBox(height: 14),
          children[i],
        ],
      ]),
    );
  }

  Widget _idBox(SdSkin t) {
    return SdInset(
      ring: true,
      height: 88,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.5),
        child: Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_t('Local Machine ID:'), style: sdTs(13.5, FontWeight.w400, t.mut)),
                Text(widget.id, maxLines: 1, style: sdTs(31, FontWeight.w600, t.ink, ls: 0.31, lh: 1.15, figures: true)),
              ]),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onCopyId,
              child: Tooltip(
                message: _t('Copy'),
                child: Container(
                  width: 58,
                  height: double.infinity,
                  decoration: BoxDecoration(gradient: t.raised, border: Border(left: BorderSide(color: t.line))),
                  alignment: Alignment.center,
                  child: SdIcon(SdIcons.copy, size: 22, color: t.ink, stroke: 1.8),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _usage(SdSkin t) {
    final u = widget.usage;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(_t('Today'), style: sdTs(14.5, FontWeight.w400, t.ink)),
        Flexible(child: Text(u?.text ?? _t('Sign in to see your usage'), maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(14.5, FontWeight.w400, t.mut, figures: true))),
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
    return Row(children: [
      Text(_t('Service Status:'), style: sdTs(14.5, FontWeight.w400, t.ink)),
      const SizedBox(width: 8),
      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(14.5, FontWeight.w500, color))),
      if (widget.service == SdServiceStatus.stopped && widget.onStartService != null) ...[
        const SizedBox(width: 8),
        SdLink(_t('Start service'), onTap: widget.onStartService),
      ],
      const SizedBox(width: 8),
      SdLed(color: led),
    ]);
  }

  // ---------------------------------------------------------------- Quick Connect and Saved Computers

  Widget _right(BuildContext context, bool narrowHeader) {
    final t = SdSkin.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SdNavyPanel(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_t('Quick Connect'), style: sdTs(20, FontWeight.w500, t.navyInk, ls: -0.2)),
          const SizedBox(height: 14),
          _quickRow(t),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 14),
        child: Builder(builder: (context) {
          final title = Text(_t('Saved Computers'), style: sdTs(20, FontWeight.w500, t.ink, ls: -0.2));
          if (narrowHeader) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), SingleChildScrollView(scrollDirection: Axis.horizontal, child: widget.tabs)]);
          }
          return Row(children: [title, const SizedBox(width: 16), const Spacer(), widget.tabs]);
        }),
      ),
      widget.body,
    ]);
  }

  Widget _quickRow(SdSkin t) {
    final launch = SdPopoverAnchor(
      targetAnchor: Alignment.bottomRight,
      followerAnchor: Alignment.topRight,
      offset: const Offset(0, 8),
      anchorBuilder: (context, toggle, open) => Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), boxShadow: const [BoxShadow(color: Color(0xCCBE821E), blurRadius: 16, spreadRadius: -8, offset: Offset(0, 8))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: t.gold),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _LaunchButton(label: _t('Launch Session'), onTap: () => widget.onLaunch?.call(SdLaunch.remote), padding: 22),
              Container(width: 1, color: const Color(0x59785A0A)),
              _LaunchButton(icon: SdIcons.chevronDown, onTap: toggle, padding: 14, tooltip: _t('Choose how to connect')),
            ]),
          ),
        ),
      ),
      popupBuilder: (context, close) => SdMenu(width: 260, children: [
        for (final e in [
          (SdLaunch.remote, SdIcons.monitor, 'Remote control'),
          (SdLaunch.files, SdIcons.folder, 'File transfer'),
          (SdLaunch.camera, SdIcons.video, 'View camera'),
          (SdLaunch.terminal, SdIcons.terminal, 'Terminal'),
          (SdLaunch.tunnel, SdIcons.swap, 'TCP tunneling'),
        ])
          SdMenuItem(
            icon: e.$2,
            label: _t(e.$3),
            onTap: () {
              close();
              widget.onLaunch?.call(e.$1);
            },
          ),
      ]),
    );
    return SdBox(
      radius: 15,
      color: t.navyField,
      borderColor: t.navyLine,
      inner: const [SdInner(0, 2, 6, Color(0x80000000))],
      height: 56,
      padding: const EdgeInsets.all(5),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: widget.query,
            onChanged: widget.onQuery,
            onSubmitted: (_) => widget.onSubmit?.call(),
            style: sdTs(16.5, FontWeight.w400, t.navyInk, lh: 1.3),
            cursorColor: t.goldA,
            inputFormatters: [IDTextInputFormatter()],
            decoration: InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: _t('Search devices or enter target ID...'),
              hintStyle: sdTs(16.5, FontWeight.w400, const Color(0xFF9DA8BE), lh: 1.3),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        launch,
      ]),
    );
  }
}

class _LaunchButton extends StatefulWidget {
  const _LaunchButton({this.label, this.icon, required this.onTap, required this.padding, this.tooltip});
  final String? label, icon, tooltip;
  final VoidCallback onTap;
  final double padding;

  @override
  State<_LaunchButton> createState() => _LaunchButtonState();
}

class _LaunchButtonState extends State<_LaunchButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    Widget w = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: 46,
          padding: EdgeInsets.symmetric(horizontal: widget.padding),
          color: _hover ? const Color(0x14FFFFFF) : Colors.transparent,
          alignment: Alignment.center,
          child: widget.icon != null
              ? SdIcon(widget.icon!, size: 16, color: t.goldInk, stroke: 2.2)
              : Text(widget.label!, style: sdTs(16.5, FontWeight.w500, t.goldInk)),
        ),
      ),
    );
    if (widget.tooltip != null) w = Tooltip(message: widget.tooltip!, waitDuration: const Duration(milliseconds: 700), child: w);
    return w;
  }
}

/// Puts text on the clipboard and tells so, the way the dashboard's copy buttons do.
Future<void> sdCopy(BuildContext context, String text, String message) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) SdToast.show(context, message);
}
