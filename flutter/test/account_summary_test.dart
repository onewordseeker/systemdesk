import 'package:flutter_hbb/services/account_summary.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _sub({
  String tier = 'free',
  String? state,
  String? expiresAt,
  int daily = 45,
  int session = 30,
  int maxDevices = 2,
  dynamic used = 12.5,
  int devices = 1,
}) =>
    {
      'subscription': {
        'tier': tier,
        'daily_limit_minutes': daily,
        'session_limit_minutes': session,
        'max_devices': maxDevices,
        'expires_at': expiresAt,
      },
      if (state != null) 'license': {'state': state, 'tier': tier, 'expires_at': expiresAt, 'cancel_at_period_end': false},
      'device_count': devices,
      'today_minutes_used': used,
    };

Map<String, dynamic> _me({String username = 'onewordseeke', String? name}) => {
      'user': {'username': username, 'email': 'a@b.c', 'display_name': name},
    };

void main() {
  test('initials: two words -> two letters, one word -> one, no full name -> the username', () {
    expect(initialsOf('Hamid Raza', 'onewordseeke'), 'HR');
    expect(initialsOf('hamid raza khan', 'x'), 'HR');
    expect(initialsOf('Hamid', 'onewordseeke'), 'H');
    expect(initialsOf('', 'onewordseeke'), 'O');
    expect(initialsOf('   ', 'onewordseeke'), 'O');
    expect(initialsOf('', ''), '?');
  });

  test('a free account', () {
    final a = AccountInfo.fromJson(_sub(state: 'free'), _me(name: ''))!;
    expect(a.isFree, isTrue);
    expect(a.shownName, 'onewordseeke');
    expect(a.initials, 'O');
    expect(a.dailyLimit, 45);
    expect(a.minutesLeftToday, 32.5);
    expect(a.daysLeft(), isNull);
    expect(planTitle(a), 'Free license (non-commercial use)');
    expect(planShort(a), 'Free license');
  });

  test('the plan names as the title bar words them', () {
    final personal = AccountInfo.fromJson(_sub(tier: 'personal_paid', state: 'active', expiresAt: '2030-01-01T00:00:00Z', daily: 500), _me(name: 'Hamid Raza'))!;
    expect(planTitle(personal), 'Personal (paid)');
    expect(planShort(personal), 'Personal (paid)');
    expect(personal.initials, 'HR');
    final payg = AccountInfo.fromJson(_sub(tier: 'business_payg', state: 'active', daily: 0), _me())!;
    expect(planTitle(payg), 'Pay as you go');
    final org = AccountInfo.fromJson(_sub(tier: 'business_org', state: 'active', daily: 0), _me(name: 'Hamid'))!;
    expect(planTitle(org), 'Business account (Account ID: Hamid)');
    expect(planShort(org), 'Business account');
    expect(AccountInfo.fromJson(_sub(tier: 'business_org', state: 'active'), _me())!.isFree, isFalse);
    expect(planTitle(null), 'Free license (non-commercial use)');
  });

  test('days left count whole days up and never go below zero', () {
    final a = AccountInfo.fromJson(_sub(tier: 'personal_paid', state: 'active', expiresAt: '2026-11-04T12:00:00Z'), _me())!;
    expect(a.daysLeft(DateTime.utc(2026, 10, 18, 13)), 17); // 16.9 days -> 17
    expect(a.daysLeft(DateTime.utc(2026, 11, 4, 12)), 0);
    expect(a.daysLeft(DateTime.utc(2027, 1, 1)), 0);
  });

  test('a paid plan that ran out counts as free, with the free limits', () {
    final sub = _sub(tier: 'personal_paid', state: 'expired', daily: 500, session: 500, maxDevices: 2);
    final withFree = AccountInfo.fromJson(sub, _me(), freeTier: {'daily_limit_minutes': 45, 'session_limit_minutes': 30, 'max_devices': 1})!;
    expect(withFree.isFree, isTrue);
    expect(withFree.expired, isTrue);
    expect(withFree.dailyLimit, 45);
    expect(withFree.maxDevices, 1);
    expect(planTitle(withFree), 'Free license (non-commercial use) · plan expired');
    expect(planShort(withFree), 'Free · plan expired');
  });

  test('odd numbers in the answer do not throw', () {
    final a = AccountInfo.fromJson(_sub(used: '7.25', devices: 3), _me())!;
    expect(a.usedToday, 7.25);
    expect(a.devices, 3);
    final b = AccountInfo.fromJson({'subscription': {}, 'today_minutes_used': null}, null)!;
    expect(b.username, '');
    expect(b.dailyLimit, 0);
  });
}
