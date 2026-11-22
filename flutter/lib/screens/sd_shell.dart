import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/widgets/peers_view.dart' show peerSearchText;
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter_hbb/screens/sd_bell.dart';
import 'package:flutter_hbb/screens/sd_dashboard.dart' show SdLaunch;
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_quick.dart';
import 'package:flutter_hbb/screens/sd_signin_modal.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:flutter_hbb/screens/sd_window_menu.dart';
import 'package:flutter_hbb/services/account_summary.dart';
import 'package:flutter_hbb/services/license_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

/// The four pages of the main window.
enum SdPage { dashboard, devices, sessions, settings }

/// Which page of the main window is open. Dashboard, Devices and Sessions are the home tab; Settings is the settings tab, so the page shown in the
/// header also follows whichever tab is selected (other parts of the app open Settings by themselves).
class SdNav {
  SdNav._();

  /// the page of the home tab
  static final home = SdPage.dashboard.obs;

  static SdPage current() {
    try {
      final c = Get.find<DesktopTabController>();
      final tabs = c.state.value.tabs;
      final i = c.state.value.selected;
      if (i >= 0 && i < tabs.length && tabs[i].key == kTabLabelSettingPage) return SdPage.settings;
    } catch (_) {}
    return home.value;
  }

  static void go(SdPage page) {
    if (page == SdPage.settings) {
      DesktopTabPage.onAddSetting();
      return;
    }
    home.value = page;
    try {
      Get.find<DesktopTabController>().jumpToByKey(kTabLabelHomePage);
    } catch (_) {}
  }

  /// The person and the plan open the Account page of the settings (the other settings are one click away from it).
  static void account() {
    if (DesktopSettingPage.tabKeys.contains(SettingsTabKey.account)) {
      DesktopSettingPage.switch2page(SettingsTabKey.account);
    } else {
      go(SdPage.settings);
    }
  }
}

/// The plan as the design's pill words it.
String sdPlanLabel(AccountInfo? info) {
  if (info == null) return 'Free Plan';
  if (info.isFree) return info.expired ? 'Free Plan · expired' : 'Free Plan';
  final shared = info.isShared ? ' · shared' : '';
  switch (info.tier) {
    case 'personal_paid':
      return 'Personal Plan$shared';
    case 'business_payg':
      return 'Pay as you go$shared';
    case 'business_org':
      return 'Business Plan$shared';
    default:
      return '${info.tier.replaceAll('_', ' ')}$shared';
  }
}

const double kSdTitleBarHeight = 40;
const double kSdHeaderHeight = 64;

/// The mark of the header: an "S" in silver blue with a gold dot.
class SdMark extends StatelessWidget {
  const SdMark({super.key, this.size = 34, this.onDark = false});
  final double size;
  final bool onDark;

  /// The real SystemDesk logo (assets/logo_white.svg, one colour), in the ink of the skin or light on a dark ground, in the same square the old mark had.
  @override
  Widget build(BuildContext context) {
    final color = onDark ? const Color(0xFFF4F6FB) : SdSkin.of(context).ink;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: SvgPicture.asset('assets/logo_white.svg', width: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
      ),
    );
  }
}

/// A 12 x 12 line glyph of the window buttons.
class _Glyph extends StatelessWidget {
  const _Glyph(this.body, this.color);
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 12 12" fill="none" stroke="#000" stroke-width="1.3">$body</svg>',
        width: 12,
        height: 12,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}

class SdGlyphs {
  SdGlyphs._();
  static const String minimise = '<path d="M1.5 6h9"/>';
  static const String maximise = '<rect x="1.8" y="1.8" width="8.4" height="8.4" rx="1"/>';
  static const String restore = '<rect x="3.4" y="1.4" width="7.2" height="7.2" rx="1"/><path d="M1.4 3.6v6a1 1 0 0 0 1 1h6"/>';
  static const String close = '<path d="M1.8 1.8l8.4 8.4M10.2 1.8l-8.4 8.4"/>';
}

/// The colour the window buttons below it draw their symbols in, where it is not the usual one (the dark bar of a remote session).
class SdWinInk extends InheritedWidget {
  const SdWinInk({super.key, required this.color, required super.child});
  final Color color;

  static Color? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SdWinInk>()?.color;

  @override
  bool updateShouldNotify(SdWinInk old) => old.color != color;
}

