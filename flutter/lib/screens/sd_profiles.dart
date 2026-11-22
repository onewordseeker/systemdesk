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

/// Permission profiles: each has its own name, its own password and its own permissions, set the way the general Permissions are set: Custom (each
/// switch by hand), Full access or Screen share. Whoever connects with a profile's password gets that profile's permissions. The profiles are kept by
/// the computer's core (`sd_profiles.rs`); passwords go to it and never come back.

const _listKey = 'sd-profiles';
const _commandKey = 'sd-profile-command';

const kSdProfileCustom = 'custom';
const kSdProfileFull = 'full';
const kSdProfileView = 'view';

/// the permissions of a profile, in the order they are shown: (key the core knows, words)
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

/// What the core is asked through (the app's bridge has no call of its own for it): the answer is empty, or why it did not work.
String sdProfileRun(String commandJson) => bind.mainGetOptionSync(key: '$_commandKey:$commandJson');
String sdProfilesNow() => bind.mainGetOptionSync(key: _listKey);

/// The form of one profile: its name, password, mode and switches. It draws and reports; saving is the caller's.
class SdProfileForm extends StatefulWidget {
  const SdProfileForm({super.key, this.existing, required this.onSave, required this.onCancel});

  /// null = a new profile
  final SdProfile? existing;

  /// the answer is empty or the reason it could not be saved (shown in the form)
  final String Function(String name, String password, bool enabled, String mode, Map<String, bool> perms) onSave;
  final VoidCallback onCancel;

  @override
  State<SdProfileForm> createState() => _SdProfileFormState();
}

class _SdProfileFormState extends State<SdProfileForm> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  final _password = TextEditingController();
  late bool _enabled = widget.existing?.enabled ?? true;

  // the person did not touch "unattended access" themselves: a password typed for a profile that was off switches it on
  bool _enabledTouched = false;
  late String _mode = widget.existing?.mode ?? kSdProfileCustom;
  late Map<String, bool> _perms = {
    for (final p in sdProfilePerms) p.$1: widget.existing?.perms[p.$1] ?? (p.$1 == 'keyboard' || p.$1 == 'clipboard'),
  };
  String _error = '';

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  void _setMode(String mode) => setState(() {
        // the switches follow the mode (Full access: all on; Screen share: all off); coming back to Custom keeps what they were
        _mode = mode;
        _perms = sdProfilePermsFor(mode, _perms);
      });

  void _save() {
    final enabled = _enabled || (!_enabledTouched && _password.text.isNotEmpty);
    final why = widget.onSave(_name.text, _password.text, enabled, _mode, sdProfilePermsFor(_mode, _perms));
    if (why.isNotEmpty) setState(() => _error = why);
  }

  Widget _modeButton(String mode, String label) => SdButton(
        key: ValueKey('sd-profile-mode-$mode'),
        small: true,
        label: label,
        kind: _mode == mode ? SdBtnKind.gold : SdBtnKind.plain,
        onTap: () => _setMode(mode),
      );

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final editing = widget.existing != null;
    final custom = _mode == kSdProfileCustom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          SdMarkTile(child: SdIcon(SdIcons.shield, size: 26, color: const Color(0xFFF3E2B8), stroke: 1.9)),
          const SizedBox(width: 14),
          Expanded(child: Text(editing ? 'Edit profile' : 'New profile', style: sdTs(21, FontWeight.w600, t.ink, ls: -0.21))),
        ]),
        const SizedBox(height: 16),
        // the name of an existing profile is its identity: it is shown, not edited
        if (editing)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(widget.existing!.name, style: sdTs(16, FontWeight.w600, t.ink)))
        else
          SdField(label: 'Name', controller: _name, autofocus: true),
        const SizedBox(height: 12),
        SdField(label: editing ? 'New password (leave empty to keep the old one)' : 'Password (6 characters or more)', controller: _password, obscure: true),
        const SizedBox(height: 16),
        Text('What this password allows', style: sdTs(13.5, FontWeight.w400, t.mut)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _modeButton(kSdProfileCustom, 'Custom'),
          _modeButton(kSdProfileFull, 'Full access'),
          _modeButton(kSdProfileView, 'Screen share'),
        ]),
        const SizedBox(height: 6),
        Flexible(
          child: SingleChildScrollView(
            child: Column(children: [
              // in Full access and Screen share the switches show what the mode gives and cannot be changed (except the lock)
              for (final p in sdProfilePerms)
                SdToggleRow(
                  key: ValueKey('sd-profile-perm-${p.$1}'),
                  label: p.$2,
                  value: _perms[p.$1] == true,
                  onChanged: custom || p.$1 == _lockKey ? (v) => setState(() => _perms[p.$1] = v) : null,
                ),
              SdToggleRow(
                key: const ValueKey('sd-profile-enabled'),
                label: 'Unattended access with this password',
                value: _enabled,
                onChanged: (v) => setState(() {
                  _enabledTouched = true;
                  _enabled = v;
                }),
              ),
            ]),
          ),
        ),
        if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error, style: sdTs(13.5, FontWeight.w500, t.bad))),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          SdButton(label: 'Cancel', onTap: widget.onCancel),
          const SizedBox(width: 10),
          SdButton(label: 'Save', kind: SdBtnKind.gold, onTap: _save),
        ]),
      ],
    );
  }
}

