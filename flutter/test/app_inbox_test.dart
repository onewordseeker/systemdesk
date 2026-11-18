import 'package:flutter_hbb/services/app_inbox.dart';
import 'package:flutter_hbb/services/app_notices.dart';
import 'package:flutter_test/flutter_test.dart';

AppMessage _m(String id, {String severity = 'info'}) => AppMessage(id: id, title: 'Title $id', body: 'Body $id', severity: severity);

/// An inbox that keeps its options in a map, so a second inbox on the same map is "the next run of the app".
AppInbox _inbox(Map<String, String> store) => AppInbox(read: (k) => store[k] ?? '', write: (k, v) => store[k] = v);

void main() {
  test('a new message lands at the top and counts as unread', () {
    final store = <String, String>{};
    final inbox = _inbox(store);
    final added = inbox.receive([_m('a'), _m('b')], now: DateTime(2026, 11, 19, 9));
    expect([for (final m in added) m.id], ['a', 'b']);
    // the server sends the oldest first, the list shows the newest first
    expect([for (final i in inbox.items) i.message.id], ['b', 'a']);
    expect(inbox.unread.value, 2);
  });

  test('a message that is already in the list is not added again, an edited one is refreshed', () {
    final inbox = _inbox({});
    inbox.receive([_m('a')], now: DateTime(2026, 11, 19, 9));
    final again = inbox.receive([_m('a')], now: DateTime(2026, 11, 19, 10));
    expect(again, isEmpty);
    expect(inbox.items.length, 1);
    inbox.receive([const AppMessage(id: 'a', title: 'New title', body: 'Body a')], now: DateTime(2026, 11, 19, 11));
    expect(inbox.items.single.message.title, 'New title');
    expect(inbox.items.single.at, DateTime(2026, 11, 19, 9));
  });

  test('a message stays in the list after the administrators withdraw it', () {
    final inbox = _inbox({});
    inbox.receive([_m('a'), _m('b')]);
    inbox.receive([_m('b')]);
    expect(inbox.items.length, 2);
  });

  test('opening the list marks everything read, and it stays read', () {
    final store = <String, String>{};
    final inbox = _inbox(store);
    inbox.receive([_m('a'), _m('b')]);
    inbox.markAllRead();
    expect(inbox.unread.value, 0);
    expect(inbox.isRead('a'), isTrue);
    expect(inbox.isRead('b'), isTrue);
    expect(inbox.receive([_m('a')]), isEmpty);
    expect(inbox.unread.value, 0);
  });

  test('what was heard is still there in the next run', () {
    final store = <String, String>{};
    _inbox(store).receive([_m('a'), _m('b')], now: DateTime(2026, 11, 19, 9));
    final next = _inbox(store)..load();
    expect([for (final i in next.items) i.message.id], ['b', 'a']);
    expect(next.items.first.at, DateTime(2026, 11, 19, 9));
    expect(next.unread.value, 2);
  });

  test('clearing empties the list and the messages do not come back', () {
    final store = <String, String>{};
    final inbox = _inbox(store);
    inbox.receive([_m('a')]);
    inbox.clear();
    expect(inbox.items, isEmpty);
    expect(inbox.unread.value, 0);
    expect(inbox.receive([_m('a')]), isEmpty);
    expect(inbox.items, isEmpty);
    expect((_inbox(store)..load()).items, isEmpty);
  });

  test('a message the person saw in a dialog of an older version is not added', () {
    final store = <String, String>{'sd_seen_messages': 'a'};
    final inbox = _inbox(store);
    expect([for (final m in inbox.receive([_m('a'), _m('b')])) m.id], ['b']);
  });

  test('only the newest ${AppInbox.kKept} are kept', () {
    final inbox = _inbox({});
    inbox.receive([for (var i = 0; i < AppInbox.kKept + 5; i++) _m('m$i')]);
    expect(inbox.items.length, AppInbox.kKept);
    expect(inbox.items.first.message.id, 'm${AppInbox.kKept + 4}');
  });

  test('damaged stored data gives an empty list, not a crash', () {
    expect((_inbox({'sd_inbox': 'not json'})..load()).items, isEmpty);
    expect((_inbox({'sd_inbox': '{"a":1}'})..load()).items, isEmpty);
  });

  test('how long ago', () {
    final now = DateTime(2026, 11, 19, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 20)), now), 'just now');
    expect(timeAgo(now.subtract(const Duration(minutes: 5)), now), '5 min ago');
    expect(timeAgo(now.subtract(const Duration(hours: 3)), now), '3 h ago');
    expect(timeAgo(now.subtract(const Duration(days: 2)), now), '2 d ago');
    expect(timeAgo(DateTime(2026, 10, 1), now), 'Oct 1');
  });
}
