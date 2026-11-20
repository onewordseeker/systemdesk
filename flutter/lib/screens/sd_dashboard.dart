import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_peers.dart' show SdCompact;
import 'package:flutter_hbb/screens/sd_tone.dart';

/// Below this width of the page the two columns are stacked and the page scrolls as a whole.
const double kSdDashboardSplit = 640;

/// The width of the "This computer" panel in a wide window, and in a window that has been made smaller (the lists get the room).
const double kSdAsideWidth = 330;
const double kSdAsideNarrowWidth = 290;

/// The width of the panel for a page that is [pageWidth] wide.
double sdAsideWidthFor(double pageWidth) => pageWidth >= 1000 ? kSdAsideWidth : kSdAsideNarrowWidth;

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

/// Who is signed in, for the top of the panel: the name, a line under it (plan and login name), the initials and, when the person has one, the photo.
class SdProfile {
  const SdProfile({required this.name, this.sub = '', required this.initials, this.image});
  final String name, sub, initials;
  final ImageProvider? image;
}

/// The "This computer" panel: who is signed in, the state of the service, the SystemDesk ID, the one-time password, unattended access, permissions and
/// today's time. It draws and nothing else; what it shows and what its buttons do come in as values and callbacks. The Dashboard has it at the left of the
/// lists; Devices and Sessions keep it there too, so the ID is always in view. [stacked]: the panel is above the page (a narrow window) and shows only
/// the ID and the state until it is opened. [scroll]: a window too low for the panel scrolls it.
class SdAsideView extends StatefulWidget {
  const SdAsideView({
    super.key,
    required this.id,
    required this.password,
    this.passwordShown = true,
    required this.unattended,
    this.onUnattended,
    this.onUnattendedPassword,
    this.unattendedNote,
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
    this.profile,
    this.onProfile,
    this.onSignIn,
    this.stacked = false,
    this.scroll = false,
    this.tr = _same,
  });

  /// "408 241 669"
  final String id;
  final String password;

  /// false: the one-time password is not in use (the line shows a dash and its buttons are off)
  final bool passwordShown;
  final bool unattended;
  final ValueChanged<bool>? onUnattended;

  /// "Change password" under the switch (shown while unattended access is on)
  final VoidCallback? onUnattendedPassword;

  /// the line under the switch while it is on ("Password of Hamid Raza")
  final String? unattendedNote;

  /// 'full', 'view' or 'custom'
  final String access;
  final ValueChanged<String>? onAccess;
  final bool accessLocked;
  final SdUsage? usage;
  final SdServiceStatus service;
  final VoidCallback? onStartService, onCopyId, onShare, onCopyPassword, onNewPassword, onPasswordSettings;

  /// who is signed in (null: nobody; [onSignIn] is then offered)
  final SdProfile? profile;
  final VoidCallback? onProfile, onSignIn;
  final bool stacked, scroll;
  final String Function(String) tr;

  static String _same(String s) => s;

  @override
  State<SdAsideView> createState() => _SdAsideViewState();
}

class _SdAsideViewState extends State<SdAsideView> {
  final _selectKey = GlobalKey();
  bool _open = false;

