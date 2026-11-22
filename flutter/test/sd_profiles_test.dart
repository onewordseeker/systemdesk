import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_profiles.dart';
import 'package:flutter_hbb/screens/sd_settings.dart';
import 'package:flutter_test/flutter_test.dart';

bool sdToggleEnabled(WidgetTester tester, String key) => tester.widget<SdToggleRow>(find.byKey(ValueKey(key))).onChanged != null;

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
    final set = sdProfileSetCommand(name: 'A', password: 'secret-1', enabled: true, mode: 'custom', perms: {'keyboard': true});
    expect(set, contains('"op":"set"'));
    expect(set, contains('"password":"secret-1"'));
    expect(set, contains('"mode":"custom"'));
    expect(set, contains('"keyboard":true'));
  });

  group('the form', () {
    Future<void> show(WidgetTester tester,
        {SdProfile? existing, required String Function(String, String, bool, String, Map<String, bool>) onSave, VoidCallback? onCancel}) async {
      SdLook.debugEnabled = true;
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 520, child: SdProfileForm(existing: existing, onSave: onSave, onCancel: onCancel ?? () {})))),
      ));
    }

    testWidgets('a new profile starts as Custom with mouse and keyboard and clipboard, and reports what was typed', (tester) async {
      String? name, password, mode;
      Map<String, bool>? perms;
      await show(tester, onSave: (n, p, e, md, m) {
        name = n;
        password = p;
        mode = md;
        perms = m;
        return '';
      });
      expect(find.text('New profile'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).at(0), 'Support');
      await tester.enterText(find.byType(EditableText).at(1), 'secret-1');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect((name, password, mode), ('Support', 'secret-1', 'custom'));
      expect(perms!['keyboard'], true);
      expect(perms!['clipboard'], true);
      expect(perms!['file'], false);
    });

    testWidgets('Full access turns every switch on and Screen share every switch off; Custom brings back what was set', (tester) async {
      String? mode;
      Map<String, bool>? perms;
      await show(tester, onSave: (n, p, e, md, m) {
        mode = md;
        perms = m;
        return '';
      });
      await tester.tap(find.byKey(const ValueKey('sd-profile-mode-full')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(mode, 'full');
      expect(perms!['file'] == true && perms!['restart'] == true && perms!['privacy_mode'] == true, true);

      await tester.tap(find.byKey(const ValueKey('sd-profile-mode-view')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(mode, 'view');
      expect(perms!['keyboard'], false);
      expect(perms!['audio'], false);
    });

    testWidgets('in Full access the switches cannot be changed (except the lock)', (tester) async {
      await show(tester, onSave: (n, p, e, md, m) => '');
      await tester.tap(find.byKey(const ValueKey('sd-profile-mode-full')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(sdToggleEnabled(tester, 'sd-profile-perm-file'), false);
      expect(sdToggleEnabled(tester, 'sd-profile-perm-lock_on_end'), true);
      await tester.tap(find.byKey(const ValueKey('sd-profile-mode-custom')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(sdToggleEnabled(tester, 'sd-profile-perm-file'), true);
    });

    testWidgets('a password typed for a profile that was off switches unattended access on, unless the person set it themselves', (tester) async {
      bool? enabled;
      final off = sdParseProfiles('[{"name":"Default","builtin":true,"enabled":false,"has_password":false,"perms":{}}]').single;
      await show(tester, existing: off, onSave: (n, p, e, md, m) {
        enabled = e;
        return '';
      });
      await tester.enterText(find.byType(EditableText).at(0), 'office-pass');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(enabled, true);

      // switched off by hand with a new password typed: it stays off (a fresh form: the first one is taken down, or its state would be reused)
      await tester.pumpWidget(const SizedBox());
      final on = sdParseProfiles('[{"name":"Default","builtin":true,"enabled":true,"has_password":true,"perms":{}}]').single;
      await show(tester, existing: on, onSave: (n, p, e, md, m) {
        enabled = e;
        return '';
      });
      await tester.enterText(find.byType(EditableText).at(0), 'office-pass');
      await tester.tap(find.byType(SdOnOff).last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(enabled, false);
    });

    testWidgets('the reason the core gives is shown and the form stays', (tester) async {
      await show(tester, onSave: (n, p, e, md, m) => 'the password must have 6 to 64 characters');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('the password must have 6 to 64 characters'), findsOneWidget);
    });

    testWidgets('an existing profile shows its name and mode, and an empty password means keep', (tester) async {
      String? password, mode;
      final existing = sdParseProfiles('[{"name":"Viewer","enabled":true,"has_password":true,"mode":"view","perms":{}}]').single;
      await show(tester, existing: existing, onSave: (n, p, e, md, m) {
        password = p;
        mode = md;
        return '';
      });
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Viewer'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect((password, mode), ('', 'view'));
    });

    testWidgets('Cancel does not save', (tester) async {
      var cancelled = 0;
      await show(tester, onSave: (n, p, e, md, m) => fail('not saved'), onCancel: () => cancelled++);
      await tester.tap(find.text('Cancel'));
      expect(cancelled, 1);
    });
  });
}
