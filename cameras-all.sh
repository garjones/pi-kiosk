#!/bin/bash
# --------------------------------------------------------------------------------
#  cameras-all.sh
# --------------------------------------------------------------------------------
#  Camera Test
# 
#  Displays all cameras locally to test them
#
#  Version 1
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
    "color=white@0:size=$2x$3:rate=1,
    drawbox=x=0:y=0:w=$2:h=$3:color=black@1:t=$6,
    drawtext=text='$1':fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:fontsize=48:fontcolor=black:x=(w-text_w)/2:y=(h-text_h)/2:
    $7" &
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
# constants & variables
# --------------------------------------------------------------------------------
# home cameras
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

# away cameras
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

# set screen width and height
SCRN_WIDTH=1800
SCRN_HEIGHT=1169

# video variables
VID_W="$((SCRN_WIDTH/12))"
VID_H="$((SCRN_HEIGHT/2))"
VID_L="$((VID_W))"
VID_T="$((SCRN_HEIGHT/2))"

# --------------------------------------------------------------------------------
# execute
# --------------------------------------------------------------------------------

#         URL                    WIDTH   HEIGHT  LEFT                 TOP
# away cameras
do_video    ${URL_CAM_AWAY[1]}   $VID_W  $VID_H  $((VID_W * 0))       0
do_video    ${URL_CAM_AWAY[2]}   $VID_W  $VID_H  $((VID_W * 1))       0
do_video    ${URL_CAM_AWAY[3]}   $VID_W  $VID_H  $((VID_W * 2))       0
do_video    ${URL_CAM_AWAY[4]}   $VID_W  $VID_H  $((VID_W * 3))       0
do_video    ${URL_CAM_AWAY[5]}   $VID_W  $VID_H  $((VID_W * 4))       0
do_video    ${URL_CAM_AWAY[6]}   $VID_W  $VID_H  $((VID_W * 5))       0
do_video    ${URL_CAM_AWAY[7]}   $VID_W  $VID_H  $((VID_W * 6))       0
do_video    ${URL_CAM_AWAY[8]}   $VID_W  $VID_H  $((VID_W * 7))       0
do_video    ${URL_CAM_AWAY[9]}   $VID_W  $VID_H  $((VID_W * 8))       0
do_video    ${URL_CAM_AWAY[10]}  $VID_W  $VID_H  $((VID_W * 9))       0
do_video    ${URL_CAM_AWAY[11]}  $VID_W  $VID_H  $((VID_W * 10))      0
do_video    ${URL_CAM_AWAY[12]}  $VID_W  $VID_H  $((VID_W * 11))      0


# home cameras
do_video    ${URL_CAM_HOME[1]}    $VID_W  $VID_H  $((VID_W * 0))       $VID_T
do_video    ${URL_CAM_HOME[2]}    $VID_W  $VID_H  $((VID_W * 1))       $VID_T
do_video    ${URL_CAM_HOME[3]}    $VID_W  $VID_H  $((VID_W * 2))       $VID_T
do_video    ${URL_CAM_HOME[4]}    $VID_W  $VID_H  $((VID_W * 3))       $VID_T
do_video    ${URL_CAM_HOME[5]}    $VID_W  $VID_H  $((VID_W * 4))       $VID_T
do_video    ${URL_CAM_HOME[6]}    $VID_W  $VID_H  $((VID_W * 5))       $VID_T
do_video    ${URL_CAM_HOME[7]}    $VID_W  $VID_H  $((VID_W * 6))       $VID_T
do_video    ${URL_CAM_HOME[8]}    $VID_W  $VID_H  $((VID_W * 7))       $VID_T
do_video    ${URL_CAM_HOME[9]}    $VID_W  $VID_H  $((VID_W * 8))       $VID_T
do_video    ${URL_CAM_HOME[10]}   $VID_W  $VID_H  $((VID_W * 9))       $VID_T
do_video    ${URL_CAM_HOME[11]}   $VID_W  $VID_H  $((VID_W * 10))      $VID_T
do_video    ${URL_CAM_HOME[12]}   $VID_W  $VID_H  $((VID_W * 11))      $VID_T
