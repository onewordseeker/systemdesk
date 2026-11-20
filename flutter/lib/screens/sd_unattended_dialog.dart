import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/screens/sd_dashboard.dart' show SdProfile;
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_modal.dart';
import 'package:flutter_hbb/screens/sd_signin_modal.dart' show SdField;
import 'package:flutter_hbb/screens/sd_tone.dart';

/// The rules of an unattended password: the ones the old "Set password" dialog had.
List<(String, bool Function(String))> sdPasswordRules() => [
      ('8 or more characters', (p) => p.length >= 8),
      ('A number', (p) => RegExp(r'\d').hasMatch(p)),
      ('A capital letter', (p) => RegExp(r'[A-Z]').hasMatch(p)),
      ('A small letter', (p) => RegExp(r'[a-z]').hasMatch(p)),
    ];

/// Asks for the unattended password when Unattended Access is switched on: the password someone uses to open this computer without anyone accepting. It
/// belongs to the profile that is signed in (shown at the top), so it is that person who makes it. [onSubmit] saves it and answers null, or says what went wrong.
class SdUnattendedPasswordDialog extends StatefulWidget {
  const SdUnattendedPasswordDialog({super.key, required this.profile, required this.onSubmit, required this.onCancel, this.tr = _same});
  final SdProfile profile;
  final Future<String?> Function(String password) onSubmit;
  final VoidCallback onCancel;
  final String Function(String) tr;

  static String _same(String s) => s;

  @override
  State<SdUnattendedPasswordDialog> createState() => _SdUnattendedPasswordDialogState();
}

class _SdUnattendedPasswordDialogState extends State<SdUnattendedPasswordDialog> {
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  final _rules = sdPasswordRules();
  String? _error;
  bool _busy = false;

  String _t(String s) => widget.tr(s);

  @override
  void initState() {
    super.initState();
    _pass.addListener(_changed);
    _confirm.addListener(_changed);
  }

  void _changed() => setState(() => _error = null);

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _valid => _rules.every((r) => r.$2(_pass.text)) && _pass.text == _confirm.text;

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    setState(() => _busy = true);
    final err = await widget.onSubmit(_pass.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final p = widget.profile;
    final mismatch = _confirm.text.isNotEmpty && _pass.text != _confirm.text;
    return SdModal(
      maxWidth: 480,
      onSubmit: _submit,
      onCancel: widget.onCancel,
      content: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SdBox(radius: 12, color: t.goldSoft, width: 44, height: 44, alignment: Alignment.center, child: SdIcon(SdIcons.key, size: 22, color: t.goldTxt, stroke: 1.9)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_t('Create an unattended password'), style: sdTs(19, FontWeight.w600, t.ink, lh: 1.25)),
              const SizedBox(height: 6),
              Text(_t('Anyone who has this password can open this computer without someone accepting. Only you should know it.'), style: sdTs(14, FontWeight.w400, t.mut, lh: 1.45)),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        SdBox(
          radius: 12,
          color: t.chrome,
          borderColor: t.line,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            SdAvatar(initials: p.initials, image: p.image, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(14.5, FontWeight.w600, t.ink, lh: 1.25)),
                Text(_t('This password belongs to your profile'), maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(12.5, FontWeight.w400, t.mut, lh: 1.3)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        SdField(label: _t('Unattended password'), controller: _pass, obscure: true, autofocus: true, onSubmitted: (_) => _submit()),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 6, children: [for (final r in _rules) _Rule(_t(r.$1), r.$2(_pass.text))]),
        const SizedBox(height: 14),
        SdField(label: _t('Confirm password'), controller: _confirm, obscure: true, onSubmitted: (_) => _submit()),
        if (mismatch || _error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error ?? _t('The confirmation is not identical.'), style: sdTs(13, FontWeight.w500, t.bad)),
          ),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SdIcon(SdIcons.lock, size: 14, color: t.mut, stroke: 2),
          const SizedBox(width: 8),
          Expanded(child: Text(_t('It is kept on this computer only. Someone else who signs in here has to make their own.'), style: sdTs(12.5, FontWeight.w400, t.mut, lh: 1.4))),
        ]),
      ]),
      actions: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          SdButton(label: _t('Cancel'), onTap: widget.onCancel),
          const SizedBox(width: 10),
          SdButton(kind: SdBtnKind.gold, label: _t('Turn on unattended access'), busy: _busy, onTap: _valid ? _submit : null),
        ]),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.label, this.ok);
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SdIcon(ok ? SdIcons.check : SdIcons.close, size: 13, color: ok ? t.ok : t.mut, stroke: 2.4),
      const SizedBox(width: 5),
      Text(label, style: sdTs(12.5, ok ? FontWeight.w500 : FontWeight.w400, ok ? t.ok : t.mut)),
    ]);
  }
}

/// Shows the dialog over the window; [onSubmit] is called with the password (answer null when it is saved, or say what went wrong). Closes itself when saved.
Future<void> showSdUnattendedPassword({required SdProfile profile, required Future<String?> Function(String password) onSubmit}) {
  return gFFI.dialogManager.show<void>(
    (setState, close, context) => SdUnattendedPasswordDialog(
      profile: profile,
      tr: translate,
      onCancel: () => close(),
      onSubmit: (p) async {
        final err = await onSubmit(p);
        if (err == null) close();
        return err;
      },
    ),
    tag: 'sd-unattended-password',
    forceGlobal: true,
  );
}
