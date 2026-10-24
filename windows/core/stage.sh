#!/usr/bin/env bash
#
# Stages everything building or testing the Windows core needs, each piece
# pinned and checked, so the core is the same on any machine:
#
#   ../../android/core/.src/xray-core  Xray-core with android/core/patches applied.
#                                      go.mod replaces xray-core with it. It is
#                                      Android's own staging, so the two platforms
#                                      cannot run different cores.
#   .assets/geoip.dat, geosite.dat     The routing data Android ships, taken from the
#                                      AndroidLibXrayLite version android/core/go.mod
#                                      pins and go.sum checksums.
#   .assets/wintun/                    Wintun, the driver the TUN adapter runs on,
#                                      checked against WINTUN_SUM.
#
# Run it before any go command in this module; build.sh does.
#
set -euo pipefail

cd "$(dirname "$0")"

# Wintun releases are rare; when one comes, update both values. The sum is
# the one WireGuard for Windows pins for the same archive.
readonly WINTUN_VERSION="0.14.1"
readonly WINTUN_SUM="07c256185d6ee3652e09fa55c0b673e2624b565e02c4b9091c79ca7d2f24ef51"
readonly ASSETS=".assets"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v go >/dev/null || die "go not found"
command -v curl >/dev/null || die "curl not found"
command -v unzip >/dev/null || die "unzip not found"

# Same toolchain as go.mod, so a manual run does not fetch another one.
if [[ -z "${GOTOOLCHAIN:-}" ]]; then
  toolchain_pin=$(awk '$1=="toolchain"{print $2}' go.mod)
  [[ -z "$toolchain_pin" ]] || export GOTOOLCHAIN="$toolchain_pin"
fi

sha256() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# --- the core ---------------------------------------------------------------
../../android/core/stage-xray.sh

# The version a go.mod requires, whether on a "require" line of its own or in
# a require block.
required_xray() {
  awk '$1=="require" && $2=="github.com/xtls/xray-core" {print $3; exit}
       $1=="github.com/xtls/xray-core" && $2 ~ /^v/ {print $2; exit}' "$1"
}
android_xray=$(required_xray ../../android/core/go.mod)
windows_xray=$(required_xray go.mod)
[[ "$android_xray" == "$windows_xray" ]] || die "go.mod requires xray-core $windows_xray, \
android/core requires $android_xray. The two platforms must run the same core."

mkdir -p "$ASSETS"

# --- routing data -----------------------------------------------------------
log "staging geo data from the AndroidLibXrayLite version android/core pins"
info=$(cd ../../android/core && go mod download -json github.com/2dust/AndroidLibXrayLite)
lib_dir=$(printf '%s' "$info" | sed -n 's/^[[:space:]]*"Dir": "\(.*\)",\{0,1\}$/\1/p' | head -1)
[[ -d "$lib_dir/assets" ]] || die "AndroidLibXrayLite has no assets directory at $lib_dir"
for dat in geoip.dat geosite.dat; do
  [[ -s "$lib_dir/assets/$dat" ]] || die "AndroidLibXrayLite has no $dat"
  cp -f "$lib_dir/assets/$dat" "$ASSETS/$dat"
  chmod u+w "$ASSETS/$dat"
done

# --- Wintun -----------------------------------------------------------------
stamp="$ASSETS/wintun/.stamp"
if [[ -f "$stamp" && "$(cat "$stamp")" == "$WINTUN_VERSION $WINTUN_SUM" ]]; then
  log "wintun $WINTUN_VERSION already staged"
else
  log "fetching wintun $WINTUN_VERSION"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "https://www.wintun.net/builds/wintun-$WINTUN_VERSION.zip" -o "$tmp/wintun.zip"
  sum=$(sha256 "$tmp/wintun.zip")
  [[ "$sum" == "$WINTUN_SUM" ]] || die "wintun-$WINTUN_VERSION.zip has sha256 $sum, expected $WINTUN_SUM"
  unzip -q "$tmp/wintun.zip" -d "$tmp"
  rm -rf "$ASSETS/wintun"
  mkdir -p "$ASSETS/wintun"
  for arch in amd64 arm64; do
    mkdir -p "$ASSETS/wintun/$arch"
    cp "$tmp/wintun/bin/$arch/wintun.dll" "$ASSETS/wintun/$arch/wintun.dll"
  done
  # Its licence lets the unmodified DLL ship next to software that uses it
  # only through wintun.h, which the core does, and asks that the notice
  # travel with it.
  cp "$tmp/wintun/LICENSE.txt" "$ASSETS/wintun/LICENSE.txt"
  printf '%s\n' "$WINTUN_VERSION $WINTUN_SUM" > "$stamp"
fi

log "staged $ASSETS"
