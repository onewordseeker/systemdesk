import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_dashboard.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_peers.dart';
import 'package:flutter_hbb/screens/sd_quick.dart';
import 'package:flutter_hbb/screens/sd_shell.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:flutter_test/flutter_test.dart';

// PICTURES of the screens of the app design, drawn from the real widgets with the design's sample data, to be laid over the design's own pictures.
// PREVIEW_DIR (default: build/previews) is where they go.
final _out = Directory(Platform.environment['PREVIEW_DIR'] ?? 'build/previews');

Future<void> _font(String family, List<(String, int)> files, String dir) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(File('$dir${f.$1}').readAsBytesSync()).buffer)));
  }
  await loader.load();
}

/// the title bar of the main window, as the real one is put together
Widget sdTitleBar() => SdTitleBarBox(
      child: Row(children: [
        const SdTitleBrand(),
        const Spacer(),
        SdWinButton(glyph: SdGlyphs.minimise, onTap: () {}),
        SdWinButton(glyph: SdGlyphs.maximise, onTap: () {}),
        SdWinButton(glyph: SdGlyphs.close, isClose: true, onTap: () {}),
      ]),
    );

Widget sdHeader(SdPage page) => SdHeaderView(
      page: page,
      onPage: (_) {},
      plan: 'Free Plan',
      initials: 'AM',
      onPlan: () {},
      onAvatar: () {},
      address: SdAddressBar(controller: TextEditingController(), onLaunch: (_) {}),
      bell: SdRoundButton(dot: true, onTap: () {}, child: SdIcon(SdIcons.bell, size: 19, color: Colors.black)),
    );

const _rows = [
  ('MARKETING-DELL', '408 118 204', SdOs.windows, true, '14ms'),
  ('RECEPTION-HP', '408 118 377', SdOs.windows, true, '22ms'),
  ('STUDIO-UBUNTU', '512 440 096', SdOs.linux, true, '31ms'),
  ('Hamid’s MacBook Pro', '730 205 941', SdOs.mac, true, '18ms'),
  ('ACCOUNTS-LENOVO', '408 118 552', SdOs.windows, false, ''),
  ('DESIGN-IMAC', '730 205 118', SdOs.mac, true, '16ms'),
  ('DEV-LINUX', '512 440 723', SdOs.linux, true, '27ms'),
  ('WAREHOUSE-PC', '408 118 690', SdOs.windows, true, '41ms'),
];

Widget sdDashboardScene() {
  return SdDashboardView(
    id: '408 241 669',
    password: 'pumd4e',
    unattended: true,
    access: 'full',
    usage: const SdUsage('18 of 60 min', 0.30),
    service: SdServiceStatus.ready,
    onShare: () {},
    onCopyId: () {},
    onCopyPassword: () {},
    onNewPassword: () {},
    onPasswordSettings: () {},
    onUnattended: (_) {},
    tabs: SizedBox(
      height: 44,
      child: Row(children: [for (final e in const ['Recent', 'Favorites', 'Discovered', 'Address book', 'Accessible'].asMap().entries) SdTextTab(label: e.value, selected: e.key == 0)]),
    ),
    tools: Row(mainAxisSize: MainAxisSize.min, children: [
      SdToolButton(icon: SdIcons.squareCheck, tooltip: 'Select', onTap: () {}),
      SdToolButton(icon: SdIcons.sort, tooltip: 'Sort by', onTap: () {}),
      SdToolButton(icon: SdIcons.grid, active: true, onTap: () {}),
      SdToolButton(icon: SdIcons.list, onTap: () {}),
      SdToolButton(icon: SdIcons.sliders, tooltip: 'Tabs', onTap: () {}),
    ]),
    body: SdPeersLayout(layout: SdPeerLayout.grid, children: [
      for (final r in _rows) SdPeerCard(data: SdPeerData(id: r.$2, name: r.$1, os: r.$3, online: r.$4, user: r.$5), onConnect: () {}, onWake: () {}),
    ]),
  );
}

Widget _page(Widget body) => SdBackdrop(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        sdTitleBar(),
        sdHeader(SdPage.dashboard),
        Expanded(child: body),
      ]),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/dev/flutter';
    await _font('Roboto', [('roboto-regular.ttf', 400), ('roboto-medium.ttf', 500), ('roboto-bold.ttf', 700)], '$root/bin/cache/artifacts/material_fonts/');
    await _font('MaterialIcons', [('materialicons-regular.otf', 400)], '$root/bin/cache/artifacts/material_fonts/');
    await _font('Inter', [('Inter-Regular.ttf', 400), ('Inter-Medium.ttf', 500), ('Inter-SemiBold.ttf', 600), ('Inter-Bold.ttf', 700)], 'assets/fonts/');
  });
  tearDown(() => SdLook.debugEnabled = null);

  final scenes = <(String, Size, Widget Function())>[
    ('dashboard', const Size(1280, 896), sdDashboardScene),
  ];
  for (final dark in [false, true]) {
    for (final s in scenes) {
      testWidgets('picture ${s.$1} ${dark ? 'dark' : 'light'}', (tester) async {
        tester.view.physicalSize = s.$2;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        SdLook.debugEnabled = true;
        debugDisableShadows = false;
        addTearDown(() => debugDisableShadows = true);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(brightness: Brightness.light, fontFamily: 'Inter'),
            darkTheme: ThemeData(brightness: Brightness.dark, fontFamily: 'Inter'),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: Scaffold(body: Builder(builder: (c) => _page(s.$3()))),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 400));
        final err = tester.takeException();
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
        final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
        _out.createSync(recursive: true);
        File('${_out.path}/${s.$1}-${dark ? 'dark' : 'light'}.png').writeAsBytesSync(data!.buffer.asUint8List());
        debugDisableShadows = true;
        expect(err, isNull);
      });
    }
  }
}
