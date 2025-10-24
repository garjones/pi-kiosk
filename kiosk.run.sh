#!/bin/bash
# --------------------------------------------------------------------------------
#  kiosk.run.sh
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
# 
#  Displays HTML kiosks or RTSP camera feeds in a mosaic on a Raspberry Pi
#
#  Version 4.5 - Better label support
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------

# --------------------------------------------------------------------------------
# variables
# --------------------------------------------------------------------------------
# camera URLS
URL_CAM_HOME=(
  ""
  "rtsp://root:missionav@10.100.1.114/axis-media/media.amp"
  "rtsp://root:missionav@10.100.1.123/axis-media/media.amp"
  "rtsp://root:missionav@10.100.1.115/axis-media/media.amp"
  "rtsp://root:missionav@10.100.1.107/axis-media/media.amp"
  "rtsp://root:missionav@10.200.30.221/axis-media/media.amp"
  "rtsp://root:missionav@10.200.30.150/axis-media/media.amp"
  "rtsp://root:missionav@10.100.1.120/axis-media/media.amp"
  "rtsp://root:missionav@10.200.30.143/axis-media/media.amp"
  "rtsp://root:missionav@10.100.1.119/axis-media/media.amp"
  "rtsp://root:missionav@10.100.1.110/axis-media/media.amp"
  "rtsp://root:missionav@10.100.1.118/axis-media/media.amp"
  "rtsp://root:missionav@10.100.1.113/axis-media/media.amp"
)

URL_CAM_AWAY=(
  ""
  "rtsp://root:missionav@10.100.1.108/axis-media/media.amp"
  "rtsp://root:missionav@10.100.1.124/axis-media/media.amp"
  "rtsp://root:missionav@10.100.1.117/axis-media/media.amp"
  "rtsp://root:missionav@10.100.1.125/axis-media/media.amp"
  "rtsp://root:missionav@10.200.30.144/axis-media/media.amp"
  "rtsp://root:missionav@10.100.1.126/axis-media/media.amp"
  "rtsp://root:missionav@10.100.1.127/axis-media/media.amp"
  "rtsp://root:missionav@10.200.30.220/axis-media/media.amp"
  "rtsp://root:missionav@10.100.1.128/axis-media/media.amp"
  "rtsp://root:missionav@10.100.1.112/axis-media/media.amp"
  "rtsp://root:missionav@10.100.1.129/axis-media/media.amp"
  "rtsp://root:missionav@10.100.1.111/axis-media/media.amp"
)

# kiosk URLS (upstairs is #1, downstairs is #2
URL_KIOSK=(
  ""
  "https://marquee.csekcreative.com/launch/display.php?device_id=572&synchronization_code=10543-48822&key=54d6ed5688b801a8e43b6d44f81fa7b87f28dcf1b11a9f4b0f722627ffc4ed469dead0bd7a1f62a971054885b50758f50b0aeec038bf9319e6c441ae43ca3bdd"
  "https://marquee.csekcreative.com/launch/display.php?device_id=581&synchronization_code=79844-79798&key=f76346c1cb478b51a00f86f04003efe9f7492853635869241e8023ec1dcce1313c467df3b81923adb937ddcf348306b12642596ad73da15e6a4540e0d5f8f82c"
)

# rotation constants
ROT_90="transpose=1"
ROT_180="transpose=2,transpose=2"
ROT_270="transpose=2"

# get config & index & rotation
KCC_KIOSKCONFIG=$(cat /home/kcckiosk/kiosk.config)
KCC_CONFIG=${KCC_KIOSKCONFIG:0:1}
KCC_INDEX=${KCC_KIOSKCONFIG:1:2}
KCC_ROTATION=${KCC_KIOSKCONFIG:3:1}

# set screen dimensions & label URL
case $KCC_ROTATION in
    V)
        echo "Vertical"
        SCRN_WIDTH=1080
        SCRN_HEIGHT=1920
        ROTATION="transpose=1"
        LABEL_URL="/home/kcckiosk/label-bg-h.png"
        LABEL_1LEFT="0"
        LABEL_1TOP="$((SCRN_HEIGHT/2-50))"
        LABEL_2LEFT="$((SCRN_WIDTH/2))"
        LABEL_2TOP="$((SCRN_HEIGHT/2-50))"
        ;;
    *)
        echo "Horizontal"
        SCRN_WIDTH=3820
        SCRN_HEIGHT=2160
        ROTATION="transpose=2,transpose=2,transpose=2,transpose=2"
        LABEL_URL="/home/kcckiosk/label-bg-v.png"
        LABEL_1LEFT="$((SCRN_WIDTH/2-50))"
        LABEL_1TOP="0"
        LABEL_2LEFT="$((SCRN_WIDTH/2-50))"
        LABEL_2TOP="$((SCRN_HEIGHT/2))"
        ;;
