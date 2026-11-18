import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_session_chips.dart';
import 'package:flutter_hbb/screens/sd_shell.dart';
import 'package:flutter_hbb/screens/sd_toolbar.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:flutter_test/flutter_test.dart';

// The picture of a remote session (the bar above it, the toolbar, the two chips) drawn from the real widgets with the design's sample data, to be laid over the
// design's own picture (dshots/session.png). PREVIEW_DIR (default: build/previews) is where it goes.
final _out = Directory(Platform.environment['PREVIEW_DIR'] ?? 'build/previews');

Future<void> _font(String family, List<(String, int)> files, String dir) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(File('$dir${f.$1}').readAsBytesSync()).buffer)));
  }
  await loader.load();
}

Widget _icon(String label) => SizedBox(
      width: 64,
      child: Column(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0x47FFFFFF), borderRadius: BorderRadius.circular(9))),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4, fontFamily: 'Inter')),
      ]),
    );

Widget _win(double l, double t, double w, double h, List<double> bars, Color head) => Positioned(
      left: l,
      top: t,
      width: w,
      height: h,
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 40, spreadRadius: -14, offset: Offset(0, 20))]),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 26, color: head),
          for (final b in bars)
            Container(height: 8, margin: const EdgeInsets.fromLTRB(16, 12, 16, 0), width: (w - 32) * b, decoration: BoxDecoration(color: const Color(0xFFD5DAE3), borderRadius: BorderRadius.circular(4))),
        ]),
      ),
    );

Widget _btn(String icon, {bool on = false, double iconSize = 19}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: SdToolFace(icon: icon, on: on),
    );

Widget _tabs() => SdRemoteBar(
      child: Row(children: [
        const SizedBox(width: 5),
        const SdTabGrid(),
        const SizedBox(width: 10),
        SdRemoteTab(
          selected: true,
          closable: true,
          onTap: () {},
          onClose: () {},
          child: sdRemoteTabContent(tabKey: 'a', label: const Text('MARKETING-DELL'), unread: const SizedBox.shrink(), tooltip: ''),
        ),
        SdRemoteTab(selected: false, closable: true, onTap: () {}, onClose: () {}, child: const Text('RECEPTION-HP')),
        SdTabAdd(onTap: () {}),
        const Spacer(),
        SdWinButton(glyph: SdGlyphs.minimise, onTap: () {}),
        SdWinButton(glyph: SdGlyphs.maximise, onTap: () {}),
        SdWinButton(glyph: SdGlyphs.close, isClose: true, onTap: () {}),
      ]),
    );

Widget _scene() => Column(children: [
      _tabs(),
      Expanded(
        child: Stack(children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1F4E8C), Color(0xFF3F83C6), Color(0xFF8FC1E8)], stops: [0, 0.48, 1])),
            ),
          ),
          Positioned(left: 28, top: 90, child: Column(children: [_icon('This PC'), const SizedBox(height: 22), _icon('Invoices'), const SizedBox(height: 22), _icon('Recycle Bin')])),
          _win(150, 120, 560, 340, const [1, 0.7, 0.84, 0.52, 0.76, 0.4], const Color(0xFFE3E7EE)),
          _win(520, 230, 520, 300, const [1, 0.64, 0.8, 0.48], const Color(0xFFD9E4F7)),
          Positioned(left: 0, right: 0, bottom: 0, height: 44, child: Container(color: const Color(0xD1121826))),
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: SdToolbarFrame(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 4),
                  _btn(SdIcons.monitor),
                  _btn(SdIcons.mouse, on: true),
                  _btn(SdIcons.keyboard),
                  _btn(SdIcons.clipboard),
                  _btn(SdIcons.folder),
                  const SdToolSep(),
                  _btn(SdIcons.speaker, on: true),
                  _btn(SdIcons.mic),
                  _btn(SdIcons.record),
                  const SdToolSep(),
                  _btn(SdIcons.sliders, on: true),
                  _btn(SdIcons.lock),
                  const SdToolSep(),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2), child: SdToolFace(icon: SdIcons.power, label: 'End')),
                  const SizedBox(width: 4),
                ]),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 60,
            child: SdChip(children: [
              const SdIcon(SdIcons.clock, size: 15, color: SdToolbar.gold, stroke: 2),
              const Text('Time left today'),
              const Text('42 min', style: TextStyle(fontWeight: FontWeight.w600, fontFeatures: SdSkin.figures)),
            ]),
          ),
          Positioned(
            right: 16,
            bottom: 60,
            child: SdChip(children: [
              Container(width: 9, height: 9, decoration: const BoxDecoration(shape: BoxShape.circle, color: SdRemoteTabs.led)),
              const Text('Direct ·'),
              const Text('14 ms', style: TextStyle(fontFeatures: SdSkin.figures)),
              const Text('· Encrypted'),
            ]),
          ),
        ]),
      ),
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/dev/flutter';
    await _font('Roboto', [('roboto-regular.ttf', 400), ('roboto-medium.ttf', 500), ('roboto-bold.ttf', 700)], '$root/bin/cache/artifacts/material_fonts/');
    await _font('MaterialIcons', [('materialicons-regular.otf', 400)], '$root/bin/cache/artifacts/material_fonts/');
    await _font('Inter', [('Inter-Regular.ttf', 400), ('Inter-Medium.ttf', 500), ('Inter-SemiBold.ttf', 600), ('Inter-Bold.ttf', 700)], 'assets/fonts/');
  });
  tearDown(() => SdLook.debugEnabled = null);

  testWidgets('picture session', (tester) async {
    tester.view.physicalSize = const Size(1280, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SdLook.debugEnabled = true;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    SdTabClock.debugSince('a', DateTime.now().subtract(const Duration(minutes: 12, seconds: 48)));
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.light, fontFamily: 'Inter'),
        home: Scaffold(backgroundColor: const Color(0xFF10141B), body: _scene()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    final err = tester.takeException();
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
    final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
    _out.createSync(recursive: true);
    File('${_out.path}/session.png').writeAsBytesSync(data!.buffer.asUint8List());
    debugDisableShadows = true;
    expect(err, isNull);
  });
}
