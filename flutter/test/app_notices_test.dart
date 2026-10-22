import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/screens/sd_message_dialog.dart';
import 'package:flutter_hbb/screens/sd_modal.dart';
import 'package:flutter_hbb/screens/sd_palette.dart';
import 'package:flutter_hbb/screens/sd_update_gate.dart';
import 'package:flutter_hbb/services/app_notices.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('versions', () {
    test('three numbers are read, anything else is not', () {
      expect(parseAppVersion('1.5.8'), [1, 5, 8]);
      expect(parseAppVersion(' 1.5.100 '), [1, 5, 100]);
      expect(parseAppVersion('1.5'), isNull);
      expect(parseAppVersion('1.5.8-beta'), isNull);
      expect(parseAppVersion(''), isNull);
      expect(parseAppVersion(null), isNull);
    });

    test('compare as numbers, not as text', () {
      expect(compareAppVersions('1.5.7', '1.5.8'), -1);
      expect(compareAppVersions('1.5.8', '1.5.8'), 0);
      expect(compareAppVersions('1.5.100', '1.5.8'), 1);
      expect(compareAppVersions('1.10.0', '1.9.9'), 1);
      expect(compareAppVersions('2.0.0', '1.99.99'), 1);
    });

    test('a version that is not one counts as the lowest', () {
      expect(compareAppVersions('', '1.0.0'), -1);
      expect(compareAppVersions('1.0.0', null), 1);
      expect(compareAppVersions('x', 'y'), 0);
    });
  });

  group('required update', () {
    test('the poll says nothing is required', () {
      expect(RequiredUpdate.fromPoll({'required': false}), isNull);
      expect(RequiredUpdate.fromPoll(null), isNull);
      expect(RequiredUpdate.fromPoll('x'), isNull);
    });

    test('the poll requires a version', () {
      final r = RequiredUpdate.fromPoll({
        'required': true,
        'version': '1.5.8',
        'message': 'A security fix.',
        'download_url': 'https://systemdesk.net/download/',
      })!;
      expect(r.version, '1.5.8');
      expect(r.message, 'A security fix.');
      expect(r.downloadUrl, 'https://systemdesk.net/download/');
    });

    test('a requirement without a real version is ignored (the app is never locked by a broken answer)', () {
      expect(RequiredUpdate.fromPoll({'required': true}), isNull);
      expect(RequiredUpdate.fromPoll({'required': true, 'version': 'soon'}), isNull);
    });

    test('it is remembered between runs', () {
      const r = RequiredUpdate(version: '1.5.8', message: 'm', downloadUrl: 'https://x.test/d');
      expect(RequiredUpdate.fromStored(r.toStored()), r);
      expect(RequiredUpdate.fromStored(''), isNull);
      expect(RequiredUpdate.fromStored('not json'), isNull);
      expect(RequiredUpdate.fromStored('{"version":"nope"}'), isNull);
    });

    test('it stays in force until the app has the version', () {
      const r = RequiredUpdate(version: '1.5.8');
      expect(r.appliesTo('1.5.7'), isTrue);
      expect(r.appliesTo('1.5.8'), isFalse);
      expect(r.appliesTo('1.6.0'), isFalse);
      expect(r.appliesTo(''), isTrue, reason: 'an app that cannot say its version stays stopped');
    });
  });

  group('messages', () {
    test('a list is read, broken entries and unknown styles are handled', () {
      final list = AppMessage.listFrom([
        {'id': 'a', 'title': 'Maintenance', 'body': 'Sunday 02:00', 'severity': 'warning'},
        {'id': 7, 'title': 'News', 'body': 'New release', 'severity': 'rainbow'},
        {'id': 'c', 'title': 'No body'},
        {'title': 'No id', 'body': 'x'},
        'junk',
      ]);
      expect(list.map((m) => m.id), ['a', '7']);
      expect(list[0].severity, 'warning');
      expect(list[1].severity, 'info');
      expect(AppMessage.listFrom(null), isEmpty);
      expect(AppMessage.listFrom({'a': 1}), isEmpty);
    });

    test('only the messages not shown yet are left, in order', () {
      final all = AppMessage.listFrom([
        {'id': '1', 'title': 't', 'body': 'b'},
        {'id': '2', 'title': 't', 'body': 'b'},
        {'id': '3', 'title': 't', 'body': 'b'},
      ]);
      expect(unseenMessages(all, '').map((m) => m.id), ['1', '2', '3']);
      expect(unseenMessages(all, '2').map((m) => m.id), ['1', '3']);
      expect(unseenMessages(all, '1,2,3'), isEmpty);
    });

    test('shown ids are remembered once and only the newest are kept', () {
      expect(rememberSeen('', 'a'), 'a');
      expect(rememberSeen('a,b', 'a'), 'b,a');
      var seen = '';
      for (var i = 0; i < kSeenMessagesKept + 10; i++) {
        seen = rememberSeen(seen, 'm$i');
      }
      final ids = seen.split(',');
      expect(ids.length, kSeenMessagesKept);
      expect(ids.last, 'm${kSeenMessagesKept + 9}');
      expect(ids.contains('m0'), isFalse);
    });
  });

  group('screens', () {
    Widget host(Widget child, {required bool dark}) => MaterialApp(
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: Scaffold(body: Center(child: child)),
        );

    for (final dark in [false, true]) {
      testWidgets('the update screen says what to do and has both buttons (${dark ? 'dark' : 'light'})', (tester) async {
        SdPalette.debugDark = dark;
        addTearDown(() => SdPalette.debugDark = null);
        tester.view.physicalSize = const Size(900, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        var updated = 0, quit = 0;
        await tester.pumpWidget(host(
          UpdateGateScreen(
            info: const RequiredUpdate(version: '1.5.8', message: 'This fixes a security problem.'),
            currentVersion: '1.5.7',
            onUpdate: () => updated++,
            onQuit: () => quit++,
            draggable: false,
          ),
          dark: dark,
        ));
        expect(find.text('Update SystemDesk'), findsOneWidget);
        expect(find.text('This update is required.'), findsOneWidget);
        expect(find.text("You can't use SystemDesk until it is installed."), findsOneWidget);
        expect(find.text('This fixes a security problem.'), findsOneWidget);
        expect(find.text('1.5.7'), findsOneWidget);
        expect(find.text('1.5.8 or newer'), findsOneWidget);
        await tester.tap(find.text('Update now'));
        await tester.tap(find.text('Quit'));
        expect([updated, quit], [1, 1]);
      });
    }

    testWidgets('the update screen has no Quit where an app cannot quit', (tester) async {
      await tester.pumpWidget(host(
        UpdateGateScreen(
          info: const RequiredUpdate(version: '1.5.8'),
          currentVersion: '',
          onUpdate: () {},
          draggable: false,
        ),
        dark: false,
      ));
      expect(find.text('Quit'), findsNothing);
      expect(find.text('You have'), findsNothing, reason: 'the own version is only shown when it is known');
    });

    testWidgets('the screen blocks what is behind it', (tester) async {
      var behind = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(children: [
            Center(child: ElevatedButton(onPressed: () => behind++, child: const Text('Connect'))),
            UpdateGateScreen(
              info: const RequiredUpdate(version: '1.5.8'),
              currentVersion: '1.5.7',
              onUpdate: () {},
              draggable: false,
            ),
          ]),
        ),
      ));
      await tester.tapAt(tester.getCenter(find.text('Connect')));
      expect(behind, 0);
    });

    testWidgets('a message shows its title and text', (tester) async {
      await tester.pumpWidget(host(
        const AppMessageBody(message: AppMessage(id: '1', title: 'Maintenance tonight', body: 'The service restarts at 02:00.', severity: 'warning')),
        dark: true,
      ));
      expect(find.text('Maintenance tonight'), findsOneWidget);
      expect(find.text('The service restarts at 02:00.'), findsOneWidget);
    });

    test('every style has an icon and a colour', () {
      for (final s in ['info', 'success', 'warning', 'critical']) {
        for (final dark in [false, true]) {
          final st = messageStyle(s, dark);
          expect(st.color.opacity, 1.0);
          expect(st.icon, isNotNull);
        }
      }
    });
  });

  group('the modal that paints its own surface', () {
    Widget app(Widget modal, {void Function()? behind}) => MaterialApp(
          home: Scaffold(
            body: Stack(children: [
              Center(child: ElevatedButton(onPressed: behind, child: const Text('Behind'))),
              modal,
            ]),
          ),
        );

    testWidgets('shows its content and actions on an opaque card and keeps the screen behind out of reach', (tester) async {
      SdPalette.debugDark = false;
      addTearDown(() => SdPalette.debugDark = null);
      var behind = 0, pressed = 0;
      await tester.pumpWidget(app(
        SdModal(
          opaqueBackdrop: true,
          content: const Text('Session time limit reached'),
          actions: [ElevatedButton(onPressed: () => pressed++, child: const Text('OK'))],
        ),
        behind: () => behind++,
      ));
      expect(find.text('Session time limit reached'), findsOneWidget);
      final card = tester.widget<DecoratedBox>(find.byKey(const ValueKey('sd-modal-card')));
      expect((card.decoration as BoxDecoration).color, SdPalette.light.fill, reason: 'its own opaque fill');
      final backdrop = tester.widget<ColoredBox>(find.byKey(const ValueKey('sd-modal-backdrop')));
      expect(backdrop.color.opacity, 1.0, reason: 'the backdrop is opaque: what is behind is not shown');
      await tester.tapAt(const Offset(5, 5));
      await tester.tap(find.text('Behind'), warnIfMissed: false);
      expect(behind, 0);
      await tester.tap(find.text('OK'));
      expect(pressed, 1);
    });

    testWidgets('Enter submits and Escape cancels', (tester) async {
      var submitted = 0, cancelled = 0;
      await tester.pumpWidget(app(
        SdModal(content: const Text('x'), onSubmit: () => submitted++, onCancel: () => cancelled++),
      ));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect([submitted, cancelled], [1, 1]);
    });

    testWidgets('the dimming backdrop of a message lets the window show through a little', (tester) async {
      SdPalette.debugDark = true;
      addTearDown(() => SdPalette.debugDark = null);
      await tester.pumpWidget(app(const SdModal(content: Text('A message'))));
      final backdrop = tester.widget<ColoredBox>(find.byKey(const ValueKey('sd-modal-backdrop')));
      expect(backdrop.color.opacity, lessThan(1.0));
    });
  });

  group('the update screen in a running app', () {
    tearDown(() => SdUpdateGate.set(null));

    testWidgets('covers the app, lets later dialogs open above it, and goes when nothing is required', (tester) async {
      SdPalette.debugDark = false;
      addTearDown(() => SdPalette.debugDark = null);
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      var behind = 0, above = 0;
      await tester.pumpWidget(MaterialApp(
        navigatorKey: globalKey,
        home: Scaffold(body: Center(child: ElevatedButton(onPressed: () => behind++, child: const Text('Connect')))),
      ));

      await tester.tap(find.text('Connect'));
      expect(behind, 1, reason: 'before the requirement the app works');
      expect(SdUpdateGate.showing, isFalse);

      SdUpdateGate.currentVersion = '1.5.7';
      SdUpdateGate.set(const RequiredUpdate(version: '1.5.8', message: 'A security fix.'));
      await tester.pump();
      expect(SdUpdateGate.showing, isTrue);
      expect(find.text('Update SystemDesk'), findsOneWidget);
      expect(find.text('A security fix.'), findsOneWidget);

      await tester.tapAt(tester.getCenter(find.text('Connect', skipOffstage: false)));
      expect(behind, 1, reason: 'nothing behind the screen can be reached');

      // the download progress opens after the screen: it must be above it
      final progress = OverlayEntry(
        builder: (_) => Center(child: ElevatedButton(onPressed: () => above++, child: const Text('Downloading'))),
      );
      globalKey.currentState!.overlay!.insert(progress);
      await tester.pump();
      await tester.tap(find.text('Downloading'));
      expect(above, 1);
      progress.remove();
      await tester.pump();

      // a second requirement with another version replaces the text, not the screen
      SdUpdateGate.set(const RequiredUpdate(version: '1.5.9'));
      await tester.pump();
      expect(find.text('1.5.9 or newer'), findsOneWidget);
      expect(find.text('1.5.8 or newer'), findsNothing);

      SdUpdateGate.set(null);
      await tester.pump();
      expect(SdUpdateGate.showing, isFalse);
      expect(find.text('Update SystemDesk'), findsNothing);
      await tester.tap(find.text('Connect'));
      expect(behind, 2, reason: 'lifted: the app works again');
    });

    testWidgets('a requirement set before the app has an overlay shows as soon as it has one', (tester) async {
      SdPalette.debugDark = true;
      addTearDown(() => SdPalette.debugDark = null);
      SdUpdateGate.set(const RequiredUpdate(version: '1.5.8'));
      expect(SdUpdateGate.showing, isFalse);
      await tester.pumpWidget(MaterialApp(navigatorKey: globalKey, home: const Scaffold(body: SizedBox())));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(SdUpdateGate.showing, isTrue);
      expect(find.text('Update SystemDesk'), findsOneWidget);
    });
  });
}
