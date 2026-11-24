import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_peers.dart';
import 'package:flutter_test/flutter_test.dart';

// A computer's card in the grid (the Dashboard and the cards of Devices) has a photo of that computer across the top, or its system's logo on a plain ground
// when there is none yet, so the cards are all as high as each other.

// a 1 x 1 picture: the card only has to be given a file
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

late File _photo;

SdPeerData _data({bool online = true, bool photo = false, SdOs os = SdOs.mac, bool fav = false}) => SdPeerData(
      id: '408 241 669',
      name: 'saqibs-macbook-pro-2025',
      os: os,
      online: online,
      user: 'saqibkhanbaloch',
      fav: fav,
      thumb: photo ? _photo.path : '',
    );

Widget _app(Widget card, {double width = 365, Brightness brightness = Brightness.light}) => MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: width, child: SingleChildScrollView(child: card)))),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    final dir = Directory.systemTemp.createTempSync('sd-card-photo-');
    _photo = File('${dir.path}${Platform.pathSeparator}SaqibKhanBaloch.jpg')..writeAsBytesSync(_png);
  });
  tearDownAll(() {
    try {
      _photo.parent.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('the banner', () {
    testWidgets('a computer without a photo has its system logo on a plain ground, at the same height', (tester) async {
      await tester.pumpWidget(_app(SdPeerCard(data: _data())));
      expect(tester.getSize(find.byKey(const ValueKey('sd-card-banner'))).height, kSdCardBannerHeight);
      expect(find.byKey(const ValueKey('sd-card-photo')), findsNothing);
      expect(find.byKey(const ValueKey('sd-card-badge')), findsNothing, reason: 'the logo is already the picture');
      expect(find.descendant(of: find.byKey(const ValueKey('sd-card-banner')), matching: find.byType(SdOsIcon)), findsOneWidget);
    });

    testWidgets('a computer with a photo shows it, and its system as a small badge on it', (tester) async {
      await tester.pumpWidget(_app(SdPeerCard(data: _data(photo: true))));
      expect(find.byKey(const ValueKey('sd-card-photo')), findsOneWidget);
      expect(find.byKey(const ValueKey('sd-card-badge')), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('sd-card-banner'))).height, kSdCardBannerHeight);
      final image = tester.widget<Image>(find.descendant(of: find.byKey(const ValueKey('sd-card-photo')), matching: find.byType(Image)));
      expect(image.fit, BoxFit.cover, reason: 'the photo fills the banner');
    });

    testWidgets('with and without a photo the cards are as high as each other', (tester) async {
      await tester.pumpWidget(_app(SdPeerCard(key: const ValueKey('a'), data: _data())));
      final plain = tester.getSize(find.byKey(const ValueKey('a'))).height;
      await tester.pumpWidget(_app(SdPeerCard(key: const ValueKey('b'), data: _data(photo: true))));
      expect(tester.getSize(find.byKey(const ValueKey('b'))).height, plain);
    });

    testWidgets('the photo of a computer that is off is grey; a plain banner is left alone', (tester) async {
      await tester.pumpWidget(_app(SdPeerCard(data: _data(online: false, photo: true))));
      expect(find.ancestor(of: find.byKey(const ValueKey('sd-card-photo')), matching: find.byType(ColorFiltered)), findsOneWidget);
      await tester.pumpWidget(_app(SdPeerCard(data: _data(online: true, photo: true))));
      expect(find.ancestor(of: find.byKey(const ValueKey('sd-card-photo')), matching: find.byType(ColorFiltered)), findsNothing);
      await tester.pumpWidget(_app(SdPeerCard(data: _data(online: false))));
      expect(find.descendant(of: find.byKey(const ValueKey('sd-card-banner')), matching: find.byType(ColorFiltered)), findsNothing);
    });

    testWidgets('a new picture is read again when the card is told one was saved', (tester) async {
      final saved = ValueNotifier<int>(0);
      await tester.pumpWidget(_app(SdPeerCard(data: _data(photo: true), repaint: saved)));
      expect(find.byKey(ValueKey('${_photo.path}#0')), findsOneWidget);
      saved.value++;
      await tester.pump();
      expect(find.byKey(ValueKey('${_photo.path}#1')), findsOneWidget);
      expect(find.byKey(ValueKey('${_photo.path}#0')), findsNothing);
    });
  });

  group('the card still does what it did', () {
    testWidgets('the star is in the banner and takes a tap of its own', (tester) async {
      var fav = 0, connect = 0;
      await tester.pumpWidget(_app(SdPeerCard(data: _data(photo: true), onFav: () => fav++, onConnect: () => connect++)));
      await tester.tap(find.byKey(const ValueKey('sd-card-fav')));
      // the card also takes a double tap, so a single tap on it is let through after the time a second tap could come
      await tester.pump(const Duration(milliseconds: 400));
      expect(fav, 1);
      expect(connect, 0);
    });

    testWidgets('Connect, files and the menu are under the name', (tester) async {
      var connect = 0, files = 0;
      await tester.pumpWidget(_app(SdPeerCard(data: _data(), onConnect: () => connect++, onFiles: () => files++)));
      expect(find.text('saqibs-macbook-pro-2025'), findsOneWidget);
      expect(find.text('408 241 669'), findsOneWidget);
      expect(find.text('ONLINE').evaluate().isNotEmpty || find.text('Online').evaluate().isNotEmpty, isTrue);
      await tester.tap(find.text('Connect'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(connect, 1);
      expect(tester.getTopLeft(find.text('saqibs-macbook-pro-2025')).dy, greaterThan(tester.getBottomLeft(find.byKey(const ValueKey('sd-card-banner'))).dy));
    });

    testWidgets('an offline computer offers Wake up', (tester) async {
      var wake = 0;
      await tester.pumpWidget(_app(SdPeerCard(data: _data(online: false), onWake: () => wake++)));
      await tester.tap(find.text('Wake up'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(wake, 1);
      expect(find.text('Asleep or switched off'), findsOneWidget);
    });
  });

  group('drawing', () {
    for (final brightness in Brightness.values) {
      for (final width in [250.0, 365.0, 520.0]) {
        for (final photo in [false, true]) {
          testWidgets('${brightness.name}, ${width.toInt()} wide, ${photo ? 'with' : 'without'} a photo', (tester) async {
            await tester.pumpWidget(_app(SdPeerCard(data: _data(photo: photo, fav: true)), width: width, brightness: brightness));
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  group('where it is used', () {
    final peerCard = File('lib/common/widgets/peer_card.dart').readAsStringSync().replaceAll('\r\n', '\n');

    test('the picture of a computer is given to its card in the grid and in the pictures layout, and a new one repaints the card', () {
      expect(peerCard.contains('thumb: layout == SdPeerLayout.pictures || layout == SdPeerLayout.grid ?'), isTrue);
      final grid = peerCard.indexOf('if (layout == SdPeerLayout.grid) {');
      final repaint = peerCard.indexOf('repaint: SdThumbs.changed,', grid);
      final rows = peerCard.indexOf('return SdPeerRow(', grid);
      expect(grid, greaterThan(0));
      expect(repaint, inInclusiveRange(grid, rows), reason: 'the grid card is told when a picture was saved');
    });
  });
}
