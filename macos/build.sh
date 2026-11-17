#!/usr/bin/env bash
#
# Builds the macOS release: build/macos/FortivaVPN-<version>-macos.dmg, with
# the app and its tunnel signed for distribution outside the Mac App Store
# (Developer ID, hardened runtime) and the disk image notarized by Apple and
# stapled, so a downloaded copy opens without a warning.
#
#   macos/build.sh                 sign with MACOS_SIGN_IDENTITY, notarize
#   macos/build.sh --no-notarize   sign only: a disk image to try, or to
#                                  notarize later
#   macos/build.sh --dev           sign with the team's Apple Development
#                                  certificate: runs on this Mac and the
#                                  ones that trust it, never published
#
# MACOS_SIGN_IDENTITY is the Developer ID Application certificate's name, as
# "security find-identity -v -p codesigning" prints it. Notarizing uses the
# App Store Connect API key in ~/.appstoreconnect/private_keys
# (ASC_KEY_ID, ASC_ISSUER_ID; see "Credentials" in the root README).
#
set -euo pipefail

cd "$(dirname "$0")/.."
root=$(pwd)

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

readonly TEAM="4KWYXWA46X"
readonly LABEL="com.vpn.fortivavpn.tunnel"

mode="release"
case "${1:-}" in
  "") ;;
  --no-notarize) mode="signed" ;;
  --dev) mode="dev" ;;
  *) die "unknown option $1 (--no-notarize or --dev)" ;;
esac

[[ "$(uname -s)" == "Darwin" ]] || die "the macOS app builds only on a Mac"
command -v flutter >/dev/null || die "flutter not found"

if [[ "$mode" == "dev" ]]; then
  identity="Apple Development"
else
  identity="${MACOS_SIGN_IDENTITY:-}"
  [[ -n "$identity" ]] || die "set MACOS_SIGN_IDENTITY to the Developer ID Application certificate (or use --dev)"
  [[ "$identity" == "Developer ID Application"* ]] || die "MACOS_SIGN_IDENTITY is not a Developer ID Application certificate: $identity"
fi
# The certificate's team is its OU, not part of its name, and a keychain
# can hold certificates of several teams under one name. Sign with the hash
# of the one that is this team's.
sign_hash=""
while read -r hash cert; do
  subject=$(security find-certificate -c "$cert" -p 2>/dev/null | openssl x509 -noout -subject 2>/dev/null || true)
  if [[ "$subject" == *"OU=$TEAM,"* || "$subject" == *"OU = $TEAM,"* ]]; then
    sign_hash="$hash"
    break
  fi
done < <(security find-identity -v -p codesigning | sed -n "s/^ *[0-9]*) \([0-9A-F]\{40\}\) \"\($identity[^\"]*\)\"$/\1 \2/p")
[[ -n "$sign_hash" ]] || die "no '$identity' certificate of team $TEAM in the keychain"

version=$(awk '$1=="version:"{print $2; exit}' pubspec.yaml)
name="${version%%+*}"
[[ -n "$name" ]] || die "no version in pubspec.yaml"

# --- build ------------------------------------------------------------------
# The core first, always: embed_tunnel.sh takes whatever dist/macos holds.
windows/core/build.sh macos
log "building the app $version"
# MACOS_FLUTTER_ARGS passes more to flutter, such as --no-pub where pub.dev
# cannot be reached (it refuses Iranian addresses) and the packages are
# already fetched.
# shellcheck disable=SC2086
flutter build macos --release ${MACOS_FLUTTER_ARGS:-}

app="build/macos/Build/Products/Release/Fortiva VPN.app"
[[ -d "$app" ]] || die "no $app"
[[ -x "$app/Contents/MacOS/fortiva-core" ]] || die "the app carries no tunnel (embed_tunnel.sh did not run)"
[[ -f "$app/Contents/Library/LaunchDaemons/$LABEL.plist" ]] || die "the app carries no daemon property list"

# --- sign -------------------------------------------------------------------
# Inside out: every framework and library, the core, then the app. Xcode
# signed them for development; distribution needs the release identity, the
# hardened runtime and a secure timestamp on each.
log "signing with $identity ($sign_hash)"
timestamp="--timestamp"
[[ "$mode" == "dev" ]] && timestamp="--timestamp=none"
while IFS= read -r -d '' code; do
  codesign --force --options runtime $timestamp --sign "$sign_hash" "$code"
done < <(find "$app/Contents/Frameworks" -depth \( -name '*.framework' -o -name '*.dylib' \) -print0)
codesign --force --options runtime $timestamp --identifier "$LABEL" \
  --sign "$sign_hash" "$app/Contents/MacOS/fortiva-core"
codesign --force --options runtime $timestamp \
  --entitlements macos/Runner/Release.entitlements \
  --sign "$sign_hash" "$app"

log "verifying the signatures"
codesign --verify --deep --strict --verbose=1 "$app"
for code in "$app" "$app/Contents/MacOS/fortiva-core"; do
  # Read whole, not piped into grep -q: with pipefail, grep closing the pipe
  # early fails the check.
  details=$(codesign -dv --verbose=2 "$code" 2>&1)
  team=$(awk -F= '$1=="TeamIdentifier"{print $2}' <<<"$details")
  [[ "$team" == "$TEAM" ]] || die "$code is signed by team ${team:-none}, want $TEAM"
  [[ "$details" == *"flags="*"(runtime)"* ]] || die "$code has no hardened runtime"
done
core_version=$("$app/Contents/MacOS/fortiva-core" version | awk -F'"' '$2=="core"{print $4}')
[[ "$core_version" == "$version" ]] || die "the app's core is $core_version, the app $version"

# --- disk image -------------------------------------------------------------
out="build/macos/FortivaVPN-$name-macos.dmg"
log "making $out"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"
rm -f "$out"
hdiutil create -quiet -volname "Fortiva VPN" -srcfolder "$stage" -fs HFS+ -format UDZO "$out"
codesign --force $timestamp --sign "$sign_hash" "$out"

# --- notarize ---------------------------------------------------------------
if [[ "$mode" == "release" ]]; then
  key_id="${ASC_KEY_ID:?set ASC_KEY_ID to the id of the App Store Connect API key}"
  issuer="${ASC_ISSUER_ID:?set ASC_ISSUER_ID to the issuer id of that key}"
  key="$HOME/.appstoreconnect/private_keys/AuthKey_$key_id.p8"
  [[ -f "$key" ]] || die "no API key at $key"
  log "notarizing (this takes a few minutes)"
  xcrun notarytool submit "$out" --key "$key" --key-id "$key_id" --issuer "$issuer" --wait
  xcrun stapler staple "$out"
  spctl --assess --type open --context context:primary-signature --verbose "$out"
fi

shasum -a 256 "$out" | sed "s|  build/macos/|  |" > "$out.sha256"
log "built $out ($mode)"
cat "$out.sha256"
