import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_limit_dialog.dart';
import 'package:flutter_hbb/services/license_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({bool upgrade = true, String kind = 'concurrent'}) => {
      'kind': kind,
      'title': 'Too many sessions at once',
      'message':
          'Your Personal plan allows 2 sessions at the same time, and 2 are already running. Close one of them to connect to another device.',
      'plan': {'tier': 'personal_paid', 'name': 'Personal'},
      'rows': [
        {'label': 'Your plan', 'value': 'Personal'},
        {'label': 'Sessions at once', 'value': '2', 'hit': true},
        {'label': 'Time per day', 'value': '10 h'},
        {'label': 'Time per session', 'value': 'Unlimited'},
      ],
      'upgrade': upgrade
          ? {
              'available': true,
              'name': 'Business Pay-As-You-Go',
              'label': 'Upgrade to Business Pay-As-You-Go',
              'url': 'https://my.systemdesk.net/billing'
            }
          : {'available': false, 'contact_url': 'https://my.systemdesk.net/tickets'},
    };

void main() {
  group('the limit notice from the server', () {
    test('is read in full', () {
      final n = LimitNotice.fromJson(_json())!;
      expect(n.kind, 'concurrent');
      expect(n.title, 'Too many sessions at once');
      expect(n.message, contains('Personal plan allows 2 sessions'));
      expect(n.planName, 'Personal');
      expect(n.rows.length, 4);
      expect(n.rows[1].label, 'Sessions at once');
      expect(n.rows[1].hit, isTrue);
      expect(n.rows[0].hit, isFalse);
      expect(n.upgradeLabel, 'Upgrade to Business Pay-As-You-Go');
      expect(n.upgradeUrl, 'https://my.systemdesk.net/billing');
    });

    test('has no upgrade when the plan is already the largest', () {
      final n = LimitNotice.fromJson(_json(upgrade: false))!;
      expect(n.upgradeLabel, isNull);
      expect(n.upgradeUrl, isNull);
    });

    test('is null for an older server or rubbish (the generic text is used then)', () {
      expect(LimitNotice.fromJson(null), isNull);
      expect(LimitNotice.fromJson('x'), isNull);
      expect(LimitNotice.fromJson({'title': 'only a title'}), isNull);
      expect(LimitNotice.fromJson({'title': 1, 'message': 2}), isNull);
    });

    test('skips a row it cannot read and an upgrade without a link', () {
      final n = LimitNotice.fromJson({
        'title': 't',
        'message': 'm',
        'rows': [
          {'label': 'ok', 'value': '1'},
          {'label': 5, 'value': '2'},
          'nope'
        ],
        'upgrade': {'available': true, 'label': 'Upgrade'},
      })!;
      expect(n.rows.length, 1);
      expect(n.upgradeLabel, isNull);
    });

    test('travels with a refused session start and a denied heartbeat', () {
      final r = SessionCheckResult(
          allowed: false, code: 'CONCURRENT_LIMIT', notice: LimitNotice.fromJson(_json()));
      expect(r.notice!.kind, 'concurrent');
      final h = HeartbeatResult(
          allowed: false, code: 'SESSION_LIMIT', notice: LimitNotice.fromJson(_json(kind: 'session')));
      expect(h.notice!.kind, 'session');
      expect(h.lost, isFalse);
    });
  });

  group('the sentence for a refused sign-in', () {
    test('wrong password: plain until it gets close, then how many tries are left', () {
      expect(loginFailureMessage(401, {'error': 'Invalid credentials', 'code': 'BAD_LOGIN', 'attempts_left': 4}),
          'Invalid credentials');
      expect(loginFailureMessage(401, {'error': 'Invalid credentials', 'code': 'BAD_LOGIN', 'attempts_left': 3}),
          'Invalid credentials. 3 attempts left before this network address is blocked.');
      expect(loginFailureMessage(401, {'error': 'Invalid credentials', 'code': 'BAD_LOGIN', 'attempts_left': 1}),
          'Invalid credentials. 1 attempt left before this network address is blocked.');
    });

    test('a blocked address gets the server\'s explanation, not "Invalid credentials"', () {
      final m = loginFailureMessage(403, {
        'error': 'This network address has been blocked because of too many wrong sign-in attempts. Contact support to get it unblocked.',
        'code': 'IP_BLOCKED'
      });
      expect(m, startsWith('This network address has been blocked'));
      expect(m, isNot(contains('Invalid credentials')));
    });

    test('a 429 says to wait, with the time when it is known', () {
      expect(loginFailureMessage(429, {'error': 'x', 'code': 'RATE_LIMITED', 'retry_after': 600}),
          'Too many requests from your network, so this sign-in was not checked. Please try again in 10 minutes.');
      expect(loginFailureMessage(429, {'code': 'RATE_LIMITED', 'retry_after': 1}), contains('in 1 second.'));
      expect(loginFailureMessage(429, {'code': 'RATE_LIMITED', 'retry_after': 45}), contains('in 45 seconds.'));
      expect(loginFailureMessage(429, {'code': 'RATE_LIMITED'}), contains('in a few minutes.'));
    });

    test('an answer that is not ours (no JSON) still says what happened', () {
      expect(loginFailureMessage(429, <String, dynamic>{}), contains('Too many requests'));
      expect(loginFailureMessage(429, <String, dynamic>{}), isNot(contains('Invalid')));
      expect(loginFailureMessage(502, <String, dynamic>{}), contains('did not answer properly'));
      expect(loginFailureMessage(400, <String, dynamic>{}), 'Login failed');
    });

    test('plain text from the server never becomes a FormatException on screen', () {
      expect(jsonObjectOrEmpty('Too many requests, please try again later.'), isEmpty);
      expect(jsonObjectOrEmpty(''), isEmpty);
      expect(jsonObjectOrEmpty('[1,2]'), isEmpty);
      expect(jsonObjectOrEmpty('{"error":"x","code":"RATE_LIMITED"}')['code'], 'RATE_LIMITED');
      final m = loginFailureMessage(429, jsonObjectOrEmpty('Too many requests, please try again later.'));
      expect(m, contains('Too many requests from your network'));
      expect(m, isNot(contains('FormatException')));
    });

    test('the other refusals keep the server\'s own text', () {
      expect(loginFailureMessage(403, {'error': 'This account is deactivated.', 'code': 'ACCOUNT_INACTIVE'}),
          'This account is deactivated.');
      expect(loginFailureMessage(423, {'error': 'Account locked due to too many failed attempts. Try again in 30 minutes.', 'code': 'ACCOUNT_LOCKED'}),
          startsWith('Account locked'));
    });
  });

  group('the limit dialog', () {
    Future<void> show(WidgetTester tester, LimitNotice n,
        {Brightness brightness = Brightness.light, List<String>? taps}) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: Builder(
            builder: (context) => AlertDialog(
              content: LimitDialogBody(notice: n),
              actions: limitDialogActions(n,
                  onUpgrade: () => taps?.add('upgrade'), onOk: () => taps?.add('ok')),
            ),
          ),
        ),
      ));
    }

    testWidgets('shows the message, the plan card and marks the limit that was reached', (tester) async {
      await show(tester, LimitNotice.fromJson(_json())!);
      expect(find.text('Too many sessions at once'), findsOneWidget);
      expect(find.textContaining('Personal plan allows 2 sessions'), findsOneWidget);
      expect(find.byKey(const ValueKey('sd-limit-plan')), findsOneWidget);
      expect(find.text('Your plan'), findsOneWidget);
      expect(find.text('Sessions at once'), findsOneWidget);
      expect(find.text('Time per session'), findsOneWidget);
      expect(find.text('limit reached'), findsOneWidget);
    });

    testWidgets('Upgrade is the primary button and sits right before an outlined OK', (tester) async {
      final taps = <String>[];
      await show(tester, LimitNotice.fromJson(_json())!, taps: taps);
      final upgrade = find.widgetWithText(ElevatedButton, 'Upgrade to Business Pay-As-You-Go');
      final ok = find.widgetWithText(OutlinedButton, 'OK');
      expect(upgrade, findsOneWidget);
      expect(ok, findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'OK'), findsNothing);
      expect(tester.getTopLeft(upgrade).dx, lessThan(tester.getTopLeft(ok).dx));
      final okStyle = tester.widget<OutlinedButton>(ok).style!;
      expect(okStyle.backgroundColor!.resolve({}), Colors.transparent);
      final upStyle = tester.widget<ElevatedButton>(upgrade).style!;
      expect(upStyle.backgroundColor!.resolve({}), const Color(0xFFF59E0B));
      await tester.tap(upgrade);
      await tester.tap(ok);
      expect(taps, ['upgrade', 'ok']);
    });

    testWidgets('an account that can buy more connections gets an outlined add-on button between Upgrade and OK', (tester) async {
      final taps = <String>[];
      final json = _json()
        ..['addon'] = {'available': true, 'label': 'Add more connections', 'url': 'https://my.systemdesk.net/addons?kind=concurrent'};
      final n = LimitNotice.fromJson(json)!;
      expect(n.addonLabel, 'Add more connections');
      expect(n.addonUrl, 'https://my.systemdesk.net/addons?kind=concurrent');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AlertDialog(
            content: LimitDialogBody(notice: n),
            actions: limitDialogActions(n,
                onUpgrade: () => taps.add('upgrade'), onAddon: () => taps.add('addon'), onOk: () => taps.add('ok')),
          ),
        ),
      ));
      final addon = find.byKey(const ValueKey('sd-limit-addon'));
      final upgrade = find.widgetWithText(ElevatedButton, 'Upgrade to Business Pay-As-You-Go');
      final ok = find.widgetWithText(OutlinedButton, 'OK');
      expect(addon, findsOneWidget);
      expect(tester.getTopLeft(upgrade).dx, lessThan(tester.getTopLeft(addon).dx));
      expect(tester.getTopLeft(addon).dx, lessThan(tester.getTopLeft(ok).dx));
      await tester.tap(addon);
      expect(taps, ['addon']);
    });

    testWidgets('no add-on button without an add-on for sale (older server, or not offered)', (tester) async {
      await show(tester, LimitNotice.fromJson(_json())!);
      expect(find.byKey(const ValueKey('sd-limit-addon')), findsNothing);
      final broken = LimitNotice.fromJson(_json()..['addon'] = {'available': true, 'label': 'x'})!;
      expect(broken.addonLabel, isNull);
    });

    testWidgets('without a bigger plan there is only the outlined OK', (tester) async {
      await show(tester, LimitNotice.fromJson(_json(upgrade: false))!);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'OK'), findsOneWidget);
    });

    testWidgets('is readable on a dark window too', (tester) async {
      await show(tester, LimitNotice.fromJson(_json())!, brightness: Brightness.dark);
      final title = tester.widget<Text>(find.text('Too many sessions at once'));
      expect(title.style!.color, const Color(0xFFECEAE4));
    });

    testWidgets('a notice without rows shows just the message', (tester) async {
      await show(tester, const LimitNotice(kind: 'daily', title: 'Daily limit reached', message: 'You have used it all.'));
      expect(find.byKey(const ValueKey('sd-limit-plan')), findsNothing);
      expect(find.text('Daily limit reached'), findsOneWidget);
    });
  });
}
