import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart' show Client;
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_modal.dart';
import 'package:flutter_hbb/screens/sd_profiles.dart';
import 'package:flutter_hbb/screens/sd_settings.dart';
import 'package:flutter_hbb/screens/sd_signin_modal.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';

/// Remote approval: a person who is connected with a profile in Full access mode can accept (or refuse) another person's request to connect to the same
/// computer, and choose what that person is allowed. The two sides talk through the chat that every session already has, so no new protocol is needed:
/// a chat text that starts with [kSdApprovalMark] is not shown as a message but handled here.
///   host -> controller   `request` (someone asks to connect, with the permissions the computer would give them) and `closed` (it was answered elsewhere)
///   controller -> host   `decision` (accept or not, and the permissions chosen)
/// The host checks everything again: who sent the decision, that the request is still open, and that no permission is given that the sender does not have.
const String kSdApprovalMark = '\u0001sd-approval:';

/// The permissions a request is about (the ones of the host window's tiles), in the order they are shown.
const List<String> kSdApprovalPerms = ['keyboard', 'clipboard', 'file', 'audio', 'restart', 'recording', 'block_input', 'privacy_mode'];

class SdApprovalRequest {
  const SdApprovalRequest({required this.id, required this.name, required this.peerId, required this.kind, required this.perms});
  final int id;
  final String name, peerId, kind;
  final Map<String, bool> perms;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'peer_id': peerId, 'kind': kind, 'perms': perms};

  static SdApprovalRequest? fromJson(Object? json) {
    if (json is! Map || json['id'] is! int) return null;
    final perms = json['perms'];
    return SdApprovalRequest(
      id: json['id'] as int,
      name: '${json['name'] ?? ''}',
      peerId: '${json['peer_id'] ?? ''}',
      kind: '${json['kind'] ?? ''}',
      perms: {for (final p in kSdApprovalPerms) p: perms is Map && perms[p] == true},
    );
  }
}

class SdApprovalDecision {
  const SdApprovalDecision({required this.id, required this.accept, this.perms = const {}});
  final int id;
  final bool accept;
  final Map<String, bool> perms;

  Map<String, dynamic> toJson() => {'id': id, 'accept': accept, 'perms': perms};

  static SdApprovalDecision? fromJson(Object? json) {
    if (json is! Map || json['id'] is! int || json['accept'] is! bool) return null;
    final perms = json['perms'];
    return SdApprovalDecision(
      id: json['id'] as int,
      accept: json['accept'] as bool,
      perms: {for (final p in kSdApprovalPerms) p: perms is Map && perms[p] == true},
    );
  }
}

/// The chat text of one message: the mark, the kind, a colon and the JSON.
String sdApprovalText(String kind, Map<String, dynamic> json) => '$kSdApprovalMark$kind:${jsonEncode(json)}';

/// (kind, json) of an approval text; null when the text is an ordinary message (or cannot be read).
(String, Object?)? sdParseApprovalText(String text) {
  if (!text.startsWith(kSdApprovalMark)) return null;
  final rest = text.substring(kSdApprovalMark.length);
  final colon = rest.indexOf(':');
  if (colon <= 0) return null;
  try {
    return (rest.substring(0, colon), jsonDecode(rest.substring(colon + 1)));
  } catch (_) {
    return null;
  }
}

/// What a connection has now, by the names the host window's permission tiles use.
Map<String, bool> sdClientPerms(Client c) => {
      'keyboard': c.keyboard,
      'clipboard': c.clipboard,
      'file': c.file,
      'audio': c.audio,
      'restart': c.restart,
      'recording': c.recording,
      'block_input': c.blockInput,
      'privacy_mode': c.privacyMode,
    };

/// May this connection accept or refuse others? Only one that has a profile in Full access mode ([profiles] is the list the core sends).
bool sdMayApprove(Client c, List<SdProfile> profiles) {
  if (!c.authorized || c.disconnected || c.isFileTransfer || c.isViewCamera || c.isTerminal || c.portForward.isNotEmpty) return false;
  return profiles.any((p) => p.name == c.sdProfile && p.mode == kSdProfileFull);
}

/// Host side: tells the people who may approve about the requests that wait, and takes the request back when it was answered elsewhere.
class SdApprovalHub {
  final Set<(int, int)> _told = {};

  /// Call whenever a connection comes, is accepted, or goes. [send] gets (approver's connection id, chat text).
  void sync(List<Client> clients, {required bool Function(Client) mayApprove, required void Function(int approverId, String text) send}) {
    final waiting = clients.where((c) => !c.authorized && !c.disconnected).toList();
    final approvers = clients.where(mayApprove).toList();
    for (final a in approvers) {
      for (final w in waiting) {
        // a person is not asked about their own other connection
        if (w.id == a.id || w.peerId == a.peerId || _told.contains((a.id, w.id))) continue;
        _told.add((a.id, w.id));
        final req = SdApprovalRequest(
          id: w.id,
          name: w.name.isNotEmpty ? w.name : w.peerId,
          peerId: w.peerId,
          kind: w.isFileTransfer
              ? 'File transfer'
              : w.isViewCamera
                  ? 'View camera'
                  : w.isTerminal
                      ? 'Terminal'
                      : w.portForward.isNotEmpty
                          ? 'TCP tunneling'
                          : 'Remote control',
          perms: sdClientPerms(w),
        );
        send(a.id, sdApprovalText('request', req.toJson()));
      }
    }
    // answered (or gone): the question is taken off the screen of everyone who was asked
    for (final pair in _told.toList()) {
      final stillWaiting = waiting.any((w) => w.id == pair.$2);
      final approverHere = approvers.any((a) => a.id == pair.$1);
      if (!stillWaiting) {
        _told.remove(pair);
        if (approverHere) send(pair.$1, sdApprovalText('closed', {'id': pair.$2}));
      } else if (!approverHere) {
        _told.remove(pair);
      }
    }
  }
}

