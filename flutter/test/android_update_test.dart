import 'package:flutter_hbb/mobile/widgets/android_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const page = 'https://github.com/onewordseeker/systemdesk/releases/tag/1.7.2';

  test('the APK address is built from the release page and the processor', () {
    expect(apkUrlFor(page, 'aarch64'),
        'https://github.com/onewordseeker/systemdesk/releases/download/1.7.2/rustdesk-1.7.2-aarch64.apk');
    expect(apkUrlFor(page, 'armv7'), endsWith('/rustdesk-1.7.2-armv7.apk'));
    expect(apkUrlFor(page, 'x86_64'), endsWith('/rustdesk-1.7.2-x86_64.apk'));
  });

  test('only our own release pages are followed', () {
    for (final bad in [
      'https://github.com/rustdesk/rustdesk/releases/tag/1.7.2',
      'https://example.com/onewordseeker/systemdesk/releases/tag/1.7.2',
      'http://github.com/onewordseeker/systemdesk/releases/tag/1.7.2',
      'https://github.com/onewordseeker/systemdesk/releases/tag/test',
      'https://github.com/onewordseeker/systemdesk/releases/tag/1.7',
      'https://github.com/onewordseeker/systemdesk/releases/tag/1.7.2.1',
      'https://github.com/onewordseeker/systemdesk/releases/download/1.7.2',
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
