import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The line icons of the design: 24 x 24 grid, round caps and joins (Lucide, ISC licence). Only the drawing is stored here; [SdIcon] puts the stroke,
/// the colour and the size on it.
class SdIcons {
  SdIcons._();

  static const String monitor = '<rect width="20" height="14" x="2" y="3" rx="2"/><path d="M8 21h8M12 17v4"/>';
  static const String copy = '<rect width="13" height="13" x="8" y="8" rx="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>';
  static const String refresh = '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8M21 3v5h-5M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16M8 16H3v5"/>';
  static const String folder = '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/>';
  static const String sliders = '<path d="M21 4h-7M10 4H3M21 12h-9M8 12H3M21 20h-5M12 20H3M14 2v4M8 10v4M16 18v4"/>';
  static const String search = '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>';
  static const String video = '<path d="m16 13 5.223 3.482a.5.5 0 0 0 .777-.416V7.87a.5.5 0 0 0-.752-.432L16 10.5"/><rect x="2" y="6" width="14" height="12" rx="2"/>';
  static const String terminal = '<path d="m4 17 6-6-6-6M12 19h8"/>';
  static const String swap = '<path d="m8 3-4 4 4 4M4 7h16M16 21l4-4-4-4M20 17H4"/>';
  static const String user = '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>';
  static const String pencil = '<path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/><path d="m15 5 4 4"/>';
  static const String link = '<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>';
  static const String chevronDown = '<path d="m6 9 6 6 6-6"/>';
  static const String chevronRight = '<path d="m9 6 6 6-6 6"/>';
  static const String chevronLeft = '<path d="m15 6-6 6 6 6"/>';
  static const String chevronUp = '<path d="m18 15-6-6-6 6"/>';
  static const String key = '<circle cx="7.5" cy="15.5" r="5.5"/><path d="m21 2-9.6 9.6M15.5 7.5l3 3L22 7l-3-3"/>';
  static const String gear =
      '<path d="M12.2 2h-.4a2 2 0 0 0-2 2v.2a2 2 0 0 1-1 1.7l-.4.3a2 2 0 0 1-2 0l-.2-.1a2 2 0 0 0-2.7.7l-.2.4a2 2 0 0 0 .7 2.7l.2.1a2 2 0 0 1 1 1.7v.5a2 2 0 0 1-1 1.8l-.2.1a2 2 0 0 0-.7 2.7l.2.4a2 2 0 0 0 2.7.7l.2-.1a2 2 0 0 1 2 0l.4.3a2 2 0 0 1 1 1.7v.2a2 2 0 0 0 2 2h.4a2 2 0 0 0 2-2v-.2a2 2 0 0 1 1-1.7l.4-.3a2 2 0 0 1 2 0l.2.1a2 2 0 0 0 2.7-.7l.2-.4a2 2 0 0 0-.7-2.7l-.2-.1a2 2 0 0 1-1-1.8v-.5a2 2 0 0 1 1-1.7l.2-.1a2 2 0 0 0 .7-2.7l-.2-.4a2 2 0 0 0-2.7-.7l-.2.1a2 2 0 0 1-2 0l-.4-.3a2 2 0 0 1-1-1.7V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/>';
  static const String shield =
      '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/>';
  static const String check = '<path d="M20 6 9 17l-5-5"/>';
  static const String power = '<path d="M12 2v10M18.4 6.6a9 9 0 1 1-12.77.04"/>';
  static const String bell = '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.94 1.94 0 0 0 3.4 0"/>';
  static const String alertCircle = '<circle cx="12" cy="12" r="10"/><path d="M12 8v4M12 16h.01"/>';
  static const String alertTriangle = '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3ZM12 9v4M12 17h.01"/>';
  static const String checkCircle = '<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><path d="m9 11 3 3L22 4"/>';
  static const String info = '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/>';
  static const String close = '<path d="M18 6 6 18M6 6l12 12"/>';
  static const String download = '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>';
  static const String star = '<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z"/>';
  static const String plus = '<path d="M12 5v14M5 12h14"/>';
  static const String list = '<path d="M4 6h16M4 12h16M4 18h16"/>';
  static const String image = '<rect width="18" height="18" x="3" y="3" rx="2" ry="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21"/>';
  static const String grid ='<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>';
  static const String dots = '<circle cx="12" cy="5" r="1.8"/><circle cx="12" cy="12" r="1.8"/><circle cx="12" cy="19" r="1.8"/>';
  static const String eye = '<path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>';
  static const String keyboard ='<rect width="20" height="14" x="2" y="5" rx="2"/><path d="M6 9h.01M10 9h.01M14 9h.01M18 9h.01M7 13h10"/>';
  static const String mouse = '<rect width="14" height="20" x="5" y="2" rx="7"/><path d="M12 6v4"/>';
  static const String clipboard = '<rect width="8" height="4" x="8" y="2" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/>';
  static const String speaker = '<path d="M11 5 6 9H2v6h4l5 4zM15.5 8.5a5 5 0 0 1 0 7M19 5a9 9 0 0 1 0 14"/>';
  static const String mic = '<path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3zM19 10v2a7 7 0 0 1-14 0v-2M12 19v3"/>';
  static const String record = '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="3.5" fill="currentColor"/>';
  static const String lock = '<rect width="18" height="11" x="3" y="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>';
  static const String clock = '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>';
  static const String arrowUpRight = '<path d="M7 7h10v10M7 17 17 7"/>';
  static const String arrowDownLeft = '<path d="M17 7 7 17M17 17H7V7"/>';
  static const String trash = '<path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/>';
  static const String mail = '<rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/>';
  static const String tiles = '<rect x="3" y="3" width="8" height="8" rx="1.5"/><rect x="13" y="3" width="8" height="8" rx="1.5"/><rect x="3" y="13" width="8" height="8" rx="1.5"/><rect x="13" y="13" width="8" height="8" rx="1.5"/>';
  static const String chat = '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>';
  static const String phone = '<path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/>';
  static const String pin = '<path d="M12 17v5M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z"/>';
  static const String smartphone = '<rect width="14" height="20" x="5" y="2" rx="2" ry="2"/><path d="M12 18h.01"/>';
  static const String sort = '<path d="m3 16 4 4 4-4M7 20V4M21 8l-4-4-4 4M17 4v16"/>';
  static const String tag = '<path d="M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42z"/><path d="M7.5 7.5h.01"/>';
  static const String squareCheck = '<rect width="18" height="18" x="3" y="3" rx="2"/><path d="m9 12 2 2 4-4"/>';
}

