import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_modal.dart';
import 'package:flutter_hbb/screens/sd_signin_modal.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';

/// "Which Windows session?" in the new design: a Windows computer can have several people signed in at once (the one at its own screen, others through
/// Remote Desktop). The computer sends the list of the sessions that are active; the person picks one and connects to it, or cancels.
class SdWindowsSession {
  const SdWindowsSession({required this.sid, required this.kind, this.user = '', this.running = false, this.sidNote = ''});

  /// the Windows session number, as the computer wants it back
  final String sid;

  /// Console, RDP, ICA (as the computer names them)
  final String kind;
  final String user;

  /// the session SystemDesk is showing right now
  final bool running;

  /// "sid = 3": the computer adds it when two sessions would be called the same
  final String sidNote;

  /// The computer names a session "Console", "Console: Ahmed", "RDP: Admin", "RDP: Admin (sid = 3)", and adds " (running)" to the one in use.
  factory SdWindowsSession.parse(String sid, String name) {
    var rest = name.trim();
    var running = false;
    if (rest.endsWith('(running)')) {
      running = true;
      rest = rest.substring(0, rest.length - '(running)'.length).trim();
    }
    var note = '';
    final m = RegExp(r'\s*\(sid = (\d+)\)$').firstMatch(rest);
    if (m != null) {
      note = 'Session ${m.group(1)}';
      rest = rest.substring(0, m.start).trim();
    }
    final colon = rest.indexOf(':');
    final kind = colon < 0 ? rest : rest.substring(0, colon).trim();
    final user = colon < 0 ? '' : rest.substring(colon + 1).trim();
    return SdWindowsSession(sid: sid, kind: kind, user: user, running: running, sidNote: note);
  }

  bool get isConsole => kind.toLowerCase() == 'console';

  String get title {
    switch (kind.toLowerCase()) {
      case 'console':
        return 'Console';
      case 'rdp':
        return 'Remote Desktop';
      case 'ica':
        return 'Citrix';
      default:
        return kind.isEmpty ? 'Session $sid' : kind;
    }
  }

  /// who is in it, and what it is
  String get detail {
    if (isConsole) return user.isEmpty ? 'The screen of this computer · nobody is signed in' : '$user · the screen of this computer';
    return user.isEmpty ? 'A remote session' : '$user · a remote session';
  }
}

/// The sessions in the JSON the computer sends (`[{sid, name}]`); a list that cannot be read is empty.
List<SdWindowsSession> sdParseWindowsSessions(String json) {
  try {
    final list = jsonDecode(json);
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map && e['sid'] != null) SdWindowsSession.parse('${e['sid']}', '${e['name'] ?? ''}'),
    ];
  } catch (_) {
    return const [];
  }
}

/// What a person sees: the options, and Cancel / Connect. It draws and nothing else.
class SdSessionPickerView extends StatelessWidget {
  const SdSessionPickerView({super.key, required this.sessions, required this.selected, required this.onSelect, required this.onConnect, required this.onCancel});
  final List<SdWindowsSession> sessions;

  /// the sid of the option that is chosen
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onConnect, onCancel;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          SdMarkTile(child: SdIcon(SdIcons.monitor, size: 26, color: const Color(0xFFF3E2B8), stroke: 1.9)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Choose a session', style: sdTs(21, FontWeight.w600, t.ink, ls: -0.21)),
              Padding(padding: const EdgeInsets.only(top: 2), child: Text('More than one person is signed in here.', style: sdTs(14.5, FontWeight.w400, t.mut))),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        for (var i = 0; i < sessions.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _SessionRow(session: sessions[i], selected: sessions[i].sid == selected, onTap: () => onSelect(sessions[i].sid)),
        ],
        const SizedBox(height: 22),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          SdButton(label: 'Cancel', onTap: onCancel),
          const SizedBox(width: 10),
          SdButton(label: 'Connect', kind: SdBtnKind.gold, onTap: onConnect),
        ]),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.selected, required this.onTap});
  final SdWindowsSession session;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: ValueKey('sd-session-${session.sid}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? t.goldSoft : t.pa,
            border: Border.all(color: selected ? t.goldB : t.line2, width: selected ? 1.5 : 1),
          ),
          child: Row(children: [
            // the radio: an empty ring, or a ring with a dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? t.goldB : t.line2, width: 1.8), color: t.pa),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: selected ? 10 : 0,
                height: selected ? 10 : 0,
                decoration: BoxDecoration(shape: BoxShape.circle, color: t.goldB),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(session.title, style: sdTs(15.5, FontWeight.w600, t.ink)),
                const SizedBox(height: 2),
                Text(session.detail, style: sdTs(13.5, FontWeight.w400, t.mut)),
              ]),
            ),
            if (session.running) ...[
              const SizedBox(width: 10),
              const SdTag('In use now', kind: SdTagKind.ok),
            ] else if (session.sidNote.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(session.sidNote, style: sdTs(12.5, FontWeight.w400, t.mut)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// The choice with its own state: it starts on the session in use now, or the first.
class SdSessionPicker extends StatefulWidget {
  const SdSessionPicker({super.key, required this.sessions, required this.onConnect, required this.onCancel});
  final List<SdWindowsSession> sessions;
  final ValueChanged<String> onConnect;
  final VoidCallback onCancel;

  @override
  State<SdSessionPicker> createState() => _SdSessionPickerState();
}

class _SdSessionPickerState extends State<SdSessionPicker> {
  late String _selected = (widget.sessions.where((s) => s.running).firstOrNull ?? widget.sessions.first).sid;

  @override
  Widget build(BuildContext context) {
    return SdSessionPickerView(
      sessions: widget.sessions,
      selected: _selected,
      onSelect: (sid) => setState(() => _selected = sid),
      onConnect: () => widget.onConnect(_selected),
      onCancel: widget.onCancel,
    );
  }
}

/// New look: asks which session to connect to. Connect tells the computer; Cancel ends the connection (the stock dialog had no Cancel: closing it left a
/// black screen, so a Cancel here closes the connection).
void sdShowWindowsSessions(OverlayDialogManager dialogManager, SessionID sessionId, String sessionsJson) {
  final sessions = sdParseWindowsSessions(sessionsJson);
  if (sessions.isEmpty) return;
  dialogManager.dismissAll();
  dialogManager.show((setState, close, context) {
    connect(String sid) {
      bind.sessionSendSelectedSessionId(sessionId: sessionId, sid: sid);
      close();
    }

    cancel() {
      close();
      closeConnection();
    }

    return SdModal(
      maxWidth: 480,
      onCancel: cancel,
      content: SdSessionPicker(sessions: sessions, onConnect: connect, onCancel: cancel),
    );
  }, tag: 'sd-windows-sessions');
}
