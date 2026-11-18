import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/shared_state.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_modal.dart';
import 'package:flutter_hbb/screens/sd_signin_modal.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:get/get.dart';

/// "Connecting to a computer" of the new design (`Connecting` board): a card with the three steps of a connection. While the connection is made the first
/// step is the one in progress; when the other computer is asked to accept, the first two are done and the third one counts down.
enum SdConnectStage { reaching, waiting }

/// The words under the heading: what is being opened and which computer.
String sdConnectSub(String peerId, {String mode = 'Remote control'}) => '$mode · ID ${sdFormatId(peerId)}';

/// 408118204 -> 408 118 204
String sdFormatId(String id) {
  final digits = id.replaceAll(' ', '');
  if (!RegExp(r'^\d{6,}$').hasMatch(digits)) return id;
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
    out.write(digits[i]);
  }
  return out.toString();
}

/// 98 -> 1:38
String sdClockOf(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// What a person sees while a connection is made. It draws and nothing else.
class SdConnectView extends StatelessWidget {
  const SdConnectView({
    super.key,
    required this.target,
    required this.sub,
    required this.stage,
    this.reachedIn,
    this.secure,
    this.direct,
    this.secondsLeft = 0,
    required this.onCancel,
  });

  /// the name of the computer
  final String target;
  final String sub;
  final SdConnectStage stage;

  /// "0.4 s": how long it took to reach the computer (known when the stage is [SdConnectStage.waiting])
  final String? reachedIn;

  /// null: not known (yet)
  final bool? secure, direct;
  final int secondsLeft;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final waiting = stage == SdConnectStage.waiting;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          SdMarkTile(child: SdIcon(SdIcons.monitor, size: 26, color: const Color(0xFFF3E2B8), stroke: 1.9)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Connecting to $target', maxLines: 2, overflow: TextOverflow.ellipsis, style: sdTs(21, FontWeight.w600, t.ink, ls: -0.21)),
              Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: sdTs(14.5, FontWeight.w400, t.mut))),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        _Step(first: true, state: waiting ? _StepState.done : _StepState.now, number: 1, label: 'Reaching the computer', value: waiting ? reachedIn : null, tabular: true),
        _Step(
          state: waiting ? _StepState.done : _StepState.todo,
          number: 2,
          label: 'Securing the connection',
          value: waiting ? (secure == false ? 'Not encrypted' : 'Encrypted') : null,
        ),
        _Step(
          state: waiting ? _StepState.now : _StepState.todo,
          number: 3,
          label: 'Waiting for approval',
          sub: waiting ? 'Someone at the other computer taps Accept.' : null,
          value: waiting ? sdClockOf(secondsLeft) : null,
          valueInk: true,
          tabular: true,
        ),
        const SizedBox(height: 18),
        Row(children: [
          if (direct != null) ...[
            SdTag(direct! ? 'Direct connection' : 'Relay connection', kind: direct! ? SdTagKind.ok : SdTagKind.plain),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text('Minutes count from the moment they accept.', style: sdTs(13, FontWeight.w400, t.mut))),
          const SizedBox(width: 10),
          SdButton(label: 'Cancel', onTap: onCancel),
        ]),
      ],
    );
  }
}

enum _StepState { done, now, todo }

