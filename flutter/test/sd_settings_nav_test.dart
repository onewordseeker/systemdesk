import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_settings.dart';
import 'package:flutter_test/flutter_test.dart';

// The menu of the Settings screen: pages under four headings, each with its icon, the open one amber with a bar at its left, a search that looks in the
// words of each page, and a line at the bottom (About and the version) that stays where it is when the pages scroll.

const _tabs = [
  SdSettingsTab('account', 'Profile & Plan', 'Account', SdIcons.circleUser, 'sign in email computer plan subscription'),
  SdSettingsTab('license', 'License', 'Account', SdIcons.key, 'license key support'),
  SdSettingsTab('access', 'Access & Passwords', 'Security', SdIcons.shieldLock, 'password 2fa code'),
  SdSettingsTab('permissions', 'Permissions & Privacy', 'Security', SdIcons.shieldEye, 'clipboard camera terminal'),
  SdSettingsTab('display', 'Display & Quality', 'Experience', SdIcons.monitor, 'codec scroll'),
  SdSettingsTab('audio', 'Audio & Recording', 'Experience', SdIcons.waveform, 'microphone call sound speaker'),
  SdSettingsTab('general', 'General', 'System', SdIcons.gear, 'theme language'),
  SdSettingsTab('network', 'Network & Proxy', 'System', SdIcons.globe, 'relay proxy'),
];

Widget _host({
  Brightness brightness = Brightness.light,
  double width = 1200,
  double height = 800,
  Object selected = 'general',
  ValueChanged<Object>? onSelect,
}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(
      body: SizedBox(
        width: width,
        height: height,
        child: SdSettingsFrame(
          tabs: _tabs,
          selected: selected,
          onSelect: onSelect ?? (_) {},
          title: 'Title',
          subtitle: 'Subtitle',
          child: const SizedBox.expand(),
          navFooter: Container(key: const ValueKey('footer'), height: 54, alignment: Alignment.centerLeft, child: const Text('About SystemDesk')),
          footerTab: const SdSettingsTab('about', 'About'),
        ),
      ),
    ),
  );
}

Future<void> _show(WidgetTester tester, Widget app, {Size size = const Size(1400, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(app);
}

void main() {
  testWidgets('the pages are listed under four headings, each with its name', (tester) async {
    await _show(tester, _host());
    for (final heading in ['ACCOUNT', 'SECURITY', 'EXPERIENCE', 'SYSTEM']) {
      expect(find.text(heading), findsOneWidget, reason: heading);
    }
    for (final tab in _tabs) {
      expect(find.text(tab.label), findsOneWidget, reason: tab.label);
    }
    expect(find.text('ABOUT'), findsNothing, reason: 'About is the line at the bottom, not a heading');
  });

  testWidgets('every page has its icon', (tester) async {
    await _show(tester, _host());
    for (final tab in _tabs) {
      expect(find.descendant(of: find.byKey(ValueKey('sd-nav-${tab.id}')), matching: find.byType(SdIcon)), findsOneWidget, reason: tab.label);
    }
  });

  testWidgets('the open page has the amber bar at its left, the others have none', (tester) async {
    await _show(tester, _host(selected: 'audio'));
    expect(find.byKey(const ValueKey('sd-nav-bar')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('sd-nav-audio')), matching: find.byKey(const ValueKey('sd-nav-bar'))), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('sd-nav-general')), matching: find.byKey(const ValueKey('sd-nav-bar'))), findsNothing);
  });

  testWidgets('a tap opens a page', (tester) async {
    Object? opened;
    await _show(tester, _host(onSelect: (id) => opened = id));
    await tester.tap(find.text('Audio & Recording'));
    expect(opened, 'audio');
  });

  group('search', () {
    testWidgets('looks in the name of a page', (tester) async {
      await _show(tester, _host());
      await tester.enterText(find.byKey(const ValueKey('sd-settings-search')), 'network');
      await tester.pump();
      expect(find.text('Network & Proxy'), findsOneWidget);
      expect(find.text('General'), findsNothing);
      expect(find.text('SYSTEM'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsNothing, reason: 'a heading with nothing under it is not shown');
    });

    testWidgets('looks in the words of the options of a page', (tester) async {
      await _show(tester, _host());
      await tester.enterText(find.byKey(const ValueKey('sd-settings-search')), 'Microphone');
      await tester.pump();
      expect(find.text('Audio & Recording'), findsOneWidget);
      expect(find.text('Access & Passwords'), findsNothing);
      expect(find.text('EXPERIENCE'), findsOneWidget);
    });

    testWidgets('says so when nothing matches, and the cross brings every page back', (tester) async {
      await _show(tester, _host());
      await tester.enterText(find.byKey(const ValueKey('sd-settings-search')), 'zzzz');
      await tester.pump();
      expect(find.text('Nothing matches'), findsOneWidget);
      expect(find.text('General'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('sd-settings-search-clear')));
      await tester.pump();
      expect(find.text('Nothing matches'), findsNothing);
      for (final tab in _tabs) {
        expect(find.text(tab.label), findsOneWidget, reason: tab.label);
      }
    });
  });

  testWidgets('the line at the bottom stays where it is when the pages scroll', (tester) async {
    // a window too short for the whole list: the list scrolls, the footer does not
    await _show(tester, _host(height: 330));
    final before = tester.getRect(find.byKey(const ValueKey('footer')));
    expect(before.bottom, closeTo(330, 1), reason: 'at the bottom edge of the menu');
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
    await tester.pump();
    expect(tester.getRect(find.byKey(const ValueKey('footer'))), before);
  });

  for (final brightness in Brightness.values) {
    testWidgets('lays out in ${brightness.name} without a fault', (tester) async {
      await _show(tester, _host(brightness: brightness, selected: 'access'));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('sd-nav-bar')), findsOneWidget);
    });
  }

  group('the About line', () {
    Widget line(String? note, {SdTagKind kind = SdTagKind.ok, bool selected = false, String version = 'v1.5.24', VoidCallback? onTap}) => MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 300, child: SdAboutLine(label: 'About SystemDesk', version: version, note: note, noteKind: kind, selected: selected, onTap: onTap)),
          ),
        );

    testWidgets('names the version and what the last look for updates found', (tester) async {
      await tester.pumpWidget(line('Up to date'));
      expect(find.text('About SystemDesk'), findsOneWidget);
      expect(find.text('v1.5.24 • Up to date'), findsOneWidget);
      await tester.pumpWidget(line('Update available', kind: SdTagKind.gold));
      expect(find.text('v1.5.24 • Update available'), findsOneWidget);
      await tester.pumpWidget(line(null));
      expect(find.text('v1.5.24'), findsOneWidget, reason: 'nothing known about updates: the version alone');
    });

    testWidgets('fits the width of the menu with the longest version a TEST build has', (tester) async {
      await tester.pumpWidget(line('Up to date', version: 'v1.5.214'));
      expect(tester.takeException(), isNull);
      expect(find.text('v1.5.214 • Up to date'), findsOneWidget);
    });

    testWidgets('opens the About page when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(line('Up to date', onTap: () => taps++));
      await tester.tap(find.byKey(const ValueKey('sd-settings-about')));
      expect(taps, 1);
    });
  });

  testWidgets('a narrow window lists the pages as chips, About last', (tester) async {
    await _show(tester, _host(width: 700), size: const Size(700, 900));
    expect(find.text('Audio & Recording'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.byKey(const ValueKey('footer')), findsNothing, reason: 'the menu panel is only for a wide window');
  });
}
