# device name
uci set system.@system[0].hostname='TL-MR500v1'
uci commit system
/etc/init.d/system reload

# extend session timeout to 1d
uci set luci.sauth.sessiontime=86400
uci commit

# create wwan interface
uci set network.wwan0=interface
uci set network.wwan0.proto='dhcp'
uci set network.wwan0.device='usb0'
uci commit network

# set proper firewall zone
uci add_list firewall.@zone[1].network='wwan0'
uci commit firewall

# configure wirelesses
uci set wireless.default_radio0.disabled='0'
uci set wireless.default_radio0.ssid='TP-Link_MR500v1'
uci set wireless.default_radio1.disabled='0'
uci set wireless.default_radio1.ssid='TP-Link_MR500v1_5G'
uci commit wireless
wifi reload

# configure wwan led
uci set system.led_wan=led
uci set system.led_wan.name='wan'
uci set system.led_wan.sysfs='white:wan'
uci set system.led_wan.trigger='netdev'
uci set system.led_wan.dev='usb0' # wan for wired
uci set system.led_wan.mode='link tx rx'
uci set system.led_lan=led
uci set system.led_lan.name='lan'
uci set system.led_lan.sysfs='white:lan'
uci set system.led_lan.trigger='netdev'
uci set system.led_lan.dev='br-lan'
uci set system.led_lan.mode='link tx rx'
uci set system.led_4g=led
uci set system.led_4g.name='4g' 
uci set system.led_4g.sysfs='white:4g'
uci set system.led_4g.trigger='none'  # used by signal level script to indicate CA
#uci set system.led_4g.dev='usb0'
#uci set system.led_4g.mode='link tx rx'
uci set system.led_wlan=led
uci set system.led_wlan.name='wlan'
uci set system.led_wlan.sysfs='white:wlan'
uci set system.led_wlan.trigger='netdev'
uci set system.led_wlan.dev='phy1-ap0' # phy0-ap0 for 2.4ghz, phy1-ap0 for 5ghz
uci set system.led_wlan.mode='link tx rx'
uci commit system

# override model name displayed by LuCI
sed -i -e '$i \echo "TP-Link MR500v1 (EU)" > /tmp/sysinfo/model\n' /etc/rc.local 

# custom gcom support file used by the leds script
cat << "EOF" > /etc/signal-info.gcom
opengt
 set com 115200n81
 set comecho off
 set senddelay 0.01
 waitquiet 0.01 0.01

 let $c="AT+CSQ^m"
 let $r="+CSQ"
 gosub readatcmd

 let $c="AT+COPS=3,0;+COPS?^m"
 let $r="+COPS"
 gosub readatcmd

 let $c="AT+COPS=3,2;+COPS?^m"
 let $r="+COPS"
 gosub readatcmd

 let $c="AT+CREG=2;+CREG?^m"
 let $r="+CREG"
 gosub readatcmd

 let $c="AT+CPIN?^m"
 let $r="+CPIN"
 gosub readatcmd

 exit 0

:readatcmd
 let i=15
 send $c
:loop
 get 0.1 "^m" $s
 let l=len($r)
 if len($s) < l goto loop1
 if $mid($s,1,l) <> $r goto loop1
 print $s
 return

:loop1
 if len($s) < 2 goto loop2
 if $mid($s,1,2) = "ER" return
 if $mid($s,1,2) = "CO" return
 if len($s) < 10 goto loop2
 if $mid($s,1,10) != "+CME ERROR" goto loop2
 print $s
 return
:loop2
 if i = 0 exit 0
 let i=i-1
 goto loop

EOF

# custom signal leds handling script
cat << "EOF" > /etc/signal-leds.sh
#!/bin/sh
#
#   Script running in the background to switch LEDs according
#     to Received Signal Strength
#
#

DEVICE="/dev/ttyUSB0"
O=$(gcom -d $DEVICE -s /etc/signal-info.gcom 2>/dev/null)

# CSQ
CSQ=$(echo "$O" | awk -F[,\ ] '/^\+CSQ/ {print $2}')

[ "x$CSQ" = "x" ] && CSQ=-1
if [ $CSQ -ge 0 -a $CSQ -le 31 ]; then
	CSQ_PER=$(($CSQ * 100/31))
else
	CSQ="?"
	CSQ_PER=""
fi

#eval $(echo "$O" | awk -F[,] '/^\+CREG/ {gsub(/[[:space:]"]+/,"");printf "T=\"%d\";LAC_HEX=\"%X\";CID_HEX=\"%X\";LAC_DEC=\"%d\";CID_DEC=\"%d\";MODE_NUM=\"%d\"", $2, "0x"$3, "0x"$4, "0x"$3, "0x"$4, $5}')
#MODE_NUM=$(echo "$O" | awk -F[,] '/^\+COPS/ {print $4;exit}')  # COPS seems to return mode 7 even when CREG returns 16
MODE_NUM=$(echo "$O" | awk -F[,] '/^\+CREG/ {print $5;exit}')
case "$MODE_NUM" in
	2*) MODE="UMTS";;
	3*) MODE="EDGE";;
	4*) MODE="HSDPA";;
	5*) MODE="HSUPA";;
	6*) MODE="HSPA";;
	7*) MODE="LTE";;
	16*) MODE="LTEPLUS";; ### value returned by FG621 in 2CA mode 
	 *) MODE="UNDEF";;
esac

LED1=$(readlink -f /sys/class/leds/white:signal1)
LED2=$(readlink -f /sys/class/leds/white:signal2)
LED3=$(readlink -f /sys/class/leds/white:signal3)
LEDLTE=$(readlink -f /sys/class/leds/white:4g)

if [ ! -n "$CSQ_PER" ]; then
        # keep old leds statuses
        #echo none > $LED1/trigger
        #echo none > $LED2/trigger
        #echo none > $LED3/trigger
        logger -t signal-levels "Invalid signal data received, exiting."
        exit 1
fi

if [ "$MODE" = "LTEPLUS" ]; then
		echo default-on > $LEDLTE/trigger
else
		echo none > $LEDLTE/trigger
fi

if [ "$CSQ_PER" -le 25 ]; then
        echo none > $LED1/trigger
        echo none > $LED2/trigger
        echo none > $LED3/trigger
        logger -t signal-levels "MODE: $MODE ($MODE_NUM); RSSI: $CSQ_PER, LEDS: xxx"
elif [ "$CSQ_PER" -le 50 ]; then
        echo default-on > $LED1/trigger
        echo none > $LED2/trigger
        echo none > $LED3/trigger
        logger -t signal-levels "MODE: $MODE ($MODE_NUM); RSSI: $CSQ_PER, LEDS: Oxx"
elif [ "$CSQ_PER" -le 75 ]; then
        echo default-on > $LED1/trigger
        echo default-on > $LED2/trigger
        echo none > $LED3/trigger
        logger -t signal-levels "MODE: $MODE ($MODE_NUM); RSSI: $CSQ_PER, LEDS: OOx"
else
        echo default-on > $LED1/trigger
        echo default-on > $LED2/trigger
        echo default-on > $LED3/trigger
        logger -t signal-levels "MODE: $MODE ($MODE_NUM); RSSI: $CSQ_PER, LEDS: OOO"
fi


EOF
chmod +x /etc/signal-leds.sh

# cron job for signal leds updates
crontab -l > /tmp/newcron
echo "*/1 * * * * /etc/signal-leds.sh" >> /tmp/newcron
crontab /tmp/newcron
rm /tmp/newcron

# DONE