#!/usr/bin/env bash
#
# Stages .src/psiphon-quic-go: Psiphon's fork of quic-go
# (github.com/Psiphon-Labs/quic-go) at the version go.mod requires, with
# patches/psiphon-quic-go/*.patch applied. go.mod replaces the fork with that
# directory, so every go command in this module needs it to exist. build.sh
# runs this after stage-xray.sh; run it by hand before `go mod tidy`,
# `go vet` or `go test`.
#
# The patch exists because the fork's http3 package calls the quic-go/qpack
# v0.4 decoder, and Xray-core needs qpack v0.6. One build holds only one
# version of qpack, so the fork is moved to v0.6 and Xray-core is left alone.
#
# The base is taken from the Go module cache, and its checksum is compared with
# QUIC_SUM below, so the staged tree is the pinned source plus the patch in
# this repository and nothing else. The patch lives in a subdirectory because
# stage-xray.sh applies every top-level patches/*.patch to Xray-core.
#
set -euo pipefail

cd "$(dirname "$0")"

# The version psiphon-tunnel-core requires. Bumping Psiphon can change it:
# update both values, then check that the patch still applies (README.md,
# "Psiphon").
readonly QUIC_VERSION="v0.0.0-20250527153145-79fe45fb83b1"
readonly QUIC_SUM="h1:zD7JvZCV8gjvtI0AZmE81Ffc/v7A+qwU1/YfUmN/Flk="
readonly PATCH_DIR="patches/psiphon-quic-go"
readonly DEST=".src/psiphon-quic-go"
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

required=$(awk '$1=="github.com/Psiphon-Labs/quic-go" && $2 ~ /^v/ {print $2; exit}' go.mod)
[[ "$required" == "$QUIC_VERSION" ]] || die "go.mod requires Psiphon-Labs/quic-go $required, \
this script stages $QUIC_VERSION. Update QUIC_VERSION and QUIC_SUM, then re-check the patch."

want="$QUIC_VERSION $QUIC_SUM $(cat "$PATCH_DIR"/*.patch | shasum -a 256 | cut -d' ' -f1)"
if [[ -f "$STAMP" && "$(cat "$STAMP")" == "$want" ]]; then
  log "patched Psiphon-Labs/quic-go already staged in $DEST"
  exit 0
fi

# Run outside this module: its go.mod replaces the fork with the directory
# this script is about to create.
log "fetching Psiphon-Labs/quic-go $QUIC_VERSION"
info=$(cd "$(mktemp -d)" && GOFLAGS=-mod=mod go mod download -json "github.com/Psiphon-Labs/quic-go@$QUIC_VERSION")
field() { printf '%s' "$info" | sed -n "s/^[[:space:]]*\"$1\": \"\(.*\)\",\{0,1\}$/\1/p" | head -1; }
src=$(field Dir)
sum=$(field Sum)
[[ -d "$src" ]] || die "go mod download did not return a source directory"
[[ "$sum" == "$QUIC_SUM" ]] || die "Psiphon-Labs/quic-go checksum is $sum, expected $QUIC_SUM"

rm -rf "$DEST" "$DEST.tmp"
mkdir -p "$(dirname "$DEST")"
cp -R "$src" "$DEST.tmp"
chmod -R u+w "$DEST.tmp"
for p in "$PATCH_DIR"/*.patch; do
  log "applying $p"
  patch -p1 -s -d "$DEST.tmp" < "$p" || die "$p does not apply to Psiphon-Labs/quic-go $QUIC_VERSION"
done
mv "$DEST.tmp" "$DEST"
printf '%s\n' "$want" > "$STAMP"
log "staged $DEST"
