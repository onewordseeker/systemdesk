import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/screens/sd_dashboard.dart' show SdLaunch;
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:flutter_hbb/services/license_service.dart';

/// An ID made of a name instead of digits, in the form the core accepts for a chosen ID: a letter first, then letters, digits, "_" or "-", 6 to 16 in all.
bool sdIsNameId(String s) => RegExp(r'^[a-zA-Z][\w-]{5,15}$').hasMatch(s);

/// The ID to connect to for what was typed ([listed] = the IDs of the computers the list shows now, filtered by the same text): a number as typed; a name ID as typed
/// (this computer may never have been connected to, so it is not in the list); otherwise the first computer of the list. Empty when there is nothing to connect to.
/// IDs are compared exactly by the servers, so a name ID goes on as it was typed, capital letters and all, unless the list holds the computer with its own spelling.
String sdQuickTarget(String typed, List<String> listed) {
  final raw = trimID(typed);
  if (RegExp(r'^\d{6,}$').hasMatch(raw)) return raw;
  if (listed.contains(raw)) return raw;
  if (listed.isNotEmpty) return listed.first;
  final name = typed.trim();
  return sdIsNameId(name) ? name : '';
}

/// An alias, the name an owner gave a computer: 3 to 64 characters, letters, numbers and . _ - @, starting with a letter or number, never only numbers
/// (the same rule as the server, `services/device_alias.js`).
bool sdIsAlias(String s) => RegExp(r'^[A-Za-z0-9][A-Za-z0-9._@-]{2,63}$').hasMatch(s) && !RegExp(r'^\d+$').hasMatch(s);

/// [sdQuickTarget] with the server's help: a number goes straight on; an ID the list already holds goes on as it is; anything that can be an alias is
/// looked up by [resolveAlias] (the server answers with the numeric ID); when that finds nothing (or nobody is signed in) the old rules decide.
Future<String> sdQuickResolve(String typed, List<String> listed, Future<String?> Function(String alias) resolveAlias) async {
  final raw = trimID(typed);
  if (RegExp(r'^\d{6,}$').hasMatch(raw) || listed.contains(raw)) return raw;
  final word = typed.trim();
  if (sdIsAlias(word)) {
    final id = await resolveAlias(word);
    if (id != null && id.isNotEmpty) return id;
  }
  return sdQuickTarget(typed, listed);
}

/// Starts a session from what the toolbar field holds: a number, an alias (the server turns it into the numeric ID), or a name (then the first computer of
/// the list as it is filtered now). A name ID (an old ID made of letters) works as typed.
Future<void> sdQuickLaunch(BuildContext context, TextEditingController text, SdLaunch how) async {
  final id = await sdQuickResolve(text.text, gFFI.peerTabModel.currentTabCachedPeers.map((p) => p.id).toList(), LicenseService.instance.resolveAlias);
  if (!context.mounted) return;
  if (id.isEmpty) {
    SdToast.show(context, translate('Type an ID or pick a computer'));
    return;
  }
  connect(context, id,
      isFileTransfer: how == SdLaunch.files,
      isViewCamera: how == SdLaunch.camera,
      isTerminal: how == SdLaunch.terminal,
      isTcpTunneling: how == SdLaunch.tunnel);
}

/// The one field of the toolbar: type an ID (or part of a name) and press Connect, or open the list beside it to start a file transfer, a camera view, a terminal or a
/// tunnel instead.
class SdAddressBar extends StatelessWidget {
  const SdAddressBar({super.key, required this.controller, this.onChanged, this.onSubmit, this.onLaunch, this.tr = _same});
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmit;
  final ValueChanged<SdLaunch>? onLaunch;
  final String Function(String) tr;

  static String _same(String s) => s;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return SdBox(
      radius: 12,
      color: t.pa,
      borderColor: t.line2,
      height: 44,
      padding: const EdgeInsets.only(left: 14, right: 5),
      child: Row(children: [
        SdIcon(SdIcons.monitor, size: 18, color: t.mut, stroke: 1.8),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit?.call(),
            style: sdTs(15, FontWeight.w400, t.ink, lh: 1.3),
            cursorColor: t.goldB,
            inputFormatters: [IDTextInputFormatter()],
            decoration: InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: tr('Enter SystemDesk ID or search computers'),
              hintStyle: sdTs(15, FontWeight.w400, t.mut, lh: 1.3),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SdLaunchSplit(label: tr('Connect'), choose: tr('Choose how to connect'), tr: tr, onLaunch: onLaunch),
      ]),
    );
  }
}

/// The split button: "Connect" starts a remote control session, the arrow beside it opens the other kinds of session.
class SdLaunchSplit extends StatelessWidget {
  const SdLaunchSplit({super.key, required this.label, required this.choose, required this.tr, this.onLaunch});
  final String label, choose;
  final String Function(String) tr;
  final ValueChanged<SdLaunch>? onLaunch;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return SdPopoverAnchor(
      targetAnchor: Alignment.bottomRight,
      followerAnchor: Alignment.topRight,
      offset: const Offset(0, 10),
      anchorBuilder: (context, toggle, open) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(color: t.goldB),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _SplitPart(label: label, onTap: () => onLaunch?.call(SdLaunch.remote), padding: 18),
            Container(width: 1, height: 34, color: const Color(0x40000000)),
            _SplitPart(icon: SdIcons.chevronDown, onTap: toggle, padding: 9, tooltip: choose),
          ]),
        ),
      ),
      popupBuilder: (context, close) => SdMenu(width: 250, children: [
        for (final e in [
          (SdLaunch.remote, SdIcons.monitor, 'Remote control'),
          (SdLaunch.files, SdIcons.folder, 'File transfer'),
          (SdLaunch.camera, SdIcons.video, 'View camera'),
          (SdLaunch.terminal, SdIcons.terminal, 'Terminal'),
          (SdLaunch.tunnel, SdIcons.swap, 'TCP tunneling'),
        ])
          SdMenuItem(
            icon: e.$2,
            label: tr(e.$3),
            onTap: () {
              close();
              onLaunch?.call(e.$1);
            },
          ),
      ]),
    );
  }
}

class _SplitPart extends StatefulWidget {
  const _SplitPart({this.label, this.icon, required this.onTap, required this.padding, this.tooltip});
  final String? label, icon, tooltip;
  final VoidCallback onTap;
  final double padding;

  @override
  State<_SplitPart> createState() => _SplitPartState();
}

class _SplitPartState extends State<_SplitPart> {
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
          height: 34,
          padding: EdgeInsets.symmetric(horizontal: widget.padding),
          color: _hover ? const Color(0x14000000) : Colors.transparent,
          alignment: Alignment.center,
          child: widget.icon != null
              ? SdIcon(widget.icon!, size: 16, color: t.goldInk, stroke: 2.2)
              : Text(widget.label!, style: sdTs(14, FontWeight.w600, t.goldInk)),
        ),
      ),
    );
    if (widget.tooltip != null) w = Tooltip(message: widget.tooltip!, waitDuration: const Duration(milliseconds: 700), child: w);
    return w;
  }
}
