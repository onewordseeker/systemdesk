import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/screens/sd_cm_window.dart';
import 'package:flutter_hbb/screens/sd_shell.dart';
import 'package:provider/provider.dart';

/// The words in the title bar of the host window: a request that waits, or a connection that is going.
String sdHostTitle({required bool connected}) => connected ? 'Active Session' : 'Incoming Connection Request';

/// The title of the host window (next to its icon): it says what the window is for, and changes when the request is accepted.
class SdHostTitleBrand extends StatelessWidget {
  const SdHostTitleBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<ServerModel>(context);
    final connected = sdCmShouldBeCompact(model.clients.map((c) => c.authorized));
    return SdTitleBrand(strong: true, title: translate(sdHostTitle(connected: connected)));
  }
}
