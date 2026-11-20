import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/address_book.dart' show hideAbTagsPanel;
import 'package:flutter_hbb/common/widgets/dialog.dart';
import 'package:flutter_hbb/common/widgets/peer_card.dart' show PeerUiType, peerCardUiType;
import 'package:flutter_hbb/common/widgets/peer_tab_page.dart' show RefreshWidget;
import 'package:flutter_hbb/common/widgets/peers_view.dart' show PeerSortType, peerSort;
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_peer_pages.dart' show sdReloadPeerTab;
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// The options of the lists of computers that the old tab bar had at its right, as flat icon buttons: refresh (address book, group), select several, show or
/// hide the tag panel (address book), sort, cards or list, and which tabs to show. While several are selected the bar becomes the bar of that selection.
class SdPeerTools extends StatelessWidget {
  const SdPeerTools({super.key, this.showView = true});

  /// false where the page has its own switch between cards and list (Devices)
  final bool showView;

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<PeerTabModel>(context);
    if (model.multiSelectionMode) return SdSelectionBar(model: model);
    final t = SdSkin.of(context);
    final tab = model.currentTab;
    return Obx(() {
      // read here so that the buttons follow them
      final view = peerCardUiType.value;
      final tagsHidden = hideAbTagsPanel.value;
      final sort = peerSort.value;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        if (tab == PeerTabIndex.ab.index) _Refresh(loading: gFFI.abModel.currentAbLoading, tab: tab),
        if (tab == PeerTabIndex.group.index) _Refresh(loading: gFFI.groupModel.groupLoading, tab: tab),
        if (model.currentTabCachedPeers.isNotEmpty)
          SdToolButton(icon: SdIcons.squareCheck, tooltip: translate('Select'), onTap: () => model.setMultiSelectionMode(true)),
        if (tab == PeerTabIndex.ab.index)
          SdToolButton(
            icon: SdIcons.tag,
            tooltip: translate('Toggle Tags'),
            active: !tagsHidden,
            onTap: () async {
              await bind.mainSetLocalOption(key: kOptionHideAbTagsPanel, value: hideAbTagsPanel.value ? defaultOptionNo : 'Y');
              hideAbTagsPanel.value = !hideAbTagsPanel.value;
            },
          ),
        if (tab != PeerTabIndex.recent.index) _SortMenu(current: sort),
        if (showView) ...[
          const SizedBox(width: 4),
          _ViewSwitch(cards: view == PeerUiType.grid, t: t),
        ],
        _TabsMenu(model: model),
      ]);
    });
  }
}

class _Refresh extends StatelessWidget {
  const _Refresh({required this.loading, required this.tab});
  final RxBool loading;
  final int tab;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return Tooltip(
      message: translate('Refresh'),
      child: RefreshWidget(
        onPressed: () => sdReloadPeerTab(tab),
        spinning: loading,
        child: SizedBox(width: 24, height: 24, child: Center(child: SdIcon(SdIcons.refresh, size: 18, color: t.mut, stroke: 1.9))),
      ),
    );
  }
}

/// Cards or list, kept in the same option the old "Change view" menu kept. (The old "small tiles" view is shown as the list.)
class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.cards, required this.t});
  final bool cards;
  final SdSkin t;

  Future<void> _set(PeerUiType v) async {
    if (isOptionFixed(kOptionPeerCardUiType)) return;
    peerCardUiType.value = v;
    await bind.setLocalFlutterOption(k: kOptionPeerCardUiType, v: v.index.toString());
  }

  @override
  Widget build(BuildContext context) {
    return SdBox(
      radius: 9,
      color: t.chip,
      padding: const EdgeInsets.all(2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SdToolButton(icon: SdIcons.grid, tooltip: translate('Big tiles'), active: cards, onTap: () => _set(PeerUiType.grid)),
        SdToolButton(icon: SdIcons.list, tooltip: translate('List'), active: !cards, onTap: () => _set(PeerUiType.list)),
      ]),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.current});
  final String current;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return SdPopoverAnchor(
      targetAnchor: Alignment.bottomRight,
      followerAnchor: Alignment.topRight,
      offset: const Offset(0, 6),
      anchorBuilder: (context, toggle, open) => SdToolButton(icon: SdIcons.sort, tooltip: translate('Sort by'), active: open, onTap: toggle),
      popupBuilder: (context, close) => SdMenu(width: 210, children: [
        Padding(padding: const EdgeInsets.fromLTRB(10, 6, 10, 4), child: Text(translate('Sort by'), style: sdTs(12.5, FontWeight.w500, t.mut))),
        for (final e in PeerSortType.values)
          SdMenuItem(
            label: translate(e),
            selected: e == current,
            trailingCheck: e == current,
            onTap: () async {
              close();
              peerSort.value = e;
              await bind.setLocalFlutterOption(k: kOptionPeerSorting, v: e);
            },
          ),
      ]),
    );
  }
}

/// Which of the lists are shown as tabs (what the right click on the old tab bar offered).
class _TabsMenu extends StatelessWidget {
  const _TabsMenu({required this.model});
  final PeerTabModel model;

