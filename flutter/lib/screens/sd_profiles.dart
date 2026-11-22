import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_modal.dart';
import 'package:flutter_hbb/screens/sd_settings.dart';
import 'package:flutter_hbb/screens/sd_signin_modal.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';

/// Permission profiles: each has its own name, its own password and its own permissions. Whoever connects with a profile's password gets that profile's
/// permissions. The profiles are kept by the computer's core (`sd_profiles.rs`); passwords go to it and never come back.
///
/// In Settings > Security the profiles are a list: pick one and its password, its on/off switch and each permission it gives are shown under the list,
/// and a change is saved at once. (The computer's own permissions are the permissions of the profile chosen on the home screen, so there is one set of
/// permissions and not two.)

const _listKey = 'sd-profiles';
const _commandKey = 'sd-profile-command';

const kSdProfileCustom = 'custom';
const kSdProfileFull = 'full';
const kSdProfileView = 'view';

/// the permissions of a profile, in the order they are listed in the approval of a request: (key the core knows, words)
const sdProfilePerms = <(String, String)>[
  ('keyboard', 'Mouse and keyboard'),
  ('clipboard', 'Clipboard'),
  ('file', 'File transfer'),
  ('audio', 'Sound of this computer'),
  ('restart', 'Restart this computer'),
  ('recording', 'Record the session'),
  ('block_input', 'Block this computer\'s own mouse and keyboard'),
  ('privacy_mode', 'Privacy mode (black screen here)'),
  ('system_info', 'System information'),
  ('lock_on_end', 'Lock this computer when the session ends'),
];

/// How the permissions of a profile are listed in Settings: (key the core knows, words, the permission it belongs under or null). A permission under another
/// one is offered only while that one is on.
const sdProfileLayout = <(String, String, String?)>[
  ('audio', 'Hear this computer\'s sound', null),
  ('keyboard', 'Control this computer with the mouse and keyboard', null),
  ('restart', 'Restart this computer', 'keyboard'),
  ('privacy_mode', 'Turn on privacy mode (black screen here)', 'keyboard'),
  ('block_input', 'Block this computer\'s own mouse and keyboard', 'keyboard'),
  ('clipboard', 'Use the clipboard (copy and paste)', null),
  ('file', 'Transfer files', null),
  ('system_info', 'See system information', null),
  ('recording', 'Record the session', null),
  ('lock_on_end', 'Lock this computer when the session ends', null),
];

/// "Full access" and "Screen share" decide every permission but the lock (that one is a rule for the computer, not something a person is given).
const _lockKey = 'lock_on_end';

Map<String, bool> sdProfilePermsFor(String mode, Map<String, bool> current) => {
      for (final p in sdProfilePerms)
        p.$1: p.$1 == _lockKey || mode == kSdProfileCustom ? current[p.$1] == true : mode == kSdProfileFull,
    };

class SdProfile {
  const SdProfile(
      {required this.name,
      required this.enabled,
      required this.hasPassword,
      required this.perms,
      this.mode = kSdProfileCustom,
      this.builtin = false,
      this.active = false,
      this.modified = false});
  final String name;
  final bool enabled, hasPassword;
  final Map<String, bool> perms;
  final String mode;

  /// the profile that gives this computer its own permissions (what a one-time password, an accepted request and the computer's password get), and
  /// whether those were changed by hand since it was chosen
  final bool active, modified;

  /// one of the standard profiles (Default, Screen Sharing, Full Access, Unattended Access): it stays, and only its password and permissions change
  final bool builtin;

  /// the words under the name: what the profile allows
  String get summary {
    if (mode == kSdProfileFull) return 'Full access';
    if (mode == kSdProfileView) return 'Screen share only';
    final on = [for (final p in sdProfilePerms) if (perms[p.$1] == true) p.$2];
    return on.isEmpty ? 'Can only watch the screen' : on.join(' · ');
  }

  /// the line under the name in the list: whether a password lets anyone in with it, and what it allows
  String get status {
    final unattended = !hasPassword
        ? 'No password yet'
        : enabled
            ? 'Unattended access on'
            : 'Unattended access off';
    return '${active ? 'Chosen on the home screen · ' : ''}$unattended · $summary';
  }
}

/// The list the core sends (no passwords in it); a list that cannot be read is empty.
List<SdProfile> sdParseProfiles(String json) {
  try {
    final list = jsonDecode(json);
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map && '${e['name'] ?? ''}'.isNotEmpty)
          SdProfile(
            name: '${e['name']}',
            enabled: e['enabled'] != false,
            hasPassword: e['has_password'] == true,
            builtin: e['builtin'] == true,
            active: e['active'] == true,
            modified: e['modified'] == true,
            mode: e['mode'] == kSdProfileFull || e['mode'] == kSdProfileView ? '${e['mode']}' : kSdProfileCustom,
            perms: {
              for (final p in sdProfilePerms) p.$1: (e['perms'] is Map ? (e['perms'] as Map)[p.$1] : null) == true,
            },
          ),
    ];
  } catch (_) {
    return const [];
  }
}

