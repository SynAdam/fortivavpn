#!/usr/bin/env bash
#
# Runs the router package on real OpenWrt, in Docker, and checks that a
# device behind the router reaches the internet through Fortiva.
#
#   wan network:  fake backend (fake_api.py), a Fortiva door (Xray), the router
#   lan network:  the router, and a client whose default route is the router
#
# The client fetches a page; the test passes when the fetch works, the
# router reports "connected" and the door counted the client's traffic.
# Then it checks what happens around that: turning it off and on, a
# restart, a WAN that loses its default route, IPv6 turned off, a guest
# zone, and a kill while the tunnel is up.
#
# The router never reaches Fortiva's backend: /etc/fortiva/api names the
# fake one before the package is installed. It never reaches GitHub either:
# install.sh downloads the build from a fake list of releases, in which the
# newest release has no router files, as install.sh finds it when the
# Router workflow has not run for a release.
#
# At the end it takes Fortiva off the router (fortiva uninstall), installs
# it again from the file, which keeps the router's id, and installs and
# removes the .ipk next to TARBALL, when there is one for the router.
#
#   router/test/e2e.sh XRAY TARBALL
#
# XRAY is a linux Xray-core binary for the Docker host's architecture (the
# door), TARBALL the router build for it (router/build.sh arm64 on an Arm
# Mac, amd64 on a PC). Needs Docker and an internet connection.
set -euo pipefail

xray=${1:?usage: e2e.sh XRAY TARBALL}
tarball=${2:?usage: e2e.sh XRAY TARBALL}
here=$(cd "$(dirname "$0")" && pwd)
p=fwt
case "$(uname -m)" in
  arm64|aarch64) image=openwrt/rootfs:armsr-armv8-openwrt-24.10 ;;
  *) image=openwrt/rootfs:x86-64-openwrt-24.10 ;;
