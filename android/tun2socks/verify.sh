#!/usr/bin/env bash
#
# Checks the shipped libtun2socks.so binaries against checksums.txt, and
# checks that the 64-bit ones are 16 KB page aligned.
#
# This is not the build script issue #31 asks for. It is the part of that
# issue that can be done without building: the binaries are recorded, so a
# swap shows up as a failure here instead of shipping unnoticed, and the
# alignment that Android 15 requires is asserted rather than assumed.
#
# Alignment matters because an unaligned .so fails at
# System.loadLibrary("tun2socks") at runtime on a 16 KB page device, not at
# build time. Every packet the app tunnels goes through this library, so
# that failure is a total outage for whoever hits it.
#
# Usage:  ./verify.sh
set -euo pipefail

cd "$(dirname "$0")"

readonly LIBS="../app/libs"
readonly ABIS=(arm64-v8a armeabi-v7a x86 x86_64)
# The ABIs Android 15 requires 16 KB alignment from. The 32-bit ones keep
# 4 KB pages and are not subject to it.
readonly ABIS_64=(arm64-v8a x86_64)

fail=0
ok()  { printf '\033[1;32m ok \033[0m %s\n' "$*"; }
bad() { printf '\033[1;31mFAIL\033[0m %s\n' "$*" >&2; fail=1; }

# --- the files are the ones we recorded ------------------------------------
for abi in "${ABIS[@]}"; do
  so="$LIBS/$abi/libtun2socks.so"
  [[ -f "$so" ]] || { bad "$abi: missing $so"; continue; }

  want=$(awk -v a="$abi" '$2 == a { print $1 }' checksums.txt)
  [[ -n "$want" ]] || { bad "$abi: no checksum recorded"; continue; }

  got=$(shasum -a 256 "$so" | cut -d' ' -f1)
  if [[ "$got" == "$want" ]]; then
    ok "$abi: matches checksums.txt"
  else
    bad "$abi: $got does not match the recorded $want"
  fi
done

# --- the 64-bit ones load on a 16 KB page device ---------------------------
#
# Read with the NDK's llvm-readelf where it is available, because the
# system readelf on macOS is not. Skipped rather than failed when neither
# is present: a developer without an NDK should still be able to run the
# checksum half.

# The first LOAD segment's alignment is what the loader honours. Printed
# by any readelf, so the first tool that actually produces a LOAD line for
# a real file wins. Tried rather than picked, because a tool being on PATH
# does not mean it can read an Android .so: an NDK copy on a CI image
# turned out to exit non-zero on these files, and a check that dies on its
# own tooling is worse than one that says which tool it used.
first_load_align() {
  local tool="$1" file="$2" out
  out=$("$tool" -lW "$file" 2>/dev/null) || return 1
  awk '$1 == "LOAD" { print $NF; found = 1; exit } END { exit !found }' <<<"$out"
}

probe="$LIBS/${ABIS_64[0]}/libtun2socks.so"
readelf=""
if [[ -f "$probe" ]]; then
  for candidate in \
    "${ANDROID_NDK_HOME:-}/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf" \
    "${ANDROID_HOME:-$HOME/Library/Android/sdk}"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-readelf \
    llvm-readelf \
    readelf
  do
    command -v "$candidate" >/dev/null 2>&1 || [[ -x "$candidate" ]] || continue
    if first_load_align "$candidate" "$probe" >/dev/null 2>&1; then
      readelf="$candidate"
      break
    fi
  done
fi

if [[ -z "$readelf" ]]; then
  printf '\033[1;33mskip\033[0m no readelf could read the binaries, alignment not checked\n'
else
  printf '     using %s\n' "$readelf"
  for abi in "${ABIS_64[@]}"; do
    so="$LIBS/$abi/libtun2socks.so"
    [[ -f "$so" ]] || continue
    align=$(first_load_align "$readelf" "$so" || echo "unreadable")
    if [[ "$align" == "0x4000" ]]; then
      ok "$abi: 16 KB aligned ($align)"
    else
      bad "$abi: LOAD alignment is $align, not 0x4000; will not load on Android 15"
    fi
  done
fi

exit "$fail"
