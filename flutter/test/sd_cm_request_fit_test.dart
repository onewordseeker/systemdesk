import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_cm_window.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:flutter_test/flutter_test.dart';

// The host window of a request: the card (who, the profile under the ID, what, two tags), the permissions and the three buttons must all fit in
// the window, with the room the title bar takes. The parts here are put together with the same margins, paddings and sizes as the real ones
// (`server_page.dart`: the request card, the "Allow" panel with tiles 68 high, buttons 44 high); when those change, change this too.
const double _titleBar = 48;

Future<void> _font(String family, List<String> files, String dir) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(File('$dir$f').readAsBytesSync()).buffer)));
  }
  await loader.load();
}

Widget _request(SdSkin t, {required bool profile}) {
  final header = Container(
    key: const ValueKey('header'),
    margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: t.chrome, border: Border.all(color: t.line)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(width: 64, height: 64, decoration: BoxDecoration(color: t.goldB, borderRadius: BorderRadius.circular(12))),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Info', maxLines: 1, style: sdTs(18, FontWeight.w600, t.ink, lh: 1.2)),
          Text('SaqibKhanBaloch', style: sdTs(13.5, FontWeight.w400, t.mut, figures: true)),
          if (profile) Padding(padding: const EdgeInsets.only(top: 3), child: Text('Profile: Full Access', style: sdTs(13.5, FontWeight.w600, t.goldTxt))),
          const SizedBox(height: 6),
          Text('wants to control this computer', style: sdTs(14, FontWeight.w400, t.ink)),
          const SizedBox(height: 8),
          const Wrap(spacing: 8, runSpacing: 6, children: [SdTag('Encrypted', kind: SdTagKind.ok), SdTag('Remote control')]),
        ]),
      ),
    ]),
  );
  final tiles = Container(
    key: const ValueKey('allow'),
    margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
    child: SdPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Allow', style: sdTs(16, FontWeight.w600, t.ink)),
          Text('Tap to switch', style: sdTs(13, FontWeight.w400, t.mut)),
        ]),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - 30) / 4;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final l in ['Mouse and keys', 'Clipboard', 'Files', 'Sound', 'Restart', 'Record', 'Block input', 'Privacy'])
              SizedBox(width: w, height: 62, child: SdPermTile(icon: SdIcons.mouse, label: l, on: true)),
          ]);
        }),
      ]),
    ),
  );
  final buttons = Padding(
    key: const ValueKey('buttons'),
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
    child: Column(children: [
      Padding(padding: const EdgeInsets.all(3), child: SdButton(kind: SdBtnKind.navy, block: true, height: 44, fontSize: 16, label: 'Accept and elevate', onTap: () {})),
      Row(children: [
        Expanded(child: Padding(padding: const EdgeInsets.all(3), child: SdButton(kind: SdBtnKind.gold, block: true, height: 44, fontSize: 16, label: 'Accept', onTap: () {}))),
        Expanded(child: Padding(padding: const EdgeInsets.all(3), child: SdButton(block: true, height: 44, fontSize: 16, label: 'Dismiss', onTap: () {}))),
      ]),
    ]),
  );
  return Column(children: [header, tiles, buttons]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => _font('Inter', ['Inter-Regular.ttf', 'Inter-Medium.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf'], 'assets/fonts/'));
  tearDown(() => SdLook.debugEnabled = null);

  testWidgets('the request card, the permissions and the buttons fit the request window, with the profile shown', (tester) async {
    SdLook.debugEnabled = true;
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    late SdSkin skin;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Inter'),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: kSdCmRequestSize.width,
            child: Builder(builder: (context) {
              skin = SdSkin.of(context);
              return SingleChildScrollView(child: _request(skin, profile: true));
            }),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    final header = tester.getSize(find.byKey(const ValueKey('header'))).height + 12;
    final allow = tester.getSize(find.byKey(const ValueKey('allow'))).height + 12;
    final buttons = tester.getSize(find.byKey(const ValueKey('buttons'))).height;
    final total = header + allow + buttons;
    // ignore: avoid_print
    print('REQUEST header=$header allow=$allow buttons=$buttons total=$total room=${kSdCmRequestSize.height - _titleBar}');
    expect(total, lessThanOrEqualTo(kSdCmRequestSize.height - _titleBar), reason: 'what the window shows ($total) must fit what it has');
    // the two tags sit on one line, as wide as their words (they used to take a whole line each)
    expect(tester.getSize(find.byType(SdTag).first).width, lessThan(140));
  });
}
