#!/bin/bash

# --------------------------------------------------------------------------------
#  kiosk
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
# 
#  Configuration Script. Allows operator to configure actions of Pi
#  Version 2.5 - Support screen rotation
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------
# 

# configuration parameters
WT_HEIGHT=20
WT_WIDTH=80
WT_MENU_HEIGHT=$((WT_HEIGHT - 7))
DEBUG=FALSE

# check for debug mode
is_debug () {
  if [ "$DEBUG" = TRUE ]; then
    return 0
  else
    return 1
  fi
}

# display main menu
while true; do
  # display menu
  FUN=$(whiptail --title "Kelowna Curling Club Kiosk Management v2" --backtitle "(c) Gareth Jones - gareth@gareth.com" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT  --cancel-button Quit --ok-button Select \
  "C1"  "Cameras over sheets 1 & 2"     \
  "C2"  "Cameras over sheets 3 & 4"     \
  "C3"  "Cameras over sheets 5 & 6"     \
  "C4"  "Cameras over sheets 7 & 8"     \
  "C5"  "Cameras over sheets 9 & 10"    \
  "C6"  "Cameras over sheets 11 & 12"   \
  "K1"  "Kiosk Upstairs"                \
  "K2"  "Kiosk Downstairs"              \
  "S1"  "Screen is Horizontal"          \
  "S2"  "Screen is Vertical"            \
  "U1"  "Upgrade the Kiosk Application" \
  "U2"  "Upgrade the Rapsberry Pi OS"   \
  3>&1 1>&2 2>&3)
  RET=$?

  # process response
  if [ $RET -eq 0 ]; then
    # menu item was selected
    whiptail --yesno "Are you sure?" 20 60 2
    if [ $? -eq 0 ]; then # yes
      case $FUN in
          U1)
            # upgrade service
            wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.run.sh    -O /home/kcckiosk/kiosk.run.sh
            wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/label-bg-h.png  -O /home/kcckiosk/label-bg-h.png
            wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/label-bg-v.png  -O /home/kcckiosk/label-bg-v.png
            ;;

          U2)
            # upgrade OS
            if is_debug; then echo "apt update";  else sudo apt update; fi
            if is_debug; then echo "apt upgrade"; else sudo sudo apt upgrade -y; fi
            ;;

          S1)
            # horizontal rotation
            echo "H" > kiosk.rotation
            echo "H"
            ;;

          S2)
            # vertical rotation
            echo "V" > kiosk.rotation
            echo "V"
            ;;

          *)
            # do camera or kiosk
            echo "$FUN" > kiosk.config
            echo "$FUN"
            ;;
      esac
      if is_debug; then echo "sync";    else sudo sync;   fi
      if is_debug; then echo "reboot";  else sudo reboot; fi
      exit 1
    fi
  else
    # quit was selected
    whiptail --yesno "Are you sure you want to quit?" 20 60 2
    if [ $? -eq 0 ]; then exit 1; fi
  fi
done