String sdProfileSetCommand({required String name, required String password, required bool enabled, required String mode, required Map<String, bool> perms}) =>
    jsonEncode({'op': 'set', 'name': name, 'password': password, 'enabled': enabled, 'mode': mode, 'perms': perms});

String sdProfileDeleteCommand(String name) => jsonEncode({'op': 'delete', 'name': name});

/// make this profile's permissions the computer's own
String sdProfileUseCommand(String name) => jsonEncode({'op': 'use', 'name': name});

/// unattended access of a profile on or off; a password (made or changed) may come with it, and turning it on needs the profile to have one
String sdProfileUnattendedCommand({required String name, required bool enabled, String password = ''}) =>
    jsonEncode({'op': 'unattended', 'name': name, 'enabled': enabled, 'password': password});

/// take the password of a profile away (it is switched off with it)
String sdProfileClearCommand(String name) => jsonEncode({'op': 'clear', 'name': name});

/// What the core is asked through (the app's bridge has no call of its own for it): the answer is empty, or why it did not work.
String sdProfileRun(String commandJson) => bind.mainGetOptionSync(key: '$_commandKey:$commandJson');
String sdProfilesNow() => bind.mainGetOptionSync(key: _listKey);

/// A line with a tick box: the words, and an optional grey line under them. [indent] puts it under the line above (a permission that belongs to another).
/// [onChanged] null = it cannot be changed (the box is dimmed).
class SdCheckRow extends StatelessWidget {
  const SdCheckRow({super.key, required this.label, required this.value, this.onChanged, this.indent = false, this.sub});
  final String label;
  final String? sub;
  final bool value, indent;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final live = onChanged != null;
    return MouseRegion(
      cursor: live ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: live ? () => onChanged!(!value) : null,
        child: Padding(
          padding: EdgeInsets.fromLTRB(indent ? 32 : 0, 7, 0, 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Opacity(
              opacity: live ? 1 : 0.45,
              child: Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: value ? t.goldB : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: value ? t.goldB : t.line2, width: 1.5),
                ),
                child: value ? const Center(child: SdIcon(SdIcons.check, size: 14, color: Color(0xFF241700), stroke: 2.8)) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(label, style: sdTs(14.5, FontWeight.w400, live ? t.ink : t.mut)),
                if (sub != null && sub!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 1), child: Text(sub!, style: sdTs(12.5, FontWeight.w400, t.mut))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The small question dialogs of the profiles: a name, a password, or a yes/no. They draw and report; what is done with the answer is the caller's.
class _AskForm extends StatefulWidget {
  const _AskForm({
    required this.title,
    required this.ok,
    required this.onCancel,
    required this.onOk,
    this.message,
    this.fieldLabel,
    this.obscure = false,
    this.bad = false,
  });
  final String title, ok;
  final String? message, fieldLabel;
  final bool obscure, bad;
  final VoidCallback onCancel;

  /// gets what was typed; the answer is empty or the reason it did not work (shown in the dialog, which stays)
  final String Function(String text) onOk;

  @override
  State<_AskForm> createState() => _AskFormState();
}

class _AskFormState extends State<_AskForm> {
  final _text = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _ok() {
    final why = widget.onOk(_text.text);
    if (why.isNotEmpty) setState(() => _error = why);
  }

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          SdMarkTile(child: SdIcon(SdIcons.shield, size: 26, color: const Color(0xFFF3E2B8), stroke: 1.9)),
          const SizedBox(width: 14),
          Expanded(child: Text(widget.title, style: sdTs(21, FontWeight.w600, t.ink, ls: -0.21))),
        ]),
        if (widget.message != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(widget.message!, style: sdTs(14, FontWeight.w400, t.mut))),
        if (widget.fieldLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SdField(key: const ValueKey('sd-profile-ask-field'), label: widget.fieldLabel!, controller: _text, obscure: widget.obscure, autofocus: true, onSubmitted: (_) => _ok()),
          ),
        if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error, style: sdTs(13.5, FontWeight.w500, t.bad))),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          SdButton(label: 'Cancel', onTap: widget.onCancel),
          const SizedBox(width: 10),
          SdButton(key: const ValueKey('sd-profile-ask-ok'), label: widget.ok, kind: widget.bad ? SdBtnKind.bad : SdBtnKind.gold, onTap: _ok),
        ]),
      ],
    );
  }
}

