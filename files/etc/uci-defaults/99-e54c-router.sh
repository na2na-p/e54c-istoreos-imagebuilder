#!/bin/sh
# USB テザリング上流用インターフェース定義。
# RJ45 WAN (port3) は iStoreOS 既定設定のまま使うためここでは触らない。
# wan_ios の eth1 は、E54C の 4 ポートが内蔵スイッチ (rtl8367b) + eth0 の
# 1 本にまとまっており、ipheth が次番号の eth1 を取る前提。

uci -q batch <<EOF
set network.wan_usb=interface
set network.wan_usb.device='usb0'
set network.wan_usb.proto='dhcp'
set network.wan_ios=interface
set network.wan_ios.device='eth1'
set network.wan_ios.proto='dhcp'
EOF

# firewall の wan ゾーンは index 固定ではないため name='wan' で探す
wan_zone=$(uci show firewall | sed -n "s/^firewall\.\(@zone\[[0-9]*\]\)\.name='wan'$/\1/p" | head -n1)
if [ -n "$wan_zone" ]; then
    uci -q del_list firewall."$wan_zone".network='wan_usb'
    uci -q del_list firewall."$wan_zone".network='wan_ios'
    uci add_list firewall."$wan_zone".network='wan_usb'
    uci add_list firewall."$wan_zone".network='wan_ios'
fi

uci commit network
uci commit firewall

# iOS テザリングは usbmuxd がペアリングを仲介しないと ipheth が上がらない
if ! grep -q '^usbmuxd' /etc/rc.local; then
    sed -i '/^exit 0/i usbmuxd' /etc/rc.local
fi

exit 0
