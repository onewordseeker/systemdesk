import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/shared_state.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_modal.dart';
import 'package:flutter_hbb/screens/sd_signin_modal.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:get/get.dart';

/// "Connecting to a computer" of the new design (`Connecting` board): a card with the three steps of a connection. While the connection is made the first
/// step is the one in progress; when the other computer is asked to accept, the first two are done and the third one counts down.
enum SdConnectStage { reaching, waiting }

/// Which step is the one in progress as the person sees it. The app only knows two moments (the connection is being made, the other computer is
/// asked to accept), and the first two steps would flash by when the network is quick: they are shown one after the other, each at least a moment.
enum SdShownStep { reaching, securing, waiting }

/// When the steps are shown as done. Pure: time in, step out.
class SdStepPacing {
  const SdStepPacing({this.reachMin = const Duration(milliseconds: 700), this.secureMin = const Duration(milliseconds: 700), this.hold = const Duration(milliseconds: 350)});

  /// the least time "Reaching the computer" is shown in progress, and "Securing the connection"
  final Duration reachMin, secureMin;

  /// how long the finished steps stay on the screen before something else takes the place of the card (a password to type)
  final Duration hold;

  /// When something else may take the place of the card: after both steps are done and their checks have been seen.
  Duration handOverAt(Duration reachedAt) => reachDoneAt(reachedAt)! + secureMin + hold;

  /// When the first step is shown as done: when the computer is really reached, but not before [reachMin] (null: not reached yet).
  Duration? reachDoneAt(Duration? reachedAt) => reachedAt == null ? null : (reachedAt > reachMin ? reachedAt : reachMin);

  /// [elapsed]: since the connection began; [reachedAt]: when the computer was reached, in the same time (null: not yet).
  SdShownStep shown(Duration elapsed, Duration? reachedAt) {
    final reached = reachDoneAt(reachedAt);
    if (reached == null || elapsed < reached) return SdShownStep.reaching;
    if (elapsed < reached + secureMin) return SdShownStep.securing;
    return SdShownStep.waiting;
  }

