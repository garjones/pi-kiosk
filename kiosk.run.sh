#!/bin/bash
# --------------------------------------------------------------------------------
#  kiosk.run.sh
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
# 
#  Displays HTML kiosks or RTSP camera feeds in a mosaic on a Raspberry Pi
#
#  Version 9.7
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------


# --------------------------------------------------------------------------------
# functions
# --------------------------------------------------------------------------------

# --------------------------------------------------------------------------------
#  do_kiosk() - Display kiosk
# --------------------------------------------------------------------------------
#    1 - URL
# --------------------------------------------------------------------------------
do_kiosk() {
    if $ON_PI; then
        /usr/bin/chromium --noerrdialogs --disable-infobars --kiosk "$1"
    else    
        /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --kiosk "$1"
    fi
}


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
  (while true; do
    ffplay -noborder -alwaysontop -left $4 -top $5 -f lavfi \
      "color=white@0:size=$2x$3:rate=1,
      drawbox=x=0:y=0:w=$2:h=$3:color=black@1:t=$6,
      drawtext=text='$1':fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:fontsize=48:fontcolor=black:x=(w-text_w)/2:y=(h-text_h)/2:
      $7"
    sleep 5
  done) &
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
#    7 - Rotation
# --------------------------------------------------------------------------------
do_labelip() {
  (while true; do
    ffplay -noborder -alwaysontop -left $4 -top $5 -f lavfi \
      "color=black@0:size=${2}x${3}:rate=1,
      drawbox=x=0:y=0:w=${2}:h=${3}:color=black@1:t=${6},
      drawtext=text='Kelowna Curling Club':fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:fontsize=24:fontcolor=white:x=20:y=(h-text_h)/2 ${7},
      drawtext=text='${1} - ${MY_HOSTNAME}':fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:fontsize=24:fontcolor=white:x=(w-text_w-20):y=(h-text_h)/2:
      $7"
    sleep 5
  done) &
}

