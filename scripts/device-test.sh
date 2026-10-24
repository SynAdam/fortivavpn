#!/usr/bin/env bash
#
# End-to-end tunnel test against a connected Android device or emulator.
#
# Builds, installs, connects to a real server and asserts that traffic
# actually moves. Written because the core is a prebuilt binary: a binding
# change compiles cleanly and fails the moment a user taps Connect, so
# static checks cannot cover it. See issue #32.
#
# Usage:
#   scripts/device-test.sh                 # build, install, run every check
#   scripts/device-test.sh --no-build      # reuse the installed APK
#   scripts/device-test.sh --keep          # leave the VPN up at the end
#   SERIAL=emulator-5554 scripts/device-test.sh
#
# Exits non-zero if any check fails. Full logcat is left in the run
# directory, which is printed at the end.

set -uo pipefail

PKG=com.vpn.fortivavpn
ACTIVITY="$PKG/.MainActivity"
BUILD=1
KEEP=0

for arg in "$@"; do
  case "$arg" in
    --no-build) BUILD=0 ;;
    --keep) KEEP=1 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

cd "$(dirname "$0")/.."
RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/fortiva-devicetest.XXXXXX")"
LOG="$RUN_DIR/logcat.txt"

PASS=0
FAIL=0
declare -a FAILURES=()

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()   { PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m  %s\n' "$*"; }
bad()  { FAIL=$((FAIL+1)); FAILURES+=("$1"); printf '  \033[31mFAIL\033[0m  %s\n' "$1"; [ $# -gt 1 ] && printf '        %s\n' "$2"; }
info() { printf '        %s\n' "$*"; }

# ---------------------------------------------------------------- device

if [ -z "${SERIAL:-}" ]; then
  SERIAL="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
fi
if [ -z "$SERIAL" ]; then
  echo "No device. Plug one in with USB debugging on, or start an emulator." >&2
  exit 1
fi
adb() { command adb -s "$SERIAL" "$@"; }

say "Device"
ABI="$(adb shell getprop ro.product.cpu.abi | tr -d '\r')"
REL="$(adb shell getprop ro.build.version.release | tr -d '\r')"
PAGE="$(adb shell getconf PAGE_SIZE 2>/dev/null | tr -d '\r')"
info "$SERIAL  Android $REL  $ABI  page size ${PAGE:-unknown}"
[ "${PAGE:-4096}" = "16384" ] && info "16 KB page size: the loadLibrary path this build must survive"

# ---------------------------------------------------------------- install

if [ "$BUILD" = 1 ]; then
  say "Build and install"
  if flutter build apk --debug > "$RUN_DIR/build.txt" 2>&1; then
    ok "debug APK built"
  else
    bad "debug APK build failed" "see $RUN_DIR/build.txt"
    tail -20 "$RUN_DIR/build.txt"
    exit 1
  fi
  adb install -r -d build/app/outputs/flutter-apk/app-debug.apk > "$RUN_DIR/install.txt" 2>&1 \
    && ok "installed" || { bad "install failed" "see $RUN_DIR/install.txt"; exit 1; }
fi

APK_PATH="$(adb shell pm path $PKG | sed 's/package://;s|/base.apk||' | tr -d '\r')"
if [ -z "$APK_PATH" ]; then bad "package not installed"; exit 1; fi

# ------------------------------------------------------- native libraries

say "Native libraries"
LIBDIR="$APK_PATH/lib/$(echo "$ABI" | cut -d- -f1)"
for lib in libgojni.so libtun2socks.so; do
  if adb shell "ls $LIBDIR/$lib" >/dev/null 2>&1; then
    SIZE="$(adb shell "stat -c %s $LIBDIR/$lib" 2>/dev/null | tr -d '\r')"
    ok "$lib present for $ABI (${SIZE:-?} bytes)"
  else
    bad "$lib missing for $ABI" "the tunnel cannot start without it"
  fi
done

# Android 15+ can require 16 KB page alignment on 64-bit. A misaligned .so
# fails at System.loadLibrary on a real device and nowhere else, so check
# what actually shipped rather than trusting the build.
if [ "${ABI#arm64}" != "$ABI" ] || [ "${ABI#x86_64}" != "$ABI" ]; then
  READELF="$(ls "$HOME/Library/Android/sdk/ndk/"*/toolchains/llvm/prebuilt/*/bin/llvm-readelf 2>/dev/null | head -1)"
  APK=build/app/outputs/flutter-apk/app-debug.apk
  if [ -n "$READELF" ] && [ -f "$APK" ]; then
    EXTRACT="$RUN_DIR/apk"
    for so in libgojni.so libtun2socks.so; do
      unzip -o -q -d "$EXTRACT" "$APK" "lib/$ABI/$so" 2>/dev/null
      ALIGN="$("$READELF" -l "$EXTRACT/lib/$ABI/$so" 2>/dev/null | awk '/LOAD/{print $NF; exit}')"
      case "$ALIGN" in
        0x4000|0x10000) ok "$so first LOAD aligned $ALIGN, 16 KB safe" ;;
        "") info "could not read alignment for $so" ;;
        *) bad "$so first LOAD aligned $ALIGN" "fails System.loadLibrary on a 16 KB device" ;;
      esac
    done
  else
    info "llvm-readelf or APK unavailable, skipping alignment check"
  fi
