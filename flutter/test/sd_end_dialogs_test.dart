import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_end_dialogs.dart';
import 'package:flutter_test/flutter_test.dart';

// What the person who connected sees when the other computer ends the session or refuses the request (new look): which card each reason gives, what
// the cards say, and that their buttons do what they say.

Future<void> _font(String family, List<String> files, String dir) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(File('$dir$f').readAsBytesSync()).buffer)));
  }
  await loader.load();
}

Widget _app(Widget child, {Brightness brightness = Brightness.light}) => MaterialApp(
      theme: ThemeData(fontFamily: 'Inter', brightness: brightness),
      home: Scaffold(body: child),
    );

Widget _dialog(SdEndKind kind,
        {Duration? duration = const Duration(minutes: 7, seconds: 51),
        String name = 'saqibs-macbook-pro-2025',
        String who = 'SaqibKhanBaloch',
        VoidCallback? onReconnect,
        VoidCallback? onClose}) =>
    SdSessionEndDialog(kind: kind, name: name, who: who, peerId: '408 241 669', duration: duration, onReconnect: onReconnect, onClose: onClose ?? () {});

void _size(WidgetTester tester, {double w = 900, double h = 700}) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => _font('Inter', ['Inter-Regular.ttf', 'Inter-Medium.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf'], 'assets/fonts/'));

  group('which card a reason gives', () {
    SdEndKind? kind(String text, {bool accepted = true, String type = 'error', String title = 'Connection Error'}) =>
        sdEndKindFor(type: type, title: title, text: text, accepted: accepted);

    test('the host closes a session it had accepted: Session Ended', () {
      expect(kind('Closed manually by the peer'), SdEndKind.ended);
    });

    test('the host says no to a request still waiting: Connection Rejected', () {
      expect(kind('Closed manually by the peer', accepted: false), SdEndKind.rejected);
    });

    test('the web console and the inactivity timer end a session with their own words', () {
      expect(kind('Closed manually by web console'), SdEndKind.admin);
      expect(kind('Connection failed due to inactivity'), SdEndKind.inactive);
    });

    test('every other message stays the plain box', () {
      expect(kind('Reset by the peer'), isNull);
      expect(kind('Remote desktop is offline'), isNull);
      expect(kind('Timeout'), isNull);
      expect(kind('Closed manually by the peer', type: 'info'), isNull);
      expect(kind('Closed manually by the peer', title: 'Prompt'), isNull);
    });
  });

  test('the time of a session is written hours:minutes:seconds', () {
    expect(sdDurationText(const Duration(minutes: 7, seconds: 51)), '00:07:51');
    expect(sdDurationText(const Duration(hours: 12, minutes: 3, seconds: 9)), '12:03:09');
    expect(sdDurationText(Duration.zero), '00:00:00');
    expect(sdDurationText(const Duration(seconds: -5)), '00:00:00');
  });

  group('Session Ended', () {
    testWidgets('names the computer, says the host ended it, and shows how long it ran', (tester) async {
      _size(tester);
      await tester.pumpWidget(_app(_dialog(SdEndKind.ended)));
      expect(find.text('saqibs-macbook-pro-2025'), findsOneWidget);
      expect(find.text('SaqibKhanBaloch'), findsOneWidget);
      expect(find.text('Ended by remote host'), findsOneWidget);
      expect(find.text('E2E Encrypted'), findsOneWidget);
      expect(find.text('00:07:51'), findsOneWidget);
      expect(find.text('DURATION'), findsOneWidget);
      expect(find.text('408 241 669'), findsOneWidget);
      expect(find.text('SYSTEMDESK ID'), findsOneWidget);
      expect(find.text('Clean Exit'), findsOneWidget);
      expect(find.text('saqibs-macbook-pro-2025 closed the remote session. Click Reconnect to start a new request.'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Retry Request'), findsNothing);
    });

    testWidgets('a session whose start is not known shows dashes, not a made-up time', (tester) async {
      _size(tester);
      await tester.pumpWidget(_app(_dialog(SdEndKind.ended, duration: null)));
      expect(find.text('--:--:--'), findsOneWidget);
    });

    testWidgets('without a name the ID stands in for it, in the card and in the sentence', (tester) async {
      _size(tester);
      await tester.pumpWidget(_app(_dialog(SdEndKind.ended, name: '', who: '')));
      expect(find.byKey(const ValueKey('sd-end-name')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('sd-end-name'))).data, '408 241 669');
      expect(find.byKey(const ValueKey('sd-end-who')), findsNothing);
      expect(find.text('408 241 669 closed the remote session. Click Reconnect to start a new request.'), findsOneWidget);
    });

    testWidgets('Reconnect and Close do what they say', (tester) async {
      _size(tester);
      final seen = <String>[];
      await tester.pumpWidget(_app(_dialog(SdEndKind.ended, onReconnect: () => seen.add('reconnect'), onClose: () => seen.add('close'))));
      await tester.tap(find.byKey(const ValueKey('sd-end-primary')));
      await tester.tap(find.byKey(const ValueKey('sd-end-secondary')));
      expect(seen, ['reconnect', 'close']);
    });

    testWidgets('Enter reconnects and Escape closes', (tester) async {
      _size(tester);
      final seen = <String>[];
      await tester.pumpWidget(_app(_dialog(SdEndKind.ended, onReconnect: () => seen.add('reconnect'), onClose: () => seen.add('close'))));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(seen, ['reconnect', 'close']);
    });
  });

  group('Connection Rejected', () {
    testWidgets('says the request was refused, with Retry Request', (tester) async {
      _size(tester);
      await tester.pumpWidget(_app(_dialog(SdEndKind.rejected, duration: null)));
      expect(find.text('Connection rejected by remote host'), findsOneWidget);
      expect(find.text('Access Denied'), findsOneWidget);
      expect(find.text('TARGET ID'), findsOneWidget);
      expect(find.text('408 241 669'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
      expect(find.text('The remote host declined the connection request. You can retry or check your access credentials.'), findsOneWidget);
      expect(find.text('Retry Request'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Reconnect'), findsNothing);
      expect(find.text('DURATION'), findsNothing, reason: 'a request that was refused never ran');
      expect(find.text('E2E Encrypted'), findsNothing);
    });

    testWidgets('Retry Request asks to connect again', (tester) async {
      _size(tester);
      var again = 0;
      await tester.pumpWidget(_app(_dialog(SdEndKind.rejected, onReconnect: () => again++)));
      await tester.tap(find.byKey(const ValueKey('sd-end-primary')));
      expect(again, 1);
    });
  });

  group('the other reasons', () {
    testWidgets('an administrator ended it from the web console', (tester) async {
      _size(tester);
      await tester.pumpWidget(_app(_dialog(SdEndKind.admin)));
      expect(find.text('Ended by an administrator'), findsOneWidget);
      expect(find.text('By Admin'), findsOneWidget);
      expect(find.text('00:07:51'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
    });

    testWidgets('the connection went quiet for too long', (tester) async {
      _size(tester);
      await tester.pumpWidget(_app(_dialog(SdEndKind.inactive)));
      expect(find.text('Ended due to inactivity'), findsOneWidget);
      expect(find.text('Timed Out'), findsOneWidget);
    });
  });

  group('the words go through the translator', () {
    testWidgets('every line of the card', (tester) async {
      _size(tester);
      String up(String s) => s.toUpperCase();
      await tester.pumpWidget(_app(SdSessionEndDialog(kind: SdEndKind.ended, name: 'a', peerId: '1 2 3', duration: Duration.zero, onClose: () {}, tr: up)));
      expect(find.text('ENDED BY REMOTE HOST'), findsOneWidget);
      expect(find.text('RECONNECT'), findsOneWidget);
      expect(find.text('CLOSE'), findsOneWidget);
      expect(find.text('CLEAN EXIT'), findsOneWidget);
    });
  });

  group('drawing', () {
    for (final brightness in Brightness.values) {
      for (final kind in SdEndKind.values) {
        testWidgets('${kind.name} in ${brightness.name} mode fits a small session window', (tester) async {
          _size(tester, w: 560, h: 560);
          await tester.pumpWidget(_app(_dialog(kind, name: 'a-computer-with-a-very-long-name-that-has-to-be-cut-somewhere'), brightness: brightness));
          expect(tester.takeException(), isNull);
          expect(find.byKey(const ValueKey('sd-end-header')), findsOneWidget);
        });
      }
    }
  });

  group('where it is used', () {
    final model = File('lib/models/model.dart').readAsStringSync().replaceAll('\r\n', '\n');

    test('the connection remembers when the host accepted, and forgets it when a new request waits', () {
      expect(model.contains('if (!isCache) _sdAcceptedAt ??= DateTime.now();'), isTrue);
      expect(model.contains("} else if (type == 'wait-remote-accept-nook') {\n      _sdAcceptedAt = null;"), isTrue);
    });

    test('the plain "Connection error" box becomes the card, in the new look only', () {
      expect(model.contains('SdLook.enabled ? sdEndKindFor(type: type, title: title, text: text, accepted: _sdAcceptedAt != null) : null'), isTrue);
      expect(model.contains('showSdSessionEndDialog(dialogManager,'), isTrue);
    });
  });
}
