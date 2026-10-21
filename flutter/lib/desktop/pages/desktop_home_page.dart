import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_hbb/common/widgets/animated_rotation_widget.dart';
import 'package:flutter_hbb/common/widgets/custom_password.dart';
import 'package:flutter_hbb/common/widgets/test_mode_badge.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/services/server_profile.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/desktop/widgets/account_sidebar.dart';
import 'package:flutter_hbb/desktop/widgets/update_progress.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:flutter_hbb/utils/multi_window_manager.dart';
import 'package:flutter_hbb/utils/platform_channel.dart';
import 'package:flutter_hbb/utils/portable_mode.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart' as window_size;
import '../widgets/button.dart';

/// Portable run: not the copy in the install folder (see runsFromInstallFolder). It works at once without installing and offers "Install".
bool _isPortableRun() {
  final dir = bind.installInstallPath();
  if (dir.isEmpty) return !bind.mainIsInstalled();
  return !runsFromInstallFolder(Platform.resolvedExecutable, dir);
}

/// macOS: copies the running app bundle to /Applications and reopens it from there. Returns why it failed; when it worked this process ends.
Future<String> _copyAppToApplications() async {
  final exe = Platform.resolvedExecutable;
  final end = exe.indexOf('.app/');
  if (end < 0) return 'This copy is not an app bundle.';
  final src = exe.substring(0, end + 4);
  final dst = '/Applications/${src.split('/').last}';
  final script =
      'rm -rf "$dst" && ditto "$src" "$dst" && (xattr -dr com.apple.quarantine "$dst" || true)';
  try {
    var r = await Process.run('/bin/sh', ['-c', script]);
    if (r.exitCode != 0) {
      r = await Process.run('osascript', [
        '-e',
        'do shell script "${script.replaceAll('"', r'\"')}" with administrator privileges'
      ]);
    }
    if (r.exitCode != 0) {
      final err = '${r.stderr}'.trim();
      if (err.contains('-128')) return 'Cancelled.';
      return err.isEmpty ? 'The copy failed.' : err;
    }
    await Process.start('/bin/sh', ['-c', 'sleep 1; open -n "$dst"'],
        mode: ProcessStartMode.detached);
  } catch (e) {
    return '$e';
  }
  exit(0);
}

/// One step of the macOS set-up that is still to do.
class _MacSetupStep {
  final IconData icon;
  final String title;
  final String text;
  final String button;
  final VoidCallback onPressed;
  const _MacSetupStep(
      this.icon, this.title, this.text, this.button, this.onPressed);
}

class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({Key? key}) : super(key: key);

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

const borderColor = Color(0xFF2F65BA);

