import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'license_service.dart';

/// Everything the sidebar and the title bar say about the signed-in account: who, which plan, how much is used.
/// Built from GET /subscription and GET /auth/me (the same answers the Account settings page reads).
class AccountInfo {
  final String username;
  final String displayName;
  final String email;

  /// free | personal_paid | business_payg | business_org. A plan that has run out counts as free.
  final String tier;

  /// the account had a paid plan that is over
  final bool expired;
  final DateTime? expiresAt;
  final DateTime? startedAt;
  final bool cancelling;

  /// minutes, 0 = no limit
  final int dailyLimit;
  final int sessionLimit;
  final double usedToday;
  final int devices;

  /// 0 = no limit. The plan's limit with the add-on units on top.
  final int maxDevices;

  /// sessions at once, 0 = no limit (the plan's limit with the add-on connections on top)
  final int maxConcurrent;

  /// the add-on units the account holds right now, and whether any add-on is for sale (the "Add-ons" button of the sidebar)
  final int addonDevices;
  final int addonConcurrent;
  final bool addonsForSale;

  /// the name of the person whose plan this account uses (a member of a shared plan); null = the account has its own plan
  final String? sharedBy;

  const AccountInfo({
    required this.username,
    this.displayName = '',
    this.email = '',
    this.tier = 'free',
    this.expired = false,
    this.expiresAt,
    this.startedAt,
    this.cancelling = false,
    this.dailyLimit = 0,
    this.sessionLimit = 0,
    this.usedToday = 0,
    this.devices = 0,
    this.maxDevices = 0,
    this.maxConcurrent = 0,
    this.addonDevices = 0,
    this.addonConcurrent = 0,
    this.addonsForSale = false,
    this.sharedBy,
  });

  bool get isShared => sharedBy != null;

  bool get hasAddons => addonDevices > 0 || addonConcurrent > 0;

  /// "+2 connections, +1 device" (empty without add-ons)
  String get addonSummary => [
        if (addonConcurrent > 0) '+$addonConcurrent ${addonConcurrent == 1 ? 'connection' : 'connections'}',
        if (addonDevices > 0) '+$addonDevices ${addonDevices == 1 ? 'device' : 'devices'}',
      ].join(', ');

  /// a plan's limit with add-on units on top; 0 means "no limit" and stays 0
  static int withAddons(int planLimit, int extra) => planLimit == 0 ? 0 : planLimit + extra;

  bool get isFree => tier == 'free';

  /// "Hamid Raza", or the username when there is no full name
  String get shownName => displayName.isNotEmpty ? displayName : username;

  String get initials => initialsOf(displayName, username);

  double get minutesLeftToday => dailyLimit > 0 ? (dailyLimit - usedToday).clamp(0, dailyLimit).toDouble() : 0;

  /// whole days until the plan ends (null = no end date or free)
  int? daysLeft([DateTime? now]) {
    final end = expiresAt;
    if (end == null || isFree) return null;
    final d = end.difference(now ?? DateTime.now());
    return d.isNegative ? 0 : (d.inHours / 24).ceil();
  }

  /// [freeTier] = the free tier's limits ({daily_limit_minutes, ...}): when a paid plan has run out the answer still carries the
  /// limits of that plan, but the free ones are what applies now.
  static AccountInfo? fromJson(Map<String, dynamic> subscriptionAnswer, Map<String, dynamic>? meAnswer, {Map? freeTier}) {
    final sub = (subscriptionAnswer['subscription'] as Map?) ?? const {};
    final license = subscriptionAnswer['license'] as Map?; // null on an older backend
    final subTier = (sub['tier'] ?? 'free').toString();
    final state = (license?['state'] ?? (subTier == 'free' ? 'free' : 'active')).toString();
    final active = state == 'active';
    final tier = active ? (license?['tier'] ?? subTier).toString() : 'free';
    final limits = (!active && subTier != 'free' && freeTier != null) ? freeTier : sub;
    final user = (meAnswer?['user'] as Map?) ?? const {};
    final addons = subscriptionAnswer['addons'] as Map?; // null on an older backend
    final addonDevices = _whole(addons?['devices']);
    final addonConcurrent = _whole(addons?['concurrent']);
    // somebody who uses another person's plan: the plan is the owner's (the answer already carries its limits) and the devices are one pool
    final shared = subscriptionAnswer['shared'] as Map?;
    final sharedBy = shared == null ? null : (shared['owner_name'] ?? shared['owner_username'] ?? '').toString();
    final pool = subscriptionAnswer['device_pool'] as Map?;
    return AccountInfo(
      username: (user['username'] ?? '').toString(),
      displayName: (user['display_name'] ?? '').toString().trim(),
      email: (user['email'] ?? '').toString(),
      tier: tier,
      expired: state == 'expired',
      expiresAt: active ? _date(license?['expires_at'] ?? sub['expires_at']) : null,
      startedAt: active ? _date(sub['started_at']) : null,
      cancelling: active && license?['cancel_at_period_end'] == true,
      dailyLimit: _whole(limits['daily_limit_minutes']),
      sessionLimit: _whole(limits['session_limit_minutes']),
      usedToday: _number(subscriptionAnswer['today_minutes_used']).toDouble(),
      devices: _whole(subscriptionAnswer['device_count']),
      maxDevices: pool != null ? _whole(pool['max']) : withAddons(_whole(limits['max_devices']), addonDevices),
      maxConcurrent: withAddons(_whole(limits['max_concurrent_sessions']), addonConcurrent),
      addonDevices: addonDevices,
      addonConcurrent: addonConcurrent,
      addonsForSale: addons?['for_sale'] == true,
      sharedBy: sharedBy == null || sharedBy.isEmpty ? (shared == null ? null : 'another account') : sharedBy,
    );
  }

