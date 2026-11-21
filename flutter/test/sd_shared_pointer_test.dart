import 'dart:async';
import 'dart:ui';

import 'package:flutter_hbb/screens/sd_shared_pointer.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mouse event -> remote point arithmetic of `InputModel._handlePointerDevicePos` (a copy of its core, to hold [sdRemoteToView] to it).
Offset _forward({
  required Offset view,
  required Rect rect,
  required double scale,
  required bool scrollAuto,
  required double canvasX,
  required double canvasY,
  required double scrollX,
  required double scrollY,
  required Size canvasSize,
  required double leftToEdge,
  required double topToEdge,
}) {
  var x = view.dx - leftToEdge;
  var y = view.dy - topToEdge;
  final imageWidth = rect.width * scale;
  final imageHeight = rect.height * scale;
  if (!scrollAuto) {
    x += imageWidth * scrollX;
    y += imageHeight * scrollY;
    if (canvasSize.width > imageWidth) x -= (canvasSize.width - imageWidth) / 2;
    if (canvasSize.height > imageHeight) {
      y -= (canvasSize.height - imageHeight) / 2;
    }
  } else {
    x -= canvasX;
    y -= canvasY;
  }
  x /= scale;
  y /= scale;
  return Offset(x + rect.left, y + rect.top);
}