  /// How long until what is shown changes by itself (null: it does not).
  Duration? nextChange(Duration elapsed, Duration? reachedAt) {
    final reached = reachDoneAt(reachedAt);
    if (reached == null) return null;
    if (elapsed < reached) return reached - elapsed;
    if (elapsed < reached + secureMin) return reached + secureMin - elapsed;
    return null;
  }
}

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
    this.shown,
    this.approval = true,
  });

  /// the name of the computer
  final String target;
  final String sub;
  final SdConnectStage stage;

  /// The step shown in progress; by default the one that goes with [stage].
  final SdShownStep? shown;

  /// false: the other computer is not asked to accept (a password is asked for instead), so the third step stays as it is
  final bool approval;

  /// "0.4 s": how long it took to reach the computer (known when the stage is [SdConnectStage.waiting])
  final String? reachedIn;

  /// null: not known (yet)
  final bool? secure, direct;
  final int secondsLeft;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final step = shown ?? (stage == SdConnectStage.waiting ? SdShownStep.waiting : SdShownStep.reaching);
    final reached = step != SdShownStep.reaching;
    final secured = step == SdShownStep.waiting;
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
        _Step(
            first: true,
            state: reached ? _StepState.done : _StepState.now,
            spinning: !reached,
            number: 1,
            label: 'Reaching the computer',
            value: reached ? reachedIn : null,
            tabular: true),
        _Step(
          state: secured ? _StepState.done : (reached ? _StepState.now : _StepState.todo),
          spinning: reached && !secured,
          number: 2,
          label: 'Securing the connection',
          value: secured ? (secure == false ? 'Not encrypted' : 'Encrypted') : null,
        ),
        _Step(
          state: secured && approval ? _StepState.now : _StepState.todo,
          number: 3,
          label: 'Waiting for approval',
          sub: secured && approval ? 'Someone at the other computer taps Accept.' : null,
          value: secured && approval ? sdClockOf(secondsLeft) : null,
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
  const _Step({this.first = false, required this.state, this.spinning = false, required this.number, required this.label, this.sub, this.value, this.valueInk = false, this.tabular = false});
  final bool first;
  final _StepState state;

  /// the step in progress shows a spinner in its circle instead of its number
  final bool spinning;
  final int number;
  final String label;
  final String? sub, value;
  final bool valueInk, tabular;

  Widget _circle(SdSkin t) {
    switch (state) {
      case _StepState.done:
        // the check pops in
        return Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: t.goldSoft),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 1),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            builder: (context, v, child) => Transform.scale(scale: v, child: child),
            child: SdIcon(SdIcons.check, size: 16, color: t.goldTxt, stroke: 2.4),
          ),
        );
      case _StepState.now:
        return Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: t.gold),
          child: spinning
              ? SizedBox(
                  key: const ValueKey('sd-step-spinner'),
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation<Color>(t.goldInk), backgroundColor: t.goldInk.withOpacity(0.18)),
                )
              : Text('$number', style: sdTs(14, FontWeight.w600, t.goldInk)),
        );
      case _StepState.todo:
        return Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: t.chip), child: Text('$number', style: sdTs(14, FontWeight.w600, t.mut)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    // the circle changes with a short fade and grow, the row dims and lights up, the words that come with a step fade in
    final circle = AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: ScaleTransition(scale: Tween<double>(begin: 0.75, end: 1).animate(animation), child: child)),
      child: KeyedSubtree(key: ValueKey('$state-$spinning'), child: _circle(t)),
    );
    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: t.line))),
      child: Row(children: [
        circle,
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: sdTs(15, FontWeight.w500, t.ink)),
            if (sub != null) _FadeIn(key: const ValueKey('sd-step-sub'), child: Text(sub!, style: sdTs(13, FontWeight.w400, t.mut))),
          ]),
        ),
        if (value != null) ...[
          const SizedBox(width: 14),
          _FadeIn(key: const ValueKey('sd-step-value'), child: Text(value!, style: sdTs(15, valueInk ? FontWeight.w500 : FontWeight.w400, valueInk ? t.ink : t.mut, figures: tabular))),
        ],
      ]),
    );
    return AnimatedOpacity(opacity: state == _StepState.todo ? 0.55 : 1, duration: const Duration(milliseconds: 260), child: row);
  }
}

/// Fades (and rises a little) when it first appears; later changes of what it holds (the seconds that count down) do not play it again.
class _FadeIn extends StatefulWidget {
  const _FadeIn({super.key, required this.child});
  final Widget child;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(curved), child: widget.child),
    );
  }
}

/// The dialog of a connection that is being made: it follows the two moments the app knows of (the connection is being made, the other computer is asked
/// to accept) and counts the seconds that are left to accept.
class SdConnectDialog extends StatefulWidget {
  const SdConnectDialog({super.key, required this.peerId, required this.stage, required this.onCancel, this.since, this.mode = 'Remote control', this.clock = _now, this.pacing = const SdStepPacing(), this.onStepsDone});
  final String peerId;
  final SdConnectStage stage;
  final VoidCallback onCancel;
  final String mode;

  /// Set when the other computer asks for a password instead of an accept: the card shows the first two steps through and then calls this (the
  /// third step is not shown as the one in progress).
  final VoidCallback? onStepsDone;

  /// when the connection began (for the time it took to reach the computer)
  final DateTime? since;

  /// the time, and how long the first two steps are shown (tests change them)
  final DateTime Function() clock;
  final SdStepPacing pacing;

  static DateTime _now() => DateTime.now();

  @override
  State<SdConnectDialog> createState() => _SdConnectDialogState();
}

/// The name shown for a computer (an alias the person gave it, else its number); a test replaces it.
@visibleForTesting
String Function(String peerId) sdConnectAlias = (peerId) => bind.mainGetPeerOptionSync(id: peerId, key: 'alias');

class _SdConnectDialogState extends State<SdConnectDialog> {
  late final DateTime _waitStart = widget.clock();
  Timer? _timer, _pace, _handOver;

