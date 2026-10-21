import 'package:flutter/foundation.dart';
import 'package:flutter_hbb/models/platform_model.dart';

// The servers of a SystemDesk build (ID server, relay, API server and key) are part of the program: the build is given them (build.rs), they are
// kept scrambled in the program and put in force at start-up (src/sd_servers.rs), over whatever was saved before, and the Network tab has no
// "ID/Relay Server" entry. Nothing about them is written in this code, so a test build and a production build differ only by what they carry.
// A developer's debug app is pointed at a server by its launcher (dev\app.ps1 passes LICENSE_API_URL and sets the options itself).
const String _kApiDefine = String.fromEnvironment('LICENSE_API_URL');

/// The API server of this build, "https://host" without a trailing slash.
final String kLicenseApiUrl = (_kApiDefine.isNotEmpty
        ? _kApiDefine
        : bind.mainGetCommonSync(key: 'sd-api-server'))
    .replaceAll(RegExp(r'/+$'), '');

/// A test build (it talks to the test servers) or an app a developer started: the licence panel says so and links to the test panel.
final bool kIsTestMode = _kApiDefine.isNotEmpty ||
    bind.mainGetCommonSync(key: 'sd-test-build') == 'Y';

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
