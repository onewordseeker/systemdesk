import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/screens/sd_look.dart';

/// One session this computer took part in, as the Sessions page lists it.
class SdSessionEntry {
  SdSessionEntry({
    required this.key,
    required this.incoming,
    required this.peerId,
    required this.name,
    required this.kind,
    required this.startedAt,
    this.endedAt,
    this.seenAt,
  });

  /// unique per session (the window's session id, or the connection number on the host side)
  final String key;
  final bool incoming;
  final String peerId, kind;
  String name;
  final DateTime startedAt;
  DateTime? endedAt;

  /// the owner of an open session writes this every few seconds: a session that is "open" but not seen for 90 s is a left-over of a crash
  DateTime? seenAt;

  bool isLive(DateTime now) => endedAt == null && seenAt != null && now.difference(seenAt!).inSeconds < 90;

  Duration length([DateTime? now]) => (endedAt ?? now ?? DateTime.now()).difference(startedAt);

  Map<String, dynamic> toJson() => {
        'k': key,
        'in': incoming,
        'p': peerId,
        'n': name,
        'kind': kind,
        's': startedAt.millisecondsSinceEpoch,
        if (endedAt != null) 'e': endedAt!.millisecondsSinceEpoch,
        if (seenAt != null) 'a': seenAt!.millisecondsSinceEpoch,
      };

  static SdSessionEntry? fromJson(dynamic j) {
    try {
      final m = j as Map;
      return SdSessionEntry(
        key: m['k'] as String,
        incoming: m['in'] == true,
        peerId: (m['p'] ?? '') as String,
        name: (m['n'] ?? '') as String,
        kind: (m['kind'] ?? 'Remote control') as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(m['s'] as int),
        endedAt: m['e'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['e'] as int),
        seenAt: m['a'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['a'] as int),
      );
    } catch (_) {
      return null;
    }
  }
}

/// The log of the sessions of this computer, kept in one local option (shared by every window of the app, since the window that hosts a session and the
/// window that lists it are different processes). It is written only in the new look: with the switch off nothing here does anything, and nothing here
/// can fail a session (every call swallows its errors).
class SdSessionLog {
  SdSessionLog._();

  static const _kOption = 'sd_session_log';
  static const _kEndOption = 'sd_end_requests';
  static const kKept = 60;

  /// sessions shorter than this never started: the other side said no, or the connection broke at once
  static const kMinLength = Duration(seconds: 4);

  static final Map<String, Timer> _beats = {};
  static final Map<String, VoidCallback> _ends = {};

  static List<SdSessionEntry> read() {
    try {
      final stored = bind.mainGetLocalOption(key: _kOption);
      if (stored.isEmpty) return [];
      final list = jsonDecode(stored) as List;
      return [for (final j in list) if (SdSessionEntry.fromJson(j) != null) SdSessionEntry.fromJson(j)!];
    } catch (_) {
      return [];
    }
  }

  static void _write(List<SdSessionEntry> entries) {
    entries.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final kept = entries.length > kKept ? entries.sublist(0, kKept) : entries;
    bind.mainSetLocalOption(key: _kOption, value: jsonEncode([for (final e in kept) e.toJson()]));
  }

  /// [onEnd]: what closes this session; the Sessions page can ask for it from another window (see [requestEnd]).
  static void start({
    required String key,
    required bool incoming,
    required String peerId,
    required String name,
    required String kind,
    VoidCallback? onEnd,
  }) {
    if (!SdLook.enabled) return;
    try {
      final all = read();
      if (all.any((e) => e.key == key && e.endedAt == null)) return;
      final now = DateTime.now();
      all.add(SdSessionEntry(key: key, incoming: incoming, peerId: peerId, name: name, kind: kind, startedAt: now, seenAt: now));
      _write(all);
      _beats[key]?.cancel();
      if (onEnd != null) _ends[key] = onEnd;
      _beats[key] = Timer.periodic(const Duration(seconds: 3), (_) => _beat(key));
    } catch (e) {
      debugPrint('SdSessionLog.start: $e');
    }
  }

  static void _beat(String key) {
    try {
      final all = read();
      for (final e in all) {
        if (e.key == key && e.endedAt == null) e.seenAt = DateTime.now();
      }
      _write(all);
      final asked = _readEnds();
      if (asked.contains(key)) {
        asked.remove(key);
        bind.mainSetLocalOption(key: _kEndOption, value: asked.join(','));
        _ends[key]?.call();
      }
    } catch (_) {}
  }

  static List<String> _readEnds() => bind.mainGetLocalOption(key: _kEndOption).split(',').where((s) => s.isNotEmpty).toList();

  /// Asks the window that owns the session [key] to end it (it looks every three seconds).
  static void requestEnd(String key) {
    if (!SdLook.enabled) return;
    try {
      final asked = _readEnds();
      if (!asked.contains(key)) asked.add(key);
      bind.mainSetLocalOption(key: _kEndOption, value: asked.join(','));
    } catch (_) {}
  }

  /// [established] false: the session never really started, so it is left out of the history.
  static void end({required String key, String? name, bool established = true}) {
    if (!SdLook.enabled) return;
    try {
      _beats.remove(key)?.cancel();
      _ends.remove(key);
      final all = read();
      final now = DateTime.now();
      for (final e in List.of(all)) {
        if (e.key != key || e.endedAt != null) continue;
        if (!established || now.difference(e.startedAt) < kMinLength) {
          all.remove(e);
        } else {
          e.endedAt = now;
          if (name != null && name.isNotEmpty) e.name = name;
        }
      }
      _write(all);
    } catch (e) {
      debugPrint('SdSessionLog.end: $e');
    }
  }
}
