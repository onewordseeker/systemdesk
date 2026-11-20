import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_dashboard.dart';
import 'package:flutter_hbb/screens/sd_devices.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_offline_dialog.dart';
import 'package:flutter_hbb/screens/sd_peer_pages.dart' show SdTabStrip;
import 'package:flutter_hbb/screens/sd_peers.dart';
import 'package:flutter_hbb/screens/sd_quick.dart';
import 'package:flutter_hbb/screens/sd_sessions.dart';
import 'package:flutter_hbb/screens/sd_shell.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:flutter_hbb/screens/sd_unattended_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

// The round of 2026-11-20 (evening): a restored window that keeps the look of a maximised one, a way back from Devices and Sessions, the ID panel and the
// profile on every page, the offline box and the unattended password. Pictures drawn from the real widgets (PREVIEW_DIR, default build/previews/r3).
final _out = Directory(Platform.environment['PREVIEW_DIR'] ?? 'build/previews/r3');

Future<void> _font(String family, List<(String, int)> files, String dir) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(File('$dir${f.$1}').readAsBytesSync()).buffer)));
  }
  await loader.load();
}

const _profile = SdProfile(name: 'Hamid Raza', sub: 'Free Plan · onewordseeker', initials: 'HR');

SdPage? _wentTo;

Widget _header(SdPage page, {double? width}) => SdHeaderView(
      page: page,
      onPage: (p) => _wentTo = p,
      plan: 'Free Plan',
      initials: 'HR',
      onPlan: () {},
      onAvatar: () {},
      address: SdAddressBar(controller: TextEditingController(), onLaunch: (_) {}),
      bell: SdRoundButton(dot: false, onTap: () {}, child: SdIcon(SdIcons.bell, size: 19, color: Colors.black)),
    );

const _shortTabs = ['Recent', 'Favorites', 'Discovered', 'Address book', 'Accessible'];
const _longTabs = ['Recent sessions', 'Favorites', 'Discovered', 'Address book', 'Accessible devices'];

Widget _tabs({bool short = true, int on = 0}) => SdTabStrip(
      tabs: [for (final e in (short ? _shortTabs : _longTabs).asMap().entries) (e.key, e.value)],
      current: on,
      onSelect: (_) async {},
    );

Widget _tools({bool view = true}) => Row(mainAxisSize: MainAxisSize.min, children: [
      SdToolButton(icon: SdIcons.squareCheck, tooltip: 'Select', onTap: () {}),
      SdToolButton(icon: SdIcons.sort, tooltip: 'Sort by', onTap: () {}),
      if (view) ...[
        SdToolButton(icon: SdIcons.grid, tooltip: 'Cards', active: true, onTap: () {}),
        SdToolButton(icon: SdIcons.list, tooltip: 'List', onTap: () {}),
      ],
      SdToolButton(icon: SdIcons.sliders, tooltip: 'Tabs', onTap: () {}),
    ]);

const _names = ['desktop-9rrsd5s', 'hamids-macbook-pro-air', 'reception', 'dellopt7040', 'e-15-gen2', 'desktop-u82ulbt', 'love-aps', 'mdw-remote'];

Widget _cards() => SdPeersLayout(layout: SdPeerLayout.grid, children: [
      for (var i = 0; i < 8; i++)
        SdPeerCard(
            data: SdPeerData(id: '${400 + i} 118 ${200 + i * 7}', name: _names[i], os: i % 3 == 1 ? SdOs.mac : SdOs.windows, online: i % 3 != 0, user: i % 3 != 0 ? 'Saqib' : ''),
            onConnect: () {},
            onWake: () {}),
    ]);

SdAsideView _aside({bool stacked = false, bool scroll = false, bool unattended = true, SdProfile? profile = _profile, ImageProvider? image}) => SdAsideView(
      id: '408 241 669',
      password: '3bfmii',
      unattended: unattended,
      onUnattended: (_) {},
      onUnattendedPassword: () {},
      unattendedNote: 'Password of Hamid Raza',
      access: 'custom',
      usage: const SdUsage('0 of 500 min', 0),
      service: SdServiceStatus.ready,
      onShare: () {},
      profile: profile == null ? null : SdProfile(name: profile.name, sub: profile.sub, initials: profile.initials, image: image),
      onProfile: () {},
      onSignIn: () {},
      stacked: stacked,
      scroll: scroll,
    );

