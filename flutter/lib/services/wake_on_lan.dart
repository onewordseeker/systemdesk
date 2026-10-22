import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/services/license_service.dart';

// Wake on LAN: wake a sleeping or switched-off computer from this one, over the local network (the packet is sent by src/sd_wol.rs).
// The MAC address of the other computer comes from, in this order: what the person saved for it, then what the SystemDesk account knows
// about its own devices (every computer reports its network adapters when it signs in).

/// "00:1a:2b:3c:4d:5e", "00-1A-2B-3C-4D-5E", "001a2b3c4d5e" and "001a.2b3c.4d5e" are one address: "00:1A:2B:3C:4D:5E".
/// null when it is not a MAC address (or one no adapter has: all zeros, all ones).
String? normalizeMac(String input) {
  final hex = input.replaceAll(RegExp(r'[:\-.\s]'), '').toUpperCase();
  if (!RegExp(r'^[0-9A-F]{12}$').hasMatch(hex)) return null;
  if (hex == '000000000000' || hex == 'FFFFFFFFFFFF') return null;
  return [for (var i = 0; i < 12; i += 2) hex.substring(i, i + 2)].join(':');
}

/// The RustDesk id as typed ("123 456 789@server" -> "123456789").
String wolPeerId(String id) => id.split('@').first.split(',').first.replaceAll(' ', '');

/// The MAC addresses of the account's device with this RustDesk id, out of the server's `GET /api/devices` answer.
List<String> macsForPeer(dynamic body, String peerId) {
  if (body is! Map || body['devices'] is! List) return const [];
  final want = wolPeerId(peerId);
  final out = <String>[];
  for (final d in body['devices'] as List) {
    if (d is! Map || wolPeerId('${d['rustdesk_id'] ?? ''}') != want || want.isEmpty) continue;
    final raw = <dynamic>[
      if (d['mac_addresses'] is List) ...(d['mac_addresses'] as List),
      d['mac_address'],
    ];
    for (final r in raw) {
      final mac = r is String ? normalizeMac(r) : null;
      if (mac != null && !out.contains(mac)) out.add(mac);
    }
  }
  return out;
}

/// What the Rust side answers: "ok:<packets sent>" or "error:<reason>".
class WakeOnLanResult {
  final bool ok;
  final String message;
  const WakeOnLanResult(this.ok, this.message);

  static WakeOnLanResult parse(String answer) {
    if (answer.startsWith('ok:')) {
      return const WakeOnLanResult(true,
          'Wake-up signal sent. Give the computer about half a minute to start, then connect.');
    }
    final reason = answer.startsWith('error:') ? answer.substring(6).trim() : '';
    return WakeOnLanResult(
        false, reason.isEmpty ? 'The wake-up signal could not be sent.' : reason);
  }
}

class WakeOnLan {
  /// The per-computer option the MAC address is saved in.
  static const optionKey = 'sd-wol-mac';

  static Future<String?> savedMac(String peerId) async {
    try {
      final v = await bind.mainGetPeerOption(id: wolPeerId(peerId), key: optionKey);
      return normalizeMac(v);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveMac(String peerId, String mac) async {
    try {
      await bind.mainSetPeerOption(id: wolPeerId(peerId), key: optionKey, value: mac);
    } catch (_) {}
  }

  /// The addresses to offer for this computer, the saved one first.
  static Future<List<String>> candidates(String peerId) async {
    final out = <String>[];
    final saved = await savedMac(peerId);
    if (saved != null) out.add(saved);
    for (final m in macsForPeer(await LicenseService.instance.accountDevicesAnswer(), peerId)) {
      if (!out.contains(m)) out.add(m);
    }
    return out;
  }

  static Future<WakeOnLanResult> send(String mac) async {
    final m = normalizeMac(mac);
    if (m == null) {
      return const WakeOnLanResult(
          false, 'That is not a MAC address. It looks like AA:BB:CC:DD:EE:FF.');
    }
    try {
      return WakeOnLanResult.parse(await bind.mainGetCommon(key: 'sd-wol:$m'));
    } catch (e) {
      return WakeOnLanResult(false, 'The wake-up signal could not be sent ($e).');
    }
  }
}
