import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_toolbar.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';

/// What the session card says about a session. All of it is already known to the app (the connection type, the quality monitor, the permissions the other
/// computer gave, what it told about itself); the card only puts it in order.
class SdSessionFacts {
  const SdSessionFacts({
    this.secure,
    this.direct,
    this.delay,
    this.fps,
    this.speed,
    this.codec,
    this.encryption = '',
    this.fingerprint = '',
    this.streamType = '',
    required this.name,
    required this.id,
    this.user = '',
    this.platform = '',
    this.version = '',
    this.displays = 0,
    this.permissions = const [],
  });

  /// null: not known yet (still connecting)
  final bool? secure, direct;
  final String? delay, fps, speed, codec;
  final String encryption, fingerprint, streamType;
  final String name, id, user, platform, version;
  final int displays;

  /// what the person at this end may do on the other computer: (words, allowed)
  final List<(String, bool)> permissions;
}

/// The card of a session: the verdict first (is it safe, how is it connected), then three tabs: the connection, what you may do, the computer. It floats
/// over the other computer's screen, so it is dark like the toolbar it opens from.
class SdSessionCard extends StatefulWidget {
  const SdSessionCard({super.key, required this.facts, this.tr = _same, this.onCopyFingerprint, this.initialTab = 0});
  final SdSessionFacts facts;
  final String Function(String) tr;
  final ValueChanged<String>? onCopyFingerprint;
  final int initialTab;

  static String _same(String s) => s;

  @override
  State<SdSessionCard> createState() => _SdSessionCardState();
}

class _SdSessionCardState extends State<SdSessionCard> {
  late int _tab = widget.initialTab;
  bool _technical = false;

  String _t(String s) => widget.tr(s);

  static const _ok = Color(0xFF4BDE8A);
  static const _bad = Color(0xFFFF8F85);
  static const _line = Color(0x1FFFFFFF);

