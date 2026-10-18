import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/services/license_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// The dialog a connection window shows when a plan limit refuses or ends a session: what happened in plain words, the plan's
/// own numbers (the limit that was reached is marked), and, when there is a bigger plan, an Upgrade button (primary) in front of an
/// outlined OK. Both buttons close the connection window, like the generic error box does.
void showLimitDialog(OverlayDialogManager dialogManager, LimitNotice notice) {
  dialogManager.dismissAll();
  void finish() {
    dialogManager.dismissAll();
    if (desktopType != DesktopType.portForward) closeConnection();
  }

  dialogManager.show(
    (setState, close, context) => CustomAlertDialog(
      title: null,
      content: LimitDialogBody(notice: notice),
      actions: limitDialogActions(
        notice,
        onUpgrade: () {
          final url = notice.upgradeUrl;
          if (url != null && url.startsWith('http')) launchUrl(Uri.parse(url));
          finish();
        },
        onOk: finish,
      ),
      onSubmit: finish,
      onCancel: finish,
    ),
    tag: 'sd-limit-${notice.kind}',
  );
}

const _amber = Color(0xFFF59E0B);
const _onAmber = Color(0xFF241700);

/// [Upgrade to ...] (primary, only when there is something to upgrade to) in front of [OK] (outlined, transparent).
List<Widget> limitDialogActions(LimitNotice notice,
    {required VoidCallback onUpgrade, required VoidCallback onOk}) {
  return [
    if (notice.upgradeLabel != null)
      ElevatedButton(
        onPressed: onUpgrade,
        style: ElevatedButton.styleFrom(
          backgroundColor: _amber,
          foregroundColor: _onAmber,
          elevation: 0,
        ),
        child: Text(notice.upgradeLabel!,
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    Builder(builder: (context) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      return OutlinedButton(
        onPressed: onOk,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: dark ? const Color(0xFFECEAE4) : const Color(0xFF1A1712),
          side: BorderSide(
              color: dark ? const Color(0xFF4A4D57) : const Color(0xFFD9D3C4)),
        ),
        child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
      );
    }),
  ];
}

class LimitDialogBody extends StatelessWidget {
  const LimitDialogBody({Key? key, required this.notice}) : super(key: key);
  final LimitNotice notice;

  IconData get _icon {
    switch (notice.kind) {
      case 'concurrent':
        return Icons.devices_other_rounded;
      case 'daily':
        return Icons.event_busy_rounded;
      default:
        return Icons.timer_off_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = ThemeData.estimateBrightnessForColor(
            Theme.of(context).dialogBackgroundColor) ==
        Brightness.dark;
    final ink = dark ? const Color(0xFFECEAE4) : const Color(0xFF1A1712);
    final muted = dark ? const Color(0xFFB4B7C0) : const Color(0xFF5E584B);
    final card = dark ? const Color(0xFF282A32) : const Color(0xFFF7F4ED);
    final line = dark ? const Color(0xFF30323A) : const Color(0xFFECE7DB);
    final hit = dark ? const Color(0xFFF0C26B) : const Color(0xFF8A5A00);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _amber.withOpacity(dark ? 0.2 : 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_icon, size: 22, color: hit),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(notice.title,
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: ink,
                              height: 1.25)),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(notice.message,
                        style:
                            TextStyle(fontSize: 14, color: muted, height: 1.45)),
                  ],
                ),
              ),
            ],
          ),
          if (notice.rows.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              key: const ValueKey('sd-limit-plan'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: line),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < notice.rows.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        border: i == 0
                            ? null
                            : Border(top: BorderSide(color: line)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(notice.rows[i].label,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: notice.rows[i].hit ? hit : muted,
                                    fontWeight: notice.rows[i].hit
                                        ? FontWeight.w700
                                        : FontWeight.w500)),
                          ),
                          if (notice.rows[i].hit)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _amber.withOpacity(dark ? 0.22 : 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('limit reached',
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: hit)),
                            ),
                          Text(notice.rows[i].value,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: notice.rows[i].hit ? hit : ink)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
