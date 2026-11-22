import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_host_title.dart';
import 'package:flutter_hbb/screens/sd_shell.dart';
import 'package:flutter_hbb/screens/sd_window_shape.dart';
import 'package:flutter_test/flutter_test.dart';

// The corners of the host window are round: the runner cuts them off the shape of the window (Windows), the content is clipped to the same corners and a
// hairline follows them. The title of the window says what it is for.

Future<void> _font(String family, List<String> files, String dir) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(File('$dir$f').readAsBytesSync()).buffer)));
  }
  await loader.load();
}

Widget _app(Widget child, {Brightness brightness = Brightness.light}) => MaterialApp(
      theme: ThemeData(fontFamily: 'Inter', brightness: brightness),
      home: Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: 300, height: 200, child: child))),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => _font('Inter', ['Inter-Regular.ttf', 'Inter-Medium.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf'], 'assets/fonts/'));
  tearDown(() => SdWindowShape.debugRound = null);

  test('the corners are 14 pixels round', () {
    expect(kSdWindowRadius, 14);
  });

  group('asking the runner to round the window', () {
    test('sends the radius', () async {
      final seen = <double>[];
      SdWindowShape.debugRound = seen.add;
      await SdWindowShape.round(kSdWindowRadius);
      expect(seen, [14]);
      expect(SdWindowShape.available, isTrue);
    });

    test('a runner that does not know the call leaves the window as it was and raises nothing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('systemdesk/window_menu'), (call) async {
        throw MissingPluginException();
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('systemdesk/window_menu'), null));
      await SdWindowShape.round(14);
    });
  });

  group('the frame', () {
    testWidgets('clips the content to the corners and draws a rounded hairline over it', (tester) async {
      await tester.pumpWidget(_app(const SdRoundedFrame(child: ColoredBox(color: Colors.white, child: SizedBox.expand()))));
      final clip = tester.widget<ClipRRect>(find.descendant(of: find.byKey(const ValueKey('sd-rounded-frame')), matching: find.byType(ClipRRect)));
      expect(clip.borderRadius, BorderRadius.circular(kSdWindowRadius));
      expect(clip.clipBehavior, Clip.antiAlias, reason: 'smooth edges');
      final frame = tester.widget<Container>(find.byKey(const ValueKey('sd-rounded-frame')));
      final border = frame.foregroundDecoration! as BoxDecoration;
      expect(border.borderRadius, BorderRadius.circular(kSdWindowRadius));
      expect(border.border, isNotNull);
    });

    testWidgets('does not change the size of what is inside', (tester) async {
      await tester.pumpWidget(_app(const SdRoundedFrame(child: SizedBox.expand(key: ValueKey('inside')))));
      expect(tester.getSize(find.byKey(const ValueKey('inside'))), const Size(300, 200));
    });

    testWidgets('a pixel in the corner is cut away, a pixel in the middle is kept', (tester) async {
      await tester.pumpWidget(_app(const SdRoundedFrame(child: ColoredBox(key: ValueKey('fill'), color: Colors.red, child: SizedBox.expand()))));
      final clip = tester.renderObject<RenderClipRRect>(find.descendant(of: find.byKey(const ValueKey('sd-rounded-frame')), matching: find.byType(ClipRRect)));
      final rrect = (clip.borderRadius as BorderRadius).toRRect(const Rect.fromLTWH(0, 0, 300, 200));
      expect(rrect.contains(const Offset(1, 1)), isFalse, reason: 'the very corner is outside the rounded shape');
      expect(rrect.contains(const Offset(150, 100)), isTrue);
      expect(rrect.contains(const Offset(14, 1)), isTrue, reason: 'the straight edge starts one radius from the corner');
    });

    for (final brightness in Brightness.values) {
      testWidgets('draws in ${brightness.name} mode', (tester) async {
        await tester.pumpWidget(_app(const SdRoundedFrame(child: Center(child: Text('x'))), brightness: brightness));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the title', () {
    test('says what the window is for', () {
      expect(sdHostTitle(connected: false), 'Incoming Connection Request');
      expect(sdHostTitle(connected: true), 'Active Session');
    });

    testWidgets('the brand shows the words it is given, and "SystemDesk" when it is given none', (tester) async {
      await tester.pumpWidget(_app(const Column(children: [SdTitleBrand(strong: true, title: 'Active Session'), SdTitleBrand()])));
      expect(find.text('Active Session'), findsOneWidget);
      expect(find.text('SystemDesk'), findsOneWidget);
    });
  });

  group('where it is used', () {
    final server = File('lib/desktop/pages/server_page.dart').readAsStringSync();
    final tabbar = File('lib/desktop/widgets/tabbar_widget.dart').readAsStringSync();
    final runner = File('windows/runner/flutter_window.cpp').readAsStringSync();

    test('the host window asks for the round corners and draws the frame (Windows only: a Mac window is round already)', () {
      expect(server.contains('SdWindowShape.round(kSdWindowRadius)'), isTrue);
      expect(server.contains('if (SdLook.enabled && isWindows) return SdRoundedFrame(child: body);'), isTrue);
    });

    test('the title bar of the host window shows the title that follows the request', () {
      expect(tabbar.contains('const SdHostTitleBrand()'), isTrue);
    });

    test('the runner takes the call, and makes the shape again when the window changes size or screen', () {
      expect(runner.contains('"setWindowRound"'), isTrue);
      expect(runner.contains('case WM_SIZE:'), isTrue);
      expect(runner.contains('case WM_DPICHANGED:'), isTrue);
      expect(runner.contains('Win32Desktop::ReapplyWindowRound(hwnd);'), isTrue);
    });
  });
}
