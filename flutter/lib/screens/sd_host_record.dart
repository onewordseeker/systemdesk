import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/screens/sd_cm_cards.dart';
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
/// The row itself (new look, `sd_cm_cards.dart`): "Record this session" and Record; while recording "Recording session", the way to the folder and Stop.
class SdHostRecordView extends StatelessWidget {
  const SdHostRecordView({super.key, required this.recording, this.always = false, required this.dir, required this.onToggle, required this.onOpenFolder});
  final bool recording;
  /// recording is on for every session (a setting), so the button is not offered
  final bool always;
  final String dir;
  final VoidCallback onToggle, onOpenFolder;

  @override
  Widget build(BuildContext context) {
    return SdCmRecordRow(
      recording: recording,
      always: always,
      dir: dir,
      onToggle: onToggle,
      onOpenFolder: onOpenFolder,
      labels: const SdCmRecordLabels(),
    );
  }
}
