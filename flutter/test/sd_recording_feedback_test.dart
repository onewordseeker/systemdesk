import 'dart:io';

import 'package:flutter_hbb/screens/sd_recording_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('sd_rec_'));
  tearDown(() => dir.deleteSync(recursive: true));

  File put(String name, {int bytes = 10, DateTime? at}) {
    final f = File('${dir.path}${Platform.pathSeparator}$name')..writeAsBytesSync(List.filled(bytes, 1));
    if (at != null) f.setLastModifiedSync(at);
    return f;
  }

  final started = DateTime.now().subtract(const Duration(seconds: 30));

  group('which file is the recording', () {
    test('the newest non-empty file of that computer since the start', () {
      put('outgoing_123456789_20261122010101000_display0_vp9.webm', at: started.add(const Duration(seconds: 5)));
      final newer = put('outgoing_123456789_20261122010202000_display0_h265.mp4', at: started.add(const Duration(seconds: 20)));
      put('outgoing_987654321_20261122010303000_display0_vp9.webm', at: started.add(const Duration(seconds: 25)));
      expect(sdNewestRecording(dir, '123456789', started)?.path, newer.path);
    });

    test('an empty file, an older one, a file of another kind and a missing folder are not a recording', () {
      put('outgoing_123456789_a_display0_vp9.webm', bytes: 0, at: started.add(const Duration(seconds: 5)));
      put('outgoing_123456789_b_display0_vp9.webm', at: started.subtract(const Duration(minutes: 5)));
      put('outgoing_123456789_c_display0_vp9.txt', at: started.add(const Duration(seconds: 5)));
      put('incoming_123456789_d_display0_vp9.webm', at: started.add(const Duration(seconds: 5)));
      expect(sdNewestRecording(dir, '123456789', started), isNull);
      expect(sdNewestRecording(Directory('${dir.path}${Platform.pathSeparator}nope'), '123456789', started), isNull);
    });

    test('an id with characters a file name cannot hold is matched the way the core names it', () {
      final f = put('outgoing_a_b_20261122_display0_vp9.webm', at: started.add(const Duration(seconds: 5)));
      expect(sdNewestRecording(dir, 'a:b', started)?.path, f.path);
    });
  });

  group('what the person is told', () {
    late List<String> said;
    late SdRecordingFeedback fb;
    setUp(() {
      said = [];
      fb = SdRecordingFeedback(
        toast: said.add,
        folder: () => dir.path,
        peerId: () => '123456789',
        settle: const Duration(milliseconds: 20),
        startWait: const Duration(milliseconds: 20),
      );
    });
    tearDown(() => fb.dispose());

    test('started: the folder is named', () {
      fb.statusChanged(true);
      expect(said.single, contains(dir.path));
    });

    test('stopped with a file: it is named; without one: the person is told nothing was saved', () async {
      fb.statusChanged(true);
      put('outgoing_123456789_x_display0_vp9.webm');
      fb.statusChanged(false);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(said.last, 'Recording saved: outgoing_123456789_x_display0_vp9.webm');

      said.clear();
      dir.listSync().forEach((e) => e.deleteSync());
      fb.statusChanged(true);
      fb.statusChanged(false);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(said.last, startsWith('Nothing was saved'));
    });

    test('pressed but it never started: tells whether the other computer allows it', () async {
      fb.asked(wantStart: true, isOn: () => false, hostAllows: false);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(said.single, sdRecordingNotAllowedText);

      said.clear();
      fb.asked(wantStart: true, isOn: () => false, hostAllows: true);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(said.single, startsWith('The recording did not start'));
    });

    test('pressed and it started in time: nothing is said about a failure; pressed to stop: nothing is waited for', () async {
      fb.asked(wantStart: true, isOn: () => true, hostAllows: true);
      fb.asked(wantStart: false, isOn: () => false, hostAllows: true);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(said, isEmpty);
    });
  });
}
