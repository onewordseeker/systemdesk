import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_banner.dart';
import 'package:flutter_hbb/screens/sd_dashboard.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_peer_pages.dart' show SdTabStrip;
import 'package:flutter_hbb/screens/sd_peers.dart';
import 'package:flutter_hbb/screens/sd_quick.dart';
import 'package:flutter_hbb/screens/sd_settings.dart';
import 'package:flutter_hbb/screens/sd_shell.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:flutter_hbb/screens/sd_window_size.dart';
import 'package:flutter_test/flutter_test.dart';

// The fixes of the 1.5.200 test round, as pictures drawn from the real widgets (PREVIEW_DIR, default build/previews), and the checks that go with them.
final _out = Directory(Platform.environment['PREVIEW_DIR'] ?? 'build/previews');

Future<void> _font(String family, List<(String, int)> files, String dir) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(File('$dir${f.$1}').readAsBytesSync()).buffer)));
  }
  await loader.load();
}

Widget _titleBar() => SdTitleBarBox(child: Row(children: [const SizedBox(width: 78), const Spacer()]));

Widget _header(SdPage page, {String initials = '1'}) => SdHeaderView(
      page: page,
      onPage: (_) {},
      plan: 'Personal Plan',
      initials: initials,
      onPlan: () {},
      onAvatar: () {},
      address: SdAddressBar(controller: TextEditingController(), onLaunch: (_) {}),
      bell: SdRoundButton(dot: false, onTap: () {}, child: SdIcon(SdIcons.bell, size: 19, color: Colors.black)),
    );

/// the tabs and tools of the lists, as the real ones are put together (the real ones read the app's models)
Widget _tabs([int on = 0]) => SdTabStrip(
      tabs: [for (final e in const ['Recent', 'Favorites', 'Discovered', 'Address book', 'Accessible'].asMap().entries) (e.key, e.value)],
      current: on,
      onSelect: (_) async {},
    );
Widget _tools({bool cards = true}) => Row(mainAxisSize: MainAxisSize.min, children: [
      SdToolButton(icon: SdIcons.squareCheck, tooltip: 'Select', onTap: () {}),
      SdToolButton(icon: SdIcons.sort, tooltip: 'Sort by', onTap: () {}),
      const SizedBox(width: 4),
      SdBox(radius: 9, color: const Color(0xFFEFEDE8), padding: const EdgeInsets.all(2), child: Row(mainAxisSize: MainAxisSize.min, children: [
        SdToolButton(icon: SdIcons.grid, tooltip: 'Cards', active: cards, onTap: () {}),
        SdToolButton(icon: SdIcons.list, tooltip: 'List', active: !cards, onTap: () {}),
      ])),
      SdToolButton(icon: SdIcons.sliders, tooltip: 'Tabs', onTap: () {}),
    ]);

Widget _banner() => SdBanner(
      tone: SdBannerTone.warn,
      iconData: Icons.shield_outlined,
      title: 'Keep SystemDesk ready in the background',
      body: 'Installs the background service, so this Mac can be reached after a restart and at the login screen, and a connection stays when this window is closed. macOS asks for your password.',
      actions: [SdBannerAction('Install', () {}, primary: true)],
      onClose: () {},
    );

const _names = ['desktop-9rrsd5s', 'hamids-macbook-pro-air', 'reception', 'dellopt7040', 'e-15-gen2', 'desktop-u82ulbt', 'love-aps', 'mdw-remote', 'samsung-SM-S918B', 'desktop-glg2per', 'hamids-macbook-pro-2', 'dellopt7040-b'];

Widget _dashboard({String id = 'SaqibKhanB', SdServiceStatus service = SdServiceStatus.stopped, int rows = 12}) => SdDashboardView(
      id: id,
      password: '',
      passwordShown: false,
      unattended: true,
      access: 'custom',
      usage: const SdUsage('0 of 500 min', 0),
      service: service,
      onStartService: () {},
      onShare: () {},
      onCopyId: () {},
      onCopyPassword: () {},
      onNewPassword: () {},
      onPasswordSettings: () {},
      onUnattended: (_) {},
      onAccess: (_) {},
      tabs: _tabs(),
      tools: _tools(),
      body: SdPeersLayout(layout: SdPeerLayout.rowsWithMenu, children: [
        for (var i = 0; i < rows; i++)
          SdPeerRow(withMenu: true, data: SdPeerData(id: '${400 + i} 118 ${200 + i * 7}', name: _names[i % _names.length], os: i % 5 == 1 ? SdOs.mac : SdOs.windows, online: i % 3 != 0, user: i % 3 != 0 ? 'Saqib' : ''), onConnect: () {}, onWake: () {}),
      ]),
    );

