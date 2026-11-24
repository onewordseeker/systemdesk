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

  group('the window is as high as its content', () {
    // a window of 490 with a 40 pixel title bar gives its card 450
    double? fit({double window = 490, double room = 450, required double need, double min = 490, double max = 900}) =>
        sdCmFitHeight(windowHeight: window, room: room, need: need, minHeight: min, maxHeight: max);

    test('what fits already leaves the window as it is', () {
      expect(fit(need: 450), isNull);
      expect(fit(need: 300), isNull, reason: 'never lower than the size it is made at');
    });

    test('more content makes it higher by exactly as much', () {
      expect(fit(need: 500), 540);
      expect(fit(need: 500.4), 541, reason: 'whole pixels, rounded up so the last button is never cut');
    });

    test('less content brings it back to the size it is made at, not below', () {
      expect(fit(window: 540, room: 500, need: 450), 490);
      expect(fit(window: 540, room: 500, need: 200), 490);
    });

    test('never higher than the screen has room for: the card scrolls instead', () {
      expect(fit(need: 2000, max: 800), 800);
      expect(fit(need: 2000, max: 400), isNull, reason: 'a screen lower than the window: the window keeps its size');
    });

    test('asking again for what it has now changes nothing (no endless resizing)', () {
      final first = fit(need: 520.3)!;
      // the window is first high, the card was given as much more room
      expect(fit(window: first, room: 450 + (first - 490), need: 520.3), isNull);
    });

    testWidgets('the card tells how much room its parts need and how much it was given', (tester) async {
      final seen = <(double, double)>[];
      await _show(tester, SdPinnedBottomScroll(top: _block(250, const Key('top')), bottom: _block(51, const Key('bottom')), onNeed: (n, r) => seen.add((n, r))), const Size(400, 300));
      await tester.pump();
      expect(seen, isNotEmpty);
      expect(seen.last, (301.0, 300.0));
    });

    testWidgets('and tells again when what it shows grows', (tester) async {
      final top = ValueNotifier<double>(100);
      final seen = <(double, double)>[];
      await _show(
          tester,
          ValueListenableBuilder<double>(
            valueListenable: top,
            builder: (_, h, __) => SdPinnedBottomScroll(top: _block(h, const Key('top')), bottom: _block(50, const Key('bottom')), onNeed: (n, r) => seen.add((n, r))),
          ),
          const Size(400, 300));
      await tester.pump();
      expect(seen.last.$1, 150);
      top.value = 260;
      await tester.pump();
      await tester.pump();
      expect(seen.last.$1, 310);
    });

    testWidgets('with no listener nothing is reported and the card is as before', (tester) async {
      await _show(tester, SdPinnedBottomScroll(top: _block(100, const Key('top')), bottom: _block(50, const Key('bottom'))), const Size(400, 300));
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byKey(const Key('bottom'))).bottom, 300);
    });

    testWidgets('once the window has grown to what is asked, nothing scrolls and the last button is in view', (tester) async {
      Widget card(void Function(double, double)? onNeed) => SdPinnedBottomScroll(top: _block(280, const Key('top')), bottom: _block(120, const Key('bottom')), onNeed: onNeed);
      double? need, room;
      await _show(tester, card((n, r) {
        need = n;
        room = r;
      }), const Size(400, 350));
      await tester.pump();
      final target = sdCmFitHeight(windowHeight: 390, room: room!, need: need!, minHeight: 390, maxHeight: 900)!;
      // the window is the target high (the title bar takes 40 of it)
      await _show(tester, card(null), Size(400, target - 40));
      expect(tester.state<ScrollableState>(find.byType(Scrollable)).position.maxScrollExtent, 0);
      expect(tester.getRect(find.byKey(const Key('bottom'))).bottom, target - 40);
    });
  });

  group('one pointer while paused', () {
    test('our own pointer is hidden while the host has the mouse, so only their arrow is on the picture', () {
      expect(sdHidePointerWhilePaused(hostInUse: true, keyboard: true), isTrue);
    });

    test('nothing is hidden when they are not using it', () {
      expect(sdHidePointerWhilePaused(hostInUse: false, keyboard: true), isFalse);
    });

    test('a view-only session keeps its "not allowed" sign: it is never allowed, whoever is at the computer', () {
      expect(sdHidePointerWhilePaused(hostInUse: true, keyboard: false), isFalse);
      expect(sdHidePointerWhilePaused(hostInUse: false, keyboard: false), isFalse);
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
