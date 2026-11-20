import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_session_card.dart';
import 'package:flutter_test/flutter_test.dart';

final _out = Directory(Platform.environment['PREVIEW_DIR'] ?? 'build/previews');

Future<void> _font(String family, List<(String, int)> files, String dir) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(File('$dir${f.$1}').readAsBytesSync()).buffer)));
  }
  await loader.load();
}

const _fp = 'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899';

SdSessionFacts _facts({bool? secure = true, bool? direct = true}) => SdSessionFacts(
      secure: secure,
      direct: direct,
      delay: '18',
      fps: '30',
      speed: '1.2MB/s',
      codec: 'H264',
      encryption: 'TLS_AES_256_GCM_SHA384 TLSv1.3',
      fingerprint: _fp,
      name: 'MARKETING-DELL',
      id: '408118204',
      user: 'saqib',
      platform: 'Windows',
      version: '1.5.22',
      displays: 2,
      permissions: const [('Keyboard and mouse', true), ('Clipboard', true), ('Sound', false), ('File transfer', true)],
    );

final _key = GlobalKey();

Future<void> _show(WidgetTester tester, Widget card) async {
  tester.view.physicalSize = const Size(520, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(
    key: _key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Inter'),
      home: Scaffold(backgroundColor: const Color(0xFF3A3A3A), body: Center(child: card)),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _save(WidgetTester tester, String name) async {
  final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.6));
  final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  _out.createSync(recursive: true);
  File('${_out.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/dev/flutter';
    await _font('Roboto', [('roboto-regular.ttf', 400), ('roboto-medium.ttf', 500), ('roboto-bold.ttf', 700)], '$root/bin/cache/artifacts/material_fonts/');
    await _font('Inter', [('Inter-Regular.ttf', 400), ('Inter-Medium.ttf', 500), ('Inter-SemiBold.ttf', 600), ('Inter-Bold.ttf', 700)], 'assets/fonts/');
  });

  testWidgets('the verdict comes first, then the route and the delay', (tester) async {
    await _show(tester, SdSessionCard(facts: _facts()));
    expect(tester.takeException(), isNull);
    expect(find.text('Secure connection'), findsOneWidget);
    expect(find.text('Direct connection'), findsOneWidget);
    expect(find.text('18 ms'), findsWidgets);
    await _save(tester, 'session-card');
  });

  testWidgets('a relay and a missing encryption are said plainly', (tester) async {
    await _show(tester, SdSessionCard(facts: _facts(secure: false, direct: false)));
    expect(find.text('Not encrypted'), findsWidgets);
    expect(find.text('Through a relay'), findsOneWidget);
    await _show(tester, SdSessionCard(facts: _facts(secure: null, direct: null)));
    expect(find.text('Connecting...'), findsWidgets);
  });

  testWidgets('the three tabs: what you may do and the device', (tester) async {
    await _show(tester, SdSessionCard(facts: _facts()));
    await tester.tap(find.text('What you may do'));
    await tester.pump();
    expect(find.text('Keyboard and mouse'), findsOneWidget);
    expect(find.text('Not allowed'), findsOneWidget, reason: 'sound is the one that is off');
    await _save(tester, 'session-card-permissions');
    await tester.tap(find.text('Device'));
    await tester.pump();
    expect(find.text('MARKETING-DELL'), findsOneWidget);
    expect(find.text('saqib'), findsOneWidget);
    await _save(tester, 'session-card-device');
  });

  testWidgets('technical details are folded away, and the fingerprint is grouped by four when opened', (tester) async {
    String? copied;
    await _show(tester, SdSessionCard(facts: _facts(), onCopyFingerprint: (v) => copied = v));
    expect(find.text('Frame rate'), findsNothing);
    await tester.tap(find.text('Technical details'));
    await tester.pump();
    expect(find.text('Frame rate'), findsOneWidget);
    expect(find.text('TLS_AES_256_GCM_SHA384 TLSv1.3'), findsOneWidget);
    expect(find.textContaining('aabb ccdd eeff 0011'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    expect(copied, _fp, reason: 'the whole fingerprint is copied, not the grouped text');
    await _save(tester, 'session-card-technical');
  });
}