fi

# ------------------------------------------------------------------ start

say "Launch"
adb shell appops set $PKG ACTIVATE_VPN allow >/dev/null 2>&1
adb shell appops set $PKG ACTIVATE_PLATFORM_VPN allow >/dev/null 2>&1
info "VPN consent granted via appops (no dialog to tap)"

adb shell am force-stop $PKG >/dev/null 2>&1
adb logcat -c >/dev/null 2>&1
adb logcat -v time > "$LOG" 2>&1 &
LOGCAT_PID=$!
trap 'kill $LOGCAT_PID 2>/dev/null' EXIT

adb shell am start -n "$ACTIVITY" >/dev/null 2>&1

# Wait for a line logcat only prints once the server list has loaded and a
# server is selected. Tapping before that silently does nothing:
# startVServiceFromToggle returns false when getSelectServer() is empty,
# which is exactly what a fixed sleep walks into on a cold start after an
# install.
wait_for_log() {
  local pattern="$1" timeout="${2:-60}" i=0
  while [ "$i" -lt "$timeout" ]; do
    grep -q "$pattern" "$LOG" 2>/dev/null && return 0
    sleep 1; i=$((i+1))
  done
  return 1
}

if wait_for_log 'realPing result' 60; then
  info "server list loaded and pinged"
else
  info "no ping seen in 60s; continuing anyway"
fi
sleep 2

# Android words this line differently per release: 15 says "using ns clns-7
# from class loader", 16 says "using class loader ns clns-9". Match on the
# library and the result, not on the phrasing in between.
if grep -E 'nativeloader.*libgojni\.so.*: ok' "$LOG" >/dev/null 2>&1; then
  ok "libgojni.so loaded by the runtime"
elif grep -qE 'Xray [0-9.]+ started' "$LOG"; then
  ok "core started, so libgojni.so loaded ($(grep -oE 'Xray [0-9.]+ started' "$LOG" | head -1))"
else
  bad "libgojni.so did not load" "UnsatisfiedLinkError is the usual cause; check page alignment"
fi

# ------------------------------------------------------------ geo assets

say "Geo databases (issue #38)"
ASSET_DIR="/sdcard/Android/data/$PKG/files/assets"
GEO_OK=1
for dat in geoip.dat geosite.dat; do
  SZ="$(adb shell "stat -c %s $ASSET_DIR/$dat 2>/dev/null" | tr -d '\r')"
  if [ -n "$SZ" ] && [ "$SZ" -gt 0 ] 2>/dev/null; then
    ok "$dat staged where the core reads ($SZ bytes)"
  else
    bad "$dat not staged in $ASSET_DIR" "initAssets did not run before initCoreEnv"
    GEO_OK=0
  fi
done

