#!/usr/bin/env bash
#
# Stages .src/xray-core: the pinned Xray-core source with patches/*.patch
# applied. go.mod replaces github.com/xtls/xray-core with that directory, so
# every go command in this module needs it to exist. build.sh runs this first;
# run it by hand before `go mod tidy`, `go vet` or `go test`.
#
# The base is taken from the Go module cache, and its checksum is compared with
# XRAY_SUM below, so the staged tree is the pinned source plus the patches in
# this repository and nothing else.
#
set -euo pipefail

cd "$(dirname "$0")"

# The version AndroidLibXrayLite requires. Bumping the core changes it: update
# both values, then check that every patch still applies and its tests pass
# (README.md, "Patches").
readonly XRAY_VERSION="v1.260327.1-0.20260728075948-5ca6f4b7d4dc"
readonly XRAY_SUM="h1:fkOkmgHWbF2Q8MdV9VxrsyxRz4OndcrUXUkh1ANBTg0="
readonly DEST=".src/xray-core"
readonly STAMP="$DEST/.fortiva-stamp"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v go >/dev/null || die "go not found"
command -v patch >/dev/null || die "patch not found"

# Same toolchain as the build, so a manual run does not fetch another one.
if [[ -z "${GOTOOLCHAIN:-}" ]]; then
  toolchain_pin=$(awk '$1=="toolchain"{print $2}' go.mod)
  [[ -z "$toolchain_pin" ]] || export GOTOOLCHAIN="$toolchain_pin"
fi

required=$(awk '$1=="github.com/xtls/xray-core" && $2 ~ /^v/ {print $2; exit}' go.mod)
[[ "$required" == "$XRAY_VERSION" ]] || die "go.mod requires xray-core $required, \
this script stages $XRAY_VERSION. Update XRAY_VERSION and XRAY_SUM, then re-check the patches."

want="$XRAY_VERSION $XRAY_SUM $(cat patches/*.patch | shasum -a 256 | cut -d' ' -f1)"
if [[ -f "$STAMP" && "$(cat "$STAMP")" == "$want" ]]; then
  log "patched xray-core already staged in $DEST"
  exit 0
fi

# Run outside this module: its go.mod replaces xray-core with the directory
# this script is about to create.
log "fetching xray-core $XRAY_VERSION"
info=$(cd "$(mktemp -d)" && GOFLAGS=-mod=mod go mod download -json "github.com/xtls/xray-core@$XRAY_VERSION")
field() { printf '%s' "$info" | sed -n "s/^[[:space:]]*\"$1\": \"\(.*\)\",\{0,1\}$/\1/p" | head -1; }
src=$(field Dir)
sum=$(field Sum)
[[ -d "$src" ]] || die "go mod download did not return a source directory"
[[ "$sum" == "$XRAY_SUM" ]] || die "xray-core checksum is $sum, expected $XRAY_SUM"

rm -rf "$DEST" "$DEST.tmp"
mkdir -p "$(dirname "$DEST")"
cp -R "$src" "$DEST.tmp"
chmod -R u+w "$DEST.tmp"
# In name order. Each patch is written against the tree the ones before it
# leave: xray-failover-calm and xray-stability-penalty change what
# xray-autoselect adds, and xray-stability-penalty builds on
# xray-failover-calm.
for p in patches/*.patch; do
  log "applying $p"
  patch -p1 -s -d "$DEST.tmp" < "$p" || die "$p does not apply to xray-core $XRAY_VERSION"
done
mv "$DEST.tmp" "$DEST"
printf '%s\n' "$want" > "$STAMP"
log "staged $DEST"