/// The card at the top of Settings > Security: the profiles, each with Edit and Delete, and a button to add one.
class SdProfilesCard extends StatefulWidget {
  const SdProfilesCard({super.key, required this.enabled});
  final bool enabled;

  @override
  State<SdProfilesCard> createState() => _SdProfilesCardState();
}

class _SdProfilesCardState extends State<SdProfilesCard> {
  List<SdProfile> _profiles = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _profiles = sdParseProfiles(sdProfilesNow()));

  void _openForm(OverlayDialogManager dm, SdProfile? existing) {
    dm.show((setState, close, context) {
      return SdModal(
        maxWidth: 520,
        onCancel: close,
        content: SdProfileForm(
          existing: existing,
          onCancel: close,
          onSave: (name, password, enabled, mode, perms) {
            final why = sdProfileRun(sdProfileSetCommand(name: existing?.name ?? name, password: password, enabled: enabled, mode: mode, perms: perms));
            if (why.isEmpty) {
              close();
              _reload();
            }
            return why;
          },
        ),
      );
    }, tag: 'sd-profile-form');
  }

  @override
  Widget build(BuildContext context) {
    final dm = gFFI.dialogManager;
    return SdSettingsCard(title: 'Permission profiles', rows: [
      SdSettingRow(
        label: 'Each profile has its own password and its own permissions',
        sub: 'Someone who connects with a profile\'s password gets exactly what that profile allows. A profile works whatever the password mode below is. The profile chosen on the home screen (Default at first) gives the computer\'s own permissions to everyone else: a one-time password, an accepted request, and the computer\'s own password.',
      ),
      for (final p in _profiles)
        SdSettingRow(
          label: p.name,
          sub: p.status,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            SdButton(small: true, label: p.builtin ? 'Permissions and password' : 'Edit', onTap: widget.enabled ? () => _openForm(dm, p) : null),
            // the standard profiles stay; only the ones made by hand can be deleted
            if (!p.builtin) ...[
              const SizedBox(width: 8),
              SdButton(
                small: true,
                label: 'Delete',
                onTap: widget.enabled
                    ? () {
                        sdProfileRun(sdProfileDeleteCommand(p.name));
                        _reload();
                      }
                    : null,
              ),
            ],
          ]),
        ),
      SdActionRow(label: 'Add a custom profile', onTap: widget.enabled ? () => _openForm(dm, null) : null),
    ]);
  }
}
