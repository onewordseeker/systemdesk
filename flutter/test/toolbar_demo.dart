import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/shared_state.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/widgets/remote_toolbar.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter_hbb/main.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_session_chips.dart';
import 'package:flutter_hbb/screens/sd_toolbar.dart';
import 'package:flutter_hbb/services/time_left.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

/// flutter run -d windows -t test/toolbar_demo.dart --dart-define=SD_NEW_LOOK=1 : the bar above a remote session and its toolbar over a picture of another
/// computer's screen (the picture is the one of the design).
void main() async {
  isTest = true;
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await initEnv(kAppTypeMain);
  initSharedStates('demo');
  ConnectionTypeState.init('demo');
  final connection = ConnectionTypeState.find('demo');
  connection.setSecure(true);
  connection.setDirect(true);
  connection.setStreamType('Video');
  SdTimeLeft.publish(dailyLimit: 60, minutesLeft: 42);
  final ffi = FFI(null);
  ffi.qualityMonitorModel.data.delay = '14';
  ffi.ffiModel.pi.isSet.value = true;
  final state = ToolbarState();
  Get.put<FFI>(ffi, tag: 'demo');

  final controller = DesktopTabController(tabType: DesktopTabType.remoteScreen);
  final screen = MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: ffi.ffiModel),
      ChangeNotifierProvider.value(value: ffi.imageModel),
      ChangeNotifierProvider.value(value: ffi.cursorModel),
      ChangeNotifierProvider.value(value: ffi.canvasModel),
      ChangeNotifierProvider.value(value: ffi.recordingModel),
    ],
    child: Stack(children: [
      const _Screen(),
      SdSessionChips(id: 'demo', ffi: ffi),
      Overlay(initialEntries: [
        OverlayEntry(
          builder: (context) => RemoteToolbar(
            id: 'demo',
            ffi: ffi,
            state: state,
            onEnterOrLeaveImageSetter: (id, f) {},
            onEnterOrLeaveImageCleaner: (id) {},
            setRemoteState: (f) {},
          ),
        ),
      ]),
    ]),
  );
  controller.add(TabInfo(key: 'MARKETING-DELL', label: 'MARKETING-DELL', closable: true, page: screen));
  controller.add(TabInfo(key: 'RECEPTION-HP', label: 'RECEPTION-HP', closable: true, page: Container()));
  controller.jumpTo(0);

  runApp(GetMaterialApp(
    debugShowCheckedModeBanner: false,
    theme: SdLook.light,
    darkTheme: SdLook.dark,
    themeMode: ThemeMode.light,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: supportedLocales,
    home: Scaffold(
      backgroundColor: const Color(0xFF10141B),
      body: DesktopTab(
        controller: controller,
        afterTabs: const AddButton(),
        pageViewBuilder: (pageView) => pageView,
        labelGetter: (id) => RxString(id),
        tabBuilder: (key, icon, label, conf) => sdRemoteTabContent(tabKey: key, label: label, unread: const SizedBox.shrink(), tooltip: 'Direct and secure connection'),
      ),
    ),
  ));
  final options = getHiddenTitleBarWindowOptions(size: const Size(1280, 760));
  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setSize(const Size(1280, 760));
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
  });
}

class _Screen extends StatelessWidget {
  const _Screen();

  Widget icon(String label) => SizedBox(
        width: 64,
        child: Column(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0x47FFFFFF), borderRadius: BorderRadius.circular(9))),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4)),
        ]),
      );

  Widget win(double l, double t, double w, double h, List<double> bars, Color head) => Positioned(
        left: l,
        top: t,
        width: w,
        height: h,
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 40, spreadRadius: -14, offset: Offset(0, 20))]),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 26, color: head),
            for (final b in bars)
              Container(height: 8, margin: const EdgeInsets.fromLTRB(16, 12, 16, 0), width: (w - 32) * b, decoration: BoxDecoration(color: const Color(0xFFD5DAE3), borderRadius: BorderRadius.circular(4))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1F4E8C), Color(0xFF3F83C6), Color(0xFF8FC1E8)], stops: [0, 0.48, 1])),
      child: Stack(children: [
        Positioned(left: 28, top: 50, child: Column(children: [icon('This PC'), const SizedBox(height: 22), icon('Invoices'), const SizedBox(height: 22), icon('Recycle Bin')])),
        win(150, 80, 560, 340, const [1, 0.7, 0.84, 0.52, 0.76, 0.4], const Color(0xFFE3E7EE)),
        win(520, 190, 520, 300, const [1, 0.64, 0.8, 0.48], const Color(0xFFD9E4F7)),
        Positioned(left: 0, right: 0, bottom: 0, height: 44, child: Container(color: const Color(0xD1121826))),
      ]),
    );
  }
}
