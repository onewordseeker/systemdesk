import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_peers.dart';
import 'package:flutter_test/flutter_test.dart';

// The star of a computer's card lights when it is pressed, not only when the page is built again (it used to glow after switching to another window and
// back): it follows the list of favourites, and answers a press at once.

class _Favs extends ChangeNotifier {
  bool value = false;
  void set(bool v) {
    value = v;
    notifyListeners();
  }
}

Widget _app(_Favs favs, {Duration pendingFor = const Duration(seconds: 3), void Function(bool fav)? onPress}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 365,
          child: SdFavFollower(
            listenable: favs,
            stored: () => favs.value,
            pendingFor: pendingFor,
            builder: (context, fav, pressed) => SdPeerCard(
              data: SdPeerData(id: '408 241 669', name: 'saqibs-macbook-pro-2025', os: SdOs.mac, online: true, fav: fav),
              onFav: () {
                onPress?.call(fav);
                pressed(!fav);
              },
            ),
          ),
        ),
      ),
    );

bool _lit(WidgetTester tester) => tester.widget<SdIcon>(find.descendant(of: find.byKey(const ValueKey('sd-card-fav')), matching: find.byType(SdIcon))).fill;

void main() {
  testWidgets('the star lights at once when it is pressed, before the list has answered', (tester) async {
    final favs = _Favs();
    await tester.pumpWidget(_app(favs));
    expect(_lit(tester), isFalse);
    await tester.tap(find.byKey(const ValueKey('sd-card-fav')));
    await tester.pump();
    expect(_lit(tester), isTrue, reason: 'nothing has rebuilt the page and the list is not loaded yet');
  });

  testWidgets('it stays lit when the list confirms, and stays lit after that', (tester) async {
    final favs = _Favs();
    await tester.pumpWidget(_app(favs));
    await tester.tap(find.byKey(const ValueKey('sd-card-fav')));
    await tester.pump();
    favs.set(true);
    await tester.pump();
    expect(_lit(tester), isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(_lit(tester), isTrue, reason: 'the list now says so itself');
  });

  testWidgets('pressing it again turns it off at once', (tester) async {
    final favs = _Favs()..value = true;
    await tester.pumpWidget(_app(favs));
    expect(_lit(tester), isTrue);
    await tester.tap(find.byKey(const ValueKey('sd-card-fav')));
    await tester.pump();
    expect(_lit(tester), isFalse);
    favs.set(false);
    await tester.pump();
    expect(_lit(tester), isFalse);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('it follows the list when the list changes without a press (another window, another computer)', (tester) async {
    final favs = _Favs();
    await tester.pumpWidget(_app(favs));
    favs.set(true);
    await tester.pump();
    expect(_lit(tester), isTrue);
    favs.set(false);
    await tester.pump();
    expect(_lit(tester), isFalse);
  });

  testWidgets('a press the list never confirms goes back to what the list says', (tester) async {
    final favs = _Favs();
    await tester.pumpWidget(_app(favs, pendingFor: const Duration(milliseconds: 500)));
    await tester.tap(find.byKey(const ValueKey('sd-card-fav')));
    await tester.pump();
    expect(_lit(tester), isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(_lit(tester), isFalse, reason: 'it was not stored');
  });

  testWidgets('an unrelated change of the list does not undo a press that is still waiting', (tester) async {
    final favs = _Favs();
    await tester.pumpWidget(_app(favs));
    await tester.tap(find.byKey(const ValueKey('sd-card-fav')));
    await tester.pump();
    favs.set(false); // the list was loaded again (for another computer) and does not have this one yet
    await tester.pump();
    expect(_lit(tester), isTrue);
    favs.set(true);
    await tester.pump();
    expect(_lit(tester), isTrue);
    await tester.pump(const Duration(seconds: 5));
  });
}
