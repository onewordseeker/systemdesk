import 'package:flutter_hbb/services/server_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('our servers are ours', () {
    for (final ok in [
      'server.relay.systemdesk.net',
      'server.relay.systemdesk.net:21116',
      'r3f9a21c07b.relay.test.systemdesk.net:22117',
      'http://server.relay.systemdesk.net:21114',
      'https://test.api.systemdesk.net',
      'https://prod.api.systemdesk.net/api/health',
      'HTTPS://Prod.API.SystemDesk.NET',
      'systemdesk.net',
      'server.relay.systemdesk.net.',
    ]) {
      expect(isSystemDeskAddress(ok), isTrue, reason: ok);
    }
  });

  test('everything else is not', () {
    for (final bad in [
      '',
      '72.62.66.94',
      '72.62.66.94:21116',
      'rustdesk.hamidentifier.cloud',
      'rustdesk.hamidentifier.cloud:21116',
      'http://rustdesk.hamidentifier.cloud:21114',
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
