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
import 'package:flutter_hbb/screens/sd_peers.dart';
import 'package:flutter_hbb/screens/sd_settings.dart';
import 'package:flutter_hbb/screens/sd_shell.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
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
      bell: SdRoundButton(dot: false, onTap: () {}, child: SdIcon(SdIcons.bell, size: 19, color: Colors.black)),
    );

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
      query: TextEditingController(),
      onLaunch: (_) {},
      permOpen: false,
      tabs: SdSeg<int>(items: const [(0, 'Recent'), (1, 'Favorites'), (2, 'Discovered'), (3, 'Address book'), (4, 'Accessible')], value: 0, onChanged: (_) {}),
      body: SdPeersLayout(layout: SdPeerLayout.rows, children: [
        for (var i = 0; i < rows; i++)
          SdPeerRow(data: SdPeerData(id: '${400 + i} 118 ${200 + i * 7}', name: _names[i % _names.length], os: i % 5 == 1 ? SdOs.mac : SdOs.windows, online: false, user: ''), onConnect: () {}, onWake: () {}),
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
    // the left panel and Quick Connect are all in view, the list is in its own scroll area
    expect(find.text('Local Machine'), findsOneWidget);
    expect(find.text('Quick Connect'), findsOneWidget);
    final scrollables = find.byType(Scrollable);
    final list = tester.state<ScrollableState>(scrollables.last);
    expect(list.position.maxScrollExtent, greaterThan(0), reason: 'twelve computers do not fit: the list scrolls');
    await _save(tester, 'fix-dashboard');
  });

  testWidgets('2: in a window as high as the one in the test pictures (1000 x 913, with the install banner) the whole left panel is in view, service line included', (tester) async {
    await _show(tester, _window(_dashboard(), banner: true), const Size(1000, 913));
    expect(tester.takeException(), isNull);
    final status = tester.getRect(find.text('Service Status:'));
    expect(status.bottom, lessThanOrEqualTo(913 - 28), reason: 'the service line is inside the window without scrolling');
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
    expect(text.width, lessThan(31 * 0.6 * 20), reason: 'it was made smaller than its normal 31 px size');
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
    final tabs = [for (final s in const [('general', 'General'), ('safety', 'Security'), ('network', 'Network'), ('display', 'Display'), ('account', 'Account'), ('about', 'About')]) SdSettingsTab(s.$1, s.$2)];
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
    expect(find.text('SystemDesk ID:'), findsOneWidget);
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
}