  String _t(String s) => widget.tr(s);

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final stacked = widget.stacked;
    // who is signed in comes first, then this computer; a narrow window shows the state and the ID, and the rest when opened
    final children = <Widget>[
      if (stacked) _summary(t) else ...[_profile(t), const SdHr(), _title(t)],
      if (!stacked || _open) ...[
        if (stacked) ...[_profile(t), const SdHr()],
        _idBlock(t),
        _passwordBlock(t),
        const SdHr(),
        _unattended(t),
        _permissions(t),
        const SdHr(),
        _usage(t),
        SdButton(icon: SdIcons.link, label: _t('Copy invite message'), block: true, small: true, onTap: widget.onShare),
      ],
    ];
    final column = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: i == 3 && !stacked ? 12 : 18), children[i]],
    ]);
    final decoration = BoxDecoration(color: t.chrome, border: Border(right: stacked ? BorderSide.none : BorderSide(color: t.line), bottom: stacked ? BorderSide(color: t.line) : BorderSide.none));
    final pad = EdgeInsets.all(stacked ? 18 : 22);
    if (!widget.scroll) return DecoratedBox(decoration: decoration, child: Padding(padding: pad, child: column));
    // in the height the window gives: a window too low for the panel scrolls it
    return DecoratedBox(decoration: decoration, child: SingleChildScrollView(padding: pad, child: column));
  }

  // ---------------------------------------------------------------- who, and the ID

  Widget _title(SdSkin t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_t('This computer'), style: sdTs(17, FontWeight.w600, t.ink)),
        const SizedBox(height: 6),
        _status(t),
      ]);

  /// a narrow window: the state and the ID on one line, and a way to open the rest
  Widget _summary(SdSkin t) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _open = !_open),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(children: [
          Expanded(child: _title(t)),
          const SizedBox(width: 12),
          // opened, the ID is in the panel below: it is not said twice
          if (!_open) ...[
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(widget.id, maxLines: 1, style: sdTs(22, FontWeight.w600, t.ink, ls: 0.3, figures: true)))),
            const SizedBox(width: 6),
            SdToolButton(icon: SdIcons.copy, tooltip: _t('Copy'), onTap: widget.onCopyId),
          ],
          SdIcon(_open ? SdIcons.chevronUp : SdIcons.chevronDown, size: 18, color: t.mut, stroke: 2),
        ]),
      ),
    );
  }

  Widget _profile(SdSkin t) {
    final p = widget.profile;
    if (p == null) {
      return Row(children: [
        SdAvatar(initials: '', size: 44, onTap: widget.onSignIn),
        const SizedBox(width: 12),
        Expanded(child: Text(_t('Not signed in'), maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(15, FontWeight.w500, t.ink))),
        SdButton(small: true, kind: SdBtnKind.gold, label: _t('Sign in'), onTap: widget.onSignIn),
      ]);
    }
    return MouseRegion(
      cursor: widget.onProfile == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onProfile,
        child: Row(children: [
          SdAvatar(initials: p.initials, image: p.image, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(15.5, FontWeight.w600, t.ink, lh: 1.25)),
              if (p.sub.isNotEmpty) Text(p.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(12.5, FontWeight.w400, t.mut, lh: 1.3)),
            ]),
          ),
          if (widget.onProfile != null) SdIcon(SdIcons.chevronRight, size: 16, color: t.mut, stroke: 2),
        ]),
      ),
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

  Widget _unattended(SdSkin t) {
    final note = widget.unattended ? widget.unattendedNote : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(_t('Unattended Access'), style: sdTs(15, FontWeight.w400, t.ink))),
        const SizedBox(width: 12),
        SdOnOff(value: widget.unattended, onChanged: widget.onUnattended),
      ]),
      if (widget.unattended && (note != null || widget.onUnattendedPassword != null))
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            SdIcon(SdIcons.key, size: 15, color: t.mut, stroke: 2),
            const SizedBox(width: 6),
            Expanded(child: Text(note ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(12.5, FontWeight.w400, t.mut))),
            if (widget.onUnattendedPassword != null) Transform.translate(offset: const Offset(8, 0), child: SdLink(_t('Change'), onTap: widget.onUnattendedPassword)),
          ]),
        ),
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
}

/// The Dashboard: the "This computer" panel flush at the left and the lists of computers at the right (tabs, their tools, the cards or rows). It draws and
/// nothing else: what it shows and what its buttons do come in as values and callbacks, so the real page ([SdDashboard]) and the test pictures use the same
/// widget. Starting a session is the address bar of the toolbar. [aside] replaces the panel the values below would make (the real page builds its own).
/// Below [kSdDashboardSplit] the panel goes above the lists, folded to the ID and the state.
class SdDashboardView extends StatelessWidget {
  const SdDashboardView({
    super.key,
    this.id = '',
    this.password = '',
    this.passwordShown = true,
    this.unattended = false,
    this.onUnattended,
    this.access = 'custom',
    this.onAccess,
    this.accessLocked = false,
    this.usage,
    this.service = SdServiceStatus.ready,
    this.onStartService,
    this.onCopyId,
    this.onShare,
    this.onCopyPassword,
    this.onNewPassword,
    this.onPasswordSettings,
    this.profile,
    this.onProfile,
    this.onSignIn,
    this.onUnattendedPassword,
    this.unattendedNote,
    this.aside,
    required this.tabs,
    this.tools,
    required this.body,
    this.tr = _same,
  });

