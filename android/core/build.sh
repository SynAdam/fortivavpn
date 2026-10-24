#!/usr/bin/env bash
#
# Builds android/app/libs/libv2ray.aar from the pinned sources in go.mod.
#
# The .aar this produces is the VPN core: Xray-core with the patches in
# patches/, wrapped by 2dust's AndroidLibXrayLite and our own fortivacore
# package, plus Psiphon's MobileLibrary/psi package (psiphon-tunnel-core), all
# bound to Java via gomobile into one libgojni.so. Everything it contains is
# pinned by go.mod + go.sum, stage-xray.sh, stage-psiphon.sh and the patch
# files. The core the app ships is built by build-in-linux.sh, which runs
# this script in /build/fortiva-core inside a linux/amd64 container whose
# toolchain Dockerfile pins. Two people who do that on the same commit get
# the same bytes and can compare the sha256 with checksums.txt.
#
# Usage:  ./build-in-linux.sh   build every shipped ABI, the way it ships
#         ./build.sh            the same, but only in /build/fortiva-core
#         ./build.sh arm64      build one ABI (fast, for local iteration)
#
set -euo pipefail

cd "$(dirname "$0")"

# Keep in lockstep with android/app/build.gradle.kts `ndkVersion`. A mismatch
# silently produces a core linked against different platform headers than the
# rest of the app.
readonly REQUIRED_NDK="28.2.13676358"
# gomobile refuses anything lower; also the app's effective floor.
readonly ANDROID_API=21
readonly OUT="../app/libs/libv2ray.aar"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# --- build folder ---------------------------------------------------------
# gomobile writes the absolute path of this folder into each libgojni.so. The
# build info replaces this module and the two in .src/ by their directories,
# `go version -m` prints them, and -trimpath does not remove them. A build in
# a home folder would put the builder's account name into every APK and into
# the public copy of the source, which carries the .aar, and a build in any
# other folder of a machine would name that machine's layout. So a full
# build runs only in /build/fortiva-core, the folder build-in-linux.sh builds
# in, and no build runs in a home folder.
# Check 6 below reads the built .so files for the same thing.
readonly NEUTRAL_DIR="/build/fortiva-core"
home_real=""
if [[ -n "${HOME:-}" && -d "$HOME" ]]; then
  home_real=$(cd "$HOME" && pwd -P)
fi
# True when $1 is inside $HOME, or inside an account's home folder:
# /Users/<name> other than /Users/Shared, or /home/<name>. macOS paths are
# case-insensitive, so the match is too.
in_home_folder() {
  local p="$1/" h found=1
  shopt -s nocasematch
  for h in "${HOME:-}" "$home_real"; do
    if [[ -n "$h" && "$h" != "/" && "$p" == "${h%/}/"* ]]; then
      found=0
    fi
  done
  if [[ $found -ne 0 ]]; then
    case "$p" in
      /Users/Shared/*) ;;
      /Users/?*/*|/home/?*/*) found=0 ;;
    esac
  fi
  shopt -u nocasematch
  return $found
}
build_dir=$(pwd -P)
if in_home_folder "$build_dir"; then
  die "$build_dir is inside a home folder.
gomobile writes the absolute build folder into each libgojni.so, so the core
would carry that account name. Build the core with ./build-in-linux.sh,
which builds it in $NEUTRAL_DIR inside a container. A one-ABI build
for local iteration runs in any folder whose path names no one."
fi

# --- toolchain ------------------------------------------------------------
command -v go >/dev/null || die "go not found"

go_version=$(go env GOVERSION)
required_go=$(awk '/^go /{print "go"$2; exit}' go.mod)
# go.mod says go1.26.0 (Psiphon requires the patch number), and any go1.26.x
# toolchain builds it, so compare the language version only: go1.26.
required_lang=$(printf '%s' "$required_go" | cut -d. -f1-2)
case "$go_version" in
  "$required_lang"|"$required_lang".*) ;;
  *) log "warning: building with $go_version, go.mod declares $required_go" ;;
esac

ndk_root="${ANDROID_NDK_HOME:-}"
if [[ -z "$ndk_root" ]]; then
  sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
  ndk_root="$sdk/ndk/$REQUIRED_NDK"
fi
[[ -d "$ndk_root" ]] || die "NDK $REQUIRED_NDK not found at $ndk_root
Install it, or set ANDROID_NDK_HOME to a $REQUIRED_NDK checkout."
if [[ "$(basename "$ndk_root")" != "$REQUIRED_NDK" ]]; then
  log "warning: NDK at $ndk_root is not the pinned $REQUIRED_NDK"
fi
export ANDROID_NDK_HOME="$ndk_root"

# --- targets --------------------------------------------------------------
# Must stay a superset of the ABIs in android/app/libs/*/libtun2socks.so,
# otherwise the app ships a tun2socks for an ABI that has no core.
# Written without associative arrays on purpose: /bin/bash on macOS is still
# 3.2, and `declare -A` would fail there with an unhelpful syntax error.
readonly ALL_TARGETS="android/arm64,android/arm,android/amd64,android/386"
if [[ $# -gt 0 ]]; then
  case "$1" in
    arm64) targets=android/arm64 ;;
    arm)   targets=android/arm ;;
    amd64) targets=android/amd64 ;;
    386)   targets=android/386 ;;
    *)     die "unknown ABI '$1' (want: arm64, arm, amd64, 386)" ;;
  esac
  log "single-ABI build: $1 (NOT shippable - use a full build to release)"
