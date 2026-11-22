import 'dart:async';
import 'dart:io';

/// A session recording gives the person no sign of itself: the button turns red, and a file is there afterwards or it is not. These tell them what
/// happened (it started and where it goes, it is saved, it could not be saved, the other computer does not allow it).

/// The newest recording of [peerId] in [dir] that was written at or after [since] and is not empty. The core names the files
/// `outgoing_<id>_<time>_display0_<codec>.webm|mp4` (characters that are not allowed in a name are replaced with `_`).
File? sdNewestRecording(Directory dir, String peerId, DateTime since) {
  if (!dir.existsSync()) return null;
  final prefix = 'outgoing_${peerId.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')}_';
  File? best;
  DateTime? bestAt;
  for (final e in dir.listSync(followLinks: false)) {
    if (e is! File) continue;
    final name = e.uri.pathSegments.last;
    if (!name.startsWith(prefix) || !(name.endsWith('.webm') || name.endsWith('.mp4'))) continue;
    final stat = e.statSync();
    if (stat.size == 0 || stat.modified.isBefore(since)) continue;
    if (bestAt == null || stat.modified.isAfter(bestAt)) {
      best = e;
      bestAt = stat.modified;
    }
  }
  return best;
}

class SdRecordingFeedback {
  SdRecordingFeedback({
    required this.toast,
    required this.folder,
    required this.peerId,
    DateTime Function()? clock,
    this.settle = const Duration(milliseconds: 1500),
    this.startWait = const Duration(seconds: 3),
  }) : _clock = clock ?? DateTime.now;

  final void Function(String) toast;

  /// the folder the core records to
  final String Function() folder;
  final String Function() peerId;
  final DateTime Function() _clock;

  /// how long after "stopped" the file is looked for (the core closes it a moment later)
  final Duration settle;

  /// how long after the button the recording may take to start
  final Duration startWait;

  DateTime? _since;
  Timer? _askTimer;

  /// The person pressed the button to start. When nothing starts, say why: [hostAllows] is what the other computer said about recording.
  void asked({required bool wantStart, required bool Function() isOn, required bool hostAllows}) {
    _askTimer?.cancel();
    if (!wantStart) return;
    _askTimer = Timer(startWait, () {
      if (isOn()) return;
      toast(hostAllows
          ? 'The recording did not start. Try again; if it keeps failing, the other computer\'s video format may not be recordable here.'
          : sdRecordingNotAllowedText);
    });
  }

  /// The core said the recording is on or off.
  void statusChanged(bool on) {
    _askTimer?.cancel();
    if (on) {
      _since = _clock().subtract(const Duration(seconds: 3));
      toast('Recording started. It is saved in ${folder()}');
      return;
    }
    final since = _since;
    if (since == null) return;
    _since = null;
    Timer(settle, () {
      final f = sdNewestRecording(Directory(folder()), peerId(), since);
      toast(f != null
          ? 'Recording saved: ${f.uri.pathSegments.last}'
          : 'Nothing was saved. A recording shorter than a second, or one that never got a full picture, is thrown away. Try again and record for a few seconds.');
    });
  }

  void dispose() => _askTimer?.cancel();
}

const String sdRecordingNotAllowedText =
    'Recording is turned off on the other computer. There, open Settings > Security > Permissions and turn on "Enable recording session".';
