import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_connect_dialog.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_test/flutter_test.dart';

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  tearDown(() => SdLook.debugEnabled = null);

  group('the first two steps are shown one after the other, each at least a moment', () {
    const pacing = SdStepPacing();

    test('a quick network: the computer is reached at 0.3 s, the steps are still shown in turn', () {
      expect(pacing.shown(ms(0), ms(300)), SdShownStep.reaching);
      expect(pacing.shown(ms(699), ms(300)), SdShownStep.reaching, reason: 'at least 0.7 s for the first step');
      expect(pacing.shown(ms(700), ms(300)), SdShownStep.securing);
      expect(pacing.shown(ms(1399), ms(300)), SdShownStep.securing, reason: 'at least 0.7 s for the second step');
      expect(pacing.shown(ms(1400), ms(300)), SdShownStep.waiting);
      expect(pacing.shown(ms(60000), ms(300)), SdShownStep.waiting);
    });

    test('a slow network: the first step is done when the computer is really reached, not before', () {
      expect(pacing.shown(ms(999), ms(1000)), SdShownStep.reaching);
      expect(pacing.shown(ms(1000), ms(1000)), SdShownStep.securing);
      expect(pacing.shown(ms(1699), ms(1000)), SdShownStep.securing);
      expect(pacing.shown(ms(1700), ms(1000)), SdShownStep.waiting);
    });

    test('not reached yet: the first step goes on, however long it takes', () {
      expect(pacing.shown(ms(0), null), SdShownStep.reaching);
      expect(pacing.shown(ms(30000), null), SdShownStep.reaching);
      expect(pacing.nextChange(ms(30000), null), isNull, reason: 'it waits for the real moment');
    });

    test('a connection that began long ago (a reconnect) shows where it is, no delay', () {
      expect(pacing.shown(ms(900000), ms(800000)), SdShownStep.waiting);
      expect(pacing.nextChange(ms(900000), ms(800000)), isNull);
    });

    test('how long until the picture changes next', () {
      expect(pacing.nextChange(ms(100), ms(300)), ms(600));
      expect(pacing.nextChange(ms(700), ms(300)), ms(700));
      expect(pacing.nextChange(ms(1000), ms(300)), ms(400));
      expect(pacing.nextChange(ms(1400), ms(300)), isNull);
      expect(pacing.nextChange(ms(200), ms(1000)), ms(800));
    });

    test('something else (a password to type) may take the place of the card once both steps are done and their checks were seen', () {
      expect(pacing.handOverAt(ms(300)), ms(1750), reason: '0.7 + 0.7 + 0.35');
      expect(pacing.handOverAt(ms(2000)), ms(3050), reason: 'a slow network: from when the computer is reached');
    });

    test('how long the steps still have to be shown when a password is asked for', () {
      final began = DateTime(2026, 11, 21, 12);
      expect(sdStepsStillToShow(null, began), isNull, reason: 'the beginning is not known');
      expect(sdStepsStillToShow(began, began.add(ms(300))), ms(1450), reason: 'asked at 0.3 s: done at 1.75 s');
      expect(sdStepsStillToShow(began, began.add(ms(2000))), ms(1050), reason: 'asked at 2 s: 0.7 + 0.35 more');
      expect(sdStepsStillToShow(began, began.add(const Duration(seconds: 60))), isNull, reason: 'a retry or a reconnect is asked at once');
      expect(sdStepsStillToShow(began, began.subtract(ms(5))), isNull, reason: 'a clock that went back');
    });

    test('the time each step is shown can be set', () {
      const fast = SdStepPacing(reachMin: Duration(milliseconds: 100), secureMin: Duration(milliseconds: 50));
      expect(fast.shown(ms(99), ms(0)), SdShownStep.reaching);
      expect(fast.shown(ms(100), ms(0)), SdShownStep.securing);
      expect(fast.shown(ms(150), ms(0)), SdShownStep.waiting);
    });
  });

  group('the dialog follows that timeline', () {
    final spinner = find.byKey(const ValueKey('sd-step-spinner'));
    final spinnerFinder = spinner;

    Future<void> pumpDialog(WidgetTester tester, DateTime Function() clock, {DateTime? since, SdConnectStage stage = SdConnectStage.waiting}) async {
      SdLook.debugEnabled = true;
      sdConnectAlias = (_) => 'MARKETING-DELL';
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SdConnectDialog(peerId: '408118204', stage: stage, since: since, clock: clock, onCancel: () {}),
        ),
      ));
    }

    testWidgets('reached at 0.3 s: spinner on step 1, then on step 2, then the countdown, never a flash', (tester) async {
      var now = DateTime(2026, 11, 21, 12, 0, 0);
      final began = now;
      now = now.add(ms(300));
      await pumpDialog(tester, () => now, since: began);

      // 0.3 s: the first step is still being made
      expect(spinner, findsOneWidget);
      expect(find.text('Reaching the computer'), findsOneWidget);
      expect(find.text('0.3 s'), findsNothing, reason: 'not done yet');
      expect(find.text('Encrypted'), findsNothing);
      expect(find.text('Someone at the other computer taps Accept.'), findsNothing);

      // 0.7 s: the first step is done, the second is the one in progress (the spinner moves down with a short cross-fade)
      now = began.add(ms(710));
      await tester.pump(ms(420));
      await tester.pump(ms(400));
      expect(spinner, findsOneWidget, reason: 'the second step now has the spinner');
      expect(find.text('0.3 s'), findsOneWidget, reason: 'the first step shows how long it took');
      expect(find.text('Encrypted'), findsNothing, reason: 'the second step is not done yet');
      expect(find.text('Someone at the other computer taps Accept.'), findsNothing);

      // 1.4 s: both are done, "waiting for approval" is the step in progress and counts down
      now = began.add(ms(1410));
      await tester.pump(ms(710));
      await tester.pump(ms(400));
      expect(spinner, findsNothing);
      expect(find.text('Encrypted'), findsOneWidget);
      expect(find.text('Someone at the other computer taps Accept.'), findsOneWidget);
      expect(find.textContaining(':'), findsWidgets, reason: 'the clock of the approval');
    });

    testWidgets('a slow network: the first step spins until the computer is really reached', (tester) async {
      var now = DateTime(2026, 11, 21, 12, 0, 0);
      final began = now;
      now = now.add(ms(2000));
      await pumpDialog(tester, () => now, since: began);
      // reached at 2.0 s: the first step is done at once (it was in progress all that time in the dialog before), the second now spins
      expect(find.text('2.0 s'), findsOneWidget);
      expect(spinner, findsOneWidget);
      expect(find.text('Encrypted'), findsNothing);
      now = began.add(ms(2720));
      await tester.pump(ms(750));
      await tester.pump(ms(400));
      expect(spinner, findsNothing);
      expect(find.text('Encrypted'), findsOneWidget);
    });

    testWidgets('while the computer is being reached the first step spins and the others wait', (tester) async {
      await pumpDialog(tester, () => DateTime(2026, 11, 21), stage: SdConnectStage.reaching);
      expect(spinner, findsOneWidget);
      expect(find.text('Reaching the computer'), findsOneWidget);
      expect(find.text('Encrypted'), findsNothing);
      expect(find.text('Someone at the other computer taps Accept.'), findsNothing);
    });

    group('a password is asked for instead of an accept', () {
      Future<int> run(WidgetTester tester, {required Duration reachedAfter}) async {
        SdLook.debugEnabled = true;
        sdConnectAlias = (_) => 'MARKETING-DELL';
        var now = DateTime(2026, 11, 21, 12, 0, 0);
        final began = now;
        now = now.add(reachedAfter);
        var asked = 0;
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SdConnectDialog(peerId: '408118204', stage: SdConnectStage.waiting, since: began, clock: () => now, onStepsDone: () => asked++, onCancel: () {}),
          ),
        ));
        return asked;
      }

      testWidgets('the steps are shown through first; the password is asked for after the second check, never sooner', (tester) async {
        SdLook.debugEnabled = true;
        sdConnectAlias = (_) => 'MARKETING-DELL';
        var now = DateTime(2026, 11, 21, 12, 0, 0);
        final began = now;
        now = now.add(ms(300));
        var asked = 0;
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SdConnectDialog(peerId: '408118204', stage: SdConnectStage.waiting, since: began, clock: () => now, onStepsDone: () => asked++, onCancel: () {}),
          ),
        ));
        expect(asked, 0);
        expect(spinnerFinder, findsOneWidget, reason: 'step 1 is still being made');

        now = began.add(ms(800));
        await tester.pump(ms(500));
        expect(asked, 0, reason: 'step 2 is in progress');
        expect(spinnerFinder, findsWidgets);

        now = began.add(ms(1500));
        await tester.pump(ms(700));
        expect(asked, 0, reason: 'both done, the checks are being seen');
        expect(find.text('Encrypted'), findsOneWidget);

        now = began.add(ms(1800));
        await tester.pump(ms(300));
        expect(asked, 1, reason: 'now the password may be asked for');
        await tester.pump(const Duration(seconds: 5));
        expect(asked, 1, reason: 'once');

        // no accept is waited for: the third step is neither in progress nor counting
        expect(find.text('Someone at the other computer taps Accept.'), findsNothing);
        expect(find.textContaining(RegExp(r'^\d+:\d\d$')), findsNothing);
      });

      testWidgets('a card that is gone before the end never asks for the password (the connection was cancelled)', (tester) async {
        final asked = await run(tester, reachedAfter: ms(300));
        expect(asked, 0);
        await tester.pump(ms(500));
        await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
        await tester.pump(const Duration(seconds: 5));
        expect(asked, 0);
      });

      testWidgets('a slow network: the password waits for the computer to be reached and both steps after it', (tester) async {
        SdLook.debugEnabled = true;
        sdConnectAlias = (_) => 'MARKETING-DELL';
        var now = DateTime(2026, 11, 21, 12, 0, 0);
        final began = now;
        now = now.add(ms(2000));
        var asked = 0;
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SdConnectDialog(peerId: '408118204', stage: SdConnectStage.waiting, since: began, clock: () => now, onStepsDone: () => asked++, onCancel: () {}),
          ),
        ));
        now = began.add(ms(2900));
        await tester.pump(ms(900));
        expect(asked, 0);
        now = began.add(ms(3100));
        await tester.pump(ms(300));
        expect(asked, 1);
      });
    });

    testWidgets('a dialog that did not see the connection begin shows where it is, at once', (tester) async {
      await pumpDialog(tester, () => DateTime(2026, 11, 21), since: null);
      expect(spinner, findsNothing);
      expect(find.text('Encrypted'), findsOneWidget);
      expect(find.text('Someone at the other computer taps Accept.'), findsOneWidget);
    });

    testWidgets('the seconds counting down do not play the fade again', (tester) async {
      var now = DateTime(2026, 11, 21, 12, 0, 0);
      final began = now.subtract(const Duration(minutes: 5));
      await pumpDialog(tester, () => now, since: began);
      // the second step is shown for a moment, then the third one takes over: let that finish
      now = now.add(ms(1200));
      await tester.pump(ms(1200));
      await tester.pump(ms(600));
      final clock = find.byWidgetPredicate((w) => w is Text && RegExp(r'^\d+:\d\d$').hasMatch(w.data ?? ''));
      expect(clock, findsOneWidget);
      final fade = find.ancestor(of: clock, matching: find.byType(FadeTransition)).first;
      final tree = tester.widgetList<FadeTransition>(find.byType(FadeTransition)).length;
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1.0);
      for (var i = 0; i < 3; i++) {
        now = now.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.widget<FadeTransition>(fade).opacity.value, 1.0, reason: 'a changed number does not fade in again');
        expect(tester.widgetList<FadeTransition>(find.byType(FadeTransition)).length, tree, reason: 'nothing is built again');
      }
    });
  });
}
