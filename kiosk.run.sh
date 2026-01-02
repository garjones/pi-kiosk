#!/bin/bash
# --------------------------------------------------------------------------------
#  kiosk.run.sh
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
# 
#  Displays HTML kiosks or RTSP camera feeds in a mosaic on a Raspberry Pi
#
#  Version 6 - Added single sheet option
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
#    8 - Rotation
# --------------------------------------------------------------------------------
do_label() {
  ffplay -noborder -alwaysontop -left $4 -top $5 -f lavfi \
    "color=white@0:size=$2x$3:rate=1,
    drawbox=x=0:y=0:w=$2:h=$3:color=black@1:t=$6,
    drawtext=text='$1':fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:fontsize=48:fontcolor=black:x=(w-text_w)/2:y=(h-text_h)/2:shadowx=0:shadowy=0:$7" &
}


# --------------------------------------------------------------------------------
#  do_labelip() - Display IP address
# --------------------------------------------------------------------------------
#    1 - Label
#    2 - Width
#    3 - Height
#    4 - Left
#    5 - Top
#    6 - Border Width
#    8 - Rotation
# --------------------------------------------------------------------------------
do_labelip() {
  ffplay -noborder -alwaysontop -left $4 -top $5 -f lavfi \
    "color=black@0:size=$2x$3:rate=1,
    drawbox=x=0:y=0:w=$2:h=$3:color=black@1:t=$6,
    drawtext=text='$1':fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:fontsize=24:fontcolor=gray:x=(w-text_w)/2:y=(h-text_h)/2:shadowx=0:shadowy=0:$7" &
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
# determine if script is running on a raspberry pi
# --------------------------------------------------------------------------------
if [[ "$(uname)" == "Linux" ]]; then
    ON_PI=true
else
    ON_PI=false
fi

# --------------------------------------------------------------------------------
# constants & variables
# --------------------------------------------------------------------------------
# home cameras
if $ON_PI; then
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
else
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
fi

# away cameras
if $ON_PI; then
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
else
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
fi

# kiosk URLS (upstairs is #1, downstairs is #2
URL_KIOSK=(
  ""
  "https://marquee.csekcreative.com/launch/display.php?device_id=572&synchronization_code=10543-48822&key=54d6ed5688b801a8e43b6d44f81fa7b87f28dcf1b11a9f4b0f722627ffc4ed469dead0bd7a1f62a971054885b50758f50b0aeec038bf9319e6c441ae43ca3bdd"
  "https://marquee.csekcreative.com/launch/display.php?device_id=581&synchronization_code=79844-79798&key=f76346c1cb478b51a00f86f04003efe9f7492853635869241e8023ec1dcce1313c467df3b81923adb937ddcf348306b12642596ad73da15e6a4540e0d5f8f82c"
)

# label constants
LBL_WIDTH="100"

# get config
if $ON_PI; then
    KCC_KIOSKCONFIG=$(cat /home/kcckiosk/kiosk.config)
else
    KCC_KIOSKCONFIG=$(cat kiosk.config)
fi

# extract variables from config
KCC_ROTATION=${KCC_KIOSKCONFIG:0:1}
KCC_CONFIG=${KCC_KIOSKCONFIG:1:1}
SHEET_TOP=$((10#${KCC_KIOSKCONFIG:4:2}))
SHEET_BOT=$((10#${KCC_KIOSKCONFIG:2:2}))

# extract resolution string like "3840x2160"
if $ON_PI; then
    RES=$(kmsprint | awk '/Crtc/ { match($0, /[0-9]+x[0-9]+/); print substr($0, RSTART, RLENGTH); exit }')
    SCRN_WIDTH=$(echo "$RES" | cut -d'x' -f1)
    SCRN_HEIGHT=$(echo "$RES" | cut -d'x' -f2)
else
    SCRN_WIDTH="1800"
    SCRN_HEIGHT="1169"
fi

# get ip address
if $ON_PI; then
    MY_IP=$(hostname -I | awk '{print $1}')
else
    # dev env - set to max characters    
    MY_IP="255.255.255.255"
fi

# display variables for debug
echo "Screen Rotation : $KCC_ROTATION"
echo "Config          : $KCC_CONFIG"
echo "Bottom Sheet    : $SHEET_BOT"
echo "Top Sheet       : $SHEET_TOP"
echo "Screen Widh     : $SCRN_WIDTH"
echo "Screen Height   : $SCRN_HEIGHT"
echo "IP address      : $MY_IP"
if ! $ON_PI; then
    read -p "Press Enter to continue..."
fi

# video variables
VID_W="$((SCRN_WIDTH/2-LBL_WIDTH/2))"
VID_H="$((SCRN_HEIGHT/2))"
VID_L="$((SCRN_WIDTH/2+LBL_WIDTH/2))"
VID_T="$((SCRN_HEIGHT/2))"

# label variables
LBL_W="$LBL_WIDTH"
LBL_H="$((SCRN_HEIGHT/2))"
LBL_L="$((SCRN_WIDTH/2-LBL_WIDTH/2))"
LBL_T="$((SCRN_HEIGHT/2))"
LBL_B="1"

# ip label variables
LIP_I=$MY_IP
LIP_W=200
LIP_H=50
LIP_L="$((SCRN_WIDTH-LIP_W))"
LIP_T="$((SCRN_HEIGHT-LIP_H))"
LIP_B="1"

# rotation constants
# ROT_90=",transpose=1"
# ROT_180=",transpose=2,transpose=2"
# ROT_270=",transpose=2"

# check for screen rotation
if [ "$KCC_ROTATION" = "H" ]; then
    LBL_R=""
else
    LBL_R=",transpose=2"
fi

# --------------------------------------------------------------------------------
# screen setup
# --------------------------------------------------------------------------------
if $ON_PI; then
    # hide the mouse
    unclutter -idle 0.5 -root &

    # fix chromium errors that may distrupt
    sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /home/kcckiosk/.config/chromium/Default/Preferences
    sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/'   /home/kcckiosk/.config/chromium/Default/Preferences
fi

# --------------------------------------------------------------------------------
# execute
# --------------------------------------------------------------------------------
case $KCC_CONFIG in
    K)
        /usr/bin/chromium --noerrdialogs --disable-infobars --kiosk "${URL_KIOSK[SHEET_BOT]}"
        ;;
    C)
        #         URL                             WIDTH   HEIGHT  LEFT    TOP       BORDER     ROTATION
        do_video    ${URL_CAM_AWAY[$SHEET_TOP]}   $VID_W  $VID_H  0       0
        do_video    ${URL_CAM_HOME[$SHEET_TOP]}   $VID_W  $VID_H  $VID_L  0
        do_video    ${URL_CAM_AWAY[$SHEET_BOT]}   $VID_W  $VID_H  0       $VID_T
        do_video    ${URL_CAM_HOME[$SHEET_BOT]}   $VID_W  $VID_H  $VID_L  $VID_T
        do_label    $SHEET_TOP                    $LBL_W  $LBL_H  $LBL_L  0         $LBL_B     $LBL_R    
        do_label    $SHEET_BOT                    $LBL_W  $LBL_H  $LBL_L  $LBL_T    $LBL_B     $LBL_R
        sleep 5
        do_labelip  $LIP_I                        $LIP_W  $LIP_H  $LIP_L  $LIP_T    $LIP_B     $LBL_R  
		;;
	S)
        #         URL                             WIDTH   HEIGHT  LEFT    TOP       BORDER     ROTATION
		do_label    " "							  $VID_W  $VID_H  0       0         0          $LBL_R
		do_label    " "							  $VID_W  $VID_H  $VID_L  0         0          $LBL_R
        do_video    ${URL_CAM_AWAY[$SHEET_BOT]}   $VID_W  $VID_H  0       $VID_T
        do_video    ${URL_CAM_HOME[$SHEET_BOT]}   $VID_W  $VID_H  $VID_L  $VID_T
        do_label    " "							  $LBL_W  $LBL_H  $LBL_L  0         0          $LBL_R
        do_label    $SHEET_BOT                    $LBL_W  $LBL_H  $LBL_L  $LBL_T    $LBL_B     $LBL_R
        sleep 5
        do_labelip  $LIP_I                        $LIP_W  $LIP_H  $LIP_L  $LIP_T    $LIP_B     $LBL_R
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
