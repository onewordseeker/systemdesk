import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_cm_cards.dart';
import 'package:flutter_hbb/screens/sd_cm_window.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_shell.dart';
import 'package:flutter_test/flutter_test.dart';

// The two host dialogs of the new look, drawn from plain values: the request and the connection that is going.

Future<void> _font(String family, List<String> files, String dir) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(File('$dir$f').readAsBytesSync()).buffer)));
  }
  await loader.load();
}

Widget _app(Widget child, {Brightness brightness = Brightness.light, double width = 420}) => MaterialApp(
      theme: ThemeData(fontFamily: 'Inter', brightness: brightness),
      home: Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: width, child: SingleChildScrollView(child: child)))),
    );

List<SdCmTile> _tiles({void Function(String)? tap, bool lock = true}) => [
      SdCmTile(icon: SdIcons.mouse, label: 'Input', on: true, tip: 'Enable keyboard/mouse', onTap: () => tap?.call('Input')),
      SdCmTile(icon: SdIcons.clipboard, label: 'Clipboard', on: true, tip: 'Enable clipboard', onTap: () => tap?.call('Clipboard')),
      SdCmTile(icon: SdIcons.folder, label: 'Files', on: true, tip: 'Enable file copy and paste', onTap: () => tap?.call('Files')),
      SdCmTile(icon: SdIcons.speaker, label: 'Audio', on: true, tip: 'Enable audio', onTap: () => tap?.call('Audio')),
      SdCmTile(icon: SdIcons.refresh, label: 'Restart', on: false, tip: 'Enable remote restart', onTap: () => tap?.call('Restart')),
      SdCmTile(icon: SdIcons.record, label: 'Record', on: false, tip: 'Enable recording session', onTap: () => tap?.call('Record')),
      if (lock) SdCmTile(icon: SdIcons.lock, label: 'Lock', on: false, tip: 'Enable blocking user input', onTap: () => tap?.call('Lock')),
      SdCmTile(icon: SdIcons.eye, label: 'Privacy', on: false, tip: 'Enable privacy mode', onTap: () => tap?.call('Privacy')),
    ];

Widget _request({String profile = 'Profile: Default'}) => SdCmRequestCard(
      name: 'Info',
      id: 'SaqibKhanBaloch',
      profile: profile,
      what: 'wants to control this computer',
      kind: 'Remote control',
      encrypted: 'E2E Encrypted',
    );