# --------------------------------------------------------------- connect

say "Connect"
CONNECT_XY="$(adb shell wm size | tr -d '\r' | awk -F'[ x]' '/Physical/ {printf "%d %d", $(NF-1)/2, $NF*0.45}')"
info "connect control at $CONNECT_XY"

tap_connect() { adb shell input tap $CONNECT_XY; }

wait_tun() {
  local timeout="${1:-25}" i=0
  while [ "$i" -lt "$timeout" ]; do
    adb shell ip addr show tun0 >/dev/null 2>&1 && return 0
    sleep 1; i=$((i+1))
  done
  return 1
}

ATTEMPTS=0
until [ "$ATTEMPTS" -ge 3 ]; do
  ATTEMPTS=$((ATTEMPTS+1))
  tap_connect
  wait_tun 25 && break
  info "no tunnel after tap $ATTEMPTS, retrying"
done
[ "$ATTEMPTS" -gt 1 ] && info "connected on attempt $ATTEMPTS"
sleep 8

TUN="$(adb shell ip addr show tun0 2>/dev/null | tr -d '\r')"
if echo "$TUN" | grep -q 'inet '; then
  ok "tun0 up: $(echo "$TUN" | awk '/inet /{print $2}')"
else
  bad "tun0 never came up" "the VPN did not establish; see $LOG"
fi

adb shell ip route show table all 2>/dev/null | grep -q 'default dev tun0' \
  && ok "default route points at tun0" \
  || bad "default route does not use tun0" "traffic would bypass the tunnel"

# Decode /proc/net/tcp into dotted quads so we can assert who we talk to.
conns() {
  adb shell "cat /proc/net/tcp" 2>/dev/null | awk 'NR>1{print $3}' | while read -r h; do
    ip="${h%%:*}"; port="${h##*:}"
    printf "%d.%d.%d.%d:%d\n" "0x${ip:6:2}" "0x${ip:4:2}" "0x${ip:2:2}" "0x${ip:0:2}" "0x$port"
  done
}
CONNS="$(conns)"

echo "$CONNS" | grep -qE ':443$' \
  && ok "upstream connection on 443: $(echo "$CONNS" | grep -E ':443$' | grep -v '^127\.' | head -1)" \
  || bad "no upstream connection on 443" "the core never reached a server"

echo "$CONNS" | grep -q '^127.0.0.1:10808$' \
  && ok "SOCKS inbound 127.0.0.1:10808 in use by tun2socks" \
  || bad "SOCKS inbound not established" "startLoop(config, 0) means tun2socks must feed the core over SOCKS"

# The headline check. The previous core implemented neither REALITY nor
# XTLS-Vision, so these configs were accepted and never actually honoured.
XTLS="$(grep -c 'Xtls Unpadding' "$LOG")"
if [ "$XTLS" -gt 0 ]; then
  ok "XTLS-Vision processing traffic ($XTLS padding blocks)"
else
  bad "no XTLS-Vision traffic observed" "tunnel may be up but passing nothing"
fi

if [ "$GEO_OK" = 1 ]; then
  if grep -q 'no geo database is bundled' "$LOG"; then
    bad "geo rules stripped despite staged databases" "stripGeoAssetRules ran anyway"
  else
    ok "no geo rules were stripped"
  fi
  grep -q 'geo databases unavailable' "$LOG" \
    && bad "core reported geo databases unavailable" "staging happened after initCoreEnv" \
    || ok "core initialised with the geo databases"
fi

# ----------------------------------------------------------------- routing

say "Routing rules"
MMKV="/data/data/$PKG/files/mmkv/SETTING"

# LC_ALL=C because the blob is binary and awk aborts on an invalid
# multibyte sequence part way through, silently truncating the read.
#
# MMKV appends rather than rewriting, so a file that has been re-seeded still
# contains every superseded ruleset. Reading the whole file would report rules
# that are no longer in effect, which is exactly how a working migration can
# look like a broken one. Only the last array written is live.
RULES="$(adb shell "run-as $PKG cat $MMKV 2>/dev/null" 2>/dev/null | strings \
  | LC_ALL=C awk '/^\[\{/ {buf=""} {buf=buf $0 "\n"} END {printf "%s", buf}' \
  | grep -oE 'geo(ip|site):[a-z0-9-]+' | sort -u | tr '\n' ' ')"