else
  targets="$ALL_TARGETS"
  # A full build writes the .aar the app ships. It carries this folder, so
  # it is built in one folder only, the one build-in-linux.sh uses.
  if [[ "$build_dir" != "$NEUTRAL_DIR/android/core" ]]; then
    die "a full build runs only in $NEUTRAL_DIR/android/core, not in $build_dir.
gomobile writes the absolute build folder into each libgojni.so, and the
core the app ships is built in that folder, in a Linux container:
  ./build-in-linux.sh
For local iteration, build one ABI in any folder whose path names no one:
  ./build.sh arm64"
  fi
fi

# --- build ----------------------------------------------------------------
# -mod=readonly: fail rather than silently rewrite the pins.
# -trimpath + -buildid=: strip absolute paths and the build id so the output is
#   reproducible. Without -trimpath the builder's home directory is baked into
#   the binary, which is exactly how the previous vendored .aar ended up
#   carrying a path in a developer's home folder. It does not cover the
#   module list in the build info: gomobile replaces this module and the two
#   in .src/ by their absolute paths, and `go version -m` on a libgojni.so
#   still shows them. The folder checks above refuse a home folder, and a
#   full build anywhere but /build/fortiva-core.
# -checklinkname=0: xray-core pulls in wlynxg/anet, which reaches into
#   net.zoneCache via //go:linkname to read interface names on Android without
#   the JVM. Go 1.23+ rejects that by default; upstream v2rayNG passes the same
#   flag. Revisit if anet ever stops needing it.
export GOFLAGS="-mod=readonly"
export CGO_ENABLED=1

# gomobile shells out to `go build` inside its own generated module, which does
# NOT inherit the `toolchain` directive from our go.mod. Without forcing
# GOTOOLCHAIN here the core silently links whatever Go is on PATH - which is
# how a build can keep shipping a stdlib with known advisories even after the
# directive is bumped. Single source of truth stays go.mod.
toolchain_pin=$(awk '$1=="toolchain"{print $2}' go.mod)
if [[ -n "$toolchain_pin" ]]; then
  export GOTOOLCHAIN="$toolchain_pin"
  log "forcing GOTOOLCHAIN=$GOTOOLCHAIN"
fi

# go.mod replaces xray-core with .src/xray-core, the pinned source plus our
# patches, and Psiphon's quic-go fork with .src/psiphon-quic-go, the same for
# patches/psiphon-quic-go/. Nothing below resolves until both exist.
./stage-xray.sh
./stage-psiphon.sh

