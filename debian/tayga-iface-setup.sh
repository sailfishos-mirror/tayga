#!/bin/sh

NAME=tayga
DAEMON=/usr/sbin/tayga

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

# Note: The comment is part of iptables -D rule match logic so we should
# check/del rules both with and without the comment until forky+1. See
# below.
IPT_COMMENT="-m comment --comment tayga-NAT44"

iptables_rule () {
        "$@" POSTROUTING -t nat -s "$DYNAMIC_POOL" -j MASQUERADE
}
add_iptables_rule () {
        iptables_rule "$IPTABLES" $IPT_COMMENT -A
}
del_iptables_rule () {
        # Even deleting rules will load kernel modules both in -nft and
        # -legacy. We avoid this here (as merely loading the kmods may have
        # unintended effects) by only really deleting when the modules are
        # already loaded.
        [ "$1" != iptables ] || return #< any module loaded? return.
        type "$IPTABLES" >/dev/null 2>&1 || return
        check_iptables_rule "$IPTABLES" "$@" && iptables_rule "$IPTABLES" "$@" -D
}
check_iptables_rule () {
        if [ "$1" = iptables ]; then #< no module loaded
                false
        else
                iptables_rule "$@" -C 2>/dev/null
        fi
}

cleanup_iptables_rules () {
        IPTABLES=iptables
        if [ -d /sys/module/nft_compat ] && type iptables-nft >/dev/null 2>&1
        then
                IPTABLES=iptables-nft
                del_iptables_rule
                del_iptables_rule $IPT_COMMENT
        fi

        if [ -d /sys/module/ip_tables ] && type iptables-legacy >/dev/null 2>&1
        then
                IPTABLES=iptables-legacy
                del_iptables_rule
                del_iptables_rule $IPT_COMMENT
        fi
}

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
            cleanup_iptables_rules
            add_iptables_rule
    fi
}

teardown_iface() {
	if [ "$CONFIGURE_IFACE" = "yes" ] ; then
		ip link set "$TUN_DEVICE" down
		"$DAEMON" --rmtun | logger -t "$NAME" -i
	fi
        cleanup_iptables_rules
}

case $1 in
        start) setup_iface ;;
        stop)  teardown_iface;;
esac

exit 0
