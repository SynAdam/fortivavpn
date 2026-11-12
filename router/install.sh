#!/bin/sh
# Installs Fortiva VPN on an OpenWrt router, or upgrades it.
#
#   sh install.sh                    download the newest release for this router
#   sh install.sh FILE.tar.gz        install from a file already on the router
#
# It works with either package manager (opkg up to OpenWrt 24.10, apk after)
# because it installs the files itself. The package manager is only asked
# for the two system parts Fortiva needs: the kernel's TUN driver and the
# certificate authorities.

set -e

RELEASES="https://github.com/SynAdam/fortivavpn/releases/latest/download"

say() { echo "fortiva: $*"; }
die() { echo "fortiva: $*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "run this as root"
[ -f /etc/openwrt_release ] || die "this is not an OpenWrt router"
. /etc/openwrt_release

# --- which build ------------------------------------------------------------
case "${DISTRIB_ARCH:-}" in
	aarch64_*) target=arm64 ;;
	arm_arm1176* | arm_arm926* | arm_xscale* | arm_fa526*) die "this router's processor ($DISTRIB_ARCH) is too old for Fortiva" ;;
	arm_*) target=armv7 ;;
	mipsel_*) target=mipsle ;;
	mips64*) die "this router's processor ($DISTRIB_ARCH) is not supported yet" ;;
	mips_*) target=mips ;;
	x86_64) target=amd64 ;;
	*) die "this router's processor (${DISTRIB_ARCH:-unknown}) is not supported" ;;
esac

# --- room for it --------------------------------------------------------------
mem_mb=$(( $(awk '/^MemTotal:/ {print $2}' /proc/meminfo) / 1024 ))
[ "$mem_mb" -ge 200 ] || die "Fortiva needs a router with at least 256 MB of memory; this one has ${mem_mb} MB"
free_kb=$(df -k /overlay 2>/dev/null | awk 'NR==2 {print $4}')
[ -n "$free_kb" ] || free_kb=$(df -k / | awk 'NR==2 {print $4}')
[ "$free_kb" -ge 16384 ] || die "Fortiva needs 16 MB of free storage; this router has $((free_kb / 1024)) MB"

# --- what the system must have ------------------------------------------------
need=""
[ -e /dev/net/tun ] || grep -q '^tun ' /proc/modules 2>/dev/null || need="$need kmod-tun"
[ -s /etc/ssl/certs/ca-certificates.crt ] || need="$need ca-bundle"
if [ -n "$need" ]; then
	say "installing$need"
	# $need is a list of package names, split on purpose.
	# shellcheck disable=SC2086
	if command -v apk >/dev/null 2>&1; then
		apk update >/dev/null && apk add $need
	elif command -v opkg >/dev/null 2>&1; then
		opkg update >/dev/null && opkg install $need
	else
		die "no package manager to install$need with"
	fi
	[ -e /dev/net/tun ] || modprobe tun 2>/dev/null || true
fi
[ -e /dev/net/tun ] || die "the kernel's TUN driver (kmod-tun) is missing"

# --- the files ------------------------------------------------------------------
fetch() {
	if command -v uclient-fetch >/dev/null 2>&1; then
		uclient-fetch -q -O "$2" "$1"
	else
		wget -q -O "$2" "$1"
	fi
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

file="$1"
if [ -z "$file" ]; then
	name="fortiva-router-$target.tar.gz"
	say "downloading $name"
	fetch "$RELEASES/$name" "$tmp/$name" || die "the download failed; download $name on a computer and run: sh install.sh $name"
	fetch "$RELEASES/SHA256SUMS" "$tmp/SHA256SUMS" || die "the checksums could not be downloaded"
	want=$(awk -v n="$name" '$2 == n {print $1}' "$tmp/SHA256SUMS")
	got=$(sha256sum "$tmp/$name" | cut -d' ' -f1)
	[ -n "$want" ] && [ "$want" = "$got" ] || die "the download is damaged (its checksum does not match)"
	file="$tmp/$name"
fi
[ -f "$file" ] || die "no file $file"
case "$file" in
*-"$target".tar.gz) ;;
*) die "$file is not the build for this router; it needs fortiva-router-$target.tar.gz" ;;
esac

if [ -x /etc/init.d/fortiva ]; then
	/etc/init.d/fortiva stop 2>/dev/null || true
fi
# Settings the router already has are kept.
[ -f /etc/config/fortiva ] && cp /etc/config/fortiva "$tmp/fortiva.config"
tar -xzf "$file" -C /
[ -f "$tmp/fortiva.config" ] && cp "$tmp/fortiva.config" /etc/config/fortiva

/usr/share/fortiva/setup.sh
say "installed $(cat /usr/share/fortiva/VERSION). Open LuCI, then Services, then Fortiva VPN; or run: fortiva status"
