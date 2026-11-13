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
# The service takes the lookups back when it stops; this covers a program
# that was killed.
[ -x /usr/share/fortiva/hook.sh ] && /usr/share/fortiva/hook.sh down >/dev/null 2>&1

# The firewall: the zone, and every forwarding that names it, the ones the
# install added and any added by hand, since none works without the zone.
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
config_load firewall
config_foreach drop_forwarding forwarding
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
	say "firewall: removed the fortiva zone and its forwardings"
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
