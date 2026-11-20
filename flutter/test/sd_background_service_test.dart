import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_background_service.dart';
import 'package:flutter_hbb/screens/sd_dashboard.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_test/flutter_test.dart';

// The background service of a Mac is an option, not a step: SystemDesk works while its window is open. One message about the service, never two.
final _out = Directory(Platform.environment['PREVIEW_DIR'] ?? 'build/previews/r4');
final _key = GlobalKey();

Future<void> _font(String family, List<String> files, String dir) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(File('$dir$f').readAsBytesSync()).buffer)));
  }
  await loader.load();
}

Widget _panel({required SdServiceStatus service, VoidCallback? onBackground, bool stacked = false}) => SdAsideView(
      id: 'SaqibKhanBaloch',
      password: '',
      passwordShown: false,
      unattended: false,
      onUnattended: (_) {},
      access: 'custom',
      service: service,
      onStartService: () {},
      onBackgroundService: onBackground,
      onShare: () {},
      onSignIn: () {},
      stacked: stacked,
    );

Future<void> _show(WidgetTester tester, Widget panel) async {
  tester.view.physicalSize = const Size(900, 760);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SdLook.debugEnabled = true;
  await tester.pumpWidget(RepaintBoundary(
    key: _key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light, fontFamily: 'Inter'),
      home: Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: kSdAsideWidth, child: panel))),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _save(WidgetTester tester, String name) async {
  debugDisableShadows = false;
  final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  boundary.markNeedsPaint();
  await tester.pump();
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
  debugDisableShadows = true;
  final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  _out.createSync(recursive: true);
  File('${_out.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/dev/flutter';
    await _font('Roboto', ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf'], '$root/bin/cache/artifacts/material_fonts/');
    await _font('MaterialIcons', ['materialicons-regular.otf'], '$root/bin/cache/artifacts/material_fonts/');
    await _font('Inter', ['Inter-Regular.ttf', 'Inter-Medium.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf'], 'assets/fonts/');
  });
  tearDown(() => SdLook.debugEnabled = null);

  group('what is offered', () {
    test('an installed background service is never offered again', () {
      for (final stopped in [false, true]) {
        for (final aside in [false, true]) {
          expect(sdBackgroundOffer(daemonInstalled: true, serviceStopped: stopped, putAside: aside), SdBackgroundOffer.none);
        }
      }
    });

    test('while the app\'s own service is stopped, the panel\'s "Start service" is the only message', () {
      expect(sdBackgroundOffer(daemonInstalled: false, serviceStopped: true, putAside: false), SdBackgroundOffer.none);
      expect(sdBackgroundOffer(daemonInstalled: false, serviceStopped: true, putAside: true), SdBackgroundOffer.none);
    });

    test('a Mac that works is offered the banner first, then only the small link once the person said "Not now"', () {
      expect(sdBackgroundOffer(daemonInstalled: false, serviceStopped: false, putAside: false), SdBackgroundOffer.banner);
      expect(sdBackgroundOffer(daemonInstalled: false, serviceStopped: false, putAside: true), SdBackgroundOffer.link);
    });
  });

  group('the panel', () {
    testWidgets('a stopped service shows "Start service" and no background link', (tester) async {
      var started = 0;
      await _show(
          tester,
          SdAsideView(
            id: 'SaqibKhanBaloch',
            password: '',
            passwordShown: false,
            unattended: false,
            access: 'custom',
            service: SdServiceStatus.stopped,
            onStartService: () => started++,
            onBackgroundService: () {},
            onSignIn: () {},
          ));
      expect(find.text('Service is not running'), findsOneWidget);
      expect(find.text('Keep running in the background'), findsNothing, reason: 'one message while the service is stopped');
      await tester.tap(find.text('Start service'));
      expect(started, 1);
      await _save(tester, 'panel-stopped');
    });

    testWidgets('a working service with the banner put aside keeps one small link', (tester) async {
      var turnedOn = 0;
      await _show(tester, _panel(service: SdServiceStatus.ready, onBackground: () => turnedOn++));
      expect(find.text('Ready (Encrypted)'), findsOneWidget);
      expect(find.text('Service is not running'), findsNothing);
      expect(find.text('Keep running in the background'), findsOneWidget);
      await tester.tap(find.text('Keep running in the background'));
      expect(turnedOn, 1);
      expect(tester.takeException(), isNull);
      await _save(tester, 'panel-link');
    });

    testWidgets('no link when nothing is offered (an installed service, another system)', (tester) async {
      await _show(tester, _panel(service: SdServiceStatus.ready));
      expect(find.text('Keep running in the background'), findsNothing);
    });

    testWidgets('the folded panel of a narrow window shows it too without overflowing', (tester) async {
      await _show(tester, _panel(service: SdServiceStatus.ready, onBackground: () {}, stacked: true));
      expect(find.text('Keep running in the background'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
