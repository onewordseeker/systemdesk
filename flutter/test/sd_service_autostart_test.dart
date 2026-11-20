import 'package:flutter_hbb/screens/sd_background_service.dart';
import 'package:flutter_test/flutter_test.dart';

// A service that an earlier run left stopped ("Service is not running") starts by itself when the app opens, wherever that needs nobody's help.
bool _start({
  bool stopped = true,
  bool outgoingOnly = false,
  bool isWindows = false,
  bool isMacOS = false,
  bool installed = false,
  bool daemonInstalled = false,
}) =>
    sdShouldAutoStartService(stopped: stopped, outgoingOnly: outgoingOnly, isWindows: isWindows, isMacOS: isMacOS, installed: installed, daemonInstalled: daemonInstalled);

void main() {
  group('Windows', () {
    test('a copy that runs without installing starts the service on its own', () {
      expect(_start(isWindows: true, installed: false), isTrue);
    });

    test('an installed copy keeps the "Start service" button (its service needs administrator rights)', () {
      expect(_start(isWindows: true, installed: true), isFalse);
    });
  });

  group('Mac', () {
    test('a Mac without the background service starts it on its own, with no password', () {
      expect(_start(isMacOS: true, installed: true, daemonInstalled: false), isTrue);
      expect(_start(isMacOS: true, installed: false, daemonInstalled: false), isTrue);
    });

    test('with the background service installed, the button stays (the Mac asks for its password)', () {
      expect(_start(isMacOS: true, installed: true, daemonInstalled: true), isFalse);
    });
  });

  group('never', () {
    test('when the service is not stopped there is nothing to start', () {
      expect(_start(stopped: false, isWindows: true), isFalse);
      expect(_start(stopped: false, isMacOS: true), isFalse);
    });

    test('an app that only connects out has no service to start', () {
      expect(_start(outgoingOnly: true, isWindows: true), isFalse);
      expect(_start(outgoingOnly: true, isMacOS: true), isFalse);
    });

    test('on another system nothing changes', () {
      expect(_start(), isFalse);
    });
  });
}
