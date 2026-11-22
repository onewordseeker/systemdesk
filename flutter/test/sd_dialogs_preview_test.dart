import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_connect_dialog.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_modal.dart';
import 'package:flutter_hbb/screens/sd_session_picker.dart';
import 'package:flutter_hbb/screens/sd_signin_modal.dart';
import 'package:flutter_hbb/screens/sd_system_info.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:flutter_hbb/screens/sd_update_card.dart';
import 'package:flutter_test/flutter_test.dart';

// PICTURES of the dialogs of the app design (sign in, required update), drawn from the real widgets, to be laid over the design's own pictures.
final _out = Directory(Platform.environment['PREVIEW_DIR'] ?? 'build/previews');

Future<void> _font(String family, List<(String, int)> files, String dir) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(File('$dir${f.$1}').readAsBytesSync()).buffer)));
  }
  await loader.load();
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

  final scenes = <(String, Widget Function())>[
    ('signin', () {
      final u = TextEditingController(text: 'alex@studio-morgan.com');
      final p = TextEditingController(text: 'correct horse');
      return SdModal(maxWidth: 440, content: SdSignInForm(user: u, password: p, onSubmit: () {}, onGuest: () {}, onCreate: () {}));
    }),
    ('connecting', () => SdModal(
          maxWidth: 480,
          content: SdConnectView(
            target: 'MARKETING-DELL',
            sub: sdConnectSub('408118204'),
            stage: SdConnectStage.waiting,
            reachedIn: '0.4 s',
            secure: true,
            direct: true,
            secondsLeft: 98,
            onCancel: () {},
          ),
        )),
    ('connecting-first', () => SdModal(
          maxWidth: 480,
          content: SdConnectView(target: 'MARKETING-DELL', sub: sdConnectSub('408118204'), stage: SdConnectStage.reaching, onCancel: () {}),
        )),
    ('connecting-step2', () => SdModal(
          maxWidth: 480,
          content: SdConnectView(
            target: 'MARKETING-DELL',
            sub: sdConnectSub('408118204'),
            stage: SdConnectStage.waiting,
            shown: SdShownStep.securing,
            reachedIn: '0.4 s',
            secure: true,
            direct: true,
            secondsLeft: 100,
            onCancel: () {},
          ),
        )),
    ('sessions', () => SdModal(
          maxWidth: 480,
          content: SdSessionPickerView(
            sessions: [SdWindowsSession.parse('2', 'Console: Ahmed'), SdWindowsSession.parse('3', 'RDP: Admin')],
            selected: '2',
            onSelect: (_) {},
            onConnect: () {},
            onCancel: () {},
          ),
        )),
    ('sessions-three', () => SdModal(
          maxWidth: 480,
          content: SdSessionPickerView(
            sessions: [SdWindowsSession.parse('2', 'Console'), SdWindowsSession.parse('3', 'RDP: Sara'), SdWindowsSession.parse('4', 'RDP: Admin (running)')],
            selected: '3',
            onSelect: (_) {},
            onConnect: () {},
            onCancel: () {},
          ),
        )),
    ('system-info', () => SdModal(
          maxWidth: 520,
          content: SdSystemInfoView(
            rows: sdSystemInfoRows({
              'hostname': 'MARKETING-DELL',
              'username': 'ali',
              'os': 'windows / Microsoft Windows 10 Pro - 10.0.19045',
              'arch': 'x86_64',
              'cpu': 'AMD Ryzen 5 5500, 3.6GHz, 12/6 cores',
              'memory': '15.93GB',
              'memory_free': '9.4GB',
              'app_version': '1.5.208',
            }),
            onClose: () {},
          ),
        )),
    ('update', () => Center(
          child: SdUpdateCard(
            version: '1.5.23',
            message: 'Quieter reconnects when the other computer changes its Windows session\nA clearer message when a connection is not accepted in time\nSmoother windows and panels',
            onUpdate: () {},
          ),
        )),
  ];
  for (final s in scenes) {
    testWidgets('picture ${s.$1}', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
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
          home: Scaffold(body: SdBackdrop(child: s.$2())),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      final err = tester.takeException();
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
      final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      _out.createSync(recursive: true);
      File('${_out.path}/${s.$1}.png').writeAsBytesSync(data!.buffer.asUint8List());
      debugDisableShadows = true;
      expect(err, isNull);
    });
  }
}
