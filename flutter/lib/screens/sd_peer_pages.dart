import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/address_book.dart';
import 'package:flutter_hbb/common/widgets/my_group.dart';
import 'package:flutter_hbb/common/widgets/peer_card.dart' show PeerUiType, peerCardUiType;
import 'package:flutter_hbb/common/widgets/peers_view.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/ab_model.dart' show ForcePullAb;
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart' show SdMenu, SdMenuItem, SdPopoverAnchor, SdTextTab;
import 'package:flutter_hbb/screens/sd_peers.dart';
import 'package:flutter_hbb/screens/sd_tone.dart' show sdTs;
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// The five lists of computers (recent, favorites, discovered, address book, accessible) as the design's tabs and body, on the app's own models.
const _kShortNames = ['Recent', 'Favorites', 'Discovered', 'Address book', 'Accessible'];

EdgeInsets? _menuPadding() => (isDesktop || isWebDesktop) ? kDesktopMenuPadding : null;

/// The view of one list. The address book and the group are loaded when their tab opens.
Widget _viewOf(int tab) {
  switch (tab) {
    case 1:
      return FavoritePeersView(menuPadding: _menuPadding());
    case 2:
      return DiscoveredPeersView(menuPadding: _menuPadding());
    case 3:
      return AddressBook(menuPadding: _menuPadding());
    case 4:
      return MyGroup(menuPadding: _menuPadding());
    default:
      return RecentPeersView(menuPadding: _menuPadding());
  }
}

/// Opens a list: the same thing the old tabs did.
Future<void> sdSelectPeerTab(int tab) async {
  final model = gFFI.peerTabModel;
  if (tab != model.currentTab) model.setCurrentTabCachedPeers([]);
  model.setCurrentTab(tab);
  if (tab == PeerTabIndex.ab.index) {
    gFFI.abModel.pullAb(force: null, quiet: false);
  } else if (tab == PeerTabIndex.group.index) {
    gFFI.groupModel.pull(force: false);
  }
  await bind.setLocalFlutterOption(k: kOptionPeerTabIndex, v: tab.toString());
}

/// Reads the saved "Change view" and tag panel options (the old tab page did it when it was built).
void sdLoadPeerOptions() {
  final uiType = bind.getLocalFlutterOption(k: kOptionPeerCardUiType);
  final n = int.tryParse(uiType);
  if (n != null) peerCardUiType.value = n == 0 ? PeerUiType.grid : (n == 1 ? PeerUiType.tile : PeerUiType.list);
  hideAbTagsPanel.value = bind.mainGetLocalOption(key: kOptionHideAbTagsPanel) == 'Y';
}

/// The refresh button of the address book and of the group: loads that list again from the server.
void sdReloadPeerTab(int tab) {
  if (tab == PeerTabIndex.ab.index) {
    gFFI.abModel.pullAb(force: ForcePullAb.listAndCurrent, quiet: false);
  } else if (tab == PeerTabIndex.group.index) {
    gFFI.groupModel.pull(force: true);
  }
}

/// Plain text tabs with a line under the open one (the tabs of the lists; the same list of tabs as the old bar, which can be dragged into another order).
class SdPeerTabs extends StatelessWidget {
  const SdPeerTabs({super.key, this.short = true});
  final bool short;

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<PeerTabModel>(context);
    final tabs = model.visibleEnabledOrderedIndexs;
    if (tabs.isEmpty) return const SizedBox(height: 44);
    final current = tabs.contains(model.currentTab) ? model.currentTab : tabs.first;
    return SdTabStrip(
      tabs: [for (final t in tabs) (t, short && t < _kShortNames.length ? translate(_kShortNames[t]) : model.tabTooltip(t))],
      current: current,
      onSelect: isOptionFixed(kOptionPeerTabIndex) ? null : sdSelectPeerTab,
      onReorder: model.reorder,
      more: translate('More'),
    );
  }
}

/// The tabs of the lists. All of them when they fit the width they are given; in a narrower window the ones that fit (the open one always among them) and a
/// "More" tab with the others in a menu, so nothing is cut off and nothing needs a scroll bar. Only the full row can be dragged into another order.
class SdTabStrip extends StatelessWidget {
  const SdTabStrip({super.key, required this.tabs, required this.current, this.onSelect, this.onReorder, this.more = 'More'});

