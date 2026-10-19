import 'package:flutter/foundation.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/platform_model.dart';

// Keeps the saved server options consistent with the kind of build, so a test build never needs hand-typed
// settings and a production build never keeps pointing at test:
//  - TEST build (LICENSE_API_URL is the test API): API, ID server, relay and key of the separate test stack.
//  - production build: removes leftovers of those test values and of the old raw VPS IP. A server the user typed
//    themselves is never touched.
// A saved ID, relay or API server that is not a systemdesk.net address (left over from an older install, typed by hand,
// imported) is cleared first: the app only talks to systemdesk.net, and falls back to its built-in servers (see also
// src/sd_lock.rs, which does the same for the background service).
// dev\app.ps1 manages the options itself and passes SERVER_PROFILE=manual (see consts.dart).
const String _kTestApi = 'https://test.api.systemdesk.net';
const String _kTestRelayHost = 'server.relay.test.systemdesk.net';
const String _kTestRelayKey = '9J0Xn8vKMSczMJUDUGV7k3obd5rgmCqklI775TesXPI=';
const String _kOldVpsIp = '72.62.66.94';
const List<String> _kServerOptions = ['custom-rendezvous-server', 'relay-server', 'api-server'];

/// True for "host", "host:port" and "https://host:port/path" when the host is systemdesk.net or one of its sub-domains.
bool isSystemDeskAddress(String value) {
  var v = value.trim();
  final scheme = v.indexOf('://');
  if (scheme >= 0) v = v.substring(scheme + 3);
  v = v.split(RegExp(r'[/?#]')).first.split('@').last;
  final host = (v.startsWith('[') ? v.substring(1).split(']').first : v.split(':').first)
      .replaceAll(RegExp(r'\.$'), '')
      .toLowerCase();
  return host == 'systemdesk.net' || host.endsWith('.systemdesk.net');
}

/// The servers and the WebRTC transport (Google/Cloudflare STUN) are locked to systemdesk.net in a release SystemDesk app.
bool get isSystemDeskLocked => kReleaseMode && bind.mainGetAppNameSync().toLowerCase() == 'systemdesk';

Future<void> applyBuildServerProfile() async {
  if (kServerProfile == 'manual') return;
  try {
    for (final key in _kServerOptions) {
      await _clearIf(key, (v) => !isSystemDeskAddress(v));
    }
    if (kLicenseApiUrl == _kTestApi) {
      await _set('api-server', _kTestApi);
      await _set('custom-rendezvous-server', '$_kTestRelayHost:22116');
      // no forced relay: a host that has one ignores the name the ID server hands out (random per connection, see SD_RELAY_WILDCARD),
      // and without it the host falls back to the ID server's host and port + 1 = this same relay
      await _clearIf('relay-server', (v) => v.startsWith(_kTestRelayHost));
      await _set('key', _kTestRelayKey);
    } else if (!kIsTestMode) {
      bool leftover(String v) =>
          v.startsWith(_kTestRelayHost) || v.startsWith(_kOldVpsIp);
      await _clearIf('custom-rendezvous-server', leftover);
      await _clearIf('relay-server', leftover);
      await _clearIf('api-server', (v) => v == _kTestApi || v.contains(_kOldVpsIp));
      await _clearIf('key', (v) => v == _kTestRelayKey);
    }
  } catch (e) {
    debugPrint('server profile: $e');
  }
}

Future<void> _set(String key, String value) async {
  if ((await bind.mainGetOption(key: key)) != value) {
    await bind.mainSetOption(key: key, value: value);
  }
}

Future<void> _clearIf(String key, bool Function(String) isLeftover) async {
  final current = (await bind.mainGetOption(key: key)).trim();
  if (current.isNotEmpty && isLeftover(current)) {
    await bind.mainSetOption(key: key, value: '');
  }
}