/// `.wc`: a button of the window (minimise, maximise, close): 46 x 40, a soft square under the pointer, the close one turns red.
class SdWinButton extends StatefulWidget {
  const SdWinButton({super.key, this.glyph, this.icon, this.onTap, this.isClose = false, this.tooltip, this.width = 46, this.height = kSdTitleBarHeight});
  final String? glyph;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isClose;
  final String? tooltip;
  final double width, height;

  @override
  State<SdWinButton> createState() => _SdWinButtonState();
}

class _SdWinButtonState extends State<SdWinButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final enabled = widget.onTap != null;
    final red = widget.isClose && _hover;
    final ink = SdWinInk.of(context) ?? t.mut;
    final color = !enabled ? ink.withOpacity(0.5) : (red ? Colors.white : ink);
    Widget w = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: widget.width,
          height: widget.height,
          alignment: Alignment.center,
          color: red ? const Color(0xFFC42B1C) : (_hover && enabled ? (t.dark ? const Color(0x14FFFFFF) : const Color(0x1428241C)) : Colors.transparent),
          child: widget.glyph != null ? _Glyph(widget.glyph!, color) : Icon(widget.icon, size: 14, color: color),
        ),
      ),
    );
    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) w = Tooltip(message: widget.tooltip!, waitDuration: const Duration(seconds: 1), child: w);
    return w;
  }
}

/// `.tb`: what the title bar of the main window shows at the left: the window icon and the name.
class SdTitleBrand extends StatelessWidget {
  const SdTitleBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // the icon of the window: a click on it opens the window menu (the room around it is part of it, so it is easy to hit)
        SdWindowMenuIcon(child: Padding(padding: const EdgeInsets.fromLTRB(8, 10, 2, 10), child: SdIcon(SdIcons.tiles, size: 14, color: t.mut, stroke: 2))),
        const SizedBox(width: 8),
        Text('SystemDesk', style: sdTs(12.5, FontWeight.w400, t.mut)),
      ]),
    );
  }
}

/// The fill and the hairline under the title bar.
class SdTitleBarBox extends StatelessWidget {
  const SdTitleBarBox({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return Container(
      height: kSdTitleBarHeight,
      decoration: BoxDecoration(
        color: t.chrome,
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: child,
    );
  }
}

/// The toolbar under the title bar. On the computers pages: the logo, the one field to connect with, the plan, the bell, the person and the menu (the other pages
/// are in the menu). On the settings page: a way back and the title.
class SdHeaderView extends StatelessWidget {
  const SdHeaderView({
    super.key,
    required this.page,
    required this.onPage,
    required this.plan,
    this.planTip,
    this.onPlan,
    required this.initials,
    this.onAvatar,
    this.bell,
    this.labels = const {SdPage.dashboard: 'Dashboard', SdPage.devices: 'Devices', SdPage.sessions: 'Sessions', SdPage.settings: 'Settings'},
    this.link,
    this.address,
    this.backLabel = 'Back to computers',
    this.backDashboardLabel = 'Back to Dashboard',
  });
  final SdPage page;
  final ValueChanged<SdPage> onPage;
  final String plan;
  final String? planTip;
  final VoidCallback? onPlan;
  final String initials;
  final VoidCallback? onAvatar;

  /// the bell (a button; the header gives it its place)
  final Widget? bell;
  final Map<SdPage, String> labels;

  /// the bell's list opens under bell and avatar: this link marks them
  final LayerLink? link;

  /// the field to connect with ([SdAddressBar]); without it the header shows only the logo
  final Widget? address;
  final String backLabel, backDashboardLabel;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final inSettings = page == SdPage.settings;
    final menu = SdPopoverAnchor(
      targetAnchor: Alignment.bottomRight,
      followerAnchor: Alignment.topRight,
      offset: const Offset(0, 6),
      anchorBuilder: (context, toggle, open) => SdRoundButton(size: 36, tooltip: 'Menu', onTap: toggle, child: SdIcon(SdIcons.list, size: 19, color: t.mut, stroke: 1.9)),
      popupBuilder: (context, close) => SdMenu(width: 220, children: [
        for (final p in SdPage.values)
          SdMenuItem(
            label: labels[p] ?? p.name,
            selected: p == page,
            trailingCheck: p == page,
            onTap: () {
              close();
              onPage(p);
            },
          ),
      ]),
    );
    Widget tools = Row(mainAxisSize: MainAxisSize.min, children: [
      if (bell != null) ...[bell!, const SizedBox(width: 4)],
      SdAvatar(initials: initials, onTap: onAvatar, size: 36),
      const SizedBox(width: 6),
      menu,
    ]);
    if (link != null) tools = CompositedTransformTarget(link: link!, child: tools);
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 980;
      return Container(
        height: kSdHeaderHeight,
        decoration: BoxDecoration(color: t.chrome, border: Border(bottom: BorderSide(color: t.line))),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(children: [
          if (inSettings) ...[
            SdRoundButton(size: 36, tooltip: backLabel, onTap: () => onPage(SdPage.dashboard), child: SdIcon(SdIcons.chevronLeft, size: 20, color: t.mut, stroke: 1.9)),
            const SizedBox(width: 10),
            Text(labels[SdPage.settings] ?? 'Settings', style: sdTs(17, FontWeight.w600, t.ink)),
            const Spacer(),
          ] else ...[
            // Devices and Sessions: one click back to the Dashboard
            if (page != SdPage.dashboard) ...[
              SdRoundButton(size: 36, tooltip: backDashboardLabel, onTap: () => onPage(SdPage.dashboard), child: SdIcon(SdIcons.chevronLeft, size: 20, color: t.mut, stroke: 1.9)),
              const SizedBox(width: 8),
            ],
            const SdMark(size: 30),
            // a narrow window keeps the logo and gives the words' room to the field
            if (c.maxWidth >= 700) ...[
              const SizedBox(width: 10),
              Text('SystemDesk', style: sdTs(16, FontWeight.w600, t.ink, ls: -0.16)),
            ],
            const SizedBox(width: 18),
            if (address != null) Expanded(child: Align(alignment: Alignment.centerLeft, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: address))) else const Spacer(),
          ],
          if (wide) ...[
            const SizedBox(width: 16),
            Tooltip(message: planTip ?? plan, waitDuration: const Duration(milliseconds: 700), child: SdGoldPill(label: plan, onTap: onPlan)),
          ],
          const SizedBox(width: 10),
          tools,
        ]),
      );
    });
  }
}

