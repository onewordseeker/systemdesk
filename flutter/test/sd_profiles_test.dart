import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_profiles.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the computer's core does with the profile commands, as far as the screen can tell (the real one is `sd_profiles.rs`, tested there).
class FakeCore {
  FakeCore() {
    profiles = [
      {'name': 'Default', 'enabled': false, 'has_password': false, 'builtin': true, 'active': true, 'mode': 'custom', 'perms': {'keyboard': true, 'clipboard': true, 'file': true, 'audio': true, 'system_info': true}},
      {'name': 'Screen Sharing', 'enabled': false, 'has_password': false, 'builtin': true, 'active': false, 'mode': 'view', 'perms': {}},
      {'name': 'Full Access', 'enabled': true, 'has_password': true, 'builtin': true, 'active': false, 'mode': 'full', 'perms': {for (final p in sdProfilePerms) p.$1: p.$1 != 'lock_on_end'}},
      {'name': 'Unattended Access', 'enabled': false, 'has_password': false, 'builtin': true, 'active': false, 'mode': 'custom', 'perms': {'keyboard': true, 'lock_on_end': true}},
    ];
  }

  late List<Map<String, dynamic>> profiles;
  final commands = <Map<String, dynamic>>[];

  String read() => jsonEncode(profiles);

  Map<String, dynamic>? _find(String name) => profiles.where((p) => '${p['name']}'.toLowerCase() == name.trim().toLowerCase()).firstOrNull;

  String run(String json) {
    final c = jsonDecode(json) as Map<String, dynamic>;
    commands.add(c);
    final p = _find('${c['name']}');
    switch (c['op']) {
      case 'set':
        if (p == null) {
          profiles.add({'name': '${c['name']}'.trim(), 'enabled': false, 'has_password': false, 'builtin': false, 'active': false, 'mode': c['mode'], 'perms': c['perms']});
        } else {
          p['perms'] = c['perms'];
          p['mode'] = c['mode'];
          p['enabled'] = c['enabled'];
        }
        return '';
      case 'unattended':
        if (p == null) return 'no such profile';
        final password = '${c['password']}';
        if (password.isNotEmpty && password.length < 6) return 'the password must have 6 to 64 characters';
        if (c['enabled'] == true && password.isEmpty && p['has_password'] != true) return 'create a password for this profile first';
        if (password.isNotEmpty) p['has_password'] = true;
        p['enabled'] = c['enabled'];
        return '';
      case 'clear':
        if (p == null) return 'no such profile';
        p['has_password'] = false;
        p['enabled'] = false;
        return '';
      case 'delete':
        if (p == null) return 'no such profile';
        profiles.remove(p);
        return '';
      case 'use':
        for (final q in profiles) {
          q['active'] = identical(q, p);
        }
        return '';
    }
    return 'unreadable command';
  }
}