/// The profiles of Settings > Security: a list, and under it the profile that is picked: its name, its password, whether it is switched on and what it
/// allows. Everything that is changed is saved at once.
class SdProfilesCard extends StatefulWidget {
  const SdProfilesCard({super.key, required this.enabled, this.read, this.run, this.dialog});

  /// false while the page is locked (the computer's password has not been asked for yet): nothing can be changed
  final bool enabled;

  /// what the card asks the core with (the list, and one command): the computer's own, unless a test brings its own
  final String Function()? read;
  final String Function(String command)? run;

  /// where the small question dialogs are shown: the app's dialog manager, unless a test brings its own (it gets the dialog as a widget builder)
  final void Function(String tag, Widget Function(VoidCallback close) builder)? dialog;

  @override
  State<SdProfilesCard> createState() => _SdProfilesCardState();
}

class _SdProfilesCardState extends State<SdProfilesCard> {
  List<SdProfile> _profiles = const [];
  String _selected = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// read the list again; [select] names the profile to show (the one made just now), else the one that was shown, else the one chosen on the home screen
  void _reload({String? select}) {
    final list = sdParseProfiles((widget.read ?? sdProfilesNow)());
    final want = select ?? _selected;
    setState(() {
      _profiles = list;
      _selected = list.any((p) => p.name == want)
          ? want
          : (list.where((p) => p.active).map((p) => p.name).firstOrNull ?? (list.isEmpty ? '' : list.first.name));
    });
  }

  SdProfile? get _current => _profiles.where((p) => p.name == _selected).firstOrNull;

  /// send one command to the core; what it answers (empty = it worked) is shown under the buttons
  bool _run(String command, {String? select}) {
    final why = (widget.run ?? sdProfileRun)(command);
    _error = why;
    _reload(select: select);
    return why.isEmpty;
  }

  void _setPerm(SdProfile p, String key, bool on) {
    // a change by hand makes it a custom set (Full access and Screen share are only the two ends)
    _run(sdProfileSetCommand(name: p.name, password: '', enabled: p.enabled, mode: kSdProfileCustom, perms: {...p.perms, key: on}));
  }

  void _ask(String tag, {required String title, required String ok, String? message, String? fieldLabel, bool obscure = false, bool bad = false, required String Function(String) onOk}) {
    Widget build(VoidCallback close) => SdModal(
          maxWidth: 480,
          onCancel: close,
          content: _AskForm(
            title: title,
            ok: ok,
            message: message,
            fieldLabel: fieldLabel,
            obscure: obscure,
            bad: bad,
            onCancel: close,
            onOk: (text) {
              final why = onOk(text);
              if (why.isEmpty) close();
              return why;
            },
          ),
        );
    final host = widget.dialog;
    if (host != null) {
      host(tag, build);
    } else {
      gFFI.dialogManager.show((setState, close, context) => build(close), tag: tag);
    }
  }

  void _add() => _ask('sd-profile-add', title: 'Add profile', ok: 'Add', fieldLabel: 'Name of the profile', onOk: (name) {
        final n = name.trim();
        if (n.isEmpty) return 'Type a name for the profile';
        // a new profile starts with the mouse, the keyboard and the clipboard; it has no password until one is set
        final ok = (widget.run ?? sdProfileRun)(sdProfileSetCommand(
            name: n, password: '', enabled: false, mode: kSdProfileCustom, perms: {for (final p in sdProfilePerms) p.$1: p.$1 == 'keyboard' || p.$1 == 'clipboard'}));
        if (ok.isEmpty) {
          _error = '';
          _reload(select: n);
        }
        return ok;
      });

  void _password(SdProfile p) => _ask('sd-profile-password',
      title: p.hasPassword ? 'Change password' : 'Set password',
      ok: 'Save',
      message: p.name,
      fieldLabel: 'Password (6 characters or more)',
      obscure: true,
      onOk: (password) {
        if (password.isEmpty) return 'Type a password';
        // a password made for a profile that had none switches it on; changing one keeps it as it was
        final why = (widget.run ?? sdProfileRun)(sdProfileUnattendedCommand(name: p.name, enabled: p.hasPassword ? p.enabled : true, password: password));
        if (why.isEmpty) {
          _error = '';
          _reload();
        }
        return why;
      });

  void _removePassword(SdProfile p) => _ask('sd-profile-remove-password',
      title: 'Remove password',
      ok: 'Remove',
      bad: true,
      message: 'Nobody can come in with the password of "${p.name}" any more, and the profile is switched off. Its permissions stay.',
      onOk: (_) {
        final why = (widget.run ?? sdProfileRun)(sdProfileClearCommand(p.name));
        if (why.isEmpty) {
          _error = '';
          _reload();
        }
        return why;
      });