Widget _dashboard({bool unattended = true, ImageProvider? image}) => SdDashboardView(
      aside: ({required bool stacked, required bool scroll}) => _aside(stacked: stacked, scroll: scroll, unattended: unattended, image: image),
      tabs: _tabs(),
      tools: _tools(),
      body: _cards(),
    );

Widget _devices() => SdDevicesView(
      summary: '7 computers · 1 online',
      tabs: _tabs(short: false),
      query: TextEditingController(),
      filter: 'all',
      onFilter: (_) {},
      grid: true,
      onGrid: (_) {},
      tools: _tools(view: false),
      body: _cards(),
    );

Widget _sessions() => SdSessionsView(
      big: '42',
      small: 'of 500 min today',
      fraction: 0.08,
      facts: const [('Sessions today', '3'), ('Longest', '18 min'), ('This week', '2 h 10 min')],
      days: const [SdDayBar('Mon', 40), SdDayBar('Tue', 75), SdDayBar('Wed', 20), SdDayBar('Thu', 90), SdDayBar('Fri', 55), SdDayBar('Sat', 10), SdDayBar('Sun', 42, today: true)],
      live: const [SdLiveRow(name: 'reception', sub: 'You are controlling it', incoming: false, time: '12 min', button: 'End')],
      history: const [
        SdHistoryRow(name: 'desktop-9rrsd5s', id: '400 118 200', incoming: false, when: 'Today, 09:14', duration: '18 min', kind: 'Remote control'),
        SdHistoryRow(name: 'hamids-macbook-pro-air', id: '401 118 207', incoming: true, when: 'Yesterday', duration: '6 min', kind: 'File transfer'),
      ],
      filter: 'all',
      onFilter: (_) {},
    );

/// the page the way [SdHomePages] puts it together: the ID panel at the left on every page, the page at the right (or the panel folded above it)
Widget _home(SdPage page, Widget content, {ImageProvider? image}) => LayoutBuilder(builder: (context, c) {
      final two = c.maxWidth >= kSdDashboardSplit;
      if (page == SdPage.dashboard) return two ? content : SingleChildScrollView(child: content);
      if (two) {
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: sdAsideWidthFor(c.maxWidth), child: _aside(scroll: true, image: image)),
          Expanded(child: SingleChildScrollView(child: content)),
        ]);
      }
      return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_aside(stacked: true), content]));
    });

Widget _window(SdPage page, Widget content, {ImageProvider? image}) => SdBackdrop(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SdTitleBarBox(child: const SizedBox()),
        _header(page),
        Expanded(child: _home(page, content, image: image)),
      ]),
    );

final _key = GlobalKey();

