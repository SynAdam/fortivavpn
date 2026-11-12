#!/usr/bin/env bash
#
# Checks that an upgrade keeps the program on flash when the flash only has
# room for it because the old program is replaced. Runs setup.sh on OpenWrt
# in Docker, with a 40 MB file system at /usr/lib/fortiva that holds an old
# 30 MB program and the new one packed. Free space alone is about 10 MB,
# less than the 34 MB setup.sh asks for; with the old program's room it is
# about 40 MB.
#
#   router/test/upgrade.sh
#
# Needs Docker. Uses the Docker name fwt-upgrade.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
case "$(uname -m)" in
  arm64|aarch64) image=openwrt/rootfs:armsr-armv8-openwrt-24.10 ;;
  *) image=openwrt/rootfs:x86-64-openwrt-24.10 ;;
esac

out=$(docker run --rm --name fwt-upgrade --tmpfs /usr/lib/fortiva:size=40m \
  -v "$here/../files/usr/share/fortiva/setup.sh:/usr/share/fortiva/setup.sh:ro" \
  "$image" sh -c '
    set -e
    dir=/usr/lib/fortiva
    # The old program, then the new one as the tarball leaves it.
    dd if=/dev/zero of=$dir/fortiva bs=1M count=30 2>/dev/null
    dd if=/dev/zero bs=1M count=30 2>/dev/null | gzip -c > $dir/fortiva.gz
    echo $((30 * 1024 * 1024)) > $dir/fortiva.size
    # The service is not what this checks.
    printf "#!/bin/sh\nexit 0\n" > /etc/init.d/fortiva
    chmod 755 /etc/init.d/fortiva
    sh /usr/share/fortiva/setup.sh
    [ -x $dir/fortiva ] && [ ! -f $dir/fortiva.gz ] && echo KEPT || echo MOVED' 2>&1)
echo "$out" | grep -v "does not match the detected host platform"
grep -q '^KEPT$' <<< "$out" || { echo "FAIL: the upgrade moved the program into memory" >&2; exit 1; }
echo passed
