import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_dashboard.dart' show kSdDashboardSplit;
import 'package:flutter_hbb/screens/sd_dashboard_bind.dart';
import 'package:flutter_hbb/screens/sd_devices.dart';
import 'package:flutter_hbb/screens/sd_sessions_bind.dart';
import 'package:flutter_hbb/screens/sd_shell.dart';
import 'package:get/get.dart';

/// The home tab of the main window in the new design: the banners (update, install), then the page the header has open: Dashboard, Devices or Sessions.
/// The Dashboard has the height of the window and scrolls only where it must (the list of computers); Devices and Sessions scroll as a whole, and so does
/// the Dashboard when the window is too narrow for its two columns.
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
      return LayoutBuilder(builder: (context, c) {
        // the dashboard takes the whole page, its left panel flush with the edge of the window
        final fixed = (page == SdPage.devices || page == SdPage.sessions) ? false : c.hasBoundedHeight && c.maxWidth >= kSdDashboardSplit;
        if (fixed) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...banners, Expanded(child: body)]);
        }
        return SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...banners, body]),
        );
      });
    });
  }
}