class _DesktopHomePageState extends State<DesktopHomePage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final _leftPaneScrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;
  var systemError = '';
  StreamSubscription? _uniLinksSubscription;
  var svcStopped = false.obs;
  var watchIsCanScreenRecording = false;
  var watchIsProcessTrust = false;
  var watchIsInputMonitoring = false;
  var watchIsCanRecordAudio = false;
  Timer? _updateTimer;
  bool isCardClosed = false;

  final RxBool _block = false.obs;

  // portable run: not the copy in the install folder (decided once: the exe does not move while it runs)
  late final bool _portable =
      isWindows && !bind.isDisableInstallation() && _isPortableRun();
  bool _installing = false;
  String _installError = '';
  bool _updateDismissed = false;
  bool _macSetupDismissed = false;
  String _currentVersion = '';

  final GlobalKey _childKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isIncomingOnly = bind.isIncomingOnly();
    return _buildBlock(
        child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLeftPane(context),
        if (!isIncomingOnly) const VerticalDivider(width: 1),
        if (!isIncomingOnly) Expanded(child: buildRightPane(context)),
      ],
    ));
  }

  Widget _buildBlock({required Widget child}) {
    return buildRemoteBlock(
        block: _block, mask: true, use: canBeBlocked, child: child);
  }

  Widget buildLeftPane(BuildContext context) {
    final isIncomingOnly = bind.isIncomingOnly();
    final isOutgoingOnly = bind.isOutgoingOnly();
    final children = <Widget>[
      if (!isOutgoingOnly) buildPresetPasswordWarning(),
      if (bind.isCustomClient())
        Align(alignment: Alignment.center, child: loadPowered(context)),
      FutureBuilder<Widget>(
        future: Future.value(
            Obx(() => buildHelpCards(stateGlobal.updateUrl.value))),
        builder: (_, data) {
          if (data.hasData) {
            if (isIncomingOnly) {
              if (isInHomePage()) {
                Future.delayed(Duration(milliseconds: 300), () {
                  _updateWindowSize();
                });
              }
            }
            return data.data!;
          } else {
            return const Offstage();
          }
        },
      ),
    ];
    if (isIncomingOnly) {
      children.addAll([
        Divider(color: const Color(0xFF333640)),
        OnlineStatusWidget(
          onSvcStatusChanged: () {
            if (isInHomePage()) {
              Future.delayed(Duration(milliseconds: 300), () {
                _updateWindowSize();
              });
            }
          },
        ).marginOnly(bottom: 6, right: 6)
      ]);
    }
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Container(
        width: 208.0,
        color: const Color(0xFF1A1C22),
        child: isIncomingOnly
            ? Stack(
                children: [
                  Column(
                    children: [
                      _buildSidebarHeader(context),
                      SingleChildScrollView(
                        controller: _leftPaneScrollController,
                        child: Column(key: _childKey, children: children),
                      ),
                      Expanded(child: Container()),
                    ],
                  ),
                ],
              )
            : Column(
                children: [
                  _buildSidebarHeader(context),
                  const SizedBox(height: 8),
                  _buildNavItem(context,
                      icon: Icons.computer_outlined,
                      label: 'Remote Control',
                      isActive: true),
                  const SidebarSettingsNav(),
                  const Expanded(child: SidebarInfo()),
                  _buildSidebarFooter(context),
                ],
              ),
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          SvgPicture.asset('assets/logo_white.svg', height: 22),
          const SizedBox(width: 10),
          Text(
            'SystemDesk',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE2E4EA),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarFooter(BuildContext context) {
    return SidebarAccountFooter(testBadge: kIsTestMode ? const TestModeBadge() : null);
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF33302A) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: isActive
                  ? BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 17,
                color: isActive
                    ? const Color(0xFF241700)
                    : const Color(0xFF8B8F99),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                translate(label),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? const Color(0xFFFFC670)
                      : const Color(0xFF8B8F99),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One click: administrator prompt, copy to the install folder, service, shortcuts; then the installed copy starts and this one closes
  /// (that exit happens inside the call). Declining the prompt, or a failure, leaves this window open and says so.
  Future<void> _installNow() async {
    if (_installing) return;
    setState(() {
      _installing = true;
      _installError = '';
    });
    await rustDeskWinManager.closeAllSubWindows();
    final failure = await bind.installInstallMeChecked(
        options: 'startmenu desktopicon', path: '');
    if (!mounted) return;
    setState(() {
      _installing = false;
      _installError = failure;
    });
  }

  /// macOS has no installer: the app is copied to Applications, then the permissions and the background service are asked for, one at a
  /// time. (The help cards in buildHelpCards do the same, but only the incoming-only layout shows them.)
  _MacSetupStep? _macSetupStep() {
    if (!isMacOS || _macSetupDismissed) return null;
    final app = bind.mainGetAppNameSync();
    final outgoingOnly = bind.isOutgoingOnly();
    if (!bind.isDisableInstallation() && !bind.mainIsInstalled()) {
      return _MacSetupStep(
          Icons.download_for_offline_outlined,
          'Running without installing',
          'Install $app to your Applications folder. It reopens from there and then asks for the permissions it needs.',
          'Install $app',
          _installMac);
    }
    if (outgoingOnly) return null;
    if (!bind.mainIsCanScreenRecording(prompt: false)) {
      return _MacSetupStep(
          Icons.screen_share_outlined,
          'Allow screen recording',
          'So this Mac can be seen from another device, $app needs your permission in System Settings. Switch it on there, then come back.',
          'Allow', () {
        bind.mainIsCanScreenRecording(prompt: true);
        watchIsCanScreenRecording = true;
      });
    }
    if (!bind.mainIsProcessTrusted(prompt: false)) {
      return _MacSetupStep(
          Icons.mouse_outlined,
          'Allow control of this Mac',
          'So another device can use the mouse and keyboard here, switch on $app under Accessibility in System Settings.',
          'Allow', () {
        bind.mainIsProcessTrusted(prompt: true);
        watchIsProcessTrust = true;
      });
    }
    if (!bind.mainIsCanInputMonitoring(prompt: false)) {
      return _MacSetupStep(
          Icons.keyboard_outlined,
          'Allow keyboard input',
          'Switch on $app under Input Monitoring in System Settings, so keys typed on the other device reach this Mac.',
          'Allow', () {
        bind.mainIsCanInputMonitoring(prompt: true);
        watchIsInputMonitoring = true;
      });
    }
    if (!svcStopped.value && !bind.mainIsInstalledDaemon(prompt: false)) {
      return _MacSetupStep(
          Icons.shield_outlined,
          'Keep $app ready in the background',
          'Installs the background service, so this Mac can be reached after a restart and at the login screen. macOS asks for your password.',
          'Install', () {
        bind.mainIsInstalledDaemon(prompt: true);
        _watchMacService();
      });
    }
    return null;
  }

  /// the service is installed by a script that runs on its own: look until it is there
  Future<void> _watchMacService() async {
    for (var i = 0; i < 120; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      if (bind.mainIsInstalledDaemon(prompt: false)) {
        setState(() {});
        return;
      }
    }
  }

  Future<void> _installMac() async {
    if (_installing) return;
    setState(() {
      _installing = true;
      _installError = '';
    });
    final failure = await _copyAppToApplications();
    if (!mounted) return;
    setState(() {
      _installing = false;
      _installError = failure;
    });
  }

  /// A newer version exists (the app looked at its own releases). Installed copy: one click downloads it, installs it and restarts the
  /// app. A portable copy cannot replace itself: it is sent to the download page.
  Widget _buildUpdateBanner(bool dark, String updateUrl) {
    final app = bind.mainGetAppNameSync();
    final version = bind.mainGetNewVersion();
    final ink = dark ? const Color(0xFFECEAE4) : const Color(0xFF1A1712);
    final muted = dark ? const Color(0xFFB4B7C0) : const Color(0xFF5E584B);
    final canInstall = !_portable;
    return Container(
      key: const ValueKey('sd-update-banner'),
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1F2A22) : const Color(0xFFE7F8EF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: dark ? const Color(0xFF2E4A37) : const Color(0xFFBFEBD3)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF22BD77).withOpacity(dark ? 0.2 : 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.system_update_alt_rounded,
                size: 21,
                color: dark ? const Color(0xFF6EE0A8) : const Color(0xFF17794D)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$app $version is available',
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700, color: ink)),
                const SizedBox(height: 2),
                Text(
                  _currentVersion.isEmpty
                      ? 'A newer version is ready.'
                      : canInstall
                          ? 'You are using $_currentVersion. One click downloads and installs it, then $app restarts by itself.'
                          : 'You are using $_currentVersion. This copy runs without installing, so download the new version.',
                  style: TextStyle(fontSize: 12.5, height: 1.35, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => launchUrl(Uri.parse(updateUrl)),
            child: Text("What's new",
                style: TextStyle(
                    color: dark ? const Color(0xFF6EE0A8) : const Color(0xFF17794D),
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () =>
                canInstall ? handleUpdate(updateUrl) : launchUrl(Uri.parse(updateUrl)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22BD77),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(canInstall ? 'Update now' : 'Download',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip: 'Later',
            icon: Icon(Icons.close_rounded, size: 18, color: muted),
            onPressed: () => setState(() => _updateDismissed = true),
          ),
        ],
      ),
    );
  }

  Widget _buildPortableBanner(bool dark) {
    final app = bind.mainGetAppNameSync();
    final ink = dark ? const Color(0xFFECEAE4) : const Color(0xFF1A1712);
    final muted = dark ? const Color(0xFFB4B7C0) : const Color(0xFF5E584B);
    final failed = _installError.isNotEmpty;
    return Container(
      key: const ValueKey('sd-portable-banner'),
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2A2417) : const Color(0xFFFFF4DC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: dark ? const Color(0xFF5A4518) : const Color(0xFFFBE0A0)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(dark ? 0.22 : 0.2),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.download_for_offline_outlined,
                size: 21,
                color: dark ? const Color(0xFFF0C26B) : const Color(0xFF8A5A00)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Running without installing',
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700, color: ink)),
                const SizedBox(height: 2),
                Text(
                  failed
                      ? 'Installation was not completed: $_installError'
                      : 'Install $app to keep it ready in the background, so this computer can be reached when nobody is sitting at it.',
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: failed ? const Color(0xFFD9534F) : muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _installing ? null : _installNow,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF241700),
              disabledBackgroundColor: const Color(0xFFF59E0B).withOpacity(0.55),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _installing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF241700)))
                : Text('Install $app',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildMacSetupBanner(bool dark, _MacSetupStep step) {
    final ink = dark ? const Color(0xFFECEAE4) : const Color(0xFF1A1712);
    final muted = dark ? const Color(0xFFB4B7C0) : const Color(0xFF5E584B);
    final failed = _installError.isNotEmpty;
    return Container(
      key: const ValueKey('sd-mac-setup-banner'),
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2A2417) : const Color(0xFFFFF4DC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: dark ? const Color(0xFF5A4518) : const Color(0xFFFBE0A0)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(dark ? 0.22 : 0.2),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(step.icon,
                size: 21,
                color: dark ? const Color(0xFFF0C26B) : const Color(0xFF8A5A00)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title,
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700, color: ink)),
                const SizedBox(height: 2),
                Text(
                  failed ? 'Installation was not completed: $_installError' : step.text,
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: failed ? const Color(0xFFD9534F) : muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _installing ? null : step.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF241700),
              disabledBackgroundColor: const Color(0xFFF59E0B).withOpacity(0.55),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _installing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF241700)))
                : Text(step.button,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip: 'Later',
            icon: Icon(Icons.close_rounded, size: 18, color: muted),
            onPressed: () => setState(() => _macSetupDismissed = true),
          ),
        ],
      ),
    );
  }

  buildRightPane(BuildContext context) {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final macStep = _macSetupStep();
      return Theme(
        data: isDark ? MyTheme.darkTheme : MyTheme.lightTheme,
        child: SizedBox.expand(
          child: ColoredBox(
            color: isDark ? const Color(0xFF18191E) : Colors.white,
            child: Column(
              children: [
                Obx(() => stateGlobal.updateUrl.value.isEmpty || _updateDismissed
                    ? const SizedBox.shrink()
                    : _buildUpdateBanner(isDark, stateGlobal.updateUrl.value)),
                if (_portable) _buildPortableBanner(isDark),
                if (macStep != null) _buildMacSetupBanner(isDark, macStep),
                const Expanded(child: ConnectionPage()),
              ],
            ),
          ),
        ),
      );
    });
  }

  buildIDBoard(BuildContext context) {
    return const SizedBox.shrink();
  }

  Widget buildPopupMenu(BuildContext context) {
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    RxBool hover = false.obs;
    return InkWell(
      onTap: DesktopTabPage.onAddSetting,
      child: Tooltip(
        message: translate('Settings'),
        child: Obx(
          () => CircleAvatar(
            radius: 15,
            backgroundColor: hover.value
                ? Theme.of(context).scaffoldBackgroundColor
                : Theme.of(context).colorScheme.background,
            child: Icon(
              Icons.more_vert_outlined,
              size: 20,
              color: hover.value ? textColor : textColor?.withOpacity(0.5),
            ),
          ),
        ),
      ),
      onHover: (value) => hover.value = value,
    );
  }

  buildPasswordBoard(BuildContext context) {
    return ChangeNotifierProvider.value(
        value: gFFI.serverModel,
        child: Consumer<ServerModel>(
          builder: (context, model, child) {
            return buildPasswordBoard2(context, model);
          },
        ));
  }

  buildPasswordBoard2(BuildContext context, ServerModel model) {
    return const SizedBox.shrink();
  }

  buildTip(BuildContext context) {
    return const SizedBox.shrink();
  }

  Widget buildHelpCards(String updateUrl) {
    if (!bind.isCustomClient() &&
        updateUrl.isNotEmpty &&
        !isCardClosed &&
        bind.mainUriPrefixSync().contains('rustdesk')) {
      final isToUpdate = (isWindows || isMacOS) && bind.mainIsInstalled();
      String btnText = isToUpdate ? 'Update' : 'Download';
      GestureTapCallback onPressed = () async {
        final Uri url = Uri.parse('https://systemdesk.net/download');
        await launchUrl(url);
      };
      if (isToUpdate) {
        onPressed = () {
          handleUpdate(updateUrl);
        };
      }
      return buildInstallCard(
          "Status",
          "${translate("new-version-of-{${bind.mainGetAppNameSync()}}-tip")} (${bind.mainGetNewVersion()}).",
          btnText,
          onPressed,
          closeButton: true,
          help: isToUpdate ? 'Changelog' : null,
          link: isToUpdate
              ? updateUrl
              : null);
    }
    if (systemError.isNotEmpty) {
      return buildInstallCard("", systemError, "", () {});
    }

    if (isWindows && !bind.isDisableInstallation()) {
      if (_isPortableRun()) {
        return buildInstallCard("", bind.isOutgoingOnly() ? "" : "install_tip",
            "Install ${bind.mainGetAppNameSync()}", _installNow);
      } else if (bind.mainIsInstalledLowerVersion()) {
        return buildInstallCard(
            "Status", "Your installation is lower version.", "Click to upgrade",
            () async {
          await rustDeskWinManager.closeAllSubWindows();
          bind.mainUpdateMe();
        });
      }
    } else if (isMacOS) {
      final isOutgoingOnly = bind.isOutgoingOnly();
      if (!(isOutgoingOnly || bind.mainIsCanScreenRecording(prompt: false))) {
        return buildInstallCard("Permissions", "config_screen", "Configure",
            () async {
          bind.mainIsCanScreenRecording(prompt: true);
          watchIsCanScreenRecording = true;
        }, help: 'Help', link: translate("doc_mac_permission"));
      } else if (!isOutgoingOnly && !bind.mainIsProcessTrusted(prompt: false)) {
        return buildInstallCard("Permissions", "config_acc", "Configure",
            () async {
          bind.mainIsProcessTrusted(prompt: true);
          watchIsProcessTrust = true;
        }, help: 'Help', link: translate("doc_mac_permission"));
      } else if (!bind.mainIsCanInputMonitoring(prompt: false)) {
        return buildInstallCard("Permissions", "config_input", "Configure",
            () async {
          bind.mainIsCanInputMonitoring(prompt: true);
          watchIsInputMonitoring = true;
        }, help: 'Help', link: translate("doc_mac_permission"));
      } else if (!isOutgoingOnly &&
          !svcStopped.value &&
          bind.mainIsInstalled() &&
          !bind.mainIsInstalledDaemon(prompt: false)) {
        return buildInstallCard("", "install_daemon_tip", "Install", () async {
          bind.mainIsInstalledDaemon(prompt: true);
        });
      }
      //// Disable microphone configuration for macOS. We will request the permission when needed.
      // else if ((await osxCanRecordAudio() !=
      //     PermissionAuthorizeType.authorized)) {
      //   return buildInstallCard("Permissions", "config_microphone", "Configure",
      //       () async {
      //     osxRequestAudio();
      //     watchIsCanRecordAudio = true;
      //   });
      // }
    } else if (isLinux) {
      if (bind.isOutgoingOnly()) {
        return Container();
      }
      final LinuxCards = <Widget>[];
      if (bind.isSelinuxEnforcing()) {
        // Check is SELinux enforcing, but show user a tip of is SELinux enabled for simple.
        final keyShowSelinuxHelpTip = "show-selinux-help-tip";
        if (bind.mainGetLocalOption(key: keyShowSelinuxHelpTip) != 'N') {
          LinuxCards.add(buildInstallCard(
            "Warning",
            "selinux_tip",
            "",
            () async {},
            marginTop: LinuxCards.isEmpty ? 20.0 : 5.0,
            help: 'Help',
            link:
                'https://systemdesk.net/docs/linux/permissions',
            closeButton: true,
            closeOption: keyShowSelinuxHelpTip,
          ));
        }
      }
      if (bind.mainCurrentIsWayland()) {
        LinuxCards.add(buildInstallCard(
            "Warning", "wayland_experiment_tip", "", () async {},
            marginTop: LinuxCards.isEmpty ? 20.0 : 5.0,
            help: 'Help',
            link: 'https://systemdesk.net/docs/linux/wayland'));
      } else if (bind.mainIsLoginWayland()) {
        LinuxCards.add(buildInstallCard("Warning",
            "Login screen using Wayland is not supported", "", () async {},
            marginTop: LinuxCards.isEmpty ? 20.0 : 5.0,
            help: 'Help',
            link: 'https://systemdesk.net/docs/linux/login-screen'));
      }
      if (LinuxCards.isNotEmpty) {
        return Column(
          children: LinuxCards,
        );
      }
    }
    if (bind.isIncomingOnly()) {
      return Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton(
          onPressed: () {
            SystemNavigator.pop(); // Close the application
            // https://github.com/flutter/flutter/issues/66631
            if (isWindows) {
              exit(0);
            }
          },
          child: Text(translate('Quit')),
        ),
      ).marginAll(14);
    }
    return Container();
  }

  Widget buildInstallCard(String title, String content, String btnText,
      GestureTapCallback onPressed,
      {double marginTop = 20.0,
      String? help,
      String? link,
      bool? closeButton,
      String? closeOption}) {
    if (bind.mainGetBuildinOption(key: kOptionHideHelpCards) == 'Y' &&
        content != 'install_daemon_tip') {
      return const SizedBox();
    }
    void closeCard() async {
      if (closeOption != null) {
        await bind.mainSetLocalOption(key: closeOption, value: 'N');
        if (bind.mainGetLocalOption(key: closeOption) == 'N') {
          setState(() {
            isCardClosed = true;
          });
        }
      } else {
        setState(() {
          isCardClosed = true;
        });
      }
    }

    return Stack(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(
              16, marginTop, 16, bind.isIncomingOnly() ? marginTop : 0),
          child: Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF059669),
                  Color(0xFF10e88a),
                ],
              )),
              padding: EdgeInsets.all(20),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (title.isNotEmpty
                          ? <Widget>[
                              Center(
                                  child: Text(
                                translate(title),
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              ).marginOnly(bottom: 6)),
                            ]
                          : <Widget>[]) +
                      <Widget>[
                        if (content.isNotEmpty)
                          Text(
                            translate(content),
                            style: TextStyle(
                                height: 1.5,
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                                fontSize: 13),
                          ).marginOnly(bottom: 20)
                      ] +
                      (btnText.isNotEmpty
                          ? <Widget>[
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FixedWidthButton(
                                      width: 150,
                                      padding: 8,
                                      isOutline: true,
                                      text: translate(btnText),
                                      textColor: Colors.white,
                                      borderColor: Colors.white,
                                      textSize: 20,
                                      radius: 10,
                                      onTap: onPressed,
                                    )
                                  ])
                            ]
                          : <Widget>[]) +
                      (help != null
                          ? <Widget>[
                              Center(
                                  child: InkWell(
                                      onTap: () async =>
                                          await launchUrl(Uri.parse(link!)),
                                      child: Text(
                                        translate(help),
                                        style: TextStyle(
                                            decoration:
                                                TextDecoration.underline,
                                            color: Colors.white,
                                            fontSize: 12),
                                      )).marginOnly(top: 6)),
                            ]
                          : <Widget>[]))),
        ),
        if (closeButton != null && closeButton == true)
          Positioned(
            top: 18,
            right: 0,
            child: IconButton(
              icon: Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
              onPressed: closeCard,
            ),
          ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    bind.mainGetVersion().then((v) {
      if (mounted) setState(() => _currentVersion = v);
    });
    _updateTimer = periodic_immediate(const Duration(seconds: 1), () async {
      await gFFI.serverModel.fetchID();
      final error = await bind.mainGetError();
      if (systemError != error) {
        systemError = error;
        setState(() {});
      }
      final v = await mainGetBoolOption(kOptionStopService);
      if (v != svcStopped.value) {
        svcStopped.value = v;
        setState(() {});
      }
      if (watchIsCanScreenRecording) {
        if (bind.mainIsCanScreenRecording(prompt: false)) {
          watchIsCanScreenRecording = false;
          setState(() {});
        }
      }
      if (watchIsProcessTrust) {
        if (bind.mainIsProcessTrusted(prompt: false)) {
          watchIsProcessTrust = false;
          setState(() {});
        }
      }
      if (watchIsInputMonitoring) {
        if (bind.mainIsCanInputMonitoring(prompt: false)) {
          watchIsInputMonitoring = false;
          // Do not notify for now.
          // Monitoring may not take effect until the process is restarted.
          // rustDeskWinManager.call(
          //     WindowType.RemoteDesktop, kWindowDisableGrabKeyboard, '');
          setState(() {});
        }
      }
      if (watchIsCanRecordAudio) {
        if (isMacOS) {
          Future.microtask(() async {
            if ((await osxCanRecordAudio() ==
                PermissionAuthorizeType.authorized)) {
              watchIsCanRecordAudio = false;
              setState(() {});
            }
          });
        } else {
          watchIsCanRecordAudio = false;
          setState(() {});
        }
      }
    });
    Get.put<RxBool>(svcStopped, tag: 'stop-service');
    rustDeskWinManager.registerActiveWindowListener(onActiveWindowChanged);

    screenToMap(window_size.Screen screen) => {
          'frame': {
            'l': screen.frame.left,
            't': screen.frame.top,
            'r': screen.frame.right,
            'b': screen.frame.bottom,
          },
          'visibleFrame': {
            'l': screen.visibleFrame.left,
            't': screen.visibleFrame.top,
            'r': screen.visibleFrame.right,
            'b': screen.visibleFrame.bottom,
          },
          'scaleFactor': screen.scaleFactor,
        };

    bool isChattyMethod(String methodName) {
      switch (methodName) {
        case kWindowBumpMouse: return true;
      }

      return false;
    }

    rustDeskWinManager.setMethodHandler((call, fromWindowId) async {
      if (!isChattyMethod(call.method)) {
        debugPrint(
          "[Main] call ${call.method} with args ${call.arguments} from window $fromWindowId");
      }
      if (call.method == kWindowMainWindowOnTop) {
        windowOnTop(null);
      } else if (call.method == kWindowRefreshCurrentUser) {
        gFFI.userModel.refreshCurrentUser();
      } else if (call.method == kWindowGetScreenList) {
        return jsonEncode(
            (await window_size.getScreenList()).map(screenToMap).toList());
      } else if (call.method == kWindowActionRebuild) {
        reloadCurrentWindow();
      } else if (call.method == kWindowEventShow) {
        await rustDeskWinManager.registerActiveWindow(call.arguments["id"]);
      } else if (call.method == kWindowEventHide) {
        await rustDeskWinManager.unregisterActiveWindow(call.arguments['id']);
      } else if (call.method == kWindowConnect) {
        await connectMainDesktop(
          call.arguments['id'],
          isFileTransfer: call.arguments['isFileTransfer'],
          isViewCamera: call.arguments['isViewCamera'],
          isTerminal: call.arguments['isTerminal'],
          isTcpTunneling: call.arguments['isTcpTunneling'],
          isRDP: call.arguments['isRDP'],
          password: call.arguments['password'],
          forceRelay: call.arguments['forceRelay'],
          connToken: call.arguments['connToken'],
        );
      } else if (call.method == kWindowBumpMouse) {
        return RdPlatformChannel.instance.bumpMouse(
          dx: call.arguments['dx'],
          dy: call.arguments['dy']);
      } else if (call.method == kWindowEventMoveTabToNewWindow) {
        final args = call.arguments.split(',');
        int? windowId;
        try {
          windowId = int.parse(args[0]);
        } catch (e) {
          debugPrint("Failed to parse window id '${call.arguments}': $e");
        }
        WindowType? windowType;
        try {
          windowType = WindowType.values.byName(args[3]);
        } catch (e) {
          debugPrint("Failed to parse window type '${call.arguments}': $e");
        }
        if (windowId != null && windowType != null) {
          await rustDeskWinManager.moveTabToNewWindow(
              windowId, args[1], args[2], windowType);
        }
      } else if (call.method == kWindowEventOpenMonitorSession) {
        final args = jsonDecode(call.arguments);
        final windowId = args['window_id'] as int;
        final peerId = args['peer_id'] as String;
        final display = args['display'] as int;
        final displayCount = args['display_count'] as int;
        final windowType = args['window_type'] as int;
        final screenRect = parseParamScreenRect(args);
        await rustDeskWinManager.openMonitorSession(
            windowId, peerId, display, displayCount, screenRect, windowType);
      } else if (call.method == kWindowEventRemoteWindowCoords) {
        final windowId = int.tryParse(call.arguments);
        if (windowId != null) {
          return jsonEncode(
              await rustDeskWinManager.getOtherRemoteWindowCoords(windowId));
        }
      }
    });
    _uniLinksSubscription = listenUniLinks();

    if (bind.isIncomingOnly()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateWindowSize();
      });
    }
    WidgetsBinding.instance.addObserver(this);
  }

  _updateWindowSize() {
    RenderObject? renderObject = _childKey.currentContext?.findRenderObject();
    if (renderObject == null) {
      return;
    }
    if (renderObject is RenderBox) {
      final size = renderObject.size;
      if (size != imcomingOnlyHomeSize) {
        imcomingOnlyHomeSize = size;
        windowManager.setSize(getIncomingOnlyHomeSize());
      }
    }
  }

  @override
  void dispose() {
    _uniLinksSubscription?.cancel();
    Get.delete<RxBool>(tag: 'stop-service');
    _updateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      shouldBeBlocked(_block, canBeBlocked);
    }
  }
}