/// `.step`: a numbered circle, the words, and a value at the right
class _Step extends StatelessWidget {
  const _Step({this.first = false, required this.state, required this.number, required this.label, this.sub, this.value, this.valueInk = false, this.tabular = false});
  final bool first;
  final _StepState state;
  final int number;
  final String label;
  final String? sub, value;
  final bool valueInk, tabular;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    Widget circle;
    switch (state) {
      case _StepState.done:
        circle = Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: t.goldSoft), child: SdIcon(SdIcons.check, size: 16, color: t.goldTxt, stroke: 2.4));
        break;
      case _StepState.now:
        circle = Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, gradient: t.gold), child: Text('$number', style: sdTs(14, FontWeight.w600, t.goldInk)));
        break;
      case _StepState.todo:
        circle = Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: t.chip), child: Text('$number', style: sdTs(14, FontWeight.w600, t.mut)));
        break;
    }
    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: t.line))),
      child: Row(children: [
        circle,
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: sdTs(15, FontWeight.w500, t.ink)),
            if (sub != null) Text(sub!, style: sdTs(13, FontWeight.w400, t.mut)),
          ]),
        ),
        if (value != null) ...[
          const SizedBox(width: 14),
          Text(value!, style: sdTs(15, valueInk ? FontWeight.w500 : FontWeight.w400, valueInk ? t.ink : t.mut, figures: tabular)),
        ],
      ]),
    );
    return state == _StepState.todo ? Opacity(opacity: 0.55, child: row) : row;
  }
}

/// The dialog of a connection that is being made: it follows the two moments the app knows of (the connection is being made, the other computer is asked
/// to accept) and counts the seconds that are left to accept.
class SdConnectDialog extends StatefulWidget {
  const SdConnectDialog({super.key, required this.peerId, required this.stage, required this.onCancel, this.since, this.mode = 'Remote control'});
  final String peerId;
  final SdConnectStage stage;
  final VoidCallback onCancel;
  final String mode;

  /// when the connection began (for the time it took to reach the computer)
  final DateTime? since;

  @override
  State<SdConnectDialog> createState() => _SdConnectDialogState();
}

class _SdConnectDialogState extends State<SdConnectDialog> {
  late final DateTime _waitStart = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _name {
    final alias = bind.mainGetPeerOptionSync(id: widget.peerId, key: 'alias');
    return alias.isEmpty ? sdFormatId(widget.peerId) : alias;
  }

  @override
  Widget build(BuildContext context) {
    final tag = ConnectionTypeState.tag(widget.peerId);
    final type = Get.isRegistered<ConnectionType>(tag: tag) ? Get.find<ConnectionType>(tag: tag) : null;
    final known = type != null && type.isValid();
    final waiting = widget.stage == SdConnectStage.waiting;
    String? reached;
    if (waiting && widget.since != null) {
      final ms = _waitStart.difference(widget.since!).inMilliseconds;
      reached = '${(ms / 1000).toStringAsFixed(1)} s';
    }
    return SdModal(
      maxWidth: 480,
      onCancel: widget.onCancel,
      content: SdConnectView(
        target: _name,
        sub: sdConnectSub(widget.peerId, mode: widget.mode),
        stage: widget.stage,
        reachedIn: reached,
        secure: known ? type.secure.value == ConnectionType.strSecure : null,
        direct: known ? type.direct.value == ConnectionType.strDirect : null,
        secondsLeft: kAcceptTimeoutSecs - DateTime.now().difference(_waitStart).inSeconds,
        onCancel: widget.onCancel,
      ),
    );
  }
}

/// When each connection began: the dialog that waits for the accept reads it, to say how long reaching the computer took.
final Map<String, DateTime> sdConnectSince = {};

/// The first dialog of a connection (replaces the spinner).
void sdShowConnecting(OverlayDialogManager dialogManager, String peerId, VoidCallback onCancel) {
  sdConnectSince[peerId] = DateTime.now();
  dialogManager.show((setState, close, context) {
    cancel() {
      dialogManager.dismissAll();
      onCancel();
    }

    return SdConnectDialog(peerId: peerId, stage: SdConnectStage.reaching, onCancel: cancel);
  }, tag: 'sd-connecting-$peerId');
}

/// The dialog while the other computer is asked to accept: [onCancel] is what the caller does besides closing it.
Widget sdWaitingDialog(String peerId, VoidCallback onCancel) =>
    SdConnectDialog(peerId: peerId, stage: SdConnectStage.waiting, since: sdConnectSince[peerId], onCancel: onCancel);