/// The header of the real window: reads the page, the plan and the person from the app.
class SdHeader extends StatefulWidget {
  const SdHeader({super.key});

  @override
  State<SdHeader> createState() => _SdHeaderState();
}

class _SdHeaderState extends State<SdHeader> {
  final _link = LayerLink();
  // the field to connect with; other parts of the app (links, "connect to the last computer") look for this controller
  final _id = IDTextEditingController();

  @override
  void initState() {
    super.initState();
    Get.put<IDTextEditingController>(_id);
  }

  @override
  void dispose() {
    if (Get.isRegistered<IDTextEditingController>() && identical(Get.find<IDTextEditingController>(), _id)) {
      Get.delete<IDTextEditingController>();
    }
    _id.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // the tab controller is read here so the header follows the selected tab
      try {
        Get.find<DesktopTabController>().state.value;
      } catch (_) {}
      final info = AccountSummary.instance.info.value;
      final signedIn = LicenseService.instance.isLoggedInRx.value;
      return SdHeaderView(
        page: _page(),
        onPage: SdNav.go,
        backLabel: translate('Back to computers'),
        backDashboardLabel: translate('Back to Dashboard'),
        address: SdAddressBar(
          controller: _id,
          onChanged: (v) => peerSearchText.value = v,
          onSubmit: () => sdQuickLaunch(context, _id, SdLaunch.remote),
          onLaunch: (how) => sdQuickLaunch(context, _id, how),
          tr: translate,
        ),
        plan: sdPlanLabel(info),
        planTip: planTitle(info),
        onPlan: SdNav.account,
        initials: signedIn && info != null ? info.initials : '',
        onAvatar: signedIn ? SdNav.account : showSdSignIn,
        link: _link,
        labels: {
          SdPage.dashboard: translate('Dashboard'),
          SdPage.devices: translate('Devices'),
          SdPage.sessions: translate('Sessions'),
          SdPage.settings: translate('Settings'),
        },
        bell: SdBell(
          link: _link,
          text: SdBellText(
            title: translate('Notifications'),
            clear: translate('Clear all'),
            empty: translate('You are all caught up'),
            emptyHint: translate('Announcements from SystemDesk appear here.'),
          ),
        ),
      );
    });
  }

  SdPage _page() => SdNav.current();
}