  @override
  Widget build(BuildContext context) {
    final f = widget.facts;
    final secure = f.secure;
    final Color verdictColor = secure == null ? SdToolbar.gold : (secure ? _ok : _bad);
    final String verdict = secure == null ? _t('Connecting...') : (secure ? _t('Secure connection') : _t('Not encrypted'));
    final String detail = secure == null
        ? _t('Waiting for the other computer.')
        : secure
            ? _t('Only you and this computer can read this session.')
            : _t('Anyone on the network could read this session.');
    return Container(
      width: 360,
      decoration: BoxDecoration(color: SdToolbar.panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: SdToolbar.edge), boxShadow: SdToolbar.barShadows),
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: verdictColor.withOpacity(0.16), borderRadius: BorderRadius.circular(10)),
            child: SdIcon(secure == false ? SdIcons.alertTriangle : SdIcons.shield, size: 21, color: verdictColor, stroke: 1.9),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(verdict, style: sdTs(16, FontWeight.w600, SdToolbar.menuInk, lh: 1.25)),
              const SizedBox(height: 2),
              Text(detail, style: sdTs(13, FontWeight.w400, SdToolbar.menuMut, lh: 1.35)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _Pill(f.direct == null ? _t('Connecting...') : (f.direct! ? _t('Direct connection') : _t('Through a relay'))),
          if (f.delay != null && f.delay!.isNotEmpty) _Pill('${f.delay} ms'),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          for (final e in [(_t('Connection'), 0), (_t('What you may do'), 1), (_t('Device'), 2)]) ...[
            _TabLabel(label: e.$1, on: _tab == e.$2, onTap: () => setState(() => _tab = e.$2)),
            const SizedBox(width: 4),
          ],
        ]),
        Container(height: 1, color: _line),
        const SizedBox(height: 8),
        if (_tab == 0) ..._connection(f),
        if (_tab == 1) ..._permissions(f),
        if (_tab == 2) ..._device(f),
      ]),
    );
  }

  List<Widget> _connection(SdSessionFacts f) {
    final fp = f.fingerprint;
    return [
      _Row(_t('Route'), f.direct == null ? '—' : (f.direct! ? _t('Direct') : _t('Relay'))),
      _Row(_t('Delay'), f.delay == null || f.delay!.isEmpty ? '—' : '${f.delay} ms'),
      _Row(_t('Encryption'), f.secure == null ? '—' : (f.secure! ? _t('Encrypted') : _t('Not encrypted'))),
      const SizedBox(height: 4),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _technical = !_technical),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(child: Text(_t('Technical details'), style: sdTs(13.5, FontWeight.w600, SdToolbar.gold))),
              SdIcon(_technical ? SdIcons.chevronDown : SdIcons.chevronRight, size: 16, color: SdToolbar.gold, stroke: 2.2),
            ]),
          ),
        ),
      ),
      if (_technical) ...[
        _Row(_t('Frame rate'), f.fps == null || f.fps!.isEmpty ? '—' : f.fps!),
        _Row(_t('Speed'), f.speed == null || f.speed!.isEmpty ? '—' : f.speed!),
        _Row(_t('Codec'), f.codec == null || f.codec!.isEmpty ? '—' : f.codec!),
        if (f.encryption.isNotEmpty) _Row(_t('Cipher'), f.encryption),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text(_t('Fingerprint'), style: sdTs(13, FontWeight.w400, SdToolbar.menuMut))),
          if (fp.isNotEmpty)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  if (widget.onCopyFingerprint != null) {
                    widget.onCopyFingerprint!(fp);
                  } else {
                    Clipboard.setData(ClipboardData(text: fp));
                  }
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SdIcon(SdIcons.copy, size: 14, color: SdToolbar.gold, stroke: 2),
                  const SizedBox(width: 4),
                  Text(_t('Copy'), style: sdTs(13, FontWeight.w500, SdToolbar.gold)),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(8)),
          child: SelectableText(fp.isEmpty ? 'N/A' : _grouped(fp), style: sdTs(12.5, FontWeight.w500, SdToolbar.menuInk, lh: 1.5, figures: true, ls: 0.4)),
        ),
      ],
    ];
  }

  /// "aabbccdd..." -> "aabb ccdd ..." (groups of four, so it can be read out and compared)
  static String _grouped(String s) {
    final plain = s.replaceAll(RegExp(r'[\s:]'), '');
    if (plain.length < 8) return s;
    final b = StringBuffer();
    for (var i = 0; i < plain.length; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(plain[i]);
    }
    return b.toString();
  }

  List<Widget> _permissions(SdSessionFacts f) {
    if (f.permissions.isEmpty) return [Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('—', style: sdTs(13.5, FontWeight.w400, SdToolbar.menuMut)))];
    return [
      for (final p in f.permissions)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SdIcon(p.$2 ? SdIcons.check : SdIcons.close, size: 16, color: p.$2 ? _ok : _bad, stroke: 2.4),
            const SizedBox(width: 10),
            Expanded(child: Text(_t(p.$1), style: sdTs(14, FontWeight.w400, p.$2 ? SdToolbar.menuInk : SdToolbar.menuMut))),
            Text(p.$2 ? _t('Allowed') : _t('Not allowed'), style: sdTs(12.5, FontWeight.w500, p.$2 ? _ok : _bad)),
          ]),
        ),
    ];
  }

  List<Widget> _device(SdSessionFacts f) => [
        _Row(_t('Name'), f.name.isEmpty ? '—' : f.name),
        _Row(_t('ID'), f.id),
        if (f.user.isNotEmpty) _Row(_t('Signed in as'), f.user),
        if (f.platform.isNotEmpty) _Row(_t('System'), f.platform),
        if (f.version.isNotEmpty) _Row(_t('Version'), f.version),
        if (f.displays > 0) _Row(_t('Displays'), '${f.displays}'),
      ];
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(999)),
        // a Row, so the pill is as wide as its words (a Container with an alignment would fill the line)
        child: Row(mainAxisSize: MainAxisSize.min, children: [Text(text, style: sdTs(12, FontWeight.w500, SdToolbar.menuInk, lh: 1.0, figures: true))]),
      );
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 2, color: on ? SdToolbar.gold : Colors.transparent))),
            child: Text(label, style: sdTs(13.5, on ? FontWeight.w600 : FontWeight.w400, on ? SdToolbar.menuInk : SdToolbar.menuMut, lh: 1.0)),
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(label, style: sdTs(13.5, FontWeight.w400, SdToolbar.menuMut))),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: sdTs(13.5, FontWeight.w500, SdToolbar.menuInk, figures: true))),
        ]),
      );
}
