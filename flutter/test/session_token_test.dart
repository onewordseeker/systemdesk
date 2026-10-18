import 'package:flutter_hbb/services/license_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('which sign-in a session start uses', () {
    test('a window that opened while nobody was signed in picks up the sign-in made afterwards', () {
      expect(tokenForSessionStart(null, 'new-token'), 'new-token');
    });

    test('a window that kept an old token uses the new one after a new sign-in', () {
      expect(tokenForSessionStart('old-revoked-token', 'new-token'), 'new-token');
    });

    test('after signing out the window is a guest, not signed in with the old token', () {
      expect(tokenForSessionStart('old-token', ''), isNull);
      expect(tokenForSessionStart('old-token', '   '), isNull);
    });

    test('an unchanged sign-in stays', () {
      expect(tokenForSessionStart('same', 'same'), 'same');
      expect(tokenForSessionStart(null, ''), isNull);
    });

    test('stray white space around the stored token is ignored', () {
      expect(tokenForSessionStart(null, ' tok \n'), 'tok');
    });
  });
}
