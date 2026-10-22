#!/usr/bin/env bash
# Checks sign-macos-selfsigned.sh on a small fake app: two different "builds" (ad hoc signed first, like the Xcode build) are signed with the stable
# identity and must end up with the SAME designated requirement, which is what keeps macOS permissions across an update.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
entitlements="$root/flutter/macos/Runner/Release.entitlements"

build_fake_app() { # <app> <text printed by the program>
  local app=$1 text=$2
  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Frameworks"
  printf '#include <stdio.h>\nint main(){puts("%s");return 0;}\n' "$text" > "$work/main.c"
  printf 'int lib_value(){return %s;}\n' "${#text}" > "$work/lib.c"
  clang "$work/main.c" -o "$app/Contents/MacOS/Fake"
  clang -dynamiclib "$work/lib.c" -o "$app/Contents/Frameworks/libfake.dylib"
  cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Fake</string>
<key>CFBundleIdentifier</key><string>com.systemdesk.app</string>
<key>CFBundleName</key><string>Fake</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
</dict></plist>
PLIST
  codesign --force --deep --sign - "$app"   # what the Xcode build leaves
}

requirement() { codesign -d -r- "$1" 2>&1 | grep 'designated' | sed 's/^designated => //'; }

build_fake_app "$work/build1.app" "first build"
build_fake_app "$work/build2.app" "second build, different code"
echo "ad hoc requirement 1: $(requirement "$work/build1.app")"
echo "ad hoc requirement 2: $(requirement "$work/build2.app")"

bash "$root/.github/scripts/sign-macos-selfsigned.sh" "$work/build1.app" "$entitlements"
bash "$root/.github/scripts/sign-macos-selfsigned.sh" "$work/build2.app" "$entitlements"

r1=$(requirement "$work/build1.app")
r2=$(requirement "$work/build2.app")
echo "stable requirement 1: $r1"
echo "stable requirement 2: $r2"
if [[ -z "$r1" || "$r1" != "$r2" ]]; then
  echo "FAIL: the two builds do not have the same designated requirement" >&2
  exit 1
fi
if echo "$r1" | grep -q 'cdhash'; then
  echo "FAIL: the requirement still depends on the build (cdhash)" >&2
  exit 1
fi
"$work/build1.app/Contents/MacOS/Fake"
"$work/build2.app/Contents/MacOS/Fake"
echo "OK: the same requirement in both builds, and both run"
