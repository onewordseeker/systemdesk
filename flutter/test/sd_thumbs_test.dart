import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_devices.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_peers.dart';
import 'package:flutter_hbb/screens/sd_thumbs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

// (the app's own name for this type is SessionID, in common.dart; the test only needs a UUID value)
UuidValue newSession() => const Uuid().v4obj();

void main() {
  late Directory dir;
  final taken = <(UuidValue, int)>[];
  final handled = <(UuidValue, String)>[];
  var handleAnswer = '';

  setUp(() {
    dir = Directory.systemTemp.createTempSync('sd-thumbs-ui-');
    taken.clear();
    handled.clear();
    handleAnswer = '';
    SdThumbs.debugDir = dir.path;
    SdThumbs.debugEnabled = () => true;
    SdThumbs.debugTake = (s, d) => taken.add((s, d));
    SdThumbs.debugHandle = (s, a) async {
      handled.add((s, a));
      return a.startsWith('3:') ? handleAnswer : '';
    };
  });

  tearDown(() {
    SdThumbs.debugDir = null;
    SdThumbs.debugEnabled = null;
    SdThumbs.debugTake = null;
    SdThumbs.debugHandle = null;
    SdThumbs.debugGetOption = null;
    SdThumbs.debugSetOption = null;
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('the files', () {
    test('a computer has one file named by its ID; an ID that cannot name a file has none', () {
      final sep = Platform.pathSeparator;
      expect(SdThumbs.pathFor('408118204'), '${dir.path}${sep}408118204.jpg');
      expect(SdThumbs.pathFor('SaqibKhanBaloch'), '${dir.path}${sep}SaqibKhanBaloch.jpg');
      expect(SdThumbs.pathFor('a@b/c'), '${dir.path}${sep}a_b_c.jpg');
      expect(SdThumbs.pathFor('../../x'), '${dir.path}${sep}______x.jpg');
      expect(SdThumbs.pathFor(''), isNull);
      expect(SdThumbs.pathFor('x' * 65), isNull);
    });

    test('the picture is there only when the file is, and pictures are on', () {
      expect(SdThumbs.fileFor('1'), isNull);
      File('${dir.path}${Platform.pathSeparator}1.jpg').writeAsBytesSync([1, 2, 3]);
      expect(SdThumbs.fileFor('1')?.path, SdThumbs.pathFor('1'));
      SdThumbs.debugEnabled = () => false;
      expect(SdThumbs.fileFor('1'), isNull, reason: 'switched off: the cards show none');
    });
  });

  group('the screenshot the app asks for', () {
    testWidgets('the answer to our request is kept as the picture, once, without a question', (tester) async {
      final s = newSession();
      SdThumbs.request(s, 0);
      expect(taken, [(s, 0)]);
      final before = SdThumbs.changed.value;
      expect(SdThumbs.consume(s, '408118204', ''), true);
      await tester.pump();
      expect(handled, [(s, '3:408118204')]);
      expect(SdThumbs.changed.value, before + 1, reason: 'the cards are told');
      // a second screenshot is not ours any more
      expect(SdThumbs.consume(s, '408118204', ''), false);
    });

    test('a screenshot the person took is theirs: nothing was asked for, nothing is taken', () {
      expect(SdThumbs.consume(newSession(), '1', ''), false);
      expect(handled, isEmpty);
    });

    testWidgets('an error from the host is let go quietly', (tester) async {
      final s = newSession();
      SdThumbs.request(s, 0);
      expect(SdThumbs.consume(s, '1', 'not supported'), true);
      await tester.pump();
      expect(handled, isEmpty);
    });

    testWidgets('a picture that could not be kept (a black screen) lets the screenshot go and changes nothing', (tester) async {
      handleAnswer = 'the screen is black';
      final s = newSession();
      final before = SdThumbs.changed.value;
      SdThumbs.request(s, 0);
      SdThumbs.consume(s, '1', '');
      await tester.pump();
      expect(handled, [(s, '3:1'), (s, '2')]);
      expect(SdThumbs.changed.value, before);
    });

    testWidgets('an answer that never came stops being waited for, so a later screenshot is the person\'s own', (tester) async {
      final s = newSession();
      SdThumbs.request(s, 0);
      await tester.pump(SdThumbs.waitFor + const Duration(seconds: 1));
      expect(SdThumbs.consume(s, '1', ''), false);
    });

    testWidgets('a new request while one is on its way starts the wait again', (tester) async {
      final s = newSession();
      SdThumbs.request(s, 0);
      await tester.pump(const Duration(seconds: 15));
      SdThumbs.request(s, 1);
      await tester.pump(const Duration(seconds: 15));
      expect(SdThumbs.consume(s, '1', ''), true);
      expect(taken.map((e) => e.$2), [0, 1]);
    });

    testWidgets('ending the session forgets the request', (tester) async {
      final s = newSession();
      SdThumbs.request(s, 0);
      SdThumbs.end(s);
      expect(SdThumbs.consume(s, '1', ''), false);
    });
  });

  group('the picture is the background of the computer, never a screenshot', () {
    test('only a computer that says so is asked; every other answer is a no', () {
      expect(SdThumbs.hostGivesWallpaper({'sd_wallpaper': true}), isTrue);
      expect(SdThumbs.hostGivesWallpaper({}), isFalse, reason: 'an older version says nothing: no picture, not a screenshot');
      expect(SdThumbs.hostGivesWallpaper({'sd_wallpaper': false}), isFalse);
      expect(SdThumbs.hostGivesWallpaper({'sd_wallpaper': 'true'}), isFalse);
      expect(SdThumbs.hostGivesWallpaper({'is_installed': true}), isFalse);
    });

    test('the request names the display no computer has, the same number the computer listens for', () {
      final rust = File('../src/sd_wallpaper.rs').readAsStringSync();
      final number = RegExp(r'REQUEST_DISPLAY: i32 = (\d+);').firstMatch(rust);
      expect(number, isNotNull);
      expect(int.parse(number!.group(1)!), SdThumbs.wallpaperDisplay);
      expect(SdThumbs.wallpaperDisplay, greaterThanOrEqualTo(1000), reason: 'a real display is a small number');
    });

    test('the key the computer sets in its platform additions is the one the app looks for', () {
      final connection = File('../src/server/connection.rs').readAsStringSync();
      expect(connection.contains('platform_additions.insert("sd_wallpaper".into(), json!(true));'), isTrue);
      expect(SdThumbs.hostGivesWallpaper({'sd_wallpaper': true}), isTrue);
    });

    test('a screenshot is never asked for: the schedule only ever requests the wallpaper', () {
      final source = File('lib/screens/sd_thumbs.dart').readAsStringSync();
      expect(source.contains('request(id, wallpaperDisplay);'), isTrue);
      expect(source.contains('pi.currentDisplay'), isFalse, reason: 'no display of the computer is asked for its screen');
      expect(source.contains('is_screenshot_supported'), isFalse);
    });

    testWidgets('the request goes out for the wallpaper display', (tester) async {
      final s = newSession();
      SdThumbs.request(s, SdThumbs.wallpaperDisplay);
      expect(taken, [(s, SdThumbs.wallpaperDisplay)]);
      SdThumbs.end(s);
    });

    testWidgets('the pictures that were screenshots are deleted once, when this version first starts', (tester) async {
      final options = <String, String>{};
      SdThumbs.debugGetOption = (k) => options[k] ?? '';
      SdThumbs.debugSetOption = (k, v) async => options[k] = v;
      final before = SdThumbs.changed.value;
      await SdThumbs.migrateToWallpapers();
      expect(SdThumbs.changed.value, before + 1, reason: 'the pictures were cleared and the cards told');
      expect(options['sd-thumbs-wallpaper'], 'Y');
      await SdThumbs.migrateToWallpapers();
      expect(SdThumbs.changed.value, before + 1, reason: 'not again: the backgrounds that came since are kept');
    });
  });

  group('the card of a computer as a picture', () {
    SdPeerData data({bool online = true, String thumb = '', String name = 'Maya\'s MacBook', bool fav = false}) =>
        SdPeerData(id: '408 118 204', name: name, os: SdOs.mac, online: online, thumb: thumb, fav: fav);

    Future<void> show(WidgetTester tester, SdPeerData d,
        {VoidCallback? onConnect, VoidCallback? onWake, VoidCallback? onFiles, VoidCallback? onFav, VoidCallback? onTap, double width = 300, ValueNotifier<int>? repaint}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: SdPeerPictureCard(data: d, onConnect: onConnect, onWake: onWake, onFiles: onFiles, onFav: onFav, onTap: onTap, repaint: repaint),
            ),
          ),
        ),
      ));
    }

    Future<void> hover(WidgetTester tester) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('sd-picture-card'))));
      await tester.pump();
    }
    // (one mouse per test: the second one added in the same test would be a second pointer of the same device)

    testWidgets('without a picture it shows the logo of the system, the name and the ID, and a green dot while online', (tester) async {
      await show(tester, data());
      expect(find.byType(Image), findsNothing);
      expect(find.byType(SdOsIcon), findsOneWidget);
      expect(find.text('Maya\'s MacBook'), findsOneWidget);
      expect(find.text('408 118 204'), findsOneWidget);
      final led = tester.widget<Container>(find.byKey(const ValueKey('sd-picture-led'))).decoration as BoxDecoration;
      expect((led.color!.green > led.color!.red), true, reason: 'green while online');
      expect(find.byType(ColorFiltered), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with a picture the card shows that file, and reads it again when a new one was saved', (tester) async {
      final f = File('${dir.path}${Platform.pathSeparator}408118204.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
      final repaint = ValueNotifier<int>(0);
      await show(tester, data(thumb: f.path), repaint: repaint);
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as FileImage).file.path, f.path);
      expect(image.fit, BoxFit.cover);
      final first = image.key;
      repaint.value++;
      await tester.pump();
      expect(tester.widget<Image>(find.byType(Image)).key, isNot(first), reason: 'a new version of the file');
    });

    testWidgets('an offline computer is shown in grey with a red dot', (tester) async {
      await show(tester, data(online: false));
      expect(find.byType(ColorFiltered), findsOneWidget);
      final led = tester.widget<Container>(find.byKey(const ValueKey('sd-picture-led'))).decoration as BoxDecoration;
      expect((led.color!.red > led.color!.green), true, reason: 'red while offline');
    });

    testWidgets('pointing at an online card offers Connect and the files; pointing away hides them', (tester) async {
      var connect = 0, files = 0;
      await show(tester, data(), onConnect: () => connect++, onFiles: () => files++);
      expect(find.byKey(const ValueKey('sd-picture-connect')), findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('sd-picture-card'))));
      await tester.pump();
      expect(find.byKey(const ValueKey('sd-picture-wake')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('sd-picture-connect')));
      // (two clicks right after each other would be a double click on the card)
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('sd-picture-files')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(connect, 1);
      expect(files, 1);
      await mouse.moveTo(const Offset(5, 5));
      await tester.pump();
      expect(find.byKey(const ValueKey('sd-picture-connect')), findsNothing);
    });

    testWidgets('an offline card offers Wake up instead of Connect', (tester) async {
      var wake = 0;
      await show(tester, data(online: false), onWake: () => wake++);
      await hover(tester);
      expect(find.byKey(const ValueKey('sd-picture-connect')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('sd-picture-wake')));
      expect(wake, 1);
    });

    testWidgets('a double click connects, and the star is the favourite', (tester) async {
      var connect = 0, fav = 0;
      await show(tester, data(), onConnect: () => connect++, onFav: () => fav++);
      await tester.tap(find.byKey(const ValueKey('sd-picture-fav')));
      await tester.pump(const Duration(milliseconds: 600));
      expect((fav, connect), (1, 0));
      final at = tester.getCenter(find.byKey(const ValueKey('sd-picture-card')));
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 600));
      expect(connect, 1);
    });

    testWidgets('while several computers are being picked a click picks one (and does not connect)', (tester) async {
      var tap = 0;
      await show(tester, data(), onTap: () => tap++);
      await tester.tap(find.byKey(const ValueKey('sd-picture-card')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tap, 1);
    });

    testWidgets('a long name is cut to one line and does not overflow, even in a narrow card', (tester) async {
      await show(tester, data(name: 'A computer with a very very long name that does not fit'), width: 230);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const ValueKey('sd-picture-card'))).height, closeTo(230 / 1.6, 1));
    });
  });

  group('the pictures layout', () {
    Future<List<double>> widthsAt(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SdPeersLayout(layout: SdPeerLayout.pictures, children: [for (var i = 0; i < 8; i++) SizedBox(key: ValueKey('c$i'), height: 50)]),
          ),
        ),
      ));
      return [for (var i = 0; i < 8; i++) tester.getSize(find.byKey(ValueKey('c$i'))).width];
    }

    testWidgets('as many columns as fit at the least width of a picture, at most five', (tester) async {
      expect((await widthsAt(tester, 1000)).first, closeTo((1000 - 3 * 16) / 4, 0.5), reason: '4 columns');
      expect((await widthsAt(tester, 480)).first, closeTo((480 - 16) / 2, 0.5), reason: '2 columns');
      expect((await widthsAt(tester, 200)).first, closeTo(200, 0.5), reason: '1 column');
      expect((await widthsAt(tester, 2400)).first, closeTo((2400 - 4 * 16) / 5, 0.5), reason: 'never more than 5');
    });
  });

  group('the view switch of Devices', () {
    Future<void> show(WidgetTester tester, {VoidCallback? onPictures, bool pictures = false, bool grid = true, ValueChanged<bool>? onGrid}) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SdDevicesView(
              summary: '3 computers',
              tabs: const SizedBox(height: 30),
              query: TextEditingController(),
              filter: 'all',
              onFilter: (_) {},
              grid: grid,
              onGrid: onGrid ?? (_) {},
              pictures: pictures,
              onPictures: onPictures,
              body: const SizedBox(height: 10),
            ),
          ),
        ),
      ));
    }

    testWidgets('has the pictures as the middle of three views, and each one reports what was chosen', (tester) async {
      var pictured = 0;
      final grids = <bool>[];
      await show(tester, onPictures: () => pictured++, onGrid: grids.add);
      expect(find.byKey(const ValueKey('sd-view-seg')), findsOneWidget);
      final seg = find.descendant(of: find.byKey(const ValueKey('sd-view-seg')), matching: find.byType(SdIcon));
      expect(seg, findsNWidgets(3));
      await tester.tap(seg.at(1));
      await tester.tap(seg.at(2));
      await tester.tap(seg.at(0));
      expect(pictured, 1);
      expect(grids, [false, true]);
    });

    testWidgets('without the third view it is the two it was', (tester) async {
      await show(tester);
      expect(find.byKey(const ValueKey('sd-view-seg')), findsNothing);
      expect(find.byType(SdIcon), findsWidgets);
    });
  });
}
