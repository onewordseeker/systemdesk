import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/widgets/update_progress.dart';
import 'package:flutter_hbb/mobile/widgets/android_update.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:flutter_hbb/screens/sd_palette.dart';
import 'package:flutter_hbb/services/app_notices.dart';
import 'package:flutter_hbb/utils/multi_window_manager.dart';
import 'package:flutter_hbb/utils/platform_channel.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

/// The screen over the whole app while the console requires an update this app does not have: everything behind it is blurred and cannot
/// be reached, the card says what to do and cannot be closed. It is an entry in the app's global overlay, so the dialogs that follow
/// (the download progress) open above it.
class SdUpdateGate {
  SdUpdateGate._();

  /// Set by AppPoll; null = nothing is required (the screen is removed).
  static final required = Rxn<RequiredUpdate>();
  static String currentVersion = '';

  /// The Android download shows its progress in a dialog of the page below the overlay: the screen steps aside while it runs.
  static final _aside = ValueNotifier<bool>(false);

  static OverlayEntry? _entry;
  static Timer? _retry;

  static bool get showing => _entry != null;

  static void set(RequiredUpdate? info) {
    required.value = info;
    _retry?.cancel();
    if (info == null) {
      _entry?.remove();
      _entry = null;
    } else {
      _insert();
    }
  }

  static void _insert([int tries = 0]) {
    if (_entry != null || required.value == null) return;
    final overlay = globalKey.currentState?.overlay;
    if (overlay == null) {
      // the app is still starting: try again shortly
      if (tries < 60) _retry = Timer(const Duration(milliseconds: 500), () => _insert(tries + 1));
      return;
    }
    _entry = OverlayEntry(
      builder: (context) => ValueListenableBuilder<bool>(
        valueListenable: _aside,
        builder: (_, aside, __) => Offstage(
          offstage: aside,
          child: Obx(() {
            final info = required.value;
            return info == null
                ? const SizedBox.shrink()
                : UpdateGateScreen(
                    info: info,
                    currentVersion: currentVersion,
                    onUpdate: () => updateNow(info),
                    onQuit: _canQuit ? quit : null,
                  );
          }),
        ),
      ),
    );
    overlay.insert(_entry!);
  }

  static bool get _canQuit => !isWeb && !isIOS;

  /// Installed copies download and install the update by themselves; the other copies are sent to the download page.
  static Future<void> updateNow(RequiredUpdate info) async {
    final page = info.downloadUrl.startsWith('http') ? info.downloadUrl : '';
    final url = stateGlobal.updateUrl.value;
    Future<void> openPage() async {
      final target = page.isNotEmpty ? page : url;
      if (target.startsWith('http')) await launchUrl(Uri.parse(target));
    }

    try {
      if (isAndroid) {
        final context = globalKey.currentContext;
        if (url.isEmpty || context == null) return openPage();
        _aside.value = true;
        try {
          await startAndroidUpdate(context, url);
        } finally {
          _aside.value = false;
        }
      } else if (isDesktop && (isWindows || isMacOS) && bind.mainIsInstalled() && url.isNotEmpty) {
        handleUpdate(url);
      } else {
        await openPage();
      }
    } catch (e) {
      debugPrint('SdUpdateGate.updateNow: $e');
      await openPage();
    }
  }

  static Future<void> quit() async {
    if (isAndroid) {
      SystemNavigator.pop();
      return;
    }
    try {
      await rustDeskWinManager.closeAllSubWindows();
    } catch (_) {}
    if (isMacOS) {
      RdPlatformChannel.instance.terminate();
    } else {
      SystemNavigator.pop();
      if (isWindows) exit(0);
    }
  }
}

/// The blurred screen with its card. Takes everything it shows as arguments, so it can be drawn on its own.
class UpdateGateScreen extends StatelessWidget {
  const UpdateGateScreen({
    Key? key,
    required this.info,
    required this.currentVersion,
    required this.onUpdate,
    this.onQuit,
    this.draggable = true,
  }) : super(key: key);

  final RequiredUpdate info;
  final String currentVersion;
  final VoidCallback onUpdate;
  final VoidCallback? onQuit;

  /// desktop: the custom title bar is covered, so the top strip moves the window
  final bool draggable;

  @override
  Widget build(BuildContext context) {
    final p = SdPalette.of(context);
    return Material(
      type: MaterialType.transparency,
      child: FocusScope(
        autofocus: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: ModalBarrier(
                dismissible: false,
                color: Colors.black.withOpacity(p.dark ? 0.68 : 0.52),
              ),
            ),
            if (draggable && isDesktop)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 40,
                child: DragToMoveArea(child: SizedBox.expand()),
              ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: UpdateGateCard(
                  info: info,
                  currentVersion: currentVersion,
                  onUpdate: onUpdate,
                  onQuit: onQuit,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UpdateGateCard extends StatelessWidget {
  const UpdateGateCard({
    Key? key,
    required this.info,
    required this.currentVersion,
    required this.onUpdate,
    this.onQuit,
  }) : super(key: key);

  final RequiredUpdate info;
  final String currentVersion;
  final VoidCallback onUpdate;
  final VoidCallback? onQuit;

  @override
  Widget build(BuildContext context) {
    final p = SdPalette.of(context);
    const amber = SdPalette.amber;
    final rows = <(String, String)>[
      if (parseAppVersion(currentVersion) != null) ('You have', currentVersion),
      ('Required', '${info.version} or newer'),
    ];
    return Container(
      key: const ValueKey('sd-update-gate'),
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
      decoration: BoxDecoration(
        color: p.fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 40, offset: Offset(0, 16))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: amber.withOpacity(p.dark ? 0.2 : 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.system_update_alt_rounded, size: 26, color: p.hit),
          ),
          const SizedBox(height: 18),
          Text('Update SystemDesk',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: p.ink, height: 1.2)),
          const SizedBox(height: 10),
          Text('This update is required.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.ink, height: 1.4)),
          const SizedBox(height: 2),
          Text("You can't use SystemDesk until it is installed.",
              style: TextStyle(fontSize: 14.5, color: p.muted, height: 1.45)),
          if (info.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(info.message, style: TextStyle(fontSize: 14, color: p.muted, height: 1.45)),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.line),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: p.line))),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(rows[i].$1,
                                style: TextStyle(fontSize: 13, color: p.muted, fontWeight: FontWeight.w500))),
                        Text(rows[i].$2,
                            style: TextStyle(fontSize: 13.5, color: p.ink, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  autofocus: true,
                  onPressed: onUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: amber,
                    foregroundColor: p.onAmber,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Update now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
              if (onQuit != null) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: onQuit,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: p.ink,
                    side: BorderSide(color: p.dark ? const Color(0xFF4A4D57) : const Color(0xFFD9D3C4)),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Quit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
