import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_modal.dart';
import 'package:flutter_hbb/screens/sd_signin_modal.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';

/// "System information" of the computer being controlled. The computer sends it with its peer info (`sd_sysinfo`), unless its owner switched
/// that off in Settings > Security > Permissions.
const String kPlatformAdditionsSdSysinfo = 'sd_sysinfo';

const _labels = <(String, String)>[
  ('hostname', 'Computer name'),
  ('username', 'Signed-in user'),
  ('os', 'System'),
  ('arch', 'Architecture'),
  ('cpu', 'Processor'),
  ('memory', 'Memory'),
  ('memory_free', 'Free memory'),
  ('app_version', 'SystemDesk version'),
];

/// The rows to show, in a fixed order; what the computer did not send is left out.
List<(String, String)> sdSystemInfoRows(Object? info) {
  if (info is! Map) return const [];
  return [
    for (final l in _labels)
      if ('${info[l.$1] ?? ''}'.trim().isNotEmpty) (l.$2, '${info[l.$1]}'.trim()),
  ];
}

class SdSystemInfoView extends StatelessWidget {
  const SdSystemInfoView({super.key, required this.rows, required this.onClose});
  final List<(String, String)> rows;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          SdMarkTile(child: SdIcon(SdIcons.monitor, size: 26, color: const Color(0xFFF3E2B8), stroke: 1.9)),
          const SizedBox(width: 14),
          Expanded(child: Text('System information', style: sdTs(21, FontWeight.w600, t.ink, ls: -0.21))),
        ]),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          Text('This computer did not send its system information.', style: sdTs(14.5, FontWeight.w400, t.mut))
        else
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 150, child: Text(r.$1, style: sdTs(14, FontWeight.w400, t.mut))),
                Expanded(child: SelectableText(r.$2, style: sdTs(14.5, FontWeight.w500, t.ink))),
              ]),
            ),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [SdButton(label: 'Close', kind: SdBtnKind.gold, onTap: onClose)]),
      ],
    );
  }
}

void sdShowSystemInfo(OverlayDialogManager dialogManager, Object? info) {
  dialogManager.show((setState, close, context) {
    return SdModal(
      maxWidth: 520,
      onCancel: close,
      content: SdSystemInfoView(rows: sdSystemInfoRows(info), onClose: close),
    );
  }, tag: 'sd-system-info');
}
