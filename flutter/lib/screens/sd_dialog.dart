import 'package:flutter/material.dart';

/// The app's confirmation / notice dialog: a round icon badge, a title and text, optionally the thing it is about
/// (a device), a short checklist of what will happen and an amber "read this" box. Same look as the console and the
/// customer portal. One button (cancelLabel null) = a notice, two = a question; the result is true only for the
/// confirm button.
enum SdTone { danger, warning, primary }

class SdDialogSubject {
  const SdDialogSubject(this.icon, this.title, {this.sub});
  final IconData icon;
  final String title;
  final String? sub;
}

class SdDialogWarning {
  const SdDialogWarning(this.title, this.text);
  final String title;
  final String text;
}

Future<bool> showSdDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  String? message,
  SdTone tone = SdTone.danger,
  SdDialogSubject? subject,
  List<String> facts = const [],
  SdDialogWarning? warning,
  String confirmLabel = 'OK',
  String? cancelLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => _SdDialog(
      icon: icon,
      title: title,
      message: message,
      tone: tone,
      subject: subject,
      facts: facts,
      warning: warning,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
  return result == true;
}

class _SdDialog extends StatelessWidget {
  const _SdDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
    required this.subject,
    required this.facts,
    required this.warning,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final IconData icon;
  final String title;
  final String? message;
  final SdTone tone;
  final SdDialogSubject? subject;
  final List<String> facts;
  final SdDialogWarning? warning;
  final String confirmLabel;
  final String? cancelLabel;

  static const _amber = Color(0xFFF59E0B);
  static const _amberDeep = Color(0xFFC9820A);
  static const _onAmber = Color(0xFF241700);
  static const _danger = Color(0xFFD9534F);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark ? const Color(0xFF20222A) : Colors.white;
    final footer = dark ? const Color(0xFF1A1C22) : const Color(0xFFF7F4ED);
    final border = dark ? const Color(0xFF30323A) : const Color(0xFFECE7DB);
    final ink = dark ? const Color(0xFFECEAE4) : const Color(0xFF1A1712);
    final muted = dark ? const Color(0xFF8B8F99) : const Color(0xFF8F887B);
    final chip = dark ? const Color(0xFF282A32) : const Color(0xFFF7F4ED);
    final warnBg = dark ? const Color(0xFF3A2E12) : const Color(0xFFFFF4DC);
    final warnBorder = dark ? const Color(0xFF5A4518) : const Color(0xFFFBE0A0);
    final warnText = dark ? const Color(0xFFF0C26B) : const Color(0xFF8A5A00);

    final badgeColor = tone == SdTone.danger ? _danger : (tone == SdTone.warning ? const Color(0xFFB06F00) : _amberDeep);
    final badgeBg = badgeColor.withOpacity(dark ? 0.2 : 0.12);
    final confirmBg = tone == SdTone.primary ? _amber : _danger;
    final confirmFg = tone == SdTone.primary ? _onAmber : Colors.white;
    // a destructive action never has the focus first: the safe button does
    final focusCancel = tone != SdTone.primary && cancelLabel != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 32, offset: Offset(0, 12))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
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
                              decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(14)),
                              child: Icon(icon, size: 22, color: badgeColor),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        style: TextStyle(
                                            fontSize: 16.5, fontWeight: FontWeight.w700, color: ink, height: 1.25)),
                                    if (message != null) ...[
                                      const SizedBox(height: 6),
                                      Text(message!, style: TextStyle(fontSize: 13, color: muted, height: 1.45)),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (subject != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(color: chip, borderRadius: BorderRadius.circular(14)),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: card,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: border),
                                  ),
                                  child: Icon(subject!.icon, size: 17, color: muted),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(subject!.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ink)),
                                      if (subject!.sub != null)
                                        Text(subject!.sub!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 11.5, color: muted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (facts.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          for (final f in facts)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(Icons.check_rounded, size: 16, color: badgeColor),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(child: Text(f, style: TextStyle(fontSize: 13, color: ink, height: 1.4))),
                                ],
                              ),
                            ),
                        ],
                        if (warning != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: BoxDecoration(
                              color: warnBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: warnBorder),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Icon(Icons.warning_amber_rounded, size: 18, color: warnText),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(warning!.title,
                                          style: TextStyle(
                                              fontSize: 13, fontWeight: FontWeight.w700, color: warnText, height: 1.35)),
                                      const SizedBox(height: 2),
                                      Text(warning!.text,
                                          style: TextStyle(fontSize: 12.5, color: warnText, height: 1.45)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  color: footer,
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (cancelLabel != null) ...[
                        OutlinedButton(
                          autofocus: focusCancel,
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ink,
                            side: BorderSide(color: border),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(cancelLabel!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ],
                      ElevatedButton(
                        autofocus: !focusCancel,
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: confirmBg,
                          foregroundColor: confirmFg,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
