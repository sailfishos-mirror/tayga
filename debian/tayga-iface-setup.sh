#!/bin/sh

NAME=tayga
DAEMON=/usr/sbin/tayga # Introduce the server's location here

CONF=/etc/tayga.conf
TUN_DEVICE=$(sed -rn "/^[ \t]*tun-device/s/^[ \t]*tun-device[ \t]+//p" $CONF)
IPV6_PREFIX=$(sed -rn "/^[ \t]*prefix/s/^[ \t]*prefix[ \t]+//p" $CONF)
DYNAMIC_POOL=$(sed -rn "/^[ \t]*dynamic-pool/s/^[ \t]*dynamic-pool[ \t]+//p" $CONF)
CONFIGURE_IFACE="no"
CONFIGURE_NAT44="no"

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
    [ "$CONFIGURE_NAT44" = "yes" ] && [ -n "$DYNAMIC_POOL" ] && iptables -t nat -A POSTROUTING -s "$DYNAMIC_POOL" -j MASQUERADE || true
}

teardown_iface() {
	if [ "$CONFIGURE_IFACE" = "yes" ] ; then
		ip link set "$TUN_DEVICE" down
		"$DAEMON" --rmtun | logger -t "$NAME" -i
	fi
	[ "$CONFIGURE_NAT44" = "yes" ] && [ -n "$DYNAMIC_POOL" ] && iptables -t nat -D POSTROUTING -s "$DYNAMIC_POOL" -j MASQUERADE || true
}

case $1 in
        start) setup_iface ;;
        stop)  teardown_iface;;
esac

exit 0
