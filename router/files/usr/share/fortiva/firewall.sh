#!/bin/sh
# Keeps the firewall ready for the tunnel. The tunnel's routes are in the
# main table, so while it is up the traffic of every zone goes to fortiva0.
# This puts fortiva0 in a zone of its own, and gives every zone that
# forwards to wan a forwarding to that zone too. Without one, that zone has
# no internet while the tunnel is up. A forwarding this added is removed
# again when its zone no longer forwards to wan.
#
# The install (/etc/uci-defaults/90-fortiva) and every start of the service
# (/etc/init.d/fortiva) run it, so a zone added later gets its forwarding at
# the next start. It saves and reloads the firewall only when it changed
# something, and it prints one line for each change.
#
# No masquerading: the tunnel ends inside the Fortiva program, which answers
# for every address, so the zones' own addresses can go in as they are.

. /lib/functions.sh

fw() { uci -q "$@"; }

changed=0
if ! uci -q get firewall.fortiva >/dev/null; then
	fw batch <<'EOF'
set firewall.fortiva=zone
set firewall.fortiva.name='fortiva'
add_list firewall.fortiva.device='fortiva0'
set firewall.fortiva.input='REJECT'
set firewall.fortiva.output='ACCEPT'
set firewall.fortiva.forward='REJECT'
set firewall.fortiva.mtu_fix='1'
EOF
	echo "fortiva: firewall: added the fortiva zone"
	changed=1
fi

to_wan=""   # zones with a forwarding to wan that is on
to_tunnel="" # zones with any forwarding to fortiva
ours=""     # forwardings this added, as section=zone

read_forwarding() {
	# config_get sets these; named apart, since sh has no local.
	f_src="" f_dest="" f_on=""
	config_get f_src "$1" src
	config_get f_dest "$1" dest
	config_get_bool f_on "$1" enabled 1
	[ -n "$f_src" ] || return 0
	if [ "$f_dest" = wan ] && [ "$f_on" = 1 ] && [ "$f_src" != fortiva ]; then
		to_wan="$to_wan $f_src"
	fi
	if [ "$f_dest" = fortiva ]; then
		to_tunnel="$to_tunnel $f_src"
		case "$1" in
		fortiva_*) ours="$ours $1=$f_src" ;;
		esac
	fi
}
config_load firewall
config_foreach read_forwarding forwarding

for zone in $to_wan; do
	case " $to_tunnel " in
	*" $zone "*) continue ;;
	esac
	section="fortiva_$(echo "$zone" | tr -c 'A-Za-z0-9_\n' '_')"
	fw set "firewall.$section=forwarding"
	fw set "firewall.$section.src=$zone"
	fw set "firewall.$section.dest=fortiva"
	to_tunnel="$to_tunnel $zone"
	echo "fortiva: firewall: $zone may now forward to the tunnel"
	changed=1
done

for pair in $ours; do
	section=${pair%%=*}
	zone=${pair#*=}
	case " $to_wan " in
	*" $zone "*) continue ;;
	esac
	fw delete "firewall.$section"
	echo "fortiva: firewall: $zone no longer forwards to wan, so not to the tunnel either"
	changed=1
done

if [ "$changed" = 1 ]; then
	fw commit firewall
	/etc/init.d/firewall reload >/dev/null 2>&1
fi
exit 0