void setPasswordDialog({VoidCallback? notEmptyCallback}) async {
  final p0 = TextEditingController(text: "");
  final p1 = TextEditingController(text: "");
  var errMsg0 = "";
  var errMsg1 = "";
  final localPasswordSet =
      (await bind.mainGetCommon(key: "local-permanent-password-set")) == "true";
  final permanentPasswordSet =
      (await bind.mainGetCommon(key: "permanent-password-set")) == "true";
  final presetPassword = permanentPasswordSet && !localPasswordSet;
  var canSubmit = false;
  final RxString rxPass = "".obs;
  final rules = [
    DigitValidationRule(),
    UppercaseValidationRule(),
    LowercaseValidationRule(),
    // SpecialCharacterValidationRule(),
    MinCharactersValidationRule(8),
  ];
  final maxLength = bind.mainMaxEncryptLen();
  final statusTip = localPasswordSet
      ? translate('password-hidden-tip')
      : (presetPassword ? translate('preset-password-in-use-tip') : '');
  final showStatusTipOnMobile =
      statusTip.isNotEmpty && !isDesktop && !isWebDesktop;

  gFFI.dialogManager.show((setState, close, context) {
    updateCanSubmit() {
      canSubmit = p0.text.trim().isNotEmpty || p1.text.trim().isNotEmpty;
    }

    submit() async {
      if (!canSubmit) {
        return;
      }
      setState(() {
        errMsg0 = "";
        errMsg1 = "";
      });
      final pass = p0.text.trim();
      if (pass.isNotEmpty) {
        final Iterable violations = rules.where((r) => !r.validate(pass));
        if (violations.isNotEmpty) {
          setState(() {
            errMsg0 =
                '${translate('Prompt')}: ${violations.map((r) => r.name).join(', ')}';
          });
          return;
        }
      }
      if (p1.text.trim() != pass) {
        setState(() {
          errMsg1 =
              '${translate('Prompt')}: ${translate("The confirmation is not identical.")}';
        });
        return;
      }
      final ok = await bind.mainSetPermanentPasswordWithResult(password: pass);
      if (!ok) {
        setState(() {
          errMsg0 = '${translate('Prompt')}: ${translate("Failed")}';
        });
        return;
      }
      if (pass.isNotEmpty) {
        notEmptyCallback?.call();
      }
      close();
    }

    return CustomAlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.key, color: MyTheme.accent),
          Text(translate("Set Password")).paddingOnly(left: 10),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: showStatusTipOnMobile ? 0.0 : 6.0,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                        labelText: translate('Password'),
                        errorText: errMsg0.isNotEmpty ? errMsg0 : null),
                    controller: p0,
                    autofocus: true,
                    onChanged: (value) {
                      rxPass.value = value.trim();
                      setState(() {
                        errMsg0 = '';
                        updateCanSubmit();
                      });
                    },
                    maxLength: maxLength,
                  ).workaroundFreezeLinuxMint(),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(child: PasswordStrengthIndicator(password: rxPass)),
              ],
            ).marginOnly(top: 2, bottom: showStatusTipOnMobile ? 2 : 8),
            SizedBox(
              height: showStatusTipOnMobile ? 0.0 : 8.0,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                        labelText: translate('Confirmation'),
                        errorText: errMsg1.isNotEmpty ? errMsg1 : null),
                    controller: p1,
                    onChanged: (value) {
                      setState(() {
                        errMsg1 = '';
                        updateCanSubmit();
                      });
                    },
                    maxLength: maxLength,
                  ).workaroundFreezeLinuxMint(),
                ),
              ],
            ),
            if (statusTip.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.info, color: Colors.amber, size: 18)
                      .marginOnly(right: 6),
                  Expanded(
                      child: Text(
                    statusTip,
                    style: const TextStyle(fontSize: 13, height: 1.1),
                  ))
                ],
              ).marginOnly(top: 6, bottom: 2),
            SizedBox(
              height: showStatusTipOnMobile ? 0.0 : 8.0,
            ),
            Obx(() => Wrap(
                  runSpacing: showStatusTipOnMobile ? 2.0 : 8.0,
                  spacing: 4,
                  children: rules.map((e) {
                    var checked = e.validate(rxPass.value.trim());
                    return Chip(
                        label: Text(
                          e.name,
                          style: TextStyle(
                              color: checked
                                  ? const Color(0xFF0A9471)
                                  : Color.fromARGB(255, 198, 86, 157)),
                        ),
                        backgroundColor: checked
                            ? const Color(0xFFD0F7ED)
                            : Color.fromARGB(255, 247, 205, 232));
                  }).toList(),
                ))
          ],
        ),
      ),
      actions: (() {
        final cancelButton = dialogButton(
          "Cancel",
          icon: Icon(Icons.close_rounded),
          onPressed: close,
          isOutline: true,
        );
        final removeButton = dialogButton(
          "Remove",
          icon: Icon(Icons.delete_outline_rounded),
          onPressed: () async {
            setState(() {
              errMsg0 = "";
              errMsg1 = "";
            });
            final ok =
                await bind.mainSetPermanentPasswordWithResult(password: "");
            if (!ok) {
              setState(() {
                errMsg0 = '${translate('Prompt')}: ${translate("Failed")}';
              });
              return;
            }
            close();
          },
          buttonStyle: ButtonStyle(
              backgroundColor: MaterialStatePropertyAll(Colors.red)),
        );
        final okButton = dialogButton(
          "OK",
          icon: Icon(Icons.done_rounded),
          onPressed: canSubmit ? submit : null,
        );
        if (!isDesktop && !isWebDesktop && localPasswordSet) {
          return [
            Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    cancelButton,
                    const SizedBox(width: 4),
                    removeButton,
                    const SizedBox(width: 4),
                    okButton,
                  ],
                ),
              ),
            ),
          ];
        }
        return [
          cancelButton,
          if (localPasswordSet) removeButton,
          okButton,
        ];
      })(),
      onSubmit: canSubmit ? submit : null,
      onCancel: close,
    );
  });
}
