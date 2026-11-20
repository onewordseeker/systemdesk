import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_cm_window.dart';
import 'package:flutter_hbb/screens/sd_host_in_use.dart';
import 'package:flutter_test/flutter_test.dart';

// The host window in the new look: which window a set of connections asks for, a card that never overflows ("bottom overflowed by 1 pixel"), and the notice
// the controller sees while the person at the controlled computer uses the mouse.
Future<void> _show(WidgetTester tester, Widget child, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: size.width, height: size.height, child: child))));
  await tester.pump();
}

Widget _block(double h, Key key) => SizedBox(key: key, height: h, child: const ColoredBox(color: Colors.amber));

void main() {
  tearDown(() => sdCmCompact = false);

  group('which window', () {
    test('a request (a connection not accepted yet) is the big card in the middle of the screen', () {
      expect(sdCmShouldBeCompact([false]), isFalse);
      expect(sdCmShouldBeCompact([true, false]), isFalse, reason: 'one still asks: the request comes first');
      sdCmCompact = false;
      expect(sdCmAlignment, Alignment.center);
      expect(sdCmSize(chatOpen: false), kSdCmRequestSize);
    });

    test('once every connection is accepted it is the small window at the bottom right', () {
      expect(sdCmShouldBeCompact([true]), isTrue);
      expect(sdCmShouldBeCompact([true, true]), isTrue);
      sdCmCompact = true;
      expect(sdCmAlignment, Alignment.bottomRight);
      expect(sdCmSize(chatOpen: false), kSdCmCompactSize);
      expect(sdCmSize(chatOpen: true), kSdCmCompactChatSize);
    });

    test('no connection: nothing asks for the small window', () {
      expect(sdCmShouldBeCompact(const []), isFalse);
    });

    test('the small window is smaller than the card, and its chat opens as wide again', () {
      expect(kSdCmCompactSize.width, lessThan(kSdCmRequestSize.width));
      expect(kSdCmCompactSize.height, lessThan(kSdCmRequestSize.height));
      expect(kSdCmCompactChatSize.width, kSdCmCompactSize.width * 2, reason: 'the chat page is as wide as the window; the layout splits them evenly');
    });
  });

  group('the card never overflows', () {
    testWidgets('with room to spare the buttons sit at the bottom', (tester) async {
      await _show(tester, SdPinnedBottomScroll(top: _block(100, const Key('top')), bottom: _block(50, const Key('bottom'))), const Size(400, 300));
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byKey(const Key('top'))).top, 0);
      expect(tester.getRect(find.byKey(const Key('bottom'))).bottom, 300, reason: 'pinned to the bottom');
    });

    testWidgets('one pixel too much scrolls instead of showing the overflow stripe', (tester) async {
      await _show(tester, SdPinnedBottomScroll(top: _block(250, const Key('top')), bottom: _block(51, const Key('bottom'))), const Size(400, 300));
      expect(tester.takeException(), isNull, reason: 'no "bottom overflowed by 1.00 pixels"');
      expect(tester.getRect(find.byKey(const Key('top'))).top, 0);
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -40));
      await tester.pump();
      expect(tester.getRect(find.byKey(const Key('bottom'))).bottom, 300, reason: 'scrolled to the end, the last button is fully there');
    });

    testWidgets('far too much content scrolls too', (tester) async {
      await _show(tester, SdPinnedBottomScroll(top: _block(700, const Key('top')), bottom: _block(120, const Key('bottom'))), const Size(400, 300));
      expect(tester.takeException(), isNull);
    });
  });

  group('input not allowed', () {
    testWidgets('the notice says what is going on while the person at the computer uses the mouse', (tester) async {
      await _show(tester, Center(child: sdHostInUseNotice(true, tr: (s) => s)), const Size(600, 200));
      expect(find.text('Input not allowed: the person at this computer is using the mouse'), findsOneWidget);
    });

    testWidgets('and is gone when they stop', (tester) async {
      await _show(tester, Center(child: sdHostInUseNotice(false, tr: (s) => s)), const Size(600, 200));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Input not allowed'), findsNothing);
    });
  });
}
