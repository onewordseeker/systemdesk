#!/usr/bin/env bash
# Signs the Mac app with SystemDesk's own STABLE certificate (self-signed, from the secrets MACOS_SELFSIGN_P12_BASE64 / MACOS_SELFSIGN_P12_PASSWORD).
#   sign-macos-selfsigned.sh <SystemDesk.app> <entitlements.plist>
# An app that is only "ad hoc" signed is a different app to macOS after every build, so an update loses the permissions the person granted
# (Screen Recording, Accessibility, Input Monitoring). Every build signed with the same certificate has the same designated requirement
# (identifier + certificate), and macOS keeps the permissions. The hardened runtime stays off (see Runner.xcodeproj: ENABLE_HARDENED_RUNTIME = NO):
# a build signed with it could not load its own frameworks.
set -euo pipefail

app_path=$1
entitlements=$2
: "${SELFSIGN_P12:?the certificate (base64) is not given}"
: "${SELFSIGN_PASS:?the certificate password is not given}"

work="${RUNNER_TEMP:-/tmp}/sd-selfsign-$$"
keychain="$work/sd-sign.keychain-db"
keychain_pass="$(uuidgen)"
mkdir -p "$work"
cleanup() {
  security delete-keychain "$keychain" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

echo "$SELFSIGN_P12" | base64 --decode > "$work/id.p12"
security create-keychain -p "$keychain_pass" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_pass" "$keychain"
security import "$work/id.p12" -k "$keychain" -P "$SELFSIGN_PASS" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_pass" "$keychain" >/dev/null
# the keychain has to be in the search list for codesign to find the identity
existing=$(security list-keychains -d user | tr -d '"' | tr '\n' ' ')
# shellcheck disable=SC2086
security list-keychains -d user -s "$keychain" $existing

identity() { security find-identity -v -p codesigning "$keychain" | sed -n 's/^ *[0-9]*) \([0-9A-F]\{40\}\) "SystemDesk Code Signing".*/\1/p' | head -1; }
hash=$(identity)
if [[ -z "$hash" ]]; then
  # a self-signed certificate is not trusted by default: trust it for code signing on this build machine, then look again
  security find-certificate -c "SystemDesk Code Signing" -p "$keychain" > "$work/cert.pem"
  sudo security add-trusted-cert -d -r trustRoot -p codeSign -k /Library/Keychains/System.keychain "$work/cert.pem" \
    || security add-trusted-cert -r trustRoot -p codeSign -k "$keychain" "$work/cert.pem" || true
  hash=$(identity)
fi
if [[ -z "$hash" ]]; then
  echo "No valid code-signing identity after the import:" >&2
  security find-identity -p codesigning "$keychain" >&2 || true
  exit 1
fi
echo "Signing with identity $hash"

sign_args=(--force --sign "$hash" --keychain "$keychain" --timestamp=none)

frameworks_path="$app_path/Contents/Frameworks"
if [[ -d "$frameworks_path" ]]; then
  while IFS= read -r -d '' code; do
    if file -b "$code" | grep -q 'Mach-O'; then
      codesign "${sign_args[@]}" "$code"
    fi
  done < <(find "$frameworks_path" -type f -print0)

  while IFS= read -r -d '' framework; do
    codesign "${sign_args[@]}" "$framework"
  done < <(find "$frameworks_path" -depth -type d -name '*.framework' -print0)
fi

service_path="$app_path/Contents/MacOS/service"
if [[ -f "$service_path" ]]; then
  codesign "${sign_args[@]}" "$service_path"
fi

codesign "${sign_args[@]}" --entitlements "$entitlements" "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"

echo "--- signature of the app:"
codesign -dvv "$app_path" 2>&1 | grep -E 'Identifier|Authority|Signature|flags|TeamIdentifier|CDHash' || true
echo "--- designated requirement (must be the same in every build):"
codesign -d -r- "$app_path" 2>&1 | grep 'designated' || true