# --------------------------------------------------------------------------------
#  do_video() - Display a video feed with automatic reconnection
# --------------------------------------------------------------------------------
#    $1 - URL
#    $2 - Width
#    $3 - Height
#    $4 - Left
#    $5 - Top
#    $6 - Rotation
# --------------------------------------------------------------------------------
do_video() {
  (while true; do
    ffplay $1 -an -noborder -alwaysontop -x $2 -y $3 -left $4 -top $5 $6
    sleep 5
  done) &
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
# load central config (camera IPs, credentials, RTSP URLs, kiosk URLs)
# --------------------------------------------------------------------------------
if $ON_PI; then
    ENV_FILE="/home/kcckiosk/kiosk.env"
else
    ENV_FILE="kiosk.env"
fi

if [ ! -f "$ENV_FILE" ]; then
    # kiosk.env missing - fall back to error screen
    /usr/bin/chromium --noerrdialogs --disable-infobars --kiosk https://whatismyipaddress.com/
    exit 1
fi

source "$ENV_FILE"

# --------------------------------------------------------------------------------
# dev override — replace RTSP URLs with local test video when not on Pi
# --------------------------------------------------------------------------------
if ! $ON_PI; then
    URL_CAM_HOME=("" "tiny-test.mp4" "tiny-test.mp4" "tiny-test.mp4" "tiny-test.mp4" \
                     "tiny-test.mp4" "tiny-test.mp4" "tiny-test.mp4" "tiny-test.mp4" \
                     "tiny-test.mp4" "tiny-test.mp4" "tiny-test.mp4" "tiny-test.mp4")
    URL_CAM_AWAY=("" "tiny-test.mp4" "tiny-test.mp4" "tiny-test.mp4" "tiny-test.mp4" \
                     "tiny-test.mp4" "tiny-test.mp4" "tiny-test.mp4" "tiny-test.mp4" \
                     "tiny-test.mp4" "tiny-test.mp4" "tiny-test.mp4" "tiny-test.mp4")
fi

# --------------------------------------------------------------------------------
# constants & variables
# --------------------------------------------------------------------------------

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
    SCRN_WIDTH="1920"
    SCRN_HEIGHT="1080"
fi

# get ip address and hostname
if $ON_PI; then
    MY_IP=$(hostname -I | awk '{print $1}')
    MY_HOSTNAME=$(hostname)
else
    # dev env - set to max characters    
    MY_IP="255.255.255.255"
    MY_HOSTNAME="kiosk-dev"
fi

# label constants
LBL_WIDTH="100"
LBL_HEIGHT="50"

# usable height
USE_H="$((SCRN_HEIGHT-LBL_HEIGHT))"

# ip label variables
LIP_I=$MY_IP
LIP_W="$((SCRN_WIDTH))"
LIP_H="$((LBL_HEIGHT))"
LIP_L="0"
LIP_T="$((USE_H))"
LIP_B="0"

# video variables
VID_W="$(((SCRN_WIDTH/2)-(LBL_WIDTH/2)))"
VID_H="$((USE_H/2))"
VID_L="$((SCRN_WIDTH/2+LBL_WIDTH/2))"
VID_T="$((USE_H/2))"

# label variables
LBL_W="$LBL_WIDTH"
LBL_H="$((USE_H/2))"
LBL_L="$(((SCRN_WIDTH/2)-(LBL_WIDTH/2)))"
LBL_T="$((USE_H/2))"
LBL_B="1"


# display variables for debug
echo "Screen Rotation : $KCC_ROTATION"
echo "Config          : $KCC_CONFIG"
echo "Bottom Sheet    : $SHEET_BOT"
echo "Top Sheet       : $SHEET_TOP"
echo "Screen Widh     : $SCRN_WIDTH"
echo "Screen Height   : $SCRN_HEIGHT"
echo "IP address      : $MY_IP"
echo "Hostname        : $MY_HOSTNAME"
echo ""
echo "Usable Height   : $USE_H"
echo ""
echo "Video Width     : $VID_W"
echo "Video Height    : $VID_H"
echo "Video Left      : $VID_L"
echo "Video Top       : $VID_T"
echo ""
echo "Label Width     : $LBL_W"
echo "Label Height    : $LBL_H"
echo "Label Left      : $LBL_L"
echo "Label Top       : $LBL_T"
echo "" 
echo "IP Width        : $LIP_W"
echo "IP Height       : $LIP_H"
echo "IP Left         : $LIP_L"
echo "IP Top          : $LIP_T"
if ! $ON_PI; then
    read -p "Press Enter to continue..."
fi

# check for screen rotation
if [ "$KCC_ROTATION" = "H" ]; then
    LBL_R=""
    VID_R=""
else
    LBL_R=",transpose=2"
    VID_R="-vf transpose=2"
fi

# --------------------------------------------------------------------------------
# screen setup
# --------------------------------------------------------------------------------
if $ON_PI; then
    # fix chromium errors that may distrupt
    sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /home/kcckiosk/.config/chromium/Default/Preferences
    sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/'   /home/kcckiosk/.config/chromium/Default/Preferences
fi

# --------------------------------------------------------------------------------
# execute
# --------------------------------------------------------------------------------
case $KCC_CONFIG in
    K)
        do_kiosk "${URL_KIOSK[SHEET_BOT]}"
        sleep 9
        do_labelip  $LIP_I                        $LIP_W  $LIP_H  $LIP_L  $LIP_T    $LIP_B     $LBL_R  
        ;;
    C)
        #         URL                             WIDTH   HEIGHT  LEFT    TOP       ROTATION
        do_video    ${URL_CAM_AWAY[$SHEET_TOP]}   $VID_W  $VID_H  0       0         "$VID_R"
        do_video    ${URL_CAM_HOME[$SHEET_TOP]}   $VID_W  $VID_H  $VID_L  0         "$VID_R"
        do_video    ${URL_CAM_AWAY[$SHEET_BOT]}   $VID_W  $VID_H  0       $VID_T    "$VID_R"
        do_video    ${URL_CAM_HOME[$SHEET_BOT]}   $VID_W  $VID_H  $VID_L  $VID_T    "$VID_R"
        do_label    $SHEET_TOP                    $LBL_W  $LBL_H  $LBL_L  0         $LBL_B     $LBL_R    
        do_label    $SHEET_BOT                    $LBL_W  $LBL_H  $LBL_L  $LBL_T    $LBL_B     $LBL_R
        sleep 9
        do_labelip  $LIP_I                        $LIP_W  $LIP_H  $LIP_L  $LIP_T    $LIP_B     $LBL_R  
        ;;
    S)
        #         URL                             WIDTH   HEIGHT  LEFT    TOP       ROTATION
        do_label    " "                           $VID_W  $VID_H  0       0         0          $LBL_R
        do_label    " "                           $VID_W  $VID_H  $VID_L  0         0          $LBL_R
        do_video    ${URL_CAM_AWAY[$SHEET_BOT]}   $VID_W  $VID_H  0       $VID_T    "$VID_R"
        do_video    ${URL_CAM_HOME[$SHEET_BOT]}   $VID_W  $VID_H  $VID_L  $VID_T    "$VID_R"
        do_label    " "                           $LBL_W  $LBL_H  $LBL_L  0         0          $LBL_R
        do_label    $SHEET_BOT                    $LBL_W  $LBL_H  $LBL_L  $LBL_T    $LBL_B     $LBL_R
        sleep 9
        do_labelip  $LIP_I                        $LIP_W  $LIP_H  $LIP_L  $LIP_T    $LIP_B     $LBL_R
        ;;	
    *)
        # error
        /usr/bin/chromium --noerrdialogs --disable-infobars --kiosk https://whatismyipaddress.com/
        sleep 9
        do_labelip  $LIP_I                        $LIP_W  $LIP_H  $LIP_L  $LIP_T    $LIP_B     $LBL_R
        ;;
esac

# --------------------------------------------------------------------------------
# keep alive
# --------------------------------------------------------------------------------
while true; do
   sleep 10
done
