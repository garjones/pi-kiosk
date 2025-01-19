#!/bin/bash
# --------------------------------------------------------------------------------
#  kiosk.run.sh
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
# 
#  Displays HTML kiosks or RTSP camera feeds in a mosaic on a Raspberry Pi
#
#  Version 2.0 - support screen rotation
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------

# --------------------------------------------------------------------------------
# functions
# --------------------------------------------------------------------------------
is_debug () {
  if [ "$DEBUG" = TRUE ]; then
    return 0
  else
    return 1
  fi
}


# --------------------------------------------------------------------------------
# variables
# --------------------------------------------------------------------------------
# debug flag
DEBUG=TRUE

# set home path
if is_debug; then 
  HOME_PATH=""
else
  HOME_PATH="/home/kcckiosk/"
fi


# camera URLS
if is_debug; then
  URL_CAM_HOME=(
    ""
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
  )

  URL_CAM_AWAY=(
    ""
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
    "BigBuckBunny_640x360.m4v"
  )
else
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
fi

# kiosk URLS
URL_KIOSK=(
  ""
  "https://marquee.csekcreative.com/launch/display.php?device_id=580&synchronization_code=73127-62700&key=7110a09bcb4e20f7fd76af20b22d0ee078a6e391368f5a401e7c51db9d55ea8d98ecb7230394223bf26efabea65ee0ae0bcc4c8f58293d4cf41130c330755209"
  "https://marquee.csekcreative.com/launch/display.php?device_id=581&synchronization_code=79844-79798&key=f76346c1cb478b51a00f86f04003efe9f7492853635869241e8023ec1dcce1313c467df3b81923adb937ddcf348306b12642596ad73da15e6a4540e0d5f8f82c"
)

# rotation constants
ROT_90="transpose=1"
ROT_180="transpose=2,transpose=2"
ROT_270="transpose=2"

# read config variable
TEMP="${HOME_PATH}kiosk.config"

# set config & index
KCC_CONFIG=${TEMP:0:1}
KCC_INDEX=${TEMP:1:2}

# read rotation variable
TEMP="${HOME_PATH}kiosk.rotation"

# set screen dimensions & label URL
case $KCC_ROTATION in
    H)
        echo "Horizontal"
        SCRN_WIDTH=1920
        SCRN_HEIGHT=1080
        ROTATION="transpose=2,transpose=2,transpose=2,transpose=2"
        LABEL_URL="label-bg-v.png"
        LABEL_1LEFT="$((SCRN_WIDTH/2-50))"
        LABEL_1TOP="0"
        LABEL_2LEFT="$((SCRN_WIDTH/2-50))"
        LABEL_2TOP="$((SCRN_HEIGHT/2))"
        ;;
    V)
        echo "Vertical"
        SCRN_WIDTH=1080
        SCRN_HEIGHT=1920
        ROTATION="transpose=1"
        LABEL_URL="label-bg-h.png"
        LABEL_1LEFT="0"
        LABEL_1TOP="$((SCRN_HEIGHT/2-50))"
        LABEL_2LEFT="$((SCRN_WIDTH/2))"
        LABEL_2TOP="$((SCRN_HEIGHT/2-50))"
        ;;
    *)
        # error
        echo "Rotation not set"
        return
        ;;
esac

# --------------------------------------------------------------------------------
# execute
# --------------------------------------------------------------------------------
# only do x windows settings if we are on a pi
if ! is_debug; then
  # set xwindows variables
  xset s noblank
  xset s off
  xset -dpms

  # hide the mouse
  unclutter -idle 0.5 -root &

  # fix chromium errors that may distrupt
  sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /home/kcckiosk/.config/chromium/Default/Preferences
  sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/'   /home/kcckiosk/.config/chromium/Default/Preferences
fi

# do it
case $KCC_CONFIG in
    K)
        # kiosks
        if is_debug; then
          echo ${URL_KIOSK[KCC_INDEX]}
        else
          /usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk "${URL_KIOSK[KCC_INDEX]}"
        fi
        ;;
    C)
        # cameras
        ffplay ${URL_CAM_AWAY[$((KCC_INDEX+1))]} -an -noborder -x $((SCRN_WIDTH/2)) -y $((SCRN_HEIGHT/2)) -left 0                 -top 0                  &
        ffplay ${URL_CAM_HOME[$((KCC_INDEX+1))]} -an -noborder -x $((SCRN_WIDTH/2)) -y $((SCRN_HEIGHT/2)) -left $((SCRN_WIDTH/2)) -top 0                  &        
        ffplay ${URL_CAM_AWAY[$((KCC_INDEX+0))]} -an -noborder -x $((SCRN_WIDTH/2)) -y $((SCRN_HEIGHT/2)) -left 0                 -top $((SCRN_HEIGHT/2)) & 
        ffplay ${URL_CAM_HOME[$((KCC_INDEX+0))]} -an -noborder -x $((SCRN_WIDTH/2)) -y $((SCRN_HEIGHT/2)) -left $((SCRN_WIDTH/2)) -top $((SCRN_HEIGHT/2)) & 
        sleep 10
        ffplay $LABEL_URL -an -noborder -alwaysontop -left $LABEL_1LEFT -top $LABEL_1TOP -vf "drawtext=text='$KCC_INDEX':font='Arial':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=black" &
        ffplay $LABEL_URL -an -noborder -alwaysontop -left $LABEL_2LEFT -top $LABEL_2TOP -vf "drawtext=text='$((KCC_INDEX+1))':font='Arial':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=black" &
        ;;
    *)
        # error
        /usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://whatismyipaddress.com/
        ;;
esac

# keep process alive
while true; do
   sleep 10
done
