#!/usr/bin/env bash
#
# Refuses when the Android core or the Windows tunnel (windows/core) contains
# code with a known vulnerability, or when a core cannot be checked. Run it
# from anywhere in the repository:
#
#   tool/core_vulncheck.sh             scan, print the result, exit 0 or 1
#   tool/core_vulncheck.sh <folder>    the same, and keep the scan files there
#
# It checks that the committed android/app/libs/libv2ray.aar is the core
# android/core/checksums.txt records, and that it was built with the Go that
# android/core/go.mod pins, which windows/core/go.mod must pin too. Then
# android/core/build-in-linux.sh --vulncheck runs govulncheck in the image
# that builds the core: on the core's source for every ABI the app ships, on
# each libgojni.so, on the Windows tunnel's source for amd64 and arm64, and
# in query mode on each module a go.mod replaces with a folder.
# tool/core_vulncheck.py reads the results with
# android/core/vulncheck-accept.txt. android/core/README.md, "Known
# vulnerabilities", explains what blocks and what to do about it.
#
# Needs Docker and network access: govulncheck reads the live database at
# vuln.go.dev, so a core that passed yesterday can be refused today.
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

readonly AAR=android/app/libs/libv2ray.aar
readonly CORE=android/core

keep=""
if [[ $# -gt 1 ]]; then
  fail "usage: tool/core_vulncheck.sh [folder to keep the scan files in]"
elif [[ $# -eq 1 ]]; then
  mkdir -p "$1"
  keep=$(cd "$1" && pwd)
fi

sha256_of() {
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

[[ -f "$AAR" ]] || fail "no $AAR"
recorded=$(awk '$2=="libv2ray.aar"{print $1}' "$CORE/checksums.txt")
actual=$(sha256_of "$AAR")
[[ -n "$recorded" && "$actual" == "$recorded" ]] || fail "$AAR has sha256 $actual, but $CORE/checksums.txt records ${recorded:-none}.
Commit the .aar and checksums.txt from the same full build ($CORE/build-in-linux.sh)."

pinned=$(awk '$1=="toolchain"{print $2}' "$CORE/go.mod")
built=$(sed -n 's/^# Built with:[[:space:]]*\([^,]*\),.*/\1/p' "$CORE/checksums.txt")
[[ -n "$pinned" && "$built" == "$pinned" ]] || fail "$CORE/checksums.txt says the core was built with ${built:-an unknown Go}, but $CORE/go.mod pins ${pinned:-no toolchain}.
Rebuild the core with $CORE/build-in-linux.sh and commit the .aar with checksums.txt."

windows_pinned=$(awk '$1=="toolchain"{print $2}' windows/core/go.mod)
[[ "$windows_pinned" == "$pinned" ]] || fail "windows/core/go.mod pins ${windows_pinned:-no toolchain}, but $CORE/go.mod pins $pinned.
The two cores must build with the same Go. Move the toolchain line in windows/core/go.mod, then run go test ./... there."

command -v docker >/dev/null || fail "docker not found; the scan runs in the image that builds the core"
docker info >/dev/null 2>&1 || fail "cannot reach the Docker daemon; start Docker (open -a Docker on a Mac) and run this again"
command -v python3 >/dev/null || fail "python3 not found"

if [[ -n "$keep" ]]; then
  out="$keep"
else
  out=$(mktemp -d)
  trap 'rm -rf "$out"' EXIT
fi

echo "Scanning the core for known vulnerabilities (this takes a while)"
"$CORE/build-in-linux.sh" --vulncheck "$out" \
  || fail "the core could not be scanned; see above"

python3 -I tool/core_vulncheck.py "$out" "$CORE/vulncheck-accept.txt"