/// the main window the way the real one is put together: title bar, header, the banners, then the page in the rest of the height
Widget _window(Widget page, {SdPage active = SdPage.dashboard, bool banner = false}) => SdBackdrop(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _titleBar(),
        _header(active),
        if (banner) Padding(padding: const EdgeInsets.fromLTRB(28, 12, 28, 0), child: _banner()),
        Expanded(child: page),
      ]),
    );

Future<void> _show(WidgetTester tester, Widget body, Size size, {bool dark = false}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SdLook.debugEnabled = true;
  debugDisableShadows = false;
  addTearDown(() => debugDisableShadows = true);
  await tester.pumpWidget(RepaintBoundary(
    key: _key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light, fontFamily: 'Inter'),
      darkTheme: ThemeData(brightness: Brightness.dark, fontFamily: 'Inter'),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(body: body),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 400));
}

final _key = GlobalKey();

Future<void> _save(WidgetTester tester, String name) async {
  final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.6));
  final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  _out.createSync(recursive: true);
  File('${_out.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  debugDisableShadows = true;
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

  testWidgets('2: the dashboard has the height of the window, nothing scrolls but the list of computers', (tester) async {
    await _show(tester, _window(_dashboard(), banner: true), const Size(1000, 780));
    expect(tester.takeException(), isNull);
    debugDisableShadows = true;
    // the left panel is in view, the list is in its own scroll area; starting a session is the address bar of the toolbar
    expect(find.text('This computer'), findsOneWidget);
    expect(find.text('Quick Connect'), findsNothing);
    expect(find.text('Enter SystemDesk ID or search computers'), findsOneWidget);
    final scrollables = find.byType(Scrollable);
    final list = tester.state<ScrollableState>(scrollables.last);
    expect(list.position.maxScrollExtent, greaterThan(0), reason: 'twelve computers do not fit: the list scrolls');
    await _save(tester, 'fix-dashboard');
  });

  testWidgets('2: in a window as high as the one in the test pictures (1000 x 913, with the install banner) the whole left panel is in view, service line included', (tester) async {
    await _show(tester, _window(_dashboard(), banner: true), const Size(1000, 913));
    expect(tester.takeException(), isNull);
    final status = tester.getRect(find.text('Service is not running'));
    expect(status.bottom, lessThanOrEqualTo(913 - 28), reason: 'the service line is inside the window without scrolling');
    expect(tester.getRect(find.text('Copy invite message')).bottom, lessThanOrEqualTo(913), reason: 'the whole panel is in view');
    final left = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(left.position.maxScrollExtent, 0, reason: 'nothing to scroll in the left panel');
    await _save(tester, 'fix-dashboard-913');
  });

  testWidgets('2: a low window scrolls the left panel, and the service line stays at its foot', (tester) async {
    await _show(tester, _window(_dashboard(), banner: true), const Size(1000, 560));
    expect(tester.takeException(), isNull);
    await _save(tester, 'fix-dashboard-low');
  });

  testWidgets('3: a long ID is made smaller, never cut', (tester) async {
    await _show(tester, _window(_dashboard(id: 'SaqibKhanBrothersLtd', service: SdServiceStatus.ready, rows: 5)), const Size(1000, 700));
    expect(tester.takeException(), isNull);
    final fit = find.ancestor(of: find.text('SaqibKhanBrothersLtd'), matching: find.byType(FittedBox)).first;
    final box = tester.getRect(fit);
    final text = tester.getRect(find.text('SaqibKhanBrothersLtd'));
    expect(text.right, lessThanOrEqualTo(box.right + 0.5));
    expect(text.width, lessThan(28 * 0.6 * 20), reason: 'it was made smaller than its normal 28 px size');
    await _save(tester, 'fix-long-id');
  });

  testWidgets('3: a 10-digit ID with its spaces fits as well', (tester) async {
    await _show(tester, _window(_dashboard(id: '1 613 887 461', service: SdServiceStatus.ready, rows: 5)), const Size(1000, 700));
    expect(tester.takeException(), isNull);
    final fit = find.ancestor(of: find.text('1 613 887 461'), matching: find.byType(FittedBox)).first;
    final box = tester.getRect(fit);
    final text = tester.getRect(find.text('1 613 887 461'));
    expect(text.right, lessThanOrEqualTo(box.right + 0.5));
    debugDisableShadows = true;
  });

  testWidgets('5: the Launch Session menu opens under its button, inside the window', (tester) async {
    await _show(tester, _window(_dashboard(service: SdServiceStatus.ready, rows: 6)), const Size(1000, 780));
    final chevron = find.byTooltip('Choose how to connect');
    expect(chevron, findsOneWidget);
    final anchor = tester.getRect(chevron);
    await tester.tap(chevron);
    await tester.pump(const Duration(milliseconds: 300));
    final item = tester.getRect(find.text('Remote control'));
    expect(item.left, greaterThan(0), reason: 'the menu is inside the window, not off its left edge');
    final menu = tester.getRect(find.byType(Overlay).last);
    expect(menu.left, greaterThanOrEqualTo(0));
    expect(item.right, lessThanOrEqualTo(anchor.right + 1), reason: 'the menu ends where the button ends');
    expect(item.top, greaterThan(anchor.bottom - 1), reason: 'and starts under it');
    expect(find.text('TCP tunneling'), findsOneWidget);
    await _save(tester, 'fix-launch-menu');
  });

  testWidgets('6: the Theme card: the words on top, the three choices under them', (tester) async {
    final tabs = [
      for (final s in const [
        ('account', 'Account', 'Account'),
        ('general', 'General', 'Application'),
        ('network', 'Network', 'Application'),
        ('safety', 'Security', 'Security'),
        ('display', 'Display', 'Session'),
        ('about', 'About', 'About'),
      ])
        SdSettingsTab(s.$1, s.$2, s.$3)
    ];
    await _show(
        tester,
        _window(
          SdSettingsFrame(
            tabs: tabs,
            selected: 'general',
            onSelect: (_) {},
            title: 'General',
            subtitle: 'How SystemDesk looks and behaves on this computer.',
            child: SingleChildScrollView(
              child: SdSettingsGrid(single: true, children: [
                SdSettingsCard(title: 'Service', rows: [SdActionRow(label: 'Start', onTap: () {})]),
                SdSettingsCard(title: 'Theme', rows: [
                  SdSettingRow(
                    label: 'Appearance',
                    sub: 'Light, dark, or follow macOS.',
                    stacked: true,
                    trailing: SdSeg<String>(items: const [('light', 'Light'), ('dark', 'Dark'), ('system', 'Follow System')], value: 'light', onChanged: (_) {}),
                  ),
                ]),
                SdSettingsCard(title: 'Hardware Codec', rows: [SdToggleRow(label: 'Enable hardware codec', value: true, onChanged: (_) {})]),
                SdSettingsCard(title: 'Language', rows: [SdValueRow(label: 'Language', value: 'Default')]),
              ]),
            ),
          ),
          active: SdPage.settings,
        ),
        const Size(1280, 720));
    expect(tester.takeException(), isNull);
    // the pages are listed under their headings, in the order of the headings
    for (final h in ['ACCOUNT', 'APPLICATION', 'SECURITY', 'SESSION', 'ABOUT']) {
      expect(find.text(h), findsOneWidget);
    }
    expect(tester.getRect(find.text('APPLICATION')).top, lessThan(tester.getRect(find.text('Network')).top));
    expect(tester.getRect(find.text('Network')).top, lessThan(tester.getRect(find.text('SECURITY')).top));
    // the label is on one line, not a column of single letters
    final label = tester.getRect(find.text('Light, dark, or follow macOS.'));
    expect(label.height, lessThan(20), reason: 'the line is one line');
    // one card under the other, in the order: Service, Theme, Hardware Codec, Language
    final tops = [for (final t in ['Service', 'Theme', 'Hardware Codec', 'Language']) tester.getRect(find.text(t).first).top];
    final lefts = [for (final t in ['Service', 'Theme', 'Hardware Codec', 'Language']) tester.getRect(find.text(t).first).left];
    expect(tops, orderedEquals([...tops]..sort()), reason: 'each card is under the one before');
    expect(lefts.every((l) => (l - lefts.first).abs() < 1), isTrue, reason: 'all in one column: nothing left or right of anything');
    await _save(tester, 'fix-theme');
  });

  testWidgets('the ID is called SystemDesk ID', (tester) async {
    await _show(tester, _window(_dashboard(service: SdServiceStatus.ready, rows: 3)), const Size(1000, 700));
    expect(find.text('SystemDesk ID'), findsOneWidget);
    expect(find.text('Local Machine ID:'), findsNothing);
    debugDisableShadows = true;
  });

  test('a shown card wrapped in an Offstage (the hardware codec one) is a card, not an unlock button', () {
    const lock = ValueKey('lock');
    final service = Container(key: const ValueKey('service'));
    final hw = Offstage(offstage: false, child: Container(key: const ValueKey('hw')));
    final gone = Offstage(offstage: true, child: Container(key: const ValueKey('gone')));
    final bareOffstage = const Offstage();
    final unlock = Offstage(key: lock, offstage: false, child: Container(key: const ValueKey('unlock')));
    final hiddenUnlock = Offstage(key: lock, offstage: true, child: Container(key: const ValueKey('hiddenUnlock')));
    final r = sdSplitSettings([unlock, service, hw, gone, bareOffstage, hiddenUnlock], lock);
    expect(r.locks.length, 1);
    expect((r.locks.single as Offstage).child!.key, const ValueKey('unlock'));
    expect(r.cards.map((c) => c.key), [const ValueKey('service'), const ValueKey('hw')], reason: 'in the order given, the card unwrapped, the hidden ones left out');
  });

  testWidgets('the unlock button lines up with the cards under it (left edge, and width where the cards are one column)', (tester) async {
    const cardKey = ValueKey('card');
    Widget lockBar() => SdButton(key: const ValueKey('unlock'), kind: SdBtnKind.gold, block: true, icon: SdIcons.shield, label: 'Unlock network settings', onTap: () {});
    Widget card(int i) => SizedBox(key: i == 0 ? cardKey : ValueKey('card$i'), height: 80, child: const SdSettingsCard(title: 'Network', rows: []));

    Future<void> page(WidgetTester t, {required List<Widget> cards, bool single = false}) async {
      t.view.physicalSize = const Size(1676, 700);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(32), child: SdSettingsPage(locks: [lockBar()], cards: cards, single: single))),
      ));
      await t.pump();
    }

    // Network: one card, in one column of two
    await page(tester, cards: [card(0)]);
    var bar = tester.getRect(find.byKey(const ValueKey('unlock')));
    var first = tester.getRect(find.byKey(cardKey));
    expect(bar.left, first.left, reason: 'the button starts where the card starts');
    expect(bar.width, first.width, reason: 'and is as wide');

    // a page of one column (cards at 760, at the left)
    await page(tester, cards: [card(0), card(1)], single: true);
    bar = tester.getRect(find.byKey(const ValueKey('unlock')));
    first = tester.getRect(find.byKey(cardKey));
    expect(bar.left, first.left);
    expect(bar.width, first.width);

    // several cards in two columns: the button goes over both columns, from the left edge of the first to the right edge of the last
    await page(tester, cards: [card(0), card(1)]);
    bar = tester.getRect(find.byKey(const ValueKey('unlock')));
    first = tester.getRect(find.byKey(cardKey));
    final second = tester.getRect(find.byKey(const ValueKey('card1')));
    expect(bar.left, first.left);
    expect(bar.right, second.right);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the window starts with a size the dashboard fits in: the connect box and the plan are complete, the first tabs are whole and the last one is under More', (tester) async {
    // what the native window opened with (800 x 600) cut them: the sizes the window opens with now are made for the screen, 1366 x 768 laptops included
    final small = sdMainWindowSizeFor(const Size(1366, 728));
    for (final size in [kSdMainWindowSize, small]) {
      await _show(tester, _window(_dashboard(service: SdServiceStatus.ready, rows: 12), banner: true), size);
      expect(tester.takeException(), isNull, reason: '${size.width} x ${size.height}');
      final hint = tester.renderObject<RenderParagraph>(find.text('Enter SystemDesk ID or search computers'));
      expect(hint.didExceedMaxLines, isFalse, reason: 'the whole text of the connect box at ${size.width} x ${size.height}, not "search comput..."');
      expect(find.text('Personal Plan'), findsOneWidget, reason: 'the plan is in the header');
      // 1015 wide is the size the owner chose: three tabs are whole, "Address book" and "Accessible" are one tap away under More (from 1080 wide all five are whole)
      for (final tab in const ['Recent', 'Favorites', 'Discovered']) {
        expect(find.text(tab), findsOneWidget, reason: '$tab is a tab of its own, not folded into More');
      }
      expect(find.text('More'), findsOneWidget);
      for (final name in const ['desktop-9rrsd5s', 'hamids-macbook-pro-air']) {
        expect(find.text(name), findsOneWidget, reason: 'the name of a computer is whole: $name');
      }
    }
    await _show(tester, _window(_dashboard(service: SdServiceStatus.ready, rows: 12), banner: true), kSdMainWindowSize);
    await _save(tester, 'window-default-size');
    // and the old size is the one that cut them
    await _show(tester, _window(_dashboard(service: SdServiceStatus.ready, rows: 12), banner: true), kSdMainWindowOldSize);
    expect(tester.renderObject<RenderParagraph>(find.text('Enter SystemDesk ID or search computers')).didExceedMaxLines, isTrue, reason: 'in 800 x 600 the connect box is cut');
    expect(find.text('Personal Plan'), findsNothing, reason: 'and the plan is gone');
    expect(find.text('More'), findsOneWidget, reason: 'and tabs are folded');
    debugDisableShadows = true;
  });

  testWidgets('the Permissions dropdown opens (it asked for its own width while the menu was being built, which a debug build turns into a red screen)', (tester) async {
    String? chosen;
    await _show(
      tester,
      _window(
        SdDashboardView(
          id: 'SaqibKhanB',
          password: '',
          passwordShown: false,
          unattended: true,
          access: 'custom',
          usage: const SdUsage('0 of 500 min', 0),
          service: SdServiceStatus.ready,
          onStartService: () {},
          onShare: () {},
          onCopyId: () {},
          onCopyPassword: () {},
          onNewPassword: () {},
          onPasswordSettings: () {},
          onUnattended: (_) {},
          onAccess: (v) => chosen = v,
          tabs: _tabs(),
          tools: _tools(),
          body: const SizedBox(),
        ),
      ),
      kSdMainWindowSize,
    );
    await tester.tap(find.text('Custom'));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'opening the menu threw');
    expect(find.text('Full Access'), findsOneWidget);
    expect(find.text('View Only'), findsOneWidget);
    await tester.tap(find.text('View Only'));
    await tester.pump();
    expect(chosen, 'view');
    debugDisableShadows = true;
  });

  test('the size to open with: the default, or what fits on a small screen with room left round it, never below what the screen has', () {
    expect(sdMainWindowSizeFor(const Size(1920, 1040)), kSdMainWindowSize);
    expect(sdMainWindowSizeFor(const Size(2560, 1400)), kSdMainWindowSize);
    expect(sdMainWindowSizeFor(const Size(1440, 800)), const Size(1015, 752));
    expect(sdMainWindowSizeFor(const Size(1366, 728)), const Size(1015, 680));
    expect(sdMainWindowSizeFor(const Size(1024, 700)), const Size(976, 652));
    expect(sdMainWindowSizeFor(const Size(780, 500)), const Size(780, 500), reason: 'a screen smaller than the old size: all of it that is usable');
  });

  test('the window is made as big as the new size once: on the first start, and a window that was saved too small; one that is big enough, maximised, or already looked at stays', () {
    const target = kSdMainWindowSize;
    Size? at({bool done = false, bool saved = true, bool? maximized, bool? fullscreen, double? w, double? h}) =>
        sdWindowSizeAtStart(done: done, saved: saved, maximized: maximized, fullscreen: fullscreen, width: w, height: h, target: target);
    expect(at(saved: false), target, reason: 'first start');
    expect(at(w: 800, h: 600), target, reason: 'what every earlier start saved');
    expect(at(w: 985, h: 653), target, reason: 'a little more than that, as one of the test computers had it: still cuts the dashboard');
    expect(at(w: 1400, h: 700), const Size(1400, 801), reason: 'wide enough, not high enough: only the height grows');
    expect(at(w: 1015, h: 801), isNull);
    expect(at(w: 1014.6, h: 801), isNull, reason: 'a pixel of rounding is no reason to move it');
    expect(at(w: 1600, h: 1000), isNull, reason: 'bigger than needed stays');
    expect(at(w: 800, h: 600, maximized: true), isNull);
    expect(at(w: 800, h: 600, fullscreen: true), isNull);
    expect(at(done: true, w: 800, h: 600), isNull, reason: 'once looked at, the size is the person\'s own for good');
    expect(at(done: true, saved: false), isNull);
    expect(at(), target, reason: 'a saved position without a size');
    // on a small screen the target is what fits: a window that is as big as that is left alone
    final small = sdMainWindowSizeFor(const Size(1366, 728));
    expect(sdWindowSizeAtStart(done: false, saved: true, width: small.width, height: small.height, target: small), isNull);
  });

  testWidgets('1: the window can be dragged by its whole title bar (an empty bar caught nothing before)', (tester) async {
    var dragged = 0;
    // the bar as the real one is put together: a row with the drag area in it, and in the area (on a Mac) only a space for the window buttons
    Widget bar({required bool fixed}) => MaterialApp(
          home: Scaffold(
            body: Column(children: [
              SizedBox(
                height: 40,
                child: Row(children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: fixed ? HitTestBehavior.opaque : null,
                      onPanStart: (_) => dragged++,
                      child: fixed ? SizedBox.expand(child: const Row(children: [SizedBox(width: 78)])) : const Row(children: [SizedBox(width: 78)]),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        );
    Future<void> drag() async {
      final g = await tester.startGesture(const Offset(400, 20));
      await g.moveBy(const Offset(40, 10), timeStamp: const Duration(milliseconds: 20));
      await g.moveBy(const Offset(40, 10), timeStamp: const Duration(milliseconds: 40));
      await g.up();
    }

    await tester.pumpWidget(bar(fixed: false));
    await drag();
    expect(dragged, 0, reason: 'what the new look had: nothing in the bar to hit, no drag');
    await tester.pumpWidget(bar(fixed: true));
    await drag();
    expect(dragged, 1, reason: 'with the whole bar catching the drag');
  });

  testWidgets('1: the window of a remote session can be dragged by the empty part of its bar, and a tab does not drag it', (tester) async {
    var dragged = 0;
    // the bar of a session the way the real one is put together (tabbar_widget.dart): the drag area is the whole bar, and in it the tabs only as wide as they
    // are (a list that wraps its content), each with a handler that takes the drag for itself, and the button of a new connection after them
    Widget bar({required bool fixed}) => MaterialApp(
          home: Scaffold(
            body: Column(children: [
              SizedBox(
                height: 40,
                child: Row(children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: fixed ? HitTestBehavior.opaque : null,
                      onPanStart: (_) => dragged++,
                      child: Row(children: [
                        const SizedBox(width: 78),
                        Expanded(
                          child: Listener(
                            child: Row(children: [
                              Flexible(
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  shrinkWrap: true,
                                  children: [for (var i = 0; i < 2; i++) GestureDetector(onPanStart: (_) {}, child: Container(width: 150, height: 28, color: Colors.amber))],
                                ),
                              ),
                              const SizedBox(width: 30, height: 28),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 138),
                ]),
              ),
            ]),
          ),
        );
    Future<void> drag(Offset from) async {
      final g = await tester.startGesture(from);
      await g.moveBy(const Offset(40, 10), timeStamp: const Duration(milliseconds: 20));
      await g.moveBy(const Offset(40, 10), timeStamp: const Duration(milliseconds: 40));
      await g.up();
    }

    // x 78..378 are the two tabs; the empty part is after them
    await tester.pumpWidget(bar(fixed: false));
    await drag(const Offset(500, 20));
    expect(dragged, 0, reason: 'what the new look had: the empty part of the bar caught nothing, so the window could not be moved');
    await tester.pumpWidget(bar(fixed: true));
    await drag(const Offset(500, 20));
    expect(dragged, 1, reason: 'the empty part of the bar drags the window');
    await drag(const Offset(40, 20));
    expect(dragged, 2, reason: 'the part before the tabs too');
    await drag(const Offset(150, 20));
    expect(dragged, 2, reason: 'a tab does not drag the window (a tab is for clicking, and for reordering later)');
  });
}