esac
uuid=0b5c9c64-5b44-4e0f-9b1b-6f1d0f7d2a11

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mFAIL:\033[0m %s\n' "$*" >&2; dump; exit 1; }
dump() {
  echo "--- router log"; docker exec $p-router logread 2>/dev/null | grep -i fortiva | tail -40 || true
  echo "--- router status"; docker exec $p-router fortiva status 2>/dev/null || true
  echo "--- events"; docker exec $p-api cat /tmp/events.jsonl 2>/dev/null | tail -10 || true
}
cleanup() {
  docker rm -f $p-router $p-api $p-door $p-client $p-gh >/dev/null 2>&1 || true
  docker network rm $p-wan $p-lan >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

log "networks"
docker network create --subnet 172.31.10.0/24 $p-wan >/dev/null
# Not --internal: Docker drops bridged packets for addresses outside an
# internal network's subnet, which is everything the client sends. The
# client's default route goes to the router instead.
docker network create --subnet 172.31.20.0/24 $p-lan >/dev/null

log "a door on the wan"
work=$(mktemp -d)
cat > "$work/door.json" <<EOF
{
  "log": {"loglevel": "warning", "access": "/tmp/access.log"},
  "inbounds": [{"listen": "0.0.0.0", "port": 443, "protocol": "vless",
    "settings": {"clients": [{"id": "$uuid", "email": "router"}], "decryption": "none"}}],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
docker run -d --name $p-door --network $p-wan --ip 172.31.10.20 \
  -v "$xray:/usr/local/bin/xray:ro" -v "$work/door.json:/etc/door.json:ro" \
  alpine:3.20 /usr/local/bin/xray run -c /etc/door.json >/dev/null
link="vless://$uuid@172.31.10.20:443?type=tcp&security=none&encryption=none#door"

log "a fake backend on the wan"
docker run -d --name $p-api --network $p-wan --ip 172.31.10.10 \
  -v "$here/fake_api.py:/fake_api.py:ro" python:3.12-alpine \
  python3 -u /fake_api.py 8080 "$link" >/dev/null

log "the router"
# netifd would take Docker's interfaces over, so the network service stays
# off; the firewall still runs.
docker run -d --name $p-router --network $p-wan --ip 172.31.10.30 \
  --cap-add NET_ADMIN --cap-add NET_RAW --device /dev/net/tun \
  --sysctl net.ipv4.ip_forward=1 \
  "$image" sh -c 'rm -f /etc/rc.d/S*network* /etc/rc.d/S*odhcpd* /etc/rc.d/S*dropbear*; exec /sbin/init' >/dev/null
sleep 6
# OpenWrt's boot takes down the interface Docker made before it started;
# put the wan address back, then add the lan side.
docker exec $p-router sh -c 'ip link set eth0 up; ip addr add 172.31.10.30/24 dev eth0 2>/dev/null; ip route replace default via 172.31.10.1 dev eth0'
docker network connect --ip 172.31.20.2 $p-lan $p-router
sleep 1
# Docker may hand the default route to the lan network it just added; on a
# router it belongs to the wan.
docker exec $p-router ip route replace default via 172.31.10.1 dev eth0
docker cp "$tarball" $p-router:/tmp/
docker cp "$here/../install.sh" $p-router:/tmp/install.sh
lan_dev=$(docker exec $p-router sh -c "ip -o -4 addr show | awk '/172.31.20.2/ {print \$2}'")
[[ -n "$lan_dev" ]] || die "the router has no lan address"
# Without netifd the lan zone has no devices; give it the lan side.
docker exec $p-router sh -c "uci add_list firewall.@zone[0].device='$lan_dev' && uci commit firewall"
# A guest zone that forwards to wan, as many routers have. It must get a
# forwarding to the tunnel too, or it loses the internet while it is up.
docker exec $p-router sh -c "uci batch <<'EOF'
set firewall.guest=zone
set firewall.guest.name='guest'
add_list firewall.guest.device='guest0'
set firewall.guest.input='REJECT'
set firewall.guest.output='ACCEPT'
set firewall.guest.forward='REJECT'
set firewall.guest_wan=forwarding
set firewall.guest_wan.src='guest'
set firewall.guest_wan.dest='wan'
commit firewall
EOF"

log "installing"
# dnsmasq does not start here without netifd; a directory of its kind is
# enough to see the hook send the lookups through the tunnel.
docker exec $p-router mkdir -p /tmp/dnsmasq.e2e.d
# The fake backend, before the first start, in the file only root can
# write (not a uci option, which the LuCI page could set).
docker exec $p-router sh -c "mkdir -p /etc/fortiva && chmod 700 /etc/fortiva && echo http://172.31.10.10:8080 > /etc/fortiva/api"

log "a fake GitHub on the wan, whose newest release has no router files"
name=$(basename "$tarball")
gh="$work/github"
mkdir -p "$gh/v9.9.9" "$gh/v9.9.8"
cp "$tarball" "$gh/v9.9.8/$name"
cat > "$gh/releases.json" <<EOF
[{"tag_name": "v9.9.9", "assets": [{"browser_download_url": "http://172.31.10.40:8000/v9.9.9/FortivaVPN-9.9.9.apk"}]},
 {"tag_name": "v9.9.8", "assets": [{"browser_download_url": "http://172.31.10.40:8000/v9.9.8/$name"},
   {"browser_download_url": "http://172.31.10.40:8000/v9.9.8/fortiva-router-SHA256SUMS"}]}]
EOF
sums() { python3 -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest() + "  " + sys.argv[2])' "$1" "$2"; }
docker run -d --name $p-gh --network $p-wan --ip 172.31.10.40 -v "$gh:/srv:ro" \
  python:3.12-alpine python3 -m http.server 8000 -d /srv >/dev/null
releases=http://172.31.10.40:8000/releases.json
for _ in $(seq 1 30); do
  docker exec $p-router uclient-fetch -q -O /dev/null "$releases" 2>/dev/null && break
  sleep 1
done

log "a damaged download is refused"
echo "$(printf '0%.0s' $(seq 1 64))  $name" > "$gh/v9.9.8/fortiva-router-SHA256SUMS"
out=$(docker exec -e FORTIVA_RELEASES_API=$releases $p-router sh /tmp/install.sh 2>&1) && die "a damaged download was installed: $out"
grep -q "damaged" <<< "$out" || die "the damaged download said: $out"
docker exec $p-router test -e /etc/init.d/fortiva && die "a damaged download left files behind"
sums "$tarball" "$name" > "$gh/v9.9.8/fortiva-router-SHA256SUMS"

log "installing from the newest release that has the router's build"
out=$(docker exec -e FORTIVA_RELEASES_API=$releases $p-router sh /tmp/install.sh 2>&1) || die "the install failed: $out"
echo "$out"
grep -q "downloading $name" <<< "$out" || die "install.sh did not download $name"

log "waiting for the router to connect"
for _ in $(seq 1 60); do
  state=$(docker exec $p-router fortiva status 2>/dev/null | sed -n 's/^  "state": "\(.*\)",/\1/p')
  [[ "$state" == connected ]] && break
  sleep 1
done
[[ "$state" == connected ]] || die "the router is $state, not connected"
docker exec $p-router sh -c 'ip link show fortiva0' >/dev/null 2>&1 || die "no fortiva0 interface"
# Read first, then searched: grep -q stops reading at its first match, and
# with pipefail the writer's broken pipe would fail the check.
routes=$(docker exec $p-router ip route)
grep -q "0.0.0.0/1 dev fortiva0" <<< "$routes" || die "no route into the tunnel"
routes6=$(docker exec $p-router ip -6 route)
grep -q "::/1 dev fortiva0" <<< "$routes6" || die "no IPv6 route into the tunnel, with IPv6 on"
rules=$(docker exec $p-router nft list ruleset 2>/dev/null)
grep -q 'iifname "fortiva0"' <<< "$rules" || die "the firewall has no zone for fortiva0"
guest=$(docker exec $p-router nft list chain inet fw4 forward_guest 2>/dev/null)
grep -q "accept_to_fortiva" <<< "$guest" || die "the guest zone cannot forward to the tunnel: $guest"
again=$(docker exec $p-router /usr/share/fortiva/firewall.sh)
[[ -z "$again" ]] || die "the firewall script changed a firewall it had set up: $again"

conf=$(docker exec $p-router cat /tmp/dnsmasq.e2e.d/fortiva.conf 2>/dev/null || true)
grep -q "^server=1.1.1.1$" <<< "$conf" && grep -q "^no-resolv$" <<< "$conf" || die "the lookups were not sent through the tunnel: $conf"

log "a client behind the router"
docker run -d --name $p-client --network $p-lan --ip 172.31.20.50 --cap-add NET_ADMIN \
  --dns 1.1.1.1 alpine:3.20 sleep 600 >/dev/null
docker exec $p-client ip route replace default via 172.31.20.2
before=$(docker exec $p-door sh -c 'wc -l < /tmp/access.log' 2>/dev/null || echo 0)
docker exec $p-client wget -q -T 20 -O /dev/null https://www.gstatic.com/generate_204 || die "the client's fetch failed"
after=$(docker exec $p-door sh -c 'wc -l < /tmp/access.log')
[[ "$after" -gt "$before" ]] || die "the door saw none of the client's traffic"
docker exec $p-door grep -q "gstatic.com" /tmp/access.log || die "the client's site is not in the door's log"

log "turning it off sends the client around the tunnel"
docker exec $p-router fortiva disconnect >/dev/null
sleep 2
routes=$(docker exec $p-router ip route)
grep -q "dev fortiva0" <<< "$routes" && die "the routes stayed after turning off"
docker exec $p-router test -f /tmp/dnsmasq.e2e.d/fortiva.conf && die "the lookups still go to the tunnel after turning off"
state=$(docker exec $p-router fortiva status | sed -n 's/^  "state": "\(.*\)",/\1/p')
[[ "$state" == paused ]] || die "the router is $state after turning off"

log "turning it back on survives a restart of the service"
docker exec $p-router fortiva connect >/dev/null
docker exec $p-router /etc/init.d/fortiva restart
for _ in $(seq 1 60); do
  state=$(docker exec $p-router fortiva status 2>/dev/null | sed -n 's/^  "state": "\(.*\)",/\1/p')
  [[ "$state" == connected ]] && break
  sleep 1
done
[[ "$state" == connected ]] || die "after a restart the router is $state"
docker exec $p-client wget -q -T 20 -O /dev/null https://www.gstatic.com/generate_204 || die "the client's fetch failed after a restart"

log "a WAN that loses its default route"
# The binder hears of it from the kernel (netlink) and must see it within a
# second each way. Its fallback, reading the table every 5 s, would rarely
# be that quick twice.
seen=$(docker exec $p-router sh -c '
  network() { fortiva status 2>/dev/null | sed -n "s/^  \"network\": \"\(.*\)\",/\1/p"; }
  within() { i=0; while [ $i -lt 10 ]; do [ "$(network)" = "$1" ] && return 0; sleep 0.1; i=$((i+1)); done; return 1; }
  ip route del default
  within "" && gone=yes || gone=no
  ip route replace default via 172.31.10.1 dev eth0
  within ethernet && back=yes || back=no
  echo "$gone $back"')
[[ "$seen" == "yes yes" ]] || die "the router did not follow the WAN's default route within a second (gone, back: $seen)"
docker exec $p-client wget -q -T 20 -O /dev/null https://www.gstatic.com/generate_204 || die "the client's fetch failed after the WAN came back"

log "a router with IPv6 turned off still connects"
# As net.ipv6.conf.all.disable_ipv6=1 does on a router: a new interface
# gets no IPv6. /proc/sys is read-only in the container, so a helper in
# its network namespace writes it.
pid=$(docker inspect -f '{{.State.Pid}}' $p-router)
docker run --rm --privileged --pid=host alpine:3.20 nsenter -t "$pid" -n \
  sh -c 'echo 1 > /proc/sys/net/ipv6/conf/default/disable_ipv6' || die "could not turn IPv6 off"
docker exec $p-router /etc/init.d/fortiva restart
for _ in $(seq 1 60); do
  state=$(docker exec $p-router fortiva status 2>/dev/null | sed -n 's/^  "state": "\(.*\)",/\1/p')
  [[ "$state" == connected ]] && break
  sleep 1
done
[[ "$state" == connected ]] || die "with IPv6 off the router is $state"
routes6=$(docker exec $p-router ip -6 route)
grep -q "dev fortiva0" <<< "$routes6" && die "IPv6 routes into the tunnel with IPv6 off"
docker exec $p-client wget -q -T 20 -O /dev/null https://www.gstatic.com/generate_204 || die "the client's fetch failed with IPv6 off"

log "events reached the backend"
for kind in connected disconnected; do
  docker exec $p-api grep -q "\"type\": \"$kind\"" /tmp/events.jsonl || die "no $kind event"
done
docker exec $p-api grep -q '"platform": "router"' /tmp/registers.jsonl || die "the router did not register as a router"

log "a kill while connected leaves no lookups on a dead tunnel"
docker exec $p-router test -f /tmp/dnsmasq.e2e.d/fortiva.conf || die "the lookups are not on the tunnel before the kill"
# The door goes away, so the tunnel cannot come back, and the program is
# killed before it notices. procd starts it again 5 s later.
docker stop -t 1 $p-door >/dev/null
docker exec $p-router sh -c 'kill -9 $(pidof fortiva)'
for _ in $(seq 1 30); do
  docker exec $p-router test -f /tmp/dnsmasq.e2e.d/fortiva.conf || break
  sleep 1
done
docker exec $p-router test -f /tmp/dnsmasq.e2e.d/fortiva.conf && die "the lookups still go to a tunnel that is gone"
state=$(docker exec $p-router fortiva status 2>/dev/null | sed -n 's/^  "state": "\(.*\)",/\1/p')
[[ -n "$state" && "$state" != connected ]] || die "after the kill the router is ${state:-not running}"

log "fortiva uninstall takes everything off but the router's id"
docker start $p-door >/dev/null
id=$(docker exec $p-router sh -c 'fortiva status' | sed -n 's/^  "device_id": "\(.*\)",/\1/p')
[[ -n "$id" ]] || die "no device id before the uninstall"
out=$(docker exec $p-router fortiva uninstall 2>&1) || die "fortiva uninstall failed: $out"
grep -q "removed" <<< "$out" || die "fortiva uninstall said: $out"
docker exec $p-router sh -c 'pidof fortiva' >/dev/null && die "the program still runs after the uninstall"
for f in /etc/init.d/fortiva /usr/bin/fortiva /usr/share/fortiva /usr/lib/fortiva /etc/config/fortiva \
  /www/luci-static/resources/view/fortiva /usr/share/luci/menu.d/luci-app-fortiva.json \
  /usr/share/rpcd/acl.d/luci-app-fortiva.json /lib/upgrade/keep.d/fortiva /tmp/dnsmasq.e2e.d/fortiva.conf; do
  docker exec $p-router test -e "$f" && die "$f is still there after the uninstall"
done
docker exec $p-router sh -c 'ls /etc/rc.d | grep -q fortiva' && die "the service still starts with the router"
docker exec $p-router test -d /etc/fortiva || die "the uninstall deleted the router's id"
fw=$(docker exec $p-router uci show firewall)
grep -q "fortiva" <<< "$fw" && die "the firewall still names fortiva: $(grep fortiva <<< "$fw")"
grep -q "firewall.guest_wan.dest='wan'" <<< "$fw" || die "the uninstall took the guest zone's own forwarding"
docker exec $p-router sh -c 'ip route; ip -6 route' | grep -q fortiva0 && die "routes into the tunnel are left"

log "installing again from the file keeps the router's id"
docker exec $p-router sh /tmp/install.sh "/tmp/$name" >/dev/null
for _ in $(seq 1 60); do
  state=$(docker exec $p-router fortiva status 2>/dev/null | sed -n 's/^  "state": "\(.*\)",/\1/p')
  [[ "$state" == connected ]] && break
  sleep 1
done
[[ "$state" == connected ]] || die "after the new install the router is $state"
again=$(docker exec $p-router sh -c 'fortiva status' | sed -n 's/^  "device_id": "\(.*\)",/\1/p')
[[ "$again" == "$id" ]] || die "the new install is another router"
docker exec $p-client wget -q -T 20 -O /dev/null https://www.gstatic.com/generate_204 || die "the client's fetch failed after the new install"

log "--purge deletes the router's id too"
docker exec $p-router sh /tmp/install.sh --remove --purge >/dev/null || die "install.sh --remove --purge failed"
docker exec $p-router test -e /etc/fortiva && die "--purge kept /etc/fortiva"

case "$name" in
  *-arm64.tar.gz) ipk=$(ls "$(dirname "$tarball")"/fortiva_*_aarch64_generic.ipk 2>/dev/null | head -n 1) ;;
  *-amd64.tar.gz) ipk=$(ls "$(dirname "$tarball")"/fortiva_*_x86_64.ipk 2>/dev/null | head -n 1) ;;
  *) ipk="" ;;
esac
if [[ -n "$ipk" ]]; then
  log "the .ipk installs, and opkg remove leaves no firewall zone"
  docker exec $p-router sh -c "mkdir -p /etc/fortiva && chmod 700 /etc/fortiva && echo http://172.31.10.10:8080 > /etc/fortiva/api"
  docker cp "$ipk" $p-router:/tmp/fortiva.ipk
  # It depends on kmod-tun, which this container has no package lists for:
  # Docker gives it the TUN driver. An empty package of that name stands in,
  # since opkg refuses a package with a dependency it cannot find, even with
  # --nodeps or --force-depends.
  python3 - "$work/kmod-tun.ipk" <<'PY'
import io, sys, tarfile


def tgz(entries):
    out = io.BytesIO()
    with tarfile.open(fileobj=out, mode="w:gz") as tar:
        for name, data in entries:
            info = tarfile.TarInfo(name)
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
    return out.getvalue()


control = b"Package: kmod-tun\nVersion: 0-docker\nArchitecture: all\nDescription: Docker's TUN driver.\n"
open(sys.argv[1], "wb").write(tgz([("./debian-binary", b"2.0\n"), ("./data.tar.gz", tgz([])),
                                    ("./control.tar.gz", tgz([("./control", control)]))]))
PY
  docker cp "$work/kmod-tun.ipk" $p-router:/tmp/kmod-tun.ipk
  docker exec $p-router opkg install /tmp/kmod-tun.ipk >/dev/null || die "the stand-in kmod-tun did not install"
  docker exec $p-router opkg install /tmp/fortiva.ipk >/dev/null || die "opkg install failed"
  for _ in $(seq 1 60); do
    state=$(docker exec $p-router fortiva status 2>/dev/null | sed -n 's/^  "state": "\(.*\)",/\1/p')
    [[ "$state" == connected ]] && break
    sleep 1
  done
  [[ "$state" == connected ]] || die "after opkg install the router is $state"
  docker exec $p-router opkg remove fortiva >/dev/null || die "opkg remove failed"
  docker exec $p-router sh -c 'pidof fortiva' >/dev/null && die "the program still runs after opkg remove"
  docker exec $p-router uci show firewall | grep -q fortiva && die "opkg remove left the firewall naming fortiva"
  docker exec $p-router test -e /usr/lib/fortiva/fortiva && die "opkg remove left the program on flash"
fi

log "passed"
