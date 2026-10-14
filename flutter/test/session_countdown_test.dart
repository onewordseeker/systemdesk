import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/session_countdown.dart';
import 'package:flutter_hbb/services/license_service.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(SessionCountdown c) => MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          Positioned(top: 10, left: 10, child: SessionCountdownCapsule(c)),
        ]),
      ),
    );

void main() {
  test('parses the server answer, ignores anything else', () {
    final d = SessionCountdownData.fromJson(
        {'seconds': 312, 'reason': 'daily', 'warn_minutes': 5});
    expect(d!.seconds, 312);
    expect(d.warnMinutes, 5);
    expect(d.reason, 'daily');
    expect(SessionCountdownData.fromJson(null), isNull);
    expect(SessionCountdownData.fromJson({'seconds': 5}), isNull);
    expect(SessionCountdownData.fromJson('x'), isNull);
  });

  testWidgets('hidden outside the warning window, shown inside, red in the last minute',
      (tester) async {
    final c = SessionCountdown();
    await tester.pumpWidget(host(c));
    expect(find.textContaining('Session closes in'), findsNothing);

    // 10 min left, warn at 5: still hidden
    c.update(const SessionCountdownData(600, 5, 'session'));
    await tester.pump();
    expect(c.visible, isFalse);
    expect(find.textContaining('Session closes in'), findsNothing);

    // 4:30 left: shown, amber
    c.update(const SessionCountdownData(270, 5, 'session'));
    await tester.pump();
    expect(c.visible, isTrue);
    expect(find.text('Session closes in 04:30'), findsOneWidget);
    Container pill() => tester.widget<Container>(find
        .descendant(
            of: find.byType(SessionCountdownCapsule),
            matching: find.byType(Container))
        .first);
    expect((pill().decoration as BoxDecoration).color, const Color(0xFFFFB224));

    // 45 s left: red
    c.update(const SessionCountdownData(45, 5, 'session'));
    await tester.pump();
    expect(find.text('Session closes in 00:45'), findsOneWidget);
    expect((pill().decoration as BoxDecoration).color, const Color(0xFFE5484D));

    // no limit / switched off: gone
    c.update(null);
    await tester.pump();
    expect(c.visible, isFalse);
    expect(find.textContaining('Session closes in'), findsNothing);
    c.update(const SessionCountdownData(30, 0, 'session'));
    await tester.pump();
    expect(c.visible, isFalse);

    c.stop();
  });

  testWidgets('the capsule lets taps through to the remote screen', (tester) async {
    final c = SessionCountdown();
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand()),
          Positioned(top: 10, left: 10, child: SessionCountdownCapsule(c)),
        ]),
      ),
    ));
    c.update(const SessionCountdownData(60, 5, 'session'));
    await tester.pump();
    await tester.tapAt(const Offset(40, 25));
    expect(taps, 1);
    c.stop();
  });

  testWidgets('ticks every second and calls onZero once when the time is up',
      (tester) async {
    final c = SessionCountdown();
    var zero = 0;
    c.onZero = () => zero++;
    await tester.pumpWidget(host(c));
    await tester.runAsync(() async {
      c.update(const SessionCountdownData(2, 1, 'session'));
      await Future.delayed(const Duration(milliseconds: 2600));
    });
    await tester.pump();
    expect(c.secondsLeft, 0);
    expect(find.text('Session closes in 00:00'), findsOneWidget);
    expect(zero, 1);

    // a new answer from the server (a few seconds more) re-arms it
    c.update(const SessionCountdownData(3, 1, 'session'));
    expect(c.secondsLeft, 3);
    c.stop();
    expect(c.visible, isFalse);
    await tester.pump();
  });
}