  void _delete(SdProfile p) => _ask('sd-profile-delete',
      title: 'Delete profile',
      ok: 'Delete',
      bad: true,
      message: 'Delete "${p.name}"? Its password stops working.',
      onOk: (_) {
        final why = (widget.run ?? sdProfileRun)(sdProfileDeleteCommand(p.name));
        if (why.isEmpty) {
          _error = '';
          _reload();
        }
        return why;
      });

  Widget _row(SdProfile p) {
    final t = SdSkin.of(context);
    final picked = p.name == _selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: ValueKey('sd-profile-row-${p.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          _selected = p.name;
          _error = '';
        }),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: picked ? t.goldSoft : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(child: Text(p.name, style: sdTs(15, picked ? FontWeight.w600 : FontWeight.w500, picked ? t.goldTxt : t.ink))),
            if (p.active) Padding(padding: const EdgeInsets.only(right: 10), child: Text('Home screen', style: sdTs(12.5, FontWeight.w400, t.mut))),
            if (p.hasPassword) SdIcon(SdIcons.key, size: 16, color: p.enabled ? t.goldTxt : t.mut, stroke: 1.9),
          ]),
        ),
      ),
    );
  }

  Widget _detail(SdProfile p) {
    final t = SdSkin.of(context);
    final live = widget.enabled;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(p.name, key: const ValueKey('sd-profile-title'), style: sdTs(19, FontWeight.w600, t.ink, ls: -0.19)),
        const SizedBox(height: 12),
        // a Row (not a Wrap): a button keeps its own width there; a narrow window scrolls the row sideways
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            if (!p.hasPassword)
              SdButton(key: const ValueKey('sd-profile-set-password'), small: true, kind: SdBtnKind.gold, label: 'Set password', onTap: live ? () => _password(p) : null)
            else ...[
              SdButton(key: const ValueKey('sd-profile-change-password'), small: true, kind: SdBtnKind.gold, label: 'Change password', onTap: live ? () => _password(p) : null),
              const SizedBox(width: 8),
              SdButton(key: const ValueKey('sd-profile-remove-password'), small: true, label: 'Remove password', onTap: live ? () => _removePassword(p) : null),
            ],
            // the standard profiles stay; only the ones made by hand can be deleted
            if (!p.builtin) ...[
              const SizedBox(width: 8),
              SdButton(key: const ValueKey('sd-profile-delete'), small: true, label: 'Delete profile', onTap: live ? () => _delete(p) : null),
            ],
          ]),
        ),
        if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error, key: const ValueKey('sd-profile-error'), style: sdTs(13.5, FontWeight.w500, t.bad))),
        const SizedBox(height: 10),
        SdCheckRow(
          key: const ValueKey('sd-profile-enabled'),
          label: 'Enable permission profile',
          sub: p.hasPassword ? 'Someone who connects with this profile\'s password gets in without anyone accepting.' : 'Set a password first: without one nobody can come in with this profile.',
          value: p.enabled && p.hasPassword,
          onChanged: live && p.hasPassword ? (v) => _run(sdProfileUnattendedCommand(name: p.name, enabled: v)) : null,
        ),
        const SizedBox(height: 8),
        Text('When other people connect to me with this profile, they can:', style: sdTs(13.5, FontWeight.w400, t.mut)),
        const SizedBox(height: 4),
        for (final e in sdProfileLayout)
          SdCheckRow(
            key: ValueKey('sd-profile-perm-${e.$1}'),
            label: e.$2,
            indent: e.$3 != null,
            value: p.perms[e.$1] == true,
            // a permission that belongs under another one is offered while that one is on
            onChanged: live && (e.$3 == null || p.perms[e.$3] == true) ? (v) => _setPerm(p, e.$1, v) : null,
          ),
        const SizedBox(height: 12),
        if (p.active)
          Text(
            'Chosen on the home screen: people who connect with a one-time password, or whose request you accept, get these permissions.',
            key: const ValueKey('sd-profile-active-note'),
            style: sdTs(12.5, FontWeight.w400, t.mut),
          )
        else
          Row(children: [
            SdButton(key: const ValueKey('sd-profile-use'), small: true, label: 'Use for everyone else', onTap: live ? () => _run(sdProfileUseCommand(p.name)) : null),
            const SizedBox(width: 12),
            Expanded(child: Text('One-time passwords and requests you accept.', style: sdTs(12.5, FontWeight.w400, t.mut))),
          ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return SdSettingsCard(
      title: 'Permission profiles',
      titleSuffix: [SdButton(key: const ValueKey('sd-profile-add'), small: true, label: 'Add profile', onTap: widget.enabled ? _add : null)],
      rows: [
        const SdSettingRow(
          label: 'Each profile has its own password and its own permissions',
          sub: 'Pick a profile to see what it allows. Someone who connects with its password gets exactly that.',
        ),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final p in _profiles) _row(p)])),
        if (current != null) _detail(current),
      ],
    );
  }
}
