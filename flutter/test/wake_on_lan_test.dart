import 'package:flutter_hbb/services/wake_on_lan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a MAC address is understood however it is written', () {
    for (final s in [
      '00:1a:2b:3c:4d:5e',
      '00-1A-2B-3C-4D-5E',
      '001a2b3c4d5e',
      '001a.2b3c.4d5e',
      '  00:1a:2b:3c:4d:5e ',
    ]) {
      expect(normalizeMac(s), '00:1A:2B:3C:4D:5E', reason: s);
    }
  });

  test('what is not a MAC address is refused', () {
    for (final s in [
      '',
      '00:1A:2B:3C:4D',
      '00:1A:2B:3C:4D:5E:6F',
      'GG:1A:2B:3C:4D:5E',
      '00:00:00:00:00:00',
      'FF:FF:FF:FF:FF:FF',
      '192.168.1.5',
      'hello',
    ]) {
      expect(normalizeMac(s), isNull, reason: s);
    }
  });

  test('the RustDesk id is read as typed', () {
    expect(wolPeerId('123 456 789@server'), '123456789');
    expect(wolPeerId('123456789,pw'), '123456789');
    expect(wolPeerId('123456789'), '123456789');
  });

  test('the account answer gives the addresses of the right device only', () {
    final body = {
      'devices': [
        {'rustdesk_id': '111222333', 'mac_address': '00:1A:2B:3C:4D:5E', 'mac_addresses': ['00:1A:2B:3C:4D:5E', 'aa-bb-cc-dd-ee-ff']},
        {'rustdesk_id': '999888777', 'mac_address': '11:22:33:44:55:66', 'mac_addresses': null},
        {'rustdesk_id': null, 'mac_address': '77:88:99:AA:BB:CC'},
      ],
    };
    expect(macsForPeer(body, '111 222 333'), ['00:1A:2B:3C:4D:5E', 'AA:BB:CC:DD:EE:FF']);
    expect(macsForPeer(body, '999888777@srv'), ['11:22:33:44:55:66']);
    expect(macsForPeer(body, '555'), isEmpty);
    expect(macsForPeer(body, ''), isEmpty);
  });

  test('odd answers give nothing, not an error', () {
    expect(macsForPeer(null, '111'), isEmpty);
    expect(macsForPeer('text', '111'), isEmpty);
    expect(macsForPeer({'devices': 5}, '111'), isEmpty);
    expect(macsForPeer({'devices': [5, null, 'x']}, '111'), isEmpty);
    expect(macsForPeer({'devices': [{'rustdesk_id': '111', 'mac_address': 5, 'mac_addresses': [5, null, 'junk']}]}, '111'), isEmpty);
  });

  test('the answer of the Rust side is turned into a sentence', () {
    final ok = WakeOnLanResult.parse('ok:3');
    expect(ok.ok, isTrue);
    expect(ok.message, contains('half a minute'));
    final bad = WakeOnLanResult.parse('error:No network.');
    expect(bad.ok, isFalse);
    expect(bad.message, 'No network.');
    expect(WakeOnLanResult.parse('').ok, isFalse);
    expect(WakeOnLanResult.parse('error:').message, 'The wake-up signal could not be sent.');
  });
}
