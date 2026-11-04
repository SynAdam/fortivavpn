#!/usr/bin/env bash
#
# Builds the core the app ships, ../app/libs/libv2ray.aar, in a linux/amd64
# container, and copies the .aar and checksums.txt back into this tree. A
# one-ABI build copies back only the .aar.
#
# gomobile writes the absolute build folder into each libgojni.so (README.md,
# "Building"), so the folder is part of the output. This script always runs
# build.sh in /build/fortiva-core, with the toolchain that Dockerfile pins.
# Anyone who runs it on the same commit gets the same .aar, byte for byte,
# and can compare its sha256 with the one in checksums.txt. The script
# prints both.
#
# Usage:  ./build-in-linux.sh          build every shipped ABI
#         ./build-in-linux.sh arm64    build one ABI (not shippable)
#         ./build-in-linux.sh --vulncheck <out-dir>
#                                      build nothing: scan the source and the
#                                      committed .aar with govulncheck
#                                      (vulncheck.sh) and copy the results
#                                      into <out-dir>
#
# Needs Docker, and network access for the image's downloads and the Go
# modules. Google builds the NDK for Linux for x86_64 only, so the container
# is linux/amd64 on every machine. Docker Desktop on an Apple silicon Mac
# runs it through Rosetta or QEMU.
#
# The container gets a copy of this directory as git sees it: tracked files
# and new files that .gitignore does not hide, with their uncommitted
# changes. It does not get .src/ or .bin/, or anything else from this
# machine. The Go module cache and build cache stay in two Docker volumes,
# so a second build is faster. To remove them:
#   docker volume rm fortiva-core-gomod fortiva-core-gocache
#
# --vulncheck uses the same image, copy and volumes. The copy also takes the
# committed ../app/libs/libv2ray.aar and a copy of ../../windows/core made
# the same way, and nothing is copied back into the tree.
# tool/core_vulncheck.sh runs this mode and reads the results.
#
set -euo pipefail

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

