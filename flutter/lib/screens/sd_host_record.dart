import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// The name the core switches the recording of the session on this computer with (`sd_host_record.rs`).
const String kSdHostRecordSwitch = 'sd-host-record';

/// "Record this session" in the host window: the owner of the computer saves a video of what the person who came in does, with one press. It is the
/// owner's own recording (nothing to do with the permission that lets the other side record): it starts and stops here, and the core stops it when
/// nobody is connected any more. The state lives in the server model, so every card of the window and the red dot agree.
class SdHostRecordBar extends StatelessWidget {
  const SdHostRecordBar({super.key, required this.client});
  final Client client;

  /// Where the recording goes: the Videos folder of the person logged in. This window runs in their session, so it is theirs.
  String get _dir => bind.mainVideoSaveDirectory(root: false);

  @override
  Widget build(BuildContext context) {
    // the owner may have forbidden changes in this window; the switch would be refused
    if (bind.mainGetBuildinOption(key: kOptionEnablePermChangeInAcceptWindow) == 'N') return const SizedBox.shrink();
    final model = Provider.of<ServerModel>(context);
    // "Automatically record incoming sessions" in Settings records every session, so there is nothing to press
    final always = option2bool(kOptionAllowAutoRecordIncoming, bind.mainGetOptionSync(key: kOptionAllowAutoRecordIncoming));
    final dir = always ? _dir : model.sdHostRecordDir;
    return SdHostRecordView(
      recording: model.sdHostRecordingNow,
      always: always,
      dir: dir,
      onToggle: () {
        final next = !model.sdHostRecording;
        bind.cmSwitchPermission(connId: client.id, name: kSdHostRecordSwitch, enabled: next);
        model.sdSetHostRecording(next, dir: _dir);
      },
      onOpenFolder: () => launchUrl(Uri.file(dir)),
    );
  }
}
/// The card itself: what it does, the button, and (once started) where the file goes.
class SdHostRecordView extends StatelessWidget {
  const SdHostRecordView({super.key, required this.recording, this.always = false, required this.dir, required this.onToggle, required this.onOpenFolder});
  final bool recording;
  /// recording is on for every session (a setting), so the button is not offered
  final bool always;
  final String dir;
  final VoidCallback onToggle, onOpenFolder;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: t.chrome, border: Border.all(color: recording ? t.bad.withOpacity(0.6) : t.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: recording ? t.bad : t.mut.withOpacity(0.45))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(recording ? 'Recording this session' : 'Record this session', style: sdTs(13.5, FontWeight.w600, t.ink, lh: 1.2)),
                Text(always ? 'On for every session (Settings)' : recording ? 'Saving the screen to a file' : 'Save a video of this session',
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: sdTs(12, FontWeight.w400, t.mut, lh: 1.25)),
              ]),
            ),
            if (!always) const SizedBox(width: 10),
            if (!always)
            GestureDetector(
              key: const ValueKey('sd-host-record-toggle'),
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: recording ? t.bad : t.goldSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: recording ? t.bad : t.goldRing.withOpacity(0.55)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    SdIcon(SdIcons.record, size: 16, color: recording ? Colors.white : t.goldTxt, stroke: 2),
                    const SizedBox(width: 7),
                    Text(recording ? 'Stop' : 'Record', style: sdTs(13, FontWeight.w600, recording ? Colors.white : t.goldTxt)),
                  ]),
                ),
              ),
            ),
          ]),
          if (dir.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text('Saved in $dir', maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(11.5, FontWeight.w400, t.mut))),
              const SizedBox(width: 8),
              GestureDetector(
                key: const ValueKey('sd-host-record-folder'),
                behavior: HitTestBehavior.opaque,
                onTap: onOpenFolder,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text('Open folder', style: sdTs(12, FontWeight.w600, t.goldTxt)),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
