import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/screens/sd_palette.dart';
import 'package:flutter_hbb/services/app_notices.dart';

/// A message an administrator sent from the console (maintenance, news, a warning). Shown once per message, over whatever the app is
/// showing; it paints its own surface and text colours from SdPalette, so it is readable in any theme.
/// Completes when the person closes it (or something else dismisses the dialogs).
Future<void> showAppMessage(AppMessage message) {
  return gFFI.dialogManager.show<void>(
    (setState, close, context) {
      final p = SdPalette.of(context);
      return CustomAlertDialog(
        title: null,
        backgroundColor: p.fill,
        shape: p.shape,
        content: AppMessageBody(message: message),
        actions: [
          Builder(builder: (context) {
            final p = SdPalette.of(context);
            return ElevatedButton(
              onPressed: () => close(),
              style: ElevatedButton.styleFrom(
                backgroundColor: SdPalette.amber,
                foregroundColor: p.onAmber,
                elevation: 0,
              ),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
            );
          }),
        ],
        onSubmit: () => close(),
        onCancel: () => close(),
      );
    },
    tag: 'sd-message-${message.id}',
    forceGlobal: true,
  );
}

/// The colour and icon of a message's style.
({Color color, IconData icon}) messageStyle(String severity, bool dark) {
  switch (severity) {
    case 'success':
      return (color: dark ? const Color(0xFF6EE0A8) : const Color(0xFF17794D), icon: Icons.check_circle_outline_rounded);
    case 'warning':
      return (color: dark ? const Color(0xFFF0C26B) : const Color(0xFF8A5A00), icon: Icons.warning_amber_rounded);
    case 'critical':
      return (color: dark ? const Color(0xFFFF8A82) : const Color(0xFFA5322D), icon: Icons.error_outline_rounded);
    default:
      return (color: dark ? const Color(0xFF7CC4F0) : const Color(0xFF1B5E86), icon: Icons.info_outline_rounded);
  }
}

class AppMessageBody extends StatelessWidget {
  const AppMessageBody({Key? key, required this.message}) : super(key: key);
  final AppMessage message;

  @override
  Widget build(BuildContext context) {
    final p = SdPalette.of(context);
    final style = messageStyle(message.severity, p.dark);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: style.color.withOpacity(p.dark ? 0.2 : 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(style.icon, size: 22, color: style.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(message.title,
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.ink, height: 1.25)),
                ),
                const SizedBox(height: 8),
                SelectableText(message.body, style: TextStyle(fontSize: 14, color: p.muted, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
