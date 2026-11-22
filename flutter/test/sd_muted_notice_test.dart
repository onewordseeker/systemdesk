import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_muted_notice.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _font(String family, List<String> files, String dir) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(File('$dir$f').readAsBytesSync()).buffer)));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => _font('Inter', ['Inter-Regular.ttf', 'Inter-Medium.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf'], 'assets/fonts/'));

  testWidgets('the muted notice says so, and Unmute and the cross each do their one thing', (tester) async {
    var unmuted = 0, closed = 0;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Inter'),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Align(
          alignment: Alignment.topLeft,
          child: SdMutedNoticeView(onUnmute: () => unmuted++, onClose: () => closed++),
        ),
      ),
    ));
    expect(find.text('Sound is muted for this computer'), findsOneWidget);
    expect(find.text('Unmute'), findsOneWidget);
    // it fits one line, 36 high, and is not wider than a small session window
    final size = tester.getSize(find.byType(SdMutedNoticeView));
    expect(size.height, 36);
    expect(size.width, lessThan(420));

    await tester.tap(find.byKey(const ValueKey('sd-muted-unmute')));
    expect((unmuted, closed), (1, 0));
    await tester.tap(find.byKey(const ValueKey('sd-muted-close')));
    expect((unmuted, closed), (1, 1));
  });
}
