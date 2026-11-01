import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/services/license_service.dart';

// Wake on LAN: wake a sleeping or switched-off computer from this one, over the local network (the packet is sent by src/sd_wol.rs).
// Nobody is asked for a MAC address. It comes from what the SystemDesk account knows about its own devices (every computer reports its
// network adapters while it is on and signed in), and from the one saved for that computer on this one by an older version.

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

/// What happened when a computer was woken by its id, in words for the person.
class WakeOnLanOutcome {
  final bool ok;
  final String message;
  const WakeOnLanOutcome(this.ok, this.message);
}

/// Why no address could be found for the computer.
String wakeLookupFailure({required bool signedIn, required bool reachedAccount}) {
  if (!signedIn) {
    return 'Sign in to your SystemDesk account first. The network address of your computers is kept in your account, and SystemDesk looks it up there for you.';
  }
  if (!reachedAccount) {
    return 'Your SystemDesk account could not be reached to look up the address. Check the internet connection and try again.';
  }
  return 'Your account does not have the network address of this computer yet. It is recorded by itself while SystemDesk runs on that computer, signed in to your account. Start it there once, then try again.';
}

/// One outcome out of the signals sent to every known address of the computer: it worked if any one of them was sent.
WakeOnLanOutcome combineWakeResults(List<WakeOnLanResult> results) {
  for (final r in results) {
    if (r.ok) return WakeOnLanOutcome(true, r.message);
  }
  return WakeOnLanOutcome(false,
      results.isEmpty ? 'The wake-up signal could not be sent.' : results.first.message);
}

class WakeOnLan {
  /// The per-computer option an older version saved the typed MAC address in.
  static const optionKey = 'sd-wol-mac';

  static Future<String?> savedMac(String peerId) async {
    try {
      final v = await bind.mainGetPeerOption(id: wolPeerId(peerId), key: optionKey);
      return normalizeMac(v);
    } catch (_) {
      return null;
    }
  }

  /// Wakes the computer with this RustDesk id: finds its address in the account (and the one saved earlier), sends the signal to each.
  static Future<WakeOnLanOutcome> wake(String peerId) async {
    final out = <String>[];
    final saved = await savedMac(peerId);
    if (saved != null) out.add(saved);
    final signedIn = LicenseService.instance.isLoggedIn;
    final answer = await LicenseService.instance.accountDevicesAnswer();
    for (final m in macsForPeer(answer, peerId)) {
      if (!out.contains(m)) out.add(m);
    }
    if (out.isEmpty) {
      return WakeOnLanOutcome(
          false, wakeLookupFailure(signedIn: signedIn, reachedAccount: answer != null));
    }
    return combineWakeResults([for (final m in out) await send(m)]);
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
