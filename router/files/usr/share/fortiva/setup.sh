#!/bin/sh
# Finishes an install or an upgrade of Fortiva on the router. The package's
# postinst and install.sh both run it.
#
# 1. The program arrives packed (fortiva.gz). With room on the flash it is
#    unpacked there once; without, the service unpacks it into memory at
#    every start, and the flash keeps only the packed copy.
# 2. The firewall zone (/etc/uci-defaults/90-fortiva), which OpenWrt would
#    otherwise only add at the next boot.
# 3. The service is enabled and started.

dir=/usr/lib/fortiva
gz="$dir/fortiva.gz"

if [ -f "$gz" ]; then
	need_kb=0
	[ -f "$dir/fortiva.size" ] && need_kb=$(( $(cat "$dir/fortiva.size") / 1024 + 4096 ))
	free_kb=$(df -k "$dir" 2>/dev/null | awk 'NR==2 {print $4}')
	# On an upgrade the old program is still on the flash, and the new one
	# replaces it, so its room counts as free. Without this a router that
	# only just kept it on flash moves it to memory at every other upgrade.
	if [ -n "$free_kb" ] && [ -f "$dir/fortiva" ]; then
		free_kb=$((free_kb + $(du -k "$dir/fortiva" | cut -f1)))
	fi
	if [ "$need_kb" -gt 0 ] && [ -n "$free_kb" ] && [ "$free_kb" -gt "$need_kb" ]; then
		# The old program goes first, so the new one has its room.
		rm -f "$dir/fortiva"
		if gunzip -c "$gz" > "$dir/fortiva.new"; then
			chmod 755 "$dir/fortiva.new"
			mv "$dir/fortiva.new" "$dir/fortiva"
			rm -f "$gz"
			echo "fortiva: the program is kept on flash"
		else
			rm -f "$dir/fortiva.new"
			echo "fortiva: the program did not fit on the flash, so it is unpacked into memory at every start"
		fi
	else
		# An older unpacked copy must not win over the new packed one.
		rm -f "$dir/fortiva"
		echo "fortiva: the flash is small, so the program is unpacked into memory at every start"
	fi
	rm -rf /tmp/fortiva
fi

if [ -f /etc/uci-defaults/90-fortiva ]; then
	( . /etc/uci-defaults/90-fortiva ) && rm -f /etc/uci-defaults/90-fortiva
fi

/etc/init.d/fortiva enable
# Stopping a service that is not running yet only prints a complaint.
/etc/init.d/fortiva stop >/dev/null 2>&1
/etc/init.d/fortiva start
exit 0