  /// when the computer was reached, counted from the beginning of the connection (null: not reached yet, or the beginning is not known)
  Duration? get _reachedAt {
    final since = widget.since;
    if (widget.stage != SdConnectStage.waiting || since == null) return null;
    final d = _waitStart.difference(since);
    return d.isNegative ? Duration.zero : d;
  }

  /// A dialog that never saw the connection begin (a reconnect) has nothing to pace: it shows where the connection is.
  SdShownStep get _shown {
    if (widget.stage == SdConnectStage.reaching) return SdShownStep.reaching;
    final since = widget.since, reachedAt = _reachedAt;
    if (since == null || reachedAt == null) return SdShownStep.waiting;
    return widget.pacing.shown(widget.clock().difference(since), reachedAt);
  }

  void _schedulePace() {
    _pace?.cancel();
    final since = widget.since;
    if (since == null) return;
    final next = widget.pacing.nextChange(widget.clock().difference(since), _reachedAt);
    if (next == null) return;
    _pace = Timer(next + const Duration(milliseconds: 5), () {
      if (!mounted) return;
      setState(() {});
      _schedulePace();
    });
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _schedulePace();
    _scheduleHandOver();
  }

  // the steps are shown through, then whatever comes next takes the place of the card (never when the card is gone before)
  void _scheduleHandOver() {
    final done = widget.onStepsDone, since = widget.since, reachedAt = _reachedAt;
    if (done == null) return;
    var wait = Duration.zero;
    if (since != null && reachedAt != null) {
      wait = widget.pacing.handOverAt(reachedAt) - widget.clock().difference(since);
      if (wait.isNegative) wait = Duration.zero;
    }
    _handOver = Timer(wait, () {
      if (mounted) done();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pace?.cancel();
    _handOver?.cancel();
    super.dispose();
  }

  String get _name {
    final alias = sdConnectAlias(widget.peerId);
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
        shown: _shown,
        approval: widget.onStepsDone == null,
        reachedIn: reached,
        secure: known ? type.secure.value == ConnectionType.strSecure : null,
        direct: known ? type.direct.value == ConnectionType.strDirect : null,
        secondsLeft: kAcceptTimeoutSecs - widget.clock().difference(_waitStart).inSeconds,
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

/// How long the first steps of a connection still have to be shown when something is asked of the person now (the other computer wants a password):
/// null when there is nothing to show (the connection did not just begin, or its beginning is not known).
Duration? sdStepsStillToShow(DateTime? since, DateTime now, {SdStepPacing pacing = const SdStepPacing(), Duration recent = const Duration(seconds: 20)}) {
  if (since == null) return null;
  final elapsed = now.difference(since);
  if (elapsed.isNegative || elapsed > recent) return null;
  final left = pacing.handOverAt(elapsed) - elapsed;
  return left.isNegative ? Duration.zero : left;
}

/// Something is asked of the person (a password) while the connection is only just made: show the first two steps through, then do [then]. A connection
/// that is not just beginning (a retry, a reconnect) does [then] at once.
void sdAfterConnectSteps(OverlayDialogManager dialogManager, String peerId, VoidCallback then, {VoidCallback? onCancel}) {
  final since = SdLook.enabled ? sdConnectSince[peerId] : null;
  if (sdStepsStillToShow(since, DateTime.now()) == null) {
    then();
    return;
  }
  dialogManager.dismissAll();
  dialogManager.show((setState, close, context) {
    cancel() {
      dialogManager.dismissAll();
      (onCancel ?? closeConnection)();
    }

    return SdConnectDialog(peerId: peerId, stage: SdConnectStage.waiting, since: since, onStepsDone: then, onCancel: cancel);
  }, tag: 'sd-connecting-$peerId');
}

/// The dialog while the other computer is asked to accept: [onCancel] is what the caller does besides closing it.
Widget sdWaitingDialog(String peerId, VoidCallback onCancel) =>
    SdConnectDialog(peerId: peerId, stage: SdConnectStage.waiting, since: sdConnectSince[peerId], onCancel: onCancel);