  @override
  Widget build(BuildContext context) {
    final fixed = isOptionFixed(kOptionPeerTabVisible);
    final t = SdSkin.of(context);
    return SdPopoverAnchor(
      targetAnchor: Alignment.bottomRight,
      followerAnchor: Alignment.topRight,
      offset: const Offset(0, 6),
      anchorBuilder: (context, toggle, open) => SdToolButton(icon: SdIcons.sliders, tooltip: translate('Tabs'), active: open, onTap: toggle),
      popupBuilder: (context, close) => AnimatedBuilder(
        animation: model,
        builder: (context, _) => SdMenu(width: 230, children: [
          Padding(padding: const EdgeInsets.fromLTRB(10, 6, 10, 4), child: Text(translate('Tabs'), style: sdTs(12.5, FontWeight.w500, t.mut))),
          for (final i in model.orders)
            if (i >= 0 && i < PeerTabModel.maxTabCount && model.isEnabled[i])
              SdMenuItem(
                label: model.tabTooltip(i),
                selected: model.isVisibleEnabled[i],
                trailingCheck: model.isVisibleEnabled[i],
                onTap: fixed ? null : () => model.setTabVisible(i, !model.isVisibleEnabled[i]),
              ),
        ]),
      ),
    );
  }
}

/// The bar of a selection of several computers: delete, add to favorites, add to the address book, edit tags, how many are selected, select all, close. The
/// same actions as the old bar.
class SdSelectionBar extends StatelessWidget {
  const SdSelectionBar({super.key, required this.model});
  final PeerTabModel model;

  Future<void> _delete() async {
    final peers = model.selectedPeers;
    switch (model.currentTab) {
      case 0:
        for (var p in peers) {
          await bind.mainRemovePeer(id: p.id);
        }
        bind.mainLoadRecentPeers();
        break;
      case 1:
        final favs = (await bind.mainGetFav()).toList();
        for (final p in peers) {
          favs.remove(p.id);
        }
        await bind.mainStoreFav(favs: favs);
        bind.mainLoadFavPeers();
        break;
      case 2:
        for (var p in peers) {
          await bind.mainRemoveDiscovered(id: p.id);
        }
        bind.mainLoadLanPeers();
        break;
      case 3:
        await gFFI.abModel.deletePeers(peers.map((p) => p.id).toList());
        break;
      default:
        break;
    }
    gFFI.peerTabModel.setMultiSelectionMode(false);
    if (model.currentTab != 3) showToast(translate('Successful'));
  }

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final tab = model.currentTab;
    final some = model.selectedPeers.isNotEmpty;
    final addressbooks = gFFI.abModel.addressBooksCanWrite();
    if (tab == PeerTabIndex.ab.index) addressbooks.remove(gFFI.abModel.currentName.value);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (some && tab != PeerTabIndex.group.index)
        SdToolButton(icon: SdIcons.trash, tooltip: translate('Delete'), color: t.bad, onTap: () => deleteConfirmDialog(_delete, translate('Delete'))),
      if (some && tab == PeerTabIndex.recent.index)
        SdToolButton(
          icon: SdIcons.star,
          tooltip: translate('Add to Favorites'),
          onTap: () async {
            final favs = (await bind.mainGetFav()).toList();
            for (var p in model.selectedPeers) {
              if (!favs.contains(p.id)) favs.add(p.id);
            }
            await bind.mainStoreFav(favs: favs);
            model.setMultiSelectionMode(false);
            showToast(translate('Successful'));
          },
        ),
      if (some && gFFI.userModel.isLogin && addressbooks.isNotEmpty)
        SdToolButton(
          icon: SdIcons.folder,
          tooltip: translate('Add to address book'),
          onTap: () {
            final peers = model.selectedPeers.map((e) => Peer.copy(e)).toList();
            addPeersToAbDialog(peers);
            model.setMultiSelectionMode(false);
          },
        ),
      if (some && gFFI.userModel.isLogin && tab == PeerTabIndex.ab.index && gFFI.abModel.currentAbTags.isNotEmpty)
        SdToolButton(
          icon: SdIcons.tag,
          tooltip: translate('Edit Tag'),
          onTap: () {
            editAbTagDialog(List.empty(), (selectedTags) async {
              await gFFI.abModel.changeTagForPeers(model.selectedPeers.map((p) => p.id).toList(), selectedTags);
              model.setMultiSelectionMode(false);
              showToast(translate('Successful'));
            });
          },
        ),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${model.selectedPeers.length} ${translate('Selected')}', style: sdTs(13.5, FontWeight.w500, t.ink))),
      if (model.selectedPeers.length < model.currentTabCachedPeers.length)
        SdToolButton(icon: SdIcons.checkCircle, tooltip: translate('Select All'), onTap: model.selectAll),
      SdToolButton(icon: SdIcons.close, tooltip: translate('Close'), onTap: () => model.setMultiSelectionMode(false)),
    ]);
  }
}
