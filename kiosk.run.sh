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
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk "https://marquee.csekcreative.com/launch/display.php?device_id=580&synchronization_code=73127-62700&key=7110a09bcb4e20f7fd76af20b22d0ee078a6e391368f5a401e7c51db9d55ea8d98ecb7230394223bf26efabea65ee0ae0bcc4c8f58293d4cf41130c330755209"
        ;;

    K2)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk "https://marquee.csekcreative.com/launch/display.php?device_id=581&synchronization_code=79844-79798&key=f76346c1cb478b51a00f86f04003efe9f7492853635869241e8023ec1dcce1313c467df3b81923adb937ddcf348306b12642596ad73da15e6a4540e0d5f8f82c"
        ;;

    *)
        /usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://whatismyipaddress.com/
        ;;
esac

# keep process alive
while true; do
   sleep 10
done