void main() {
  group('a pointer put where the controlled computer\'s arrow is, is sent as that same point', () {
    const rect = Rect.fromLTWH(1920, 0, 2560, 1440);
    for (final scale in [0.5, 1.0, 1.5]) {
      for (final auto in [true, false]) {
        test('scale $scale, ${auto ? 'auto scroll' : 'scrollbar style'}', () {
          const canvasSize = Size(1500, 900);
          final view = sdRemoteToView(
            remoteX: 3100,
            remoteY: 700,
            rect: rect,
            scale: scale,
            scrollAuto: auto,
            canvasX: 37,
            canvasY: -12,
            scrollX: 0.25,
            scrollY: 0.1,
            canvasSize: canvasSize,
            leftToEdge: 8,
            topToEdge: 40,
          );
          final back = _forward(
            view: view,
            rect: rect,
            scale: scale,
            scrollAuto: auto,
            canvasX: 37,
            canvasY: -12,
            scrollX: 0.25,
            scrollY: 0.1,
            canvasSize: canvasSize,
            leftToEdge: 8,
            topToEdge: 40,
          );
          expect(back.dx, closeTo(3100, 1e-6));
          expect(back.dy, closeTo(700, 1e-6));
        });
      }
    }

    test('a picture smaller than the window sits in its middle', () {
      // 800x600 picture at scale 1 in a 1000x800 canvas, scrollbar style: 100 px / 100 px of margin
      final view = sdRemoteToView(
        remoteX: 0,
        remoteY: 0,
        rect: const Rect.fromLTWH(0, 0, 800, 600),
        scale: 1,
        scrollAuto: false,
        canvasX: 0,
        canvasY: 0,
        scrollX: 0,
        scrollY: 0,
        canvasSize: const Size(1000, 800),
        leftToEdge: 0,
        topToEdge: 30,
      );
      expect(view, const Offset(100, 130));
    });
  });

  group('where a point of the window is on the screen', () {
    test('Mac: points, the title bar is what the view leaves of the window', () {
      // 1200x800 window, the view is 780 points high (2x screen): a 20 point title bar
      final s = sdViewToScreen(
        frame: const Rect.fromLTWH(100, 50, 1200, 800),
        viewPhysical: const Size(2400, 1560),
        devicePixelRatio: 2,
        view: const Offset(10, 30),
        isMac: true,
      );
      expect(s, const Offset(110, 100));
    });

    test('Windows: pixels, the border and title bar come off the frame', () {
      // frame 1216x839 around a 1200x800 view: 8 px borders and a 31 px title bar
      final s = sdViewToScreen(
        frame: const Rect.fromLTWH(100, 50, 1216, 839),
        viewPhysical: const Size(1200, 800),
        devicePixelRatio: 1,
        view: const Offset(10, 30),
        isMac: false,
      );
      expect(s, const Offset(118, 111));
    });

    test('Windows at 150%: the view point is in pixels', () {
      final s = sdViewToScreen(
        frame: const Rect.fromLTWH(0, 0, 1816, 1239),
        viewPhysical: const Size(1800, 1200),
        devicePixelRatio: 1.5,
        view: const Offset(100, 60),
        isMac: false,
      );
      // borders 8, title 31
      expect(s, const Offset(8 + 150, 31 + 90));
    });
  });

  group('the pointer is put where the arrow is, once, and nothing reaches the other computer meanwhile', () {
    late DateTime clock;
    late SdSharedPointer pointer;
    setUp(() {
      clock = DateTime(2026, 11, 21, 12);
      pointer = SdSharedPointer(now: () => clock);
    });

    test('events are held while the move is under way, then only the ones near the new place pass', () async {
      final screen = Completer<Offset?>();
      final warps = <List<int>>[];
      Offset? placedAt;
      final started = pointer.start(
        from: const Offset(100, 100),
        hostView: const Offset(400, 300),
        screenOf: (_) => screen.future,
        warp: (x, y) {
          warps.add([x, y]);
          return true;
        },
        placed: (v) => placedAt = v,
        failed: () => fail('the move worked'),
      );
      expect(started, isTrue);
      expect(pointer.busy, isTrue);
      expect(pointer.swallows(const Offset(10, 10)), isTrue);
      expect(pointer.swallows(const Offset(400, 300)), isTrue, reason: 'still under way');

      screen.complete(const Offset(500.4, 600.6));
      await Future<void>.delayed(Duration.zero);
      expect(warps, [
        [500, 601]
      ], reason: 'whole numbers, rounded');
      expect(placedAt, const Offset(400, 300));
      expect(pointer.busy, isFalse);

      // events that were already on their way from the old place (the pointer was at 100,100) are not the pointer going on
      expect(pointer.swallows(const Offset(90, 80)), isTrue);
      expect(pointer.swallows(const Offset(160, 130)), isTrue);
      // the pointer going on from where it was put
      expect(pointer.swallows(const Offset(405, 310)), isFalse);
      expect(pointer.swallows(const Offset(430, 320)), isFalse);
      // a quick flick away right after the move is never held, wherever it goes
      expect(pointer.swallows(const Offset(900, 700)), isFalse);
      expect(pointer.swallows(const Offset(700, 120)), isFalse);
      expect(pointer.swallows(const Offset(250, 600)), isFalse);

      // a moment later everything is the person's own movement again
      clock = clock.add(SdSharedPointer.settle);
      expect(pointer.swallows(const Offset(90, 80)), isFalse);
    });

    test('the check on every mouse event costs next to nothing', () async {
      // a move was made and is done, so the check has something to compare to (the worst case of the check)
      pointer.start(
        from: const Offset(100, 100),
        hostView: const Offset(400, 300),
        screenOf: (_) async => const Offset(500, 600),
        warp: (x, y) => true,
        placed: (_) {},
        failed: () {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(pointer.busy, isFalse);
      var held = 0;
      const events = 2000000;
      final watch = Stopwatch()..start();
      for (var i = 0; i < events; i++) {
        if (pointer.swallows(Offset(i % 1900 + 0.5, i % 1000 + 0.5))) held++;
      }
      watch.stop();
      final perEventNs = watch.elapsedMicroseconds * 1000 / events;
      // ignore: avoid_print
      print('SWALLOWS-COST: $events events in ${watch.elapsedMilliseconds} ms = ${perEventNs.toStringAsFixed(1)} ns each (held $held)');
      // a mouse sends at most ~1000 events a second: even 100x this budget is nothing
      expect(perEventNs, lessThan(2000));
    });

    test('a pointer that cannot be moved leaves the events as they were', () async {
      var failed = 0;
      pointer.start(
        from: const Offset(100, 100),
        hostView: const Offset(400, 300),
        screenOf: (_) async => const Offset(500, 600),
        warp: (x, y) => false,
        placed: (_) => fail('nothing was moved'),
        failed: () => failed++,
      );
      await Future<void>.delayed(Duration.zero);
      expect(failed, 1);
      expect(pointer.busy, isFalse);
      expect(pointer.swallows(const Offset(90, 80)), isFalse);
    });

    test('a window that cannot be asked, or throws, is a failure and not a crash', () async {
      var failed = 0;
      pointer.start(
        from: const Offset(100, 100),
        hostView: const Offset(1, 1),
        screenOf: (_) async => null,
        warp: (x, y) => fail('no place to go'),
        placed: (_) => fail('no place to go'),
        failed: () => failed++,
      );
      await Future<void>.delayed(Duration.zero);
      pointer.start(
        from: const Offset(100, 100),
        hostView: const Offset(1, 1),
        screenOf: (_) async => throw StateError('window gone'),
        warp: (x, y) => fail('no place to go'),
        placed: (_) => fail('no place to go'),
        failed: () => failed++,
      );
      await Future<void>.delayed(Duration.zero);
      expect(failed, 2);
      expect(pointer.busy, isFalse);
    });

    test('a second ask while the first is under way does not move the pointer twice', () async {
      final screen = Completer<Offset?>();
      var warps = 0;
      pointer.start(
        from: const Offset(100, 100),
        hostView: const Offset(1, 1),
        screenOf: (_) => screen.future,
        warp: (x, y) {
          warps++;
          return true;
        },
        placed: (_) {},
        failed: () {},
      );
      expect(
          pointer.start(
            from: const Offset(100, 100),
            hostView: const Offset(2, 2),
            screenOf: (_) async => const Offset(9, 9),
            warp: (x, y) {
              warps += 10;
              return true;
            },
            placed: (_) {},
            failed: () {},
          ),
          isTrue);
      screen.complete(const Offset(5, 5));
      await Future<void>.delayed(Duration.zero);
      expect(warps, 1);
    });

    test('nothing is held when no move was ever asked for', () {
      expect(pointer.swallows(const Offset(10, 10)), isFalse);
    });
  });

  group('"Show remote cursor" is kept on', () {
    test('turned on when it is off, and the state follows', () async {
      var on = false;
      final reported = <bool>[];
      await sdKeepRemoteCursorOn(
        isOn: () => on,
        turnOn: () async => on = true,
        report: reported.add,
      );
      expect(on, isTrue);
      expect(reported, [true]);
    });

    test('left alone when it is already on', () async {
      var turned = 0;
      await sdKeepRemoteCursorOn(
        isOn: () => true,
        turnOn: () async => turned++,
        report: (_) => fail('nothing changed'),
      );
      expect(turned, 0);
    });

    test('an error does not escape', () async {
      await sdKeepRemoteCursorOn(
        isOn: () => false,
        turnOn: () async => throw StateError('session gone'),
        report: (_) => fail('nothing changed'),
      );
    });
  });
}
