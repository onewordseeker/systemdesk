import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_dashboard_bind.dart';
import 'package:flutter_hbb/screens/sd_devices.dart';
import 'package:flutter_hbb/screens/sd_sessions_bind.dart';
import 'package:flutter_hbb/screens/sd_shell.dart';
import 'package:get/get.dart';

/// The home tab of the main window in the new design: the banners (update, install), then the page the header has open: Dashboard, Devices or Sessions.
/// The page scrolls as a whole when the window is shorter than it.
class SdHomePages extends StatelessWidget {
  const SdHomePages({super.key, this.banners = const []});
  final List<Widget> banners;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final page = SdNav.home.value;
      final Widget body;
      switch (page) {
        case SdPage.devices:
          body = const SdDevices(key: ValueKey('sd-devices'));
          break;
        case SdPage.sessions:
          body = const SdSessions(key: ValueKey('sd-sessions'));
          break;
        default:
          body = const SdDashboard(key: ValueKey('sd-dashboard'));
      }
      return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...banners, body]),
      );
    });
  }
}
