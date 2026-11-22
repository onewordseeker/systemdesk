import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_window_menu.dart';
import 'package:flutter_test/flutter_test.dart';

/// A part of a window that takes the keyboard for itself (the screen of another computer).
class _Keeper extends StatelessWidget {
  const _Keeper();
  @override
  Widget build(BuildContext context) => Focus(autofocus: true, onKeyEvent: (node, event) => KeyEventResult.handled, child: const SizedBox(width: 50, height: 50));
}

void main() {
  final asked = <(int?, int?)>[];

  setUp(() {
    asked.clear();
    SdWindowMenu.debugOpen = (x, y) async => asked.add((x, y));
  });
  tearDown(() => SdWindowMenu.debugOpen = null);

  Future<void> altSpace(WidgetTester tester, {bool ctrl = false, bool shift = false}) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    if (ctrl) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (ctrl) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
  }

  testWidgets('a click on the icon opens the menu under the icon, in the pixels of the window', (tester) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(1600, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Align(alignment: Alignment.topLeft, child: Padding(padding: EdgeInsets.only(left: 20, top: 5), child: SdWindowMenuIcon(child: SizedBox(width: 30, height: 24))))),
    ));
    await tester.tap(find.byKey(const ValueKey('sd-window-menu-icon')));
    await tester.pump();
    // left edge 20 and bottom 29 logical pixels, at a pixel ratio of 2
    expect(asked, [(40, 58)]);
  });

  testWidgets('without the runner\'s menu (not Windows) the icon and the bar are plain', (tester) async {
    SdWindowMenu.debugOpen = null;
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Column(children: [SdWindowMenuIcon(child: SizedBox(width: 30, height: 24)), Expanded(child: SdWindowMenuRegion(child: SizedBox.expand()))]))));
    expect(find.byKey(const ValueKey('sd-window-menu-icon')), findsNothing);
    expect(find.byKey(const ValueKey('sd-window-menu-region')), findsNothing);
    await altSpace(tester);
    expect(asked, isEmpty);
  });

  group('a right click on the bar', () {
    testWidgets('opens the menu at the pointer, a left click does not', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SdWindowMenuRegion(child: SizedBox.expand()))));
      await tester.tap(find.byKey(const ValueKey('sd-window-menu-region')));
      await tester.pump();
      expect(asked, isEmpty);
      await tester.tap(find.byKey(const ValueKey('sd-window-menu-region')), buttons: kSecondaryButton);
      await tester.pump();
      expect(asked, [(null, null)]);
    });

    testWidgets('works on the empty part of a bar whose own children take no part in it', (tester) async {
      // like the bar of the old look: a drag area with a row of things in it, and nothing under most of the bar
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SdWindowMenuRegion(
            child: GestureDetector(onPanStart: (_) {}, child: const Row(children: [SizedBox(width: 40, height: 30), Spacer()])),
          ),
        ),
      ));
      await tester.tapAt(const Offset(400, 15), buttons: kSecondaryButton);
      await tester.pump();
      expect(asked, [(null, null)]);
    });

    testWidgets('what has a right click of its own (a tab) keeps it', (tester) async {
      var tab = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SdWindowMenuRegion(
            child: Row(children: [
              GestureDetector(key: const ValueKey('tab'), behavior: HitTestBehavior.opaque, onSecondaryTap: () => tab++, child: const SizedBox(width: 80, height: 30)),
              const Spacer(),
            ]),
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('tab')), buttons: kSecondaryButton);
      await tester.pump();
      expect(tab, 1);
      expect(asked, isEmpty);
    });
  });

  group('Alt+Space', () {
    testWidgets('opens the menu under the icon, whatever has the focus', (tester) async {
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SdWindowMenuKeys(child: const Center(child: TextField(autofocus: true))))));
      await tester.pump();
      await altSpace(tester);
      expect(asked, [((SdWindowMenu.keyboardAnchor.dx * 1.5).round(), (SdWindowMenu.keyboardAnchor.dy * 1.5).round())]);
    });

    testWidgets('also when nothing has the focus', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SdWindowMenuKeys(child: SizedBox.expand()))));
      await altSpace(tester);
      expect(asked.length, 1);
    });

    testWidgets('Space alone, or with other keys, is left alone', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SdWindowMenuKeys(child: SizedBox.expand()))));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await altSpace(tester, ctrl: true);
      await altSpace(tester, shift: true);
      expect(asked, isEmpty);
    });

    testWidgets('a part of the window that sends its keys elsewhere keeps Alt+Space', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SdWindowMenuKeys(keepsKeys: (focused) => focused.findAncestorWidgetOfExactType<_Keeper>() != null, child: const _Keeper())),
      ));
      await tester.pump();
      await altSpace(tester);
      expect(asked, isEmpty);
    });

    testWidgets('where the window has the title bar of the system, the system opens its own menu and this does not', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SdWindowMenuKeys(enabled: false, child: SizedBox.expand()))));
      await altSpace(tester);
      expect(asked, isEmpty);
    });

    testWidgets('two of them in one window open the menu once', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SdWindowMenuKeys(child: SdWindowMenuKeys(child: SizedBox.expand())))));
      await altSpace(tester);
      expect(asked.length, 1);
    });

    testWidgets('when the window is gone the key is no longer taken', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SdWindowMenuKeys(child: SizedBox.expand()))));
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox.expand())));
      await altSpace(tester);
      expect(asked, isEmpty);
    });
  });
}
