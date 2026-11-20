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