  static num _number(dynamic v) => v is num ? v : (v is String ? num.tryParse(v) ?? 0 : 0);
  static int _whole(dynamic v) => _number(v).round();
  static DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
}

/// "Hamid Raza" -> HR, "Hamid" -> H, no full name: the username's first letter ("onewordseeke" -> O). Never empty.
String initialsOf(String displayName, String username) {
  final words = displayName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  String first(String s) => String.fromCharCode(s.runes.first).toUpperCase();
  if (words.length >= 2) return first(words[0]) + first(words[1]);
  if (words.length == 1) return first(words[0]);
  final u = username.trim();
  return u.isEmpty ? '?' : first(u);
}

/// The plan as the title bar words it. [info] null = signed out (the free licence applies).
String planTitle(AccountInfo? info) {
  if (info == null || info.isFree) {
    return info != null && info.expired ? 'Free license (non-commercial use) · plan expired' : 'Free license (non-commercial use)';
  }
  if (info.isShared) return '${_planName(info)} · shared by ${info.sharedBy}';
  return _planName(info, title: true);
}

String _planName(AccountInfo info, {bool title = false}) {
  switch (info.tier) {
    case 'personal_paid':
      return 'Personal (paid)';
    case 'business_payg':
      return 'Pay as you go';
    case 'business_org':
      return title ? 'Business account (Account ID: ${info.shownName})' : 'Business account';
    default:
      return info.tier.replaceAll('_', ' ');
  }
}

/// The same, short enough for the sidebar card.
String planShort(AccountInfo? info) {
  if (info == null || info.isFree) return info != null && info.expired ? 'Free · plan expired' : 'Free license';
  switch (info.tier) {
    case 'personal_paid':
      return 'Personal (paid)';
    case 'business_payg':
      return 'Pay as you go';
    case 'business_org':
      return 'Business account';
    default:
      return info.tier.replaceAll('_', ' ');
  }
}

/// Keeps one copy of the account's summary for the whole window and refreshes it once a minute (and on sign-in / sign-out).
class AccountSummary {
  AccountSummary._();
  static final instance = AccountSummary._();

  /// null = signed out, or not loaded yet
  final info = Rxn<AccountInfo>();

  /// true until the first answer of a sign-in came (or failed)
  final loading = false.obs;
  Timer? _timer;
  Worker? _watch;
  int _generation = 0;

  void start() {
    if (_watch != null) return;
    _watch = ever(LicenseService.instance.isLoggedInRx, (bool loggedIn) {
      if (loggedIn) {
        refresh();
      } else {
        _generation++;
        info.value = null;
        loading.value = false;
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
    refresh();
  }

  Future<void> refresh() async {
    if (!LicenseService.instance.isLoggedIn) return;
    final generation = ++_generation;
    if (info.value == null) loading.value = true;
    try {
      final results = await Future.wait([
        LicenseService.instance.getSubscription(),
        LicenseService.instance.getProfile(),
      ]);
      final sub = results[0];
      Map? freeTier;
      final license = sub['license'] as Map?;
      final subTier = ((sub['subscription'] as Map?)?['tier'] ?? 'free').toString();
      if (license != null && license['state'] != 'active' && subTier != 'free') {
        freeTier = await LicenseService.instance.getFreeTier();
      }
      if (generation != _generation) return; // signed out (or refreshed again) while the answer was on its way
      info.value = AccountInfo.fromJson(sub, results[1], freeTier: freeTier);
    } catch (e) {
      debugPrint('AccountSummary.refresh: $e'); // keep showing what we had
    } finally {
      if (generation == _generation) loading.value = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _watch?.dispose();
    _watch = null;
  }
}
