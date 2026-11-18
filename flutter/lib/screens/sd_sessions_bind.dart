import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_sessions.dart';
import 'package:flutter_hbb/screens/sd_shell.dart';
import 'package:flutter_hbb/services/account_summary.dart';
import 'package:flutter_hbb/services/license_service.dart';
import 'package:flutter_hbb/services/session_log.dart';
import 'package:get/get.dart';

const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

String _two(int n) => n.toString().padLeft(2, '0');

/// "12:04" for a session that has run twelve minutes and four seconds.
String sdClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60, s = d.inSeconds % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '${_two(m)}:${_two(s)}';
}

/// "12 min", "1 h 05 min", "<1 min".
String sdLength(Duration d) {
  if (d.inSeconds < 60) return '<1 min';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  return '${d.inHours} h ${_two(d.inMinutes % 60)} min';
}

/// "Today, 14:08", "Yesterday, 17:30", "Mon, 09:12", "Nov 12, 09:12".
String sdWhen(DateTime at, DateTime now) {
  final clock = '${_two(at.hour)}:${_two(at.minute)}';
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today, $clock';
  if (diff == 1) return 'Yesterday, $clock';
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  if (diff > 0 && diff < 7) return '${names[at.weekday - 1]}, $clock';
  return '${months[at.month - 1]} ${at.day}, $clock';
}

/// The minutes of the last seven (UTC) days, oldest first, from the account's usage answer; null when the answer has no days.
List<SdDayBar>? sdDaysFromUsage(Map<String, dynamic>? usage, DateTime now) {
  final devices = usage?['devices'];
  if (devices is! List) return null;
  final perDay = <String, double>{};
  var any = false;
  for (final d in devices) {
    final days = (d is Map) ? d['days'] : null;
    if (days is! List) continue;
    for (final x in days) {
      if (x is! Map) continue;
      any = true;
      perDay[x['date'].toString()] = (perDay[x['date'].toString()] ?? 0) + (x['minutes'] is num ? (x['minutes'] as num).toDouble() : 0);
    }
  }
  if (!any) return null;
  final utc = now.toUtc();
  return [
    for (var i = 6; i >= 0; i--)
      () {
        final d = DateTime.utc(utc.year, utc.month, utc.day).subtract(Duration(days: i));
        final key = '${d.year}-${_two(d.month)}-${_two(d.day)}';
        return SdDayBar(_weekdays[d.weekday - 1], perDay[key] ?? 0, today: i == 0);
      }(),
  ];
}

/// The same bars from this computer's own log (when the account's answer is not there).
List<SdDayBar> sdDaysFromLog(List<SdSessionEntry> log, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return [
    for (var i = 6; i >= 0; i--)
      () {
        final d = today.subtract(Duration(days: i));
        var minutes = 0.0;
        for (final e in log) {
          if (e.endedAt == null) continue;
          final s = DateTime(e.startedAt.year, e.startedAt.month, e.startedAt.day);
          if (s == d) minutes += e.length().inSeconds / 60;
        }
        return SdDayBar(_weekdays[d.weekday - 1], minutes, today: i == 0);
      }(),
  ];
}

/// The Sessions page of the window: today's ring and the week from the account, who is connected now and the history from the log of this computer.
class SdSessions extends StatefulWidget {
  const SdSessions({super.key});

  @override
  State<SdSessions> createState() => _SdSessionsState();
}

class _SdSessionsState extends State<SdSessions> {
  String _filter = 'all';
  Map<String, dynamic>? _usage;
  Timer? _tick, _fetch;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() {});
    });
    _load();
    _fetch = Timer.periodic(const Duration(minutes: 1), (_) => _load());
  }

  Future<void> _load() async {
    if (!LicenseService.instance.isLoggedIn) return;
    final u = await LicenseService.instance.getDeviceUsage();
    if (mounted && u != null) setState(() => _usage = u);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _fetch?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final info = AccountSummary.instance.info.value;
      final signedIn = LicenseService.instance.isLoggedInRx.value;
      final now = DateTime.now();
      final log = SdSessionLog.read();
      final used = info?.usedToday ?? 0;
      final limit = info?.dailyLimit ?? 0;
      final days = (signedIn ? sdDaysFromUsage(_usage, now) : null) ?? sdDaysFromLog(log, now);
      final week = days.fold<double>(0, (s, d) => s + d.minutes);
      final localToday = log.where((e) => e.endedAt != null || e.isLive(now)).where((e) {
        final s = e.startedAt;
        return s.year == now.year && s.month == now.month && s.day == now.day;
      }).length;
      var sessionsToday = localToday;
      final devices = _usage?['devices'];
      if (signedIn && devices is List) {
        var n = 0;
        for (final d in devices) {
          if (d is! Map) continue;
          final periods = d['periods'];
          if (periods is! Map) continue;
          final today = periods['today'];
          if (today is Map && today['sessions'] is num) n += (today['sessions'] as num).toInt();
        }
        sessionsToday = n;
      }
      final live = [
        for (final e in log.where((e) => e.isLive(now)))
          SdLiveRow(
            name: e.name.isEmpty ? formatID(e.peerId) : e.name,
            sub: '${translate(e.incoming ? 'Viewing this computer' : 'You are connected')} · ${translate(e.kind)}',
            incoming: e.incoming,
            time: sdClock(e.length(now)),
            button: e.incoming ? translate('End session') : '',
            danger: true,
            onTap: e.incoming
                ? () {
                    SdSessionLog.requestEnd(e.key);
                    SdToast.show(context, translate('Ending the session...'));
                  }
                : null,
          ),
      ];
      final history = [
        for (final e in log.where((e) => e.endedAt != null).take(40))
          SdHistoryRow(
            name: e.name.isEmpty ? formatID(e.peerId) : e.name,
            id: formatID(e.peerId),
            incoming: e.incoming,
            when: sdWhen(e.startedAt, now),
            duration: sdLength(e.length()),
            kind: translate(e.kind),
          ),
      ];
      return SdSessionsView(
        big: signedIn && info != null ? '${used.round()}' : '–',
        small: signedIn && info != null ? (limit > 0 ? '${translate('of')} $limit ${translate('min')}' : translate('min')) : translate('Sign in to see your usage'),
        fraction: limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0,
        facts: [
          ('Plan', sdPlanLabel(info)),
          ('Sessions today', '$sessionsToday'),
          ('This week', '${week.round()} ${translate('min')}'),
          if (info != null) ('Computers on this plan', '${info.devices} ${translate('of')} ${info.maxDevices > 0 ? info.maxDevices : '∞'}'),
        ],
        days: days,
        live: live,
        history: history,
        filter: _filter,
        onFilter: (f) => setState(() => _filter = f),
        onPlans: () => DesktopSettingPage.switch2page(SettingsTabKey.account),
        tr: translate,
      );
    });
  }
}