mode=build
out_dir=""
if [[ "${1:-}" == "--vulncheck" ]]; then
  [[ $# -eq 2 && -n "$2" ]] || die "usage: ./build-in-linux.sh --vulncheck <out-dir>"
  [[ -d "$2" ]] || die "$2 is not a folder"
  # Resolved before the cd below, so a relative folder means the one it
  # names from where the script was started.
  out_dir=$(cd "$2" && pwd)
  mode=vulncheck
  shift 2
fi

cd "$(dirname "$0")"

readonly BUILD_DIR="/build/fortiva-core"
readonly PLATFORM="linux/amd64"
readonly IMAGE_NAME="fortiva-core-builder"
readonly GOMOD_VOLUME="fortiva-core-gomod"
readonly GOCACHE_VOLUME="fortiva-core-gocache"

sha256_of() {
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

command -v docker >/dev/null || die "docker not found"
docker info >/dev/null 2>&1 || die "cannot reach the Docker daemon. Is Docker running?"

# --- pins -----------------------------------------------------------------
# The image must hold the Go that go.mod pins and the NDK that build.sh
# requires. Otherwise build.sh would download another Go, or stop on the NDK.
dockerfile_arg() { sed -n "s/^ARG $1=//p" Dockerfile; }
go_pin=$(awk '$1=="toolchain"{print $2}' go.mod)
image_go="go$(dockerfile_arg GO_VERSION)"
[[ "$image_go" == "$go_pin" ]] || die "go.mod pins ${go_pin:-no toolchain}, but Dockerfile installs $image_go.
Set GO_VERSION and GO_SHA256 in Dockerfile to the toolchain line in go.mod."
ndk_pin=$(sed -n 's/^readonly REQUIRED_NDK="\(.*\)"$/\1/p' build.sh)
image_ndk=$(dockerfile_arg NDK_VERSION)
[[ "$image_ndk" == "$ndk_pin" ]] || die "build.sh requires NDK $ndk_pin, but Dockerfile installs $image_ndk.
Set NDK_VERSION, NDK_RELEASE and NDK_SHA256 in Dockerfile to the NDK in build.sh."

# --- image ----------------------------------------------------------------
# Built without a context, so nothing from this machine goes into it.
dockerfile_sum=$(sha256_of Dockerfile)
image="$IMAGE_NAME:${dockerfile_sum:0:12}"
log "building image $image from Dockerfile"
docker build --platform "$PLATFORM" -t "$image" - < Dockerfile

# --- source ---------------------------------------------------------------
stage=$(mktemp -d)
cid=""
cleanup() {
  if [[ -n "$cid" ]]; then
    docker rm -f "$cid" >/dev/null 2>&1 || true
  fi
  rm -rf "$stage"
}
trap cleanup EXIT

# copy_tree <dir> <dest>: the files of <dir> as git sees them, or all of it
# without the folders the scripts stage into and build into when <dir> is
# not in a git tree.
copy_tree() {
  local src=$1 dest=$2 f
  mkdir -p "$dest"
  if git -C "$src" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r -d '' f; do
      # A tracked file deleted in the working tree is left out.
      [[ -f "$src/$f" ]] || continue
      mkdir -p "$dest/$(dirname "$f")"
      cp -p "$src/$f" "$dest/$f"
    done < <(git -C "$src" ls-files -z --cached --others --exclude-standard)
  else
    cp -Rp "$src/." "$dest/"
    rm -rf "$dest/.src" "$dest/.bin" "$dest/.assets" "$dest/dist"
  fi
}
copy_tree . "$stage/android/core"
[[ -x "$stage/android/core/build.sh" ]] || die "no build.sh in the copy of $(pwd)"

# --- vulnerability scan ---------------------------------------------------
if [[ "$mode" == vulncheck ]]; then
  [[ -x "$stage/android/core/vulncheck.sh" ]] || die "no vulncheck.sh in the copy of $(pwd)"
  [[ -f ../app/libs/libv2ray.aar ]] || die "no ../app/libs/libv2ray.aar to scan"
  mkdir -p "$stage/android/app/libs"
  cp -p ../app/libs/libv2ray.aar "$stage/android/app/libs/libv2ray.aar"
  # The Windows tunnel builds from the same patched Xray-core, so
  # vulncheck.sh scans it too.
  [[ -f ../../windows/core/go.mod ]] || die "no ../../windows/core/go.mod to scan"
  copy_tree ../../windows/core "$stage/windows/core"
  cid=$(docker create --platform "$PLATFORM" \
    -v "$GOMOD_VOLUME:/go/pkg/mod" \
    -v "$GOCACHE_VOLUME:/go/cache" \
    -e VULNCHECK_OUT=/build/out \
    ${GOPROXY:+-e GOPROXY} \
    -w "$BUILD_DIR/android/core" \
    "$image" ./vulncheck.sh)
  docker cp "$stage/." "$cid:$BUILD_DIR"
  log "running vulncheck.sh in $BUILD_DIR/android/core ($PLATFORM container)"
  rc=0
  docker start -a "$cid" || rc=$?
  # Copied even after a failure, so the results so far can be read.
  docker cp "$cid:/build/out/." "$out_dir" 2>/dev/null || true
  [[ $rc -eq 0 ]] || die "vulncheck.sh failed in the container (exit $rc)"
  log "scan results copied into $out_dir"
  exit 0
fi

# --- build ----------------------------------------------------------------
old_sum=$(awk '$2=="libv2ray.aar"{print $1}' checksums.txt 2>/dev/null || true)

# GOPROXY is passed on when it is set, for a machine that cannot reach the
# default proxy. go.sum still checks every module.
cid=$(docker create --platform "$PLATFORM" \
  -v "$GOMOD_VOLUME:/go/pkg/mod" \
  -v "$GOCACHE_VOLUME:/go/cache" \
  -e CORE_BUILD_CONTAINER="android/core/build-in-linux.sh, Dockerfile sha256 $dockerfile_sum" \
  ${GOPROXY:+-e GOPROXY} \
  -w "$BUILD_DIR/android/core" \
  "$image" ./build.sh "$@")
docker cp "$stage/." "$cid:$BUILD_DIR"
log "running build.sh in $BUILD_DIR/android/core ($PLATFORM container)"
docker start -a "$cid" || die "build.sh failed in the container"

mkdir -p ../app/libs
docker cp "$cid:$BUILD_DIR/android/app/libs/libv2ray.aar" ../app/libs/libv2ray.aar
new_sum=$(sha256_of ../app/libs/libv2ray.aar)

# A one-ABI build cannot ship. build.sh does not write checksums.txt for it,
# so the file keeps the sha256 of the last full build and the new .aar does
# not match it.
if [[ $# -gt 0 ]]; then
  log "copied the one-ABI ../app/libs/libv2ray.aar into this tree (NOT shippable)"
  log "  sha256 of the new .aar: $new_sum"
  log "checksums.txt is unchanged. Before you commit the .aar, run a full build"
  log "(./build-in-linux.sh with no argument), or restore the .aar with"
  log "  git restore $(cd ../app/libs && pwd)/libv2ray.aar"
  exit 0
fi

docker cp "$cid:$BUILD_DIR/android/core/checksums.txt" checksums.txt
log "copied ../app/libs/libv2ray.aar and checksums.txt into this tree"
log "  sha256 of the new .aar:          $new_sum"
log "  sha256 checksums.txt had before: ${old_sum:-none}"
if [[ "$new_sum" == "$old_sum" ]]; then
  log "same core as the one checksums.txt recorded"
else
  log "a different core from the one checksums.txt recorded"
fi
