import 'package:flutter_hbb/services/server_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('our servers are ours', () {
    for (final ok in [
      'id.systemdesk.net',
      'id.systemdesk.net:21116',
      'r3f9a21c07b.relay.systemdesk.net:22117',
      'http://id.systemdesk.net:21114',
      'https://api.systemdesk.net',
      'https://api.systemdesk.net/api/health',
      'HTTPS://Api.SystemDesk.NET',
      'systemdesk.net',
      'id.systemdesk.net.',
    ]) {
      expect(isSystemDeskAddress(ok), isTrue, reason: ok);
    }
  });

  test('everything else is not', () {
    for (final bad in [
      '',
      '203.0.113.7',
      '203.0.113.7:21116',
      'rustdesk.example.cloud',
      'rustdesk.example.cloud:21116',
      'http://rustdesk.example.cloud:21114',
      'rs-ny.rustdesk.com',
      'systemdesk.net.evil.test',
      'evilsystemdesk.net',
      'notsystemdesk.net:21116',
      'https://systemdesk.net@evil.test/',
      'https://evil.test/systemdesk.net',
      'https://evil.test?x=.systemdesk.net',
      '[::1]:21116',
      'localhost:3000',
      'http://127.0.0.1:3000',
    ]) {
      expect(isSystemDeskAddress(bad), isFalse, reason: bad);
    }
  });
}