info "geo tokens in the live ruleset: ${RULES:-none}"

# The tunnel starting while geo tokens are present is the proof the databases
# resolved: one token the core cannot resolve makes it reject the whole config.
if echo "$RULES" | grep -q 'geo'; then
  ok "config carried geo tokens and the core accepted it"
else
  info "no geo tokens in the active preset, so this run does not exercise resolution"
fi

# Anything routed direct is traffic leaving outside the tunnel, so it has to
# be a deliberate choice rather than a leftover. Iran is now the deliberate
# choice (#40): Iranian traffic goes direct, which is faster and does not
# spend the daily allowance on traffic that never needed the tunnel.
if echo "$RULES" | grep -q 'geoip:ir' && echo "$RULES" | grep -q 'geosite:category-ir'; then
  ok "Iranian traffic routed direct, as decided in issue #40"
else
  bad "the Iran preset is not live: $RULES" \
      "WHITE_IRAN is the default; check ROUTING_PRESET_VERSION re-seeded"
fi

# China is the preset this app started on and must never come back: it sends
# Chinese traffic direct for users who are not in China and did not ask.
if echo "$RULES" | grep -qE 'geo(ip|site):cn'; then
  bad "the China preset is live again: $RULES" \
      "getPresetRoutingRulesets defaulted back to RoutingType.WHITE"
else
  ok "no Chinese direct routing"
fi

# ------------------------------------------------------------- lifecycle

say "Disconnect and reconnect without restarting the app"
TUN_BEFORE="$(adb shell ip addr show tun0 2>/dev/null | head -1 | cut -d: -f1 | tr -d '\r ')"
tap_connect
for _ in $(seq 1 20); do
  adb shell ip addr show tun0 >/dev/null 2>&1 || break
  sleep 1
done
adb shell ip addr show tun0 >/dev/null 2>&1 \
  && bad "tun0 survived disconnect" "interface leak across stopLoop" \
  || ok "tun0 torn down on disconnect"

adb logcat -c >/dev/null 2>&1
tap_connect
wait_tun 25 || { info "retrying reconnect tap"; tap_connect; wait_tun 25; }
sleep 8

TUN_AFTER="$(adb shell ip addr show tun0 2>/dev/null | head -1 | cut -d: -f1 | tr -d '\r ')"
if [ -n "$TUN_AFTER" ]; then
  ok "tun0 back up after reconnect (index $TUN_BEFORE then $TUN_AFTER)"
else
  bad "reconnect did not bring tun0 back" "stopLoop left the core unusable"
fi

RE_XTLS="$(adb logcat -d 2>/dev/null | grep -c 'Xtls Unpadding')"
[ "$RE_XTLS" -gt 0 ] \
  && ok "traffic flowing again after reconnect ($RE_XTLS blocks)" \
  || bad "no traffic after reconnect" "the second startLoop did not take"

# ---------------------------------------------------------------- crashes

say "Stability"
CRASH="$(grep -cE 'FATAL EXCEPTION|UnsatisfiedLinkError|E/AndroidRuntime|panic:' "$LOG")"
[ "$CRASH" -eq 0 ] \
  && ok "no crashes, no link errors, no core panics" \
  || bad "$CRASH crash or link error lines in logcat" "grep FATAL $LOG"

# ------------------------------------------------------------------- done

if [ "$KEEP" = 0 ]; then
  tap_connect >/dev/null 2>&1
  sleep 2
fi
kill $LOGCAT_PID 2>/dev/null

say "Result"
printf '  %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '\n  Failed checks:\n'
  for f in "${FAILURES[@]}"; do printf '    - %s\n' "$f"; done
fi
printf '\n  Logcat: %s\n' "$LOG"
[ "$FAIL" -eq 0 ]
