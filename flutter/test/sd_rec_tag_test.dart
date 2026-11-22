import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_rec_since.dart';
import 'package:flutter_hbb/screens/sd_rec_tag.dart';
import 'package:flutter_hbb/screens/sd_toolbar.dart';
import 'package:flutter_test/flutter_test.dart';

// While a session is recorded the title bar of the window says so (a tag with the time), and the taskbar button or the Dock icon carries a red mark.

Future<void> _font(String family, List<String> files, String dir) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(File('$dir$f').readAsBytesSync()).buffer)));
  }
  await loader.load();
}

Widget _app(Widget child, {Brightness brightness = Brightness.light}) => MaterialApp(
      theme: ThemeData(fontFamily: 'Inter', brightness: brightness),
      home: Scaffold(body: Align(alignment: Alignment.topRight, child: SizedBox(height: 40, child: Row(mainAxisSize: MainAxisSize.min, children: [child])))),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => _font('Inter', ['Inter-Regular.ttf', 'Inter-Medium.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf'], 'assets/fonts/'));
  tearDown(() {
    SdRecTag.debugNow = null;
    SdRecBadge.debugSet = null;
    SdRecBadge.debugReset();
  });

  test('the time is minutes and seconds, then hours', () {
    expect(sdRecClock(Duration.zero), '00:00');
    expect(sdRecClock(const Duration(seconds: 12)), '00:12');
    expect(sdRecClock(const Duration(minutes: 7, seconds: 51)), '07:51');
    expect(sdRecClock(const Duration(minutes: 59, seconds: 59)), '59:59');
    expect(sdRecClock(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    expect(sdRecClock(const Duration(hours: 12)), '12:00:00');
    // a clock that is a little behind never shows a minus
    expect(sdRecClock(const Duration(seconds: -3)), '00:00');
  });

  for (final brightness in Brightness.values) {
    testWidgets('the tag shows REC and the time, and the time moves every second (${brightness.name})', (tester) async {
      var now = DateTime(2026, 11, 23, 1, 0, 12);
      SdRecTag.debugNow = () => now;
      await tester.pumpWidget(_app(SdRecTag(since: DateTime(2026, 11, 23, 1, 0, 0)), brightness: brightness));
      expect(find.text('REC'), findsOneWidget);
      expect(find.text('00:12'), findsOneWidget);
      // it blinks: the dot is inside
      expect(find.byKey(const ValueKey('sd-rec-dot')), findsOneWidget);

      now = DateTime(2026, 11, 23, 1, 0, 13);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:13'), findsOneWidget);
      now = DateTime(2026, 11, 23, 1, 1, 5);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('01:05'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the tag is a small pill that fits the title bar and stays level with the window buttons', (tester) async {
    SdRecTag.debugNow = () => DateTime(2026, 11, 23, 1, 0, 12);
    await tester.pumpWidget(_app(SdRecTag(since: DateTime(2026, 11, 23, 1, 0, 0))));
    final size = tester.getSize(find.byKey(const ValueKey('sd-rec-tag')));
    expect(size.height, 22);
    expect(size.width, lessThan(112), reason: 'it is a small tag, not a bar');
    expect(size.height, lessThan(40), reason: 'the title bar is 40 high');
    // vertically centred in the bar
    expect(tester.getCenter(find.byKey(const ValueKey('sd-rec-tag'))).dy, closeTo(20, 0.6));
  });

  group('the slot in the title bar', () {
    testWidgets('is empty while nothing is recorded, shows the tag while it is', (tester) async {
      SdRecBadge.debugSet = (_) {};
      SdRecTag.debugNow = () => DateTime(2026, 11, 23, 1, 0, 30);
      final since = DateTime(2026, 11, 23, 1, 0, 0);
      await tester.pumpWidget(_app(SdRecTagSlot(recording: false, since: () => since)));
      expect(find.byKey(const ValueKey('sd-rec-tag')), findsNothing);
      await tester.pumpWidget(_app(SdRecTagSlot(recording: true, since: () => since)));
      expect(find.byKey(const ValueKey('sd-rec-tag')), findsOneWidget);
      expect(find.text('00:30'), findsOneWidget);
      await tester.pumpWidget(_app(SdRecTagSlot(recording: false, since: () => since)));
      expect(find.byKey(const ValueKey('sd-rec-tag')), findsNothing);
    });

    testWidgets('does not ask when the recording began unless it is recording', (tester) async {
      SdRecBadge.debugSet = (_) {};
      var asked = 0;
      await tester.pumpWidget(_app(SdRecTagSlot(recording: false, since: () {
        asked++;
        return DateTime.now();
      })));
      expect(asked, 0);
    });

    testWidgets('puts the red mark on the taskbar button when a recording starts and takes it off when it ends', (tester) async {
      final calls = <bool>[];
      SdRecBadge.debugSet = calls.add;
      SdRecTag.debugNow = () => DateTime(2026, 11, 23, 1, 0, 30);
      final since = DateTime(2026, 11, 23, 1, 0, 0);
      await tester.pumpWidget(_app(SdRecTagSlot(recording: false, since: () => since)));
      await tester.pump();
      expect(calls, isEmpty, reason: 'nothing to do at rest');
      await tester.pumpWidget(_app(SdRecTagSlot(recording: true, since: () => since)));
      await tester.pump();
      expect(calls, [true]);
      // a rebuild while it goes on does not send it again
      await tester.pumpWidget(_app(SdRecTagSlot(recording: true, since: () => since)));
      await tester.pump();
      expect(calls, [true]);
      await tester.pumpWidget(_app(SdRecTagSlot(recording: false, since: () => since)));
      await tester.pump();
      expect(calls, [true, false]);
    });

    testWidgets('a window that closes while recording takes the mark off', (tester) async {
      final calls = <bool>[];
      SdRecBadge.debugSet = calls.add;
      SdRecTag.debugNow = () => DateTime(2026, 11, 23, 1, 0, 30);
      await tester.pumpWidget(_app(SdRecTagSlot(recording: true, since: () => DateTime(2026, 11, 23, 1, 0, 0))));
      await tester.pump();
      expect(calls, [true]);
      await tester.pumpWidget(const SizedBox());
      expect(calls, [true, false]);
    });
  });

  group('where the tag sits', () {
    // Windows: left of Minimize (the `tail` of the window buttons). Mac: right of the three coloured buttons. Both only in the host window.
    final tabbar = File('lib/desktop/widgets/tabbar_widget.dart').readAsStringSync();
    final server = File('lib/desktop/pages/server_page.dart').readAsStringSync();

    test('on Windows the host window gives it as the tail, next to Minimize', () {
      expect(server.contains('tail: SdLook.enabled && !isMacOS ? const SdHostRecTag() : null'), isTrue);
    });

    test('on a Mac the title bar of the host window puts it after the 78 pixels of the three coloured buttons', () {
      final at = tabbar.indexOf('if (isMacOS) const SizedBox(width: 78),');
      expect(at, greaterThan(0));
      final next = tabbar.indexOf('if (isMacOS && tabType == DesktopTabType.cm) const SdHostRecTag(),', at);
      expect(next, greaterThan(at));
      expect(next - at, lessThan(400), reason: 'right after the spacer');
    });

    test('the old dot is no longer in the host window', () {
      expect(server.contains('SdRecDotPlaced'), isFalse);
    });
  });

  group('when the recording began', () {
    test('is kept from the first moment it runs, forgotten when it ends, and counted again from the next start', () {
      final since = SdRecSince();
      expect(since.at, isNull);
      since.update(false);
      expect(since.at, isNull);
      since.update(true, now: () => DateTime(2026, 11, 23, 1, 0, 0));
      expect(since.at, DateTime(2026, 11, 23, 1, 0, 0));
      // told again while it goes on: still the first moment
      since.update(true, now: () => DateTime(2026, 11, 23, 1, 5, 0));
      expect(since.at, DateTime(2026, 11, 23, 1, 0, 0));
      since.update(false);
      expect(since.at, isNull);
      since.update(true, now: () => DateTime(2026, 11, 23, 2, 0, 0));
      expect(since.at, DateTime(2026, 11, 23, 2, 0, 0));
    });
  });

  group('the red mark on the taskbar button with several holders', () {
    test('goes on with the first holder and off with the last, whoever stops first', () {
      final calls = <bool>[];
      SdRecBadge.debugSet = calls.add;
      final a = Object(), b = Object();
      SdRecBadge.acquire(a);
      SdRecBadge.acquire(b);
      expect(calls, [true], reason: 'it is on once');
      SdRecBadge.release(a);
      expect(calls, [true], reason: 'one tab still records');
      SdRecBadge.release(a);
      expect(calls, [true], reason: 'a second release of the same holder changes nothing');
      SdRecBadge.release(b);
      expect(calls, [true, false]);
      SdRecBadge.release(b);
      expect(calls, [true, false]);
    });
  });

  group('the tag in the tab of a session that is recorded', () {
    late ChangeNotifier changes;
    late bool recording;
    late DateTime since;
    SdRecFeed feedOf() => (changes: changes, recording: () => recording, since: () => since);

    setUp(() {
      changes = ChangeNotifier();
      recording = false;
      since = DateTime(2026, 11, 23, 1, 0, 0);
      SdRecTag.debugNow = () => DateTime(2026, 11, 23, 1, 0, 12);
    });

    testWidgets('shows nothing while the session is not recorded, the tag with the time while it is, and nothing again after', (tester) async {
      SdRecBadge.debugSet = (_) {};
      await tester.pumpWidget(_app(SdTabRecTag(tabKey: 'a', find: (_) => feedOf())));
      expect(find.byKey(const ValueKey('sd-rec-tag')), findsNothing);
      recording = true;
      changes.notifyListeners();
      await tester.pump();
      expect(find.byKey(const ValueKey('sd-rec-tag')), findsOneWidget);
      expect(find.text('00:12'), findsOneWidget);
      recording = false;
      changes.notifyListeners();
      await tester.pump();
      expect(find.byKey(const ValueKey('sd-rec-tag')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the tag is 20 high, so it fits the 28 high tab', (tester) async {
      SdRecBadge.debugSet = (_) {};
      recording = true;
      await tester.pumpWidget(_app(SdTabRecTag(tabKey: 'a', find: (_) => feedOf())));
      expect(tester.getSize(find.byKey(const ValueKey('sd-rec-tag'))).height, 20);
    });

    testWidgets('the taskbar button gets its mark while it records and loses it when it stops or when the tab goes', (tester) async {
      final calls = <bool>[];
      SdRecBadge.debugSet = calls.add;
      await tester.pumpWidget(_app(SdTabRecTag(tabKey: 'a', find: (_) => feedOf())));
      expect(calls, isEmpty);
      recording = true;
      changes.notifyListeners();
      await tester.pump();
      expect(calls, [true]);
      recording = false;
      changes.notifyListeners();
      await tester.pump();
      expect(calls, [true, false]);
      recording = true;
      changes.notifyListeners();
      await tester.pump();
      expect(calls, [true, false, true]);
      await tester.pumpWidget(const SizedBox());
      expect(calls, [true, false, true, false], reason: 'a tab that closes while it records takes the mark off');
    });

    testWidgets('two tabs that record share one mark: it stays until the last one stops', (tester) async {
      final calls = <bool>[];
      SdRecBadge.debugSet = calls.add;
      final other = ChangeNotifier();
      var otherRecording = true;
      recording = true;
      await tester.pumpWidget(_app(Row(mainAxisSize: MainAxisSize.min, children: [
        SdTabRecTag(tabKey: 'a', find: (_) => feedOf()),
        SdTabRecTag(tabKey: 'b', find: (_) => (changes: other, recording: () => otherRecording, since: () => since)),
      ])));
      await tester.pump();
      expect(calls, [true], reason: 'on once for both');
      recording = false;
      changes.notifyListeners();
      await tester.pump();
      expect(calls, [true], reason: 'the other tab still records');
      otherRecording = false;
      other.notifyListeners();
      await tester.pump();
      expect(calls, [true, false]);
    });

    testWidgets('a session that is made a moment after its tab is found a moment later', (tester) async {
      SdRecBadge.debugSet = (_) {};
      SdRecFeed? feed;
      recording = true;
      await tester.pumpWidget(_app(SdTabRecTag(tabKey: 'a', find: (_) => feed)));
      expect(find.byKey(const ValueKey('sd-rec-tag')), findsNothing);
      feed = feedOf();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('sd-rec-tag')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('in the tab, the tag comes after the time, before the cross; a tab without one is as it was', (tester) async {
      SdRecBadge.debugSet = (_) {};
      SdTabClock.debugSince('tab', DateTime.now().subtract(const Duration(minutes: 12, seconds: 48)));
      recording = true;
      await tester.pumpWidget(_app(sdRemoteTabContent(
        tabKey: 'tab',
        label: const Text('Studio iMac'),
        unread: const SizedBox(),
        tooltip: 'Direct',
        rec: SdTabRecTag(tabKey: 'tab', find: (_) => feedOf()),
      )));
      expect(find.text('Studio iMac'), findsOneWidget);
      final time = tester.getRect(find.byType(SdTabClock));
      final tag = tester.getRect(find.byKey(const ValueKey('sd-rec-tag')));
      expect(tag.left, greaterThan(time.right));
      await tester.pumpWidget(_app(sdRemoteTabContent(tabKey: 'tab', label: const Text('Studio iMac'), unread: const SizedBox(), tooltip: 'Direct')));
      expect(find.byKey(const ValueKey('sd-rec-tag')), findsNothing);
    });
  });

  group('the controller window', () {
    final tabPage = File('lib/desktop/pages/remote_tab_page.dart').readAsStringSync();
    final remotePage = File('lib/desktop/pages/remote_page.dart').readAsStringSync();
    final model = File('lib/models/model.dart').readAsStringSync();

    test('the tab of a recorded session carries the tag', () {
      expect(tabPage.contains('rec: SdTabRecTag(tabKey: key)'), isTrue);
    });

    test('the old dot over the remote screen is gone', () {
      expect(remotePage.contains('SdSessionRecDot'), isFalse);
      expect(File('lib/screens/sd_rec_dot.dart').readAsStringSync().contains('SdSessionRecDot'), isFalse);
    });

    test('the recording of a session remembers when it began', () {
      expect(model.contains('_sdSince.update(status);'), isTrue);
    });
  });}
