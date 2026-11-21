import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_session_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => SdLook.debugEnabled = null);

  group('the sessions the computer sends', () {
    test('how it names them', () {
      final console = SdWindowsSession.parse('2', 'Console');
      expect((console.title, console.user, console.isConsole), ('Console', '', true));
      expect(console.detail, 'The screen of this computer · nobody is signed in');

      final ahmed = SdWindowsSession.parse('1', 'Console: Ahmed');
      expect((ahmed.title, ahmed.user), ('Console', 'Ahmed'));
      expect(ahmed.detail, 'Ahmed · the screen of this computer');

      final admin = SdWindowsSession.parse('3', 'RDP: Admin');
      expect((admin.title, admin.user, admin.isConsole), ('Remote Desktop', 'Admin', false));
      expect(admin.detail, 'Admin · a remote session');

      final citrix = SdWindowsSession.parse('5', 'ICA: Sara');
      expect(citrix.title, 'Citrix');
    });

    test('the session in use now, and two with the same name', () {
      final running = SdWindowsSession.parse('3', 'RDP: Admin (running)');
      expect((running.running, running.user, running.sidNote), (true, 'Admin', ''));
      final twin = SdWindowsSession.parse('4', 'RDP: Admin (sid = 4)');
      expect((twin.running, twin.user, twin.sidNote), (false, 'Admin', 'Session 4'));
      final both = SdWindowsSession.parse('4', 'RDP: Admin (sid = 4) (running)');
      expect((both.running, both.user, both.sidNote), (true, 'Admin', 'Session 4'));
    });

    test('a name that is empty or odd still gives something to show', () {
      expect(SdWindowsSession.parse('7', '').title, 'Session 7');
      expect(SdWindowsSession.parse('7', 'Weird').title, 'Weird');
    });

    test('the list in the JSON', () {
      final list = sdParseWindowsSessions('[{"sid":"2","name":"Console: Ahmed"},{"sid":3,"name":"RDP: Admin"},{"name":"no sid"}]');
      expect(list.map((s) => s.sid), ['2', '3'], reason: 'a number is as good as a string; an entry with no sid is left out');
      expect(sdParseWindowsSessions('not json'), isEmpty);
      expect(sdParseWindowsSessions('{"a":1}'), isEmpty);
      expect(sdParseWindowsSessions(''), isEmpty);
    });
  });

  group('the dialog', () {
    final sessions = [
      SdWindowsSession.parse('2', 'Console: Ahmed'),
      SdWindowsSession.parse('3', 'RDP: Admin'),
      SdWindowsSession.parse('4', 'RDP: Sara (running)'),
    ];

    Future<void> show(WidgetTester tester, List<SdWindowsSession> list, {required void Function(String) onConnect, required VoidCallback onCancel}) async {
      SdLook.debugEnabled = true;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 480, child: SdSessionPicker(sessions: list, onConnect: onConnect, onCancel: onCancel)))),
      ));
    }

    testWidgets('it starts on the session in use now and connects to it', (tester) async {
      String? connected;
      await show(tester, sessions, onConnect: (sid) => connected = sid, onCancel: () => fail('not cancelled'));
      expect(find.text('Choose a session'), findsOneWidget);
      expect(find.text('Remote Desktop'), findsNWidgets(2));
      expect(find.text('IN USE NOW'), findsOneWidget);
      await tester.tap(find.text('Connect'));
      expect(connected, '4');
    });

    testWidgets('without one in use it starts on the first; a tap chooses another', (tester) async {
      String? connected;
      await show(tester, [sessions[0], sessions[1]], onConnect: (sid) => connected = sid, onCancel: () => fail('not cancelled'));
      await tester.tap(find.text('Connect'));
      expect(connected, '2');
      await tester.tap(find.byKey(const ValueKey('sd-session-3')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Connect'));
      expect(connected, '3');
    });

    testWidgets('Cancel does not connect', (tester) async {
      var cancelled = 0;
      await show(tester, sessions, onConnect: (_) => fail('not connected'), onCancel: () => cancelled++);
      await tester.tap(find.text('Cancel'));
      expect(cancelled, 1);
    });
  });
}
