#!/bin/sh
# Called by the Fortiva service with "up" when the tunnel starts carrying
# traffic and "down" when it stops. While it is up, the router's resolver
# (dnsmasq) asks the resolvers in fortiva.main.dns, whose packets go through
# the tunnel, instead of the ones the WAN handed out. When it stops, dnsmasq
# goes back to the WAN's resolvers, so the network keeps working without the
# tunnel.

name=fortiva.conf
dns=$(uci -q get fortiva.main.dns)
[ -n "$dns" ] || dns=1.1.1.1

# Every dnsmasq instance's own configuration directory: /tmp/dnsmasq.d on
# older releases, /tmp/dnsmasq.<section>.d on newer ones.
conf_dirs() {
	for d in /tmp/dnsmasq.d /tmp/dnsmasq.*.d; do
		[ -d "$d" ] && echo "$d"
	done
}

changed=0
case "$1" in
up)
	for d in $(conf_dirs); do
		tmp="$d/.$name"
		{
			echo "# Written by Fortiva while its tunnel is up; removed when it stops."
			echo "no-resolv"
			for s in $(echo "$dns" | tr ',' ' '); do
				echo "server=$s"
			done
		} > "$tmp"
		if cmp -s "$tmp" "$d/$name"; then
			rm -f "$tmp"
		else
			mv "$tmp" "$d/$name"
			changed=1
		fi
	done
	;;
down)
	for d in $(conf_dirs); do
		if [ -f "$d/$name" ]; then
			rm -f "$d/$name"
			changed=1
		fi
	done
	;;
*)
	echo "usage: $0 up|down" >&2
	exit 2
	;;
esac

if [ "$changed" = 1 ] && [ -x /etc/init.d/dnsmasq ]; then
	/etc/init.d/dnsmasq restart >/dev/null 2>&1
fi
exit 0