esac

# --------------------------------------------------------------------------------
# execute
# --------------------------------------------------------------------------------
# set xwindows variables
xset s noblank
xset s off
xset -dpms

# hide the mouse
unclutter -idle 0.5 -root &

# fix chromium errors that may distrupt
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /home/kcckiosk/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/'   /home/kcckiosk/.config/chromium/Default/Preferences

# do it
case $KCC_CONFIG in
    K)
        /usr/bin/chromium --noerrdialogs --disable-infobars --kiosk "${URL_KIOSK[KCC_INDEX]}"
        ;;
    C)
        # cameras
        ffplay ${URL_CAM_AWAY[$((KCC_INDEX+1))]} -an -noborder -alwaysontop -x $((SCRN_WIDTH/2-50)) -y $((SCRN_HEIGHT/2)) -left 0                    -top 0                  &
        ffplay ${URL_CAM_HOME[$((KCC_INDEX+1))]} -an -noborder -alwaysontop -x $((SCRN_WIDTH/2-50)) -y $((SCRN_HEIGHT/2)) -left $((SCRN_WIDTH/2+50)) -top 0                  &        
        ffplay ${URL_CAM_AWAY[$((KCC_INDEX+0))]} -an -noborder -alwaysontop -x $((SCRN_WIDTH/2-50)) -y $((SCRN_HEIGHT/2)) -left 0                    -top $((SCRN_HEIGHT/2)) & 
        ffplay ${URL_CAM_HOME[$((KCC_INDEX+0))]} -an -noborder -alwaysontop -x $((SCRN_WIDTH/2-50)) -y $((SCRN_HEIGHT/2)) -left $((SCRN_WIDTH/2+50)) -top $((SCRN_HEIGHT/2)) & 

        ffplay $LABEL_URL -an -noborder -alwaysontop -left $LABEL_1LEFT -top $LABEL_1TOP -fs -x 100 -y $((SCRN_HEIGHT/2)) -vf "drawtext=text='$((KCC_INDEX+0))':font='Arial':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=black" &
        ffplay $LABEL_URL -an -noborder -alwaysontop -left $LABEL_2LEFT -top $LABEL_2TOP -fs -x 100 -y $((SCRN_HEIGHT/2)) -vf "drawtext=text='$((KCC_INDEX+1))':font='Arial':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=black" &
        ;;
    A)
        # all cameras
        ffplay ${URL_CAM_AWAY[$((1))]}  -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 0)) -top 0                      -vf "transpose=1" &
        ffplay ${URL_CAM_HOME[$((1))]}  -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 0)) -top $((SCRN_HEIGHT/2+50))  -vf "transpose=1" &
        ffplay ${URL_CAM_AWAY[$((2))]}  -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 1)) -top 0                      -vf "transpose=1" &
        ffplay ${URL_CAM_HOME[$((2))]}  -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 1)) -top $((SCRN_HEIGHT/2+50))  -vf "transpose=1" &
        ffplay ${URL_CAM_AWAY[$((3))]}  -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 2)) -top 0                      -vf "transpose=1" &
        ffplay ${URL_CAM_HOME[$((3))]}  -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 2)) -top $((SCRN_HEIGHT/2+50))  -vf "transpose=1" &
        ffplay ${URL_CAM_AWAY[$((4))]}  -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 3)) -top 0                      -vf "transpose=1" &
        ffplay ${URL_CAM_HOME[$((4))]}  -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 3)) -top $((SCRN_HEIGHT/2+50))  -vf "transpose=1" &
        ffplay ${URL_CAM_AWAY[$((5))]}  -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 4)) -top 0                      -vf "transpose=1" &
        ffplay ${URL_CAM_HOME[$((5))]}  -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 4)) -top $((SCRN_HEIGHT/2+50))  -vf "transpose=1" &
        ffplay ${URL_CAM_AWAY[$((6))]}  -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 5)) -top 0                      -vf "transpose=1" &
        ffplay ${URL_CAM_HOME[$((6))]}  -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 5)) -top $((SCRN_HEIGHT/2+50))  -vf "transpose=1" &
        ffplay ${URL_CAM_AWAY[$((7))]}  -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 6)) -top 0                      -vf "transpose=1" &
        ffplay ${URL_CAM_HOME[$((7))]}  -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 6)) -top $((SCRN_HEIGHT/2+50))  -vf "transpose=1" &
        ffplay ${URL_CAM_AWAY[$((8))]}  -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 7)) -top 0                      -vf "transpose=1" &
        ffplay ${URL_CAM_HOME[$((8))]}  -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 7)) -top $((SCRN_HEIGHT/2+50))  -vf "transpose=1" &
        ffplay ${URL_CAM_AWAY[$((9))]}  -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 8)) -top 0                      -vf "transpose=1" &
        ffplay ${URL_CAM_HOME[$((9))]}  -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 8)) -top $((SCRN_HEIGHT/2+50))  -vf "transpose=1" &
        ffplay ${URL_CAM_AWAY[$((10))]} -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 9)) -top 0                      -vf "transpose=1" &
        ffplay ${URL_CAM_HOME[$((10))]} -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 9)) -top $((SCRN_HEIGHT/2+50))  -vf "transpose=1" &
        ffplay ${URL_CAM_AWAY[$((11))]} -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 10)) -top 0                     -vf "transpose=1" &
        ffplay ${URL_CAM_HOME[$((11))]} -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 10)) -top $((SCRN_HEIGHT/2+50)) -vf "transpose=1" &
        ffplay ${URL_CAM_AWAY[$((12))]} -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 11)) -top 0                     -vf "transpose=1" &
        ffplay ${URL_CAM_HOME[$((12))]} -an -noborder -alwaysontop -x $((SCRN_WIDTH/12)) -y $((SCRN_HEIGHT/2-50)) -left $((SCRN_WIDTH/12 * 11)) -top $((SCRN_HEIGHT/2+50)) -vf "transpose=1" &

        ffplay /home/kcckiosk/label-bg-all.png -an -noborder -alwaysontop -left $((SCRN_WIDTH/12 * 0))  -top $((SCRN_HEIGHT/2-50)) -vf "drawtext=text='1':font='Arial':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=black" &
        ffplay /home/kcckiosk/label-bg-all.png -an -noborder -alwaysontop -left $((SCRN_WIDTH/12 * 1))  -top $((SCRN_HEIGHT/2-50)) -vf "drawtext=text='2':font='Arial':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=black" &
        ffplay /home/kcckiosk/label-bg-all.png -an -noborder -alwaysontop -left $((SCRN_WIDTH/12 * 2))  -top $((SCRN_HEIGHT/2-50)) -vf "drawtext=text='3':font='Arial':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=black" &
        ffplay /home/kcckiosk/label-bg-all.png -an -noborder -alwaysontop -left $((SCRN_WIDTH/12 * 3))  -top $((SCRN_HEIGHT/2-50)) -vf "drawtext=text='4':font='Arial':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=black" &
        ffplay /home/kcckiosk/label-bg-all.png -an -noborder -alwaysontop -left $((SCRN_WIDTH/12 * 4))  -top $((SCRN_HEIGHT/2-50)) -vf "drawtext=text='5':font='Arial':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=black" &
        ffplay /home/kcckiosk/label-bg-all.png -an -noborder -alwaysontop -left $((SCRN_WIDTH/12 * 5))  -top $((SCRN_HEIGHT/2-50)) -vf "drawtext=text='6':font='Arial':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=black" &
        ffplay /home/kcckiosk/label-bg-all.png -an -noborder -alwaysontop -left $((SCRN_WIDTH/12 * 6))  -top $((SCRN_HEIGHT/2-50)) -vf "drawtext=text='7':font='Arial':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=black" &
        ffplay /home/kcckiosk/label-bg-all.png -an -noborder -alwaysontop -left $((SCRN_WIDTH/12 * 7))  -top $((SCRN_HEIGHT/2-50)) -vf "drawtext=text='8':font='Arial':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=black" &
        ffplay /home/kcckiosk/label-bg-all.png -an -noborder -alwaysontop -left $((SCRN_WIDTH/12 * 8))  -top $((SCRN_HEIGHT/2-50)) -vf "drawtext=text='9':font='Arial':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=black" &
        ffplay /home/kcckiosk/label-bg-all.png -an -noborder -alwaysontop -left $((SCRN_WIDTH/12 * 9))  -top $((SCRN_HEIGHT/2-50)) -vf "drawtext=text='10':font='Arial':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=black" &
        ffplay /home/kcckiosk/label-bg-all.png -an -noborder -alwaysontop -left $((SCRN_WIDTH/12 * 10)) -top $((SCRN_HEIGHT/2-50)) -vf "drawtext=text='11':font='Arial':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=black" &
        ffplay /home/kcckiosk/label-bg-all.png -an -noborder -alwaysontop -left $((SCRN_WIDTH/12 * 11)) -top $((SCRN_HEIGHT/2-50)) -vf "drawtext=text='12':font='Arial':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=black" &
        ;;
    *)
        # error
        /usr/bin/chromium --noerrdialogs --disable-infobars --kiosk https://whatismyipaddress.com/
        ;;
esac

# keep process alive
while true; do
   sleep 10
done