# --- Psiphon ----------------------------------------------------------------
# psiphon-tunnel-core is pinned by commit (README.md, "Psiphon"). Its
# pseudo-version ends in the commit's first 12 hex digits. Psiphon sends
# buildRev to its servers as client_build_rev; its own build sets it to the
# first 10 (`git rev-parse --short=10`), so this does the same. buildDate is
# left empty on purpose: a date would make every build differ.
readonly PSIPHON_MODULE="github.com/Psiphon-Labs/psiphon-tunnel-core"
psiphon_version=$(awk -v m="$PSIPHON_MODULE" '$1==m && $2 ~ /^v/ {print $2; exit}' go.mod)
[[ -n "$psiphon_version" ]] || die "go.mod does not require $PSIPHON_MODULE"
psiphon_commit=${psiphon_version##*-}
[[ "$psiphon_commit" =~ ^[0-9a-f]{12}$ ]] || \
  die "$PSIPHON_MODULE $psiphon_version is not a commit pseudo-version"
psiphon_build_rev=${psiphon_commit:0:10}
# The linker ignores -X for a variable that does not exist, so check that
# upstream still has it before relying on it.
go mod download "$PSIPHON_MODULE"
psiphon_dir=$(go list -m -f '{{.Dir}}' "$PSIPHON_MODULE")
[[ -d "$psiphon_dir" ]] || die "no source directory for $PSIPHON_MODULE $psiphon_version"
grep -q '^var buildRev string' "$psiphon_dir/psiphon/common/buildinfo/buildinfo.go" || \
  die "$PSIPHON_MODULE no longer has psiphon/common/buildinfo.buildRev"
readonly PSIPHON_LDFLAG="-X $PSIPHON_MODULE/psiphon/common/buildinfo.buildRev=$psiphon_build_rev"

# gomobile shells out to `gobind`, so both have to be on PATH at the versions
# go.mod pins - not whatever a previous `go install` left in ~/go/bin. Building
# them into ./.bin keeps the toolchain hermetic and disposable. They are
# built without cgo: the only cgo package they link is net's resolver, which
# they do not use, and a Linux host would otherwise need its own C compiler
# for them. gomobile sets CGO_ENABLED=1 itself for each Android build.
readonly TOOLBIN="$PWD/.bin"
log "staging pinned gomobile toolchain in .bin/"
mkdir -p "$TOOLBIN"
CGO_ENABLED=0 GOBIN="$TOOLBIN" go install \
  golang.org/x/mobile/cmd/gobind \
  golang.org/x/mobile/cmd/gomobile
export PATH="$TOOLBIN:$PATH"

log "gomobile bind -> $OUT"
log "  targets:    $targets"
log "  androidapi: $ANDROID_API"
log "  ndk:        $ANDROID_NDK_HOME"
log "  psiphon:    $psiphon_version (buildRev $psiphon_build_rev)"

mkdir -p "$(dirname "$OUT")"
"$TOOLBIN/gomobile" bind \
  -target="$targets" \
  -androidapi "$ANDROID_API" \
  -trimpath \
  -ldflags="-s -w -buildid= -checklinkname=0 $PSIPHON_LDFLAG" \
  -o "$OUT" \
  github.com/2dust/AndroidLibXrayLite \
  github.com/fortiva/fortiva-vpn-mobile/android/core/fortivacore \
  "$PSIPHON_MODULE/MobileLibrary/psi"

[[ -f "$OUT" ]] || die "gomobile reported success but produced no .aar"

# --- verify ---------------------------------------------------------------
# These checks exist because every one of them has a failure mode that shows up
# at runtime on a user's phone rather than at build time.
#
# Note: each check materialises its input before grepping. Piping straight into
# `grep -q` under `set -o pipefail` fails spuriously - grep exits on the first
# match, the writer takes SIGPIPE, and pipefail reports the whole pipeline as
# failed.
log "verifying output"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
unzip -q "$OUT" -d "$work"

# 1. The Java API the Kotlin layer binds against must exist. A rename upstream
#    turns into a NoSuchMethodError on connect, not a compile error, because
#    the .aar is a prebuilt binary.
unzip -l "$work/classes.jar" > "$work/classes.list"
for cls in libv2ray/Libv2ray.class libv2ray/CoreController.class \
           libv2ray/CoreCallbackHandler.class \
           fortivacore/Fortivacore.class \
           psi/Psi.class psi/PsiphonProvider.class; do
  grep -qF "$cls" "$work/classes.list" || die "missing $cls in classes.jar"
done

# 2. Routing data must be bundled. SettingsManager.initAssets() copies these out
#    of the APK on first run; without them every geoip:/geosite: rule in a
#    generated config silently matches nothing.
for dat in assets/geoip.dat assets/geosite.dat; do
  [[ -s "$work/$dat" ]] || die "missing $dat - routing rules would not resolve"
done

# 3. REALITY and XTLS-Vision must actually be compiled in. The core this
#    replaced was v2ray-core, which implements neither, while the Kotlin layer
#    has always generated configs asking for both - so the app negotiated plain
#    TLS while believing it had REALITY camouflage.
for abi_dir in "$work"/jni/*/; do
  abi=$(basename "$abi_dir")
  so="$abi_dir/libgojni.so"
  [[ -f "$so" ]] || die "no libgojni.so for $abi"
  strings -a "$so" > "$work/$abi.strings"
  for feature in realitySettings xtls-rprx-vision; do
    grep -qF -- "$feature" "$work/$abi.strings" || \
      die "$abi: core has no '$feature' support"
  done
  # The autoselect outbound comes from patches/xray-autoselect.patch. A core
  # built without it rejects every config that names the group, at connect.
  grep -qF -- "xray.proxy.autoselect" "$work/$abi.strings" || \
    die "$abi: core has no autoselect outbound - was the patch applied?"
done

# 4. Android 15+ requires 16 KB-aligned segments. An unaligned .so fails at
#    System.loadLibrary(), at runtime, on exactly the newest devices.
# macOS has no readelf; the NDK ships llvm-readelf, which is the same tool and
# is already a hard dependency of this script.
readelf_bin=$(command -v readelf || true)
if [[ -z "$readelf_bin" ]]; then
  readelf_bin=$(ls "$ANDROID_NDK_HOME"/toolchains/llvm/prebuilt/*/bin/llvm-readelf 2>/dev/null | head -1 || true)
