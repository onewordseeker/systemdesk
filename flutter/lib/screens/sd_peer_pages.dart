import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/address_book.dart';
import 'package:flutter_hbb/common/widgets/my_group.dart';
import 'package:flutter_hbb/common/widgets/peers_view.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_peers.dart';
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

/// `.seg` of the lists. [short] uses the short names of the dashboard.
class SdPeerTabs extends StatelessWidget {
  const SdPeerTabs({super.key, this.short = true});
  final bool short;

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<PeerTabModel>(context);
    final tabs = model.visibleEnabledOrderedIndexs;
    if (tabs.isEmpty) return const SizedBox.shrink();
    final current = tabs.contains(model.currentTab) ? model.currentTab : tabs.first;
    return SdSeg<int>(
      items: [for (final t in tabs) (t, short && t < _kShortNames.length ? translate(_kShortNames[t]) : model.tabTooltip(t))],
      value: current,
      onChanged: (t) {
        if (!isOptionFixed(kOptionPeerTabIndex)) sdSelectPeerTab(t);
      },
    );
  }
}

/// The list that is open, laid out as [layout].
class SdPeerBody extends StatelessWidget {
  const SdPeerBody({super.key, required this.layout});
  final SdPeerLayout layout;

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<PeerTabModel>(context);
    final tabs = model.visibleEnabledOrderedIndexs;
    if (tabs.isEmpty) return const SizedBox.shrink();
    final current = tabs.contains(model.currentTab) ? model.currentTab : tabs.first;
    Widget view = _viewOf(current);
    // the address book and the group lay themselves out in the height they are given (tag panel and list side by side)
    if (current >= PeerTabIndex.ab.index) view = SizedBox(height: 560, child: view);
    return SdPeerStyle(layout: layout, child: KeyedSubtree(key: ValueKey('sd-peers-$current'), child: view));
  }
}
