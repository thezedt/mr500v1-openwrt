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
MODE_NUM=$(echo "$O" | awk -F[,] '/^\+CREG/ {print $5;exit}')
#echo $MODE_NUM
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


