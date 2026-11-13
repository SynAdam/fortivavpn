#!/usr/bin/env bash
#
# Builds Fortiva for OpenWrt routers into router/dist/:
#
#   fortiva-router-<target>.tar.gz   the files, rooted at /, for install.sh
#   fortiva_<version>-1_<arch>.ipk   the same files as an opkg package, one
#                                    per OpenWrt architecture name
#   install.sh                       the installer
#   fortiva-router-SHA256SUMS        for all of them (not SHA256SUMS, the APKs' name)
#
# <target> is the Go build: arm64, armv7, mipsle, mips or amd64. One Go
# build serves every OpenWrt architecture of its CPU family (the ARCHES table
# below), because Go needs nothing from the firmware but the kernel.
#
#   ./build.sh                 every target
#   ./build.sh arm64 mipsle    only these
#
# Cross-compiles from any platform. The relays the app is built with are
# read from lib/api/built_in.dart and passed to the compiler; they are never
# written to a file here. In the public copy that file holds none, and the
# router then reaches the backend directly and through the relays the
# backend sends.
set -euo pipefail

cd "$(dirname "$0")"
root=$(cd .. && pwd)
core="$root/windows/core"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# OpenWrt architecture name -> Go target. Every name a common router uses.
ARCHES="
aarch64_cortex-a53 arm64
aarch64_cortex-a72 arm64
aarch64_cortex-a76 arm64
aarch64_generic arm64
arm_cortex-a7 armv7
arm_cortex-a7_neon-vfpv4 armv7
arm_cortex-a7_vfpv4 armv7
arm_cortex-a8_vfpv3 armv7
arm_cortex-a9 armv7
arm_cortex-a9_neon armv7
arm_cortex-a9_vfpv3-d16 armv7
arm_cortex-a15_neon-vfpv4 armv7
mipsel_24kc mipsle
mipsel_74kc mipsle
mipsel_mips32 mipsle
mips_24kc mips
mips_4kec mips
mips_mips32 mips
x86_64 amd64
"

