#!/usr/bin/env bash
# SystemDesk: makes a dmg smaller by writing it again with a stronger compression (UDBZ = bzip2, ULMO = LZMA). Nothing inside changes: the same image is
# compressed again, so a dmg that is signed afterwards is signed as it is, and the app inside keeps its own signature. When anything goes wrong the dmg is left
# exactly as it was, and this never fails the build.
#   recompress-dmg.sh <file.dmg> <UDBZ|ULMO>
# ULMO needs macOS 10.15 or later to be opened; use it only for builds that need that anyway (Apple Silicon needs 11), UDBZ opens everywhere.
set -u
dmg="${1:?the dmg}"
fmt="${2:-UDBZ}"
out="${dmg%.dmg}.recompressed.dmg"
rm -f "$out"
before=$(stat -f%z "$dmg" 2>/dev/null || echo 0)
if hdiutil convert "$dmg" -format "$fmt" -o "$out" >/dev/null 2>&1 && [ -s "$out" ]; then
  after=$(stat -f%z "$out" 2>/dev/null || echo 0)
  if [ "$after" -gt 0 ] && [ "$after" -lt "$before" ] && hdiutil verify "$out" >/dev/null 2>&1; then
    mv -f "$out" "$dmg"
    echo "dmg $dmg: $before -> $after bytes ($fmt)"
  else
    rm -f "$out"
    echo "dmg $dmg: kept as it was ($before bytes; written again it had $after bytes or did not verify)"
  fi
else
  rm -f "$out"
  echo "dmg $dmg: could not be written again as $fmt: kept as it was ($before bytes)"
fi
exit 0
