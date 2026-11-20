import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_connect_dialog.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_modal.dart';
import 'package:flutter_hbb/screens/sd_palette.dart';
import 'package:flutter_hbb/screens/sd_sessions_bind.dart';
import 'package:flutter_hbb/screens/sd_signin_modal.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:flutter_hbb/screens/sd_toolbar.dart';
import 'package:flutter_hbb/screens/sd_update_card.dart';
import 'package:flutter_hbb/services/session_log.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

Future<void> _font(String family, List<String> files, String dir) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(File('$dir$f').readAsBytesSync()).buffer)));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // the real fonts: the test font of the framework is as wide as it is high, and a row that fits on a screen would not fit in it
  setUpAll(() async {
    await _font('Inter', ['Inter-Regular.ttf', 'Inter-Medium.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf'], 'assets/fonts/');
  });
  tearDown(() {
    SdLook.debugEnabled = null;
    SdPalette.debugDark = null;
  });

  group('words and numbers', () {
    test('an ID is written in groups of three', () {
      expect(sdFormatId('408118204'), '408 118 204');
      expect(sdFormatId('408 118 204'), '408 118 204');
      expect(sdFormatId('1234567'), '1 234 567');
      expect(sdFormatId('abc'), 'abc');
      expect(sdConnectSub('408118204'), 'Remote control · ID 408 118 204');
    });

    test('the seconds left to accept are a clock', () {
      expect(sdClockOf(98), '1:38');
      expect(sdClockOf(100), '1:40');
      expect(sdClockOf(5), '0:05');
      expect(sdClockOf(-3), '0:00');
    });

    test('the time a tab has been open', () {
      expect(sdTabTime(const Duration(minutes: 12, seconds: 48)), '12:48');
      expect(sdTabTime(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
      expect(sdTabTime(Duration.zero), '00:00');
    });

    test('the notes of an update are the lines of the message', () {
      expect(SdUpdateCard.notesOf('- first\n* second\n\n• third\nplain\r\n  - fourth  '), ['first', 'second', 'third', 'plain', 'fourth']);
      expect(SdUpdateCard.notesOf(''), isEmpty);
      expect(SdUpdateCard.notesOf('  \n - \n'), isEmpty);
    });

    test('the kind of a computer is read from the name of its system', () {
      expect(sdOsOf('Windows'), SdOs.windows);
      expect(sdOsOf('Mac OS'), SdOs.mac);
      expect(sdOsOf('macOS 14'), SdOs.mac);
      expect(sdOsOf('Linux'), SdOs.linux);
      expect(sdOsOf('Android'), SdOs.android);
      expect(sdOsOf(''), SdOs.other);
      expect(sdOsOf('Plan 9'), SdOs.other);
    });

    test('the Sessions page words', () {
      expect(sdClock(const Duration(minutes: 12, seconds: 4)), '12:04');
      expect(sdClock(const Duration(hours: 2, minutes: 5, seconds: 9)), '2:05:09');
      expect(sdLength(const Duration(seconds: 30)), '<1 min');
      expect(sdLength(const Duration(minutes: 12)), '12 min');
      expect(sdLength(const Duration(hours: 1, minutes: 5)), '1 h 05 min');
      final now = DateTime(2026, 11, 19, 15, 0);
      expect(sdWhen(DateTime(2026, 11, 19, 14, 8), now), 'Today, 14:08');
      expect(sdWhen(DateTime(2026, 11, 18, 17, 30), now), 'Yesterday, 17:30');
      expect(sdWhen(DateTime(2026, 11, 16, 9, 12), now), 'Mon, 09:12');
      expect(sdWhen(DateTime(2026, 11, 1, 9, 12), now), 'Nov 1, 09:12');
    });

    test('the week of the usage answer is seven bars, oldest first', () {
      final bars = sdDaysFromUsage({
        'devices': [
          {
            'days': [
              {'date': '2026-11-19', 'minutes': 20},
              {'date': '2026-11-19', 'minutes': 5},
              {'date': '2026-11-17', 'minutes': 40},
            ]
          }
        ]
      }, DateTime.utc(2026, 11, 19, 12));
      expect(bars, isNotNull);
      expect(bars!.length, 7);
      expect(bars.last.today, isTrue);
      expect(bars.last.minutes, 25);
      expect(bars[4].minutes, 40);
      expect(bars.first.minutes, 0);
      expect(sdDaysFromUsage({'devices': []}, DateTime.utc(2026, 11, 19)), isNull);
      expect(sdDaysFromUsage(null, DateTime.utc(2026, 11, 19)), isNull);
    });

    test('the week of this computer s own log', () {
      final now = DateTime(2026, 11, 19, 15);
      final log = [
        SdSessionEntry(key: 'a', incoming: false, peerId: '1', name: 'A', kind: 'Remote control', startedAt: DateTime(2026, 11, 19, 10), endedAt: DateTime(2026, 11, 19, 10, 30)),
        SdSessionEntry(key: 'b', incoming: false, peerId: '1', name: 'A', kind: 'Remote control', startedAt: DateTime(2026, 11, 18, 10), endedAt: DateTime(2026, 11, 18, 10, 15)),
        SdSessionEntry(key: 'c', incoming: false, peerId: '1', name: 'A', kind: 'Remote control', startedAt: DateTime(2026, 11, 19, 14)),
      ];
      final bars = sdDaysFromLog(log, now);
      expect(bars.length, 7);
      expect(bars.last.minutes, closeTo(30, 0.01));
      expect(bars[5].minutes, closeTo(15, 0.01));
    });

    test('a session entry survives its own JSON and knows when it is live', () {
      final e = SdSessionEntry(
        key: 'k',
        incoming: true,
        peerId: '408118204',
        name: 'MARKETING-DELL',
        kind: 'Remote control',
        startedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        seenAt: DateTime.fromMillisecondsSinceEpoch(5000),
      );
      final back = SdSessionEntry.fromJson(e.toJson())!;
      expect(back.key, 'k');
      expect(back.incoming, isTrue);
      expect(back.peerId, '408118204');
      expect(back.endedAt, isNull);
      expect(e.isLive(DateTime.fromMillisecondsSinceEpoch(5000 + 89000)), isTrue);
      expect(e.isLive(DateTime.fromMillisecondsSinceEpoch(5000 + 91000)), isFalse);
      e.endedAt = DateTime.fromMillisecondsSinceEpoch(6000);
      expect(e.isLive(DateTime.fromMillisecondsSinceEpoch(7000)), isFalse);
      expect(SdSessionEntry.fromJson('nonsense'), isNull);
    });
  });

  group('the switch', () {
    testWidgets('dialogs keep the amber of the old look and take the gold of the new one', (tester) async {
      SdPalette.debugDark = false;
      late SdPalette oldP, newP;
      SdLook.debugEnabled = false;
      await tester.pumpWidget(_app(Builder(builder: (c) {
        oldP = SdPalette.of(c);
        return const SizedBox();
      })));
      SdLook.debugEnabled = true;
      await tester.pumpWidget(_app(Builder(builder: (c) {
        newP = SdPalette.of(c);
        return const SizedBox();
      })));
      expect(oldP.accent, SdPalette.amber);
      // the flat design uses the same amber as the old look
      expect(newP.accent, SdSkin.light.goldB);
    });

    testWidgets('the modal has its blurred backdrop only in the new look', (tester) async {
      SdLook.debugEnabled = false;
      await tester.pumpWidget(_app(const SdModal(content: Text('hello'))));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('hello'), findsOneWidget);
      SdLook.debugEnabled = true;
      await tester.pumpWidget(_app(const SdModal(content: Text('hello'))));
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byKey(const ValueKey('sd-modal-card')), findsOneWidget);
      expect(find.text('hello'), findsOneWidget);
    });
  });

  group('the cards', () {
    testWidgets('the sign-in asks for a name and a password and signs in on the button and on Enter', (tester) async {
      SdLook.debugEnabled = true;
      var signedIn = 0, guest = 0;
      final user = TextEditingController(), password = TextEditingController();
      await tester.pumpWidget(_app(SingleChildScrollView(child: SizedBox(width: 440, child: SdSignInForm(user: user, password: password, onSubmit: () => signedIn++, onGuest: () => guest++, onCreate: () {})))));
      expect(find.text('Sign in to SystemDesk'), findsOneWidget);
      expect(find.text('Username or email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'alex');
      await tester.enterText(find.byType(TextField).last, 'secret');
      expect(user.text, 'alex');
      expect(password.text, 'secret');
      await tester.tap(find.text('Sign in'));
      expect(signedIn, 1);
      await tester.tap(find.text('Continue as guest'));
      expect(guest, 1);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(signedIn, 2);
    });

    testWidgets('the sign-in shows the error under the fields', (tester) async {
      SdLook.debugEnabled = true;
      await tester.pumpWidget(_app(SingleChildScrollView(child: SizedBox(width: 440, child: SdSignInForm(user: TextEditingController(), password: TextEditingController(), error: 'Wrong password.', onSubmit: () {})))));
      expect(find.text('Wrong password.'), findsOneWidget);
    });

    testWidgets('the connecting card follows the stage of the connection', (tester) async {
      SdLook.debugEnabled = true;
      var cancelled = 0;
      Widget view(SdConnectStage stage) => _app(SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: SdConnectView(target: 'MARKETING-DELL', sub: sdConnectSub('408118204'), stage: stage, reachedIn: '0.4 s', secure: true, direct: true, secondsLeft: 98, onCancel: () => cancelled++),
            ),
          ));
      await tester.pumpWidget(view(SdConnectStage.reaching));
      expect(find.text('Connecting to MARKETING-DELL'), findsOneWidget);
      expect(find.text('Reaching the computer'), findsOneWidget);
      expect(find.text('1:38'), findsNothing);
      expect(find.text('Encrypted'), findsNothing);
      await tester.pumpWidget(view(SdConnectStage.waiting));
      expect(find.text('Encrypted'), findsOneWidget);
      expect(find.text('0.4 s'), findsOneWidget);
      expect(find.text('1:38'), findsOneWidget);
      expect(find.text('Someone at the other computer taps Accept.'), findsOneWidget);
      expect(find.text('DIRECT CONNECTION'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      expect(cancelled, 1);
    });

    testWidgets('a relay connection is not called direct', (tester) async {
      SdLook.debugEnabled = true;
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: SizedBox(width: 480, child: SdConnectView(target: 'X', sub: 's', stage: SdConnectStage.waiting, secure: false, direct: false, secondsLeft: 10, onCancel: () {})),
      )));
      expect(find.text('RELAY CONNECTION'), findsOneWidget);
      expect(find.text('Not encrypted'), findsOneWidget);
    });

    testWidgets('the update card says which version and lists what it brings', (tester) async {
      SdLook.debugEnabled = true;
      var updated = 0, quit = 0;
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: SdUpdateCard(version: '1.5.23', message: 'One\nTwo', onUpdate: () => updated++, onQuit: () => quit++),
      )));
      expect(find.text('SystemDesk 1.5.23 is ready'), findsOneWidget);
      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
      await tester.tap(find.text('Update now'));
      await tester.tap(find.text('Quit'));
      expect(updated, 1);
      expect(quit, 1);
      await tester.pumpWidget(_app(SingleChildScrollView(child: SdUpdateCard(version: '1.5.23', message: '', onUpdate: () {}))));
      expect(find.text('Quit'), findsNothing);
    });
  });

  group('the toolbar', () {
    testWidgets('a button of the bar shows its icon, and the End button its word', (tester) async {
      SdLook.debugEnabled = true;
      await tester.pumpWidget(_app(const Row(mainAxisSize: MainAxisSize.min, children: [
        SdToolFace(icon: SdIcons.mic),
        SdToolFace(icon: SdIcons.speaker, on: true),
        SdToolFace(icon: SdIcons.power, label: 'End'),
      ])));
      expect(find.byType(SdToolFace), findsNWidgets(3));
      expect(find.text('End'), findsOneWidget);
      final faces = tester.widgetList<SdToolFace>(find.byType(SdToolFace)).toList();
      expect(faces[1].on, isTrue);
      expect(faces[0].on, isFalse);
      final size = tester.getSize(find.byType(SdToolFace).first);
      expect(size.width, SdToolbar.buttonWidth);
      expect(size.height, SdToolbar.buttonHeight);
    });

    testWidgets('the bar has a line between groups, lying across a bar that lies along the top', (tester) async {
      await tester.pumpWidget(_app(const Row(mainAxisSize: MainAxisSize.min, children: [SdToolSep(), SdToolSep(horizontal: false)])));
      final seps = tester.widgetList<Container>(find.descendant(of: find.byType(SdToolSep), matching: find.byType(Container))).toList();
      expect(seps.length, 2);
    });

    testWidgets('a tab of a computer shows the time it has been open', (tester) async {
      SdLook.debugEnabled = true;
      SdTabClock.debugSince('tab-1', DateTime.now().subtract(const Duration(minutes: 3, seconds: 7)));
      await tester.pumpWidget(_app(sdRemoteTabContent(tabKey: 'tab-1', label: const Text('PC'), unread: const SizedBox.shrink(), tooltip: 'Direct')));
      expect(find.text('PC'), findsOneWidget);
      expect(find.textContaining('03:0'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
