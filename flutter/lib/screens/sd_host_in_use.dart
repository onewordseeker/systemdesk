import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart' show translate;

/// What the controller sees while the person at the controlled computer is using the mouse: input is paused until they stop (the host drops the remote
/// mouse meanwhile, see src/sd_local_input.rs). A small pill at the top of the remote window; it never takes a click.
Widget sdHostInUseNotice(bool show, {String Function(String) tr = translate}) {
  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 160),
    child: show
        ? Container(
            key: const ValueKey('sd-host-in-use'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xEB211C14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x55F59E0B)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  tr('Input not allowed: the person at this computer is using the mouse'),
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500, decoration: TextDecoration.none),
                ),
              ),
            ]),
          )
        : const SizedBox.shrink(key: ValueKey('sd-host-in-use-off')),
  );
}
