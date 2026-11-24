import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_hbb/screens/sd_window_size.dart';
import 'package:flutter_test/flutter_test.dart';

// The main window can be made bigger or maximised, never smaller than the size the owner chose; a screen too small for that size keeps all of itself.

void main() {
  test('the smallest the window can be is the size the owner chose', () {
    expect(kSdMainWindowMinSize, const Size(1146, 848));
  });

  group('on a screen that holds it', () {
    test('the lock is the chosen size', () {
      expect(sdMainWindowMinFor(const Size(1920, 1040)), kSdMainWindowMinSize);
      expect(sdMainWindowMinFor(const Size(2560, 1400)), kSdMainWindowMinSize);
      expect(sdMainWindowMinFor(const Size(1146, 848)), kSdMainWindowMinSize, reason: 'a screen exactly that big');
    });
  });

  group('on a screen too small for it', () {
    test('the lock is what the screen can show, in each direction', () {
      expect(sdMainWindowMinFor(const Size(1366, 728)), const Size(1146, 728), reason: 'a low laptop screen: as wide as asked, as high as there is');
      expect(sdMainWindowMinFor(const Size(1024, 900)), const Size(1024, 848));
      expect(sdMainWindowMinFor(const Size(1024, 700)), const Size(1024, 700));
    });
  });

  test('the opening size of a window is never below the lock on a screen that holds it', () {
    // the window starts at kSdMainWindowSize (or what was saved) and is then brought up to the lock
    expect(kSdMainWindowSize.width, lessThanOrEqualTo(kSdMainWindowMinSize.width));
    expect(kSdMainWindowSize.height, lessThanOrEqualTo(kSdMainWindowMinSize.height));
  });

  group('where it is used', () {
    final main = File('lib/main.dart').readAsStringSync().replaceAll('\r\n', '\n');
    final size = File('lib/screens/sd_window_size.dart').readAsStringSync().replaceAll('\r\n', '\n');

    test('the main window asks for the lock right after its size was looked at, before it is shown', () {
      final sized = main.indexOf('await sdSizeMainWindow();');
      final locked = main.indexOf('await sdLockMainWindowMinimum();');
      final shown = main.indexOf('windowManager.show();', sized);
      expect(sized, greaterThan(0));
      expect(locked, greaterThan(sized));
      expect(shown, greaterThan(locked));
    });

    test('the lock is the window manager\'s minimum, and a window saved smaller is made as big as it', () {
      expect(size.contains('await windowManager.setMinimumSize(least);'), isTrue);
      expect(size.contains('await windowManager.setSize(Size(max(now.width, least.width), max(now.height, least.height)));'), isTrue);
    });
  });
}
