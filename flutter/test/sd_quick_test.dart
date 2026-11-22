import 'package:flutter_hbb/screens/sd_quick.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a number is connected to as typed, spaces taken out', () {
    expect(sdQuickTarget('420921178', const []), '420921178');
    expect(sdQuickTarget('420 921 178', const []), '420921178');
    expect(sdQuickTarget('420 921 178', const ['111222333']), '420921178');
  });

  test('a name ID of a computer that is not in the list is connected to as typed', () {
    // the Mac whose ID is a name: nothing in the list matches it, the box still has to start the connection
    expect(sdQuickTarget('SaqibKhanBaloch', const []), 'SaqibKhanBaloch');
    expect(sdQuickTarget('saqibkhanbaloch', const []), 'saqibkhanbaloch');
    expect(sdQuickTarget('  SaqibKhanBaloch ', const []), 'SaqibKhanBaloch');
    expect(sdQuickTarget('onewordseeker', const []), 'onewordseeker');
    expect(sdQuickTarget('a-b_c-d', const []), 'a-b_c-d');
  });

  test('a name ID has the shape the core accepts: a letter first, 6 to 16 characters', () {
    expect(sdIsNameId('abcdef'), isTrue);
    expect(sdIsNameId('abcdefghijklmnop'), isTrue);
    expect(sdIsNameId('abcdefghijklmnopq'), isFalse);
    expect(sdIsNameId('abcde'), isFalse);
    expect(sdIsNameId('1abcdef'), isFalse);
    expect(sdIsNameId('-abcdef'), isFalse);
    expect(sdIsNameId('abc def'), isFalse);
    expect(sdIsNameId('abc.def'), isFalse);
    expect(sdQuickTarget('1abcdef', const []), '');
  });

  test('words that are not an ID and match no computer give nothing to connect to', () {
    expect(sdQuickTarget('', const []), '');
    expect(sdQuickTarget('   ', const []), '');
    expect(sdQuickTarget('dell', const []), '');
    expect(sdQuickTarget('12345', const []), '');
    // an ID has no space in it: words are a search, not an ID
    expect(sdQuickTarget('two words', const []), '');
    expect(sdQuickTarget('Saqib Khan Baloch', const []), '');
  });

  test('a name that matches computers of the list connects to the first of them, as before', () {
    expect(sdQuickTarget('shop', const ['420921178', '4459591']), '420921178');
    // the list has the computer with its own spelling: that spelling is used, not the one typed
    expect(sdQuickTarget('saqib', const ['SaqibKhanBaloch']), 'SaqibKhanBaloch');
    expect(sdQuickTarget('saqibkhanbaloch', const ['SaqibKhanBaloch']), 'SaqibKhanBaloch');
  });

  test('an alias has the shape the server accepts and is never only numbers', () {
    for (final ok in ['maya-studio', 'maya@studio', 'Mac.Office_2', 'abc', 'a1b']) {
      expect(sdIsAlias(ok), isTrue, reason: ok);
    }
    for (final bad in ['ab', '12345678', 'my mac', '-office', 'a/b/c', 'a' * 65, '']) {
      expect(sdIsAlias(bad), isFalse, reason: bad);
    }
  });

  group('with the server turning an alias into the numeric ID', () {
    final asked = <String>[];
    Future<String?> server(String alias) async {
      asked.add(alias);
      return {'maya-studio': '408118204', 'saqibkhanbaloch': 'SaqibKhanBaloch'}[alias.toLowerCase()];
    }

    setUp(asked.clear);

    test('an alias connects to the ID the server answers with, in any letter case', () async {
      expect(await sdQuickResolve('maya-studio', const [], server), '408118204');
      expect(await sdQuickResolve('  Maya-Studio ', const [], server), '408118204');
      expect(await sdQuickResolve('saqibkhanbaloch', const [], server), 'SaqibKhanBaloch');
    });

    test('an alias beats the first computer of the list that merely matches the same letters', () async {
      expect(await sdQuickResolve('maya-studio', const ['111222333'], server), '408118204');
    });

    test('a number and an ID of the list never wait for the server', () async {
      expect(await sdQuickResolve('420 921 178', const [], server), '420921178');
      expect(await sdQuickResolve('onewordseeker', const ['408241669', 'onewordseeker'], server), 'onewordseeker');
      expect(asked, isEmpty);
    });

    test('an alias nobody has, or no answer from the server, falls back to the old rules', () async {
      expect(await sdQuickResolve('nobody-here', const [], server), 'nobody-here');
      expect(await sdQuickResolve('shop', const ['420921178'], server), '420921178');
      expect(await sdQuickResolve('two words', const [], server), '');
      expect(await sdQuickResolve('ab', const [], server), '');
      expect(await sdQuickResolve('maya-studio', const [], (_) async => null), 'maya-studio');
    });

    test('words that cannot be an alias are not sent to the server', () async {
      await sdQuickResolve('two words', const [], server);
      await sdQuickResolve('ab', const [], server);
      await sdQuickResolve('', const [], server);
      expect(asked, isEmpty);
    });
  });

  test('an ID typed in full wins over another computer that only has the same letters in its name', () {
    expect(sdQuickTarget('onewordseeker', const ['408241669', 'onewordseeker']), 'onewordseeker');
  });
}
