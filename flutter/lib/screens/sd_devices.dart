import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/widgets/peer_card.dart' show PeerUiType, peerCardUiType;
import 'package:flutter_hbb/common/widgets/peers_view.dart' show peerSearchText;
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_peer_pages.dart';
import 'package:flutter_hbb/screens/sd_peer_tools.dart';
import 'package:flutter_hbb/screens/sd_peers.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// The Devices page of the design: the title and the count, the five lists as tabs, a search, the online filter, the view switch, and the computers as
/// cards or as a list. It only draws; [SdDevices] gives it the real lists.
class SdDevicesView extends StatelessWidget {
  const SdDevicesView({
    super.key,
    required this.summary,
    required this.tabs,
    required this.query,
    this.onQuery,
    required this.filter,
    required this.onFilter,
    required this.grid,
    required this.onGrid,
    this.pictures = false,
    this.onPictures,
    this.onAdd,
    this.tools,
    required this.body,
    this.tr = _same,
  });
  final String summary;
  final Widget tabs, body;

  /// the other options of the lists (sort, refresh, select several, which tabs)
  final Widget? tools;
  final TextEditingController query;
  final ValueChanged<String>? onQuery;
  final String filter;
  final ValueChanged<String> onFilter;
  final bool grid;
  final ValueChanged<bool> onGrid;

  /// the third view, the pictures (offered when [onPictures] is given): the cards show the last screen seen of each computer
  final bool pictures;
  final VoidCallback? onPictures;
  final VoidCallback? onAdd;
  final String Function(String) tr;

  static String _same(String s) => s;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final search = SdInset(
      width: 260,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        SdIcon(SdIcons.search, size: 18, color: t.ink, stroke: 2),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: query,
            onChanged: onQuery,
            style: sdTs(15, FontWeight.w400, t.ink, lh: 1.3),
            cursorColor: t.goldRing,
            decoration: InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: tr('Search name or ID'),
              hintStyle: sdTs(15, FontWeight.w400, t.mut, lh: 1.3),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ]),
    );
    final filterSeg = SdSeg<String>(items: [('all', tr('All')), ('online', tr('Online')), ('offline', tr('Offline'))], value: filter, onChanged: onFilter);
    final Widget viewSeg = onPictures == null
        ? SdSeg<bool>(items: [(true, SdIcons.grid), (false, SdIcons.list)], value: grid, onChanged: onGrid, itemPadding: 14, icons: true)
        : SdSeg<int>(
            key: const ValueKey('sd-view-seg'),
            items: [(0, SdIcons.grid), (1, SdIcons.image), (2, SdIcons.list)],
            value: pictures ? 1 : (grid ? 0 : 2),
            onChanged: (v) => v == 1 ? onPictures!() : onGrid(v == 0),
            itemPadding: 14,
            icons: true,
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Computers'), style: sdTs(26, FontWeight.w500, t.ink, ls: -0.26)),
              Text(summary, style: sdTs(14, FontWeight.w400, t.mut)),
            ]),
          ),
          SdButton(kind: SdBtnKind.gold, icon: SdIcons.plus, label: tr('Add computer'), onTap: onAdd),
        ]),
        const SizedBox(height: 20),
        DecoratedBox(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
          child: SizedBox(width: double.infinity, child: Row(children: [Expanded(child: tabs), if (tools != null) tools!])),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 760) {
            return Row(children: [search, const Spacer(), filterSeg, const SizedBox(width: 14), viewSeg]);
          }
          return Wrap(spacing: 14, runSpacing: 14, crossAxisAlignment: WrapCrossAlignment.center, children: [search, filterSeg, viewSeg]);
        }),
        const SizedBox(height: 20),
        body,
      ]),
    );
  }
}

/// The Devices page of the window, on the real lists.
class SdDevices extends StatefulWidget {
  const SdDevices({super.key});

  @override
  State<SdDevices> createState() => _SdDevicesState();
}

class _SdDevicesState extends State<SdDevices> {
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.text = peerSearchText.value;
    sdPeerFilter.value = 'all';
    sdLoadPeerOptions();
  }

  @override
  void dispose() {
    peerSearchText.value = '';
    sdPeerFilter.value = 'all';
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PeerTabModel>(builder: (context, model, _) => Obx(() {
      final peers = model.currentTabCachedPeers;
      final online = peers.where((p) => p.online).length;
      return SdDevicesView(
        summary: '${peers.length} ${translate('computers')} · $online ${translate('online')}',
        tabs: const SdPeerTabs(short: false),
        query: _query,
        onQuery: (v) => peerSearchText.value = v,
        filter: sdPeerFilter.value,
        onFilter: (f) => sdPeerFilter.value = f,
        grid: peerCardUiType.value == PeerUiType.grid,
        onGrid: (g) async {
          if (isOptionFixed(kOptionPeerCardUiType)) return;
          final v = g ? PeerUiType.grid : PeerUiType.list;
          peerCardUiType.value = v;
          await bind.setLocalFlutterOption(k: kOptionPeerCardUiType, v: v.index.toString());
        },
        pictures: peerCardUiType.value == PeerUiType.tile,
        onPictures: () async {
          if (isOptionFixed(kOptionPeerCardUiType)) return;
          peerCardUiType.value = PeerUiType.tile;
          await bind.setLocalFlutterOption(k: kOptionPeerCardUiType, v: PeerUiType.tile.index.toString());
        },
        onAdd: () => showSdAddComputer(context),
        tools: const SdPeerTools(showView: false),
        body: const SdPeerBody(),
        tr: translate,
      );
    }));
  }
}

/// "Add computer": the ID (and a name) of a computer goes into the address book.
void showSdAddComputer(BuildContext context) {
  if (gFFI.abModel.isCurrentAbFull(true)) return;
  final idController = IDTextEditingController(text: '');
  final aliasController = TextEditingController(text: '');
  String? error;
  gFFI.dialogManager.show((setState, close, ctx) {
    submit() async {
      final id = idController.id;
      if (id.isEmpty) return;
      if (gFFI.abModel.idContainByCurrent(id)) {
        setState(() => error = translate('ID already exists'));
        return;
      }
      final err = await gFFI.abModel.addIdToCurrent(id, aliasController.text.trim(), '', <dynamic>[].obs, '');
      if (err != null) {
        setState(() => error = err);
        return;
      }
      close();
    }

    return CustomAlertDialog(
      title: Text(translate('Add ID')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: idController, autofocus: true, inputFormatters: [IDTextInputFormatter()], decoration: InputDecoration(labelText: translate('ID'), errorText: error)),
        const SizedBox(height: 12),
        TextField(controller: aliasController, decoration: InputDecoration(labelText: translate('Alias'))),
      ]),
      actions: [dialogButton('Cancel', onPressed: close, isOutline: true), dialogButton('OK', onPressed: submit)],
      onSubmit: submit,
      onCancel: close,
    );
  });
}