Widget _session({bool connected = true, Widget? chat}) => SdCmSessionCard(
      name: 'Info',
      id: 'SaqibKhanBaloch',
      profile: 'Profile: Default',
      chat: chat,
      connected: connected,
      stateLabel: connected ? 'Connected' : 'Disconnected',
      time: (s) => Text('00:07:51', style: s),
      pill: 'Encrypted',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => _font('Inter', ['Inter-Regular.ttf', 'Inter-Medium.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf'], 'assets/fonts/'));

  group('the request', () {
    testWidgets('says who asks, what for, and how it is protected', (tester) async {
      await tester.pumpWidget(_app(_request()));
      expect(find.text('Info'), findsOneWidget);
      expect(find.text('SaqibKhanBaloch'), findsOneWidget);
      expect(find.text('Profile: Default'), findsOneWidget);
      expect(find.text('wants to control this computer'), findsOneWidget);
      expect(find.text('E2E Encrypted'), findsOneWidget);
      // the kind is a small capital label
      expect(find.text('REMOTE CONTROL'), findsOneWidget);
      // the picture is the amber square with the first letter
      expect(find.descendant(of: find.byKey(const ValueKey('sd-cm-avatar')), matching: find.text('I')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('has no profile pill when the connection has no profile', (tester) async {
      await tester.pumpWidget(_app(_request(profile: '')));
      expect(find.textContaining('Profile'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the ID and the profile share a line, the name is above them', (tester) async {
      await tester.pumpWidget(_app(_request()));
      final name = tester.getRect(find.text('Info'));
      final id = tester.getRect(find.text('SaqibKhanBaloch'));
      final profile = tester.getRect(find.text('Profile: Default'));
      expect(id.top, greaterThan(name.bottom - 2));
      expect((id.center.dy - profile.center.dy).abs(), lessThan(4), reason: 'the profile sits beside the ID');
      expect(profile.left, greaterThan(id.right));
    });
  });

  group('the connection', () {
    testWidgets('shows who, how long, and that it is encrypted', (tester) async {
      await tester.pumpWidget(_app(_session(), width: 400));
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('00:07:51'), findsOneWidget);
      expect(find.text('Encrypted'), findsOneWidget);
      expect(find.text('Profile: Default'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the pill fits beside the time in the small window (it used to be cut to "Remote ...")', (tester) async {
      await tester.pumpWidget(_app(_session(), width: 400));
      expect(find.textContaining('...'), findsNothing);
      expect(tester.getRect(find.text('Encrypted')).right, lessThanOrEqualTo(400 - 18 - 14 + 0.5));
      expect(tester.getRect(find.text('00:07:51')).right, lessThan(tester.getRect(find.text('Encrypted')).left));
    });

    testWidgets('a connection that has ended says so', (tester) async {
      await tester.pumpWidget(_app(_session(connected: false), width: 400));
      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.text('Connected'), findsNothing);
    });

    testWidgets('the chat button is on the card, takes a tap, and shows the unread count', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(
        _session(chat: SdCmChatCircle(icon: SdIcons.chatRound, onTap: () => taps++, tooltip: 'Chat', badge: const Text('3', key: ValueKey('unread')))),
        width: 400,
      ));
      expect(find.byKey(const ValueKey('unread')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sd-cm-chat')));
      expect(taps, 1);
      // it is level with the name and the ID, at the right end
      final chat = tester.getRect(find.byKey(const ValueKey('sd-cm-chat')));
      final card = tester.getRect(find.byKey(const ValueKey('sd-cm-session-card')));
      expect(chat.right, lessThan(card.right));
      expect(chat.top, lessThan(card.top + 60));
    });
  });

  group('the permissions', () {
    testWidgets('are eight tiles, four to a row, with a title and a hint', (tester) async {
      await tester.pumpWidget(_app(SdCmTileGrid(title: 'Allow', hint: 'Tap to toggle', tiles: _tiles())));
      expect(find.text('Allow'), findsOneWidget);
      expect(find.text('Tap to toggle'), findsOneWidget);
      for (final l in ['Input', 'Clipboard', 'Files', 'Audio', 'Restart', 'Record', 'Lock', 'Privacy']) {
        expect(find.text(l), findsOneWidget, reason: l);
      }
      final tops = {for (final l in ['Input', 'Clipboard', 'Files', 'Audio']) tester.getRect(find.text(l)).top.round()};
      expect(tops.length, 1, reason: 'the first four are on one row');
      final second = {for (final l in ['Restart', 'Record', 'Lock', 'Privacy']) tester.getRect(find.text(l)).top.round()};
      expect(second.length, 1);
      expect(second.first, greaterThan(tops.first + SdCmTileGrid.tileHeight - 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('without the title hint it shows the title alone (the connection says "Permissions")', (tester) async {
      await tester.pumpWidget(_app(SdCmTileGrid(title: 'Permissions', tiles: _tiles())));
      expect(find.text('Permissions'), findsOneWidget);
      expect(find.text('Tap to toggle'), findsNothing);
    });

    testWidgets('a tap on a tile reaches its switch; a tile the owner may not change does nothing', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(_app(SdCmTileGrid(title: 'Allow', tiles: [
        ..._tiles(tap: tapped.add).take(2),
        const SdCmTile(icon: SdIcons.lock, label: 'Lock', on: false, tip: 'Enable blocking user input'),
      ])));
      await tester.tap(find.text('Input'));
      await tester.tap(find.text('Clipboard'));
      await tester.tap(find.text('Lock'));
      expect(tapped, ['Input', 'Clipboard']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('each tile has a dot in its corner: amber when on, grey when off', (tester) async {
      await tester.pumpWidget(_app(SdCmTileGrid(title: 'Allow', tiles: _tiles())));
      Color dotOf(String label) {
        final tile = find.ancestor(of: find.text(label), matching: find.byType(SdCmTileView));
        final dots = find.descendant(of: tile, matching: find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 6 && w.constraints?.maxHeight == 6));
        final box = (tester.widget<Container>(dots.first).decoration as BoxDecoration);
        return box.color!;
      }

      expect(dotOf('Input'), SdCmColors.light.amber);
      expect(dotOf('Audio'), SdCmColors.light.amber);
      expect(dotOf('Restart'), SdCmColors.light.offDot);
      expect(dotOf('Privacy'), SdCmColors.light.offDot);
    });

    testWidgets('the tip says whether it is on, the way the old tiles did', (tester) async {
      await tester.pumpWidget(_app(SdCmTileGrid(title: 'Allow', tiles: _tiles())));
      expect(find.byTooltip('Enable keyboard/mouse: ON'), findsOneWidget);
      expect(find.byTooltip('Enable remote restart: OFF'), findsOneWidget);
    });
  });

  group('the buttons', () {
    testWidgets('Accept is amber, Dismiss is outlined, Disconnect is red; all take a tap', (tester) async {
      var accept = 0, dismiss = 0, disconnect = 0;
      await tester.pumpWidget(_app(Column(children: [
        SdCmButton(label: 'Accept', kind: SdCmBtnKind.amber, onTap: () => accept++),
        SdCmButton(label: 'Dismiss', kind: SdCmBtnKind.outline, onTap: () => dismiss++),
        SdCmButton(label: 'Disconnect', kind: SdCmBtnKind.red, onTap: () => disconnect++),
      ])));
      Color fillOf(String label) {
        final box = find.ancestor(of: find.text(label), matching: find.byType(Container)).first;
        return ((tester.widget<Container>(box).decoration) as BoxDecoration).color!;
      }

      expect(fillOf('Accept'), SdCmColors.light.amber);
      expect(fillOf('Dismiss'), Colors.white);
      expect(fillOf('Disconnect'), SdCmColors.light.red);
      await tester.tap(find.text('Accept'));
      await tester.tap(find.text('Dismiss'));
      await tester.tap(find.text('Disconnect'));
      expect([accept, dismiss, disconnect], [1, 1, 1]);
      expect(tester.getSize(find.text('Accept')).height, lessThan(24));
    });

    testWidgets('a button without a tap handler is dimmed and silent', (tester) async {
      await tester.pumpWidget(_app(const SdCmButton(label: 'Accept', kind: SdCmBtnKind.amber, onTap: null)));
      expect(tester.widget<Opacity>(find.ancestor(of: find.text('Accept'), matching: find.byType(Opacity)).first).opacity, lessThan(1));
      await tester.tap(find.text('Accept'));
      expect(tester.takeException(), isNull);
    });
  });

  group('the recording row', () {
    Widget row({bool recording = false, bool always = false, String dir = '', VoidCallback? toggle, VoidCallback? folder}) => SdCmRecordRow(
          recording: recording,
          always: always,
          dir: dir,
          onToggle: toggle ?? () {},
          onOpenFolder: folder ?? () {},
          labels: const SdCmRecordLabels(),
        );

    testWidgets('offers to record; once recording it says so, offers the folder and Stop', (tester) async {
      var toggled = 0, opened = 0;
      await tester.pumpWidget(_app(row(toggle: () => toggled++, folder: () => opened++), width: 400));
      expect(find.text('Record this session'), findsOneWidget);
      expect(find.text('Record'), findsOneWidget);
      expect(find.text('Open folder'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('sd-host-record-toggle')));
      expect(toggled, 1);

      await tester.pumpWidget(_app(row(recording: true, dir: r'C:\Users\Maya\Videos\SystemDesk', toggle: () => toggled++, folder: () => opened++), width: 400));
      expect(find.text('Recording session'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
      expect(find.text('Open folder'), findsOneWidget);
      // where the file goes is a tip over the row, not a line of text
      expect(find.byTooltip(r'Saved in C:\Users\Maya\Videos\SystemDesk'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sd-host-record-folder')));
      expect(opened, 1);
      await tester.tap(find.byKey(const ValueKey('sd-host-record-toggle')));
      expect(toggled, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('while recording it is pale red; at rest it is plain', (tester) async {
      await tester.pumpWidget(_app(row(recording: true), width: 400));
      var box = tester.widget<Container>(find.byKey(const ValueKey('sd-cm-record-row'))).decoration as BoxDecoration;
      expect(box.color, SdCmColors.light.redSoft);
      await tester.pumpWidget(_app(row(), width: 400));
      box = tester.widget<Container>(find.byKey(const ValueKey('sd-cm-record-row'))).decoration as BoxDecoration;
      expect(box.color, SdCmColors.light.card);
    });

    testWidgets('with "record every session" there is nothing to press, only the way to the folder', (tester) async {
      await tester.pumpWidget(_app(row(recording: true, always: true, dir: r'C:\x'), width: 400));
      expect(find.byKey(const ValueKey('sd-host-record-toggle')), findsNothing);
      expect(find.byKey(const ValueKey('sd-host-record-folder')), findsOneWidget);
      expect(find.text('Recording every session'), findsOneWidget);
    });
  });

  group('the window', () {
    // The pieces are put together here with the margins of `server_page.dart`; what the window shows must fit what it has, with the room the title bar
    // takes, also with the extra "Accept and elevate" button above Accept and Dismiss.
    Widget requestWindow({bool elevate = false}) => Column(key: const ValueKey('window'), children: [
          _request(),
          SdCmTileGrid(title: 'Allow', hint: 'Tap to toggle', tiles: _tiles()),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(children: [
              if (elevate) Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: SdCmButton(label: 'Accept and elevate', kind: SdCmBtnKind.dark, onTap: () {})),
              Row(children: [
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: SdCmButton(label: 'Accept', kind: SdCmBtnKind.amber, onTap: () {}))),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: SdCmButton(label: 'Dismiss', kind: SdCmBtnKind.outline, onTap: () {}))),
              ]),
            ]).paddingOnlyBottom(8),
          ),
        ]);

    Widget sessionWindow() => Column(key: const ValueKey('window'), children: [
          _session(chat: SdCmChatCircle(icon: SdIcons.chatRound, onTap: () {})),
          SdCmTileGrid(title: 'Permissions', tiles: _tiles()),
          SdCmRecordRow(recording: true, dir: r'C:\x', onToggle: () {}, onOpenFolder: () {}, labels: const SdCmRecordLabels()),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: SdCmButton(label: 'Disconnect', kind: SdCmBtnKind.red, onTap: () {})).paddingOnlyBottom(8),
          ),
        ]);

    testWidgets('the request, with "Accept and elevate", fits the request window', (tester) async {
      await tester.pumpWidget(_app(requestWindow(elevate: true), width: kSdCmRequestSize.width));
      final h = tester.getSize(find.byKey(const ValueKey('window'))).height;
      // ignore: avoid_print
      print('REQUEST content=$h room=${kSdCmRequestSize.height - kSdTitleBarHeight}');
      expect(h, lessThanOrEqualTo(kSdCmRequestSize.height - kSdTitleBarHeight));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the connection, with the recording row, fits the docked window', (tester) async {
      await tester.pumpWidget(_app(sessionWindow(), width: kSdCmCompactSize.width));
      final h = tester.getSize(find.byKey(const ValueKey('window'))).height;
      // ignore: avoid_print
      print('SESSION content=$h room=${kSdCmCompactSize.height - kSdTitleBarHeight}');
      expect(h, lessThanOrEqualTo(kSdCmCompactSize.height - kSdTitleBarHeight));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a connection with "Elevate" asks for a higher window, and in it Disconnect is in view without scrolling', (tester) async {
      Widget card({void Function(double, double)? onNeed}) => SdPinnedBottomScroll(
            onNeed: onNeed,
            top: Column(children: [
              _session(chat: SdCmChatCircle(icon: SdIcons.chatRound, onTap: () {})),
              SdCmTileGrid(title: 'Permissions', tiles: _tiles()),
              SdCmRecordRow(recording: false, onToggle: () {}, onOpenFolder: () {}, labels: const SdCmRecordLabels()),
            ]),
            bottom: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(children: [
                Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: SdCmButton(label: 'Elevate', kind: SdCmBtnKind.amber, onTap: () {})),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: SdCmButton(key: const ValueKey('disconnect'), label: 'Disconnect', kind: SdCmBtnKind.red, onTap: () {})),
              ]).paddingOnlyBottom(8),
            ),
          );
      Future<void> show(double height, Widget child) async {
        tester.view.physicalSize = Size(kSdCmCompactSize.width, height);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(theme: ThemeData(fontFamily: 'Inter'), home: Scaffold(body: child)));
        await tester.pump();
      }

      double? need, room;
      await show(kSdCmCompactSize.height - kSdTitleBarHeight, card(onNeed: (n, r) {
        need = n;
        room = r;
      }));
      final target = sdCmFitHeight(windowHeight: kSdCmCompactSize.height, room: room!, need: need!, minHeight: kSdCmCompactSize.height, maxHeight: 900);
      expect(target, isNotNull, reason: 'the fixed window is too low for Elevate');
      expect(target!, greaterThan(kSdCmCompactSize.height));

      await show(target - kSdTitleBarHeight, card());
      expect(tester.state<ScrollableState>(find.byType(Scrollable)).position.maxScrollExtent, 0);
      expect(tester.getRect(find.byKey(const ValueKey('disconnect'))).bottom, lessThanOrEqualTo(target - kSdTitleBarHeight));
      expect(tester.takeException(), isNull);
    });

    for (final brightness in Brightness.values) {
      testWidgets('both draw without an error in ${brightness.name} mode', (tester) async {
        await tester.pumpWidget(_app(requestWindow(), brightness: brightness));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(_app(sessionWindow(), brightness: brightness, width: 400));
        expect(tester.takeException(), isNull);
      });
    }
  });

  test('the colours of the design: amber on, green connected, red recording and disconnect', () {
    expect(SdCmColors.light.amber, const Color(0xFFF59E0B));
    expect(SdCmColors.light.red, const Color(0xFFDC2626));
    expect(SdCmColors.light.green, const Color(0xFF1FC289));
    // the dark skin keeps the app's own neutrals and the same accents
    expect(SdCmColors.dark.amber, SdCmColors.light.amber);
    expect(SdCmColors.dark.red, SdCmColors.light.red);
  });
}

extension on Widget {
  Widget paddingOnlyBottom(double v) => Padding(padding: EdgeInsets.only(bottom: v), child: this);
}
