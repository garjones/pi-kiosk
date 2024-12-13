#!/bin/bash

# --------------------------------------------------------------------------------
#  kiosk.sh
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
# 
#  Displays HTML kiosks or RTSP camera feeds in a mosaic on a Raspberry Pi
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------
# 

# read config variable
kiosk=$(cat /home/kcckiosk/kiosk.config)

# set xwindows variables
xset s noblank
xset s off
xset -dpms

# hide the mouse
unclutter -idle 0.5 -root &

# fix chromium errors that may distrupt
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /home/kcckiosk/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/'   /home/kcckiosk/.config/chromium/Default/Preferences

# execute
case $kiosk in
    C1)
        ffplay rtsp://root:missionav@10.100.1.108/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0    &
        ffplay rtsp://root:missionav@10.100.1.114/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0    &
        ffplay rtsp://root:missionav@10.100.1.124/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540  &
        ffplay rtsp://root:missionav@10.100.1.123/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540  &
        ;;

    C2)
        ffplay rtsp://root:missionav@10.100.1.117/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0    &
        ffplay rtsp://root:missionav@10.100.1.115/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0    &
        ffplay rtsp://root:missionav@10.100.1.125/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540  &
        ffplay rtsp://root:missionav@10.100.1.107/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540  &
        ;;

    C3)
        ffplay rtsp://root:missionav@10.200.30.144/axis-media/media.amp  -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0    -vf "transpose=1, transpose=1" &
        ffplay rtsp://root:missionav@10.200.30.221/axis-media/media.amp  -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0    &
        ffplay rtsp://root:missionav@10.100.1.126/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540  -vf "transpose=1, transpose=1" &
        ffplay rtsp://root:missionav@10.200.30.150/axis-media/media.amp  -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540  &
        ;;

    C4)
        ffplay rtsp://root:missionav@10.100.1.127/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0    -vf "transpose=1, transpose=1" &
        ffplay rtsp://root:missionav@10.100.1.120/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0    &
        ffplay rtsp://root:missionav@10.200.30.220/axis-media/media.amp  -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540  -vf "transpose=1, transpose=1" &
        ffplay rtsp://root:missionav@10.200.30.143/axis-media/media.amp  -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540  &
        ;;

    C5)
        ffplay rtsp://root:missionav@10.100.1.128/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0    &
        ffplay rtsp://root:missionav@10.100.1.119/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0    &
        ffplay rtsp://root:missionav@10.100.1.112/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540  &
        ffplay rtsp://root:missionav@10.100.1.110/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540  &
        ;;

    C6)
        ffplay rtsp://root:missionav@10.100.1.129/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0    &
        ffplay rtsp://root:missionav@10.100.1.118/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0    &
        ffplay rtsp://root:missionav@10.100.1.111/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540  &
        ffplay rtsp://root:missionav@10.100.1.113/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540  &
        ;;

    K1)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=580
        ;;

    K2)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=581
        ;;

    K3)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=582
        ;;

    K4)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=583
        ;;

    K5)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=584
        ;;

    K6)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=585
        ;;

    K7)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=586
        ;;

    K8)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=587
        ;;

    K9)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=588
        ;;

    K10)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=589
        ;;

    *)
        /usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://whatismyipaddress.com/
        ;;
esac

# keep process alive
while true; do
   sleep 10
done
