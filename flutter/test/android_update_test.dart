import 'package:flutter_hbb/mobile/widgets/android_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // the API server of the app (a build carries its own, see services/server_profile.dart); an example address here
  const api = 'https://api.systemdesk.net';
  const host = 'api.systemdesk.net';
  const base = 'https://$host/api/updates/onewordseeker/systemdesk/releases';
  const page = '$base/tag/1.7.2';

  test('the APK address is built from the release page and the processor', () {
    expect(apkUrlFor(page, 'aarch64', api), '$base/download/1.7.2/SystemDesk-1.7.2-aarch64.apk');
    expect(apkUrlFor(page, 'armv7', api), endsWith('/SystemDesk-1.7.2-armv7.apk'));
    expect(apkUrlFor(page, 'x86_64', api), endsWith('/SystemDesk-1.7.2-x86_64.apk'));
  });

  test('only our own release pages are followed', () {
    for (final bad in [
      'https://github.com/onewordseeker/systemdesk/releases/tag/1.7.2',
      'https://$host/api/updates/rustdesk/rustdesk/releases/tag/1.7.2',
      'https://example.com/api/updates/onewordseeker/systemdesk/releases/tag/1.7.2',
      'https://$host.evil.test/api/updates/onewordseeker/systemdesk/releases/tag/1.7.2',
      'https://user@$host/api/updates/onewordseeker/systemdesk/releases/tag/1.7.2',
      'https://$host:8443/api/updates/onewordseeker/systemdesk/releases/tag/1.7.2',
      'http://$host/api/updates/onewordseeker/systemdesk/releases/tag/1.7.2',
      '$base/tag/test',
      '$base/tag/1.7',
      '$base/tag/1.7.2.1',
      '$base/tag/1.7.2?x=1',
      '$base/download/1.7.2',
      '',
    ]) {
      expect(apkUrlFor(bad, 'aarch64', api), isNull, reason: bad);
    }
  });

  test('a checksum line is found by file name', () {
    const sums = 'AAA111  SystemDesk-1.7.2-aarch64.apk\nbbb222 *SystemDesk-1.7.2-armv7.apk\nccc333  SystemDesk.exe\n';
    expect(checksumFor(sums, 'SystemDesk-1.7.2-aarch64.apk'), 'aaa111');
    expect(checksumFor(sums, 'SystemDesk-1.7.2-armv7.apk'), 'bbb222');
    expect(checksumFor(sums, 'SystemDesk-1.7.2-x86_64.apk'), isNull);
    expect(checksumFor('', 'x'), isNull);
  });
}
