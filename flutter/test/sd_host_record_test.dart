import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_host_record.dart';
import 'package:flutter_hbb/screens/sd_rec_dot.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _font(String family, List<String> files, String dir) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(File('$dir$f').readAsBytesSync()).buffer)));
  }
  await loader.load();
}

Widget _host(Widget child, {Brightness brightness = Brightness.light}) => MaterialApp(
      theme: ThemeData(fontFamily: 'Inter', brightness: brightness),
      home: Scaffold(body: SizedBox(width: 400, child: child)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => _font('Inter', ['Inter-Regular.ttf', 'Inter-Medium.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf'], 'assets/fonts/'));

  for (final brightness in Brightness.values) {
    testWidgets('the record card offers to record, then shows it is recording and where the file goes (${brightness.name})', (tester) async {
      var toggled = 0, opened = 0;
      var recording = false;
      var dir = '';
      late StateSetter set;
      await tester.pumpWidget(_host(
        StatefulBuilder(builder: (context, s) {
          set = s;
          return SdHostRecordView(recording: recording, dir: dir, onToggle: () => toggled++, onOpenFolder: () => opened++);
        }),
        brightness: brightness,
      ));
      expect(find.text('Record this session'), findsOneWidget);
      expect(find.text('Record'), findsOneWidget);
      // nothing about a folder before a recording was started
      expect(find.text('Open folder'), findsNothing);
      // it fills the width of the small host window (its 12 px margins included)
      expect(tester.getSize(find.byType(SdHostRecordView)).width, 400);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('sd-host-record-toggle')));
      expect(toggled, 1);

      set(() {
        recording = true;
        dir = r'C:\ProgramData\SystemDesk\recording';
      });
      await tester.pump();
      expect(find.text('Recording session'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
      // where the file goes is a tip over the row
      expect(find.byTooltip(r'Saved in C:\ProgramData\SystemDesk\recording'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sd-host-record-folder')));
      expect(opened, 1);
      await tester.tap(find.byKey(const ValueKey('sd-host-record-toggle')));
      expect(toggled, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('when every session is recorded by a setting there is no button, only the way to the folder', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_host(SdHostRecordView(
      recording: true,
      always: true,
      dir: r'C:\Users\Maya\Videos\SystemDesk',
      onToggle: () {},
      onOpenFolder: () => opened++,
    )));
    expect(find.byKey(const ValueKey('sd-host-record-toggle')), findsNothing);
    expect(find.text('Recording every session'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sd-host-record-folder')));
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the red dot blinks like the light of a camera: lit, then dark, then lit again, round and round', (tester) async {
    await tester.pumpWidget(_host(const Center(child: SdRecDot())));
    double opacity() => tester.widget<FadeTransition>(find.byType(FadeTransition).last).opacity.value;
    final seen = <double>[];
    for (var i = 0; i < 28; i++) {
      seen.add(opacity());
      await tester.pump(const Duration(milliseconds: 100));
    }
    // fully lit for a good while, nearly dark for a while, and it comes back: over 2.8 seconds that happens twice
    expect(seen.where((o) => o > 0.95).length, greaterThan(8));
    expect(seen.where((o) => o < 0.1).length, greaterThan(4));
    var changes = 0;
    for (var i = 1; i < seen.length; i++) {
      if ((seen[i] > 0.5) != (seen[i - 1] > 0.5)) changes++;
    }
    expect(changes, greaterThanOrEqualTo(3));
    final decoration = tester.widget<Container>(find.byKey(const ValueKey('sd-rec-dot'))).decoration as BoxDecoration;
    expect(decoration.color, kSdRecRed);
    expect(decoration.shape, BoxShape.circle);
    expect(tester.getSize(find.byKey(const ValueKey('sd-rec-dot'))), const Size(kSdRecDotSize, kSdRecDotSize));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long folder name is cut to one line and does not overflow', (tester) async {
    await tester.pumpWidget(_host(SdHostRecordView(
      recording: true,
      dir: r'C:\Users\Someone With A Very Long Name\Videos\SystemDesk\Recordings\Of\The\Sessions\Of\This\Computer',
      onToggle: () {},
      onOpenFolder: () {},
    )));
    expect(tester.takeException(), isNull);
    expect(find.text('Open folder'), findsOneWidget);
  });
}