targets=("$@")
[[ ${#targets[@]} -gt 0 ]] || targets=(arm64 armv7 mipsle mips amd64)
for t in "${targets[@]}"; do
  case "$t" in arm64|armv7|mipsle|mips|amd64) ;; *) die "unknown target $t" ;; esac
done

command -v go >/dev/null || die "go not found"
command -v python3 >/dev/null || die "python3 not found"

"$core/stage.sh"
if [[ -z "${GOTOOLCHAIN:-}" ]]; then
  export GOTOOLCHAIN="$(awk '$1=="toolchain"{print $2}' "$core/go.mod")"
fi

version=$(awk '$1=="version:"{print $2; exit}' "$root/pubspec.yaml")
version=${version%%+*}
[[ -n "$version" ]] || die "no version in pubspec.yaml"

sha256() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# tgz OUT DIR NAMES...: a gzipped tar of NAMES inside DIR, owned by root, so
# the router's tar gives the files to root and not to the builder's user id.
# GNU tar on Linux, bsdtar on macOS.
tgz() {
  local out=$1 dir=$2; shift 2
  if tar --version 2>/dev/null | grep -q GNU; then
    (cd "$dir" && tar --owner=0 --group=0 --numeric-owner -czf "$out" "$@")
  else
    (cd "$dir" && COPYFILE_DISABLE=1 tar --no-xattrs --uid 0 --gid 0 --uname root --gname root -czf "$out" "$@")
  fi
}

# The relays, as the JSON the agent reads (internal/agent builtinRelays).
relays=$(python3 - "$root/lib/api/built_in.dart" <<'PY'
import json, re, sys
src = open(sys.argv[1], encoding="utf-8").read()
pins = dict(re.findall(r"static const (_\w+)\s*=\s*'([0-9a-fA-F]{64})';", src))
out = []
block = re.search(r"static const relays\s*=\s*<[^>]*>\[(.*?)\];", src, re.S)
for url, pin in re.findall(r"\(url:\s*'([^']+)',\s*pin:\s*([^)]+?)\s*\)", block.group(1) if block else ""):
    pin = pin.strip()
    pin = pins.get(pin, pin.strip("'"))
    if re.fullmatch(r"[0-9a-fA-F]{64}", pin) and url.startswith("https://"):
        out.append({"url": url, "pin": pin.lower()})
print(json.dumps(out, separators=(",", ":")))
PY
)
relay_count=$(python3 -c 'import json,sys; print(len(json.loads(sys.argv[1])))' "$relays")
log "fortiva-router $version, $relay_count built-in relays"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The routing data, cut to the lists the tunnel's rules name.
(cd "$core" && go run ./cmd/geotrim -in .assets -out "$work/geo")

dist="$PWD/dist"
rm -rf "$dist"
mkdir -p "$dist"

for t in "${targets[@]}"; do
  goarch=$t; goarm=""; gomips=""
  case "$t" in
    armv7) goarch=arm; goarm=7 ;;
    mipsle|mips) gomips=softfloat ;;
  esac

  log "building for linux/$t"
  bin="$work/$t/fortiva"
  mkdir -p "$work/$t"
  # -checklinkname=0: the TUN inbound reaches runtime.procyield through
  # go:linkname, as in the Windows and Android builds.
  (cd "$core" && GOOS=linux GOARCH="$goarch" GOARM="$goarm" GOMIPS="$gomips" CGO_ENABLED=0 go build \
    -trimpath \
    -ldflags="-s -w -buildid= -checklinkname=0 -X main.version=$version -X github.com/fortiva/fortiva-vpn-clients/windows/core/internal/agent.builtinRelays=$relays" \
    -o "$bin" ./cmd/fortiva-router)

  # --- verify -------------------------------------------------------------
  go version -m "$bin" > "$work/$t/buildinfo"
  grep -q "GOOS=linux" "$work/$t/buildinfo" || die "$t: not built for Linux"
  grep -q "GOARCH=$goarch" "$work/$t/buildinfo" || die "$t: not built for $goarch"
  replaced=$(awk '$1=="dep" && $2=="github.com/xtls/xray-core" {getline; if ($1=="=>") print $2}' "$work/$t/buildinfo")
  [[ "$replaced" == "../../android/core/.src/xray-core" ]] || \
    die "$t: xray-core does not come from android/core/.src (the patched source): ${replaced:-not replaced}"
  strings -a "$bin" > "$work/$t/strings"
  for needle in xtls-rprx-vision autoselect proxy/tun reality; do
    grep -q -- "$needle" "$work/$t/strings" || die "$t: the program lacks $needle"
  done

  # --- the files, rooted at / ----------------------------------------------
  tree="$work/$t/root"
  mkdir -p "$tree"
  cp -R files/. "$tree/"
  mkdir -p "$tree/usr/lib/fortiva" "$tree/usr/share/fortiva"
  wc -c < "$bin" | tr -d ' ' > "$tree/usr/lib/fortiva/fortiva.size"
  gzip -9 -n -c "$bin" > "$tree/usr/lib/fortiva/fortiva.gz"
  cp "$work/geo/geoip.dat" "$work/geo/geosite.dat" "$tree/usr/share/fortiva/"
  cp "$root/LICENSE" "$tree/usr/share/fortiva/LICENSE"
  echo "$version" > "$tree/usr/share/fortiva/VERSION"
  # Modes of their own, whatever the builder's umask. Root's tar gives an
  # existing directory the mode it has in the archive, and /, /etc and /usr
  # are among them; a 0750 / would lock dnsmasq out of its files.
  find "$tree" -type d -exec chmod 755 {} +
  find "$tree" -type f -exec chmod 644 {} +
  chmod 755 "$tree/etc/init.d/fortiva" "$tree/etc/uci-defaults/90-fortiva" \
    "$tree/usr/bin/fortiva" "$tree/usr/share/fortiva/hook.sh" "$tree/usr/share/fortiva/setup.sh" \
    "$tree/usr/share/fortiva/firewall.sh" "$tree/usr/share/fortiva/remove.sh"
  # Every file the install puts on the router, for remove.sh.
  (cd "$tree" && { find . -type f | sed 's|^\.||'; echo /usr/share/fortiva/FILES; } | LC_ALL=C sort -u) \
    > "$tree/usr/share/fortiva/FILES"

  tarball="$dist/fortiva-router-$t.tar.gz"
  # The top directories by name, not ".": a "./" entry would set the mode
  # of / itself.
  tops=()
  for d in "$tree"/*; do tops+=("./$(basename "$d")"); done
  tgz "$tarball" "$tree" "${tops[@]}"
  # Every directory 0755 and no entry for / itself.
  bad=$(tar -tvzf "$tarball" | awk '$1 ~ /^d/ && $1 != "drwxr-xr-x" {print}; $NF == "./" || $NF == "." {print}')
  [[ -z "$bad" ]] || die "$t: the tarball would change the mode of a directory on the router: $bad"

  # --- an .ipk for each OpenWrt architecture of this target ---------------
  size=$(du -sk "$tree" | cut -f1)
  echo "$ARCHES" | while read -r arch target; do
    [[ "$target" == "$t" ]] || continue
    pkg="$work/$t/ipk-$arch"
    mkdir -p "$pkg/control"
    cat > "$pkg/control/control" <<EOF
Package: fortiva
Version: $version-1
Depends: libc, kmod-tun, ca-bundle
Source: https://github.com/SynAdam/fortivavpn
SourceName: fortiva
License: GPL-3.0-or-later
LicenseFiles: LICENSE
Section: net
URL: https://fortivavpn.com
Architecture: $arch
Installed-Size: $((size * 1024))
Description: Fortiva VPN for the whole network. Every device behind the
 router connects through Fortiva, with a page under Services in LuCI.
EOF
    echo "/etc/config/fortiva" > "$pkg/control/conffiles"
    cat > "$pkg/control/postinst" <<'EOF'
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] && exit 0
/usr/share/fortiva/setup.sh
EOF
    # The package manager deletes the package's files; remove.sh undoes the
    # rest: the service, the lookups, the firewall zone, the program
    # unpacked on flash.
    cat > "$pkg/control/prerm" <<'EOF'
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] && exit 0
/usr/share/fortiva/remove.sh --package
exit 0
EOF
    chmod 755 "$pkg/control/postinst" "$pkg/control/prerm"
    echo "2.0" > "$pkg/debian-binary"
    tgz "$pkg/control.tar.gz" "$pkg/control" ./control ./conffiles ./postinst ./prerm
    cp "$tarball" "$pkg/data.tar.gz"
    tgz "$dist/fortiva_${version}-1_${arch}.ipk" "$pkg" ./debian-binary ./data.tar.gz ./control.tar.gz
  done
done

cp install.sh "$dist/install.sh"
(cd "$dist" && for f in *; do [[ "$f" == fortiva-router-SHA256SUMS ]] || echo "$(sha256 "$f")  $f"; done > fortiva-router-SHA256SUMS)
log "done:"
ls -la "$dist"
