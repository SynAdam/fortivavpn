#!/bin/bash
#
# An Xcode build phase of the Runner target: puts the tunnel in the app.
#
#   Contents/MacOS/fortiva-core                      the core (windows/core), universal
#   Contents/Resources/geoip.dat, geosite.dat        its routing data
#   Contents/Library/LaunchDaemons/<label>.plist     the daemon SMAppService registers
#
# It takes the core from windows/core/dist/macos and builds it there first
# when it is missing (that needs Go). After a change to the core, run
# windows/core/build.sh macos again; macos/build.sh, which builds a
# release, always does.
#
# Xcode signs the bundle after this phase but not the executables inside
# it, so the core is signed here with the app's identity and the hardened
# runtime. launchd refuses a daemon whose signature does not match the
# app's team.
set -euo pipefail

core_dir="$PROJECT_DIR/../windows/core"
dist="$core_dir/dist/macos"
if [[ ! -x "$dist/fortiva-core" ]]; then
  echo "embed_tunnel.sh: no core in $dist; building it"
  "$core_dir/build.sh" macos
fi

app="$TARGET_BUILD_DIR/$WRAPPER_NAME"
install -m 0755 "$dist/fortiva-core" "$app/Contents/MacOS/fortiva-core"
install -m 0644 "$dist/geoip.dat" "$dist/geosite.dat" "$app/Contents/Resources/"
mkdir -p "$app/Contents/Library/LaunchDaemons"
install -m 0644 "$PROJECT_DIR/Runner/LaunchDaemons/com.vpn.fortivavpn.tunnel.plist" \
  "$app/Contents/Library/LaunchDaemons/"

if [[ "${CODE_SIGNING_ALLOWED:-YES}" == "YES" && -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp=none \
    --identifier com.vpn.fortivavpn.tunnel \
    --sign "$EXPANDED_CODE_SIGN_IDENTITY" \
    "$app/Contents/MacOS/fortiva-core"
fi
