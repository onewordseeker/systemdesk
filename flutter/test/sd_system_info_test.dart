import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_system_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => SdLook.debugEnabled = null);

  test('the rows come in a fixed order and what was not sent is left out', () {
    final rows = sdSystemInfoRows({
      'memory': '15.9GB',
      'hostname': 'DESKTOP-1',
      'os': 'Windows 10',
      'cpu': '',
      'username': 'ali',
      'unknown_key': 'x',
    });
    expect(rows.map((r) => r.$1), ['Computer name', 'Signed-in user', 'System', 'Memory']);
    expect(rows.first.$2, 'DESKTOP-1');
  });

  test('nothing usable gives no rows', () {
    expect(sdSystemInfoRows(null), isEmpty);
    expect(sdSystemInfoRows('text'), isEmpty);
    expect(sdSystemInfoRows(<String, dynamic>{}), isEmpty);
  });

  testWidgets('the dialog shows the rows and closes', (tester) async {
    SdLook.debugEnabled = true;
    var closed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 520, child: SdSystemInfoView(rows: const [('Computer name', 'DESKTOP-1'), ('Memory', '15.9GB')], onClose: () => closed++)),
        ),
      ),
    ));
    expect(find.text('System information'), findsOneWidget);
    expect(find.text('DESKTOP-1'), findsOneWidget);
    await tester.tap(find.text('Close'));
    expect(closed, 1);
  });

  testWidgets('an empty list says so', (tester) async {
    SdLook.debugEnabled = true;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 520, child: SdSystemInfoView(rows: const [], onClose: () {})))),
    ));
    expect(find.text('This computer did not send its system information.'), findsOneWidget);
  });
}
