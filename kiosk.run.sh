#!/bin/bash
# --------------------------------------------------------------------------------
#  kiosk.run.sh
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
# 
#  Displays HTML kiosks or RTSP camera feeds in a mosaic on a Raspberry Pi
#
#  Version 5.5 - Updated rotations
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------


# --------------------------------------------------------------------------------
# functions
# --------------------------------------------------------------------------------

# --------------------------------------------------------------------------------
#  do_label() - Draw white label, black border, text in centre
# --------------------------------------------------------------------------------
#    1 - Label
#    2 - Width
#    3 - Height
#    4 - Left
#    5 - Top
#    6 - Border Width
#    7 - Rotation
# --------------------------------------------------------------------------------
do_label() {
  ffplay -noborder -alwaysontop -left $4 -top $5 -f lavfi \
    "color=white:size=$2x$3:rate=1,
    drawbox=x=0:y=0:w=$2:h=$3:color=black@1:t=$6,
    drawtext=text='$1':fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:fontsize=48:fontcolor=black:x=(w-text_w)/2:y=(h-text_h)/2$7" &
}

# --------------------------------------------------------------------------------
#  do_video() - Display a video feed
# --------------------------------------------------------------------------------
#    $1 - URL
#    $2 - Width
#    $3 - Height
#    $4 - Left
#    $5 - Top
# --------------------------------------------------------------------------------
do_video() {
  ffplay $1 -an -noborder -alwaysontop -x $2 -y $3 -left $4 -top $5 &
}


# --------------------------------------------------------------------------------
# constants
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

# label constants
LBL_WIDTH="100"
LBL_BORDER="1"

# --------------------------------------------------------------------------------
# variables
# --------------------------------------------------------------------------------
# get config & index & rotation
KCC_KIOSKCONFIG=$(cat /home/kcckiosk/kiosk.config)
KCC_ROTATION=${KCC_KIOSKCONFIG:0:1}
KCC_CONFIG=${KCC_KIOSKCONFIG:1:1}
KCC_INDEX=${KCC_KIOSKCONFIG:2:2}
KCC_INDEX2=${KCC_KIOSKCONFIG:4:2}

# Extract resolution string like "3840x2160"
RES=$(kmsprint | awk '/Crtc/ { match($0, /[0-9]+x[0-9]+/); print substr($0, RSTART, RLENGTH); exit }')

# video and label variables
SHEET_TOP="$KCC_INDEX2"
SHEET_BOT="$KCC_INDEX"

SCRN_WIDTH=$(echo "$RES" | cut -d'x' -f1)
SCRN_HEIGHT=$(echo "$RES" | cut -d'x' -f2)

VID_W="$((SCRN_WIDTH/2-LBL_WIDTH/2))"
VID_H="$((SCRN_HEIGHT/2))"
VID_L="$((SCRN_WIDTH/2+LBL_WIDTH/2))"
VID_T="$((SCRN_HEIGHT/2))"
LBL_W="$LBL_WIDTH"
LBL_H="$((SCRN_HEIGHT/2))"
LBL_L="$((SCRN_WIDTH/2-LBL_WIDTH/2))"
LBL_T="$((SCRN_HEIGHT/2))"
LBL_B="$LBL_BORDER"

# check for screen rotation
if [ "$KCC_ROTATION" = "V" ]; then
    echo "Vertical"
    LBL_R=""
else
    echo "Horizontal"
    LBL_R=",transpose=2"
fi


# --------------------------------------------------------------------------------
# screen setup
# --------------------------------------------------------------------------------
# hide the mouse
unclutter -idle 0.5 -root &

# fix chromium errors that may distrupt
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /home/kcckiosk/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/'   /home/kcckiosk/.config/chromium/Default/Preferences

# --------------------------------------------------------------------------------
# execute
# --------------------------------------------------------------------------------
case $KCC_CONFIG in
    K)
        /usr/bin/chromium --noerrdialogs --disable-infobars --kiosk "${URL_KIOSK[KCC_INDEX]}"
        ;;
    C)
        #         URL                           WIDTH   HEIGHT  LEFT    TOP       BORDER     ROTATION
        do_video  ${URL_CAM_AWAY[$SHEET_TOP]}   $VID_W  $VID_H  0       0
        do_video  ${URL_CAM_HOME[$SHEET_TOP]}   $VID_W  $VID_H  $VID_L  0
        do_video  ${URL_CAM_AWAY[$SHEET_BOT]}   $VID_W  $VID_H  0       $VID_T
        do_video  ${URL_CAM_HOME[$SHEET_BOT]}   $VID_W  $VID_H  $VID_L  $VID_T
        do_label  $SHEET_TOP                    $LBL_W  $LBL_H  $LBL_L  0         $LBL_B     $LBL_R
        do_label  $SHEET_BOT                    $LBL_W  $LBL_H  $LBL_L  $LBL_T    $LBL_B     $LBL_R
	      ;;

    *)
        # error
        /usr/bin/chromium --noerrdialogs --disable-infobars --kiosk https://whatismyipaddress.com/
        ;;
esac

# --------------------------------------------------------------------------------
# keep alive
# --------------------------------------------------------------------------------
while true; do
   sleep 10
done