  final String id, password;
  final bool passwordShown, unattended, accessLocked;
  final ValueChanged<bool>? onUnattended;
  final String access;
  final ValueChanged<String>? onAccess;
  final SdUsage? usage;
  final SdServiceStatus service;
  final VoidCallback? onStartService, onCopyId, onShare, onCopyPassword, onNewPassword, onPasswordSettings, onProfile, onSignIn, onUnattendedPassword;
  final SdProfile? profile;
  final String? unattendedNote;

  /// makes the panel (the real page builds it from the app's data); it is told whether it sits above the page (narrow window) and whether it must scroll
  final Widget Function({required bool stacked, required bool scroll})? aside;

  /// the lists of computers: the tabs (they get the width they are given), the tools at their right, and the open list
  final Widget tabs, body;
  final Widget? tools;
  final String Function(String) tr;

  static String _same(String s) => s;

  Widget _panel({required bool stacked, bool scroll = false}) =>
      aside?.call(stacked: stacked, scroll: scroll) ??
      SdAsideView(
        id: id,
        password: password,
        passwordShown: passwordShown,
        unattended: unattended,
        onUnattended: onUnattended,
        onUnattendedPassword: onUnattendedPassword,
        unattendedNote: unattendedNote,
        access: access,
        onAccess: onAccess,
        accessLocked: accessLocked,
        usage: usage,
        service: service,
        onStartService: onStartService,
        onCopyId: onCopyId,
        onShare: onShare,
        onCopyPassword: onCopyPassword,
        onNewPassword: onNewPassword,
        onPasswordSettings: onPasswordSettings,
        profile: profile,
        onProfile: onProfile,
        onSignIn: onSignIn,
        stacked: stacked,
        scroll: scroll,
        tr: tr,
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final stacked = c.maxWidth < kSdDashboardSplit;
      final asideWidth = sdAsideWidthFor(c.maxWidth);
      // the rows drop their delay column when the list is narrow
      final mainWidth = stacked ? c.maxWidth : c.maxWidth - asideWidth;
      final narrow = mainWidth - 48 < 560;
      if (stacked) {
        return SdCompact(narrow: narrow, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_panel(stacked: true), _main(context, mainWidth)]));
      }
      // the window gives the page its height: nothing scrolls but the left panel (when the window is very low) and the list of computers
      if (c.hasBoundedHeight) {
        return SdCompact(
          narrow: narrow,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: asideWidth, child: _panel(stacked: false, scroll: true)),
            Expanded(child: _main(context, mainWidth, scroll: true)),
          ]),
        );
      }
      // no height given (the page scrolls as a whole): each column is as high as it is
      return SdCompact(
        narrow: narrow,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: asideWidth, child: _panel(stacked: false)),
          Expanded(child: _main(context, mainWidth)),
        ]),
      );
    });
  }

  // ---------------------------------------------------------------- the lists of computers

  Widget _main(BuildContext context, double width, {bool scroll = false}) {
    final t = SdSkin.of(context);
    // tabs and tools on one line at every width: the tabs give way (a "More" tab) before the tools do
    final header = DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [Expanded(child: tabs), const SizedBox(width: 12), if (tools != null) tools!]),
      ),
    );
    final pad = EdgeInsets.fromLTRB(width < 560 ? 16 : 24, 20, width < 560 ? 16 : 24, 28);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      if (scroll)
        // the tabs stay where they are; the list of computers scrolls in the rest of the height
        Expanded(child: SingleChildScrollView(padding: pad, child: body))
      else
        Padding(padding: pad, child: body),
    ]);
  }
}

/// Puts text on the clipboard and tells so, the way the dashboard's copy buttons do.
Future<void> sdCopy(BuildContext context, String text, String message) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) SdToast.show(context, message);
}