/// One of the icons above, in one colour, at one size. [fill] draws it solid (the star of an favourite computer).
class SdIcon extends StatelessWidget {
  const SdIcon(this.body, {super.key, this.size = 18, required this.color, this.stroke = 1.9, this.fill = false});
  final String body;
  final double size, stroke;
  final Color color;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="${fill ? '#000' : 'none'}" stroke="#000" stroke-width="$stroke" '
        'stroke-linecap="round" stroke-linejoin="round">${body.replaceAll('fill="currentColor"', 'fill="#000"')}</svg>';
    return SvgPicture.string(svg, width: size, height: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
  }
}

/// The kind of computer a saved computer is.
enum SdOs { windows, mac, linux, android, other }

SdOs sdOsOf(String platform) {
  final p = platform.toLowerCase();
  if (p.contains('windows')) return SdOs.windows;
  if (p.contains('mac')) return SdOs.mac;
  if (p.contains('android')) return SdOs.android;
  if (p.contains('linux')) return SdOs.linux;
  return SdOs.other;
}

/// The operating system logo of a computer: the Windows panes in their blue, the apple in the ink colour, the penguin in its own colours.
class SdOsIcon extends StatelessWidget {
  const SdOsIcon(this.os, {super.key, this.size = 26, required this.ink});
  final SdOs os;
  final double size;
  final Color ink;

  static const _windows = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#1F7BC8"><path d="M3 5.5l8-1.1v7H3zM12 4.3l9-1.3v8.4h-9zM3 12.6h8v7l-8-1.1zM12 12.6h9v8.4l-9-1.3z"/></svg>';
  static const _apple =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#000"><path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701"/></svg>';
  static const _linux =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><ellipse cx="12" cy="13" rx="6.2" ry="8" fill="#2A3350" stroke="#9AA5BE" stroke-width=".8"/><ellipse cx="12" cy="14.6" rx="3.6" ry="5.3" fill="#F4F1E8"/><circle cx="10" cy="8.4" r="1" fill="#fff"/><circle cx="14" cy="8.4" r="1" fill="#fff"/><path d="M10.4 10.3l1.6 1.2 1.6-1.2-1.6-.8z" fill="#E2AC50"/><ellipse cx="8.4" cy="21" rx="2.4" ry="1.1" fill="#E2AC50"/><ellipse cx="15.6" cy="21" rx="2.4" ry="1.1" fill="#E2AC50"/></svg>';

  @override
  Widget build(BuildContext context) {
    switch (os) {
      case SdOs.windows:
        return SvgPicture.string(_windows, width: size, height: size);
      case SdOs.mac:
        return SvgPicture.string(_apple, width: size, height: size, colorFilter: ColorFilter.mode(ink, BlendMode.srcIn));
      case SdOs.linux:
        return SvgPicture.string(_linux, width: size, height: size);
      case SdOs.android:
        return SdIcon(SdIcons.monitor, size: size - 4, color: const Color(0xFF3DDC84), stroke: 1.8);
      case SdOs.other:
        return SdIcon(SdIcons.monitor, size: size - 4, color: ink, stroke: 1.8);
    }
  }
}