fi
[[ -n "$readelf_bin" ]] || die "no readelf/llvm-readelf found; cannot verify page alignment"

for abi_dir in "$work"/jni/*/; do
  abi=$(basename "$abi_dir")
  # 32-bit ABIs are not subject to the 16 KB requirement.
  [[ "$abi" == "arm64-v8a" || "$abi" == "x86_64" ]] || continue
  "$readelf_bin" -lW "$abi_dir/libgojni.so" > "$work/$abi.elf"
  align=$(awk '/LOAD/{print $NF; exit}' "$work/$abi.elf")
  [[ "$align" == "0x4000" ]] || \
    die "$abi libgojni.so is $align-aligned, Android 15+ needs 0x4000"
done

# 5. Each .so must link the Psiphon that go.mod pins and our patched copy of
#    Psiphon's quic-go fork, and be built by the Go that go.mod pins. The
#    build info Go writes into every binary says what was linked, so read it.
#    Every other linked module must also be at the version go.mod resolves.
#    gomobile builds in a module of its own that requires every module in our
#    graph directly, so Go's graph pruning does not apply there, and a module
#    can come out newer than go.mod says (syndtr/gocapability did, through
#    runc). A replaced module is skipped, because its line shows the version
#    it replaces and not what was built: our own module, Xray-core (checked
#    by stage-xray.sh and check 3) and Psiphon's quic-go fork (checked here).
go list -m -f '{{.Path}} {{.Version}}' all > "$work/modules.txt"
for abi_dir in "$work"/jni/*/; do
  abi=$(basename "$abi_dir")
  go version -m "$abi_dir/libgojni.so" > "$work/$abi.buildinfo"
  linked_go=$(awk 'NR==1{print $NF; exit}' "$work/$abi.buildinfo")
  [[ -z "$toolchain_pin" || "$linked_go" == "$toolchain_pin" ]] || \
    die "$abi libgojni.so was built by $linked_go, go.mod pins $toolchain_pin"
  awk -v m="$PSIPHON_MODULE" -v v="$psiphon_version" \
    '$1=="dep" && $2==m && $3==v {ok=1} END{exit !ok}' "$work/$abi.buildinfo" || \
    die "$abi libgojni.so does not link $PSIPHON_MODULE $psiphon_version"
  awk '$1=="dep" && $2=="github.com/Psiphon-Labs/quic-go" {
         if ((getline nxt) > 0) { split(nxt, f, "\t"); if (f[2]=="=>" && f[3] ~ /\/\.src\/psiphon-quic-go$/) ok=1 }
       } END{exit !ok}' "$work/$abi.buildinfo" || \
    die "$abi libgojni.so does not use the patched Psiphon-Labs/quic-go from .src/psiphon-quic-go"
  awk 'NR==FNR { want[$1] = $2; next }
       $1=="dep" { n++; path[n] = $2; ver[n] = $3; next }
       $1=="=>"  { replaced[n] = 1; next }
       END {
         bad = 0
         for (i = 1; i <= n; i++) {
           if (replaced[i]) continue
           if (!(path[i] in want)) {
             printf "  %s %s is linked, but go.mod has no such module\n", path[i], ver[i]; bad = 1
           } else if (want[path[i]] != ver[i]) {
             printf "  %s is linked at %s, go.mod resolves %s\n", path[i], ver[i], want[path[i]]; bad = 1
           }
         }
         exit bad
       }' "$work/modules.txt" "$work/$abi.buildinfo" > "$work/$abi.versions" || \
    die "$abi libgojni.so links modules at versions go.mod does not pin:
