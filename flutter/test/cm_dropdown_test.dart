import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

// The list that opens from the arrow of the tab bar when several people control one computer (the connection manager window). Its rows
// used to turn the whole popup into one flat grey box: a row holds a reactive widget that only read its hover state when the tab has a close
// button, and the controllers' tabs have none, so GetX threw and a release build paints that as grey.
void main() {
  Widget bar(DesktopTabController controller, RxList<String> keys) => MaterialApp(
        theme: MyTheme.lightTheme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: WindowActionPanel(
              isMainWindow: false,
              state: controller.state,
              tabController: controller,
              invisibleTabKeys: keys,
              showMinimize: false,
              showMaximize: false,
              showClose: false,
            ),
          ),
        ),
      );

  TabInfo tab(String key, {VoidCallback? onClose}) => TabInfo(
        key: key,
        label: 'Controller $key',
        selectedIcon: Icons.person,
        unselectedIcon: Icons.person_outline,
        closable: onClose != null,
        onTabCloseButton: onClose,
        page: const SizedBox(),
      );

  for (final withClose in [false, true]) {
    testWidgets('the controller list opens and lists every controller (${withClose ? 'tabs with a close button' : 'tabs without one, like the connection manager'})',
        (tester) async {
      tester.view.physicalSize = const Size(300, 490);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final controller = DesktopTabController(tabType: DesktopTabType.cm);
      for (final k in ['1', '2', '3']) {
        controller.add(tab(k, onClose: withClose ? () {} : null));
      }
      await tester.pumpWidget(bar(controller, RxList<String>(['1', '2', '3'])));
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'a row of the list threw while it was built');
      for (final k in ['1', '2', '3']) {
        expect(find.text('$k. Controller $k'), findsOneWidget);
      }
      // hovering a row does not throw either
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('2. Controller 2')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      // the popup is a small menu, not a window-filling surface
      final size = tester.getSize(find.byType(Material).last);
      expect(size.height, lessThan(300), reason: 'three rows of 32 px and some padding');
    });
  }
}
