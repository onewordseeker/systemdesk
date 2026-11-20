import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

/// The local option that remembers "Not now" for the background service of a Mac.
const kSdBackgroundLater = 'sd-background-service-later';

/// How the home page offers the background service of a Mac. It is optional: SystemDesk already works while its window is open, the service
/// only keeps this Mac reachable after a restart and at the login screen, and keeps a connection when the window is closed.
/// [banner] is the first offer, [link] what is left of it once the person said "Not now" (a small link under the state in the panel).
enum SdBackgroundOffer { none, banner, link }

/// One message about the service, never two: while the app's own service is stopped, the panel's "Start service" is the only one (the background
/// service comes after it), and an installed background service is not offered again.
SdBackgroundOffer sdBackgroundOffer({required bool daemonInstalled, required bool serviceStopped, required bool putAside}) {
  if (daemonInstalled || serviceStopped) return SdBackgroundOffer.none;
  return putAside ? SdBackgroundOffer.link : SdBackgroundOffer.banner;
}

/// Should a service that an earlier run left stopped (the saved "stop-service" option, which the old uninstall steps and "Stop service" write and
/// nothing cleared) start by itself now that the app has opened? Then this computer is ready the moment SystemDesk opens, as with AnyDesk.
/// Not for an outgoing-only app, and not where starting it needs a person: an installed Windows copy has to be given administrator rights to bring
/// its service back, a Mac with the background service installed asks for its password. Those keep the "Start service" button.
bool sdShouldAutoStartService({
  required bool stopped,
  required bool outgoingOnly,
  required bool isWindows,
  required bool isMacOS,
  required bool installed,
  required bool daemonInstalled,
}) {
  if (!stopped || outgoingOnly) return false;
  if (isWindows) return !installed;
  if (isMacOS) return !daemonInstalled;
  return false;
}

RxBool? _later;

/// True once the person put the offer aside (remembered between runs).
RxBool get sdBackgroundLater => _later ??= RxBool(_read());

bool _read() {
  try {
    return bind.mainGetLocalOption(key: kSdBackgroundLater) == 'Y';
  } catch (_) {
    return false;
  }
}

void sdPutBackgroundServiceAside() {
  sdBackgroundLater.value = true;
  try {
    bind.mainSetLocalOption(key: kSdBackgroundLater, value: 'Y');
  } catch (_) {}
}
