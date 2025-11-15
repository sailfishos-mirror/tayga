#!/bin/sh

NAME=tayga
DAEMON=/usr/sbin/tayga # Introduce the server's location here

CONF=/etc/tayga.conf
TUN_DEVICE=$(sed -rn "/^[ \t]*tun-device/s/^[ \t]*tun-device[ \t]+//p" $CONF)
IPV6_PREFIX=$(sed -rn "/^[ \t]*prefix/s/^[ \t]*prefix[ \t]+//p" $CONF)
DYNAMIC_POOL=$(sed -rn "/^[ \t]*dynamic-pool/s/^[ \t]*dynamic-pool[ \t]+//p" $CONF)
CONFIGURE_IFACE="no"
CONFIGURE_NAT44="no"

IPTABLES=${IPTABLES:-iptables}
type $IPTABLES >/dev/null 2>&1 || IPTABLES=true

# Include defaults if available
if [ -f "/etc/default/$NAME" ]; then
    . "/etc/default/$NAME"
fi

setup_iface() {
    if [ "$CONFIGURE_IFACE" = "yes" ] ; then
	    "$DAEMON" --mktun | logger -t "$NAME" -i
	    ip link set "$TUN_DEVICE" up
	    [ -n "$DYNAMIC_POOL" ] && ip route add "$DYNAMIC_POOL" dev "$TUN_DEVICE"
	    [ -n "$IPV6_PREFIX" ] && ip route add "$IPV6_PREFIX" dev "$TUN_DEVICE"
	    [ -n "$IPV4_TUN_ADDR" ] && ip addr add "$IPV4_TUN_ADDR" dev "$TUN_DEVICE"
	    [ -n "$IPV6_TUN_ADDR" ] && ip addr add "$IPV6_TUN_ADDR" dev "$TUN_DEVICE"
    fi
    if [ "$CONFIGURE_NAT44" = "yes" ] && [ -n "$DYNAMIC_POOL" ]; then
            # Make sure we clear the legacy rule.
            $IPTABLES -t nat -D POSTROUTING -s "$DYNAMIC_POOL" -j MASQUERADE || true
            nft -f- <<EOF || true
# TODO: Replace add/delete/add sequence with 'destroy'
# ... once it doesn't segfault :-)
add table ip tayga
delete table ip tayga
add table ip tayga
add chain ip tayga srcnat { type nat hook postrouting priority srcnat; }
add rule  ip tayga srcnat ip saddr $DYNAMIC_POOL counter masquerade
EOF
    fi
}

teardown_iface() {
	if [ "$CONFIGURE_IFACE" = "yes" ] ; then
		ip link set "$TUN_DEVICE" down
		"$DAEMON" --rmtun | logger -t "$NAME" -i
	fi
        $IPTABLES -t nat -D POSTROUTING -s "$DYNAMIC_POOL" -j MASQUERADE || true
        if nft list table ip tayga >/dev/null 2>&1; then
                nft delete table ip tayga
        fi
}

case $1 in
        start) setup_iface ;;
        stop)  teardown_iface;;
esac

exit 0
