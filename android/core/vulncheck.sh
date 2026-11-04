#!/usr/bin/env bash
#
# Scans the core for known vulnerabilities with govulncheck, in the container
# of build-in-linux.sh. Run it with:
#
#   ./build-in-linux.sh --vulncheck <out-dir>
#
# or, from the repository root, tool/core_vulncheck.sh, which also decides
# what the results mean (README.md, "Known vulnerabilities").
#
# It writes these files to $VULNCHECK_OUT and nothing into this tree:
#
#   source-<abi>.json  govulncheck in source mode for one ABI. It follows the
#                      call graph from the packages build.sh binds, so it
#                      tells code the core calls from code it only links.
#   binary-<abi>.json  govulncheck -mode=binary on that ABI's libgojni.so in
#                      the committed .aar. build.sh links with -s, which
#                      removes the symbol table, so this mode sees only
#                      modules and versions. For information only.
#   source-windows-<arch>.json
#                      govulncheck in source mode on the Windows tunnel,
#                      ../../windows/core/cmd/fortiva-core, for amd64 and
#                      arm64, the two builds windows/core/build.sh makes.
#   query-<n>.json     govulncheck -mode=query on one module that this go.mod
#                      or windows/core/go.mod replaces with a folder, at the
#                      version go.mod requires. Source mode cannot see
#                      advisories in such a module.
#   replaced.txt       one line for each of those modules: the file name
#                      query-<n>.json, the module and the version.
#   x509distrust.txt   the output of go test ./x509distrust/, which fails
#                      while the Go in go.mod trusts the eight eMudhra
#                      intermediates, and x509distrust.status: pass or fail.
#   facts.txt          the Go and govulncheck versions, the date of the
#                      vulnerability database and the .aar's sha256.
#
# It exits non-zero only when it cannot scan, or when the committed .aar was
# not built from this source and toolchain. Findings and the test result do
# not change its exit code: tool/core_vulncheck.py reads them.
#
set -euo pipefail

cd "$(dirname "$0")"

# The newest release on 2026-11-04. The module proxy and the checksum
# database check what go install fetches.
readonly GOVULNCHECK_VERSION="v1.9.0"
readonly AAR="../app/libs/libv2ray.aar"
# The packages build.sh binds, in the same order. check_package_list keeps
# the two lists the same.
readonly PACKAGES=(
  github.com/2dust/AndroidLibXrayLite
  github.com/fortiva/fortiva-vpn-mobile/android/core/fortivacore
  github.com/Psiphon-Labs/psiphon-tunnel-core/MobileLibrary/psi
)
readonly ANDROID_API=21
# The Windows tunnel. build-in-linux.sh --vulncheck copies it next to this
# folder, as it is in the repository.
readonly WINDOWS_CORE="../../windows/core"
readonly WINDOWS_PACKAGE="./cmd/fortiva-core"
readonly WINDOWS_ARCHES=(amd64 arm64)

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

sha256_of() {
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

[[ -n "${VULNCHECK_OUT:-}" ]] || die "set VULNCHECK_OUT to the folder for the results"
mkdir -p "$VULNCHECK_OUT"
[[ -f "$AAR" ]] || die "no $AAR to check"
[[ -n "${ANDROID_NDK_HOME:-}" && -d "$ANDROID_NDK_HOME" ]] || die "ANDROID_NDK_HOME is not set to an NDK"
command -v go >/dev/null || die "go not found"
command -v unzip >/dev/null || die "unzip not found"

# --- toolchain ------------------------------------------------------------
# GOTOOLCHAIN=local: scan with the Go this image holds and never fetch
# another one, so the standard library scanned is the one the core links.
toolchain_pin=$(awk '$1=="toolchain"{print $2}' go.mod)
[[ -n "$toolchain_pin" ]] || die "go.mod has no toolchain line"
export GOTOOLCHAIN=local
go_version=$(go env GOVERSION)
[[ "$go_version" == "$toolchain_pin" ]] || die "this Go is $go_version, go.mod pins $toolchain_pin.
Run this through ./build-in-linux.sh --vulncheck, whose image holds the pinned Go."

# The Windows tunnel builds from the same patched Xray-core, with the Go its
# own go.mod pins. This image's Go scans it, and x509distrust tests that Go,
# so the two pins must be the same.
[[ -f "$WINDOWS_CORE/go.mod" ]] || die "no $WINDOWS_CORE/go.mod. Run this through ./build-in-linux.sh --vulncheck, which copies windows/core."
windows_pin=$(awk '$1=="toolchain"{print $2}' "$WINDOWS_CORE/go.mod")
[[ "$windows_pin" == "$toolchain_pin" ]] || die "windows/core/go.mod pins ${windows_pin:-no toolchain}, android/core/go.mod pins $toolchain_pin.
The two cores must build with the same Go. Move the toolchain line in
windows/core/go.mod to $toolchain_pin, then run go test ./... there."
grep -qF "$WINDOWS_PACKAGE" "$WINDOWS_CORE/build.sh" || die "windows/core/build.sh no longer builds $WINDOWS_PACKAGE.
Make WINDOWS_PACKAGE in vulncheck.sh the package it builds."

# --- package list ---------------------------------------------------------
# The packages after `gomobile" bind` in build.sh, with $PSIPHON_MODULE
# filled in. A package bound there and not scanned here would hide its
# findings, so the lists must be the same.
check_package_list() {
  local psiphon_module bound want
  psiphon_module=$(sed -n 's/^readonly PSIPHON_MODULE="\(.*\)"$/\1/p' build.sh)
  [[ -n "$psiphon_module" ]] || die "build.sh no longer sets PSIPHON_MODULE"
  bound=$(awk '/"\$TOOLBIN\/gomobile" bind/ {on=1; next}
               on { line=$0; more = (line ~ /\\$/); sub(/\\$/, "", line)
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", line); gsub(/"/, "", line)
                    if (line != "" && line !~ /^-/) print line
                    if (!more) exit }' build.sh |
          sed "s#\$PSIPHON_MODULE#$psiphon_module#")
  want=$(printf '%s\n' "${PACKAGES[@]}")
  [[ "$bound" == "$want" ]] || die "build.sh binds other packages than this script scans.
build.sh binds:
$(printf '%s\n' "$bound" | sed 's/^/  /')
this script scans:
$(printf '%s\n' "$want" | sed 's/^/  /')
Make PACKAGES in vulncheck.sh the same list."
}
check_package_list

