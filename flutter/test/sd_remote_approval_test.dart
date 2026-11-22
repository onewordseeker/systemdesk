import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/models/server_model.dart' show Client;
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_profiles.dart';
import 'package:flutter_hbb/screens/sd_remote_approval.dart';
import 'package:flutter_hbb/screens/sd_tone.dart' show SdBackdrop;
import 'package:flutter_test/flutter_test.dart';

Future<void> _font(String family, List<String> files, String dir) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(File('$dir$f').readAsBytesSync()).buffer)));
  }
  await loader.load();
}

Client _client(int id, String peer, {bool authorized = true, String profile = '', bool all = true, bool disconnected = false}) {
  final c = Client(id, authorized, false, false, 'name-$id', peer, all, all, all);
  c.file = all;
  c.restart = all;
  c.recording = all;
  c.blockInput = all;
  c.privacyMode = all;
  c.sdProfile = profile;
  c.disconnected = disconnected;
  c.portForward = '';
  return c;
}

final _profiles = sdParseProfiles('[{"name":"Full Access","mode":"full"},{"name":"Default","mode":"custom"},{"name":"Support","mode":"custom"}]');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => _font('Inter', ['Inter-Regular.ttf', 'Inter-Medium.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf'], 'assets/fonts/'));
  tearDown(() => SdLook.debugEnabled = null);

  group('the messages', () {
    test('a request and a decision survive the trip through a chat text', () {
      final req = SdApprovalRequest(id: 7, name: 'Ali', peerId: '123456', kind: 'Remote control', perms: {'keyboard': true, 'audio': true});
      final parsed = sdParseApprovalText(sdApprovalText('request', req.toJson()))!;
      expect(parsed.$1, 'request');
      final back = SdApprovalRequest.fromJson(parsed.$2)!;
      expect((back.id, back.name, back.peerId, back.kind), (7, 'Ali', '123456', 'Remote control'));
      expect(back.perms['keyboard'], true);
      expect(back.perms['file'], false, reason: 'what is not said is off');
      final d = SdApprovalDecision.fromJson(sdParseApprovalText(sdApprovalText('decision', const SdApprovalDecision(id: 7, accept: true, perms: {'file': true}).toJson()))!.$2)!;
      expect((d.id, d.accept, d.perms['file']), (7, true, true));
    });

    test('an ordinary chat text, and a damaged one, are not approval messages', () {
      expect(sdParseApprovalText('hello'), isNull);
      expect(sdParseApprovalText('${kSdApprovalMark}request'), isNull);
      expect(sdParseApprovalText('${kSdApprovalMark}request:{broken'), isNull);
      expect(SdApprovalDecision.fromJson({'id': 'x', 'accept': true}), isNull);
      expect(SdApprovalDecision.fromJson({'id': 3}), isNull);
      expect(SdApprovalRequest.fromJson('text'), isNull);
    });
  });

  group('who may approve', () {
    test('only a connection that is in, with a profile in Full access mode', () {
      expect(sdMayApprove(_client(1, 'a', profile: 'Full Access'), _profiles), true);
      expect(sdMayApprove(_client(1, 'a', profile: 'Default'), _profiles), false);
      expect(sdMayApprove(_client(1, 'a', profile: 'Support'), _profiles), false);
      expect(sdMayApprove(_client(1, 'a', profile: ''), _profiles), false, reason: 'a core that did not name the profile');
      expect(sdMayApprove(_client(1, 'a', profile: 'Full Access', authorized: false), _profiles), false, reason: 'not let in yet');
      expect(sdMayApprove(_client(1, 'a', profile: 'Full Access', disconnected: true), _profiles), false);
      expect(sdMayApprove(_client(1, 'a', profile: 'Nobody'), _profiles), false);
    });
  });

  group('the host tells the approvers, and takes the question back', () {
    test('a waiting request goes to every approver once, and never to the person who asks', () {
      final admin = _client(1, 'admin', profile: 'Full Access');
      final other = _client(2, 'other', profile: 'Default');
      final waiting = _client(3, 'guest', authorized: false);
      final hub = SdApprovalHub();
      final sent = <(int, String)>[];
      void sync(List<Client> all) => hub.sync(all, mayApprove: (c) => sdMayApprove(c, _profiles), send: (id, text) => sent.add((id, text)));
      sync([admin, other, waiting]);
      expect(sent.length, 1);
      expect(sent.single.$1, 1, reason: 'only the one with Full access is asked');
      final req = SdApprovalRequest.fromJson(sdParseApprovalText(sent.single.$2)!.$2)!;
      expect((req.id, req.peerId), (3, 'guest'));
      // again: not twice
      sync([admin, other, waiting]);
      expect(sent.length, 1);
      // the same person on another connection of their own is not asked about themselves
      final mine = _client(4, 'admin', authorized: false);
      sync([admin, other, waiting, mine]);
      expect(sent.length, 1);
    });

    test('an approver who comes later is told about what is already waiting; an answered request is taken back', () {
      final waiting = _client(3, 'guest', authorized: false);
      final hub = SdApprovalHub();
      final sent = <(int, String)>[];
      void sync(List<Client> all) => hub.sync(all, mayApprove: (c) => sdMayApprove(c, _profiles), send: (id, text) => sent.add((id, text)));
      sync([waiting]);
      expect(sent, isEmpty, reason: 'nobody to ask');
      final admin = _client(1, 'admin', profile: 'Full Access');
      sync([admin, waiting]);
      expect(sent.length, 1);
      // the host answered it on its own screen: the approver's question goes
      waiting.authorized = true;
      sync([admin, waiting]);
      expect(sent.length, 2);
      expect(sdParseApprovalText(sent.last.$2)!.$1, 'closed');
    });
  });

  group('the decision is checked on the host', () {
    late Client admin, guest, small;
    late List<String> log;
    setUp(() {
      admin = _client(1, 'admin', profile: 'Full Access');
      guest = _client(3, 'guest', authorized: false, all: false);
      small = _client(2, 'small', profile: 'Support');
      log = [];
    });

    bool decide(List<Client> all, int from, Object? json) => sdApplyDecision(
          clients: all,
          fromId: from,
          json: json,
          mayApprove: (c) => sdMayApprove(c, _profiles),
          respond: (c, accept) => log.add('respond ${c.id} $accept'),
          setPermission: (c, name, on) => log.add('$name ${c.id} $on'),
        );

    test('accepted: the person is let in first, then the permissions are set', () {
      expect(decide([admin, guest], 1, {'id': 3, 'accept': true, 'perms': {'keyboard': true, 'audio': true}}), true);
      expect(log.first, 'respond 3 true');
      expect(log.contains('keyboard 3 true') && log.contains('audio 3 true') && log.contains('file 3 false'), true);
      expect(log.length, 1 + kSdApprovalPerms.length, reason: 'every permission is set, on or off');
    });

    test('dismissed: refused, nothing else', () {
      expect(decide([admin, guest], 1, {'id': 3, 'accept': false}), true);
      expect(log, ['respond 3 false']);
    });

    test('nobody can give what they do not have themselves', () {
      final limited = _client(5, 'half', profile: 'Full Access', all: false)..keyboard = true;
      expect(decide([limited, guest], 5, {'id': 3, 'accept': true, 'perms': {for (final p in kSdApprovalPerms) p: true}}), true);
      expect(log.contains('keyboard 3 true'), true);
      expect(log.where((l) => l.endsWith('true') && !l.startsWith('respond') && !l.startsWith('keyboard')), isEmpty);
    });

    test('a connection without Full access, an unknown or answered request, oneself and damaged messages change nothing', () {
      expect(decide([small, guest], 2, {'id': 3, 'accept': true}), false);
      expect(decide([admin, guest], 1, {'id': 99, 'accept': true}), false);
      expect(decide([admin, guest], 99, {'id': 3, 'accept': true}), false);
      final done = _client(6, 'done');
      expect(decide([admin, done], 1, {'id': 6, 'accept': true}), false, reason: 'already in');
      expect(decide([admin, guest], 1, {'id': 1, 'accept': true}), false, reason: 'not oneself');
      final sameEnd = _client(7, 'admin', authorized: false);
      expect(decide([admin, sameEnd], 1, {'id': 7, 'accept': true}), false, reason: 'the same person on another connection');
      expect(decide([admin, guest], 1, 'text'), false);
      expect(decide([admin, guest], 1, {'id': 3}), false);
      expect(log, isEmpty);
    });
  });

  group('what the approver sees', () {
    Future<void> show(WidgetTester tester, SdApprovalRequest r, {required void Function(Map<String, bool>) onAccept, required VoidCallback onDismiss}) async {
      SdLook.debugEnabled = true;
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SdBackdrop(child: SdApprovalView(request: r, onAccept: onAccept, onDismiss: onDismiss)))));
      await tester.pump(const Duration(milliseconds: 300));
    }

    const req = SdApprovalRequest(id: 3, name: 'Ali', peerId: '123456', kind: 'Remote control', perms: {'keyboard': true, 'clipboard': true});

    testWidgets('who asks, for what, and the permissions the computer would give; Accept sends them as they are', (tester) async {
      Map<String, bool>? got;
      await show(tester, req, onAccept: (p) => got = p, onDismiss: () => fail('not dismissed'));
      expect(find.text('Someone wants to connect'), findsOneWidget);
      expect(find.textContaining('Ali · 123456 · Remote control'), findsOneWidget);
      await tester.tap(find.text('Accept'));
      expect(got!['keyboard'], true);
      expect(got!['file'], false);
    });

    testWidgets('a switch changed before Accept is what is sent; Dismiss does not accept', (tester) async {
      Map<String, bool>? got;
      var dismissed = 0;
      await show(tester, req, onAccept: (p) => got = p, onDismiss: () => dismissed++);
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('sd-approval-file')), matching: find.byType(SdOnOff)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Accept'));
      expect(got!['file'], true);
      await tester.tap(find.text('Dismiss'));
      expect(dismissed, 1);
    });
  });
}