$(cat "$work/$abi.versions")
Pin each one with: GOFLAGS= go get <module>@<linked version> && GOFLAGS= go mod tidy"
done

# 6. No home folder in any .so: not $HOME, not /Users/<name> other than
#    /Users/Shared, not /home/<name>. The folder checks at the top keep the
#    build folder out of the build info. This also catches a home folder that
#    anything else writes into the binary, and the .so ships in every APK.
#    A full build, the one that ships, must also name no Mac folder at all
#    (/Users/Shared included), and every folder its build info names must be
#    inside /build/fortiva-core.
for abi_dir in "$work"/jni/*/; do
  abi=$(basename "$abi_dir")
  {
    if [[ "$targets" == "$ALL_TARGETS" ]]; then
      grep -oE '/(Users|home)/[^/[:space:]]+' "$work/$abi.strings" || true
      awk -F'\t' -v d="$NEUTRAL_DIR/" '$2=="=>" && index($3, d) != 1 {print $3}' \
        "$work/$abi.buildinfo"
    else
      grep -oE '/(Users|home)/[^/[:space:]]+' "$work/$abi.strings" | grep -vx '/Users/Shared' || true
    fi
    for h in "${HOME:-}" "$home_real"; do
      if [[ -n "$h" && "$h" != "/" ]]; then
        grep -oiF -- "${h%/}/" "$work/$abi.strings" || true
      fi
    done
  } | sed 's#/$##' | sort -u > "$work/$abi.homes"
  [[ ! -s "$work/$abi.homes" ]] || die "$abi libgojni.so names a folder of the machine that built it:
$(sed 's/^/  /' "$work/$abi.homes")
gomobile writes the absolute build folder into each libgojni.so. Build the
core with ./build-in-linux.sh, which builds it in $NEUTRAL_DIR."
done

# --- record ---------------------------------------------------------------
# Only a full build writes checksums.txt. A one-ABI .aar cannot ship, so it
# leaves the file as it was. Its sha256 then differs from the one recorded
# there, and the checksum audit refuses it if it is committed.
if [[ "$targets" != "$ALL_TARGETS" ]]; then
  log "done (one ABI: checksums.txt left as it was, this .aar is not shippable)"
  shasum -a 256 "$OUT"
  ls -lh "$OUT"
  exit 0
fi
{
  echo "# Generated by android/core/build.sh - do not edit by hand."
  echo "# Regenerate with a full (all-ABI) build."
  echo "#"
  echo "# AndroidLibXrayLite: $(awk '$1=="github.com/2dust/AndroidLibXrayLite"{print $2}' go.mod)"
  echo "# Xray-core:          $(awk '$1=="github.com/xtls/xray-core"{print $2}' go.mod)"
  for p in patches/*.patch; do
    echo "# Patch:              $(basename "$p") sha256 $(shasum -a 256 "$p" | cut -d' ' -f1)"
  done
  echo "# Psiphon:            $psiphon_version (commit $psiphon_commit, buildRev $psiphon_build_rev)"
  echo "# Psiphon quic-go:    $(awk '$1=="github.com/Psiphon-Labs/quic-go" && $2 ~ /^v/ {print $2; exit}' go.mod)"
  for p in patches/psiphon-quic-go/*.patch; do
    echo "# Patch:              psiphon-quic-go/$(basename "$p") sha256 $(shasum -a 256 "$p" | cut -d' ' -f1)"
  done
  echo "# Built with:         $(GOTOOLCHAIN=${toolchain_pin:-local} go env GOVERSION), NDK $REQUIRED_NDK, androidapi $ANDROID_API, $(javac -version 2>&1)"
  # build-in-linux.sh sets CORE_BUILD_CONTAINER to its own name and the
  # sha256 of the Dockerfile the image was built from.
  echo "# Built in:           ${build_dir%/android/core}, $(uname -s) $(uname -m)"
  if [[ -n "${CORE_BUILD_CONTAINER:-}" ]]; then
    echo "#                     in a container: $CORE_BUILD_CONTAINER"
  else
    echo "#                     not in the container of build-in-linux.sh"
  fi
  echo
  shasum -a 256 "$OUT" | sed 's#\.\./app/libs/##'
} > checksums.txt

log "done"
shasum -a 256 "$OUT"
ls -lh "$OUT"