  /// (what the list is called in the model, its words)
  final List<(int, String)> tabs;
  final int current;
  final Future<void> Function(int)? onSelect;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final String more;

  static double _width(String s, FontWeight w) {
    final p = TextPainter(text: TextSpan(text: s, style: sdTs(14.5, w, const Color(0xFF000000))), textDirection: TextDirection.ltr, maxLines: 1)..layout();
    return p.width + 28;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: LayoutBuilder(builder: (context, c) {
        final widths = [for (final t in tabs) _width(t.$2, FontWeight.w600) + 2];
        final total = widths.fold<double>(0, (a, b) => a + b);
        if (total <= c.maxWidth || !c.maxWidth.isFinite) {
          var counter = -1;
          return ReorderableListView(
            buildDefaultDragHandles: false,
            onReorder: onReorder ?? (a, b) {},
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            proxyDecorator: (child, i, a) => Material(type: MaterialType.transparency, child: child),
            children: [
              for (final t in tabs)
                ReorderableDragStartListener(
                  key: ValueKey(t.$1),
                  index: ++counter,
                  child: SdTextTab(label: t.$2, selected: t.$1 == current, onTap: onSelect == null ? null : () => onSelect!(t.$1)),
                ),
            ],
          );
        }
        // the ones that fit, in order; the open one stays in view even when it is far down the list
        final moreWidth = _width(more, FontWeight.w400) + 19;
        final shown = <int>[];
        var used = moreWidth;
        for (var i = 0; i < tabs.length; i++) {
          if (used + widths[i] > c.maxWidth) break;
          shown.add(i);
          used += widths[i];
        }
        final open = tabs.indexWhere((t) => t.$1 == current);
        if (open >= 0 && !shown.contains(open)) {
          while (shown.isNotEmpty && used + widths[open] > c.maxWidth) {
            used -= widths[shown.removeLast()];
          }
          shown.add(open);
        }
        final hidden = [for (var i = 0; i < tabs.length; i++) if (!shown.contains(i)) i];
        return Row(children: [
          for (final i in shown) SdTextTab(label: tabs[i].$2, selected: tabs[i].$1 == current, onTap: onSelect == null ? null : () => onSelect!(tabs[i].$1)),
          if (hidden.isNotEmpty)
            SdPopoverAnchor(
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 4),
              anchorBuilder: (context, toggle, isOpen) => SdTextTab(label: more, selected: false, onTap: toggle, trailingIcon: SdIcons.chevronDown),
              popupBuilder: (context, close) => SdMenu(width: 220, children: [
                for (final i in hidden)
                  SdMenuItem(
                    label: tabs[i].$2,
                    onTap: () {
                      close();
                      onSelect?.call(tabs[i].$1);
                    },
                  ),
              ]),
            ),
        ]);
      }),
    );
  }
}

/// The list that is open, laid out as [layout]; without one it follows the "Change view" option (cards or list).
class SdPeerBody extends StatelessWidget {
  const SdPeerBody({super.key, this.layout});
  final SdPeerLayout? layout;

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<PeerTabModel>(context);
    final tabs = model.visibleEnabledOrderedIndexs;
    if (tabs.isEmpty) return const SizedBox.shrink();
    final current = tabs.contains(model.currentTab) ? model.currentTab : tabs.first;
    Widget view = _viewOf(current);
    // the address book and the group lay themselves out in the height they are given (tag panel and list side by side)
    if (current >= PeerTabIndex.ab.index) view = SizedBox(height: 560, child: view);
    final keyed = KeyedSubtree(key: ValueKey('sd-peers-$current'), child: view);
    if (layout != null) return SdPeerStyle(layout: layout!, child: keyed);
    // the three views of Devices: cards (grid), pictures (tile) and the list
    return Obx(() => SdPeerStyle(
        layout: peerCardUiType.value == PeerUiType.grid
            ? SdPeerLayout.grid
            : (peerCardUiType.value == PeerUiType.tile ? SdPeerLayout.pictures : SdPeerLayout.rowsWithMenu),
        child: keyed));
  }
}