# --- source ---------------------------------------------------------------
export GOFLAGS="-mod=readonly"
./stage-xray.sh
./stage-psiphon.sh

# --- govulncheck ----------------------------------------------------------
# Built into .bin/ from the module proxy. Not added to go.mod, which would
# move the core's module graph, and not to Dockerfile, whose sha256
# checksums.txt records.
install_govulncheck() {
  log "installing govulncheck $GOVULNCHECK_VERSION into .bin/"
  mkdir -p .bin
  GOFLAGS= CGO_ENABLED=0 GOBIN="$PWD/.bin" \
    go install "golang.org/x/vuln/cmd/govulncheck@$GOVULNCHECK_VERSION"
  local got
  got=$(go version -m .bin/govulncheck | awk '$1=="mod" && $2=="golang.org/x/vuln" {print $3}')
  [[ "$got" == "$GOVULNCHECK_VERSION" ]] || die "installed govulncheck is ${got:-unknown}, not $GOVULNCHECK_VERSION"
}
install_govulncheck
readonly GOVULNCHECK="$PWD/.bin/govulncheck"

# --- the committed .aar ---------------------------------------------------
# The source scan says something about the shipped core only if the .aar was
# built from this source. So each libgojni.so must be built by the pinned Go,
# and link every module that is not replaced at the version go.mod resolves.
# This is check 5 of build.sh, copied here: build.sh runs it on the .aar it
# has just built, this script on the .aar that is committed.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
unzip -q "$AAR" -d "$work/aar"
go list -m -f '{{.Path}} {{.Version}}' all > "$work/modules.txt"

check_aar_buildinfo() {
  local abi=$1 so=$2 linked_go
  go version -m "$so" > "$work/$abi.buildinfo"
  linked_go=$(awk 'NR==1{print $NF; exit}' "$work/$abi.buildinfo")
  [[ "$linked_go" == "$toolchain_pin" ]] || die "$abi libgojni.so in the committed .aar was built by $linked_go, go.mod pins $toolchain_pin.
Rebuild the core with ./build-in-linux.sh and commit the .aar with checksums.txt."
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
    die "$abi libgojni.so in the committed .aar was not built from this go.mod:
$(cat "$work/$abi.versions")
Rebuild the core with ./build-in-linux.sh and commit the .aar with checksums.txt."
}

# --- scans ----------------------------------------------------------------
# The settings gomobile builds each ABI with: GOOS=android, cgo with the
# NDK's clang for that ABI and API level, GOARM=7 on 32-bit ARM, no tags.
readonly CLANG_DIR="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"

scan_source() {
  local abi=$1 goarch=$2 clang=$3 goarm=${4:-}
  [[ -x "$CLANG_DIR/$clang" ]] || die "no $clang in the NDK"
  log "govulncheck, source mode: $abi"
  env GOOS=android GOARCH="$goarch" ${goarm:+GOARM="$goarm"} \
      CGO_ENABLED=1 CC="$CLANG_DIR/$clang" \
      "$GOVULNCHECK" -format json "${PACKAGES[@]}" > "$VULNCHECK_OUT/source-$abi.json" || \
    die "govulncheck could not scan the source for $abi"
}

