import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:flutter_hbb/screens/sd_background_service.dart';
import 'package:flutter_hbb/screens/sd_dashboard.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_peer_pages.dart';
import 'package:flutter_hbb/screens/sd_peer_tools.dart';
import 'package:flutter_hbb/screens/sd_shell.dart' show SdNav, sdPlanLabel;
import 'package:flutter_hbb/screens/sd_signin_modal.dart' show showSdSignIn;
import 'package:flutter_hbb/screens/sd_unattended_dialog.dart';
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
  @override
  void initState() {
    super.initState();
    sdLoadPeerOptions();
  }

  @override
  Widget build(BuildContext context) {
    return SdDashboardView(
      aside: ({required bool stacked, required bool scroll}) => SdThisComputer(stacked: stacked, scroll: scroll),
      tabs: const SdPeerTabs(short: true),
      tools: const SdPeerTools(),
      body: const SdPeerBody(),
      tr: translate,
    );
  }
}

/// The local option that remembers whose profile the unattended password was made for.
const String kSdUnattendedOwner = 'sd-unattended-owner';

/// The "This computer" panel on the app's own data: the ID and the passwords of the server model, the permissions and the approval mode of the options,
/// today's minutes of the account, the state of the service, and who is signed in. The Dashboard has it at the left of the lists; Devices and Sessions too.
class SdThisComputer extends StatefulWidget {
  const SdThisComputer({super.key, this.stacked = false, this.scroll = false});
  final bool stacked, scroll;

  @override
  State<SdThisComputer> createState() => _SdThisComputerState();
}

class _SdThisComputerState extends State<SdThisComputer> {
  final _svcStopped = Get.find<RxBool>(tag: 'stop-service');

  @override
  void initState() {
    super.initState();
    SdServiceWatch.instance.start();
  }

  @override
  void dispose() {
    SdServiceWatch.instance.stop();
    super.dispose();
  }

  /// The unattended password is made by the profile that is signed in and stays tied to it. Without a profile there is nobody to make it for: the sign-in opens.
  /// With a password already made by this profile the switch just turns on; otherwise the password is asked for first.
  Future<void> _setUnattended(ServerModel model, bool on, AccountInfo? info, bool signedIn) async {
    if (!on) {
      await model.setApproveMode('click');
      return;
    }
    if (!signedIn || info == null) {
      showSdSignIn();
      return;
    }
    final isSet = (await bind.mainGetCommon(key: 'local-permanent-password-set')) == 'true';
    final owner = bind.mainGetLocalOption(key: kSdUnattendedOwner);
    if (isSet && owner == info.username) {
      await model.setApproveMode(defaultOptionApproveMode);
      return;
    }
    await _askPassword(model, info, turnOn: true);
  }

  Future<void> _askPassword(ServerModel model, AccountInfo info, {required bool turnOn}) {
    return showSdUnattendedPassword(
      profile: _profile(info),
      onSubmit: (password) async {
        final ok = await bind.mainSetPermanentPasswordWithResult(password: password);
        if (!ok) return translate('Failed');
        await bind.mainSetLocalOption(key: kSdUnattendedOwner, value: info.username);
        if (turnOn) await model.setApproveMode(defaultOptionApproveMode);
        return null;
      },
    );
  }

  SdProfile _profile(AccountInfo info) => SdProfile(name: info.shownName, sub: '${translate(sdPlanLabel(info))} · ${info.username}', initials: info.initials);

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

  /// A Mac that works while the window is open, whose person said "Not now" to the banner: the small link under the state, for later. The password
  /// is asked once, by macOS, when the service is installed.
  VoidCallback? _backgroundLink() {
    if (!isMacOS || !bind.mainIsInstalled() || bind.isOutgoingOnly()) return null;
    final offer = sdBackgroundOffer(
        daemonInstalled: bind.mainIsInstalledDaemon(prompt: false),
        serviceStopped: _svcStopped.value,
        putAside: sdBackgroundLater.value);
    if (offer != SdBackgroundOffer.link) return null;
    return () {
      bind.mainIsInstalledDaemon(prompt: true);
      _watchDaemon();
    };
  }

  /// the service is installed by a script that runs on its own: look until it is there, so the link goes
  Future<void> _watchDaemon() async {
    for (var i = 0; i < 120; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      if (bind.mainIsInstalledDaemon(prompt: false)) {
        setState(() {});
        return;
      }
    }
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
          final signedIn = LicenseService.instance.isLoggedInRx.value && info != null;
          // the signed-in profile, or null
          final acc = signedIn ? info : null;
          final owner = bind.mainGetLocalOption(key: kSdUnattendedOwner);
          return SdAsideView(
            stacked: widget.stacked,
            scroll: widget.scroll,
            id: model.serverId.text,
            password: model.serverPasswd.text,
            passwordShown: tempShown,
            unattended: model.approveMode != 'click',
            onUnattended: approveFixed ? null : (on) => _setUnattended(model, on, info, signedIn),
            onUnattendedPassword: approveFixed || acc == null ? null : () => _askPassword(model, acc, turnOn: false),
            unattendedNote: acc != null && owner == acc.username ? '${translate('Password of')} ${acc.shownName}' : null,
            profile: acc == null ? null : _profile(acc),
            onProfile: SdNav.account,
            onSignIn: showSdSignIn,
            access: _access(),
            accessLocked: isOptionFixed(kOptionAccessMode),
            onAccess: (m) async {
              await bind.mainSetOption(key: kOptionAccessMode, value: m == 'custom' ? defaultOptionAccessMode : m);
              if (mounted) setState(() {});
            },
            usage: _usage(info),
            service: _service(),
            onStartService: () => start_service(true),
            onBackgroundService: _backgroundLink(),
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
            tr: translate,
          );
        }),
      ),
    );
  }
}
