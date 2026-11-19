import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/widgets/peers_view.dart' show peerSearchText;
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:flutter_hbb/screens/sd_dashboard.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_peer_pages.dart';
import 'package:flutter_hbb/screens/sd_peers.dart';
import 'package:flutter_hbb/services/account_summary.dart';
import 'package:flutter_hbb/services/license_service.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// The state of the connection to the SystemDesk network, polled once a second (what the old status line did).
class SdServiceWatch {
  SdServiceWatch._();
  static final instance = SdServiceWatch._();
  Timer? _timer;
  int _users = 0;

  void start() {
    _users++;
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _update());
    _update();
  }

  void stop() {
    if (--_users <= 0) {
      _timer?.cancel();
      _timer = null;
      _users = 0;
    }
  }

  Future<void> _update() async {
    try {
      final status = jsonDecode(await bind.mainGetConnectStatus()) as Map<String, dynamic>;
      final n = status['status_num'] as int;
      stateGlobal.svcStatus.value = n == 0 ? SvcStatus.connecting : (n == 1 ? SvcStatus.ready : SvcStatus.notReady);
      try {
        stateGlobal.videoConnCount.value = status['video_conn_count'] as int;
      } catch (_) {}
    } catch (_) {}
  }
}

/// The Dashboard of the main window, on the app's own data: the ID and the passwords of the server model, the permissions and the approval mode of the
/// options, today's minutes of the account, the state of the service, and the real list of computers.
class SdDashboard extends StatefulWidget {
  const SdDashboard({super.key});

  @override
  State<SdDashboard> createState() => _SdDashboardState();
}

class _SdDashboardState extends State<SdDashboard> {
  final _query = TextEditingController();
  // other parts of the app (links, "connect to the last computer") look for this controller
  final _idController = IDTextEditingController();
  final _svcStopped = Get.find<RxBool>(tag: 'stop-service');

  @override
  void initState() {
    super.initState();
    Get.put<IDTextEditingController>(_idController);
    SdServiceWatch.instance.start();
    _query.text = peerSearchText.value;
  }

  @override
  void dispose() {
    SdServiceWatch.instance.stop();
    peerSearchText.value = '';
    _query.dispose();
    _idController.dispose();
    super.dispose();
  }

  String _access() {
    final m = bind.mainGetOptionSync(key: kOptionAccessMode);
    return m == 'full' ? 'full' : (m == 'view' ? 'view' : 'custom');
  }

  SdUsage? _usage(AccountInfo? info) {
    if (info == null) return null;
    final used = info.usedToday;
    if (info.dailyLimit <= 0) return SdUsage('${used.round()} ${translate('min')}', 0);
    return SdUsage('${used.round()} ${translate('of')} ${info.dailyLimit} ${translate('min')}', (used / info.dailyLimit).clamp(0.0, 1.0));
  }

  SdServiceStatus _service() {
    if (_svcStopped.value) return SdServiceStatus.stopped;
    switch (stateGlobal.svcStatus.value) {
      case SvcStatus.ready:
        return SdServiceStatus.ready;
      case SvcStatus.connecting:
        return SdServiceStatus.connecting;
      default:
        return SdServiceStatus.notReady;
    }
  }

  void _launch(SdLaunch how) {
    final raw = trimID(_query.text);
    String id = '';
    if (RegExp(r'^\d{6,}$').hasMatch(raw)) {
      id = raw;
    } else {
      // a name: the first computer of the list as it is filtered now
      final cached = gFFI.peerTabModel.currentTabCachedPeers;
      if (cached.isNotEmpty) id = cached.first.id;
    }
    if (id.isEmpty) {
      SdToast.show(context, translate('Type an ID or pick a computer'));
      return;
    }
    connect(context, id,
        isFileTransfer: how == SdLaunch.files,
        isViewCamera: how == SdLaunch.camera,
        isTerminal: how == SdLaunch.terminal,
        isTcpTunneling: how == SdLaunch.tunnel);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Consumer<ServerModel>(
        builder: (context, model, _) => Obx(() {
          final info = AccountSummary.instance.info.value;
          LicenseService.instance.isLoggedInRx.value;
          final tempShown = model.approveMode != 'click' && model.verificationMethod != kUsePermanentPassword;
          final approveFixed = isOptionFixed(kOptionApproveMode);
          return SdDashboardView(
            id: model.serverId.text,
            password: model.serverPasswd.text,
            passwordShown: tempShown,
            unattended: model.approveMode != 'click',
            onUnattended: approveFixed ? null : (on) => model.setApproveMode(on ? defaultOptionApproveMode : 'click'),
            access: _access(),
            accessLocked: isOptionFixed(kOptionAccessMode),
            onAccess: (m) async {
              await bind.mainSetOption(key: kOptionAccessMode, value: m == 'custom' ? defaultOptionAccessMode : m);
              if (mounted) setState(() {});
            },
            usage: _usage(info),
            service: _service(),
            onStartService: () => start_service(true),
            onCopyId: () => sdCopy(context, model.serverId.text, translate('ID copied')),
            onCopyPassword: () => sdCopy(context, model.serverPasswd.text, translate('Password copied')),
            onNewPassword: () {
              bind.mainUpdateTemporaryPassword();
              SdToast.show(context, translate('New temporary password'));
            },
            onPasswordSettings: bind.isDisableSettings() ? null : () => DesktopSettingPage.switch2page(SettingsTabKey.safety),
            onShare: () => sdCopy(
                context,
                [
                  '${translate('Join my SystemDesk')}: ${bind.mainGetAppNameSync()}',
                  'ID: ${model.serverId.text}',
                  if (tempShown) '${translate('Password')}: ${model.serverPasswd.text}',
                ].join('\n'),
                translate('Invite copied')),
            query: _query,
            onQuery: (v) => peerSearchText.value = v,
            onSubmit: () => _launch(SdLaunch.remote),
            onLaunch: _launch,
            tabs: const SdPeerTabs(short: true),
            body: const SdPeerBody(layout: SdPeerLayout.rows),
            tr: translate,
            // a dropdown starts closed: open, the left panel is taller than the window and the service line is out of sight
            permOpen: false,
          );
        }),
      ),
    );
  }
}
