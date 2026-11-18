import 'dart:convert';

import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/services/app_notices.dart';
import 'package:get/get.dart';

/// One announcement in the inbox: the message and when this computer first heard of it.
class InboxItem {
  const InboxItem(this.message, this.at);
  final AppMessage message;
  final DateTime at;
}

/// The announcements the administrators sent (console > Messages), kept as a list of notifications under the bell of the title bar instead of
/// being thrown at the person as dialogs. The list is what the license server's last answer said is active, with the time each one first arrived;
/// it is remembered between runs, so a message is still there after a restart or while offline. A message is "read" once the person has opened
/// the bell with it in the list (the ids are kept in the same option the dialogs used, so nothing is shown twice).
class AppInbox {
  AppInbox({required String Function(String) read, required void Function(String, String) write})
      : _read = read,
        _write = write;

  static final instance = AppInbox(
    read: (k) => bind.mainGetLocalOption(key: k),
    write: (k, v) => bind.mainSetLocalOption(key: k, value: v),
  );

  static const _kInbox = 'sd_inbox';
  static const _kSeen = 'sd_seen_messages';
  static const kKept = 30;

  final String Function(String) _read;
  final void Function(String, String) _write;

  /// newest first
  final items = <InboxItem>[].obs;

  /// how many of [items] have not been read
  final unread = 0.obs;

  /// counts up when something must be put in front of the person (a critical message): the bell opens its panel
  final openRequest = 0.obs;

  Set<String> _seenIds() => _read(_kSeen).split(',').where((s) => s.isNotEmpty).toSet();

  bool isRead(String id) => _seenIds().contains(id);

  void _recount() => unread.value = items.where((i) => !_seenIds().contains(i.message.id)).length;

  /// Brings back what was remembered.
  void load() {
    items.value = _decode(_read(_kInbox));
    _recount();
  }

  static List<InboxItem> _decode(String stored) {
    if (stored.isEmpty) return const [];
    try {
      final json = jsonDecode(stored);
      if (json is! List) return const [];
      final out = <InboxItem>[];
      for (final m in json) {
        if (m is! Map) continue;
        final msg = AppMessage.listFrom([m]);
        if (msg.isEmpty) continue;
        final at = m['at'] is int ? DateTime.fromMillisecondsSinceEpoch(m['at'] as int) : DateTime.now();
        out.add(InboxItem(msg.first, at));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  String _encode() => jsonEncode([
        for (final i in items)
          {'id': i.message.id, 'title': i.message.title, 'body': i.message.body, 'severity': i.message.severity, 'at': i.at.millisecondsSinceEpoch}
      ]);

  /// Takes what the license server says is active now. A message the inbox does not have yet and the person has not seen (the dialogs of older
  /// versions remember theirs in the same place) is added at the top; everything already in the list stays, even when the administrators
  /// withdraw the message later, so a notification does not vanish while it is being read. Returns the messages that were added, in the order
  /// the server sent them.
  List<AppMessage> receive(List<AppMessage> active, {DateTime? now}) {
    final when = now ?? DateTime.now();
    final known = {for (final i in items) i.message.id: i};
    final seen = _seenIds();
    final added = <InboxItem>[];
    final refreshed = <String, AppMessage>{};
    for (final m in active) {
      if (known.containsKey(m.id)) {
        refreshed[m.id] = m; // the administrators edited it
      } else if (!seen.contains(m.id)) {
        added.add(InboxItem(m, when));
      }
    }
    if (added.isEmpty && refreshed.isEmpty) return const [];
    final next = [
      ...added.reversed, // newest on top: the server sends oldest first
      for (final i in items) refreshed.containsKey(i.message.id) ? InboxItem(refreshed[i.message.id]!, i.at) : i,
    ];
    items.value = next.length > kKept ? next.sublist(0, kKept) : next;
    _write(_kInbox, _encode());
    _recount();
    return [for (final i in added) i.message];
  }

  /// The person has looked at the list: everything in it counts as read.
  void markAllRead() {
    if (unread.value == 0) return;
    var seen = _read(_kSeen);
    for (final i in items.reversed) {
      seen = rememberSeen(seen, i.message.id);
    }
    _write(_kSeen, seen);
    _recount();
  }

  /// Empties the list. The messages count as read, so they do not come back while the administrators still list them.
  void clear() {
    markAllRead();
    items.value = [];
    _write(_kInbox, _encode());
    _recount();
  }
}

/// "just now", "5 min ago", "3 h ago", "2 d ago", then the date.
String timeAgo(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 14) return '${d.inDays} d ago';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[at.month - 1]} ${at.day}';
}
