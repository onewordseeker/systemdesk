import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/models/server_model.dart' show Client;
import 'package:flutter_hbb/screens/sd_dashboard.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_tone.dart' show SdBackdrop;
import 'package:flutter_hbb/screens/sd_unattended_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

// The "Permissions" choice of the home screen's left panel: the permission profiles, Default first and chosen at the start.
Widget _panel({List<SdPermChoice> choices = const [], ValueChanged<String>? onChoice, ValueChanged<String>? onAccess}) => SdAsideView(
      id: '4 459 591',
      password: 'i2yj9m',
      unattended: false,
      access: 'custom',
      onAccess: onAccess,
      permChoices: choices,
      onPermChoice: onChoice,
      service: SdServiceStatus.ready,
    );

Future<void> _show(WidgetTester tester, Widget panel) async {
  tester.view.physicalSize = const Size(900, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SdLook.debugEnabled = true;
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: kSdAsideWidth, child: panel)))));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _font(String family, List<String> files, String dir) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(File('$dir$f').readAsBytesSync()).buffer)));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // the real letters: with the test font the dialog's lines are wider than any real one and the rows overflow
  setUpAll(() => _font('Inter', ['Inter-Regular.ttf', 'Inter-Medium.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf'], 'assets/fonts/'));
  tearDown(() => SdLook.debugEnabled = null);

  final profiles = [
    const SdPermChoice('Default', selected: true),
    const SdPermChoice('Screen Sharing'),
    const SdPermChoice('Full Access'),
    const SdPermChoice('Unattended Access'),
    const SdPermChoice('Support'),
  ];

  testWidgets('the choice starts on Default, and the three general modes are not offered', (tester) async {
    await _show(tester, _panel(choices: profiles));
    expect(find.text('Permissions'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Custom'), findsNothing);
    await tester.tap(find.text('Default'));
    await tester.pump(const Duration(milliseconds: 300));
    for (final name in ['Screen Sharing', 'Full Access', 'Support']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    // the panel has a switch of that name too: the profile makes the second
    expect(find.text('Unattended Access'), findsNWidgets(2));
    expect(find.text('View Only'), findsNothing);
  });

  testWidgets('picking a profile reports its name and not a general mode', (tester) async {
    String? picked, mode;
    await _show(tester, _panel(choices: profiles, onChoice: (n) => picked = n, onAccess: (m) => mode = m));
    await tester.tap(find.text('Default'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Full Access'));
    await tester.pump(const Duration(milliseconds: 300));
    expect((picked, mode), ('Full Access', null));
  });

  testWidgets('permissions changed by hand since the profile was chosen are said: "Default (changed)"', (tester) async {
    await _show(tester, _panel(choices: const [SdPermChoice('Default', selected: true, modified: true), SdPermChoice('Full Access')]));
    expect(find.text('Default (changed)'), findsOneWidget);
  });

  testWidgets('the unattended password is asked for a permission profile, with its own words and nobody signed in', (tester) async {
    SdLook.debugEnabled = true;
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    String? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SdBackdrop(
          child: SdUnattendedPasswordDialog(
            profile: const SdProfile(name: 'Full Access', initials: 'FU'),
            belongs: 'Permission profile · Full access',
            footer: 'It is kept on this computer only. Whoever has this password gets what this profile allows: Full Access.',
            onSubmit: (p) async {
              saved = p;
              return null;
            },
            onCancel: () {},
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Full Access'), findsOneWidget);
    expect(find.text('Permission profile · Full access'), findsOneWidget);
    expect(find.textContaining('gets what this profile allows'), findsOneWidget);
    expect(find.text('This password belongs to your profile'), findsNothing);
    expect(find.textContaining('signs in here'), findsNothing);
    // the rules of the password are the same as ever
    await tester.enterText(find.byType(EditableText).at(0), 'Office-pass-1');
    await tester.enterText(find.byType(EditableText).at(1), 'Office-pass-1');
    await tester.pump();
    await tester.tap(find.text('Turn on unattended access'));
    await tester.pump();
    expect(saved, 'Office-pass-1');
  });

  testWidgets('the dialog keeps its old words for the account profile when it is given none of its own', (tester) async {
    SdLook.debugEnabled = true;
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: SdBackdrop(child: SdUnattendedPasswordDialog(profile: const SdProfile(name: 'Hamid Raza', initials: 'HR'), onSubmit: (p) async => null, onCancel: () {}))),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('This password belongs to your profile'), findsOneWidget);
  });

  test('the connection window is told which permission profile a connection has', () {
    Map<String, dynamic> json({String? profile}) => {
          'id': 7,
          'authorized': true,
          'is_file_transfer': false,
          'is_view_camera': false,
          'port_forward': '',
          'name': 'Info',
          'peer_id': 'SaqibKhanBaloch',
          'keyboard': true,
          'clipboard': true,
          'audio': true,
          'file': true,
          'restart': false,
          'recording': false,
          'block_input': false,
          'disconnected': false,
          'from_switch': false,
          'in_voice_call': false,
          'incoming_voice_call': false,
          if (profile != null) 'sd_profile': profile,
        };
    expect(Client.fromJson(json(profile: 'Full Access')).sdProfile, 'Full Access');
    expect(Client.fromJson(json()).sdProfile, '', reason: 'a core that does not say: nothing is shown');
    expect(Client.fromJson(Client.fromJson(json(profile: 'Default')).toJson()).sdProfile, 'Default');
  });

  testWidgets('without profiles the three general modes are still what is offered', (tester) async {
    String? mode;
    await _show(tester, _panel(onAccess: (m) => mode = m));
    expect(find.text('Custom'), findsOneWidget);
    await tester.tap(find.text('Custom'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Full Access'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(mode, 'full');
  });
}