scan_binary() {
  local abi=$1 so=$2
  log "govulncheck, binary mode: $abi"
  "$GOVULNCHECK" -mode=binary -format json "$so" > "$VULNCHECK_OUT/binary-$abi.json" || \
    die "govulncheck could not scan $abi libgojni.so"
}

# abi goarch clang [goarm]
readonly TARGETS=(
  "arm64-v8a arm64 aarch64-linux-android${ANDROID_API}-clang"
  "armeabi-v7a arm armv7a-linux-androideabi${ANDROID_API}-clang 7"
  "x86_64 amd64 x86_64-linux-android${ANDROID_API}-clang"
  "x86 386 i686-linux-android${ANDROID_API}-clang"
)
for t in "${TARGETS[@]}"; do
  read -r abi goarch clang goarm <<<"$t"
  so="$work/aar/jni/$abi/libgojni.so"
  [[ -f "$so" ]] || die "the committed .aar has no libgojni.so for $abi"
  check_aar_buildinfo "$abi" "$so"
  scan_source "$abi" "$goarch" "$clang" "$goarm"
  scan_binary "$abi" "$so"
done
abis=$(ls "$work/aar/jni")
[[ $(printf '%s\n' "$abis" | wc -l) -eq ${#TARGETS[@]} ]] || die "the committed .aar has other ABIs than this script scans: $(echo $abis)"

# --- the Windows tunnel ---------------------------------------------------
# windows/core/build.sh builds $WINDOWS_PACKAGE with CGO_ENABLED=0 and no
# tags. No Windows build is committed, so there is no binary to scan.
scan_windows() {
  local arch=$1
  log "govulncheck, source mode: windows/$arch"
  (cd "$WINDOWS_CORE" && env GOOS=windows GOARCH="$arch" CGO_ENABLED=0 \
      "$GOVULNCHECK" -format json "$WINDOWS_PACKAGE") > "$VULNCHECK_OUT/source-windows-$arch.json" || \
    die "govulncheck could not scan the Windows core for $arch"
}
for arch in "${WINDOWS_ARCHES[@]}"; do
  scan_windows "$arch"
done

# --- modules replaced by a folder -----------------------------------------
# go.mod replaces Xray-core and Psiphon's quic-go fork with the patched trees
# in .src/, and windows/core/go.mod replaces Xray-core with the same tree.
# govulncheck looks such a module up under the folder's path, and has no
# version for it, so a source scan never reports an advisory in it. Query
# mode looks each one up at the version go.mod requires, which is the base
# the stage scripts patch. It cannot see calls, so tool/core_vulncheck.py
# blocks on every advisory it lists.
replaced_in() {
  (cd "$1" && go list -m -f '{{if .Replace}}{{if not .Replace.Version}}{{.Path}} {{.Version}}{{end}}{{end}}' all)
}
android_replaced=$(replaced_in .) || die "go list cannot read the replaced modules of android/core/go.mod"
windows_replaced=$(replaced_in "$WINDOWS_CORE") || die "go list cannot read the replaced modules of windows/core/go.mod"
: > "$VULNCHECK_OUT/replaced.txt"
n=0
while read -r mod ver; do
  [[ -n "$mod" ]] || continue
  [[ -n "$ver" ]] || die "a go.mod replaces $mod with a folder but requires no version of it"
  n=$((n + 1))
  log "govulncheck, query mode: $mod@$ver"
  "$GOVULNCHECK" -mode=query -format json "$mod@$ver" > "$VULNCHECK_OUT/query-$n.json" || \
    die "govulncheck could not look up $mod@$ver"
  echo "query-$n.json $mod $ver" >> "$VULNCHECK_OUT/replaced.txt"
done < <(printf '%s\n%s\n' "$android_replaced" "$windows_replaced" | awk NF | sort -u)

# --- the eMudhra distrust -------------------------------------------------
log "go test ./x509distrust/"
if CGO_ENABLED=0 go test -count=1 ./x509distrust/ > "$VULNCHECK_OUT/x509distrust.txt" 2>&1; then
  echo pass > "$VULNCHECK_OUT/x509distrust.status"
else
  echo fail > "$VULNCHECK_OUT/x509distrust.status"
fi
cat "$VULNCHECK_OUT/x509distrust.txt"

# --- facts ----------------------------------------------------------------
db_modified=$(sed -n 's/^[[:space:]]*"db_last_modified": "\(.*\)",\{0,1\}$/\1/p' "$VULNCHECK_OUT/source-arm64-v8a.json" | head -1)
{
  echo "go: $go_version"
  echo "govulncheck: $GOVULNCHECK_VERSION"
  echo "database modified: ${db_modified:-unknown}"
  echo "aar sha256: $(sha256_of "$AAR")"
  echo "packages: ${PACKAGES[*]}"
  echo "windows: $WINDOWS_PACKAGE for ${WINDOWS_ARCHES[*]}"
} > "$VULNCHECK_OUT/facts.txt"
log "done; results in $VULNCHECK_OUT"