Future<void> _show(WidgetTester tester, Widget body, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SdLook.debugEnabled = true;
  await tester.pumpWidget(RepaintBoundary(
    key: _key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light, fontFamily: 'Inter'),
      home: Scaffold(body: body),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _save(WidgetTester tester, String name, {double ratio = 1.0}) async {
  // painted once more with the shadows on (the tests run with them off)
  debugDisableShadows = false;
  final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  boundary.markNeedsPaint();
  await tester.pump();
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: ratio));
  debugDisableShadows = true;
  final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  _out.createSync(recursive: true);
  File('${_out.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
}

/// a small drawn portrait, so the preview can show a profile that has a photo
Future<ImageProvider> _photo(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(const Rect.fromLTWH(0, 0, 96, 96), Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(96, 96), const [Color(0xFF5B7FA6), Color(0xFFE8B06A)]));
    c.drawCircle(const Offset(48, 38), 17, Paint()..color = const Color(0xFFF1D9C0));
    c.drawOval(const Rect.fromLTWH(18, 62, 60, 50), Paint()..color = const Color(0xFFF1D9C0));
    final img = await rec.endRecording().toImage(96, 96);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final provider = MemoryImage(bytes!.buffer.asUint8List());
    return provider;
  }))!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/dev/flutter';
    await _font('Roboto', [('roboto-regular.ttf', 400), ('roboto-medium.ttf', 500), ('roboto-bold.ttf', 700)], '$root/bin/cache/artifacts/material_fonts/');
    await _font('MaterialIcons', [('materialicons-regular.otf', 400)], '$root/bin/cache/artifacts/material_fonts/');
    await _font('Inter', [('Inter-Regular.ttf', 400), ('Inter-Medium.ttf', 500), ('Inter-SemiBold.ttf', 600), ('Inter-Bold.ttf', 700)], 'assets/fonts/');
  });
  tearDown(() => SdLook.debugEnabled = null);

  // ------------------------------------------------------------------ 1: a restored window looks like a maximised one

  testWidgets('1: the dashboard at every width keeps the same two columns (panel at the left, the computers at the right)', (tester) async {
    for (final s in const [Size(1920, 1000), Size(1280, 760), Size(1100, 720), Size(900, 640), Size(791, 595), Size(660, 600)]) {
      await _show(tester, _window(SdPage.dashboard, _dashboard()), s);
      expect(tester.takeException(), isNull, reason: 'no overflow at ${s.width.toInt()}');
      final panel = tester.getRect(find.text('This computer'));
      final tab = tester.getRect(find.text('Recent'));
      expect(tab.left, greaterThan(panel.right), reason: 'the lists are beside the panel, not under it, at ${s.width.toInt()}');
      expect(tab.top, closeTo(tester.getRect(find.byTooltip('Select')).center.dy - 22 + 12, 40), reason: 'the tabs and their tools are on one line');
      await _save(tester, 'dashboard-${s.width.toInt()}');
    }
  });

  testWidgets('1: the cards have as many columns as fit: three, two, one', (tester) async {
    int columns(WidgetTester t) {
      final lefts = <int>{};
      for (final e in t.widgetList<SdPeerCard>(find.byType(SdPeerCard))) {
        lefts.add(t.getRect(find.byWidget(e)).left.round());
      }
      return lefts.length;
    }

    await _show(tester, _window(SdPage.dashboard, _dashboard()), const Size(1920, 1000));
    expect(columns(tester), 3);
    await _show(tester, _window(SdPage.dashboard, _dashboard()), const Size(1100, 720));
    expect(columns(tester), 2);
    await _show(tester, _window(SdPage.dashboard, _dashboard()), const Size(791, 595));
    expect(columns(tester), 1);
  });

  testWidgets('1: tabs that do not fit give way to a More tab; the open tab stays in view', (tester) async {
    await _show(tester, Scaffold(body: Center(child: SizedBox(width: 330, child: _tabs(on: 3)))), const Size(500, 200));
    expect(tester.takeException(), isNull);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Address book'), findsOneWidget, reason: 'the open list is one of the tabs shown');
    await tester.tap(find.text('More'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Accessible'), findsOneWidget, reason: 'what did not fit is in the menu');
    await _show(tester, Scaffold(body: Center(child: SizedBox(width: 600, child: _tabs()))), const Size(700, 200));
    expect(find.text('More'), findsNothing, reason: 'all five fit: no More tab');
  });

  testWidgets('1: a narrow window folds the panel above the lists to the ID and the state; it opens on a tap', (tester) async {
    await _show(tester, _window(SdPage.dashboard, _dashboard()), const Size(560, 760));
    expect(tester.takeException(), isNull);
    expect(find.text('408 241 669'), findsOneWidget);
    expect(find.text('One-time password'), findsNothing, reason: 'folded');
    await _save(tester, 'dashboard-560-folded');
    await tester.tap(find.text('This computer'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('One-time password'), findsOneWidget);
    await _save(tester, 'dashboard-560-open');
  });

  // ------------------------------------------------------------------ 2: back from Devices and Sessions

  testWidgets('2: Devices and Sessions have a back arrow in the toolbar: one click to the Dashboard', (tester) async {
    for (final p in [SdPage.devices, SdPage.sessions]) {
      _wentTo = null;
      await _show(tester, _window(p, p == SdPage.devices ? _devices() : _sessions()), const Size(1280, 800));
      expect(tester.takeException(), isNull);
      final back = find.byTooltip('Back to Dashboard');
      expect(back, findsOneWidget);
      await tester.tap(back);
      expect(_wentTo, SdPage.dashboard);
      await _save(tester, p == SdPage.devices ? 'devices-1280' : 'sessions-1280');
    }
    await _show(tester, _window(SdPage.dashboard, _dashboard()), const Size(1280, 800));
    expect(find.byTooltip('Back to Dashboard'), findsNothing, reason: 'the Dashboard is where it goes back to');
  });

  // ------------------------------------------------------------------ 4: the ID panel and the profile on every page

  testWidgets('4: Devices and Sessions keep the SystemDesk ID panel, with who is signed in', (tester) async {
    for (final p in [SdPage.devices, SdPage.sessions]) {
      await _show(tester, _window(p, p == SdPage.devices ? _devices() : _sessions()), const Size(1280, 800));
      expect(find.text('408 241 669'), findsOneWidget);
      expect(find.text('Hamid Raza'), findsOneWidget);
      expect(find.text('Free Plan · onewordseeker'), findsOneWidget);
    }
    await _show(tester, _window(SdPage.devices, _devices()), const Size(791, 595));
    expect(tester.takeException(), isNull);
    await _save(tester, 'devices-791');
  });

  testWidgets('4: the profile shows a photo when there is one, initials when not, and a sign-in when nobody is signed in', (tester) async {
    final photo = await _photo(tester);
    await _show(tester, _window(SdPage.dashboard, _dashboard(image: photo), image: photo), const Size(1280, 800));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    await _save(tester, 'dashboard-photo');
    await _show(
        tester,
        SdBackdrop(
            child: Row(children: [
          SizedBox(width: 330, child: _aside(profile: null)),
        ])),
        const Size(330, 700));
    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    await _save(tester, 'aside-signed-out');
  });

  // ------------------------------------------------------------------ 3: the offline box

  testWidgets('3: the offline box says what the person asked for, with Power on, Retry and Cancel', (tester) async {
    var powered = 0, retried = 0, cancelled = 0;
    await _show(
        tester,
        Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: Colors.black),
          SdOfflineDialog(peerId: '459 591', onPowerOn: () => powered++, onRetry: () => retried++, onCancel: () => cancelled++),
        ]),
        const Size(1100, 700));
    expect(tester.takeException(), isNull);
    expect(find.text('SystemDesk Offline'), findsOneWidget);
    expect(find.text('This desk is not available'), findsOneWidget);
    expect(find.text('Please make sure that SystemDesk is running on the remote device and it is connected to the internet.'), findsOneWidget);
    await _save(tester, 'offline');
    final p = tester.getRect(find.text('Power on')).left, r = tester.getRect(find.text('Retry')).left, c = tester.getRect(find.text('Cancel')).left;
    debugPrint('OFFLINE lefts: power $p retry $r cancel $c');
    expect(p, lessThan(r));
    expect(r, lessThan(c));
    await tester.tap(find.text('Power on'));
    await tester.tap(find.text('Retry'));
    await tester.tap(find.text('Cancel'));
    expect([powered, retried, cancelled], [1, 1, 1]);
  });

  // ------------------------------------------------------------------ 5: the unattended password

  testWidgets('5: switching Unattended Access on asks for a password of the profile; it needs the rules and the same twice', (tester) async {
    String? saved;
    await _show(
        tester,
        Stack(fit: StackFit.expand, children: [
          _window(SdPage.dashboard, _dashboard(unattended: false)),
          SdUnattendedPasswordDialog(profile: _profile, onCancel: () {}, onSubmit: (p) async => (saved = p) == null ? 'x' : null),
        ]),
        const Size(1280, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('Create an unattended password'), findsOneWidget);
    expect(find.text('Hamid Raza'), findsWidgets);
    SdButton turnOn() => tester.widget<SdButton>(find.widgetWithText(SdButton, 'Turn on unattended access'));
    // the two fields of the dialog (the window behind it has a field of its own)
    final fields = find.descendant(of: find.byType(SdUnattendedPasswordDialog), matching: find.byType(TextField));
    expect(turnOn().onTap, isNull, reason: 'nothing typed yet');
    await _save(tester, 'unattended-empty');
    await tester.enterText(fields.first, 'weak');
    await tester.enterText(fields.last, 'weak');
    await tester.pump();
    expect(turnOn().onTap, isNull, reason: 'the same twice, but the rules are not met');
    await tester.enterText(fields.first, 'Orchard2026x');
    await tester.enterText(fields.last, 'Orchard2026y');
    await tester.pump();
    expect(find.text('The confirmation is not identical.'), findsOneWidget);
    expect(turnOn().onTap, isNull);
    await tester.enterText(fields.last, 'Orchard2026x');
    await tester.pump();
    expect(turnOn().onTap, isNotNull);
    await _save(tester, 'unattended-filled');
    await tester.tap(find.text('Turn on unattended access'));
    await tester.pump();
    expect(saved, 'Orchard2026x');
  });

  testWidgets('5: unattended on shows whose password it is, with a way to change it', (tester) async {
    await _show(tester, _window(SdPage.dashboard, _dashboard()), const Size(1280, 800));
    expect(find.text('Password of Hamid Raza'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    await _show(tester, _window(SdPage.dashboard, _dashboard(unattended: false)), const Size(1280, 800));
    expect(find.text('Password of Hamid Raza'), findsNothing, reason: 'off: nothing to show');
  });
}
