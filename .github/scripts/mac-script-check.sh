#!/usr/bin/env bash
# Checks the AppleScript files that install / update the background service (src/platform/privileges_scripts) with the real macOS tools:
#   1. every .scpt compiles (osacompile)
#   2. update.scpt: the shell script it builds is run through `bash -n` (syntax) with example arguments, and has to carry the steps that keep the
#      service running (load the daemon without aborting, bootstrap + kickstart the agent)
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
dir="$root/src/platform/privileges_scripts"
work="$(mktemp -d)"

for f in "$dir"/*.scpt; do
  osacompile -o "$work/$(basename "$f").scptd" "$f"
  echo "compiles: $(basename "$f")"
done

# update.scpt with its last line (the privileged `do shell script`) turned into `return sh`, so osascript prints the shell script instead of running it
sed 's/^  do shell script sh with prompt.*$/  return sh/' "$dir/update.scpt" > "$work/update-print.scpt"
grep -q 'return sh' "$work/update-print.scpt" || { echo "FAIL: the do-shell-script line of update.scpt was not found" >&2; exit 1; }
osascript "$work/update-print.scpt" '<plist>daemon</plist>' '<plist>agent</plist>' "$(id -un)" 12345 /tmp/SystemDesk.app > "$work/update.sh"
bash -n "$work/update.sh"
echo "update.scpt builds a shell script that parses ($(wc -c < "$work/update.sh") bytes)"

for must in 'set -e' 'launchctl unload -w' 'launchctl load -w /Library/LaunchDaemons/com.carriez.RustDesk_service.plist || true' 'launchctl bootstrap gui/$uid' 'launchctl kickstart -k gui/$uid/$agent_label'; do
  grep -qF -- "$must" "$work/update.sh" || { echo "FAIL: the update script no longer contains: $must" >&2; exit 1; }
done
echo "OK: the update script carries the steps that restart the service"