void main() {
  tearDown(() => SdLook.debugEnabled = null);

  group('the list the core sends', () {
    test('rows come with their permissions; a row without a name, or text that is no list, is left out', () {
      final list = sdParseProfiles(
          '[{"name":"Support","enabled":true,"has_password":true,"perms":{"keyboard":true,"audio":true}},{"name":"","perms":{}},{"name":"Viewer","enabled":false,"has_password":true}]');
      expect(list.map((p) => p.name), ['Support', 'Viewer']);
      expect(list[0].perms['keyboard'], true);
      expect(list[0].perms['file'], false, reason: 'what is not there is off');
      expect(list[0].mode, 'custom', reason: 'an older profile has no mode: custom');
      expect(list[1].enabled, false);
      expect(sdParseProfiles('nope'), isEmpty);
      expect(sdParseProfiles('{"a":1}'), isEmpty);
      expect(sdParseProfiles(''), isEmpty);
    });

    test('the words under the name say what is allowed', () {
      final list = sdParseProfiles(
          '[{"name":"A","perms":{"keyboard":true,"audio":true}},{"name":"B","perms":{}},{"name":"C","mode":"full"},{"name":"D","mode":"view"}]');
      expect(list[0].summary, 'Mouse and keyboard · Sound of this computer');
      expect(list[1].summary, 'Can only watch the screen');
      expect(list[2].summary, 'Full access');
      expect(list[3].summary, 'Screen share only');
    });
  });

  test('the line under a name says whether a password lets anyone in, and what it allows', () {
    final list = sdParseProfiles(
        '[{"name":"Default","builtin":true,"enabled":false,"has_password":false,"perms":{"audio":true}},'
        '{"name":"Full Access","builtin":true,"enabled":true,"has_password":true,"mode":"full"},'
        '{"name":"Full Access 2","builtin":false,"enabled":false,"has_password":true,"mode":"view"}]');
    expect(list.map((p) => p.builtin), [true, true, false]);
    expect(list[0].status, 'No password yet · Sound of this computer');
    expect(list[1].status, 'Unattended access on · Full access');
    expect(list[2].status, 'Unattended access off · Screen share only');
  });

  test('Full access and Screen share decide every switch but the lock', () {
    final custom = {for (final p in sdProfilePerms) p.$1: false}..['audio'] = true..['lock_on_end'] = true;
    final full = sdProfilePermsFor('full', custom);
    expect(full.entries.where((e) => e.key != 'lock_on_end').every((e) => e.value), true);
    expect(full['lock_on_end'], true, reason: 'the lock is the owner\'s rule, not part of the mode');
    final view = sdProfilePermsFor('view', custom);
    expect(view.entries.where((e) => e.key != 'lock_on_end').every((e) => !e.value), true);
    expect(view['lock_on_end'], true);
    expect(sdProfilePermsFor('custom', custom), custom);
  });

  test('the list says which profile is chosen for the computer and whether its permissions were changed since', () {
    final list = sdParseProfiles(
        '[{"name":"Default","active":false,"modified":false},{"name":"Full Access","builtin":true,"active":true,"modified":true,"mode":"full"}]');
    expect((list[0].active, list[0].modified), (false, false));
    expect((list[1].active, list[1].modified), (true, true));
    expect(list[1].status, startsWith('Chosen on the home screen · '));
    expect(list[0].status, isNot(contains('Chosen')));
  });

  test('the commands the core reads', () {
    expect(sdProfileUseCommand('Full Access'), '{"op":"use","name":"Full Access"}');
    expect(sdProfileDeleteCommand('A'), '{"op":"delete","name":"A"}');
    expect(sdProfileClearCommand('A'), '{"op":"clear","name":"A"}');
    final set = sdProfileSetCommand(name: 'A', password: 'secret-1', enabled: true, mode: 'custom', perms: {'keyboard': true});
    expect(set, contains('"op":"set"'));
    expect(set, contains('"password":"secret-1"'));
    expect(set, contains('"mode":"custom"'));
    expect(set, contains('"keyboard":true'));
  });

  test('every permission a profile carries is listed once in Settings, and one under another belongs to a permission that is listed', () {
    final listed = sdProfileLayout.map((e) => e.$1).toList();
    expect(listed.toSet(), sdProfilePerms.map((e) => e.$1).toSet());
    expect(listed.length, listed.toSet().length);
    for (final e in sdProfileLayout.where((e) => e.$3 != null)) {
      expect(listed.contains(e.$3), true);
    }
  });

  group('the profiles in Settings', () {
    Future<void> show(WidgetTester tester, FakeCore core, {bool enabled = true}) async {
      SdLook.debugEnabled = true;
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      Widget? dialog;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(builder: (context, setHost) {
            return Stack(children: [
              SingleChildScrollView(
                child: SizedBox(
                  width: 760,
                  child: SdProfilesCard(
                    enabled: enabled,
                    read: core.read,
                    run: core.run,
                    dialog: (tag, build) => setHost(() => dialog = build(() => setHost(() => dialog = null))),
                  ),
                ),
              ),
              if (dialog != null) Positioned.fill(child: dialog!),
            ]);
          }),
        ),
      ));
    }

    Future<void> tapKey(WidgetTester tester, String key) async {
      final target = find.byKey(ValueKey(key));
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> typeInDialog(WidgetTester tester, String text) async {
      await tester.enterText(find.descendant(of: find.byKey(const ValueKey('sd-profile-ask-field')), matching: find.byType(EditableText)), text);
      await tester.pump();
    }

    bool checked(WidgetTester tester, String key) => tester.widget<SdCheckRow>(find.byKey(ValueKey(key))).value;
    bool changeable(WidgetTester tester, String key) => tester.widget<SdCheckRow>(find.byKey(ValueKey(key))).onChanged != null;

    testWidgets('the profiles are a list; the one chosen on the home screen is shown with what it allows', (tester) async {
      await show(tester, FakeCore());
      for (final n in ['Default', 'Screen Sharing', 'Full Access', 'Unattended Access']) {
        expect(find.byKey(ValueKey('sd-profile-row-$n')), findsOneWidget);
      }
      expect(tester.widget<Text>(find.byKey(const ValueKey('sd-profile-title'))).data, 'Default');
      expect(find.text('Home screen'), findsOneWidget, reason: 'the list marks the profile chosen on the home screen');
      expect(find.byKey(const ValueKey('sd-profile-active-note')), findsOneWidget);
      expect(find.byKey(const ValueKey('sd-profile-use')), findsNothing);
      // no password yet: Set password, nothing to remove, the standard profiles cannot be deleted
      expect(find.byKey(const ValueKey('sd-profile-set-password')), findsOneWidget);
      expect(find.byKey(const ValueKey('sd-profile-change-password')), findsNothing);
      expect(find.byKey(const ValueKey('sd-profile-delete')), findsNothing);
      expect(checked(tester, 'sd-profile-perm-keyboard'), true);
      expect(checked(tester, 'sd-profile-perm-file'), true);
      expect(checked(tester, 'sd-profile-perm-recording'), false);
      expect(tester.takeException(), isNull);
    });

    testWidgets('picking another profile shows its own password buttons and permissions', (tester) async {
      await show(tester, FakeCore());
      await tapKey(tester, 'sd-profile-row-Full Access');
      expect(tester.widget<Text>(find.byKey(const ValueKey('sd-profile-title'))).data, 'Full Access');
      expect(find.byKey(const ValueKey('sd-profile-change-password')), findsOneWidget);
      expect(find.byKey(const ValueKey('sd-profile-remove-password')), findsOneWidget);
      expect(find.byKey(const ValueKey('sd-profile-set-password')), findsNothing);
      expect(checked(tester, 'sd-profile-enabled'), true);
      for (final e in sdProfileLayout.where((e) => e.$1 != 'lock_on_end')) {
        expect(checked(tester, 'sd-profile-perm-${e.$1}'), true, reason: e.$1);
      }
      expect(checked(tester, 'sd-profile-perm-lock_on_end'), false);
      // it is not the one chosen on the home screen: it can be made that
      expect(find.byKey(const ValueKey('sd-profile-use')), findsOneWidget);
      expect(find.byKey(const ValueKey('sd-profile-active-note')), findsNothing);

      await tapKey(tester, 'sd-profile-row-Screen Sharing');
      for (final e in sdProfileLayout) {
        expect(checked(tester, 'sd-profile-perm-${e.$1}'), false, reason: e.$1);
      }
    });

    testWidgets('ticking a permission is saved at once, as a custom set, without touching the password', (tester) async {
      final core = FakeCore();
      await show(tester, core);
      await tapKey(tester, 'sd-profile-perm-recording');
      final c = core.commands.last;
      expect((c['op'], c['name'], c['mode'], c['password'], c['enabled']), ('set', 'Default', 'custom', '', false));
      expect((c['perms'] as Map)['recording'], true);
      expect((c['perms'] as Map)['keyboard'], true, reason: 'the others stay as they were');
      expect(checked(tester, 'sd-profile-perm-recording'), true);

      await tapKey(tester, 'sd-profile-perm-file');
      expect(checked(tester, 'sd-profile-perm-file'), false);
      expect(((core.commands.last['perms']) as Map)['file'], false);
    });

    testWidgets('a permission that belongs under Control is offered only while Control is on', (tester) async {
      final core = FakeCore();
      await show(tester, core);
      expect(changeable(tester, 'sd-profile-perm-restart'), true);
      await tapKey(tester, 'sd-profile-perm-keyboard');
      expect(checked(tester, 'sd-profile-perm-keyboard'), false);
      for (final k in ['restart', 'privacy_mode', 'block_input']) {
        expect(changeable(tester, 'sd-profile-perm-$k'), false, reason: k);
      }
      expect(changeable(tester, 'sd-profile-perm-file'), true);
    });

    testWidgets('a profile without a password cannot be switched on; with one it can', (tester) async {
      final core = FakeCore();
      await show(tester, core);
      expect(changeable(tester, 'sd-profile-enabled'), false);
      expect(checked(tester, 'sd-profile-enabled'), false);

      await tapKey(tester, 'sd-profile-row-Full Access');
      expect(changeable(tester, 'sd-profile-enabled'), true);
      await tapKey(tester, 'sd-profile-enabled');
      expect(core.commands.last['op'], 'unattended');
      expect(core.commands.last['enabled'], false);
      expect(checked(tester, 'sd-profile-enabled'), false);
    });

    testWidgets('Set password: a short one is refused with the core\'s reason and the dialog stays; a good one switches the profile on and closes it', (tester) async {
      final core = FakeCore();
      await show(tester, core);
      await tapKey(tester, 'sd-profile-set-password');
      expect(find.byKey(const ValueKey('sd-profile-ask-field')), findsOneWidget);
      await typeInDialog(tester, 'abc');
      await tapKey(tester, 'sd-profile-ask-ok');
      expect(find.text('the password must have 6 to 64 characters'), findsOneWidget);
      expect(find.byKey(const ValueKey('sd-profile-ask-field')), findsOneWidget);

      await typeInDialog(tester, 'office-pass');
      await tapKey(tester, 'sd-profile-ask-ok');
      expect(find.byKey(const ValueKey('sd-profile-ask-field')), findsNothing);
      final c = core.commands.last;
      expect((c['op'], c['name'], c['password'], c['enabled']), ('unattended', 'Default', 'office-pass', true));
      expect(find.byKey(const ValueKey('sd-profile-change-password')), findsOneWidget);
      expect(find.byKey(const ValueKey('sd-profile-set-password')), findsNothing);
      expect(checked(tester, 'sd-profile-enabled'), true);
    });

    testWidgets('changing a password keeps the profile as switched on or off as it was', (tester) async {
      final core = FakeCore();
      await show(tester, core);
      await tapKey(tester, 'sd-profile-row-Full Access');
      await tapKey(tester, 'sd-profile-enabled'); // off
      await tapKey(tester, 'sd-profile-change-password');
      await typeInDialog(tester, 'another-pass');
      await tapKey(tester, 'sd-profile-ask-ok');
      expect(core.commands.last['enabled'], false);
      expect(core.commands.last['password'], 'another-pass');
    });

    testWidgets('Remove password asks first, then takes the password away and switches the profile off', (tester) async {
      final core = FakeCore();
      await show(tester, core);
      await tapKey(tester, 'sd-profile-row-Full Access');
      await tapKey(tester, 'sd-profile-remove-password');
      expect(find.textContaining('Nobody can come in with the password of "Full Access"'), findsOneWidget);
      expect(core.commands, isEmpty, reason: 'nothing happens before it is confirmed');
      await tapKey(tester, 'sd-profile-ask-ok');
      expect(core.commands.last['op'], 'clear');
      expect(find.byKey(const ValueKey('sd-profile-set-password')), findsOneWidget);
      expect(checked(tester, 'sd-profile-enabled'), false);
      expect(checked(tester, 'sd-profile-perm-file'), true, reason: 'the permissions stay');
    });

    testWidgets('Add profile asks for a name, makes the profile without a password, shows it, and a profile made by hand can be deleted', (tester) async {
      final core = FakeCore();
      await show(tester, core);
      await tapKey(tester, 'sd-profile-add');
      await tapKey(tester, 'sd-profile-ask-ok');
      expect(find.text('Type a name for the profile'), findsOneWidget);
      await typeInDialog(tester, 'Helpdesk');
      await tapKey(tester, 'sd-profile-ask-ok');
      expect(find.byKey(const ValueKey('sd-profile-ask-field')), findsNothing);
      final c = core.commands.last;
      expect((c['op'], c['name'], c['password'], c['enabled']), ('set', 'Helpdesk', '', false));
      expect(tester.widget<Text>(find.byKey(const ValueKey('sd-profile-title'))).data, 'Helpdesk');
      expect(checked(tester, 'sd-profile-perm-keyboard'), true);
      expect(checked(tester, 'sd-profile-perm-clipboard'), true);
      expect(checked(tester, 'sd-profile-perm-file'), false);
      expect(find.byKey(const ValueKey('sd-profile-set-password')), findsOneWidget);

      await tapKey(tester, 'sd-profile-delete');
      expect(find.textContaining('Delete "Helpdesk"?'), findsOneWidget);
      await tapKey(tester, 'sd-profile-ask-ok');
      expect(core.commands.last['op'], 'delete');
      expect(find.byKey(const ValueKey('sd-profile-row-Helpdesk')), findsNothing);
      expect(tester.widget<Text>(find.byKey(const ValueKey('sd-profile-title'))).data, 'Default', reason: 'the profile chosen on the home screen is shown again');
    });

    testWidgets('Use for everyone else makes the profile the one chosen on the home screen', (tester) async {
      final core = FakeCore();
      await show(tester, core);
      await tapKey(tester, 'sd-profile-row-Unattended Access');
      await tapKey(tester, 'sd-profile-use');
      expect(core.commands.last['op'], 'use');
      expect(core.commands.last['name'], 'Unattended Access');
      expect(find.byKey(const ValueKey('sd-profile-active-note')), findsOneWidget);
      expect(find.byKey(const ValueKey('sd-profile-use')), findsNothing);
      expect(find.text('Home screen'), findsOneWidget);
    });

    testWidgets('while the page is locked nothing can be changed', (tester) async {
      final core = FakeCore();
      await show(tester, core, enabled: false);
      expect(tester.widget<SdButton>(find.byKey(const ValueKey('sd-profile-add'))).onTap, isNull);
      expect(tester.widget<SdButton>(find.byKey(const ValueKey('sd-profile-set-password'))).onTap, isNull);
      for (final e in sdProfileLayout) {
        expect(changeable(tester, 'sd-profile-perm-${e.$1}'), false, reason: e.$1);
      }
      // looking at another profile is still possible
      await tapKey(tester, 'sd-profile-row-Full Access');
      expect(tester.widget<Text>(find.byKey(const ValueKey('sd-profile-title'))).data, 'Full Access');
      expect(core.commands, isEmpty);
    });
  });
}