/// Host side: a decision came from connection [fromId]. Everything is checked here, not trusted: the sender must be allowed to approve, the request must
/// be open and be someone else's, and no permission is given that the sender does not have. Returns whether it was carried out.
bool sdApplyDecision({
  required List<Client> clients,
  required int fromId,
  required Object? json,
  required bool Function(Client) mayApprove,
  required void Function(Client target, bool accept) respond,
  required void Function(Client target, String name, bool enabled) setPermission,
}) {
  final d = SdApprovalDecision.fromJson(json);
  if (d == null) return false;
  Client? find(int id) {
    for (final c in clients) {
      if (c.id == id) return c;
    }
    return null;
  }

  final approver = find(fromId);
  final target = find(d.id);
  if (approver == null || target == null || !mayApprove(approver)) return false;
  if (target.authorized || target.disconnected || target.id == approver.id || target.peerId == approver.peerId) return false;
  if (!d.accept) {
    respond(target, false);
    return true;
  }
  // accepted first, then the permissions: nothing is changed on a connection that has not been let in
  respond(target, true);
  final own = sdClientPerms(approver);
  for (final name in kSdApprovalPerms) {
    setPermission(target, name, d.perms[name] == true && own[name] == true);
  }
  return true;
}

/// What the approver sees: who asks, what for, the permissions to give, and Accept / Dismiss. It draws and reports; sending is the caller's.
class SdApprovalView extends StatefulWidget {
  const SdApprovalView({super.key, required this.request, required this.onAccept, required this.onDismiss});
  final SdApprovalRequest request;
  final void Function(Map<String, bool> perms) onAccept;
  final VoidCallback onDismiss;

  @override
  State<SdApprovalView> createState() => _SdApprovalViewState();
}

class _SdApprovalViewState extends State<SdApprovalView> {
  late final Map<String, bool> _perms = {for (final p in kSdApprovalPerms) p: widget.request.perms[p] == true};

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final r = widget.request;
    final labels = {for (final p in sdProfilePerms) p.$1: p.$2};
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          SdMarkTile(child: SdIcon(SdIcons.shield, size: 26, color: const Color(0xFFF3E2B8), stroke: 1.9)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Someone wants to connect', style: sdTs(21, FontWeight.w600, t.ink, ls: -0.21)),
              Padding(padding: const EdgeInsets.only(top: 2), child: Text('${r.name} · ${r.peerId} · ${r.kind}', maxLines: 2, overflow: TextOverflow.ellipsis, style: sdTs(14, FontWeight.w400, t.mut))),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Text('What they are allowed to do', style: sdTs(13.5, FontWeight.w400, t.mut)),
        const SizedBox(height: 4),
        Flexible(
          child: SingleChildScrollView(
            child: Column(children: [
              for (final p in kSdApprovalPerms)
                SdToggleRow(key: ValueKey('sd-approval-$p'), label: labels[p] ?? p, value: _perms[p] == true, onChanged: (v) => setState(() => _perms[p] = v)),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          SdButton(label: 'Dismiss', onTap: widget.onDismiss),
          const SizedBox(width: 10),
          SdButton(label: 'Accept', kind: SdBtnKind.gold, onTap: () => widget.onAccept(Map.of(_perms))),
        ]),
      ],
    );
  }
}

String _tag(int id) => 'sd-approval-$id';

/// Controller side: the host asked about [request]. Shown over the session; the answer goes back through the chat.
void sdShowApproval(FFI ffi, SdApprovalRequest request) {
  void answer(SdApprovalDecision d, void Function() close) {
    bind.sessionSendChat(sessionId: ffi.sessionId, text: sdApprovalText('decision', d.toJson()));
    close();
  }

  ffi.dialogManager.show((setState, close, context) {
    return SdModal(
      maxWidth: 480,
      onCancel: () => answer(SdApprovalDecision(id: request.id, accept: false), close),
      content: SdApprovalView(
        request: request,
        onAccept: (perms) => answer(SdApprovalDecision(id: request.id, accept: true, perms: perms), close),
        onDismiss: () => answer(SdApprovalDecision(id: request.id, accept: false), close),
      ),
    );
  }, tag: _tag(request.id));
}

/// Controller side: the request was answered by someone else (or the person left): the question goes.
void sdCloseApproval(FFI ffi, int id) => ffi.dialogManager.dismissByTag(_tag(id));

/// A chat text that starts with the mark came in. [fromHost]: it is the host speaking to this controller (a `request` or a `closed`); otherwise it is a
/// controller speaking to this host, [from] being its connection (a `decision`).
void sdHandleApprovalMessage(FFI session, {required bool fromHost, required int from, required String kind, required Object? json}) {
  if (fromHost) {
    if (kind == 'request') {
      final r = SdApprovalRequest.fromJson(json);
      if (r != null) sdShowApproval(session, r);
    } else if (kind == 'closed' && json is Map && json['id'] is int) {
      sdCloseApproval(session, json['id'] as int);
    }
  } else if (kind == 'decision') {
    session.serverModel.sdOnApprovalDecision(from, json);
  }
}
