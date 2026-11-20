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
import 'package:flutter_hbb/screens/sd_kit.dart' show SdTextTab;
import 'package:flutter_hbb/screens/sd_peers.dart';
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
    var counter = -1;
    return SizedBox(
      height: 44,
      child: ReorderableListView(
        buildDefaultDragHandles: false,
        onReorder: model.reorder,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        proxyDecorator: (child, i, a) => Material(type: MaterialType.transparency, child: child),
        children: [
          for (final t in tabs)
            ReorderableDragStartListener(
              key: ValueKey(t),
              index: ++counter,
              child: SdTextTab(
                label: short && t < _kShortNames.length ? translate(_kShortNames[t]) : model.tabTooltip(t),
                selected: t == current,
                onTap: isOptionFixed(kOptionPeerTabIndex) ? null : () => sdSelectPeerTab(t),
              ),
            ),
        ],
      ),
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
    return Obx(() => SdPeerStyle(layout: peerCardUiType.value == PeerUiType.grid ? SdPeerLayout.grid : SdPeerLayout.rowsWithMenu, child: keyed));
  }
}
