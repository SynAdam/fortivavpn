#!/bin/sh
# Takes Fortiva off the router: stops the service, gives the network's
# lookups back to the WAN, removes the firewall zone and every forwarding to
# or from it, and deletes every file the install put there (the list is in
# /usr/share/fortiva/FILES). The router then uses its own connection, as
# before the install.
#
#   fortiva uninstall [--purge]          or: sh install.sh --remove [--purge]
#   remove.sh --package                  the .ipk's prerm: the package manager
#                                        deletes the files itself
#
# /etc/fortiva stays: the router's id with Fortiva and its saved doors, so a
# later install is the same router, with its Premium. --purge deletes it too.

package=0
purge=0
for arg in "$@"; do
	case "$arg" in
	--package) package=1 ;;
	--purge) purge=1 ;;
	*)
		echo "fortiva: unknown option $arg" >&2
		exit 2
		;;
	esac
done

say() { echo "fortiva: $*"; }

if [ -x /etc/init.d/fortiva ]; then
	/etc/init.d/fortiva stop >/dev/null 2>&1
	/etc/init.d/fortiva disable >/dev/null 2>&1
fi
# procd stops the program in the background, and the program takes up to
# 15 s (the service's term_timeout) to give the lookups back, take its
# routes away and send its last events. Nothing is deleted before it is
# gone: on 2026-11-13 an uninstall that did not wait deleted the hook the
# program was about to run, and left its routes up for some seconds.
i=0
while pidof fortiva >/dev/null 2>&1 && [ "$i" -lt 20 ]; do
	sleep 1
	i=$((i + 1))
done
if pidof fortiva >/dev/null 2>&1; then
	say "the program did not stop in 20 s; stopping it now"
	kill -9 $(pidof fortiva) 2>/dev/null
	sleep 1
fi
# What a program that was killed leaves behind: the lookups on the tunnel,
# and IPv6 refused (its TUN interface and routes go with it).
[ -x /usr/share/fortiva/hook.sh ] && /usr/share/fortiva/hook.sh down >/dev/null 2>&1
for half in ::/1 8000::/1; do
	ip -6 route del prohibit "$half" metric 1 >/dev/null 2>&1
done

# The firewall: the zone, and every forwarding and rule that names it, the
# ones the install added and any added by hand, since none works without
# the zone.
. /lib/functions.sh
changed=0
gone=""
drop_forwarding() {
	f_src="" f_dest=""
	config_get f_src "$1" src
	config_get f_dest "$1" dest
	if [ "$f_src" = fortiva ] || [ "$f_dest" = fortiva ]; then
		gone="$gone $1"
	fi
}
drop_rule() {
	r_dest=""
	config_get r_dest "$1" dest
	[ "$r_dest" = fortiva ] && gone="$gone $1"
}
config_load firewall
config_foreach drop_forwarding forwarding
config_foreach drop_rule rule
for section in $gone; do
	uci -q delete "firewall.$section" && changed=1
done
if uci -q get firewall.fortiva >/dev/null; then
	uci -q delete firewall.fortiva
	changed=1
fi
if [ "$changed" = 1 ]; then
	uci -q commit firewall
	/etc/init.d/firewall reload >/dev/null 2>&1
	say "firewall: removed the fortiva zone, its forwardings and its rules"
fi

if [ "$package" = 0 ]; then
	if [ -f /usr/share/fortiva/FILES ]; then
		while read -r f; do
			case "$f" in
			/*) rm -f "$f" ;;
			esac
		done < /usr/share/fortiva/FILES
	fi
	# What the install made besides the listed files: the program unpacked
	# on flash or into memory, and the folders that hold only Fortiva's.
	rm -rf /usr/lib/fortiva /usr/share/fortiva /tmp/fortiva \
		/www/luci-static/resources/view/fortiva
fi
# The program unpacked on flash is none of the package's files either.
rm -f /usr/lib/fortiva/fortiva
rm -rf /tmp/fortiva

if [ "$purge" = 1 ]; then
	rm -rf /etc/fortiva
fi

# The LuCI menu forgets the page.
/etc/init.d/rpcd reload >/dev/null 2>&1
rm -f /tmp/luci-indexcache /tmp/luci-indexcache.* 2>/dev/null

if [ "$package" = 0 ]; then
	if [ "$purge" = 1 ]; then
		say "removed, with the router's id"
	elif [ -d /etc/fortiva ]; then
		say "removed. The router's id stays in /etc/fortiva, so a new install is the same router, with its Premium. To delete it too: rm -rf /etc/fortiva"
	else
		say "removed"
	fi
fi
exit 0
