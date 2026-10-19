import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/mobile/widgets/android_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final host = Uri.parse(kLicenseApiUrl).host;
  final base = 'https://$host/api/updates/onewordseeker/systemdesk/releases';
  final page = '$base/tag/1.7.2';

  test('the APK address is built from the release page and the processor', () {
    expect(apkUrlFor(page, 'aarch64'), '$base/download/1.7.2/rustdesk-1.7.2-aarch64.apk');
    expect(apkUrlFor(page, 'armv7'), endsWith('/rustdesk-1.7.2-armv7.apk'));
    expect(apkUrlFor(page, 'x86_64'), endsWith('/rustdesk-1.7.2-x86_64.apk'));
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
      expect(apkUrlFor(bad, 'aarch64'), isNull, reason: bad);
    }
  });

  test('a checksum line is found by file name', () {
    const sums = 'AAA111  rustdesk-1.7.2-aarch64.apk\nbbb222 *rustdesk-1.7.2-armv7.apk\nccc333  SystemDesk.exe\n';
    expect(checksumFor(sums, 'rustdesk-1.7.2-aarch64.apk'), 'aaa111');
    expect(checksumFor(sums, 'rustdesk-1.7.2-armv7.apk'), 'bbb222');
    expect(checksumFor(sums, 'rustdesk-1.7.2-x86_64.apk'), isNull);
    expect(checksumFor('', 'x'), isNull);
  });
}
